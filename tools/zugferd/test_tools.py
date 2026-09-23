"""Unit tests of the conformance tools themselves (no Typst, no Java).

  python3 -m unittest discover -s tools -p 'test_*.py'

The proof layer is only as good as its classification, report parsing,
oracles and generator constraints, so these parts are tested on their own.
"""

import itertools
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "corpus"))

import common  # noqa: E402
import gen  # noqa: E402
import oracles  # noqa: E402
import run  # noqa: E402

REPORT = """<validation><xml><messages>
<error type="24" location="/a" criterion="x">[BR-AG-05]-In an Invoice line ... [ID BR-AG-05] from x)</error>
<error type="4" location="/b">Element 'ram:Name' must occur exactly 1 times. [ID FX-SCH-A-000030] from y)</error>
<error type="27" location="/c">Buyer electronic address MUST be provided [ID PEPPOL-EN16931-R010] from z)</error>
<notice type="27" location="/d">[BR-DE-15] Das Element "Buyer reference" (BT-10) muss übermittelt werden. [ID BR-DE-15]</notice>
<error type="18">schema validation fails: cvc-complex-type.2.4.b</error>
<warning type="27">[BR-DE-21] soll [ID BR-DE-21]</warning>
</messages><summary status="invalid"/></xml><summary status="invalid"/></validation>"""


class MustangReport(unittest.TestCase):
    def test_rules_of_every_error(self):
        result = common.parse_mustang_report(REPORT)
        self.assertEqual(result["status"], "invalid")
        # XRechnung errors come with type 27 and must be kept; notices are not errors.
        self.assertEqual(set(result["errors"]), {"BR-AG-05", "FX-SCH-A-000030", "PEPPOL-EN16931-R010", "XSD"})
        self.assertEqual(len(result["warnings"]), 1)

    def test_valid_and_crash(self):
        self.assertEqual(common.parse_mustang_report('<summary status="valid"/>')["errors"], {})
        crashed = common.parse_mustang_report("<crash>java.lang.OutOfMemoryError</crash>")
        self.assertEqual(crashed["status"], "crash")
        self.assertIn("MUSTANG-CRASH", crashed["errors"])


def result(ours=(), official=(), valid=None, crash=None, source=None):
    res = {"xml_path": "x.xml"}
    if crash:
        return {"crash": crash}
    res["diagnostics"] = [
        {"level": "error", "rule": rule, **({"source": source} if source else {})} for rule in ours
    ] + [{"level": "warning", "rule": "BR-X"}]
    res["official"] = {"valid": not official if valid is None else valid, "rules": sorted(official)}
    return res


