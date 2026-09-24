"""Unit tests of the rule coverage gate (rule_coverage.py).

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'

The parts run on small synthetic artefacts, inventories and classification
files and need only lxml. With the Mustang CLI jar 2.14.0 ($MUSTANG_JAR) and
KoSIT's XRechnung configuration ($KOSIT_CONFIG), the inventory of the pinned
artefacts is checked as well.
"""

import collections
import os
import sys
import tempfile
import unittest
import unittest.mock
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common  # noqa: E402
import rule_coverage as rc  # noqa: E402

XSLT = """<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl" version="2.0">
  <xsl:template match="//ram:SellerTradeParty" priority="4" mode="d7">
    <xsl:if test="not(ram:Name)">
      <svrl:failed-assert id="BR-06" flag="fatal">
        <xsl:attribute name="test">ram:Name</xsl:attribute>
        <svrl:text>[BR-06]-The Seller name (BT-27) shall be provided.</svrl:text>
      </svrl:failed-assert>
    </xsl:if>
    <xsl:if test="not(count(ram:ID) &lt;= 1)">
      <svrl:failed-assert id="CII-SR-04" flag="warning">
        <xsl:attribute name="test">count(ram:ID) &lt;= 1</xsl:attribute>
        <svrl:text>[CII-SR-004] - Only one ID</svrl:text>
      </svrl:failed-assert>
    </xsl:if>
  </xsl:template>
  <xsl:template match="//ram:BilledQuantity" priority="3" mode="d7">
    <xsl:if test="not(@unitCode = 'H87')">
      <svrl:failed-assert id="BR-CL-23" flag="fatal">
        <xsl:attribute name="test">@unitCode = 'H87'</xsl:attribute>
        <svrl:text>[BR-CL-23]-Unit code</svrl:text>
      </svrl:failed-assert>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>"""

SCENARIOS = """<scenarios xmlns="http://www.xoev.de/de/validator/framework/1/scenarios">
  <scenario>
    <name>EN16931 (CII)</name>
    <match>exists(/rsm:CrossIndustryInvoice[rsm:ExchangedDocumentContext/ram:GuidelineSpecifiedDocumentContextParameter/ram:ID/text() = 'urn:cen.eu:en16931:2017'])</match>
    <validateWithSchematron><resource><name>CEN</name><location>cen.xsl</location></resource></validateWithSchematron>
  </scenario>
  <scenario>
    <name>EN16931 (UBL)</name>
    <match>exists(/invoice:Invoice[cbc:CustomizationID = 'urn:cen.eu:en16931:2017'])</match>
    <validateWithSchematron><resource><name>UBL</name><location>ubl.xsl</location></resource></validateWithSchematron>
  </scenario>
  <scenario>
    <name>EN16931 XRechnung (CII)</name>
    <match>exists(/rsm:CrossIndustryInvoice[rsm:ExchangedDocumentContext/ram:GuidelineSpecifiedDocumentContextParameter/ram:ID/text() = 'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0'])</match>
    <validateWithSchematron><resource><name>CEN</name><location>cen.xsl</location></resource></validateWithSchematron>
    <validateWithSchematron><resource><name>XR</name><location>xr.xsl</location></resource></validateWithSchematron>
    <createReport><resource><name>r</name><location>r.xsl</location></resource>
      <customLevel level="warning">BR-CL-23</customLevel>
    </createReport>
  </scenario>
</scenarios>"""


def assertion(ref, validator="mustang", dispositions=("compiled",), context=None, test=None, level="error",
              rule_id=None):
    return rc.Assertion(
        validator=validator,
        artefact="CEN" if validator == "mustang" else "cen.xsl",
        id=rule_id or ref,
        ref=ref,
        context=context or f"//{ref}",
        test=test or f"test({ref})",
        flag=None,
        level=level,
        text=f"[{ref}] text",
        dispositions=tuple(dispositions) if validator == "mustang" else (),
    )


def twin(a, **changes):
    """KoSIT's version of a Mustang assertion (same context and test)."""
    return rc.Assertion(**dict(vars(a), validator="kosit", artefact="cen.xsl", dispositions=(), **changes))


def inventory(**profiles):
    """An inventory of {profile: {rule: [assertions]}} (profile names with _)."""
    rules = {p: {} for p in rc.PROFILES}
    for name, found in profiles.items():
        rules[name.replace("_", "-")] = dict(found)
    return rc.Inventory(rules, {p: collections.Counter() for p in rc.PROFILES}, {}, guard=True, kosit=True)


