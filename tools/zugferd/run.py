#!/usr/bin/env python3
"""Conformance runner: invoice-pro's verdict against the official validators.

  run.py [PATH ...] [--jobs N] [--only ID,..] [--strict] [--no-mustang] [--no-kosit]

PATH is a generated corpus (a directory with `manifest.json`, see
corpus/gen.py), a directory of regression cases or of parity fixtures, or
single `.typ` files. Default: <build dir>/corpus (when generated),
corpus/regression and corpus/rules.

For every case:
  1. Typst, once: `zugferd-errors: "report"` with the harness theme
     (harness.typ), which attaches invoice-pro's diagnostics as JSON. The
     e-invoice XML, the diagnostics and the PDF text are read from the PDF.
  2. XSD of the profile (lxml; the Factur-X XSDs come from the Mustang jar).
  3. Mustang 2.14 (EN 16931, Factur-X and XRechnung Schematron) in a single
     JVM for the whole run (java/MustangBatch.java, compiled on first use).
  4. KoSIT 1.6.3 with the XRechnung configuration (CEN Schematron 1.3.16,
     XRechnung Schematron 2.6.0), the reference validator for XRechnung: one
     JVM validates the EN 16931 and XRechnung documents of the run as a
     batch. KoSIT has no scenario for MINIMUM, BASIC WL and BASIC.
  5. Classification (see CLASSES) against the official verdict: valid only
     when the XSD, Mustang and KoSIT accept the XML. Then the case's
     expectation, the semantic oracles (oracles.py), the metamorphic
     relations between twins, and that every error of invoice-pro names its
     rule, field and a hint.
  6. Rule ids (rule_coverage.py): every error of invoice-pro names a rule the
     official validators of the case's profile have, or one of its own
     (O-RULE), and every diagnostic a rule the rule registry lists in the
     profile, or a warning of `zugferd: auto` one of a richer profile the
     invoice missed (O-REGISTRY); a parity fixture (corpus/rules/<RULE>.typ), a
     case in each profile of its `// profiles:` header, is reported under
     its rule by each validator that has the rule in the profile
     (O-PARITY). A run with
     every fixture checks that each rule the classification calls `fixture`
     has, in each such profile, a fixture that passed.

Failures are grouped by signature. `known-issues.toml` lists the signatures
of known bugs with their finding: a known signature does not fail the run,
an unknown one does, and so does a known one that no longer occurs (xpass),
so the list can only shrink. `--strict` ignores the list. The hard gate,
every legal invoice is AGREE_VALID, cannot be excused by the list.

When only one of Mustang and KoSIT rejects a document, every rule behind the
disagreement must be documented in `validator-differences.toml`; an
undocumented one fails the run (OFFICIAL_DISAGREE), and so does a documented
one that no case shows any more in a run of all regression cases.

Exit code: 0 all green (or only known issues), 1 failures, 2 setup error.
"""

import argparse
import collections
import fnmatch
import json
import multiprocessing
import os
import re
import sys
import time
import tomllib
from concurrent.futures import ProcessPoolExecutor, as_completed
from decimal import Decimal
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common  # noqa: E402
import oracles  # noqa: E402
import registry  # noqa: E402
import rule_coverage  # noqa: E402

# The committed regression cases and parity fixtures (default paths of a run).
REGRESSION = HERE / "corpus" / "regression"
RULES = rule_coverage.RULES_DIR
# Case ids and populations of the committed case files, by directory.
FILE_CASES = {REGRESSION: ("rg-", "regression"), RULES: ("rule-", "rules")}

CLASSES = {
    "AGREE_VALID": "no invoice-pro error, officially valid",
    "AGREE_INVALID": "invoice-pro error, officially invalid, the rules match",
    "WRONG_RULE_ID": "both reject the invoice, but invoice-pro names none of the official rules",
    "FALSE_NEGATIVE": "no invoice-pro error, but officially invalid (silently invalid XML)",
    "WARNED": "no invoice-pro error, and only one validator rejects the XML, under rules invoice-pro warns about "
              "as decided (`warned-as` in validator-differences.toml)",
    "FALSE_POSITIVE": "invoice-pro error, but officially valid",
    "STRICTER": "only invoice-pro's own rules (IP-*) reject an officially valid invoice",
    "GUARD_ONLY": "only the XML guard objects: no rule of the registry explains it",
    "CRASH": "the compilation failed",
    "INPUT_ERROR": "the compilation stopped with the expected message about the input (a deliberate check)",
    "NO_XML": "no e-invoice XML attached",
}
# The hard gate: every legal invoice is AGREE_VALID, and no entry of
# known-issues.toml can excuse another class there. The report counts these
# classes separately (silently invalid, falsely blocked, crashed).
HARD = ("FALSE_NEGATIVE", "FALSE_POSITIVE", "CRASH", "GUARD_ONLY")
# Official ids that name no business rule: schema and well-formedness,
# Factur-X structure rules and failures of the validators themselves.
STRUCTURAL = re.compile(r"^(XSD|XML|\?|FX-SCH-.*|MUSTANG-CRASH|KOSIT-.*)$")
# The official validators, in the order of the report.
VALIDATORS = ("mustang", "kosit")
VALIDATOR_NAMES = {"mustang": "Mustang", "kosit": "KoSIT"}
# How Typst reports a `panic(..)` or a failed `assert(..)` of the package.
_DELIBERATE = re.compile(r"^error: (panicked with|assertion failed)", re.M)
TOTALS = {
    "BT-106": "ram:LineTotalAmount",
    "BT-107": "ram:AllowanceTotalAmount",
    "BT-108": "ram:ChargeTotalAmount",
    "BT-109": "ram:TaxBasisTotalAmount",
    "BT-110": "ram:TaxTotalAmount",
    "BT-112": "ram:GrandTotalAmount",
    "BT-115": "ram:DuePayableAmount",
}
_HEADER = re.compile(r"^//\s*(expect|warns|profiles|error|finding|facts):\s*(.*)$")
# Arguments of a regression case that would switch the harness off.
_THEME_ARG = re.compile(r"(?<![\w-])theme\s*:\s*(\S*)")
_ERRORS_ARG = re.compile(r"(?<![\w-])zugferd-errors\s*:\s*([^\s,)]*)")


# ---------------------------------------------------------------- cases


