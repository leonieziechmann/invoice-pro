"""Unit tests of the business term disposition check (no Typst, no Java).

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'
"""

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bt_disposition  # noqa: E402


def table(**overrides):
    """A complete table (every term unsupported), with `overrides` applied:
    a term mapped to None is removed."""
    terms = {term: {"name": term, "disposition": "unsupported", "reason": "test"} for term in bt_disposition.TERMS}
    for term, entry in overrides.items():
        term = term.replace("_", "-")
        if entry is None:
            terms.pop(term)
        else:
            terms[term] = entry
    return {"terms": terms}


class Disposition(unittest.TestCase):
    def test_committed_table_is_complete(self):
        committed = bt_disposition.load(bt_disposition.TABLE)
        self.assertEqual(bt_disposition.check(committed), [])
        # The party details have their inputs.
        terms = committed["terms"]
        for term in ("BT-28", "BT-30", "BT-33", "BT-45", "BT-47", "BG-9", "BG-10", "BG-11"):
            self.assertEqual(terms[term]["disposition"], "input", term)

    def test_terms_of_en16931(self):
        self.assertEqual(len(bt_disposition.TERMS), 164 + 32)
        self.assertNotIn("BT-4", bt_disposition.TERMS)
        self.assertIn("BT-165", bt_disposition.TERMS)
        self.assertIn("BG-32", bt_disposition.TERMS)

    def test_complete_table(self):
        self.assertEqual(bt_disposition.check(table()), [])

    def test_missing_term(self):
        self.assertEqual(bt_disposition.check(table(BT_30=None)), ["BT-30: has no disposition"])

    def test_unknown_term(self):
        problems = bt_disposition.check(table(BT_4={"name": "x", "disposition": "unsupported", "reason": "x"}))
        self.assertEqual(len(problems), 1)
        self.assertTrue(problems[0].startswith("BT-4: is no business term"), problems)

    def test_disposition_needs_its_key(self):
        cases = {
            "BT-1": {"name": "Invoice number", "disposition": "input"},
            "BT-106": {"name": "Sum", "disposition": "derived", "reason": "wrong key"},
            "BT-6": {"name": "Currency", "disposition": "unsupported", "reason": " "},
        }
        problems = bt_disposition.check(table(**{k.replace("-", "_"): v for k, v in cases.items()}))
        self.assertIn("BT-1: a disposition 'input' needs `input`", problems)
        self.assertIn("BT-106: a disposition 'derived' needs `source`", problems)
        self.assertTrue(any(p.startswith("BT-106: unknown keys reason") for p in problems), problems)
        self.assertIn("BT-6: a disposition 'unsupported' needs `reason`", problems)

    def test_invalid_entries(self):
        problems = bt_disposition.check(
            table(
                BT_2={"name": "Date", "disposition": "maybe", "input": "date"},
                BT_3={"disposition": "derived", "source": "380"},
                BT_5="EUR",
            )
        )
        self.assertEqual(
            sorted(problems),
            [
                "BT-2: disposition 'maybe' is none of input, derived, unsupported",
                "BT-3: has no `name`",
                "BT-5: must be a table with `name` and `disposition`",
            ],
        )
        self.assertEqual(bt_disposition.check({}), ["the table has no [terms] table"])

    def test_main(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "table.toml"
            path.write_text('[terms]\n"BT-1" = { name = "Invoice number", disposition = "input", input = "invoice-nr" }\n')
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(bt_disposition.main([str(path)]), 1)
            self.assertIn("BT-2: has no disposition", out.getvalue())
            path.write_text("not toml [")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(bt_disposition.main([str(path)]), 1)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(bt_disposition.main([]), 0)
        self.assertIn("196 business terms of EN 16931 have a disposition", out.getvalue())


if __name__ == "__main__":
    unittest.main()