def entry(ids, cls, profiles=None, reason="r", evidence=(), reported_as=(), index=0):
    return rc.Entry(index, list(ids), cls, profiles, reason, list(evidence), None, list(reported_as))


def fixture(rule, *rules, expect="AGREE_INVALID", name=None):
    return rc.Fixture(Path(f"/x/{name or rule}.typ"), expect, list(rules) or [rule])


class Artefacts(unittest.TestCase):
    def test_business_ref(self):
        # Mustang reports a Factur-X assertion under the rule its message names.
        self.assertEqual(rc.business_ref("FX-SCH-A-000123", "[BR-CO-26]-In order to ..."), "BR-CO-26")
        self.assertEqual(rc.business_ref("FX-SCH-A-000030", "Element 'ram:Name' must occur"), "FX-SCH-A-000030")
        self.assertEqual(rc.business_ref("x", "[BR-DE-23-a] Wenn ..."), "BR-DE-23-a")

    def test_schxslt(self):
        found = rc.load_schxslt(XSLT.encode(), "cen.xsl", {"BR-CL-23": "warning"})
        self.assertEqual([(a.id, a.level) for a in found],
                         [("BR-06", "error"), ("CII-SR-04", "warning"), ("BR-CL-23", "warning")])
        first = found[0]
        # The test comes from xsl:attribute, not from the negated xsl:if.
        self.assertEqual((first.context, first.test, first.validator), ("//ram:SellerTradeParty", "ram:Name", "kosit"))
        self.assertEqual(found[1].test, "count(ram:ID) <= 1")
        with self.assertRaisesRegex(rc.CoverageError, "without id"):
            rc.load_schxslt(XSLT.replace(' id="BR-06"', "").encode(), "cen.xsl", {})
        with self.assertRaisesRegex(rc.CoverageError, "no test"):
            rc.load_schxslt(XSLT.replace('<xsl:attribute name="test">ram:Name</xsl:attribute>', "").encode(),
                            "cen.xsl", {})
        with self.assertRaisesRegex(rc.CoverageError, "unknown"):
            rc.load_schxslt(XSLT.replace('flag="fatal"', 'flag="severe"', 1).encode(), "cen.xsl", {})

    def test_kosit_scenarios(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "scenarios.xml").write_text(SCENARIOS, encoding="utf-8")
            config = rc.KositConfig(tmp, pinned=False)
            self.assertEqual(config.scenario_for("en16931")[0], "EN16931 (CII)")
            name, _, locations, levels = config.scenario_for("xrechnung")
            self.assertEqual((name, locations, levels), ("EN16931 XRechnung (CII)", ["cen.xsl", "xr.xsl"],
                                                         {"BR-CL-23": "warning"}))
            # The Factur-X profiles below EN 16931 match no scenario.
            for profile in ("minimum", "basic-wl", "basic"):
                self.assertIsNone(config.scenario_for(profile))
                self.assertEqual(rc.kosit_assertions(config, profile), [])
            # The pinned configuration refuses other artefacts.
            with self.assertRaisesRegex(rc.CoverageError, "not the pinned artefact"):
                rc.KositConfig(tmp).scenarios()

    def test_kosit_assertions_of_a_scenario(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "scenarios.xml").write_text(SCENARIOS, encoding="utf-8")
            (Path(tmp) / "cen.xsl").write_text(XSLT, encoding="utf-8")
            (Path(tmp) / "xr.xsl").write_text(XSLT.replace("BR-06", "BR-DE-2"), encoding="utf-8")
            config = rc.KositConfig(tmp, pinned=False)
            self.assertEqual([a.id for a in rc.kosit_assertions(config, "en16931")], ["BR-06", "CII-SR-04", "BR-CL-23"])
            levels = {a.id: a.level for a in rc.kosit_assertions(config, "xrechnung")}
            # The customLevel of the scenario overrides the flag.
            self.assertEqual(levels, {"BR-06": "error", "BR-DE-2": "error", "CII-SR-04": "warning",
                                      "BR-CL-23": "warning"})