def parse_header(path):
    """The header comments of a case file:

      // expect: <CLASS> [RULE ...]   class and rules invoice-pro must report
      // warns: RULE ...              rules invoice-pro must report as warnings
      // profiles: PROFILE ...        a parity fixture: the profiles it runs in
      // error: <text>                INPUT_ERROR: text of the expected message
      // finding: <id>                audit finding or issue it reproduces
      // facts: {<json>}              oracle facts (see oracles.py), repeatable
    """
    expect, rules, warns, profiles, finding, facts, error = None, [], [], [], None, {}, None
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        m = _HEADER.match(line.strip())
        if not m:
            if line.strip() and not line.startswith("//"):
                break
            continue
        key, value = m.groups()
        if key == "expect":
            parts = value.split()
            expect, rules = parts[0], parts[1:]
        elif key == "warns":
            warns += value.split()
        elif key == "profiles":
            profiles += value.split()
        elif key == "error":
            error = value.strip()
        elif key == "finding":
            finding = value.strip()
        elif key == "facts":
            try:
                facts.update(json.loads(value))
            except json.JSONDecodeError as e:
                raise common.ToolError(f"{path}: invalid `// facts:` JSON: {e}")
    if expect is None:
        raise common.ToolError(f"{path}: no `// expect: <CLASS> [RULE ...]` header")
    if expect not in CLASSES and expect not in UNIONS:
        raise common.ToolError(f"{path}: unknown class {expect!r} (one of {', '.join([*CLASSES, *UNIONS])})")
    if expect == "INPUT_ERROR" and not error:
        raise common.ToolError(f"{path}: `// expect: INPUT_ERROR` needs `// error: <text of the message>`")
    unknown = [p for p in profiles if p not in rule_coverage.PROFILES]
    if unknown or len(set(profiles)) != len(profiles):
        raise common.ToolError(f"{path}: `// profiles:` lists profiles of {', '.join(rule_coverage.PROFILES)}, "
                               f"each once (not {' '.join(profiles)})")
    return {"expect": expect, "expect_rules": rules, "expect_warnings": warns, "expect_error": error,
            "finding": finding, "facts": facts, "profiles": profiles}


def load_cases(paths):
    cases = []
    for path in paths:
        path = Path(path).resolve()
        if path.is_dir() and (path / "manifest.json").exists():
            manifest = json.loads((path / "manifest.json").read_text(encoding="utf-8"))
            for case in manifest["cases"]:
                case["file"] = str(path / f"{case['id']}.typ")
                cases.append(case)
        elif path.is_dir():
            # Files starting with "_" are shared definitions, not cases.
            for file in sorted(path.glob("*.typ")):
                if not file.name.startswith("_"):
                    cases += _file_cases(file)
        elif path.suffix == ".typ":
            cases += _file_cases(path)
        else:
            raise common.ToolError(f"{path}: not a corpus directory or .typ file")
    duplicates = sorted(i for i, n in collections.Counter(c["id"] for c in cases).items() if n > 1)
    if duplicates:
        raise common.ToolError(f"duplicate case ids: {', '.join(duplicates)}")
    return cases


def regression_complete(cases, directory=REGRESSION):
    """Whether the cases include every committed regression case. Together
    they show every documented validator difference, so only such a run can
    tell that a difference no longer occurs; a single case file run on its
    own is a regression case as well, but shows only its own."""
    return _complete(cases, directory, "rg-")


def rules_complete(cases, directory=RULES):
    """Whether the cases include every parity fixture in every one of its
    profiles: only such a run can tell that every rule classified as
    `fixture` has, in each profile, a fixture that passed."""
    return _complete(cases, directory, "rule-")


def _complete(cases, directory, prefix):
    ids = {case["id"] for case in cases}
    for file in Path(directory).glob("*.typ"):
        if file.name.startswith("_"):
            continue
        if prefix == "rule-":
            profiles = parse_header(file)["profiles"]
            wanted = [rule_coverage.fixture_case_id(file, p) for p in profiles] or [f"rule-{file.stem}@?"]
        else:
            wanted = [prefix + file.stem]
        if not all(case in ids for case in wanted):
            return False
    return True


def _file_cases(file):
    """The cases of a committed case file: a regression case, or a parity
    fixture in each profile of its `// profiles:` header, which the
    compilation passes to the fixture (`--input profile=<profile>`, read by
    `fixture-profile` of corpus/rules/_base.typ)."""
    header = parse_header(file)
    text = Path(file).read_text(encoding="utf-8")
    # Without the harness, "no diagnostics attached" would read as "no errors".
    if "harness(" not in text and "..setup" not in text:
        raise common.ToolError(f"{file}: a case must use the harness theme (`..setup` of _base.typ or `harness(..)`)")
    # Nor may the case switch it off after `..setup`: another theme, or a
    # mode other than "report", would silently lose the diagnostics.
    code = "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("//"))
    for m in _THEME_ARG.finditer(code):
        if not m.group(1).startswith("harness("):
            raise common.ToolError(f"{file}: `theme: {m.group(1)}` loses the diagnostics; wrap it: `theme: harness(..)`")
    for m in _ERRORS_ARG.finditer(code):
        if m.group(1) != '"report"':
            raise common.ToolError(f"{file}: the harness needs `zugferd-errors: \"report\"`, not {m.group(1)}")
    # A parity fixture of corpus/rules is a case of its own population; any
    # other case file counts as a regression case.
    prefix, population = FILE_CASES.get(Path(file).resolve().parent, FILE_CASES[REGRESSION])
    case = {
        "id": prefix + file.stem,
        "population": population,
        "file": str(file),
        "features": None,
        "twin": None,
        **header,
    }
    if population != "rules":
        if header["profiles"]:
            raise common.ToolError(f"{file}: only a parity fixture (corpus/rules) runs in several profiles "
                                   "(`// profiles:`)")
        return [case]
    if not header["profiles"]:
        raise common.ToolError(f"{file}: a parity fixture lists the profiles it runs in (`// profiles:`)")
    return [
        dict(case, id=rule_coverage.fixture_case_id(file, profile), profile=profile, inputs={"profile": profile})
        for profile in header["profiles"]
    ]


# ---------------------------------------------------------------- stage 1: Typst


