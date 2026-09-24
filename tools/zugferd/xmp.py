#!/usr/bin/env python3
"""Factur-X PDF check: an expected failure until Typst writes custom XMP.

  xmp.py [--update]

A Factur-X / ZUGFeRD PDF announces its XML in the XMP metadata of the PDF,
which Typst cannot write yet (https://github.com/typst/typst/issues/5667).
src/zugferd/xmp.typ prepares the metadata; this check tracks the gap:

  1. Typst compiles one test document per profile (DOCUMENTS) to PDF/A-3b.
  2. Mustang validates each PDF (one JVM): the XML must be valid, the PDF
     compliant with PDF/A-3, and its only problems the missing Factur-X XMP
     metadata (EXPECTED_PDF_ERRORS).
  3. Mustang adds the Factur-X XMP metadata (`--action combine`, the recipe
     of docs/docs/e-invoicing.md). The result must be valid in full, so the
     metadata is all that is missing. Its fx: values and schema description
     must equal tests/zugferd/xmp/mustang-<letter>.xmp, the reference the
     unit test of src/zugferd/xmp.typ compares with; --update rewrites the
     references from Mustang's output.
  4. Typst lists the definitions of its `pdf` module: one that is not in
     TYPST_PDF_DEFINITIONS may be the custom XMP support.

The check fails when anything differs from that: other problems of a PDF, a
PDF without the XMP problems (XPASS: the metadata is written now, turn this
check around), an invalid combined PDF, a changed reference, or a new
definition of `pdf` (check whether it writes custom XMP; if so, write the
metadata with src/zugferd/xmp.typ, else add it to TYPST_PDF_DEFINITIONS).

Needs Typst ($TYPST_BIN), Python 3.11+ with lxml and pypdf, a JDK and the
Mustang CLI jar ($MUSTANG_JAR); `nix run .#zugferd-xmp` provides them.
Exit code: 0 as expected, 1 not as expected, 2 setup error.
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common  # noqa: E402

REPO = common.REPO
REFERENCES = REPO / "tests" / "zugferd" / "xmp"

# One valid test document per profile, with Mustang's profile letter.
DOCUMENTS = {
    "minimum": ("M", "tests/integration/zugferd-profile-minimum/test.typ"),
    "basic-wl": ("W", "tests/integration/zugferd-small-biz-fr/test.typ"),
    "basic": ("B", "tests/integration/zugferd-profile-basic/test.typ"),
    "en16931": ("E", "tests/integration/zugferd-en16931/test.typ"),
    "xrechnung": ("X", "tests/integration/zugferd-auto/test.typ"),
}

# Mustang's messages (type, text) for a PDF without Factur-X XMP metadata.
EXPECTED_PDF_ERRORS = {
    (11, "XMP Metadata: ConformanceLevel not found"),
    (12, "XMP Metadata: ConformanceLevel contains invalid value"),
    (13, "XMP Metadata: DocumentType not found"),
    (14, "XMP Metadata: DocumentType invalid"),
    (15, "XMP Metadata: Version not found"),
    (16, "XMP Metadata: Version contains invalid value"),
    (19, "XMP Metadata: DocumentFileName contains invalid value"),
    (21, "XMP Metadata: DocumentFileName not found"),
}

# The definitions of Typst's `pdf` module (Typst 0.14): none writes custom
# XMP metadata. A new one may, see typst/typst#5667.
TYPST_PDF_DEFINITIONS = {"attach", "embed", "artifact"}

NS = {
    "x": "adobe:ns:meta/",
    "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    "fx": "urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#",
    "pdfaExtension": "http://www.aiim.org/pdfa/ns/extension/",
    "pdfaSchema": "http://www.aiim.org/pdfa/ns/schema#",
    "pdfaProperty": "http://www.aiim.org/pdfa/ns/property#",
}
FX_PROPERTIES = ("ConformanceLevel", "DocumentType", "DocumentFileName", "Version")
SCHEMA_NAME = "Factur-X PDFA Extension Schema"

# Values of Mustang's XMP that depend on the time and the machine, and
# what the references state instead.
_VOLATILE = [
    (re.compile(r"(<xmp:(?:CreateDate|ModifyDate|MetadataDate)>)[^<]*(</xmp:)"), r"\g<1>1980-01-01T00:00:00+00:00\2"),
    (re.compile(r"(<dc:date>\s*<rdf:Seq>\s*<rdf:li>)[^<]*(</rdf:li>)"), r"\g<1>1980-01-01T00:00:00+00:00\2"),
    (re.compile(r"(<dc:creator>\s*<rdf:Seq>\s*<rdf:li>)[^<]*(</rdf:li>)"), r"\g<1>(normalized)\2"),
]


def normalize(xmp):
    """Mustang's XMP packet without the values that depend on time and machine."""
    for pattern, replacement in _VOLATILE:
        xmp = pattern.sub(replacement, xmp)
    return xmp