class Derivation(unittest.TestCase):
    def test_the_guard_settles_a_rule(self):
        compiled = [assertion("BR-06"), assertion("BR-06", dispositions=("compiled", "conservative"))]
        self.assertEqual(rc.automatic(compiled)[0], "compiled")
        self.assertEqual(rc.automatic([assertion("BR-28", dispositions=("tautology",))]),
                         ("unreachable", rc.GUARD_UNREACHABLE["tautology"]))
        # A business rule is the validator's, and an assertion without
        # disposition (not compiled at all) settles nothing.
        self.assertIsNone(rc.automatic([assertion("BR-06"), assertion("BR-06", dispositions=("business",))]))
        self.assertIsNone(rc.automatic([assertion("BR-06", dispositions=())]))

    def test_kosit_must_test_the_same(self):
        mustang = assertion("BR-18")
        self.assertEqual(rc.automatic([mustang, twin(mustang)])[0], "compiled")
        other = twin(mustang, test="normalize-space(ram:Name) != ''")
        self.assertIsNone(rc.automatic([mustang, other]))
        # Only KoSIT has the rule: nothing compiled.
        self.assertIsNone(rc.automatic([other]))
        # An explicit `compiled` needs every assertion of Mustang compiled.
        self.assertTrue(rc.guard_compiles([mustang, other]))
        self.assertFalse(rc.guard_compiles([other]))
        self.assertFalse(rc.guard_compiles([mustang, assertion("BR-18", dispositions=("business",))]))

    def test_twins_under_other_ids(self):
        # KoSIT reports CII-SR-04, Mustang the same assertion as CII-SR-004.
        mustang = assertion("CII-SR-004")
        kosit = twin(mustang, id="CII-SR-04", ref="CII-SR-04")
        inv = inventory(en16931={"CII-SR-004": [mustang], "CII-SR-04": [kosit]})
        decisions, problems = rc.classify(inv, [], {})
        self.assertEqual(problems, [])
        self.assertEqual({r: d.cls for r, d in decisions["en16931"].items()},
                         {"CII-SR-004": "compiled", "CII-SR-04": "compiled"})