def compile_case(case, out_dir, timestamp=common.DEFAULT_TIMESTAMP):
    """Runs in a worker process: compile, then read XML, diagnostics, text."""
    pdf = Path(out_dir) / f"{case['id']}.pdf"
    ok, stderr, seconds = common.typst_compile(case["file"], pdf, inputs=case.get("inputs"), timestamp=timestamp)
    res = {"id": case["id"], "t_compile": round(seconds, 3)}
    if not ok:
        res["crash"] = stderr.strip()[:4000]
        return res
    try:
        attachments, text = common.read_pdf(pdf)
        diagnostics = attachments.get(common.DIAGNOSTICS_ATTACHMENT)
        data = json.loads(diagnostics) if diagnostics else {}
    except Exception as e:  # a broken PDF or attachment fails this case, not the run
        res["crash"] = f"cannot read the PDF or its diagnostics: {e!r}"
        return res
    res["pdf_text"] = text
    res["diagnostics"] = data.get("diagnostics", [])
    if data:
        profile = data.get("profile") or {}
        res["reported_profile"] = profile.get("id")
        # With `zugferd: auto`, the richer profiles the invoice missed, whose
        # errors the chosen profile lists as warnings.
        res["skipped_profiles"] = profile.get("skipped") or []
    name, xml = common.invoice_xml(attachments)
    if xml is not None:
        xml_path = Path(out_dir) / f"{case['id']}.xml"
        xml_path.write_bytes(xml)
        res["xml_path"] = str(xml_path)
        res["xml_name"] = name
    return res


# ---------------------------------------------------------------- classification


def error_rules(res):
    return sorted({d.get("rule", "?") for d in res.get("diagnostics", []) if d.get("level") == "error"})


def classify(res, official=None):
    """The class of a compiled case against the official verdict, or against
    the view of one validator (`official`, see `Checker.collect`). In such a
    view, an error of invoice-pro on a rule the validator only warns about is
    stricter than the validator, not a false positive."""
    if "crash" in res:
        return "CRASH"
    if "xml_path" not in res:
        return "NO_XML"
    errors = [d for d in res.get("diagnostics", []) if d.get("level") == "error"]
    ours = error_rules(res)
    official = official or res["official"]
    if errors and all(d.get("source") == "guard" for d in errors):
        return "GUARD_ONLY"
    if not ours:
        return "AGREE_VALID" if official["valid"] else "FALSE_NEGATIVE"
    if official["valid"]:
        warned = set(official.get("warned", ()))
        return "STRICTER" if all(r.startswith("IP-") or r in warned for r in ours) else "FALSE_POSITIVE"
    named_official = {r for r in official["rules"] if not STRUCTURAL.match(r)}
    named_ours = {r for r in ours if not r.startswith("IP-")}
    if named_official and named_ours and not named_official & named_ours:
        return "WRONG_RULE_ID"
    return "AGREE_INVALID"


# Expectations that accept several classes.
UNIONS = {
    # invoice-pro and the official validators agree, invoice-pro applies one
    # of its own documented rules or warns as decided, or it stops with its
    # own message about the input (random population).
    "AGREE": ("AGREE_VALID", "AGREE_INVALID", "STRICTER", "WARNED", "INPUT_ERROR"),
    # invoice-pro stops the invoice, whatever the official verdict: for input
    # that must not produce an e-invoice although its XML would be valid.
    "REJECTED": ("AGREE_INVALID", "WRONG_RULE_ID", "STRICTER", "FALSE_POSITIVE"),
}


def warning_rules(res):
    return sorted({d.get("rule", "?") for d in res.get("diagnostics", []) if d.get("level") != "error"})


def warned_as_decided(res, differences):
    """Whether an XML invoice-pro accepts is officially invalid only because
    one validator rejects it under rules that invoice-pro, as the maintainer
    decided, reports as a warning (`warned-as` of validator-differences.toml),
    e.g. a currency that only the newest EN 16931 code list of KoSIT has
    withdrawn: the XSD accepts it, the other validator accepts it, and
    invoice-pro warns of every rule behind the disagreement."""
    official = res.get("official") or {}
    dis = official.get("disagreement")
    if not dis or not dis["rules"] or res.get("xsd_errors"):
        return False
    warned = set(warning_rules(res))
    for rule in dis["rules"]:
        entry = (differences or {}).get(rule)
        if not entry or dis["rejected_by"] not in entry["rejected-by"] or entry.get("warned-as") not in warned:
            return False
    return True


def expectation_met(case, cls, ours, warned=()):
    """Whether the class is the expected one, and the expected rules that
    invoice-pro did not report: errors (`// expect:`) and warnings
    (`// warns:`, listed with the prefix "warning:")."""
    expect = case["expect"]
    class_ok = cls in UNIONS[expect] if expect in UNIONS else cls == expect
    missing = [r for r in case.get("expect_rules", []) if r not in ours]
    missing += [f"warning:{r}" for r in case.get("expect_warnings", []) if r not in warned]
    return class_ok, missing


def signature(row):
    """Class, rules and failed oracles of a failing case, e.g.
    `FALSE_NEGATIVE missing=BR-AG-05 ours=- official=BR-AG-05`. The rules are
    only part of it when the class or the reported rules are wrong."""
    parts = [row["cls"]]
    if row["missing_rules"]:
        parts.append("missing=" + ",".join(row["missing_rules"]))
    if not row["class_ok"] or row["missing_rules"]:
        parts.append("ours=" + (",".join(row["ours"]) or "-"))
        parts.append("official=" + (",".join(row["official"]) or "-"))
    ids = sorted({p.split(":")[0] for p in row["oracle"]})
    if ids:
        parts.append("oracle=" + ",".join(ids))
    undocumented = (row.get("disagreement") or {}).get("undocumented")
    if undocumented:
        parts.append(f"OFFICIAL_DISAGREE only-{row['disagreement']['rejected_by']}=" + ",".join(undocumented))
    return " ".join(parts)


def totals(doc):
    out = {}
    for bt, element in TOTALS.items():
        value = common.xtext1(doc, oracles.SUMMATION + "/" + element)
        if value is not None:
            out[bt] = common.dec(value)
    return out


def bundle_total(doc):
    total, count = Decimal(0), 0
    for line in doc.xpath(oracles.LINES, namespaces=common.NS):
        name = line.xpath("ram:SpecifiedTradeProduct/ram:Name/text()", namespaces=common.NS)
        if name and oracles._split_bracket(name[0])[0] == "Paket":
            amount = line.xpath(
                "ram:SpecifiedLineTradeSettlement/ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount/text()",
                namespaces=common.NS,
            )
            total += common.dec(amount[0], Decimal(0)) if amount else Decimal(0)
            count += 1
    return total, count


