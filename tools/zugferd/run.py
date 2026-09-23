#!/usr/bin/env python3
"""Conformance runner: invoice-pro's verdict against the official validators.

  run.py [PATH ...] [--jobs N] [--only ID,..] [--strict] [--no-mustang]

PATH is a generated corpus (a directory with `manifest.json`, see
corpus/gen.py), a directory of regression cases, or single `.typ` files.
Default: <build dir>/corpus (when generated) and corpus/regression.

For every case:
  1. Typst, once: `zugferd-errors: "report"` with the harness theme
     (harness.typ), which attaches invoice-pro's diagnostics as JSON. The
     e-invoice XML, the diagnostics and the PDF text are read from the PDF.
  2. XSD of the profile (lxml; the Factur-X XSDs come from the Mustang jar).
  3. Mustang 2.14 (EN 16931, Factur-X and XRechnung Schematron) in a single
     JVM for the whole run (java/MustangBatch.java, compiled on first use).
  4. Classification (see CLASSES), the case's expectation, the semantic
     oracles (oracles.py), the metamorphic relations between twins, and
     that every error of invoice-pro names its rule, field and a hint.

Failures are grouped by signature. `known-issues.toml` lists the signatures
of known bugs with their finding: a known signature does not fail the run,
an unknown one does, and so does a known one that no longer occurs (xpass),
so the list can only shrink. `--strict` ignores the list. The hard gates
(HARD on the legal population) cannot be excused by the list.

Exit code: 0 all green (or only known issues), 1 failures, 2 setup error.
"""

import argparse
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

CLASSES = {
    "AGREE_VALID": "no invoice-pro error, officially valid",
    "AGREE_INVALID": "invoice-pro error, officially invalid, the rules match",
    "WRONG_RULE_ID": "both reject the invoice, but invoice-pro names none of the official rules",
    "FALSE_NEGATIVE": "no invoice-pro error, but officially invalid (silently invalid XML)",
    "FALSE_POSITIVE": "invoice-pro error, but officially valid",
    "STRICTER": "only invoice-pro's own rules (IP-*) reject an officially valid invoice",
    "GUARD_ONLY": "only the XML guard objects: no rule of the registry explains it",
    "CRASH": "the compilation failed",
    "INPUT_ERROR": "the compilation stopped with the expected message about the input (a deliberate check)",
    "NO_XML": "no e-invoice XML attached",
}
# The hard gates: none of these may occur on the legal population, and no
# entry of known-issues.toml can excuse them.
HARD = ("FALSE_NEGATIVE", "FALSE_POSITIVE", "CRASH", "GUARD_ONLY")
STRUCTURAL = re.compile(r"^(XSD|\?|FX-SCH-.*|MUSTANG-CRASH)$")
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
_HEADER = re.compile(r"^//\s*(expect|error|finding|facts):\s*(.*)$")


# ---------------------------------------------------------------- cases


def parse_header(path):
    """The header comments of a case file:

      // expect: <CLASS> [RULE ...]   class and rules invoice-pro must report
      // error: <text>                INPUT_ERROR: text of the expected message
      // finding: <id>                audit finding or issue it reproduces
      // facts: {<json>}              oracle facts (see oracles.py), repeatable
    """
    expect, rules, finding, facts, error = None, [], None, {}, None
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
    return {"expect": expect, "expect_rules": rules, "expect_error": error, "finding": finding, "facts": facts}


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
                    cases.append(_file_case(file))
        elif path.suffix == ".typ":
            cases.append(_file_case(path))
        else:
            raise common.ToolError(f"{path}: not a corpus directory or .typ file")
    ids = [c["id"] for c in cases]
    duplicates = sorted({i for i in ids if ids.count(i) > 1})
    if duplicates:
        raise common.ToolError(f"duplicate case ids: {', '.join(duplicates)}")
    return cases