class Classification(unittest.TestCase):
    def setUp(self):
        self.inv = inventory(
            en16931={
                "BR-06": [assertion("BR-06")],
                "BR-27": [assertion("BR-27", dispositions=("business",))],
                "BR-20": [assertion("BR-20"), twin(assertion("BR-20"), test="other")],
                "BR-61": [assertion("BR-61", dispositions=("business",)),
                          twin(assertion("BR-61", dispositions=("business",)))],
            },
            basic={"BR-27": [assertion("BR-27", dispositions=("business",))]},
        )

    def classes(self, entries, fixtures=None, unclassified=True):
        """({(profile, rule): class}, problems), without the unclassified
        rules the test does not look at unless `unclassified`."""
        decisions, problems = rc.classify(self.inv, entries, fixtures or {})
        if not unclassified:
            problems = [p for p in problems if not p.startswith("UNCLASSIFIED")]
        return {(p, r): d.cls for p in rc.PROFILES for r, d in decisions[p].items()}, problems

    def test_every_id_needs_a_class(self):
        classes, problems = self.classes([])
        self.assertEqual(classes[("en16931", "BR-06")], "compiled")
        self.assertEqual(classes[("en16931", "BR-27")], "unclassified")
        self.assertEqual(sorted(p.split(":")[0] for p in problems),
                         ["UNCLASSIFIED BR-20 in en16931", "UNCLASSIFIED BR-27 in basic",
                          "UNCLASSIFIED BR-27 in en16931", "UNCLASSIFIED BR-61 in en16931"])

    def test_entries(self):
        entries = [
            entry(["BR-27"], "construction", evidence=["src/zugferd/model.typ: line-model"]),
            entry(["BR-20"], "compiled", profiles=["en16931"], index=1),
            entry(["BR-61"], "open", index=2),
        ]
        classes, problems = self.classes(entries)
        self.assertEqual(problems, [])
        self.assertEqual((classes[("basic", "BR-27")], classes[("en16931", "BR-27")]), ("construction", "construction"))
        self.assertEqual((classes[("en16931", "BR-20")], classes[("en16931", "BR-61")]), ("compiled", "open"))

    def test_stale_duplicate_redundant(self):
        entries = [
            entry(["BR-27", "BR-99"], "construction", evidence=["src/nowhere.typ: x"]),
            entry(["BR-27"], "unreachable", profiles=["basic", "minimum"], index=1),
            entry(["BR-06"], "unreachable", index=2),
            entry(["BR-61"], "compiled", index=3),
            entry(["BR-20"], "open", index=4),
        ]
        _, problems = self.classes(entries)
        kinds = sorted(p.split(" (")[0].split(":")[0] for p in problems)
        self.assertEqual(kinds, [
            "DUPLICATE BR-27 in basic",
            "EVIDENCE BR-27, BR-99",
            "NOT COMPILED BR-61 in en16931",
            "REDUNDANT BR-06 in en16931",
            "STALE BR-27",  # not in MINIMUM
            "STALE BR-99",
        ])

    def test_fixtures(self):
        entries = [entry(["BR-27", "BR-61"], "fixture"), entry(["BR-06"], "fixture", index=1),
                   entry(["BR-20"], "compiled", profiles=["en16931"], index=2)]
        fixtures = {
            "BR-27": [fixture("BR-27")],
            # A fixture entry may take a rule the guard settles (BR-06).
            "BR-06": [fixture("BR-06")],
            # BR-61 has no fixture; BR-20 is classified otherwise.
            "BR-20": [fixture("BR-20")],
        }
        classes, problems = self.classes(entries, fixtures)
        self.assertEqual(classes[("en16931", "BR-06")], "fixture")
        self.assertEqual(sorted(p.split(":")[0] for p in problems), ["FIXTURE BR-20", "FIXTURE BR-61"])
        self.assertIn("classify it as fixture", [p for p in problems if p.startswith("FIXTURE BR-20")][0])

    def test_fixture_header_names_the_rule(self):
        entries = [entry(["BR-27"], "fixture")]
        _, problems = self.classes(entries, {"BR-27": [fixture("BR-27", "BR-28")]}, unclassified=False)
        self.assertEqual(len(problems), 1)
        self.assertIn("does not name BR-27", problems[0])

    def test_reported_as(self):
        entries = [entry(["BR-61"], "fixture", reported_as=["BR-27"])]
        self.assertEqual(self.classes(entries, {"BR-61": [fixture("BR-61", "BR-27")]}, unclassified=False)[1], [])
        problems = self.classes(entries, {"BR-61": [fixture("BR-61", "BR-06")]}, unclassified=False)[1]
        self.assertIn("expects none of the rules of `reported-as`", problems[0])
        problems = self.classes(entries, {"BR-61": [fixture("BR-61", "BR-61")]}, unclassified=False)[1]
        self.assertIn("remove `reported-as`", problems[0])

    def test_open_rules_may_keep_a_fixture(self):
        entries = [entry(["BR-61"], "open")]
        self.assertEqual(self.classes(entries, {"BR-61": [fixture("BR-61")]}, unclassified=False)[1], [])
        _, problems = self.classes(entries, {"BR-61": [fixture("BR-61")], "BR-98": [fixture("BR-98")]},
                                   unclassified=False)
        self.assertEqual(len(problems), 1)
        self.assertIn("a rule no validator of any profile has", problems[0])

    def test_summary_and_open_rules(self):
        decisions, _ = rc.classify(self.inv, [entry(["BR-27", "BR-61"], "open"),
                                              entry(["BR-20"], "compiled", profiles=["en16931"], index=1)], {})
        summary = rc.summarize(decisions)
        self.assertEqual(dict(summary["en16931"]), {"compiled": 2, "open": 2, "total": 4})
        self.assertEqual(rc.open_rules(decisions), {"BR-27": ["basic", "en16931"], "BR-61": ["en16931"]})