def metamorphic(rows, docs, cases_by_id):
    """Relations between twins: problems are added to the twin's row."""
    rows_by_id = {row["id"]: row for row in rows}
    for row in rows:
        twin = cases_by_id[row["id"]].get("twin")
        if not twin:
            continue
        other = twin["of"]
        if other not in docs or row["id"] not in docs:
            continue
        if row["cls"] != "AGREE_VALID" or rows_by_id[other]["cls"] != "AGREE_VALID":
            continue
        relation = twin["relation"]
        if relation == "bundle-quantity":
            one, n1 = bundle_total(docs[row["id"]])
            two, n2 = bundle_total(docs[other])
            if abs(two - 2 * one) > Decimal("0.01") * max(1, n1, n2):
                row["oracle"].append(f"O-META-bundle-quantity: quantity 2 gives {two}, 2 x quantity 1 gives {2 * one}")
        elif relation == "same-totals":
            a, b = totals(docs[row["id"]]), totals(docs[other])
            diff = {bt: (a[bt], b[bt]) for bt in a.keys() & b.keys() if a[bt] != b[bt]}
            if diff:
                shown = ", ".join(f"{bt} {x} vs {y}" for bt, (x, y) in sorted(diff.items()))
                row["oracle"].append(f"O-META-same-totals: differs from {other}: {shown}")


# ---------------------------------------------------------------- known issues


def load_known(path):
    if not path or not Path(path).exists():
        return []
    data = tomllib.loads(Path(path).read_text(encoding="utf-8"))
    entries = data.get("issue", [])
    for entry in entries:
        if "finding" not in entry or "signatures" not in entry:
            raise common.ToolError(f"{path}: every [[issue]] needs `finding` and `signatures`")
        features = entry.get("features")
        if features is not None and (not isinstance(features, dict) or not features):
            raise common.ToolError(f"{path}: `features` of {entry['finding']} must be a non-empty table")
    return entries


def covers(entry, row):
    """Whether a known-issue entry applies to a case: the case id matches one
    of its `cases` globs, and the generator features have the values its
    `features` table names (a value or a list of values per dimension).
    Cases without features (regression cases) never match `features`."""
    globs = entry.get("cases")
    if globs and not any(fnmatch.fnmatchcase(row["id"], g) for g in globs):
        return False
    wanted = entry.get("features")
    if not wanted:
        return True
    features = row.get("features") or {}
    for dim, values in wanted.items():
        if dim not in features or features[dim] not in (values if isinstance(values, list) else [values]):
            return False
    return True


def match_known(row, entries):
    """(index of the entry, signature) that explains a failing row, or None."""
    for index, entry in enumerate(entries):
        if row["signature"] in entry["signatures"] and covers(entry, row):
            return index, row["signature"]
    return None


# ---------------------------------------------------------------- validator differences


def load_differences(path):
    """{rule: entry} of validator-differences.toml: the rules on which Mustang
    and KoSIT are known to disagree, with the validator that rejects and why.
    `rejected-by` and `other` become lists: which validator rejects a rule,
    and what the other one reports, may depend on the document (e.g. on the
    code of a code list that only one of them has)."""
    if not path or not Path(path).exists():
        return {}
    data = tomllib.loads(Path(path).read_text(encoding="utf-8"))
    for rule, entry in data.items():
        if not isinstance(entry, dict):
            raise common.ToolError(f"{path}: [{rule}] must be a table")
        rejected = entry.get("rejected-by")
        rejected = rejected if isinstance(rejected, list) else [rejected]
        if not rejected or any(name not in VALIDATORS for name in rejected):
            raise common.ToolError(f"{path}: [{rule}] needs `rejected-by = \"mustang\"` or `\"kosit\"` (or a list of both)")
        entry["rejected-by"] = rejected
        # What the other validator reports: one level, or a list of them.
        other = entry.get("other")
        others = other if isinstance(other, list) else [other]
        if not others or any(level not in ("warning", "nothing") for level in others):
            raise common.ToolError(f"{path}: [{rule}] needs `other = \"warning\"` or `\"nothing\"` (or a list of both)")
        entry["other"] = others
        if not entry.get("reason"):
            raise common.ToolError(f"{path}: [{rule}] needs a `reason`")
        # The rule invoice-pro warns of instead, where the maintainer decided
        # that it accepts what only the rejecting validator rejects.
        warned = entry.get("warned-as")
        if warned is not None and not (isinstance(warned, str) and warned.startswith("IP-")):
            raise common.ToolError(f"{path}: [{rule}] `warned-as` must name a rule of invoice-pro (IP-*)")
    return data


def documented(rule, rejected_by, other, differences):
    """Whether validator-differences.toml documents this disagreement: the
    rule, the validator that rejects it and what the other one reports."""
    entry = differences.get(rule)
    return bool(entry) and rejected_by in entry["rejected-by"] and other in entry["other"]


def disagreement(official):
    """How Mustang and KoSIT disagree on a document both validated, or None:
    the validator that rejects it, and the rules it reports as errors that
    the other one does not (with what the other one reports for each)."""
    views = official.get("validators", {})
    mustang, kosit = views.get("mustang"), views.get("kosit")
    if not mustang or not kosit or mustang["valid"] == kosit["valid"]:
        return None
    rejecting, other = ("mustang", kosit) if not mustang["valid"] else ("kosit", mustang)
    rules = sorted(set(views[rejecting]["rules"]) - set(other["rules"]))
    return {
        "rejected_by": rejecting,
        "rules": rules,
        "other": {rule: "warning" if rule in other.get("warned", ()) else "nothing" for rule in rules},
    }


# ---------------------------------------------------------------- main