def facts(xmp):
    """The fx: values and the PDF/A description of the Factur-X extension
    schema in an XMP packet: {"values": {name: text}, "schema": {...}}."""
    from lxml import etree

    root = etree.fromstring(xmp.encode("utf-8") if isinstance(xmp, str) else xmp,
                            etree.XMLParser(resolve_entities=False, no_network=True))
    # Every value as a list, so that a missing or repeated property shows.
    values = {name: [e.text for e in root.xpath(f"//fx:{name}", namespaces=NS)] for name in FX_PROPERTIES}
    schemas = [li for li in root.xpath("//pdfaExtension:schemas/rdf:Bag/rdf:li", namespaces=NS)
               if li.findtext("pdfaSchema:schema", namespaces=NS) == SCHEMA_NAME]
    schema = None
    if len(schemas) == 1:
        li = schemas[0]
        schema = {
            "namespaceURI": li.findtext("pdfaSchema:namespaceURI", namespaces=NS),
            "prefix": li.findtext("pdfaSchema:prefix", namespaces=NS),
            "properties": [
                [prop.findtext(f"pdfaProperty:{field}", namespaces=NS)
                 for field in ("name", "valueType", "category", "description")]
                for prop in li.xpath("pdfaSchema:property/rdf:Seq/rdf:li", namespaces=NS)
            ],
        }
    return {"values": values, "schema": schema}


def pdf_verdict(report):
    """(verdict, problems) of Mustang's report on a PDF of invoice-pro:
    "expected" when the XML is valid, the PDF is PDF/A compliant and its only
    problems are the missing Factur-X XMP metadata; "xpass" when the XMP
    problems are gone; "fail" otherwise."""
    pdf, xml = report["pdf"], report["xml"]
    problems = []
    if xml["status"] != "valid" or xml["errors"]:
        problems.append(f"the XML is not valid: {', '.join(xml['errors']) or xml['status']}")
    if pdf["compliant"] is not True:
        problems.append("the PDF is not PDF/A compliant")
    errors = set(pdf["errors"])
    other = sorted(errors - EXPECTED_PDF_ERRORS)
    if other:
        problems.append("other PDF problems: " + "; ".join(f"[{t}] {text}" for t, text in other))
    if problems:
        return "fail", problems
    if not errors & EXPECTED_PDF_ERRORS:
        return "xpass", ["the PDF has the Factur-X XMP metadata now: turn this expected failure into a check"]
    missing = sorted(EXPECTED_PDF_ERRORS - errors)
    if missing:
        return "fail", ["only part of the XMP metadata is missing: " + "; ".join(text for _, text in missing)
                        + " is there now"]
    return "expected", []


def combined_verdict(report):
    """Problems of the PDF with Mustang's Factur-X XMP: it must be valid."""
    pdf, xml = report["pdf"], report["xml"]
    problems = []
    if report["status"] != "valid":
        problems.append(f"overall status {report['status']}")
    if pdf["errors"]:
        problems.append("PDF: " + "; ".join(f"[{t}] {text}" for t, text in pdf["errors"]))
    if xml["errors"]:
        problems.append("XML: " + ", ".join(xml["errors"]))
    return problems


def new_definitions(names):
    """Definitions of Typst's `pdf` module this check does not know."""
    return sorted(set(names) - TYPST_PDF_DEFINITIONS)


def xmp_of(pdf):
    from pypdf import PdfReader

    reader = PdfReader(str(pdf))
    metadata = reader.trailer["/Root"].get("/Metadata")
    return metadata.get_object().get_data().decode("utf-8") if metadata is not None else None