class ClassificationFile(unittest.TestCase):
    def load(self, text):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "coverage.toml"
            path.write_text(text, encoding="utf-8")
            return rc.load_toml(path)

    def test_entries(self):
        entries, ip = self.load(
            '[[rule]]\nids = ["BR-27"]\nclass = "construction"\nreason = "r"\nevidence = ["src/x.typ"]\n'
            '[[rule]]\nids = ["BR-DE-16"]\nclass = "fixture"\nreported-as = ["BR-S-02"]\nreason = "r"\n'
            '[ip."IP-TAX-01"]\nlevel = "error"\nsummary = "s"\nbasis = "b"\ntests = ["t.typ"]\n'
        )
        self.assertEqual([(e.ids, e.cls, e.reported_as) for e in entries],
                         [(["BR-27"], "construction", []), (["BR-DE-16"], "fixture", ["BR-S-02"])])
        self.assertEqual(list(ip), ["IP-TAX-01"])

    def test_refused(self):
        bad = {
            '[[rule]]\nids = []\nclass = "open"\nreason = "r"\n': "non-empty list",
            '[[rule]]\nids = ["BR-27"]\nclass = "done"\n': "`class` must be one of",
            '[[rule]]\nids = ["BR-27"]\nclass = "open"\n': "needs `reason`",
            '[[rule]]\nids = ["BR-27"]\nclass = "construction"\nreason = "r"\n': "needs `evidence`",
            '[[rule]]\nids = ["BR-27"]\nclass = "open"\nreason = "r"\nprofiles = ["full"]\n': "`profiles`",
            '[[rule]]\nids = ["BR-27"]\nclass = "open"\nreason = "r"\nreported-as = ["BR-28"]\n': "only a fixture",
            '[[rule]]\nids = ["BR-27"]\nclass = "fixture"\nreported-as = ["BR-28"]\n': "needs a `reason`",
            '[[rule]]\nids = ["BR-27"]\nclass = "open"\nreason = "r"\nwhy = "w"\n': "unknown keys",
            '[rules]\n': "unknown tables",
            '[ip."IP-X"]\nlevel = "error"\n': "looks like IP-VAT-226",
            '[ip."IP-TAX-01"]\nlevel = "error"\nsummary = "s"\nbasis = "b"\n': "needs `tests`",
            '[ip."IP-TAX-01"]\nlevel = "fatal"\nsummary = "s"\nbasis = "b"\ntests = ["t"]\n': "`level`",
        }
        for text, message in bad.items():
            with self.assertRaisesRegex(rc.CoverageError, message, msg=text):
                self.load(text)

    def test_the_committed_file(self):
        # The classification file loads, its fixture entries have fixture
        # files (their parity is run.py's part), and its IP rules are those
        # of the source.
        entries, ip = rc.load_toml()
        fixtures, problems = rc.fixture_files()
        self.assertEqual(problems, [])
        for e in entries:
            if e.cls == "fixture":
                for rule in e.ids:
                    self.assertIn(rule, fixtures, rule)
        self.assertEqual(rc.check_ip(ip, rc.ip_rules_in_source()), [])


