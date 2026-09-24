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
import minimize  # noqa: E402
import oracles  # noqa: E402
import registry  # noqa: E402
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
        # Warnings and information are kept apart.
        self.assertEqual(set(result["warnings"]), {"BR-DE-27"})
        self.assertEqual(set(result["information"]), {"BR-CL-10"})

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


def kosit_report(*errors, warnings=(), information=(), status=None):
    return {"status": status or ("reject" if errors else "accept"), "scenario": "EN16931 XRechnung (CII)",
            "errors": {e: e for e in errors}, "warnings": {w: w for w in warnings},
            "information": {i: i for i in information}}


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
        differences = {"BR-DE-27": {"rejected-by": ["mustang"], "other": ["warning"], "reason": "r"}}

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
            "BR-DE-27": {"rejected-by": ["mustang"], "other": ["warning"], "reason": "r"},
            "BR-CO-25": {"rejected-by": ["mustang"], "other": ["nothing"], "reason": "r"},
        }
        case = {"id": "rg-a", "population": "regression", "expect": "AGREE_INVALID", "file": "x.typ"}
        rows = [run.make_row(case, collected(mustang_report("BR-DE-27"), kosit_report(warnings=["BR-DE-27"]),
                                             ours=["BR-DE-27"]), None)]
        self.assertEqual(run.triage(rows, [], differences=differences, check_stale=True)[3], ["BR-CO-25"])
        # Only a run of all regression cases, which show every difference,
        # checks the list: not a subset (--only, --population, single case
        # files), nor a run without KoSIT.
        self.assertEqual(run.triage(rows, [], differences=differences)[3], [])
        rows_without_kosit = [run.make_row(case, collected(mustang_report("BR-DE-27"), ours=["BR-DE-27"]), None)]
        self.assertEqual(run.triage(rows_without_kosit, [], differences=differences, check_stale=True)[3], [])

    def test_only_all_regression_cases_check_the_differences(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("a.typ", "b.typ", "_base.typ"):
                (Path(tmp) / name).write_text("", encoding="utf-8")
            both = [{"id": "rg-a"}, {"id": "rg-b"}, {"id": "pw001"}]
            self.assertTrue(run.regression_complete(both, tmp))  # `_base.typ` is no case
            # A single case file, e.g. `run.py tools/zugferd/corpus/regression/a.typ`.
            self.assertFalse(run.regression_complete([{"id": "rg-a"}], tmp))
            self.assertFalse(run.regression_complete([{"id": "pw001"}], tmp))
        # The committed regression cases are complete on their own.
        cases = run.load_cases([run.REGRESSION])
        self.assertTrue(run.regression_complete(cases))
        self.assertFalse(run.regression_complete(cases[1:]))

    def test_differences_file(self):
        differences = run.load_differences(HERE / "validator-differences.toml")
        for rule, entry in differences.items():
            self.assertTrue(entry["rejected-by"] and set(entry["rejected-by"]) <= set(run.VALIDATORS), rule)
        # KoSIT reports nothing for a domain with umlauts and warns about an
        # address without a domain name (BR-DE-28); Mustang rejects both.
        self.assertTrue(run.documented("BR-DE-28", "mustang", "nothing", differences))
        self.assertTrue(run.documented("BR-DE-28", "mustang", "warning", differences))
        # The code lists differ both ways: a code only the newer lists of
        # KoSIT have, and one they have withdrawn.
        for rule in ("BR-CL-03", "BR-CL-04", "BR-CL-25"):
            for validator in run.VALIDATORS:
                self.assertTrue(run.documented(rule, validator, "nothing", differences), (rule, validator))
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "differences.toml"
            bad.write_text('[BR-DE-27]\nrejected-by = "kosit"\nother = "error"\nreason = "r"\n', encoding="utf-8")
            with self.assertRaisesRegex(common.ToolError, "other"):
                run.load_differences(bad)
            bad.write_text('[BR-DE-27]\nrejected-by = ["kosit", "xsd"]\nother = "nothing"\nreason = "r"\n',
                           encoding="utf-8")
            with self.assertRaisesRegex(common.ToolError, "rejected-by"):
                run.load_differences(bad)
            # Which validator rejects may depend on the document as well.
            both = Path(tmp) / "both.toml"
            both.write_text('[BR-CL-04]\nrejected-by = ["mustang", "kosit"]\nother = "nothing"\nreason = "r"\n',
                            encoding="utf-8")
            entries = run.load_differences(both)
            self.assertTrue(run.documented("BR-CL-04", "kosit", "nothing", entries))
            self.assertTrue(run.documented("BR-CL-04", "mustang", "nothing", entries))
            self.assertFalse(run.documented("BR-CL-04", "kosit", "warning", entries))
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
        entries = {"BR-DE-27": {"rejected-by": ["mustang"], "other": ["warning"], "reason": "r"}}
        self.assertFalse(run.documented("BR-DE-27", "mustang", "nothing", entries))


class Minimizer(unittest.TestCase):
    def test_undocumented_disagreements_are_failures(self):
        # A random case on which Mustang and KoSIT disagree: its class is as
        # expected, only the disagreement makes it fail (run.triage), so the
        # minimizer must see the failure and keep it in the signature.
        case = {"id": "ru0001", "population": "random", "expect": "AGREE", "file": "x.typ"}
        res = collected(mustang_report("BR-DE-27"), kosit_report(warnings=["BR-DE-27"]), ours=["BR-DE-27"])
        documented = {"BR-DE-27": {"rejected-by": ["mustang"], "other": ["warning"], "reason": "r"}}
        signature, failing = minimize.failure(run.make_row(case, res, None), documented)
        self.assertEqual((signature, failing), (("AGREE_INVALID", ("BR-DE-27",), ("BR-DE-27",), (), ()), False))
        row = run.make_row(case, res, None)
        signature, failing = minimize.failure(row, {})
        self.assertEqual((signature[-1], failing), (("BR-DE-27",), True))
        self.assertIn("OFFICIAL_DISAGREE only-mustang=BR-DE-27", run.signature(row))
        # The other failures, as before.
        wrong = dict(case, expect="AGREE_VALID")
        self.assertTrue(minimize.failure(run.make_row(wrong, res, None), documented)[1])


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

    def test_expected_warnings(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "case.typ"
            file.write_text("// expect: AGREE_VALID\n// warns: BR-DE-TMP-32\n// warns: IP-UNIT-01\n\n#x\n",
                            encoding="utf-8")
            header = run.parse_header(file)
        self.assertEqual((header["expect_rules"], header["expect_warnings"]), ([], ["BR-DE-TMP-32", "IP-UNIT-01"]))
        self.assertEqual(run.expectation_met(header, "AGREE_VALID", [], ["IP-UNIT-01"]),
                         (True, ["warning:BR-DE-TMP-32"]))
        self.assertEqual(run.expectation_met(header, "AGREE_VALID", [], ["BR-DE-TMP-32", "IP-UNIT-01"]), (True, []))
        # An error is no warning.
        res = {"diagnostics": [{"level": "error", "rule": "BR-DE-TMP-32"}, {"level": "warning", "rule": "IP-UNIT-01"}]}
        self.assertEqual(run.warning_rules(res), ["IP-UNIT-01"])

    def test_parity_fixtures(self):
        cases = run.load_cases([run.RULES])
        self.assertTrue(cases)
        for case in cases:
            self.assertTrue(case["id"].startswith("rule-"), case["id"])
            self.assertEqual(case["population"], "rules")
        # Only a run of every fixture can tell that each rule classified as
        # `fixture` has one that passed.
        self.assertTrue(run.rules_complete(cases))
        self.assertFalse(run.rules_complete(cases[1:]))
        # A fixture is no regression case, and the other way round.
        self.assertFalse(run.regression_complete(cases))
        self.assertTrue(run.rules_complete(run.load_cases([run.RULES, run.REGRESSION])))
        # A fixture is a case in each profile of its header; a run without
        # one of them is not complete either.
        several = [c for c in cases if c["file"].endswith("/BR-02.typ")]
        self.assertEqual([c["id"] for c in several], [f"rule-BR-02@{p}" for p in run.rule_coverage.PROFILES])
        self.assertEqual([c["inputs"] for c in several], [{"profile": p} for p in run.rule_coverage.PROFILES])
        self.assertFalse(run.rules_complete([c for c in cases if c["id"] != "rule-BR-02@basic"]))

    def test_fixture_profiles(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "BR-01.typ"
            source = '\n#import "_base.typ": *\n#show: invoice.with(..setup, zugferd: fixture-profile("basic"))\n'
            file.write_text("// expect: AGREE_INVALID BR-01\n// profiles: basic en16931\n" + source, encoding="utf-8")
            # A regression case runs in the profile of its source only.
            with self.assertRaisesRegex(common.ToolError, "only a parity fixture"):
                run.load_cases([file])
            with unittest.mock.patch.dict(run.FILE_CASES, {Path(tmp).resolve(): ("rule-", "rules")}):
                cases = run.load_cases([file])
                self.assertEqual([(c["id"], c["profile"], c["inputs"], c["population"]) for c in cases], [
                    ("rule-BR-01@basic", "basic", {"profile": "basic"}, "rules"),
                    ("rule-BR-01@en16931", "en16931", {"profile": "en16931"}, "rules"),
                ])
                file.write_text("// expect: AGREE_INVALID BR-01\n" + source, encoding="utf-8")
                with self.assertRaisesRegex(common.ToolError, "lists the profiles it runs in"):
                    run.load_cases([file])
            file.write_text("// expect: AGREE_INVALID BR-01\n// profiles: full\n" + source, encoding="utf-8")
            with self.assertRaisesRegex(common.ToolError, "`// profiles:` lists profiles of"):
                run.load_cases([file])

    def test_the_profile_goes_to_typst(self):
        case = {"id": "rule-BR-01@basic", "file": "x.typ", "inputs": {"profile": "basic"}}
        with tempfile.TemporaryDirectory() as tmp, \
                unittest.mock.patch.object(common, "typst_compile", return_value=(False, "error: x", 0.1)) as compile_:
            run.compile_case(case, tmp)
        self.assertEqual(compile_.call_args.kwargs["inputs"], {"profile": "basic"})


def fixture_case(name, *rules, warns=()):
    return {"file": str(run.RULES / f"{name}.typ"), "expect_rules": list(rules), "expect_warnings": list(warns)}


class RuleChecks(unittest.TestCase):
    """The rule ids of every case (O-RULE) and the parity of the fixtures
    (O-PARITY), against the rules of the validators of the profile."""

    LEVELS = {
        "xrechnung": {
            "BR-DE-27": {"mustang": "error", "kosit": "warning"},
            "BR-DE-TMP-32": {"kosit": "information"},
            "BR-DE-16": {"mustang": "error", "kosit": "error"},
            "BR-S-02": {"mustang": "error", "kosit": "error"},
            "BR-AG-05": {"mustang": "error", "kosit": "error"},
            "BR-02": {"mustang": "error", "kosit": "error"},
        },
        "basic-wl": {"BR-O-11": {"mustang": "error"}},
    }

    def parity(self, case, res, differences=None):
        return run.fixture_parity(case, res, self.LEVELS, differences or {})

    def test_both_validators_report_the_rule(self):
        res = collected(mustang_report("BR-02"), kosit_report("BR-02"), ours=["BR-02"])
        self.assertEqual(self.parity(fixture_case("BR-02", "BR-02"), res), [])
        res = collected(mustang_report("BR-02"), kosit_report("BR-CO-26"), ours=["BR-02"])
        self.assertEqual(self.parity(fixture_case("BR-02", "BR-02"), res),
                         ["O-PARITY: KoSIT does not report BR-02 (error in its artefacts)"])
        # The case runs without the validators: nobody reports the rule.
        res = collected(ours=["BR-02"])
        self.assertEqual(self.parity(fixture_case("BR-02", "BR-02"), res), ["O-PARITY: no official validator reports BR-02"])

    def test_at_the_level_of_each_validator(self):
        # KoSIT warns about BR-DE-27, Mustang reports an error.
        res = collected(mustang_report("BR-DE-27"), kosit_report(warnings=["BR-DE-27"]), ours=["BR-DE-27"])
        self.assertEqual(self.parity(fixture_case("BR-DE-27", "BR-DE-27"), res), [])
        # A warning expected of invoice-pro, which KoSIT reports as information.
        res = collected(mustang_report(), kosit_report(information=["BR-DE-TMP-32"]))
        self.assertEqual(self.parity(fixture_case("BR-DE-TMP-32", warns=["BR-DE-TMP-32"]), res), [])
        res = collected(mustang_report(), kosit_report())
        self.assertEqual(self.parity(fixture_case("BR-DE-TMP-32", warns=["BR-DE-TMP-32"]), res),
                         ["O-PARITY: KoSIT does not report BR-DE-TMP-32 (information in its artefacts)"])

    def test_documented_differences_and_schema_errors(self):
        res = collected(mustang_report("BR-AG-05"), kosit_report(), ours=["BR-AG-05"])
        self.assertEqual(len(self.parity(fixture_case("BR-AG-05", "BR-AG-05"), res)), 1)
        differences = {"BR-AG-05": {"rejected-by": ["mustang"], "other": ["nothing"], "reason": "r"}}
        self.assertEqual(self.parity(fixture_case("BR-AG-05", "BR-AG-05"), res, differences), [])
        # KoSIT runs no Schematron on a document that fails its schema.
        kosit = dict(kosit_report("XSD"), schematron=False)
        res = collected(mustang_report("BR-02", "XSD"), kosit, ours=["BR-02"])
        self.assertEqual(self.parity(fixture_case("BR-02", "BR-02"), res), [])

    def test_related_rules_and_counterparts(self):
        # BR-DE-16 is reported as BR-S-02: both must come from the validators.
        res = collected(mustang_report("BR-DE-16", "BR-S-02"), kosit_report("BR-DE-16", "BR-S-02"), ours=["BR-S-02"])
        self.assertEqual(self.parity(fixture_case("BR-DE-16", "BR-S-02"), res), [])
        res = collected(mustang_report("BR-DE-16"), kosit_report("BR-DE-16"), ours=["BR-S-02"])
        self.assertEqual(len(self.parity(fixture_case("BR-DE-16", "BR-S-02"), res)), 2)
        # invoice-pro's own rules have no official counterpart to compare.
        res = collected(mustang_report("BR-02"), kosit_report("BR-02"), ours=["BR-02", "IP-PAY-03"])
        self.assertEqual(self.parity(fixture_case("BR-02", "BR-02", "IP-PAY-03"), res), [])
        # A passing counterpart has nothing to compare, a rule of another
        # profile fails.
        self.assertEqual(self.parity(fixture_case("BR-02--pass"), collected(mustang_report(), kosit_report())), [])
        res = collected(mustang_report("BR-O-11"), ours=["BR-O-11"])
        self.assertEqual(self.parity(fixture_case("BR-O-11", "BR-O-11"), res),
                         ["O-PARITY: no official validator of the xrechnung profile has BR-O-11"])

    def test_the_profile_of_the_run(self):
        # A fixture that ignores the profile of its run (a literal `zugferd:`)
        # would show the rule in another profile than it claims.
        res = collected(mustang_report("BR-02"), kosit_report("BR-02"), ours=["BR-02"])
        case = dict(fixture_case("BR-02", "BR-02"), profile="xrechnung")
        self.assertEqual(self.parity(case, res), [])
        self.assertEqual(self.parity(dict(case, profile="basic"), res),
                         ["O-PARITY: the fixture ran as xrechnung, not as basic (`zugferd: fixture-profile(..)`)"])
        # Also for a passing counterpart.
        passing = dict(fixture_case("BR-02--pass"), profile="basic")
        self.assertEqual(len(self.parity(passing, collected(mustang_report(), kosit_report()))), 1)

    def test_the_rules_of_the_registry(self):
        # Every diagnostic, a warning too, names a rule the registry lists in
        # the profile of the case (the check of the tests' harness).
        reported = {"basic-wl": {"BR-O-11", "IP-VAT-226"}}
        res = collected(ours=["BR-O-02", "IP-VAT-226"])
        res["diagnostics"].append({"level": "warning", "rule": "BR-O-11"})
        res["profile"] = "basic-wl"
        self.assertEqual(run.registry_rule_problems(res, reported), [
            "O-REGISTRY: invoice-pro reports BR-O-02, which the rule registry does not list in the basic-wl profile",
        ])
        res["profile"] = None  # no profile (e.g. no e-invoice): no check
        self.assertEqual(run.registry_rule_problems(res, reported), [])
        # The registry lists the ids of its entries per profile.
        listed = registry.reported_in(registry.load(), "basic-wl")
        self.assertIn("FX-SCH-A-000040", listed)
        self.assertNotIn("BR-CL-04", listed)

    def test_foreign_rules(self):
        res = collected(mustang_report("BR-O-03"), ours=["BR-O-02", "IP-VAT-226"])
        res["profile"] = "basic-wl"
        self.assertEqual(run.foreign_rule_problems(res, self.LEVELS),
                         ["O-RULE: invoice-pro reports BR-O-02, which no official validator of the basic-wl profile has"])
        res["profile"] = "minimum"  # no inventory of the profile: no check
        self.assertEqual(run.foreign_rule_problems(res, self.LEVELS), [])


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

    def test_references_notes_and_line_details(self):
        cii = CII.replace(
            "<ram:TypeCode>380</ram:TypeCode></rsm:ExchangedDocument>",
            "<ram:TypeCode>381</ram:TypeCode>"
            "<ram:IncludedNote><ram:Content>Lieferung frei Haus.</ram:Content></ram:IncludedNote>"
            "<ram:IncludedNote><ram:Content>AGB</ram:Content><ram:SubjectCode>AAI</ram:SubjectCode></ram:IncludedNote>"
            "</rsm:ExchangedDocument>",
        ).replace(
            "<ram:SpecifiedTradeProduct><ram:Name>Buch</ram:Name></ram:SpecifiedTradeProduct>",
            "<ram:AssociatedDocumentLineDocument><ram:IncludedNote><ram:Content>Signiert</ram:Content>"
            "</ram:IncludedNote></ram:AssociatedDocumentLineDocument>"
            "<ram:SpecifiedTradeProduct><ram:Name>Buch</ram:Name>"
            "<ram:OriginTradeCountry><ram:ID>IT</ram:ID></ram:OriginTradeCountry></ram:SpecifiedTradeProduct>",
        ).replace(
            "</ram:SpecifiedTradeSettlementHeaderMonetarySummation>",
            "</ram:SpecifiedTradeSettlementHeaderMonetarySummation>"
            '<ram:InvoiceReferencedDocument xmlns:qdt="urn:un:unece:uncefact:data:standard:QualifiedDataType:100">'
            "<ram:IssuerAssignedID>RE-0</ram:IssuerAssignedID><ram:FormattedIssueDateTime>"
            '<qdt:DateTimeString format="102">20260803</qdt:DateTimeString></ram:FormattedIssueDateTime>'
            "</ram:InvoiceReferencedDocument>",
        )
        doc = common.parse_xml(cii.encode("utf-8"))
        facts = {
            "type_code": "381",
            "preceding_invoice": ["RE-0", "20260803"],
            "notes": [["AAI", "AGB"]],  # other notes may come before
            "item_notes": [["Buch", "Signiert"]],
            "item_origins": [["Buch", "IT"]],
        }
        self.assertEqual(oracles.check(facts, doc, None, "en16931"), [])
        wrong = {
            "preceding_invoice": ["RE-0", "20260804"],
            "notes": [["AAI", "AGB"], ["", "Lieferung frei Haus."]],  # in the wrong order
            "item_notes": [["Paket", "Signiert"]],  # no such line, and "Buch" has a note of its own
            "item_origins": [["Buch", "DE"]],
        }

        def ids(profile):
            return sorted({p.split(":")[0] for p in oracles.check(wrong, doc, None, profile)})

        self.assertEqual(ids("en16931"), ["O-BT127", "O-BT159", "O-BT22", "O-BT25"])
        # BASIC states no country of origin, BASIC WL no lines, MINIMUM
        # neither notes nor a preceding invoice.
        self.assertEqual(ids("basic"), ["O-BT127", "O-BT22", "O-BT25"])
        self.assertEqual(ids("basic-wl"), ["O-BT22", "O-BT25"])
        self.assertEqual(ids("minimum"), [])

    def test_details_only_where_the_profile_states_them(self):
        # The fixture states no payee, payment card or account name.
        facts = {"payee": {"name": "Factoring Bank AG"}, "card": ["1234", "Erika Kunde"], "account_name": "Factoring"}

        def ids(profile):
            return sorted({p.split(":")[0] for p in oracles.check(facts, self.doc, None, profile)})

        self.assertEqual(ids("en16931"), ["O-BG10", "O-BG18", "O-BT85"])
        self.assertEqual(ids("basic-wl"), ["O-BG10"])  # BASIC WL has no card and no account name
        self.assertEqual(ids("minimum"), [])  # MINIMUM has no payee

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

    def test_identity_constraints(self):
        base = dict(gen.SIMPLE)
        # MINIMUM identifies the seller by its VAT ID or its legal registration
        # identifier (BR-CO-26); without VAT IDs (category O) only the latter.
        outside = dict(base, tax="o", route="de-us", profile="minimum")
        self.assertTrue(gen.allowed(dict(outside, ids="legal")))
        self.assertFalse(gen.allowed(dict(outside, ids="id")))
        self.assertFalse(gen.allowed(dict(base, profile="minimum", ids="taxnr")))
        # A reverse charge to a buyer with a legal registration identifier
        # instead of a VAT ID: at home only (IP-VAT-226 across borders).
        self.assertTrue(gen.allowed(dict(base, tax="ae", ids="legal", route="de-de")))
        self.assertFalse(gen.allowed(dict(base, tax="ae", ids="legal", route="de-fr")))
        self.assertFalse(gen.allowed(dict(base, tax="k", ids="legal", route="de-at")))  # K needs VAT IDs

    def test_document_and_payment_constraints(self):
        base = dict(gen.SIMPLE)
        # The sender of a credit note pays: no direct debit, card, payee, and
        # bank details only of a buyer with an account; paid already, e.g. in
        # cash, also to a buyer without one.
        credit = dict(base, doctype="credit-note")
        self.assertTrue(gen.allowed(credit))
        for other in ({"payment": "direct-debit", "route": "de-de"}, {"payment": "card"},
                      {"extras": "payee"}, {"route": "de-us", "payment": "bank+days"}):
            self.assertFalse(gen.allowed(dict(credit, **other)), other)
        self.assertTrue(gen.allowed(dict(credit, route="de-us", payment="nobank+days")))
        self.assertTrue(gen.allowed(dict(credit, payment="paid")))
        self.assertTrue(gen.allowed(dict(credit, route="de-us", payment="paid")))
        # A self-billed invoice: at home, not in XRechnung.
        billed = dict(base, doctype="self-billed", route="de-de")
        self.assertTrue(gen.allowed(billed))
        self.assertTrue(gen.allowed(dict(billed, payment="paid")))
        self.assertFalse(gen.allowed(dict(billed, route="de-fr")))
        self.assertFalse(gen.allowed(dict(billed, profile="xrechnung")))
        # A SEPA direct debit of the German seller from an account in the euro area.
        debit = dict(base, payment="direct-debit")
        self.assertTrue(gen.allowed(debit))
        self.assertFalse(gen.allowed(dict(debit, route="at-de")))
        self.assertFalse(gen.allowed(dict(debit, route="de-us", tax="g")))
        # US dollars for exports and supplies outside the scope of VAT only.
        self.assertTrue(gen.allowed(dict(base, currency="usd", tax="g", route="de-us")))
        self.assertFalse(gen.allowed(dict(base, currency="usd")))
        self.assertFalse(gen.allowed(dict(base, extras="payee", payment="card")))  # the payee gets a transfer

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
        # Legal registration identifiers instead of VAT IDs; the seller states
        # its tax number.
        src, legal = gen.render("x", dict(gen.SIMPLE, ids="legal", route="de-fr"))
        self.assertIn('legal-id: id.register("HRB 4711", court: "Amtsgericht Charlottenburg")', src)
        self.assertIn('legal-id: id.siren("954 506 077")', src)
        self.assertNotIn("vat-id", src)
        self.assertEqual((legal["seller_vat"], legal["seller_tax_nr"], legal["buyer_vat"]), (None, "30/123/45678", None))
        self.assertEqual((legal["seller_legal_id"], legal["buyer_legal_id"]),
                         (["", "Amtsgericht Charlottenburg, HRB 4711"], ["0002", "954506077"]))

    def test_document_type_facts(self):
        src, credit = gen.render("x", dict(gen.SIMPLE, doctype="credit-note", route="de-de"))
        self.assertIn('document-type: "credit-note"', src)
        self.assertIn('preceding-invoice-nr: "RE-2026-0815"', src)
        # The seller refunds the buyer to the buyer's account.
        self.assertIn(f'iban: "{gen.BUYER["de"]["iban"]}"', src)
        self.assertEqual((credit["type_code"], credit["preceding_invoice"], credit["iban"]),
                         ("381", ["RE-2026-0815", "20260803"], gen.BUYER["de"]["iban"]))
        # A self-billed invoice: the XML states the recipient as seller and the
        # sender as buyer, and the amount is paid to the recipient.
        src, billed = gen.render("x", dict(gen.SIMPLE, doctype="self-billed", route="de-de", ids="vat+taxnr"))
        self.assertNotIn("buyer-reference", src)
        self.assertEqual(
            (billed["type_code"], billed["seller_name"], billed["buyer_name"], billed["seller_vat"],
             billed["buyer_vat"], billed["seller_tax_nr"], billed["iban"], billed["preceding_invoice"]),
            ("389", "Kunde AG", "Muster GmbH", "DE987654328", "DE123456788", None, gen.BUYER["de"]["iban"], None),
        )
        # The random population has no legal constraints: an intra-community
        # supply on a self-billed invoice goes to its buyer, the sender, and
        # `auto` cannot choose XRechnung, whose seller contact (BG-6) the
        # recipient lacks.
        _, supply = gen.render("x", dict(gen.SIMPLE, doctype="self-billed", tax="k", route="de-fr", profile="auto"))
        self.assertEqual((supply["ship_to_country"], supply["profile"]), ("DE", "en16931"))
        self.assertEqual(gen.render("x", dict(gen.SIMPLE, tax="k", route="de-fr"))[1]["ship_to_country"], "FR")

    def test_payment_facts(self):
        def render(**features):
            return gen.render("x", dict(gen.SIMPLE, **features))

        src, debit = render(payment="direct-debit", route="de-de")
        self.assertIn('#direct-debit(mandate: "M-2026-017", creditor-id: "DE98ZZZ09999999999", '
                      f'debtor-iban: "{gen.BUYER["de"]["iban"]}")', src)
        self.assertNotIn("#bank-details", src)
        self.assertEqual((debit["payment_means"], debit["mandate"], debit["creditor_id"], debit["debtor_iban"],
                          debit["due_date"], debit["iban"]),
                         (["59"], "M-2026-017", "DE98ZZZ09999999999", gen.BUYER["de"]["iban"], "20260915", None))
        src, card = render(payment="card")
        self.assertIn('#card-payment(last4: "1234", holder: "Erika Kunde", kind: "credit")', src)
        self.assertEqual((card["payment_means"], card["card"], card["due_date"]), (["54"], ["1234", "Erika Kunde"], None))
        src, paid = render(payment="paid")
        self.assertIn('#paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))', src)
        self.assertNotIn("#payment-goal", src)
        self.assertEqual((paid["payment_means"], paid["paid"], paid["due_date"]), (["10"], True, None))
        # A credit transfer or a direct debit outside the euro is no SEPA
        # payment (the random population has direct debits in other currencies).
        self.assertEqual(render()[1]["payment_means"], ["58"])
        self.assertEqual(render(route="ch-ch")[1]["payment_means"], ["30"])
        self.assertEqual(render(payment="direct-debit", route="ch-ch")[1]["payment_means"], ["49"])
        src, usd = render(currency="usd", tax="g", route="de-us")
        self.assertIn('currency: "USD"', src)
        self.assertEqual((usd["currency"], usd["payment_means"]), ("USD", ["30"]))
        # A factoring company as payee, paid to its own account.
        src, payee = render(extras="payee")
        self.assertIn(f'iban: "{gen.PAYEE["iban"]}"', src)
        self.assertEqual((payee["payee"]["name"], payee["iban"], payee["account_name"]),
                         ("Factoring Bank AG", gen.PAYEE["iban"], "Factoring Bank AG"))

    def test_extras_facts(self):
        src, notes = gen.render("x", dict(gen.SIMPLE, extras="notes"))
        self.assertIn('notes: ("Lieferung frei Haus.", (text: "Es gelten unsere Allgemeinen Geschäftsbedingungen.", '
                      'subject-code: "AAI")),', src)
        self.assertEqual(notes["notes"], [["", "Lieferung frei Haus."],
                                          ["AAI", "Es gelten unsere Allgemeinen Geschäftsbedingungen."]])
        # The note and the country of origin of the last item, never one of a bundle.
        src, items = gen.render("x", dict(gen.SIMPLE, extras="item-data", lines=3, mods="bundle2-pct"))
        self.assertEqual(src.count(f'note: "{gen.ITEM_NOTE}", origin: country.it'), 1)
        self.assertEqual((items["item_notes"], items["item_origins"]),
                         ([["Position 3", gen.ITEM_NOTE]], [["Position 3", "IT"]]))
        src, period = gen.render("x", dict(gen.SIMPLE, delivery="period"))
        self.assertIn(f"service-period: {gen.ITEM_PERIOD},", src)
        self.assertEqual(period["period"], list(gen.PERIOD))

    def test_currency_twins(self):
        rows = [dict(gen.SIMPLE, lines=3)] * 3
        rows[2] = dict(rows[2], payment="direct-debit")  # a SEPA direct debit is in euro
        self.assertEqual([c["id"] for c in gen.metamorphic(rows) if c["id"].startswith("mm-currency")], [])
        rows[2] = dict(rows[2], payment="bank+days")
        self.assertEqual([c["id"] for c in gen.metamorphic(rows) if c["id"].startswith("mm-currency")],
                         ["mm-currency-002"])

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

    def test_paid_credit_note(self):
        src, paid = gen.render("x", dict(gen.SIMPLE, doctype="credit-note", payment="paid", route="de-de"))
        self.assertIn('#paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))', src)
        self.assertNotIn("#bank-details", src)
        self.assertEqual((paid["type_code"], paid["payment_means"], paid["paid"], paid["iban"]), ("381", ["10"], True, None))

    def test_fiscal_representative(self):
        # A Swiss seller supplies goods from Germany to France through its
        # German fiscal representative (BG-11): an intra-community supply,
        # with the VAT ID of the representative and the buyer's.
        route = dict(gen.SIMPLE, route="ch-fr", tax="k")
        self.assertTrue(gen.allowed(route))
        self.assertTrue(gen.allowed(dict(route, ids="gln")))
        for other in ({"tax": "s"}, {"tax": "g"}, {"ids": "legal"}, {"ids": "taxnr"}, {"doctype": "self-billed"},
                      {"payment": "direct-debit"}):
            self.assertFalse(gen.allowed(dict(route, **other)), other)
        src, facts = gen.render("x", route)
        self.assertIn('legal-id: id.uid-ch("CHE-123.456.788")', src)
        self.assertIn(f"tax-representative: {gen.TAX_REPRESENTATIVE['source']}", src)
        self.assertIn("locale: locale.de-de", src)
        self.assertNotIn('vat-id: "CHE', src)
        self.assertEqual((facts["seller_vat"], facts["seller_legal_id"], facts["buyer_vat"], facts["ship_to_country"],
                          facts["currency"], facts["breakdown"]),
                         (None, ["0183", "CHE123456788"], "FR61954506077", "FR", "EUR", [("K", "0")]))
        self.assertEqual(facts["tax_representative"], {"name": "Fiskalvertretung Muster GmbH", "vat": "DE136695976",
                                                       "country": "DE"})
        # MINIMUM states no tax representative.
        self.assertIsNone(gen.render("x", dict(route, profile="minimum"))[1]["tax_representative"])
        # A random self-billed invoice: the sender is the buyer, who has no
        # tax representative of the seller.
        src, billed = gen.render("x", dict(route, doctype="self-billed"))
        self.assertNotIn("tax-representative", src)
        self.assertIsNone(billed["tax_representative"])

    def test_exemption_codes(self):
        f = dict(gen.SIMPLE, tax="e-code", route="de-de", lines=2)
        self.assertTrue(gen.allowed(f))
        self.assertFalse(gen.allowed(dict(f, route="de-fr")))  # an exemption at home
        src, facts = gen.render("x", f)
        self.assertEqual(src.count(f'tax.exempt(grounds: "{gen.GROUNDS["e2"]}", code: "{gen.EXEMPTION_CODE}")'), 2)
        self.assertEqual((facts["breakdown"], facts["grounds"]), ([("E", "0")], [("E", gen.GROUNDS["e2"])] * 2))

    def test_references(self):
        src, _ = gen.render("x", dict(gen.SIMPLE, theme="din-5008-refs"))
        self.assertIn("theme: harness(themes.DIN-5008()),", src)
        self.assertIn("  references: (references.invoice-nr(), references.invoice-date(), references.service-time(), "
                      "references.due-date(), references.seller-tax-nr(), references.seller-vat-id(), "
                      "references.buyer-vat-id()),", src)
        self.assertNotIn("references:", gen.render("x", dict(gen.SIMPLE, theme="din-5008"))[0])
        # The printed details the law requires, left out of the references.
        printed = {c["id"]: c for c in gen.mutations() if c["id"].startswith("mu-refs")}
        self.assertEqual(sorted(printed), ["mu-refs-no-date-of-supply-en16931", "mu-refs-no-date-of-supply-xrechnung",
                                           "mu-refs-no-seller-tax-id-en16931", "mu-refs-no-seller-tax-id-xrechnung"])
        case = printed["mu-refs-no-seller-tax-id-xrechnung"]
        self.assertEqual((case["expect"], case["expect_rules"], case["features"]["route"]),
                         ("STRICTER", ["IP-PRINT-03"], "de-de"))
        self.assertIn("references: (references.invoice-nr(), references.invoice-date(), references.service-time(), "
                      "references.buyer-vat-id()),", case["source"])

    def test_resolved_profile(self):
        self.assertEqual(gen.resolved_profile(dict(gen.SIMPLE, profile="en16931", route="de-de")), "en16931")
        self.assertEqual(gen.resolved_profile(dict(gen.SIMPLE, profile="auto", route="de-de")), "xrechnung")
        self.assertEqual(gen.resolved_profile(dict(gen.SIMPLE, profile="auto", route="de-fr")), "en16931")


if __name__ == "__main__":
    unittest.main()
