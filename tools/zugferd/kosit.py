#!/usr/bin/env python3
"""KoSIT validation of e-invoice documents.

  kosit.py FILE.pdf|FILE.xml ...

KoSIT, the reference validator for XRechnung (version 1.6.3 with the
XRechnung configuration 2026-08-31), checks the EN 16931 and XRechnung
documents among the files in a single JVM: the XML attached to a PDF, or an
XML file as it is. It has no scenario for MINIMUM, BASIC WL and BASIC, which
are listed as skipped. scripts/validate-all-zugferd runs it over its test
documents; the conformance corpus (run.py) runs KoSIT itself.

Needs Python 3.11+ with lxml and pypdf, Java and KOSIT_JAR / KOSIT_CONFIG
(see common.py).

Exit code: 0 KoSIT accepts every EN 16931 and XRechnung document, 1 it
rejects one, 2 setup error.
"""

import argparse
import re
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common  # noqa: E402


def extract(files, xml_dir):
    """[(file, XML path, profile)]: the e-invoice XML of every file, written
    to `xml_dir` under a name of its own."""
    docs = []
    for n, file in enumerate(files, 1):
        path = Path(file)
        if not path.is_file():
            raise common.ToolError(f"{file} does not exist")
        if path.suffix.lower() == ".pdf":
            attachments, _ = common.read_pdf(path, text=False)
            _, data = common.invoice_xml(attachments)
            if data is None:
                raise common.ToolError(f"{file}: no e-invoice XML attached")
        else:
            data = path.read_bytes()
        target = xml_dir / f"{n:03d}-{re.sub(r'[^A-Za-z0-9._-]', '_', path.stem)}.xml"
        target.write_bytes(data)
        try:
            guideline = common.xtext1(common.parse_xml(data), common.GUIDELINE_PATH)
        except Exception:  # not well-formed: KoSIT reports it
            guideline = None
        profile = common.GUIDELINES.get(guideline, (None,))[0]
        docs.append((file, target, profile))
    return docs


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+", help="PDFs with an attached e-invoice, or XML files")
    args = ap.parse_args(argv)
    rejected = checked = 0
    try:
        jar, config = common.kosit_setup()
        with tempfile.TemporaryDirectory(prefix="kosit-") as tmp:
            work = Path(tmp)
            (work / "xml").mkdir()
            docs = extract(args.files, work / "xml")
            kosit = common.Kosit(jar, config, work)
            # A document that is not well-formed has no profile: KoSIT rejects it.
            batch = [target for _, target, profile in docs if profile in common.KOSIT_PROFILES or profile is None]
            reports = kosit.validate(batch)
            print(f"{kosit.describe()}: {len(batch)} of {len(docs)} documents (EN 16931 and XRechnung)")
            for file, target, profile in docs:
                report = reports.get(str(target.resolve()))
                if report is None:
                    print(f"  skipped     {Path(file).name} ({profile}: KoSIT has no scenario for it)")
                    continue
                checked += 1
                ok = report["status"] == "accept"
                rejected += not ok
                print(f"  {'ACCEPTABLE' if ok else 'REJECT':10s}  {Path(file).name} ({profile or 'unknown profile'}, "
                      f"{report['scenario'] or 'no scenario matched'})")
                for rule, message in report["errors"].items():
                    print(f"      error    [{rule}] {message[:300]}")
                for rule, message in report["warnings"].items():
                    print(f"      warning  [{rule}] {message[:300]}")
    except common.ToolError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    if rejected:
        print(f"✘ KoSIT rejects {rejected} of {checked} documents.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
