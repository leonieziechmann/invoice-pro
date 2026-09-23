#!/usr/bin/env python3
"""Golden e-invoice XML and reproducibility check.

  golden.py [--update] [--jobs N] [DOCUMENT.typ ...]

The documents are the e-invoice test documents that must be valid, as listed
in scripts/validate-all-zugferd (one list for both checks). For each one:

  1. Reproducibility: compile it twice (PDF/A-3b, fixed creation timestamp)
     and require bit-identical PDFs. This is invoice-pro's guarantee: the
     same Typst and package version give the same document, PDF and XML.
  2. Golden XML: extract the attached XML and compare it with the committed
     tests/zugferd/golden/<document>.xml. The golden files are pretty-printed,
     so a change of the output shows up as a readable diff in the review.

--update rewrites the golden files (and removes those of documents that are
no longer listed). An intended change of the XML updates them in the same
commit; a change users notice is also documented in docs/docs/e-invoicing.md.
"""

import argparse
import difflib
import hashlib
import re
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common  # noqa: E402

REPO = common.REPO
GOLDEN = REPO / "tests" / "zugferd" / "golden"
LIST = REPO / "scripts" / "validate-all-zugferd"


def listed_documents():
    """The documents scripts/validate-all-zugferd validates, in its order."""
    docs = []
    for line in LIST.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        m = re.match(r'^"\$VALIDATE_ZUGFERD"\s+"([^"$]+\.typ)"', line)
        if m:
            docs.append(m.group(1))
            continue
        m = re.match(r"^for\s+\w+\s+in\s+(\S+\.typ)\s*;", line)
        if m:
            docs += sorted(str(p.relative_to(REPO)) for p in REPO.glob(m.group(1)))
    if not docs:
        raise common.ToolError(f"no documents found in {LIST}")
    return docs


def golden_path(document):
    """tests/integration/zugferd-basic/test.typ -> golden/integration/zugferd-basic.xml"""
    rel = Path(document)
    if rel.parts[0] == "tests":
        rel = Path(*rel.parts[1:])
    if rel.name == "test.typ":
        rel = rel.parent
    return GOLDEN / rel.with_suffix(".xml") if rel.suffix == ".typ" else GOLDEN / (str(rel) + ".xml")


def pretty(xml):
    from lxml import etree

    parser = etree.XMLParser(remove_blank_text=True, resolve_entities=False, no_network=True)
    root = etree.fromstring(xml, parser)
    return etree.tostring(root, pretty_print=True, xml_declaration=True, encoding="UTF-8").decode("utf-8")


_PACKAGE_IMPORT = re.compile(r'"@preview/invoice-pro:[0-9.]+"')


def source_of(document):
    """The file to compile: documents that import the published package (the
    template) are compiled against the checkout, as a copy under the build
    directory whose import points to /src/lib.typ."""
    path = REPO / document
    text = path.read_text(encoding="utf-8")
    if not _PACKAGE_IMPORT.search(text):
        return path
    copy = common.build_dir() / "golden-src" / (document.replace("/", "--"))
    copy.parent.mkdir(parents=True, exist_ok=True)
    copy.write_text(_PACKAGE_IMPORT.sub('"/src/lib.typ"', text), encoding="utf-8")
    return copy


def check(document, work):
    """Compiles `document` twice; returns (pretty XML or None, problems)."""
    problems = []
    digests = []
    xml = None
    source = source_of(document)
    for run in (1, 2):
        pdf = work / f"{hashlib.sha1(document.encode()).hexdigest()[:12]}-{run}.pdf"
        ok, stderr, _ = common.typst_compile(source, pdf)
        if not ok:
            return None, [f"compilation failed:\n{stderr.strip()[:2000]}"]
        data = pdf.read_bytes()
        digests.append(hashlib.sha256(data).hexdigest())
        if run == 1:
            attachments, _ = common.read_pdf(pdf, text=False)
            _, raw = common.invoice_xml(attachments)
            if raw is None:
                return None, ["no e-invoice XML attached"]
            xml = pretty(raw)
    if digests[0] != digests[1]:
        problems.append(f"not reproducible: two compilations gave different PDFs ({digests[0][:12]} vs {digests[1][:12]})")
    return xml, problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("documents", nargs="*", help="default: the documents of scripts/validate-all-zugferd")
    ap.add_argument("--update", action="store_true", help="rewrite the golden files")
    ap.add_argument("--jobs", type=int, default=4)
    args = ap.parse_args(argv)
    try:
        documents = args.documents or listed_documents()
    except common.ToolError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    failed = 0
    with tempfile.TemporaryDirectory(prefix="golden-") as tmp:
        work = Path(tmp)
        with ThreadPoolExecutor(args.jobs) as pool:
            results = list(pool.map(lambda d: (d, *check(d, work)), documents))
    for document, xml, problems in results:
        target = golden_path(document)
        rel = target.relative_to(REPO)
        if xml is not None:
            if args.update:
                if not target.exists() or target.read_text(encoding="utf-8") != xml:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text(xml, encoding="utf-8")
                    print(f"  updated  {rel}")
            elif not target.exists():
                problems.append(f"no golden file {rel} (run with --update and commit it)")
            else:
                expected = target.read_text(encoding="utf-8")
                if expected != xml:
                    diff = difflib.unified_diff(
                        expected.splitlines(), xml.splitlines(), f"{rel} (golden)", f"{document} (now)", lineterm="", n=2
                    )
                    problems.append("XML differs from the golden file:\n" + "\n".join(list(diff)[:80]))
        status = "FAIL" if problems else "ok"
        print(f"  {status:5s} {document}")
        for p in problems:
            print("        " + p.replace("\n", "\n        "))
        failed += bool(problems)
    if not args.documents:
        wanted = {golden_path(d) for d in documents}
        for stale in sorted(p for p in GOLDEN.rglob("*.xml") if p not in wanted):
            if args.update:
                stale.unlink()
                print(f"  removed  {stale.relative_to(REPO)} (document no longer listed)")
            else:
                print(f"  FAIL  {stale.relative_to(REPO)}: golden file of a document that is no longer listed")
                failed += 1
    print()
    if failed:
        print(f"✘ {failed} of {len(documents)} e-invoice documents failed (tests/TESTING.md: golden XML).")
        return 1
    print(f"✔ {len(documents)} e-invoice documents are reproducible and match their golden XML.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