class Fixtures(unittest.TestCase):
    def test_files(self):
        files = {
            "BR-01.typ": "// expect: AGREE_INVALID BR-01\n//\n// A fixture.\n\n#import \"_base.typ\": *\n",
            "BR-01--pass.typ": "// expect: AGREE_VALID\n",
            "BR-01--minimum.typ": "// expect: AGREE_INVALID BR-01 BR-02\n",
            "BR-05.typ": "// expect: AGREE_VALID\n// warns: BR-05\n",
            "BR-02--pass.typ": "// expect: AGREE_INVALID BR-02\n",
            "BR-03.typ": "// A fixture without header.\n",
            "BR-04.typ": "// expect: AGREE_VALID\n",
            "_base.typ": "// shared definitions\n",
        }
        with tempfile.TemporaryDirectory() as tmp:
            for name, text in files.items():
                (Path(tmp) / name).write_text(text, encoding="utf-8")
            found, problems = rc.fixture_files(tmp)
        self.assertEqual({rule: [(f.name, f.expect, f.rules) for f in fs] for rule, fs in found.items()}, {
            "BR-01": [("BR-01--minimum.typ", "AGREE_INVALID", ["BR-01", "BR-02"]),
                      ("BR-01.typ", "AGREE_INVALID", ["BR-01"])],
            "BR-05": [("BR-05.typ", "AGREE_VALID", ["BR-05"])],
        })
        self.assertEqual(len(problems), 3)
        self.assertIn("BR-02--pass.typ: a passing counterpart expects `AGREE_VALID`", problems[0])
        self.assertIn("BR-03.typ: no `// expect:` header", problems[1])
        self.assertIn("BR-04.typ: its `// expect:` header names no rule", problems[2])

    def test_names(self):
        self.assertEqual(rc.fixture_rule("x/BR-DE-23-a.typ"), ("BR-DE-23-a", False))
        self.assertEqual(rc.fixture_rule("x/BR-CO-26--minimum.typ"), ("BR-CO-26", False))
        self.assertEqual(rc.fixture_rule("x/BR-AE-02--pass.typ"), ("BR-AE-02", True))
        self.assertEqual(rc.fixture_rule("x/BR-AE-02--pass-13b.typ"), ("BR-AE-02", True))
        self.assertEqual(rc.fixture_case_id("x/BR-CO-26--minimum.typ"), "rule-BR-CO-26--minimum")

    def test_every_fixture_rule_passes_in_a_run(self):
        entries = [entry(["BR-01", "BR-02", "BR-03"], "fixture"), entry(["BR-04"], "open", index=1)]
        fixtures = {"BR-01": [fixture("BR-01"), fixture("BR-01", name="BR-01--minimum")],
                    "BR-02": [fixture("BR-02")], "BR-04": [fixture("BR-04")]}
        rows = [{"id": "rule-BR-01", "verdict": "FAIL"}, {"id": "rule-BR-01--minimum", "verdict": "PASS"},
                {"id": "rule-BR-02", "verdict": "FAIL"}, {"id": "rule-BR-04", "verdict": "FAIL"}]
        self.assertEqual(rc.fixture_results(rows, entries, fixtures), [
            "FIXTURE BR-02: no fixture of the rule passed (rule-BR-02)",
            "FIXTURE BR-03: no fixture of the rule ran",
        ])

    def test_foreign_rules(self):
        res = {"profile": "basic-wl", "diagnostics": [
            {"level": "error", "rule": "BR-O-02"}, {"level": "error", "rule": "BR-O-11"},
            {"level": "error", "rule": "IP-VAT-226"}, {"level": "warning", "rule": "BR-IC-12"},
        ]}
        levels = {"basic-wl": {"BR-O-11": {"mustang": "error"}}}
        # BASIC WL has no lines, and no BR-O-02; warnings and IP rules do not count.
        self.assertEqual(rc.foreign_rules(res, levels), ["BR-O-02"])
        self.assertEqual(rc.foreign_rules(dict(res, profile=None), levels), [])


class OwnRules(unittest.TestCase):
    def test_source(self):
        found = rc.ip_rules_in_source()
        self.assertIn("IP-VAT-226", found)
        self.assertIn(rc.REPO / "src" / "zugferd" / "validate.typ", found["IP-VAT-226"])

    def test_entries(self):
        source = {"IP-TAX-01": [rc.REPO / "src/zugferd/validate.typ"], "IP-GUARD-02": [rc.REPO / "src/x.typ"],
                  "IP-NEW-01": [rc.REPO / "src/zugferd/validate.typ"]}

        def ip(*tests):
            return {"level": "error", "summary": "s", "basis": "b", "tests": list(tests)}

        entries = {
            "IP-TAX-01": ip("tests/zugferd/vat-categories/test.typ"),
            # The rules of the guard are tested by their kind of finding.
            "IP-GUARD-02": ip("tests/zugferd/guard/test.typ"),
            "IP-OLD-01": ip("tests/zugferd/vat-categories/test.typ"),
        }
        problems = rc.check_ip(entries, source)
        self.assertEqual([p.split(":")[0] for p in problems], ["IP IP-NEW-01", "IP IP-OLD-01", "IP IP-OLD-01"])
        self.assertIn("not listed in rule-coverage.toml", problems[0])
        self.assertIn("stale", problems[1])
        problems = rc.check_ip({"IP-TAX-01": ip("tests/nowhere.typ", "typst.toml")}, {"IP-TAX-01": source["IP-TAX-01"]})
        self.assertEqual(problems, ["IP IP-TAX-01: its test tests/nowhere.typ does not exist",
                                    "IP IP-TAX-01: none of its tests names the rule"])


