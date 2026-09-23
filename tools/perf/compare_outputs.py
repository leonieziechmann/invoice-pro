#!/usr/bin/env python3
"""Check that a change keeps the output of documents identical.

Compiles every document in two checkouts of the repository, `--base` (e.g. the
commit before an optimization) and `--head`, and compares

  * the exit status and the diagnostics (the messages on stderr; the code
    excerpts may show other line numbers when the change moved code),
  * the PDF, byte for byte,
  * if the PDFs differ: the attachments (name, AFRelationship, description,
    MIME type and content, so the e-invoice XML) and the text of the pages,
  * if neither checkout can export a PDF (e.g. a test with several e-invoices,
    whose attachments share a name): the attachments as `typst query` sees
    them (path, relationship, MIME type, description and content).

A performance change must leave every document identical. Documents are given
relative to the checkouts and must exist in both, e.g. a test, the template
or files copied into both trees:

  tools/perf/compare_outputs.py --base /tmp/base --head . \\
      template/invoice.typ tests/integration/zugferd-basic/test.typ

With `--mode panic|report|ignore`, every document that sets `zugferd:` is also
compiled with that `zugferd-errors` mode (inserted before its `zugferd:`
argument); copies are written next to the document as `.cmp-<mode>-*.typ` and
removed afterwards.

Exit status 1 if any document differs. Needs Python 3 and `typst`; comparing
attachments and page text of differing PDFs needs the `pypdf` package.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

_ZUGFERD_ARG = re.compile(r"^([ \t]*)zugferd:", re.M)
# Lines of the code excerpt of a diagnostic: `┌─ file:line:column`, numbered
# source lines and the gutter. Their line numbers change whenever a changed
# file is involved, so they are compared separately from the messages.
_EXCERPT_LINE = re.compile(r"^\s*(\d+\s*)?[│·┌╭╰]")
# Lists the attachments of a document without exporting it.
_QUERY_WRAPPER = """#include "/{document}"
#context for a in query(pdf.attach) {{
  [#metadata((
    a.path, a.relationship, a.mime-type, a.description, str(a.data),
  ))<compare-outputs-attachment>]
}}
"""


def _messages(stderr):
    return [line for line in stderr.splitlines() if not _EXCERPT_LINE.match(line)]


def _variant(root, document, mode):
    """Writes a copy of `document` with `zugferd-errors: mode` (or None)."""
    path = os.path.join(root, document)
    with open(path, encoding="utf-8") as f:
        source = f.read()
    if "zugferd-errors" in source or not _ZUGFERD_ARG.search(source):
        return None
    source = _ZUGFERD_ARG.sub(
        lambda m: f'{m.group(1)}zugferd-errors: "{mode}",\n{m.group(1)}zugferd:',
        source,
        count=1,
    )
    directory, name = os.path.split(document)
    variant = os.path.join(directory, f".cmp-{mode}-{name}")
    with open(os.path.join(root, variant), "w", encoding="utf-8") as f:
        f.write(source)
    return variant


def _typst(args, root, *command):
    extra = ["--creation-timestamp", str(args.timestamp)]
    process = subprocess.run(
        [args.typst, command[0], "--root", ".", *extra, *command[1:]],
        cwd=root,
        capture_output=True,
        text=True,
    )
    return process.returncode, process.stdout, process.stderr


def _queried_attachments(args, root, document, index):
    """The attachments as `typst query` lists them, or None if it fails."""
    wrapper = f".cmp-query-{index}.typ"
    path = os.path.join(root, wrapper)
    with open(path, "w", encoding="utf-8") as f:
        f.write(_QUERY_WRAPPER.format(document=document))
    try:
        code, stdout, _ = _typst(
            args,
            root,
            "query",
            wrapper,
            "<compare-outputs-attachment>",
            "--field",
            "value",
        )
    finally:
        os.remove(path)
    return json.loads(stdout) if code == 0 else None


def _attachments(pdf):
    """(name, relationship, description, mime type, sha256) per attachment."""
    import pypdf  # optional dependency, only needed when the PDFs differ

    reader = pypdf.PdfReader(pdf)
    names = reader.trailer["/Root"].get("/Names")
    if names is None or "/EmbeddedFiles" not in names:
        return []
    out = []

    def walk(node):
        node = node.get_object()
        for kid in node.get("/Kids", []):
            walk(kid)
        entries = node.get("/Names", [])
        for i in range(0, len(entries), 2):
            spec = entries[i + 1].get_object()
            stream = spec["/EF"]["/F"].get_object()
            out.append(
                (
                    str(spec.get("/UF", spec.get("/F"))),
                    str(spec.get("/AFRelationship")),
                    str(spec.get("/Desc")),
                    str(stream.get("/Subtype")),
                    hashlib.sha256(stream.get_data()).hexdigest(),
                )
            )

    walk(names["/EmbeddedFiles"])
    return sorted(out)


def _page_text(pdf):
    import pypdf

    return [page.extract_text() for page in pypdf.PdfReader(pdf).pages]


def _compare_pdfs(base_path, head_path):
    differences = []
    try:
        base_files = _attachments(base_path)
        head_files = _attachments(head_path)
        if [f[4] for f in base_files] != [f[4] for f in head_files]:
            differences.append("attached data differs")
        elif base_files != head_files:
            differences.append(
                f"attachment metadata differs: {base_files} -> {head_files}"
            )
        if _page_text(base_path) != _page_text(head_path):
            differences.append("page text differs")
    except ImportError:
        return ["PDF bytes differ (install pypdf for details)"]
    return differences or ["PDF bytes differ"]


def compare(args, document, out_dir, index):
    """Compiles `document` in both checkouts; returns its differences."""
    results = []
    for side, root in (("base", args.base), ("head", args.head)):
        pdf = os.path.join(out_dir, f"{index}-{side}.pdf")
        code, _, stderr = _typst(args, root, "compile", document, pdf)
        data = None
        if code == 0 and os.path.exists(pdf):
            with open(pdf, "rb") as f:
                data = f.read()
        results.append((code, stderr, data, pdf))
    (base_code, base_err, base_pdf, base_path) = results[0]
    (head_code, head_err, head_pdf, head_path) = results[1]

    differences = []
    notes = []
    if base_code != head_code:
        differences.append(f"exit status {base_code} -> {head_code}")
    if _messages(base_err) != _messages(head_err):
        differences.append("diagnostics differ")
    elif base_err != head_err:
        notes.append("same diagnostics at other source lines")

    if base_pdf is not None and head_pdf is not None:
        if base_pdf != head_pdf:
            differences += _compare_pdfs(base_path, head_path)
    elif base_code != 0 and head_code != 0:
        base_files = _queried_attachments(args, args.base, document, index)
        head_files = _queried_attachments(args, args.head, document, index)
        if base_files != head_files:
            differences.append("queried attachments differ")
        elif base_files is not None:
            notes.append(f"{len(base_files)} queried attachments identical")

    status = "ok" if base_code == 0 else f"ok, both fail with status {base_code}"
    return document, differences, "; ".join([status] + notes), base_err, head_err


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "documents", nargs="*", help="documents, relative to the roots"
    )
    parser.add_argument(
        "--from-file",
        metavar="FILE",
        help="also compare the documents listed in FILE, one per line",
    )
    parser.add_argument("--base", required=True, help="checkout before the change")
    parser.add_argument("--head", required=True, help="checkout after the change")
    parser.add_argument(
        "--mode",
        action="append",
        default=[],
        choices=("panic", "report", "ignore"),
        help="also compile e-invoices with this zugferd-errors mode (repeatable)",
    )
    parser.add_argument(
        "--timestamp",
        type=int,
        default=315532800,
        help="creation timestamp for both compiles (default: 315532800)",
    )
    parser.add_argument("--typst", default="typst", help="typst executable")
    parser.add_argument("--jobs", type=int, default=1, help="parallel compiles")
    parser.add_argument(
        "--verbose", action="store_true", help="list identical documents, too"
    )
    args = parser.parse_args(argv)
    args.base = os.path.abspath(args.base)
    args.head = os.path.abspath(args.head)

    documents = list(args.documents)
    if args.from_file:
        with open(args.from_file, encoding="utf-8") as f:
            documents += [line.strip() for line in f if line.strip()]
    if not documents:
        parser.error("no documents given")
    originals = list(documents)
    variants = []
    try:
        for mode in args.mode:
            for document in originals:
                base_variant = _variant(args.base, document, mode)
                head_variant = _variant(args.head, document, mode)
                if base_variant is not None and base_variant == head_variant:
                    variants.append(base_variant)
                    documents.append(base_variant)

        with tempfile.TemporaryDirectory(prefix="invoice-pro-cmp-") as out_dir:
            with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
                results = list(
                    pool.map(
                        lambda item: compare(args, item[1], out_dir, item[0]),
                        enumerate(documents),
                    )
                )
    finally:
        for variant in variants:
            for root in (args.base, args.head):
                path = os.path.join(root, variant)
                if os.path.exists(path):
                    os.remove(path)

    failed = 0
    for document, differences, status, base_err, head_err in results:
        if differences:
            failed += 1
            print(f"DIFFERS {document}: " + "; ".join(differences))
            if "diagnostics differ" in differences:
                print("  base: " + base_err.strip().replace("\n", "\n        "))
                print("  head: " + head_err.strip().replace("\n", "\n        "))
        elif args.verbose:
            print(f"same    {document}: {status}")
    print(
        f"{len(results) - failed} of {len(results)} documents identical"
        + (f", {failed} differ" if failed else "")
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
