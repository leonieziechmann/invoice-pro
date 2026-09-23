"""Unit tests of the golden XML tool (no Typst).

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'
"""

import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common  # noqa: E402
import golden  # noqa: E402


class Golden(unittest.TestCase):
    def test_documents_come_from_the_validation_list(self):
        documents = golden.listed_documents()
        self.assertIn("template/invoice.typ", documents)
        self.assertIn("tests/integration/zugferd-basic/test.typ", documents)
        # The loop over the payment reference tests is expanded.
        self.assertTrue(any(d.startswith("tests/integration/payment-reference/") for d in documents))
        self.assertEqual(len(documents), len(set(documents)))
        for document in documents:
            self.assertTrue((common.REPO / document).exists(), document)

    def test_every_validation_call_is_understood(self):
        original = golden.LIST
        with tempfile.TemporaryDirectory() as tmp:
            golden.LIST = Path(tmp) / "validate-all-zugferd"
            try:
                golden.LIST.write_text(
                    'if ! command -v "$VALIDATE_ZUGFERD" &> /dev/null; then\nfi\n'
                    '"$VALIDATE_ZUGFERD" "template/invoice.typ"\n'
                    "for doc in tests/integration/payment-reference/*/test.typ; do\n"
                    '  "$VALIDATE_ZUGFERD" "$doc"\ndone\n'
                )
                self.assertEqual(golden.listed_documents()[0], "template/invoice.typ")
                # A call whose document is not known, or a loop over nothing,
                # would leave a document without golden file.
                for listing in (
                    '"$VALIDATE_ZUGFERD" "$DOCUMENT"\n',
                    'for doc in tests/none/*/test.typ; do\n  "$VALIDATE_ZUGFERD" "$doc"\ndone\n',
                ):
                    golden.LIST.write_text('"$VALIDATE_ZUGFERD" "template/invoice.typ"\n' + listing)
                    with self.assertRaises(common.ToolError):
                        golden.listed_documents()
            finally:
                golden.LIST = original

    def test_golden_paths(self):
        def path(document):
            return golden.golden_path(document).relative_to(common.REPO).as_posix()

        self.assertEqual(path("tests/integration/zugferd-basic/test.typ"), "tests/zugferd/golden/integration/zugferd-basic.xml")
        self.assertEqual(path("template/invoice.typ"), "tests/zugferd/golden/template/invoice.xml")

    def test_every_listed_document_has_a_golden_file(self):
        for document in golden.listed_documents():
            self.assertTrue(golden.golden_path(document).exists(), f"{document}: run scripts/zugferd-golden --update")

    def test_pretty_printing_is_stable(self):
        xml = b'<?xml version="1.0"?><a xmlns="urn:x"><b>1</b><c>line 1\nline 2\n</c></a>'
        once = golden.pretty(xml)
        self.assertEqual(golden.pretty(once.encode("utf-8")), once)
        self.assertIn("line 1\nline 2\n", once)  # text, e.g. payment terms, keeps its line breaks


if __name__ == "__main__":
    unittest.main()