class Checker:
    """The official side: XSD with lxml, Schematron with Mustang (one JVM for
    the run, streaming) and KoSIT (one JVM per batch)."""

    def __init__(self, cache_dir, use_mustang=True, use_kosit=True):
        jar = common.mustang_jar() if use_mustang or os.environ.get("MUSTANG_JAR") else None
        self.kosit = common.Kosit(*common.kosit_setup(), cache_dir) if use_kosit else None
        self.schemas = common.Schemas(jar, cache_dir) if jar else None
        self.mustang = common.Mustang(jar, cache_dir) if use_mustang else None
        self.mustang_version = common.jar_version(jar, "org.mustangproject/Mustang-CLI") if jar else None

    def describe(self):
        """The official validators of this run, for the report."""
        parts = ["XSD (Factur-X 1.0.07)" if self.schemas else "no XSD"]
        if self.mustang:
            parts.append(f"Mustang {self.mustang_version or '(unknown version)'}")
        if self.kosit:
            parts.append(self.kosit.describe())
        return ", ".join(parts)

    def submit(self, res):
        """Parses the XML of a compiled case, checks the XSD and queues it for
        Mustang. Returns the parsed document (or None)."""
        if "xml_path" not in res:
            return None
        try:
            doc = common.parse_xml(Path(res["xml_path"]).read_bytes())
        except Exception as e:  # not well-formed: an official error as well
            res["xml_error"] = str(e)
            return None
        if self.schemas:
            res["profile"], res["xsd_errors"] = self.schemas.validate(doc)
        else:
            guideline = common.xtext1(doc, common.GUIDELINE_PATH)
            res["profile"], res["xsd_errors"] = common.GUIDELINES.get(guideline, (None,))[0], []
        if self.mustang:
            res["_future"] = self.mustang.submit(res["xml_path"])
        return doc

    def validate_kosit(self, results):
        """Validates the XML of the EN 16931 and XRechnung documents among the
        compiled cases with KoSIT, in one JVM; sets `res["kosit"]`. The other
        profiles have no KoSIT scenario. Returns the number of files."""
        if not self.kosit:
            return 0
        batch = {res["xml_path"]: res for res in results
                 if "xml_path" in res and "xml_error" not in res and res.get("profile") in common.KOSIT_PROFILES}
        reports = self.kosit.validate(list(batch))
        for path, res in batch.items():
            report = reports[str(Path(path).resolve())]
            if report["status"] == "no-scenario":
                # The configuration has scenarios for both profiles: a
                # document of them that matches none is not what it claims.
                report = dict(report, status="reject",
                              errors={"KOSIT-NO-SCENARIO": f"no KoSIT scenario for this {res['profile']} document"})
            res["kosit"] = report
        return len(batch)

    @staticmethod
    def collect(res):
        """Waits for Mustang and sets `res["official"]`: the verdict of all
        official validators together, and the view of each one."""
        future = res.pop("_future", None)
        if future:
            res["mustang"] = future.result()
        if "xml_path" not in res:
            return
        xsd_errors = res.get("xsd_errors", [])
        if "xml_error" in res:
            xsd_errors = res["xsd_errors"] = ["not well-formed: " + res["xml_error"]]
        views = {}
        m = res.get("mustang")
        if m:
            views["mustang"] = {
                "valid": m["status"] == "valid" and not m["errors"],
                "rules": sorted(m["errors"]),
                "warned": sorted({w.split(":")[0] for w in m["warnings"]}),
            }
        k = res.get("kosit")
        if k:
            views["kosit"] = {
                "valid": k["status"] == "accept",
                "rules": sorted(k["errors"]),
                "warned": sorted(k["warnings"]),
                "informed": sorted(k.get("information", ())),
                # KoSIT runs no Schematron on a document that fails the schema.
                "schematron": k.get("schematron", True),
            }
        rules = set().union(*(set(v["rules"]) for v in views.values()))
        res["official"] = {
            "valid": not xsd_errors and all(v["valid"] for v in views.values()),
            "rules": sorted(rules | ({"XSD"} if xsd_errors else set())),
            "validators": views,
        }
        res["official"]["disagreement"] = disagreement(res["official"])

    def close(self):
        if self.mustang:
            self.mustang.close()


def make_row(case, res, doc, differences=None):
    """Classification, expectation and oracles of one evaluated case."""
    cls = classify(res)
    if cls == "FALSE_NEGATIVE" and warned_as_decided(res, differences):
        cls = "WARNED"
    # A deliberate stop on invalid input is not a crash: when it is the
    # message the case expects, or, for random input, any message of a
    # `panic` or `assert` of invoice-pro (not a runtime error of Typst).
    if cls == "CRASH":
        if case.get("expect_error"):
            cls = "INPUT_ERROR" if case["expect_error"] in res["crash"] else cls
        elif case["expect"] == "AGREE" and _DELIBERATE.search(res["crash"]):
            cls = "INPUT_ERROR"
    ours = error_rules(res)
    class_ok, missing = expectation_met(case, cls, ours, warning_rules(res))
    problems = oracles.check_diagnostics(res.get("diagnostics", []))
    if cls == "AGREE_VALID" and doc is not None:
        problems += oracles.check(case.get("facts") or {}, doc, res.get("pdf_text"), res.get("profile"))
    mustang = res.get("mustang") or {}
    official = res.get("official", {})
    # The class against each validator on its own, e.g. STRICTER than KoSIT
    # for a rule KoSIT only warns about, next to AGREE_INVALID with Mustang.
    validators = {name: dict(view, cls=classify(res, view)) for name, view in official.get("validators", {}).items()}
    return {
        "id": case["id"],
        "population": case["population"],
        "finding": case.get("finding"),
        "cls": cls,
        "expect": case["expect"],
        "class_ok": class_ok,
        "missing_rules": missing,
        "ours": ours,
        "official": official.get("rules", []),
        "validators": validators,
        "disagreement": official.get("disagreement"),
        "profile": res.get("profile"),
        "oracle": problems,
        "diagnostics": res.get("diagnostics", []),
        "xsd_errors": res.get("xsd_errors", [])[:5],
        "official_messages": [
            [name, rule, message]
            for name, report in (("mustang", mustang), ("kosit", res.get("kosit") or {}))
            for rule, message in report.get("errors", {}).items()
        ],
        "crash": res.get("crash"),
        "t_compile": res.get("t_compile"),
        "t_mustang_ms": mustang.get("ms"),
        "features": case.get("features"),
        "file": case["file"],
    }


def fixture_parity(case, res, levels, differences):
    """Problems of a parity fixture (corpus/rules/<RULE>.typ) in one of its
    profiles: the document is one of that profile, and each official
    validator whose artefacts have the rule in the profile reports it, and
    so for every official rule the fixture expects
    invoice-pro to report (normally the same one; a rule of the same
    violation where invoice-pro reports that instead, see `reported-as` in
    rule-coverage.toml). A validator reports a rule of its warning or
    information level at that level. A validator that does not report a rule
    documented in validator-differences.toml as rejected by the other one
    only is fine, and so is one that ran no Schematron (KoSIT stops at a
    schema error); at least one validator must report the rule, though. A
    passing counterpart (<RULE>--pass.typ) has nothing to compare. `levels`:
    {profile: {rule: {validator: level}}} of the validators
    (rule_coverage.rule_levels)."""
    rule, passing = rule_coverage.fixture_rule(case["file"])
    profile = res.get("profile")
    wanted_profile = case.get("profile")
    if wanted_profile and "xml_path" in res and profile != wanted_profile:
        # The source must take the profile of the run: `zugferd: fixture-profile(..)`.
        return [f"O-PARITY: the fixture ran as {profile or 'an unknown profile'}, not as {wanted_profile} "
                "(`zugferd: fixture-profile(..)`)"]
    if passing or profile not in levels:
        return []
    views = (res.get("official") or {}).get("validators", {})
    expected = [*case.get("expect_rules", []), *case.get("expect_warnings", [])]
    wanted = [r for r in dict.fromkeys([rule, *expected]) if not r.startswith("IP-")]
    problems = []
    for r in wanted:
        have = levels[profile].get(r)
        if not have:
            problems.append(f"O-PARITY: no official validator of the {profile} profile has {r}")
            continue
        reported = False
        for validator, level in sorted(have.items()):
            view = views.get(validator)
            if view is None or not view.get("schematron", True):
                continue  # it did not run, has no scenario for the profile, or stopped at the schema
            if r in view["rules"] or (level != "error" and r in (*view.get("warned", ()), *view.get("informed", ()))):
                reported = True
                continue
            entry = differences.get(r)
            if entry and validator not in entry["rejected-by"]:
                continue
            problems.append(f"O-PARITY: {VALIDATOR_NAMES[validator]} does not report {r} ({level} in its artefacts)")
            reported = True  # the problem says it already
        if not reported:
            problems.append(f"O-PARITY: no official validator reports {r}")
    return problems