def _file_case(file):
    header = parse_header(file)
    text = Path(file).read_text(encoding="utf-8")
    # Without the harness, "no diagnostics attached" would read as "no errors".
    if "harness(" not in text and "..setup" not in text:
        raise common.ToolError(f"{file}: a case must use the harness theme (`..setup` of _base.typ or `harness(..)`)")
    return {
        "id": "rg-" + file.stem,
        "population": "regression",
        "file": str(file),
        "features": None,
        "twin": None,
        **header,
    }


# ---------------------------------------------------------------- stage 1: Typst


def compile_case(case, out_dir, timestamp=common.DEFAULT_TIMESTAMP):
    """Runs in a worker process: compile, then read XML, diagnostics, text."""
    pdf = Path(out_dir) / f"{case['id']}.pdf"
    ok, stderr, seconds = common.typst_compile(case["file"], pdf, timestamp=timestamp)
    res = {"id": case["id"], "t_compile": round(seconds, 3)}
    if not ok:
        res["crash"] = stderr.strip()[:4000]
        return res
    attachments, text = common.read_pdf(pdf)
    res["pdf_text"] = text
    diagnostics = attachments.get(common.DIAGNOSTICS_ATTACHMENT)
    if diagnostics:
        data = json.loads(diagnostics)
        res["diagnostics"] = data.get("diagnostics", [])
        res["reported_profile"] = (data.get("profile") or {}).get("id")
    else:
        res["diagnostics"] = []
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


def classify(res):
    if "crash" in res:
        return "CRASH"
    if "xml_path" not in res:
        return "NO_XML"
    errors = [d for d in res.get("diagnostics", []) if d.get("level") == "error"]
    ours = error_rules(res)
    official = res["official"]
    if errors and all(d.get("source") == "guard" for d in errors):
        return "GUARD_ONLY"
    if not ours:
        return "AGREE_VALID" if official["valid"] else "FALSE_NEGATIVE"
    if official["valid"]:
        return "STRICTER" if all(r.startswith("IP-") for r in ours) else "FALSE_POSITIVE"
    named_official = {r for r in official["rules"] if not STRUCTURAL.match(r)}
    named_ours = {r for r in ours if not r.startswith("IP-")}
    if named_official and named_ours and not named_official & named_ours:
        return "WRONG_RULE_ID"
    return "AGREE_INVALID"


# Expectations that accept several classes.
UNIONS = {
    # invoice-pro and the official validators agree, invoice-pro applies one
    # of its own documented rules, or it stops with its own message about the
    # input (random population).
    "AGREE": ("AGREE_VALID", "AGREE_INVALID", "STRICTER", "INPUT_ERROR"),
    # invoice-pro stops the invoice, whatever the official verdict: for input
    # that must not produce an e-invoice although its XML would be valid.
    "REJECTED": ("AGREE_INVALID", "WRONG_RULE_ID", "STRICTER", "FALSE_POSITIVE"),
}


def expectation_met(case, cls, ours):
    expect = case["expect"]
    class_ok = cls in UNIONS[expect] if expect in UNIONS else cls == expect
    missing = [r for r in case.get("expect_rules", []) if r not in ours]
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


# ---------------------------------------------------------------- main


class Checker:
    """The official side: XSD with lxml, Schematron with Mustang (one JVM)."""

    def __init__(self, cache_dir, use_mustang=True):
        jar = common.mustang_jar() if use_mustang or os.environ.get("MUSTANG_JAR") else None
        self.schemas = common.Schemas(jar, cache_dir) if jar else None
        self.mustang = common.Mustang(jar, cache_dir) if use_mustang else None

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

    @staticmethod
    def collect(res):
        """Waits for Mustang and sets `res["official"]`."""
        future = res.pop("_future", None)
        if future:
            res["mustang"] = future.result()
        if "xml_path" not in res:
            return
        m = res.get("mustang") or {"status": "valid", "errors": {}}
        xsd_errors = res.get("xsd_errors", [])
        if "xml_error" in res:
            xsd_errors = res["xsd_errors"] = ["not well-formed: " + res["xml_error"]]
        res["official"] = {
            "valid": not xsd_errors and m["status"] == "valid" and not m["errors"],
            "rules": sorted(set(m["errors"]) | ({"XSD"} if xsd_errors else set())),
        }

    def close(self):
        if self.mustang:
            self.mustang.close()


