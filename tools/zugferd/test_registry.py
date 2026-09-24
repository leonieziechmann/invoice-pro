"""Unit tests of the rule registry (registry.py): the committed registry,
its consistency with the rule modules and with the documentation.

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'

With the Mustang CLI jar 2.14.0 ($MUSTANG_JAR), the Factur-X aliases that
`covers` names are also checked against the Schematrons of the jar.
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import registry as r  # noqa: E402

JAR = os.environ.get("MUSTANG_JAR")


def entry(**changes):
    """A valid entry of an official rule, with `changes`."""
    out = {
        "covers": ["BR-02", "FX-SCH-A-000011"],
        "source": "EN16931",
        "versions": ["1.3.12", "1.3.16"],
        "profiles": ["minimum", "basic-wl"],
        "scope": "document",
        "terms": ["BT-1"],
        "level": "error",
        "field": "invoice-nr",
        "summary": "An invoice has an invoice number (BT-1).",
        "legal": None,
    }
    out.update(changes)
    return {key: value for key, value in out.items() if value is not ...}


def registry(**rules):
    return {"format": 1, "sources": {source: "" for source in r.SOURCES}, "rules": rules}


class Entries(unittest.TestCase):
    def test_the_committed_registry_is_valid(self):
        loaded = r.load()
        self.assertEqual(r.problems(loaded), [])
        # Every rule of the old validator and the write guard has an entry.
        self.assertGreaterEqual(len(loaded["rules"]), 120)
        for key in ("BR-02", "BR-48", "BR-DE-18", "IP-TAX-01", "IP-GUARD-07", "vat-rate-zero"):
            self.assertIn(key, loaded["rules"])

    def test_a_valid_entry(self):
        self.assertEqual(r.problems(registry(**{"BR-02": entry()})), [])

    def test_the_problems_of_an_entry(self):
        cases = [
            (entry(field=...), "rules.BR-02: no field"),
            (entry(extra="x"), "rules.BR-02: unknown field extra"),
            (entry(terms="BT-1"), "rules.BR-02.terms: str"),
            (entry(source="CEN"), "rules.BR-02.source: CEN"),
            (entry(scope="header"), "rules.BR-02.scope: header"),
            (entry(profiles=["basic-wl", "minimum"]), "rules.BR-02.profiles: not in the order"),
            (entry(profiles=[]), "rules.BR-02.profiles: []"),
            (entry(level=["warning", "warning"]), "rules.BR-02.level"),
            (entry(level="info"), "rules.BR-02.level: info"),
            (entry(covers=["IP-TAX-01"]), "rules.BR-02.covers: IP-TAX-01 is no official rule"),
            (entry(covers=["BR-03"]), "rules.BR-02.covers: lacks the ids it reports"),
            (entry(versions=[]), "rules.BR-02.versions: the artefact versions are missing"),
            (entry(legal="§ 14 UStG"), "rules.BR-02.legal: only for rules of invoice-pro"),
            (entry(terms=["BT1"]), "rules.BR-02.terms: BT1"),
            (entry(summary=" "), "rules.BR-02: empty summary or field"),
            (entry(ids=["BR-S"]), "rules.BR-02.ids: BR-S is no rule id"),
        ]
        for value, problem in cases:
            with self.subTest(problem=problem):
                found = r.problems(registry(**{"BR-02": value}))
                self.assertTrue(any(p.startswith(problem) for p in found), found)

    def test_the_rules_of_invoice_pro(self):
        own = entry(covers=[], source="IP", versions=[], legal="Art. 226 of the VAT Directive")
        self.assertEqual(r.problems(registry(**{"IP-TAX-01": own})), [])
        self.assertIn(
            "rules.IP-TAX-01.covers: a rule of invoice-pro covers no official rule",
            r.problems(registry(**{"IP-TAX-01": dict(own, covers=["BR-02"])})),
        )
        self.assertIn(
            "rules.IP-TAX-01.ids: a rule of invoice-pro reports ids of IP-* only",
            r.problems(registry(**{"IP-TAX-01": dict(own, ids=["BR-02"])})),
        )

    def test_the_registry_itself(self):
        broken = registry()
        broken["format"] = 2
        del broken["sources"]["IP"]
        self.assertEqual(
            r.problems(broken),
            ["format: 1 expected", f"sources: {sorted(r.SOURCES)} expected"],
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "registry.json"
            path.write_text('{"format": 1, "sources": {}, "rules": {}}', encoding="utf-8")
            with self.assertRaises(ValueError):
                r.load(path)

    def test_reported_and_covering(self):
        rules = {
            "BR-02": entry(),
            "vat-rate-zero": entry(
                ids=["BR-Z-05", "BR-E-05"],
                covers=["BR-Z-05", "BR-E-05"],
                profiles=["basic", "en16931"],
            ),
        }
        loaded = registry(**rules)
        self.assertEqual(
            r.reported(loaded),
            {"BR-02": ["BR-02"], "BR-Z-05": ["vat-rate-zero"], "BR-E-05": ["vat-rate-zero"]},
        )
        self.assertEqual(r.covering(loaded, "minimum"), {"BR-02": ["BR-02"], "FX-SCH-A-000011": ["BR-02"]})
        self.assertEqual(
            r.covering(loaded, "basic"), {"BR-Z-05": ["vat-rate-zero"], "BR-E-05": ["vat-rate-zero"]}
        )


class Sources(unittest.TestCase):
    """The registry and the rule modules under src/zugferd/rules/."""

    def test_every_entry_has_a_message_and_a_check(self):
        self.assertEqual(r.source_problems(r.load()), [])

    def test_the_messages_are_read(self):
        keys = r.message_keys()
        self.assertIn("BR-02", keys)
        self.assertIn("vat-rate-zero", keys)
        self.assertEqual(len(keys), len(set(keys)))

    def test_the_rule_ids_of_the_modules(self):
        literals = r.module_literals()
        self.assertIn("BR-CO-25", literals)
        # The prefixes of the rule families are no rule ids.
        self.assertIn("BR-IC", literals)
        self.assertIsNone(r.RULE_ID.match("BR-IC"))
        self.assertIsNotNone(r.RULE_ID.match("BR-DE-23-a"))
        self.assertIsNotNone(r.RULE_ID.match("PEPPOL-EN16931-R020"))

    def test_the_guard_rules(self):
        self.assertEqual(r.guard_ids(), {f"IP-GUARD-{n:02d}" for n in range(10)})


class Docs(unittest.TestCase):
    """The tables of the rules in docs/docs/e-invoicing.md."""

    def test_the_tables_are_the_generated_ones(self):
        self.assertEqual(r.docs_problems(r.load()), [])

    def test_the_layout_of_a_table(self):
        self.assertEqual(
            r.table([["`IP-X-01`", "error", "A check."]], ["Rule", "Level", "Checks"]),
            [
                "| Rule      | Level | Checks   |",
                "| :-------- | :---- | :------- |",
                "| `IP-X-01` | error | A check. |",
            ],
        )

    def test_write_docs(self):
        loaded = r.load()
        text = r.DOCS.read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "e-invoicing.md"
            # A stale row in each table.
            stale = text.replace("| `IP-TAX-01`", "| `IP-TAX-99`").replace("| `IP-GUARD-09`", "| `IP-GUARD-99`")
            path.write_text(stale, encoding="utf-8")
            self.assertEqual(len(r.docs_problems(loaded, path)), 2)
            r.write_docs(loaded, path)
            self.assertEqual(path.read_text(encoding="utf-8"), text)

    def test_a_missing_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "e-invoicing.md"
            path.write_text("# E-Invoicing\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                r.docs_problems(r.load(), path)


@unittest.skipUnless(JAR and Path(JAR).is_file(), "needs the Mustang CLI jar 2.14.0 ($MUSTANG_JAR)")
class Aliases(unittest.TestCase):
    """`covers` names the Factur-X rules of the official rules it covers."""

    @classmethod
    def setUpClass(cls):
        cls.aliases = r.fx_aliases(JAR)

    def test_the_aliases_of_the_jar(self):
        self.assertEqual(self.aliases["BR-02"], {"FX-SCH-A-000011"})
        # A code list rule at the position of the CEN rule.
        self.assertIn("FX-SCH-A-000040", self.aliases["BR-CL-04"])
        self.assertNotIn("BR-DE-1", self.aliases)

    def test_covers_names_every_alias(self):
        self.assertEqual(r.alias_problems(r.load(), self.aliases), [])

    def test_a_missing_and_a_wrong_alias(self):
        loaded = registry(**{"BR-02": entry(covers=["BR-02", "FX-SCH-A-000040"])})
        self.assertEqual(
            r.alias_problems(loaded, self.aliases),
            [
                "rules.BR-02.covers: lacks the Factur-X alias FX-SCH-A-000011",
                "rules.BR-02.covers: FX-SCH-A-000040 is no Factur-X alias of a rule it covers",
            ],
        )


if __name__ == "__main__":
    unittest.main()
