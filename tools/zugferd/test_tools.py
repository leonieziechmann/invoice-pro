"""Unit tests of the conformance tools themselves (no Typst, no Java).

  python3 -m unittest discover -s tools/zugferd -p 'test_*.py'

The proof layer is only as good as its classification, the parsing of the
reports of Mustang and KoSIT, the combined official verdict, oracles and
generator constraints, so these parts are tested on their own.
"""

import itertools
import sys
import tempfile
import unittest
import unittest.mock
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


def varl(body, assessment="reject"):
    """A trimmed KoSIT report (VARL), as the validator writes it for a file."""
    return (
        '<?xml version="1.0" encoding="UTF-8"?><rep:report xmlns:rep="http://www.xoev.de/de/validator/varl/1"'
        ' xmlns:s="http://www.xoev.de/de/validator/framework/1/scenarios" varlVersion="1.0.0">'
        "<rep:engine><rep:name>KoSIT Validator 1.6.3</rep:name></rep:engine>" + body
        + f'<rep:assessment><rep:{assessment}><rep:explanation><html xmlns="http://www.w3.org/1999/xhtml">'
        f"<body><p>Prüfbericht</p></body></html></rep:explanation></rep:{assessment}></rep:assessment></rep:report>"
    )


def scenario(name, *steps):
    return (f"<rep:scenarioMatched><s:scenario><s:name>{name}</s:name></s:scenario>" + "".join(steps)
            + '<rep:validationStepResult id="val-xml" valid="true"/></rep:scenarioMatched>')


def step(step_id, *messages):
    body = "".join(
        f'<rep:message id="{step_id}.{n}" level="{level}" code="{code}">{text}</rep:message>'
        for n, (level, code, text) in enumerate(messages, 1)
    )
    return f'<rep:validationStepResult id="{step_id}" valid="{"false" if body else "true"}">{body}</rep:validationStepResult>'


class KositReport(unittest.TestCase):
    def test_rejected_xrechnung(self):
        report = varl(scenario(
            "EN16931 XRechnung (CII)",
            step("val-xsd"),
            step("val-sch.1", ("warning", "BR-DE-27", "[BR-DE-27] Telefonnummer ...")),
            step("val-sch.2", ("error", "BR-DE-15", "[BR-DE-15] Das Element \"Buyer reference\" (BT-10) muss "
                                                      "übermittelt werden."),
                 ("information", "BR-CL-10", "[BR-CL-10] ...")),
        ))
        result = common.parse_kosit_report(report)
        self.assertEqual((result["status"], result["scenario"]), ("reject", "EN16931 XRechnung (CII)"))
        self.assertEqual(set(result["errors"]), {"BR-DE-15"})
        self.assertIn("muss übermittelt", result["errors"]["BR-DE-15"])
        # Warnings are kept apart, information is left out.
        self.assertEqual(set(result["warnings"]), {"BR-DE-27"})

    def test_accepted_with_warnings(self):
        report = varl(scenario("EN16931 (CII)", step("val-xsd"), step("val-sch.1", ("warning", "BR-DE-28", "x"))),
                      assessment="accept")
        result = common.parse_kosit_report(report)
        self.assertEqual((result["status"], result["errors"], set(result["warnings"])), ("accept", {}, {"BR-DE-28"}))

    def test_schema_errors_are_xsd(self):
        report = varl(scenario("EN16931 (CII)", step("val-xsd", ("error", "cvc-complex-type.2.4.a", "Invalid content"))))
        self.assertEqual(set(common.parse_kosit_report(report)["errors"]), {"XSD"})

    def test_no_scenario_and_unreadable_documents(self):
        # MINIMUM, BASIC WL and BASIC match no scenario of the configuration.
        minimum = varl('<rep:noScenarioMatched><rep:validationStepResult id="val-xml" valid="true"/></rep:noScenarioMatched>')
        self.assertEqual(common.parse_kosit_report(minimum)["status"], "no-scenario")
        # A file that is not well-formed matches none either, and is rejected.
        broken = varl('<rep:noScenarioMatched><rep:validationStepResult id="val-xml" valid="false">'
                      '<rep:message id="val-xml.1" level="error" code="generic-error">SXXP0003 ...</rep:message>'
                      "</rep:validationStepResult></rep:noScenarioMatched>")
        result = common.parse_kosit_report(broken)
        self.assertEqual((result["status"], set(result["errors"])), ("reject", {"XML"}))

    def test_broken_reports_are_errors(self):
        self.assertEqual(set(common.parse_kosit_report("<rep:report")["errors"]), {"KOSIT-CRASH"})
        silent = varl(scenario("EN16931 (CII)", step("val-xsd")))  # rejected without a message
        self.assertEqual(set(common.parse_kosit_report(silent)["errors"]), {"KOSIT-REJECT"})

    def test_setup_says_what_is_missing(self):
        with unittest.mock.patch.dict("os.environ", {"KOSIT_JAR": "", "KOSIT_CONFIG": ""}):
            with self.assertRaisesRegex(common.ToolError, "KOSIT_JAR and KOSIT_CONFIG are not set"):
                common.kosit_setup()
        with tempfile.TemporaryDirectory() as tmp:
            jar = Path(tmp) / "validator.jar"
            jar.write_bytes(b"")
            with unittest.mock.patch.dict("os.environ", {"KOSIT_JAR": str(jar), "KOSIT_CONFIG": tmp}):
                with self.assertRaisesRegex(common.ToolError, "no scenarios.xml"):
                    common.kosit_setup()
                (Path(tmp) / "scenarios.xml").write_text("<scenarios/>", encoding="utf-8")
                self.assertEqual(common.kosit_setup(), (jar.resolve(), Path(tmp).resolve()))

    def test_skipping_a_validator_is_refused_in_ci(self):
        with unittest.mock.patch.dict("os.environ", {"CI": "true"}):
            with unittest.mock.patch("sys.stderr"):
                self.assertEqual(run.main(["--no-kosit"]), 2)
                self.assertEqual(run.main(["--no-mustang"]), 2)