def make_row(case, res, doc):
    """Classification, expectation and oracles of one evaluated case."""
    cls = classify(res)
    # A deliberate stop on invalid input is not a crash: when it is the
    # message the case expects, or, for random input, any message of a
    # `panic` or `assert` of invoice-pro (not a runtime error of Typst).
    if cls == "CRASH":
        if case.get("expect_error"):
            cls = "INPUT_ERROR" if case["expect_error"] in res["crash"] else cls
        elif case["expect"] == "AGREE" and _DELIBERATE.search(res["crash"]):
            cls = "INPUT_ERROR"
    ours = error_rules(res)
    class_ok, missing = expectation_met(case, cls, ours)
    problems = oracles.check_diagnostics(res.get("diagnostics", []))
    if cls == "AGREE_VALID" and doc is not None:
        problems += oracles.check(case.get("facts") or {}, doc, res.get("pdf_text"), res.get("profile"))
    mustang = res.get("mustang") or {}
    return {
        "id": case["id"],
        "population": case["population"],
        "finding": case.get("finding"),
        "cls": cls,
        "expect": case["expect"],
        "class_ok": class_ok,
        "missing_rules": missing,
        "ours": ours,
        "official": res.get("official", {}).get("rules", []),
        "profile": res.get("profile"),
        "oracle": problems,
        "diagnostics": res.get("diagnostics", []),
        "xsd_errors": res.get("xsd_errors", [])[:5],
        "official_messages": mustang.get("errors", {}),
        "crash": res.get("crash"),
        "t_compile": res.get("t_compile"),
        "t_mustang_ms": mustang.get("ms"),
        "features": case.get("features"),
        "file": case["file"],
    }


def run(cases, jobs, out_dir, use_mustang, known, strict, check_xpass):
    started = time.perf_counter()
    checker = Checker(out_dir.parent, use_mustang)
    results, docs = {}, {}
    t_compile = time.perf_counter()
    # Typst runs in worker processes; the XSD check and the queueing for
    # Mustang happen here as soon as a case is compiled, so the JVM validates
    # while Typst still compiles.
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
    t_wait = time.perf_counter()
    for res in results.values():
        checker.collect(res)
    t_wait = time.perf_counter() - t_wait
    checker.close()

    rows = [make_row(case, results[case["id"]], docs.get(case["id"])) for case in cases]
    metamorphic(rows, docs, {c["id"]: c for c in cases})

    failures, hits, xpass = triage(rows, known, strict, check_xpass)
    timing = {
        "total_s": round(time.perf_counter() - started, 1),
        "compile_s": round(t_compile, 1),
        "mustang_wait_s": round(t_wait, 1),
        "jobs": jobs,
    }
    return rows, failures, hits, xpass, timing


def breaks_hard_gate(row):
    """A hard class on the legal population: never excused by known issues."""
    return row.get("population") == "legal" and row["cls"] in HARD


def triage(rows, known, strict=False, check_xpass=True):
    """Sets verdict and signature of every row and sorts the failures into
    new ones and known issues. Returns (new failures, [(entry, signature,
    case ids)], [(entry, signature)] of listed signatures that did not occur).
    """
    failures, known_hits = [], {}
    for row in rows:
        passed = row["class_ok"] and not row["missing_rules"] and not row["oracle"] and not breaks_hard_gate(row)
        row["verdict"] = "PASS" if passed else "FAIL"
        if row["verdict"] == "FAIL":
            row["signature"] = signature(row)
            hit = None if strict or breaks_hard_gate(row) else match_known(row, known)
            if hit:
                row["known"] = known[hit[0]]["finding"]
                known_hits.setdefault(hit, []).append(row["id"])
            else:
                failures.append(row)
    # Every listed signature must still occur, so the list can only shrink.
    # Entries that cover no case of this run are left alone.
    xpass = []
    if not strict and check_xpass:
        for index, entry in enumerate(known):
            if not any(covers(entry, row) for row in rows):
                continue
            for sig in entry["signatures"]:
                if (index, sig) not in known_hits:
                    xpass.append((entry, sig))
    hits = [(known[index], sig, ids) for (index, sig), ids in known_hits.items()]
    return failures, hits, xpass