def foreign_rule_problems(res, levels):
    """The backward check of every case: an error of invoice-pro that names a
    rule the official validators of the profile do not have (a wrong id, or
    a rule of another profile). invoice-pro's own rules are IP-*."""
    profile = res.get("profile")
    if profile not in levels:
        return []
    return [
        f"O-RULE: invoice-pro reports {rule}, which no official validator of the {profile} profile has"
        for rule in rule_coverage.foreign_rules(res, levels)
    ]


def registry_rule_problems(res, reported):
    """The check of the tests' harness (tests/zugferd/harness.typ) in every
    case: each diagnostic names a rule that the rule registry reports in the
    case's profile (its `profiles` and `id-profiles`, see
    registry.reported_in). With `zugferd: auto`, a warning may name a rule of
    a richer profile the invoice missed (`skipped_profiles`, e.g. BR-DE-1 of
    XRechnung on an EN 16931 invoice), whose errors the chosen profile lists
    as warnings (src/zugferd/zugferd.typ). `reported`: {profile: {rule id}}."""
    profile = res.get("profile")
    if profile not in reported:
        return []
    missed = set()
    for other in res.get("skipped_profiles") or ():
        missed |= reported.get(other, set())
    rules = {
        d.get("rule")
        for d in res.get("diagnostics", [])
        if not (d.get("level") == "warning" and d.get("rule") in missed)
    }
    return [
        f"O-REGISTRY: invoice-pro reports {rule}, which the rule registry does not list in the {profile} profile"
        for rule in sorted(rules - reported[profile], key=str)
    ]


def rule_levels(checker, use_kosit):
    """{profile: {rule: {validator: level}}} of the official validators of
    this run, or None without the Mustang jar (the rule checks are skipped
    then, and the report says so)."""
    jar = os.environ.get("MUSTANG_JAR")
    if not jar:
        return None
    config = checker.kosit.config if use_kosit and checker.kosit else None
    try:
        return rule_coverage.rule_levels(jar, config)
    except rule_coverage.CoverageError as e:
        raise common.ToolError(f"the rule inventory for the rule checks: {e}")


def run(cases, jobs, out_dir, use_mustang, known, strict, check_xpass, use_kosit=True, differences=None,
        check_stale=False, check_fixtures=False):
    started = time.perf_counter()
    checker = Checker(out_dir.parent, use_mustang, use_kosit)
    levels = rule_levels(checker, use_kosit)
    try:
        results, docs = {}, {}
        t_compile = time.perf_counter()
        # Typst runs in worker processes; the XSD check and the queueing for
        # Mustang happen here as soon as a case is compiled, so the JVM
        # validates while Typst still compiles.
        # "spawn": the workers must not inherit the JVM's pipes or the reader thread.
        with ProcessPoolExecutor(jobs, mp_context=multiprocessing.get_context("spawn")) as pool:
            pending = [pool.submit(compile_case, case, str(out_dir)) for case in cases]
            for done in as_completed(pending):
                res = done.result()
                results[res["id"]] = res
                doc = checker.submit(res)
                if doc is not None:
                    docs[res["id"]] = doc
        t_compile = time.perf_counter() - t_compile
        # KoSIT validates the whole batch in one JVM, while Mustang works off
        # what is left in its queue.
        t_kosit = time.perf_counter()
        kosit_files = checker.validate_kosit(results.values())
        t_kosit = time.perf_counter() - t_kosit
        t_wait = time.perf_counter()
        for res in results.values():
            checker.collect(res)
        t_wait = time.perf_counter() - t_wait
    finally:
        checker.close()

    rows = [make_row(case, results[case["id"]], docs.get(case["id"]), differences) for case in cases]
    metamorphic(rows, docs, {c["id"]: c for c in cases})
    try:
        rules_registry = registry.load()
    except ValueError as e:
        raise common.ToolError(f"the rule registry: {e}")
    reported = {p: set(registry.reported_in(rules_registry, p)) for p in registry.PROFILES}
    for case, row in zip(cases, rows):
        row["oracle"] += registry_rule_problems(results[case["id"]], reported)
    if levels is not None:
        for case, row in zip(cases, rows):
            res = results[case["id"]]
            row["oracle"] += foreign_rule_problems(res, levels)
            if case["population"] == "rules":
                row["oracle"] += fixture_parity(case, res, levels, differences or {})

    failures, hits, xpass, stale = triage(rows, known, strict, check_xpass, differences, check_stale)
    coverage = []
    if check_fixtures and levels is not None:
        entries, _, _ = rule_coverage.load_toml()
        fixtures, _ = rule_coverage.fixture_files()
        coverage = rule_coverage.fixture_results(rows, entries, fixtures, levels)
    timing = {
        "total_s": round(time.perf_counter() - started, 1),
        "compile_s": round(t_compile, 1),
        "kosit_s": round(t_kosit, 1),
        "kosit_files": kosit_files,
        "mustang_wait_s": round(t_wait, 1),
        "jobs": jobs,
        "validators": checker.describe(),
        "rule_checks": levels is not None,
        "coverage": coverage,
    }
    return rows, failures, hits, xpass, stale, timing


def breaks_hard_gate(row):
    """A legal invoice that is not AGREE_VALID (silently invalid, blocked by
    invoice-pro, crashed, no XML), or WARNED as decided: never excused by
    known issues. Oracle failures of valid legal invoices can be known
    issues."""
    return row.get("population") == "legal" and row["cls"] not in ("AGREE_VALID", "WARNED")