def combine(pdf, xml, letter, out):
    """Mustang's recipe of docs/docs/e-invoicing.md: embeds the XML again
    together with the Factur-X XMP metadata. Returns (ok, output)."""
    java = common._java_tool("JAVA_BIN", "java")
    cmd = [java, "-jar", str(common.mustang_jar()), "--action", "combine", "--source", str(pdf),
           "--source-xml", str(xml), "--out", str(out), "--format", "fx", "--version", "1",
           "--profile", letter, "--no-additional-attachments"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    except FileNotFoundError:
        raise common.ToolError(f"java not found ({java}); set JAVA_BIN or JAVA_HOME")
    return proc.returncode == 0 and out.exists(), (proc.stdout + proc.stderr)[-1500:]


def typst_pdf_definitions(work):
    """(Typst version, definitions of its `pdf` module)."""
    probe = work / "probe.typ"
    probe.write_text("#metadata((version: str(sys.version), pdf: dictionary(pdf).keys())) <probe>\n", encoding="utf-8")
    cmd = [common.typst_bin(), "query", "--root", str(work), str(probe), "<probe>", "--field", "value", "--one"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except FileNotFoundError:
        raise common.ToolError(f"Typst not found ({common.typst_bin()}); set TYPST_BIN")
    if proc.returncode != 0:
        raise common.ToolError("typst query failed:\n" + proc.stderr.strip()[:1000])
    value = json.loads(proc.stdout)
    return value["version"], value["pdf"]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--update", action="store_true", help="rewrite the references tests/zugferd/xmp/mustang-*.xmp")
    args = ap.parse_args(argv)
    lines, failed = [], 0
    try:
        work = common.build_dir() / "xmp"
        shutil.rmtree(work, ignore_errors=True)
        work.mkdir(parents=True)
        mustang = common.Mustang(common.mustang_jar(), common.build_dir())
        try:
            compiled = {}
            for profile, (letter, document) in DOCUMENTS.items():
                pdf = work / f"{letter}.pdf"
                ok, stderr, _ = common.typst_compile(REPO / document, pdf)
                if not ok:
                    raise common.ToolError(f"{document} does not compile:\n{stderr.strip()[:1500]}")
                attachments, _ = common.read_pdf(pdf, text=False)
                name, data = common.invoice_xml(attachments)
                if data is None:
                    raise common.ToolError(f"{document}: no e-invoice XML attached")
                guideline = common.xtext1(common.parse_xml(data), common.GUIDELINE_PATH)
                if common.GUIDELINES.get(guideline, (None,))[0] != profile:
                    raise common.ToolError(f"{document} is no longer a {profile} invoice ({guideline})")
                xml = work / f"{letter}.xml"
                xml.write_bytes(data)
                combined = work / f"{letter}-combined.pdf"
                ok, output = combine(pdf, xml, letter, combined)
                if not ok:
                    raise common.ToolError(f"Mustang could not combine {document}:\n{output}")
                compiled[profile] = (pdf, combined, mustang.submit(pdf), mustang.submit(combined))
            for profile, (pdf, combined, plain_future, combined_future) in compiled.items():
                letter, document = DOCUMENTS[profile]
                verdict, problems = pdf_verdict(common.parse_mustang_pdf_report(plain_future.result()["report"]))
                problems += [f"with Mustang's XMP metadata: {p}" for p in
                             combined_verdict(common.parse_mustang_pdf_report(combined_future.result()["report"]))]
                xmp = normalize(xmp_of(combined) or "")
                reference = REFERENCES / f"mustang-{letter}.xmp"
                if args.update:
                    reference.write_text(xmp, encoding="utf-8")
                elif not reference.exists():
                    problems.append(f"no reference {reference.relative_to(REPO)} (run with --update)")
                elif facts(xmp) != facts(reference.read_text(encoding="utf-8")):
                    problems.append(f"Mustang's XMP differs from {reference.relative_to(REPO)}: update it with "
                                    "--update and check src/zugferd/xmp.typ with tests/zugferd/xmp")
                if verdict == "expected" and not problems:
                    status = "EXPECTED FAILURE"
                else:
                    status = "XPASS" if verdict == "xpass" else "FAIL"
                    failed += 1
                lines.append(f"  {status:16s} {profile:9s} {document}")
                lines += [f"                   {p}" for p in problems]
        finally:
            mustang.close()
        version, definitions = typst_pdf_definitions(work)
        new = new_definitions(definitions)
        lines.append(f"  Typst {version}, `pdf` module: {', '.join(definitions)}")
        if new:
            failed += 1
            lines.append(f"  FAIL             new definitions of `pdf`: {', '.join(new)}. If one writes custom XMP "
                         "metadata (typst/typst#5667), write the Factur-X metadata with src/zugferd/xmp.typ and turn "
                         "this check around; otherwise add them to TYPST_PDF_DEFINITIONS in tools/zugferd/xmp.py.")
    except common.ToolError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    print("Factur-X PDF check: an expected failure until Typst can write custom XMP metadata "
          "(https://github.com/typst/typst/issues/5667)")
    print("\n".join(lines))
    print()
    if failed:
        print(f"✘ {failed} checks are not as expected (see tools/zugferd/xmp.py).")
        return 1
    print("✔ Expected failure: the PDFs are PDF/A-3 with valid XML and lack only the Factur-X XMP metadata, "
          "which Mustang's recipe adds.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