class Classification(unittest.TestCase):
    def test_classes(self):
        self.assertEqual(run.classify(result()), "AGREE_VALID")
        self.assertEqual(run.classify(result(official=["BR-S-08"])), "FALSE_NEGATIVE")
        self.assertEqual(run.classify(result(ours=["BR-S-02"])), "FALSE_POSITIVE")
        self.assertEqual(run.classify(result(ours=["IP-VAT-226"])), "STRICTER")
        self.assertEqual(run.classify(result(ours=["BR-S-02"], official=["BR-S-02", "XSD"])), "AGREE_INVALID")
        self.assertEqual(run.classify(result(ours=["BR-CL-10"], official=["BR-CL-26"])), "WRONG_RULE_ID")
        self.assertEqual(run.classify(result(ours=["G2-01"], official=["XSD"], source="guard")), "GUARD_ONLY")
        self.assertEqual(run.classify(result(crash="error: boom")), "CRASH")
        self.assertEqual(run.classify({"diagnostics": []}), "NO_XML")

    def test_rule_ids_are_only_compared_when_both_name_rules(self):
        # Structural official ids (XSD, FX-SCH-*) and own rules (IP-*) cannot match.
        self.assertEqual(run.classify(result(ours=["BR-07"], official=["XSD", "FX-SCH-A-000030"])), "AGREE_INVALID")
        self.assertEqual(run.classify(result(ours=["IP-DEC-01"], official=["BR-DEC-09"])), "AGREE_INVALID")

    def test_deliberate_stops_are_input_errors(self):
        def cls(crash, **case):
            base = {"id": "x", "population": "random", "expect": "AGREE", "file": "x.typ"}
            return run.make_row(dict(base, **case), {"crash": crash}, None)["cls"]

        panic = 'error: panicked with: "The modifier `Versand` cannot be split"'
        self.assertEqual(cls(panic), "INPUT_ERROR")
        self.assertEqual(cls("error: assertion failed: the IBAN is not valid"), "INPUT_ERROR")
        self.assertEqual(cls("error: string index 2 is not a character boundary"), "CRASH")
        # Outside the random population only the expected message counts.
        self.assertEqual(cls(panic, population="legal", expect="AGREE_VALID"), "CRASH")
        self.assertEqual(cls(panic, expect="INPUT_ERROR", expect_error="cannot be split"), "INPUT_ERROR")
        self.assertEqual(cls(panic, expect="INPUT_ERROR", expect_error="post-code"), "CRASH")

    def test_expectations(self):
        case = {"expect": "REJECTED", "expect_rules": ["IP-DOC-01"]}
        self.assertEqual(run.expectation_met(case, "STRICTER", ["IP-DOC-01"]), (True, []))
        self.assertEqual(run.expectation_met(case, "AGREE_VALID", []), (False, ["IP-DOC-01"]))
        self.assertTrue(run.expectation_met({"expect": "AGREE"}, "AGREE_INVALID", ["BR-02"])[0])
        self.assertTrue(run.expectation_met({"expect": "AGREE"}, "STRICTER", ["IP-VAT-226"])[0])
        self.assertFalse(run.expectation_met({"expect": "AGREE"}, "FALSE_POSITIVE", ["BR-IC-02"])[0])
        self.assertFalse(run.expectation_met({"expect": "AGREE"}, "FALSE_NEGATIVE", [])[0])


def row(cid, cls="AGREE_VALID", expect="AGREE_VALID", oracle=(), missing=(), ours=(), official=()):
    return {
        "id": cid,
        "cls": cls,
        "expect": expect,
        "class_ok": cls == expect,
        "missing_rules": list(missing),
        "ours": list(ours),
        "official": list(official),
        "oracle": list(oracle),
    }


class KnownIssues(unittest.TestCase):
    def test_signature(self):
        r = row("rg-a", cls="FALSE_NEGATIVE", missing=["BR-AG-05"], official=["BR-AG-05"])
        self.assertEqual(run.signature(r), "FALSE_NEGATIVE missing=BR-AG-05 ours=- official=BR-AG-05")
        r = row("pw001", oracle=["O-BG14: x", "O-BT1: y", "O-BG14: z"])
        self.assertEqual(run.signature(r), "AGREE_VALID oracle=O-BG14,O-BT1")

    def test_known_new_and_xpass(self):
        known = [
            {"finding": "f1", "signatures": ["AGREE_VALID oracle=O-BG14"], "cases": ["pw*"]},
            {"finding": "f2", "signatures": ["AGREE_VALID oracle=O-BT1", "AGREE_VALID oracle=O-BT5"]},
            {"finding": "f3", "signatures": ["CRASH ours=- official=-"], "cases": ["ad-*"]},
        ]
        rows = [
            row("pw001", oracle=["O-BG14: x"]),  # known (f1)
            row("rl001", oracle=["O-BG14: x"]),  # f1 does not cover rl*: new
            row("pw002", oracle=["O-BT1: x"]),  # known (f2)
            row("pw003"),  # passes
        ]
        failures, hits, xpass = run.triage(rows, known)
        self.assertEqual([r["id"] for r in failures], ["rl001"])
        self.assertEqual(sorted((e["finding"], ids[0]) for e, _, ids in hits), [("f1", "pw001"), ("f2", "pw002")])
        # f2's second signature did not occur; f3 covers no case of this run.
        self.assertEqual([(e["finding"], s) for e, s in xpass], [("f2", "AGREE_VALID oracle=O-BT5")])
        # --strict: every failure is new, nothing is xpass.
        failures, hits, xpass = run.triage(rows, known, strict=True)
        self.assertEqual(len(failures), 3)
        self.assertEqual((hits, xpass), ([], []))

    def test_known_issues_file(self):
        entries = run.load_known(HERE / "known-issues.toml")
        self.assertTrue(entries)
        for entry in entries:
            self.assertTrue(entry["finding"])
            self.assertTrue(entry["signatures"])