def report(rows, failures, known_hits, xpass, timing, use_mustang):
    lines = []
    by_pop = {}
    for row in rows:
        by_pop.setdefault(row["population"], {}).setdefault(row["cls"], 0)
        by_pop[row["population"]][row["cls"]] += 1
    lines.append(f"cases: {len(rows)}   time: {timing['total_s']} s (compile {timing['compile_s']} s with "
                 f"{timing['jobs']} jobs, then waiting for Mustang {timing['mustang_wait_s']} s)")
    if not use_mustang:
        lines.append("WARNING: --no-mustang: only the XSD was checked; the classes are NOT the official verdict")
    for pop, counts in sorted(by_pop.items()):
        shown = ", ".join(f"{k} {v}" for k, v in sorted(counts.items(), key=lambda kv: -kv[1]))
        lines.append(f"  {pop:12s} {sum(counts.values()):4d}: {shown}")
    legal = [r for r in rows if r["population"] == "legal"]
    hard = {c: sum(1 for r in legal if r["cls"] == c) for c in HARD}
    broken = sum(hard.values())
    lines.append(("HARD GATE BROKEN" if broken else "hard gates") + " (legal population, never a known issue): "
                 + ", ".join(f"{c} {n}" for c, n in hard.items())
                 + f", not AGREE_VALID {sum(1 for r in legal if r['cls'] != 'AGREE_VALID')}")
    oracle_fail = sum(1 for r in rows if r["oracle"])
    lines.append(f"PASS {sum(r['verdict'] == 'PASS' for r in rows)}  FAIL {sum(r['verdict'] == 'FAIL' for r in rows)}"
                 f"  (known issues {sum(len(ids) for _, _, ids in known_hits)}, oracle failures {oracle_fail})")
    if known_hits:
        lines.append("\nKnown issues (known-issues.toml):")
        for entry, sig, ids in sorted(known_hits, key=lambda e: (e[0]["finding"], e[1])):
            lines.append(f"  [{len(ids):3d}] {entry['finding']}: {sig}")
            lines.append(f"        cases: {' '.join(ids[:8])}{' ...' if len(ids) > 8 else ''}")
    if xpass:
        lines.append("\nXPASS - known issues that no longer occur; remove them from known-issues.toml:")
        for entry, sig in xpass:
            lines.append(f"  {entry['finding']}: {sig!r}")
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
            for rule, msg in list(ex["official_messages"].items())[:3]:
                lines.append(f"        official [{rule}]: {msg[:200]}")
            for d in ex["diagnostics"][:3]:
                if d.get("level") == "error":
                    lines.append(f"        invoice-pro [{d.get('rule')}] {d.get('field')}: {str(d.get('message'))[:200]}")
            for e in ex["xsd_errors"][:2]:
                lines.append(f"        xsd: {e[:200]}")
            if ex["crash"]:
                crash = [l for l in ex["crash"].splitlines() if l.strip()]
                lines.append("        crash: " + " | ".join(crash[:3])[:400])
    ok = not failures and not xpass
    lines.append("\n" + ("OK: no new failures" if ok else "FAILED: see NEW FAILURES / XPASS above (tests/TESTING.md explains the triage)"))
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
    ap.add_argument("--no-mustang", action="store_true", help="skip the official Schematron (XSD only; not a gate)")
    ap.add_argument("--json", default=None, help="write the results to this file (default: <build>/results.json)")
    args = ap.parse_args(argv)
    try:
        build = common.build_dir(args.build_dir)
        paths = args.paths or [p for p in (build / "corpus", HERE / "corpus" / "regression") if p.exists()]
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
        rows, failures, known_hits, xpass, timing = run(
            cases, args.jobs, out_dir, not args.no_mustang, known, args.strict, check_xpass=not subset
        )
    except common.ToolError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    text, ok = report(rows, failures, known_hits, xpass, timing, not args.no_mustang)
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