def triage(rows, known, strict=False, check_xpass=True, differences=None, check_stale=False):
    """Sets verdict and signature of every row and sorts the failures into
    new ones and known issues. Returns (new failures, [(entry, signature,
    case ids)], [(entry, signature)] of listed signatures that did not occur,
    [rule] of documented validator differences that did not occur).

    A disagreement of Mustang and KoSIT on a rule that `differences` does not
    document with the rejecting validator fails the case: it is no bug of
    invoice-pro that known-issues.toml could list, but a difference of the
    official validators to understand and document. `check_stale`: the run
    has every committed regression case (`regression_complete`), so every
    documented difference must occur.
    """
    differences = differences or {}
    failures, known_hits, seen, shown = [], {}, set(), set()
    for row in rows:
        dis = row.get("disagreement")
        if dis:
            known_rules = [r for r in dis["rules"] if documented(r, dis["rejected_by"], dis["other"][r], differences)]
            shown.update(known_rules)
            dis["undocumented"] = [r for r in dis["rules"] if r not in known_rules]
        undocumented = bool(dis and dis["undocumented"])
        passed = (row["class_ok"] and not row["missing_rules"] and not row["oracle"] and not breaks_hard_gate(row)
                  and not undocumented)
        row["verdict"] = "PASS" if passed else "FAIL"
        if row["verdict"] == "FAIL":
            row["signature"] = signature(row)
            hit = None if strict else match_known(row, known)
            if hit:
                seen.add(hit)  # the issue still occurs, excused or not
            if hit and not breaks_hard_gate(row) and not undocumented:
                row["known"] = known[hit[0]]["finding"]
                known_hits.setdefault(hit, []).append(row["id"])
            else:
                failures.append(row)
    # Every listed signature must still occur, so the list can only shrink.
    # Entries that cover no case of this run are left alone.
    xpass, stale = [], []
    if not strict and check_xpass:
        for index, entry in enumerate(known):
            if not any(covers(entry, row) for row in rows):
                continue
            for sig in entry["signatures"]:
                if (index, sig) not in seen:
                    xpass.append((entry, sig))
    # Every documented difference is shown by a case, so that the
    # documentation stays true: checked on a run of all regression cases,
    # which have a case for every difference, with both validators.
    if check_stale and any(len(row.get("validators") or {}) == len(VALIDATORS) for row in rows):
        stale = sorted(rule for rule in differences if rule not in shown)
    hits = [(known[index], sig, ids) for (index, sig), ids in known_hits.items()]
    return failures, hits, xpass, stale


def _stop_message(crash):
    """The start of the message of a deliberate stop without its numbers,
    e.g. `The modifier `Versand` (#.#) cannot be split over the VAT
    categories`, so that stops of one kind form one group."""
    first = next((line for line in (crash or "").splitlines() if line.startswith("error:")), crash or "")
    first = _DELIBERATE.sub("", first).lstrip(': "')
    return re.sub(r"\d+", "#", first)[:70].rstrip()