class Headers(unittest.TestCase):
    def test_parse(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "case.typ"
            file.write_text(
                "// expect: AGREE_INVALID BR-AG-05 BR-S-08\n// finding: f\n"
                '// facts: {"currency": "PLN"}\n// facts: {"units": ["MTK"]}\n\n#import "x"\n',
                encoding="utf-8",
            )
            header = run.parse_header(file)
            self.assertEqual(header["expect"], "AGREE_INVALID")
            self.assertEqual(header["expect_rules"], ["BR-AG-05", "BR-S-08"])
            self.assertEqual(header["facts"], {"currency": "PLN", "units": ["MTK"]})
            file.write_text("// expect: SOMETHING\n", encoding="utf-8")
            with self.assertRaises(common.ToolError):
                run.parse_header(file)

    def test_regression_cases(self):
        cases = run.load_cases([HERE / "corpus" / "regression"])
        self.assertTrue(cases)
        for case in cases:
            self.assertTrue(case["finding"], case["id"])


# A trimmed CII document (not schema-complete): what the oracles read.
CII = """<?xml version="1.0" encoding="UTF-8"?>
<rsm:CrossIndustryInvoice
  xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"
  xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"
  xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">
  <rsm:ExchangedDocument><ram:ID>RE-1</ram:ID><ram:TypeCode>380</ram:TypeCode></rsm:ExchangedDocument>
  <rsm:SupplyChainTradeTransaction>
    <ram:IncludedSupplyChainTradeLineItem>
      <ram:SpecifiedTradeProduct><ram:Name>Paket (19% S)</ram:Name></ram:SpecifiedTradeProduct>
      <ram:SpecifiedLineTradeDelivery><ram:BilledQuantity unitCode="HUR">2</ram:BilledQuantity></ram:SpecifiedLineTradeDelivery>
      <ram:SpecifiedLineTradeSettlement>
        <ram:ApplicableTradeTax><ram:CategoryCode>S</ram:CategoryCode><ram:RateApplicablePercent>19.00</ram:RateApplicablePercent></ram:ApplicableTradeTax>
      </ram:SpecifiedLineTradeSettlement>
    </ram:IncludedSupplyChainTradeLineItem>
    <ram:IncludedSupplyChainTradeLineItem>
      <ram:SpecifiedTradeProduct><ram:Name>Buch</ram:Name></ram:SpecifiedTradeProduct>
      <ram:SpecifiedLineTradeDelivery><ram:BilledQuantity unitCode="C62">1</ram:BilledQuantity></ram:SpecifiedLineTradeDelivery>
      <ram:SpecifiedLineTradeSettlement>
        <ram:ApplicableTradeTax><ram:CategoryCode>E</ram:CategoryCode><ram:RateApplicablePercent>0</ram:RateApplicablePercent></ram:ApplicableTradeTax>
      </ram:SpecifiedLineTradeSettlement>
    </ram:IncludedSupplyChainTradeLineItem>
    <ram:ApplicableHeaderTradeAgreement>
      <ram:SellerTradeParty><ram:Name>Muster GmbH</ram:Name></ram:SellerTradeParty>
      <ram:BuyerTradeParty><ram:Name>Kunde AG</ram:Name></ram:BuyerTradeParty>
    </ram:ApplicableHeaderTradeAgreement>
    <ram:ApplicableHeaderTradeSettlement>
      <ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>
      <ram:ApplicableTradeTax><ram:CategoryCode>S</ram:CategoryCode><ram:RateApplicablePercent>19.00</ram:RateApplicablePercent></ram:ApplicableTradeTax>
      <ram:ApplicableTradeTax><ram:ExemptionReason>Steuerfrei nach § 4 Nr. 21 UStG</ram:ExemptionReason><ram:CategoryCode>E</ram:CategoryCode><ram:RateApplicablePercent>0.00</ram:RateApplicablePercent></ram:ApplicableTradeTax>
      <ram:SpecifiedTradeAllowanceCharge>
        <ram:ChargeIndicator><udt:Indicator>false</udt:Indicator></ram:ChargeIndicator>
        <ram:CalculationPercent>5.00</ram:CalculationPercent><ram:BasisAmount>100.00</ram:BasisAmount>
        <ram:ActualAmount>5.00</ram:ActualAmount><ram:Reason>Treuerabatt</ram:Reason>
        <ram:CategoryTradeTax><ram:CategoryCode>S</ram:CategoryCode><ram:RateApplicablePercent>19.00</ram:RateApplicablePercent></ram:CategoryTradeTax>
      </ram:SpecifiedTradeAllowanceCharge>
      <ram:SpecifiedTradeAllowanceCharge>
        <ram:ChargeIndicator><udt:Indicator>true</udt:Indicator></ram:ChargeIndicator>
        <ram:ActualAmount>23.53</ram:ActualAmount><ram:Reason>Versand</ram:Reason>
        <ram:CategoryTradeTax><ram:CategoryCode>S</ram:CategoryCode><ram:RateApplicablePercent>19.00</ram:RateApplicablePercent></ram:CategoryTradeTax>
      </ram:SpecifiedTradeAllowanceCharge>
      <ram:SpecifiedTradeAllowanceCharge>
        <ram:ChargeIndicator><udt:Indicator>true</udt:Indicator></ram:ChargeIndicator>
        <ram:ActualAmount>1.47</ram:ActualAmount><ram:Reason>Versand</ram:Reason>
        <ram:CategoryTradeTax><ram:CategoryCode>E</ram:CategoryCode><ram:RateApplicablePercent>0</ram:RateApplicablePercent></ram:CategoryTradeTax>
      </ram:SpecifiedTradeAllowanceCharge>
      <ram:SpecifiedTradeSettlementHeaderMonetarySummation>
        <ram:GrandTotalAmount>1234.50</ram:GrandTotalAmount><ram:DuePayableAmount>1234.50</ram:DuePayableAmount>
      </ram:SpecifiedTradeSettlementHeaderMonetarySummation>
    </ram:ApplicableHeaderTradeSettlement>
  </rsm:SupplyChainTradeTransaction>
</rsm:CrossIndustryInvoice>
"""


class Oracles(unittest.TestCase):
    def setUp(self):
        self.doc = common.parse_xml(CII.encode("utf-8"))

    def test_facts_that_hold(self):
        facts = {
            "invoice_nr": "RE-1",
            "type_code": "380",
            "currency": "EUR",
            "seller_name": "Muster GmbH",
            "buyer_name": "Kunde AG",
            "breakdown": [["S", "19"], ["E", "0"]],
            "grounds": [["E", "Steuerfrei nach § 4 Nr. 21 UStG"]],
            "units": ["HUR", "C62"],
            "line_names": ["Paket", "Buch"],
            "doc_modifiers": [
                {"name": "Treuerabatt", "charge": False, "percent": "5"},
                {"name": "Versand", "charge": True, "amount": "25.00"},
            ],
        }
        self.assertEqual(oracles.check(facts, self.doc, None, "en16931"), [])

    def test_wrong_facts_are_reported(self):
        facts = {
            "currency": "PLN",
            "units": ["C62", "C62"],
            "breakdown": [["S", "19"]],
            "doc_modifiers": [{"name": "Versand", "charge": True, "amount": "20.00"}],
            "grounds": [["E", "Steuerfrei nach § 4 Nr. 14 UStG"]],
        }
        problems = oracles.check(facts, self.doc, None, "en16931")
        self.assertEqual(sorted(p.split(":")[0] for p in problems), ["O-BG20/21", "O-BG23", "O-BT120", "O-BT130", "O-BT5"])
        # MINIMUM carries no breakdown, lines or allowances: nothing to compare.
        self.assertEqual(sorted(p.split(":")[0] for p in oracles.check(facts, self.doc, None, "minimum")), ["O-BT5"])

    def test_printed_amounts_and_reasons(self):
        printed = "Gesamtbetrag: 1.234,50 €\nSteuerfrei nach § 4 Nr. 21\nUStG"
        self.assertEqual(oracles.check({}, self.doc, printed, "en16931"), [])
        self.assertEqual(oracles.check({"number_format": [".", "'"]}, self.doc, "CHF 1'234.50 Steuerfrei nach § 4 Nr. 21 UStG", "en16931"), [])
        problems = oracles.check({}, self.doc, "nothing printed", "en16931")
        self.assertEqual(sorted(p.split(":")[0] for p in problems), ["O-PDF-BT112", "O-PDF-BT115", "O-PDF-BT120"])

    def test_helpers(self):
        self.assertEqual(oracles.format_amount("1234567.5", (",", ".")), "1.234.567,50")
        self.assertEqual(oracles.format_amount("-5", (".", "'")), "5.00")
        self.assertEqual(oracles._split_bracket("Paket (5,5% S)"), ("Paket", common.dec("5.5")))
        self.assertTrue(oracles._names_match(["Paket (19% S)", "Paket (7% S)", "B"], [common.dec(19), common.dec(7), None], ["Paket", "B"]))
        self.assertFalse(oracles._names_match(["Paket (6% S)"], [common.dec("5.5")], ["Paket"]))


class Generator(unittest.TestCase):
    def test_pairwise_covers_every_allowed_pair(self):
        rows, unreachable = gen.pairwise(seed=1)
        self.assertEqual(unreachable, [])
        names = list(gen.DIMS)
        seen = {(a, r[a], b, r[b]) for r in rows for a, b in itertools.combinations(names, 2)}
        for a, b in itertools.combinations(names, 2):
            for va in gen.DIMS[a]:
                for vb in gen.DIMS[b]:
                    if gen.allowed({a: va, b: vb}):
                        self.assertIn((a, va, b, vb), seen)
        self.assertTrue(all(gen.allowed(r) for r in rows))

    def test_legal_constraints(self):
        base = dict(gen.SIMPLE)
        self.assertTrue(gen.allowed(base))
        self.assertFalse(gen.allowed(dict(base, tax="k", route="de-de")))  # K needs two member states
        self.assertFalse(gen.allowed(dict(base, tax="g", route="de-fr")))  # G only outside the EU
        self.assertFalse(gen.allowed(dict(base, tax="ae", ids="taxnr")))  # AE needs the seller VAT ID
        self.assertFalse(gen.allowed(dict(base, profile="xrechnung", payment="nobank+days")))  # BR-DE-1
        self.assertTrue(gen.allowed(dict(base, profile="auto", payment="nobank+days")))  # falls back

    def test_resolved_profile(self):
        self.assertEqual(gen.resolved_profile(dict(gen.SIMPLE, profile="en16931", route="de-de")), "en16931")
        self.assertEqual(gen.resolved_profile(dict(gen.SIMPLE, profile="auto", route="de-de")), "xrechnung")
        self.assertEqual(gen.resolved_profile(dict(gen.SIMPLE, profile="auto", route="de-fr")), "en16931")


if __name__ == "__main__":
    unittest.main()