class Documentation(unittest.TestCase):
    def test_table(self):
        counts = {p: collections.Counter({"total": 10, "compiled": 8, "fixture": 1, "open": 1}) for p in rc.PROFILES}
        table = rc.markdown_table(counts).splitlines()
        self.assertEqual(len(table), 2 + len(rc.PROFILES))
        self.assertTrue(table[1].startswith("| :---"))
        self.assertTrue(table[2].startswith("| MINIMUM "))
        self.assertTrue(all(len(line) == len(table[0]) for line in table))

    def test_check_and_update(self):
        inv = inventory(en16931={"BR-27": [assertion("BR-27", dispositions=("business",))]})
        decisions, _ = rc.classify(inv, [entry(["BR-27"], "open")], {})
        summary = rc.summarize(decisions)
        block = rc.docs_block(decisions, summary)
        self.assertTrue(block.endswith("Open: `BR-27` (EN 16931)."))
        with tempfile.TemporaryDirectory() as tmp:
            docs = Path(tmp) / "docs.md"
            docs.write_text("# Docs\n\nText.\n", encoding="utf-8")
            with unittest.mock.patch.object(rc, "REPO", Path(tmp)):
                self.assertIn("markers of the rule-coverage table are missing", rc.check_docs(decisions, summary, docs)[0])
                docs.write_text(f"# Docs\n\n{rc.DOCS_BEGIN}\n{rc.DOCS_END}\n\nMore.\n", encoding="utf-8")
                self.assertIn("differs from the classification", rc.check_docs(decisions, summary, docs)[0])
                rc.update_docs(decisions, summary, docs)
                self.assertEqual(rc.check_docs(decisions, summary, docs), [])
                text = docs.read_text(encoding="utf-8")
                self.assertTrue(text.startswith("# Docs\n\n") and text.endswith(f"{rc.DOCS_END}\n\nMore.\n"))
                self.assertEqual(rc.docs_table(text), block)
                # Without an open rule, the documentation says so.
                decisions, _ = rc.classify(inv, [entry(["BR-27"], "unreachable")], {})
                self.assertTrue(rc.docs_block(decisions, rc.summarize(decisions)).endswith("Open: none."))


JAR = os.environ.get("MUSTANG_JAR")
KOSIT = os.environ.get("KOSIT_CONFIG")


@unittest.skipUnless(JAR and Path(JAR).is_file() and KOSIT and Path(KOSIT).is_dir(),
                     "needs the Mustang CLI jar 2.14.0 ($MUSTANG_JAR) and KoSIT's configuration ($KOSIT_CONFIG)")
class PinnedArtefacts(unittest.TestCase):
    """The inventory of the pinned artefacts, as Mustang and KoSIT select them."""

    @classmethod
    def setUpClass(cls):
        cls.levels = rc.rule_levels(JAR, KOSIT)

    def test_selection(self):
        levels = self.levels
        # MINIMUM: the Factur-X Schematron of the profile only, in Mustang.
        self.assertEqual(levels["minimum"]["BR-CO-26"], {"mustang": "error"})
        self.assertNotIn("BR-S-02", levels["minimum"])
        # BASIC WL has no lines, so no rules of lines.
        self.assertNotIn("BR-O-02", levels["basic-wl"])
        self.assertIn("BR-O-03", levels["basic-wl"])
        # KoSIT has scenarios for EN 16931 and XRechnung only.
        self.assertEqual(levels["basic"]["BR-S-02"], {"mustang": "error"})
        self.assertEqual(levels["en16931"]["BR-S-02"], {"mustang": "error", "kosit": "error"})
        # Rules only the newer CEN Schematron of KoSIT has, or only the older one of Mustang.
        self.assertEqual(levels["en16931"]["CII-SR-470"], {"kosit": "error"})
        self.assertEqual(levels["en16931"]["BR-CO-25"], {"mustang": "error"})
        # Mustang applies the XRechnung Schematron to XRechnung only; KoSIT at
        # the levels of the scenario (customLevel) and of the flags.
        self.assertNotIn("BR-DE-15", levels["en16931"])
        self.assertEqual(levels["xrechnung"]["BR-DE-15"], {"mustang": "error", "kosit": "error"})
        self.assertEqual(levels["xrechnung"]["BR-CL-23"], {"mustang": "error", "kosit": "warning"})
        self.assertEqual(levels["xrechnung"]["BR-DE-TMP-32"], {"kosit": "information"})
        self.assertEqual(levels["xrechnung"]["BR-DE-17"], {"mustang": "error", "kosit": "warning"})

    def test_twins(self):
        # KoSIT reports the assertion id, Mustang the id its message names.
        self.assertEqual(self.levels["en16931"]["CII-SR-04"], {"kosit": "warning"})
        self.assertEqual(self.levels["en16931"]["CII-SR-004"], {"mustang": "error"})


if __name__ == "__main__":
    unittest.main()