def _disagreements(rows, differences):
    """Lines of the report on the documented disagreements of Mustang and
    KoSIT, grouped by the rules and by what invoice-pro does."""
    groups = {}
    for row in rows:
        dis = row.get("disagreement")
        if not dis or dis.get("undocumented"):
            continue
        key = (dis["rejected_by"], tuple(dis["rules"]), tuple(dis["other"][r] for r in dis["rules"]), bool(row["ours"]),
               row["cls"] == "WARNED")
        groups.setdefault(key, []).append(row["id"])
    lines = []
    for (rejecting, rules, others, ours, warned), ids in sorted(groups.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        other = "KoSIT" if rejecting == "mustang" else "Mustang"
        said = ", ".join(sorted(set(others)))
        if ours:
            verdict = f"invoice-pro reports an error (stricter than {other})"
        elif warned:
            verdict = "invoice-pro warns, as decided (WARNED)"
        else:
            verdict = "invoice-pro reports NO error (FALSE_NEGATIVE)"
        lines.append(f"  [{len(ids):3d}] only {VALIDATOR_NAMES[rejecting]} rejects {', '.join(rules)} "
                     f"({other}: {said}); {verdict}")
        lines.append(f"        cases: {' '.join(ids[:8])}{' ...' if len(ids) > 8 else ''}")
    return lines


def report(rows, failures, known_hits, xpass, timing, use_mustang, stale=(), use_kosit=True, differences=None):
    lines = []
    by_pop = {}
    for row in rows:
        by_pop.setdefault(row["population"], {}).setdefault(row["cls"], 0)
        by_pop[row["population"]][row["cls"]] += 1
    lines.append(f"cases: {len(rows)}   time: {timing['total_s']} s (compile {timing['compile_s']} s with "
                 f"{timing['jobs']} jobs, KoSIT {timing.get('kosit_s', 0)} s for {timing.get('kosit_files', 0)} "
                 f"files, then waiting for Mustang {timing['mustang_wait_s']} s)")
    if timing.get("validators"):
        lines.append(f"official verdict: {timing['validators']}")
    if not use_mustang:
        lines.append("WARNING: --no-mustang: Mustang did not run; the classes are NOT the official verdict")
    if not use_kosit:
        lines.append("WARNING: --no-kosit: KoSIT did not run; the classes are NOT the official verdict")
    if timing.get("rule_checks") is False:
        lines.append("WARNING: without MUSTANG_JAR, the rule ids of invoice-pro were not checked (O-RULE, O-PARITY)")
    for pop, counts in sorted(by_pop.items()):
        shown = ", ".join(f"{k} {v}" for k, v in sorted(counts.items(), key=lambda kv: -kv[1]))
        lines.append(f"  {pop:12s} {sum(counts.values()):4d}: {shown}")
    legal = [r for r in rows if r["population"] == "legal"]
    hard = {c: sum(1 for r in legal if r["cls"] == c) for c in HARD}
    broken = sum(1 for r in legal if breaks_hard_gate(r))
    lines.append(("HARD GATE BROKEN" if broken else "hard gate") + " (legal population, never a known issue): "
                 + ", ".join(f"{c} {n}" for c, n in hard.items()) + f", not AGREE_VALID {broken}")
    # Deliberate stops are accepted in the random population; list their
    # messages, so that a new kind (maybe a valid invoice it blocks) is seen.
    stops = collections.Counter(_stop_message(r["crash"]) for r in rows if r["cls"] == "INPUT_ERROR")
    if stops:
        lines.append("deliberate stops (INPUT_ERROR) by message:")
        lines += [f"  [{n:3d}] {message}" for message, n in stops.most_common()]
    oracle_fail = sum(1 for r in rows if r["oracle"])
    lines.append(f"PASS {sum(r['verdict'] == 'PASS' for r in rows)}  FAIL {sum(r['verdict'] == 'FAIL' for r in rows)}"
                 f"  (known issues {sum(len(ids) for _, _, ids in known_hits)}, oracle failures {oracle_fail})")
    documented = _disagreements(rows, differences or {})
    if documented:
        lines.append("\nMustang and KoSIT disagree (documented in validator-differences.toml):")
        lines += documented
    if known_hits:
        lines.append("\nKnown issues (known-issues.toml):")
        for entry, sig, ids in sorted(known_hits, key=lambda e: (e[0]["finding"], e[1])):
            lines.append(f"  [{len(ids):3d}] {entry['finding']}: {sig}")
            lines.append(f"        cases: {' '.join(ids[:8])}{' ...' if len(ids) > 8 else ''}")
    if xpass:
        lines.append("\nXPASS - known issues that no longer occur; remove them from known-issues.toml:")
        for entry, sig in xpass:
            lines.append(f"  {entry['finding']}: {sig!r}")
    if stale:
        lines.append("\nSTALE - documented validator differences that no case shows any more; remove them from "
                     "validator-differences.toml (or add a regression case that shows them):")
        lines += [f"  {rule}" for rule in stale]
    coverage = timing.get("coverage") or []
    if coverage:
        lines.append("\nRULE COVERAGE - rules classified as `fixture` in rule-coverage.toml without a fixture "
                     "that passed:")
        lines += [f"  {problem}" for problem in coverage]
    if failures:
        groups = {}
        for row in failures:
            groups.setdefault(row["signature"], []).append(row)
        lines.append(f"\nNEW FAILURES ({len(failures)} cases, {len(groups)} signatures):")
        for sig, group in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            ids = [r["id"] for r in group]
            lines.append(f"  [{len(ids):3d}] {sig}")
            lines.append(f"        cases: {' '.join(ids[:10])}{' ...' if len(ids) > 10 else ''}")
            ex = group[0]
            lines.append(f"        example: {ex['file']}")
            for p in ex["oracle"][:3]:
                lines.append(f"        oracle: {p[:300]}")
            dis = ex.get("disagreement") or {}
            if dis.get("undocumented"):
                other = dis["other"]
                lines.append(f"        only {VALIDATOR_NAMES[dis['rejected_by']]} rejects: "
                             + ", ".join(f"{r} (the other: {other[r]})" for r in dis["undocumented"])
                             + "; document it in validator-differences.toml")
            for name, rule, msg in ex["official_messages"][:4]:
                lines.append(f"        {VALIDATOR_NAMES.get(name, name)} [{rule}]: {msg[:200]}")
            for d in ex["diagnostics"][:3]:
                if d.get("level") == "error":
                    lines.append(f"        invoice-pro [{d.get('rule')}] {d.get('field')}: {str(d.get('message'))[:200]}")
            for e in ex["xsd_errors"][:2]:
                lines.append(f"        xsd: {e[:200]}")
            if ex["crash"]:
                crash = [l for l in ex["crash"].splitlines() if l.strip()]
                lines.append("        crash: " + " | ".join(crash[:3])[:400])
    ok = not failures and not xpass and not stale and not coverage
    lines.append("\n" + ("OK: no new failures" if ok else
                         "FAILED: see NEW FAILURES / XPASS / STALE / RULE COVERAGE above "
                         "(tests/TESTING.md explains the triage)"))
    return "\n".join(lines), ok


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*", help="corpus directories or .typ files")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2, help="parallel Typst compilations")
    ap.add_argument("--build-dir", default=None, help="default: $ZUGFERD_BUILD_DIR or <repo>/build/zugferd")
    ap.add_argument("--known-issues", default=str(HERE / "known-issues.toml"))
    ap.add_argument("--only", default=None, help="comma separated case ids (glob patterns allowed)")
    ap.add_argument("--population", default=None, help="only cases of these populations (comma separated)")
    ap.add_argument("--strict", action="store_true", help="known issues fail too")
    ap.add_argument("--no-mustang", action="store_true", help="skip Mustang (not the official verdict; refused in CI)")
    ap.add_argument("--no-kosit", action="store_true", help="skip KoSIT (not the official verdict; refused in CI)")
    ap.add_argument("--validator-differences", default=str(HERE / "validator-differences.toml"))
    ap.add_argument("--json", default=None, help="write the results to this file (default: <build>/results.json)")
    args = ap.parse_args(argv)
    try:
        # CI must always give the official verdict: skipping a validator is
        # only a shortcut for a local run.
        skipped = [flag for flag, on in (("--no-mustang", args.no_mustang), ("--no-kosit", args.no_kosit)) if on]
        if skipped and common.in_ci():
            raise common.ToolError(f"{' and '.join(skipped)} in CI: the corpus needs the official verdict")
        build = common.build_dir(args.build_dir)
        paths = args.paths or [p for p in (build / "corpus", REGRESSION, RULES) if p.exists()]
        cases = load_cases(paths)
        subset = False
        if args.only:
            globs = args.only.split(",")
            cases = [c for c in cases if any(fnmatch.fnmatchcase(c["id"], g) for g in globs)]
            subset = True
        if args.population:
            wanted = set(args.population.split(","))
            cases = [c for c in cases if c["population"] in wanted]
            subset = True
        if not cases:
            raise common.ToolError("no cases to run")
        for case in cases:
            common.require_under_root(case["file"])
        out_dir = build / "out"
        out_dir.mkdir(parents=True, exist_ok=True)
        known = load_known(args.known_issues)
        differences = load_differences(args.validator_differences)
        # Only a run of every committed case can tell that a documented
        # difference or a fixture of the rule coverage no longer shows.
        complete = not subset and regression_complete(cases) and rules_complete(cases)
        rows, failures, known_hits, xpass, stale, timing = run(
            cases, args.jobs, out_dir, not args.no_mustang, known, args.strict, check_xpass=not subset,
            use_kosit=not args.no_kosit, differences=differences, check_stale=complete,
            check_fixtures=not subset and rules_complete(cases),
        )
    except common.ToolError as e:
        print(f"error: {e}", file=sys.stderr)
        if not args.no_kosit and "KOSIT_" in str(e):
            print("For a quick local run without KoSIT, pass --no-kosit (not the official verdict).", file=sys.stderr)
        return 2
    text, ok = report(rows, failures, known_hits, xpass, timing, not args.no_mustang, stale,
                      not args.no_kosit, differences)
    print(text)
    out = Path(args.json) if args.json else build / "results.json"
    out.write_text(json.dumps({"timing": timing, "cases": rows}, indent=1, ensure_ascii=False, default=str), encoding="utf-8")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("## E-invoice conformance corpus\n\n```\n" + text + "\n```\n")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