def mustang_report(*errors, warnings=()):
    return {"status": "invalid" if errors else "valid", "errors": {e: e for e in errors},
            "warnings": [f"{w}: text" for w in warnings]}


def kosit_report(*errors, warnings=(), status=None):
    return {"status": status or ("reject" if errors else "accept"), "scenario": "EN16931 XRechnung (CII)",
            "errors": {e: e for e in errors}, "warnings": {w: w for w in warnings}}


def collected(mustang=None, kosit=None, ours=(), xsd_errors=()):
    """A compiled case after the official validation (Checker.collect)."""
    res = {"xml_path": "x.xml", "xsd_errors": list(xsd_errors), "profile": "xrechnung",
           "diagnostics": [{"level": "error", "rule": rule, "field": "f", "message": "m", "hint": "h"} for rule in ours]}
    if mustang is not None:
        res["mustang"] = mustang
    if kosit is not None:
        res["kosit"] = kosit
    run.Checker.collect(res)
    return res


class OfficialVerdict(unittest.TestCase):
    def test_every_validator_must_accept(self):
        self.assertTrue(collected(mustang_report(), kosit_report())["official"]["valid"])
        # Only KoSIT rejects: officially invalid, and silent XML is a FALSE_NEGATIVE.
        res = collected(mustang_report(), kosit_report("CII-SR-467"))
        self.assertEqual((res["official"]["valid"], res["official"]["rules"]), (False, ["CII-SR-467"]))
        self.assertEqual(run.classify(res), "FALSE_NEGATIVE")
        self.assertFalse(collected(mustang_report(), kosit_report(), xsd_errors=["line 1: x"])["official"]["valid"])
        # Profiles without KoSIT scenario: Mustang and the XSD decide.
        self.assertTrue(collected(mustang_report())["official"]["valid"])

    def test_disagreements(self):
        # BR-DE-27: Mustang rejects, KoSIT only warns. invoice-pro reports an
        # error: AGREE_INVALID overall, stricter than KoSIT on its own.
        res = collected(mustang_report("BR-DE-27"), kosit_report(warnings=["BR-DE-27"]), ours=["BR-DE-27"])
        self.assertEqual(run.classify(res), "AGREE_INVALID")
        self.assertEqual(res["official"]["disagreement"],
                         {"rejected_by": "mustang", "rules": ["BR-DE-27"], "other": {"BR-DE-27": "warning"}})
        row = run.make_row({"id": "rg-x", "population": "regression", "expect": "AGREE_INVALID", "file": "x.typ"}, res, None)
        self.assertEqual({name: view["cls"] for name, view in row["validators"].items()},
                         {"mustang": "AGREE_INVALID", "kosit": "STRICTER"})
        # KoSIT rejects a rule Mustang does not know at all.
        res = collected(mustang_report(), kosit_report("CII-SR-470"), ours=["BR-61"])
        self.assertEqual(res["official"]["disagreement"]["other"], {"CII-SR-470": "nothing"})
        # Both reject, with other rules: no disagreement of the verdict.
        self.assertIsNone(collected(mustang_report("BR-CO-25", "BR-S-08"), kosit_report("BR-S-08"))["official"]["disagreement"])

    def test_undocumented_disagreements_fail(self):
        differences = {"BR-DE-27": {"rejected-by": "mustang", "other": ["warning"], "reason": "r"}}

        def case_row(cid, mustang, kosit, ours=()):
            case = {"id": cid, "population": "regression", "expect": "AGREE_INVALID", "file": "x.typ"}
            return run.make_row(case, collected(mustang, kosit, ours=ours), None)

        documented = case_row("rg-a", mustang_report("BR-DE-27"), kosit_report(warnings=["BR-DE-27"]), ["BR-DE-27"])
        unknown = case_row("rg-b", mustang_report(), kosit_report("CII-SR-467"), ["IP-PAY-03"])
        # BR-DE-27 is documented as rejected by Mustang, not by KoSIT.
        reversed_ = case_row("rg-c", mustang_report(), kosit_report("BR-DE-27"), ["BR-DE-27"])
        known = [{"finding": "f", "signatures": [run.signature(dict(unknown, disagreement=dict(unknown["disagreement"],
                                                                                            undocumented=["CII-SR-467"])))]}]
        failures, hits, xpass, stale = run.triage([documented, unknown, reversed_], known, differences=differences)
        self.assertEqual([r["id"] for r in failures], ["rg-b", "rg-c"])
        self.assertEqual(failures[0]["signature"], "AGREE_INVALID OFFICIAL_DISAGREE only-kosit=CII-SR-467")
        self.assertEqual(hits, [])  # known-issues.toml cannot excuse it
        self.assertEqual(stale, [])
        text, ok = run.report([documented, unknown, reversed_], failures, hits, xpass,
                              {"total_s": 0, "compile_s": 0, "mustang_wait_s": 0, "jobs": 1}, True, stale, True, differences)
        self.assertFalse(ok)
        self.assertIn("only Mustang rejects BR-DE-27 (KoSIT: warning); invoice-pro reports an error (stricter than KoSIT)", text)
        self.assertIn("document it in validator-differences.toml", text)

    def test_documented_differences_must_occur(self):
        differences = {
            "BR-DE-27": {"rejected-by": "mustang", "other": ["warning"], "reason": "r"},
            "BR-CO-25": {"rejected-by": "mustang", "other": ["nothing"], "reason": "r"},
        }
        case = {"id": "rg-a", "population": "regression", "expect": "AGREE_INVALID", "file": "x.typ"}
        rows = [run.make_row(case, collected(mustang_report("BR-DE-27"), kosit_report(warnings=["BR-DE-27"]),
                                             ours=["BR-DE-27"]), None)]
        self.assertEqual(run.triage(rows, [], differences=differences)[3], ["BR-CO-25"])
        # Not on a subset (--only), nor without KoSIT.
        self.assertEqual(run.triage(rows, [], check_xpass=False, differences=differences)[3], [])
        rows = [run.make_row(case, collected(mustang_report("BR-DE-27"), ours=["BR-DE-27"]), None)]
        self.assertEqual(run.triage(rows, [], differences=differences)[3], [])

    def test_differences_file(self):
        differences = run.load_differences(HERE / "validator-differences.toml")
        for rule, entry in differences.items():
            self.assertIn(entry["rejected-by"], run.VALIDATORS, rule)
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "differences.toml"
            bad.write_text('[BR-DE-27]\nrejected-by = "kosit"\nother = "error"\nreason = "r"\n', encoding="utf-8")
            with self.assertRaisesRegex(common.ToolError, "other"):
                run.load_differences(bad)
            # What the other validator reports may depend on the document.
            good = Path(tmp) / "good.toml"
            good.write_text('[BR-DE-28]\nrejected-by = "mustang"\nother = ["warning", "nothing"]\nreason = "r"\n',
                            encoding="utf-8")
            entries = run.load_differences(good)
            self.assertTrue(run.documented("BR-DE-28", "mustang", "nothing", entries))
            self.assertTrue(run.documented("BR-DE-28", "mustang", "warning", entries))
            self.assertFalse(run.documented("BR-DE-28", "kosit", "nothing", entries))
            self.assertFalse(run.documented("BR-DE-17", "mustang", "warning", entries))
        # Only the documented level of the other validator counts.
        entries = {"BR-DE-27": {"rejected-by": "mustang", "other": ["warning"], "reason": "r"}}
        self.assertFalse(run.documented("BR-DE-27", "mustang", "nothing", entries))


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

    def test_errors_name_rule_field_and_hint(self):
        good = {"level": "error", "rule": "BR-02", "field": "invoice-nr", "message": "missing", "hint": "Set it."}
        self.assertEqual(oracles.check_diagnostics([good, {"level": "warning", "rule": "BR-DE-27"}]), [])
        problems = oracles.check_diagnostics([dict(good, hint=None), dict(good, field="")])
        self.assertEqual([p.split(":")[0] for p in problems], ["O-DIAG", "O-DIAG"])
        self.assertIn("has no hint", problems[0])
        # Checked in every case, not only in officially valid ones.
        case = {"id": "mu-x", "population": "mutation", "expect": "AGREE_INVALID", "expect_rules": ["BR-02"], "file": "x.typ"}
        row = run.make_row(case, result(ours=["BR-02"], official=["BR-02"]), None)  # no field, no hint
        self.assertEqual((row["cls"], row["class_ok"]), ("AGREE_INVALID", True))
        self.assertEqual([p.split(":")[0] for p in row["oracle"]], ["O-DIAG"])

    def test_deliberate_stops_are_listed_by_message(self):
        def stop(cid, message):
            return dict(row(cid, cls="INPUT_ERROR", expect="AGREE", population="random"),
                        class_ok=True, crash=f'error: panicked with: "{message}"\n  ┌─ /src/x.typ:1:1')

        rows = [
            stop("ru0001", "The modifier `Versand` (5.9) cannot be split over the VAT categories 19% S, 7% S"),
            stop("ru0002", "The modifier `Versand` (5.9) cannot be split over the VAT categories 20% S, 0% Z"),
            stop("ru0003", "`sender.city.post-code` must be a string such as \"01067\""),
        ]
        failures, hits, xpass, _ = run.triage(rows, [])
        self.assertEqual(failures, [])
        text, ok = run.report(rows, failures, hits, xpass, {"total_s": 0, "compile_s": 0, "mustang_wait_s": 0, "jobs": 1}, True)
        self.assertTrue(ok)
        self.assertIn("[  2] The modifier `Versand` (#.#) cannot be split over the VAT categories", text)
        self.assertIn("[  1] `sender.city.post-code` must be a string", text)

    def test_expectations(self):
        case = {"expect": "REJECTED", "expect_rules": ["IP-DOC-01"]}
        self.assertEqual(run.expectation_met(case, "STRICTER", ["IP-DOC-01"]), (True, []))
        self.assertEqual(run.expectation_met(case, "AGREE_VALID", []), (False, ["IP-DOC-01"]))
        self.assertTrue(run.expectation_met({"expect": "AGREE"}, "AGREE_INVALID", ["BR-02"])[0])
        self.assertTrue(run.expectation_met({"expect": "AGREE"}, "STRICTER", ["IP-VAT-226"])[0])
        self.assertFalse(run.expectation_met({"expect": "AGREE"}, "FALSE_POSITIVE", ["BR-IC-02"])[0])
        self.assertFalse(run.expectation_met({"expect": "AGREE"}, "FALSE_NEGATIVE", [])[0])


def row(cid, cls="AGREE_VALID", expect="AGREE_VALID", oracle=(), missing=(), ours=(), official=(), population=None):
    return {
        "id": cid,
        "population": population,
        "cls": cls,
        "expect": expect,
        "class_ok": cls == expect,
        "missing_rules": list(missing),
        "ours": list(ours),
        "official": list(official),
        "oracle": list(oracle),
        # what the report shows of a failure
        "file": f"{cid}.typ",
        "official_messages": [],
        "diagnostics": [],
        "xsd_errors": [],
        "crash": None,
    }


class Metamorphic(unittest.TestCase):
    def test_twins_with_other_totals_fail(self):
        doc = common.parse_xml(CII.encode("utf-8"))
        other = common.parse_xml(CII.replace("<ram:GrandTotalAmount>1234.50", "<ram:GrandTotalAmount>1234.51").encode("utf-8"))
        rows = [row("pw001"), row("mm-split-001"), row("mm-reverse-001")]
        cases = {
            "pw001": {},
            "mm-split-001": {"twin": {"of": "pw001", "relation": "same-totals"}},
            "mm-reverse-001": {"twin": {"of": "pw001", "relation": "same-totals"}},
        }
        run.metamorphic(rows, {"pw001": doc, "mm-split-001": other, "mm-reverse-001": doc}, cases)
        self.assertEqual([r["oracle"] for r in rows[::2]], [[], []])
        self.assertEqual([p.split(":")[0] for p in rows[1]["oracle"]], ["O-META-same-totals"])
        self.assertIn("BT-112", rows[1]["oracle"][0])


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
        failures, hits, xpass, _ = run.triage(rows, known)
        self.assertEqual([r["id"] for r in failures], ["rl001"])
        self.assertEqual(sorted((e["finding"], ids[0]) for e, _, ids in hits), [("f1", "pw001"), ("f2", "pw002")])
        # f2's second signature did not occur; f3 covers no case of this run.
        self.assertEqual([(e["finding"], s) for e, s in xpass], [("f2", "AGREE_VALID oracle=O-BT5")])
        # --strict: every failure is new, nothing is xpass.
        failures, hits, xpass, _ = run.triage(rows, known, strict=True)
        self.assertEqual(len(failures), 3)
        self.assertEqual((hits, xpass), ([], []))

    def test_known_issues_narrowed_by_features(self):
        known = [{"finding": "f1", "signatures": ["AGREE_VALID oracle=O-BG14"], "features": {"delivery": "dates-mixed"}}]
        mixed = dict(row("pw001", oracle=["O-BG14: x"]), features={"delivery": "dates-mixed", "lines": 3})
        dated = dict(row("pw002", oracle=["O-BG14: x"]), features={"delivery": "dates-all", "lines": 3})
        regression = row("rg-a", oracle=["O-BG14: x"])  # no features
        failures, hits, xpass, _ = run.triage([mixed, dated, regression], known)
        # The same signature outside the named features is a new failure.
        self.assertEqual([r["id"] for r in failures], ["pw002", "rg-a"])
        self.assertEqual([ids for _, _, ids in hits], [["pw001"]])
        # A list names several values; an entry that covers no case of the run is not xpass.
        self.assertTrue(run.covers({"features": {"lines": [1, 3]}}, mixed))
        self.assertFalse(run.covers({"features": {"lines": [1, 8]}}, mixed))
        self.assertEqual(run.triage([dated], known)[2], [])
        # It is xpass when it covers a case of the run that no longer fails.
        passing = dict(row("pw003"), features={"delivery": "dates-mixed"})
        self.assertEqual([s for _, s in run.triage([passing], known)[2]], ["AGREE_VALID oracle=O-BG14"])

    def test_hard_gates_are_never_known_issues(self):
        known = [
            {"finding": "f1", "signatures": ["FALSE_NEGATIVE ours=- official=BR-S-08"]},
            {"finding": "f2", "signatures": ["AGREE_VALID oracle=O-BG14"]},
        ]
        rows = [
            # The same signature is excused for a regression case, never on
            # the legal population.
            row("rg-a", cls="FALSE_NEGATIVE", official=["BR-S-08"], population="regression"),
            row("pw001", cls="FALSE_NEGATIVE", official=["BR-S-08"], population="legal"),
            # An oracle failure on the legal population can be a known issue.
            row("pw002", oracle=["O-BG14: x"], population="legal"),
            # invoice-pro blocks a legal invoice with its own rule.
            row("pw003", cls="STRICTER", ours=["IP-VAT-226"], population="legal"),
        ]
        known.append({"finding": "f3", "signatures": [run.signature(rows[-1])]})
        failures, hits, xpass, _ = run.triage(rows, known)
        self.assertEqual([r["id"] for r in failures], ["pw001", "pw003"])
        self.assertEqual(sorted(ids[0] for _, _, ids in hits), ["pw002", "rg-a"])
        self.assertEqual(xpass, [])
        text, ok = run.report(rows, failures, hits, xpass, {"total_s": 0, "compile_s": 0, "mustang_wait_s": 0, "jobs": 1}, True)
        self.assertFalse(ok)
        self.assertIn("HARD GATE BROKEN", text)

    def test_known_issues_file(self):
        # The list only shrinks, down to no entry at all.
        entries = run.load_known(HERE / "known-issues.toml")
        self.assertIsInstance(entries, list)
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

    def test_cases_keep_the_harness(self):
        head = "// expect: AGREE_VALID\n// finding: f\n// The theme: blank, as in zugferd-errors: \"panic\".\n\n"
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "case.typ"

            def load(body):
                file.write_text(head + '#import "_base.typ": *\n#show: invoice.with(\n' + body + ")\n", encoding="utf-8")
                return run.load_cases([file])[0]["id"]

            self.assertEqual(load("  ..setup,\n  zugferd: \"en16931\",\n"), "rg-case")
            self.assertEqual(load("  ..setup,\n  theme: harness(themes.DIN-5008()),\n"), "rg-case")
            # Another theme or mode after `..setup` would lose the diagnostics.
            for body in ("  ..setup,\n  theme: themes.DIN-5008(),\n", '  ..setup,\n  zugferd-errors: "panic",\n'):
                with self.assertRaises(common.ToolError):
                    load(body)

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

    def test_identifiers(self):
        cii = CII.replace(
            "<ram:SellerTradeParty><ram:Name>Muster GmbH</ram:Name></ram:SellerTradeParty>",
            "<ram:SellerTradeParty><ram:ID>SUP-1</ram:ID><ram:Name>Muster GmbH</ram:Name>"
            '<ram:SpecifiedTaxRegistration><ram:ID schemeID="VA">DE123456788</ram:ID></ram:SpecifiedTaxRegistration>'
            '<ram:SpecifiedTaxRegistration><ram:ID schemeID="FC">30/123/45678</ram:ID></ram:SpecifiedTaxRegistration>'
            "</ram:SellerTradeParty>",
        ).replace(
            "<ram:BuyerTradeParty><ram:Name>Kunde AG</ram:Name></ram:BuyerTradeParty>",
            '<ram:BuyerTradeParty><ram:GlobalID schemeID="0088">4000001987658</ram:GlobalID><ram:Name>Kunde AG</ram:Name>'
            '<ram:SpecifiedTaxRegistration><ram:ID schemeID="VA">DE987654328</ram:ID></ram:SpecifiedTaxRegistration>'
            "</ram:BuyerTradeParty>",
        )
        doc = common.parse_xml(cii.encode("utf-8"))
        facts = {
            "seller_vat": "DE123456788",
            "seller_tax_nr": "30/123/45678",
            "seller_ids": [["", "SUP-1"]],
            "buyer_vat": "DE987654328",
            "buyer_ids": [["0088", "4000001987658"]],
        }
        self.assertEqual(oracles.check(facts, doc, None, "en16931"), [])
        # e.g. a tax number written as VAT identifier, a GLN without its scheme
        wrong = {"seller_tax_nr": "DE123456788", "buyer_vat": "FR61954506077", "buyer_ids": [["", "4000001987658"]]}
        problems = oracles.check(wrong, doc, None, "en16931")
        self.assertEqual(sorted(p.split(":")[0] for p in problems), ["O-BT32", "O-BT46", "O-BT48"])
        # MINIMUM carries no buyer identifiers.
        self.assertEqual([p.split(":")[0] for p in oracles.check(wrong, doc, None, "minimum")], ["O-BT32"])

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

    def test_identifier_facts(self):
        def facts(**features):
            return gen.render("x", dict(gen.SIMPLE, **features))[1]

        gln = facts(ids="gln")
        self.assertEqual((gln["seller_vat"], gln["seller_ids"], gln["buyer_ids"]),
                         ("DE123456788", [["0088", gen.SELLER_GLN]], [["0088", gen.BUYER_GLN]]))
        both = facts(ids="vat+taxnr")
        self.assertEqual((both["seller_vat"], both["seller_tax_nr"], both["buyer_vat"]),
                         ("DE123456788", "30/123/45678", "FR61954506077"))
        # Category O leaves out every VAT identifier (BR-O-02): nothing to expect.
        outside = facts(tax="o", route="de-ch", ids="id")
        self.assertEqual((outside["seller_vat"], outside["buyer_vat"], outside["seller_ids"]),
                         (None, None, [["", gen.SELLER_ID]]))
        self.assertIsNone(facts(route="de-us")["buyer_vat"])

    def test_split_twins(self):
        f = dict(gen.SIMPLE, lines=3, route="de-de")  # quantities 1, 2, 1
        src, facts = gen.render("x", f, opts={"split": True})
        self.assertEqual(src.count("#item("), 4)
        self.assertEqual(src.count("quantity: 2"), 0)
        self.assertEqual(facts["line_names"], ["Position 1", "Position 2", "Position 2", "Position 3"])
        rows = [dict(f, mode="inclusive"), f, dict(f, mods="item-pct")]
        twins = [c["id"] for c in gen.metamorphic(rows) if c["id"].startswith("mm-split")]
        self.assertEqual(twins, ["mm-split-001"])  # exact line amounts only

    def test_write_replaces_only_a_generated_corpus(self):
        base = common.build_dir()
        base.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=base) as tmp:
            out = Path(tmp)
            (out / "case.typ").write_text("// expect: AGREE_VALID\n", encoding="utf-8")
            with self.assertRaises(common.ToolError):  # e.g. the regression cases
                gen.write([], out, {})
            self.assertTrue((out / "case.typ").exists())
            (out / "manifest.json").write_text("{}", encoding="utf-8")
            gen.write([], out, {})  # a generated corpus is replaced
            self.assertFalse((out / "case.typ").exists())

    def test_resolved_profile(self):
        self.assertEqual(gen.resolved_profile(dict(gen.SIMPLE, profile="en16931", route="de-de")), "en16931")
        self.assertEqual(gen.resolved_profile(dict(gen.SIMPLE, profile="auto", route="de-de")), "xrechnung")
        self.assertEqual(gen.resolved_profile(dict(gen.SIMPLE, profile="auto", route="de-fr")), "en16931")


if __name__ == "__main__":
    unittest.main()
