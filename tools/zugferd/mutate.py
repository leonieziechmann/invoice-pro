#!/usr/bin/env python3
"""Mutation test of the XML write guard (G1, G2; src/zugferd/guard/).

  mutate.py [--seed N] [--per-operator K] [--only GLOB] [--out DIR] [--kosit]

Takes the golden e-invoices of every profile (tests/zugferd/golden/), derives
mutants from them with a fixed seed and puts every mutant through

  - the guard: tools/zugferd/mutate.typ reads the XML with Typst's parser,
    turns it back into the builder's element tree and serializes it with
    the guard (one compilation for all mutants);
  - the XSD of the profile (lxml), and Mustang (XSD and the Schematron of
    Factur-X, EN 16931 and XRechnung, in one JVM);
  - with --kosit, the KoSIT validator for EN 16931 and XRechnung
    ($KOSIT_JAR, $KOSIT_CONFIG: the validator jar and the directory of the
    XRechnung configuration with scenarios.xml).

Operators: structural (delete, duplicate, swap with the next sibling,
insert an unknown element, move to another parent, rename, empty a leaf),
code (another code of any list, or none) and lexical (decimals, dates,
indicators). A mutant the builder's tree cannot express as it is (the XML
the guard writes differs from the mutant) is left out and counted.

The proof criteria, each must hold for every mutant:

  C1  the guard accepts no mutant that the XSD rejects;
  C2  the guard blocks no structural mutant the official validators accept,
      except by its documented stricter checks: an element the builder never
      writes, one the Factur-X Schematron marks as not used (Mustang ignores
      those reports), a date that names no day;
  C3  the guard rejects a mutated code exactly when Mustang reports a code
      list rule of that position (and KoSIT one of EN 16931 or XRechnung,
      with --kosit).

Needs Python 3.11+ with lxml, Typst, a JDK and $MUSTANG_JAR; the numbers go
to <out>/mutate-report.json. Exit status 1 when a criterion fails.
"""

import argparse
import collections
import copy
import fnmatch
import json
import os
import random
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common  # noqa: E402
import gen_guard  # noqa: E402

from lxml import etree  # noqa: E402

GOLDEN = common.REPO / "tests" / "zugferd" / "golden"
HARNESS = "/tools/zugferd/mutate.typ"
NSMAP = common.NS
PREFIX_OF = {uri: prefix for prefix, uri in NSMAP.items()}

# Mutants by operator and seed file, with the default --per-operator 2 and
# the 38 golden files: about 1100 mutants, a few minutes with Mustang.
STRUCTURAL = ("delete", "duplicate", "swap", "unknown", "move", "rename", "empty")
VALUES = ("code", "lexical")

# Elements and attributes with a code list somewhere, the targets of code
# mutants (the tables say which list applies where).
CODE_ELEMENTS = {
    "CountryID", "InvoiceCurrencyCode", "TaxCurrencyCode", "TypeCode", "CategoryCode",
    "ExemptionReasonCode", "ReasonCode", "SubjectCode", "DueDateTypeCode",
}
CODE_ATTRIBUTES = {"unitCode", "schemeID", "currencyID", "format", "mimeCode", "listID"}
INVALID_CODES = ("QQ", "Q1", "999", "XYZZY", "eur", "de")

# Leaves of a lexical form, and texts outside of it.
LEXICAL = [
    (re.compile(r"Amount$|Quantity$|Percent$"), ("1,00", "1.000", "12.345", "1e3", "abc", "- 1")),
    (re.compile(r"^DateTimeString$|^DateString$"), ("20260230", "2026-01-01", "20261301", "2026010")),
    (re.compile(r"^Indicator$"), ("yes", "TRUE", "2")),
]

# Finding kinds of the guard's documented checks beyond the official
# validators (criterion C2).
STRICTER = {"unknown", "not-used", "attribute-not-used", "xref-other"}


def local(el):
    return etree.QName(el).localname


def qname(el):
    q = etree.QName(el)
    return f"{PREFIX_OF.get(q.namespace, '?')}:{q.localname}"


def path_of(el):
    """The path of an element as the guard names it, without indices."""
    steps = []
    while el is not None:
        steps.append(qname(el))
        el = el.getparent()
    return "/".join(reversed(steps))


def conventional_prefix(el):
    """The prefix CII gives an element (see tools/zugferd/mutate.typ)."""
    depth = len(list(el.iterancestors()))
    parent = el.getparent()
    if depth <= 1:
        return "rsm"
    if local(el) == "DateTimeString" and parent is not None and local(parent) == "FormattedIssueDateTime":
        return "qdt"
    if local(el) in ("DateTimeString", "DateString", "Indicator"):
        return "udt"
    return "ram"


# ---------------------------------------------------------------- operators


def elements(root, leaf=None):
    """Every element below the root; only leaves or only complex ones."""
    out = []
    for el in root.iter():
        if el is root or not isinstance(el.tag, str):
            continue
        is_leaf = len(el) == 0
        if leaf is None or leaf == is_leaf:
            out.append(el)
    return out


def op_delete(root, rng, known):
    el = rng.choice(elements(root))
    target = path_of(el)
    el.getparent().remove(el)
    return f"delete {target}", target


def op_duplicate(root, rng, known):
    el = rng.choice(elements(root))
    el.addnext(copy.deepcopy(el))
    return f"duplicate {path_of(el)}", path_of(el)


def op_swap(root, rng, known):
    pairs = [el for el in elements(root) if el.getnext() is not None and el.getnext().tag != el.tag]
    if not pairs:
        return None
    el = rng.choice(pairs)
    nxt = el.getnext()
    nxt.addnext(el)
    return f"swap {path_of(el)} and {qname(nxt)}", path_of(el)


def op_unknown(root, rng, known):
    parent = rng.choice(elements(root, leaf=False) or [root])
    el = etree.Element(f"{{{NSMAP['ram']}}}GuardMutant")
    el.text = "x"
    parent.insert(rng.randint(0, len(parent)), el)
    return f"insert ram:GuardMutant into {path_of(parent)}", path_of(el)


def op_move(root, rng, known):
    el = rng.choice(elements(root))
    targets = [p for p in elements(root, leaf=False) + [root]
               if p is not el.getparent() and el not in p.iterancestors() and p is not el]
    if not targets:
        return None
    parent = rng.choice(targets)
    source = path_of(el)
    parent.insert(rng.randint(0, len(parent)), el)
    return f"move {source} into {path_of(parent)}", path_of(el)


def op_rename(root, rng, known):
    el = rng.choice(elements(root))
    name = rng.choice(sorted(t for t in known if t.startswith("ram:"))).split(":")[1]
    if name == local(el):
        return None
    source = path_of(el)
    el.tag = f"{{{NSMAP['ram']}}}{name}"
    return f"rename {source} to ram:{name}", path_of(el)


def op_empty(root, rng, known):
    leaves = [el for el in elements(root, leaf=True) if (el.text or "").strip()]
    if not leaves:
        return None
    el = rng.choice(leaves)
    el.text = None
    return f"empty {path_of(el)}", path_of(el)


def op_code(root, rng, codes):
    targets = []
    for el in elements(root, leaf=True):
        if local(el) in CODE_ELEMENTS and (el.text or "").strip():
            targets.append((el, None))
        for name in el.attrib:
            if name in CODE_ATTRIBUTES:
                targets.append((el, name))
    if not targets:
        return None
    el, attr = rng.choice(targets)
    value = rng.choice(INVALID_CODES) if rng.random() < 0.3 else rng.choice(codes)
    if attr is None:
        old, el.text = el.text, value
    else:
        old = el.get(attr)
        el.set(attr, value)
    if old == value:
        return None
    what = "." if attr is None else "@" + attr
    return f"code {path_of(el)}{'' if attr is None else '/@' + attr}: {old!r} -> {value!r}", (path_of(el), what)


def op_lexical(root, rng, codes):
    targets = []
    for el in elements(root, leaf=True):
        for pattern, values in LEXICAL:
            if pattern.search(local(el)) and (el.text or "").strip():
                targets.append((el, values))
    if not targets:
        return None
    el, values = rng.choice(targets)
    old, el.text = el.text, rng.choice(values)
    return f"lexical {path_of(el)}: {old!r} -> {el.text!r}", path_of(el)


OPERATORS = {
    "delete": op_delete, "duplicate": op_duplicate, "swap": op_swap, "unknown": op_unknown,
    "move": op_move, "rename": op_rename, "empty": op_empty, "code": op_code, "lexical": op_lexical,
}


def compact(data):
    """The XML without the indentation of the golden files: the builder
    writes no whitespace between elements."""
    root = etree.fromstring(data)
    for el in root.iter():
        if len(el) and el.text is not None and not el.text.strip():
            el.text = None
        if el.tail is not None and not el.tail.strip():
            el.tail = None
    return etree.tostring(root, xml_declaration=True, encoding="UTF-8")


def representable(root):
    """Whether the builder's tree can express the document as it is (see
    tools/zugferd/mutate.typ): the prefixes of CII, no text between
    elements, no repeated element with another one between, no blank text."""
    for el in root.iter():
        if not isinstance(el.tag, str):
            return False
        if qname(el).split(":")[0] != conventional_prefix(el):
            return False
        children = [c for c in el if isinstance(c.tag, str)]
        if children:
            texts = [el.text] + [c.tail for c in children]
            if any(t and t.strip() for t in texts):
                return False
            seen, last = set(), None
            for c in children:
                if c.tag in seen and c.tag != last:
                    return False
                seen.add(c.tag)
                last = c.tag
        elif el.text is not None and el.text != "" and not el.text.strip():
            return False
    return True


# ---------------------------------------------------------------- oracles


def code_list_rules(jar, profiles):
    """The rules of every code list the official validators apply at each
    position of a profile: {profile: {(path, "." or "@name"): {rule:
    source}}}, from the generator's compiled rules."""
    j = gen_guard.Jar(jar)
    schemas = gen_guard.load_schemas(j)
    out = {}
    for profile in profiles:
        compiler = gen_guard.load_profile(j, profile, schemas)
        rules = collections.defaultdict(dict)
        for pos in compiler.positions:
            steps, p = [], pos
            while p is not None:
                steps.append(p.tag)
                p = p.parent
            path = "/".join(reversed(steps))
            for cl in pos.lists:
                rules[(path, ".")][cl.rule] = cl.source
            for name, attr in pos.attrs.items():
                for cl in attr.lists:
                    rules[(path, "@" + name)][cl.rule] = cl.source
            for cl in getattr(pos, "prefix", None) or []:
                rules[(path, ".")][cl.rule] = cl.source
        out[profile] = rules
    return out


def all_codes(jar):
    """Every code of every list of the tables, sorted: candidates for code
    mutants that some list knows."""
    text = (common.REPO / "src" / "zugferd" / "guard" / "lists.typ").read_text(encoding="utf-8")
    codes = set()
    for literal in re.findall(r'"([^"\n]*)"', text):
        codes.update(c for c in literal.split() if re.fullmatch(r"[A-Za-z0-9.-]+", c))
    return sorted(codes)


def run_kosit(files, work):
    """KoSIT's errors per file ({path: set of rules} or None without a
    scenario), with $KOSIT_JAR and the configuration in $KOSIT_CONFIG."""
    jar, config = os.environ.get("KOSIT_JAR"), os.environ.get("KOSIT_CONFIG")
    if not jar or not config:
        raise common.ToolError("--kosit needs KOSIT_JAR and KOSIT_CONFIG")
    out = Path(work) / "kosit"
    out.mkdir(parents=True, exist_ok=True)
    java = common._java_tool("JAVA_BIN", "java")
    subprocess.run([java, "-jar", jar, "-r", config, "-s", str(Path(config) / "scenarios.xml"), "-o", str(out),
                    *map(str, files)], capture_output=True, text=True)
    result = {}
    for f in files:
        report = out / (Path(f).stem + "-report.xml")
        if not report.exists():
            raise common.ToolError(f"KoSIT wrote no report for {f}")
        text = report.read_text(encoding="utf-8")
        if "rep:noScenarioMatched" in text:
            result[str(f)] = None
            continue
        errors = set()
        for m in re.finditer(r"<rep:message\b([^>]*)>", text):
            attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
            if attrs.get("level") == "error":
                errors.add(attrs.get("code", "?"))
        result[str(f)] = errors
    return result


def run_guard(cases, work):
    """The guard's result per mutant id (tools/zugferd/mutate.typ)."""
    listing = Path(work) / "cases.json"
    listing.write_text(json.dumps(cases), encoding="utf-8")
    rel = "/" + listing.resolve().relative_to(common.REPO).as_posix()
    cmd = [common.typst_bin(), "query", "--root", str(common.REPO), "--input", f"cases={rel}",
           str(common.REPO / HARNESS.lstrip("/")), "<guard-results>", "--field", "value", "--one"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise common.ToolError("the guard harness failed:\n" + proc.stderr[-4000:])
    return {r["id"]: r for r in json.loads(proc.stdout)}


def canonical(data):
    """C14N of an XML document, attributes and namespaces in a fixed order."""
    root = etree.fromstring(data, etree.XMLParser(resolve_entities=False, no_network=True))
    return etree.tostring(root, method="c14n2")


# ---------------------------------------------------------------- main


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=20260924, help="seed of the mutants (fixed, so runs compare)")
    ap.add_argument("--per-operator", type=int, default=2, help="mutants per operator and golden file")
    ap.add_argument("--only", default="*", help="glob of the golden files to start from")
    ap.add_argument("--out", default=None, help="work directory (default: build/zugferd/mutate)")
    ap.add_argument("--kosit", action="store_true", help="also compare code mutants with KoSIT")
    args = ap.parse_args(argv)
    started = time.monotonic()
    try:
        jar = common.mustang_jar()
        out = Path(args.out or common.REPO / "build" / "zugferd" / "mutate").resolve()
        common.require_under_root(out)
        (out / "mutants").mkdir(parents=True, exist_ok=True)
        for old in (out / "mutants").glob("*.xml"):
            old.unlink()

        seeds = sorted(p for p in GOLDEN.rglob("*.xml") if fnmatch.fnmatch(p.name, args.only))
        if not seeds:
            raise common.ToolError(f"no golden XML matches {args.only}")
        known = gen_guard.known_tags(gen_guard.load_schemas(gen_guard.Jar(jar)).values())
        codes = all_codes(jar)

        mutants, skipped = [], collections.Counter()
        for seed in seeds:
            data = compact(seed.read_bytes())
            doc = common.parse_xml(data)
            guideline = common.xtext1(doc, common.GUIDELINE_PATH)
            profile, xsd = common.GUIDELINES[guideline]
            for op in STRUCTURAL + VALUES:
                rng = random.Random(f"{args.seed}:{seed.relative_to(GOLDEN)}:{op}")
                made, attempts = 0, 0
                while made < args.per_operator and attempts < 20 * args.per_operator:
                    attempts += 1
                    root = etree.fromstring(data)
                    extra = codes if op in VALUES else known
                    result = OPERATORS[op](root, rng, extra)
                    if result is None:
                        continue
                    detail, target = result
                    if not representable(root):
                        skipped["not expressible as the builder's tree"] += 1
                        continue
                    mid = f"{seed.stem}-{op}-{made}"
                    path = out / "mutants" / f"{mid}.xml"
                    path.write_bytes(etree.tostring(root, xml_declaration=True, encoding="UTF-8"))
                    mutants.append({
                        "id": mid, "seed": str(seed.relative_to(common.REPO)), "profile": profile, "xsd": xsd,
                        "op": op, "class": "structural" if op in STRUCTURAL else op, "detail": detail,
                        "target": target, "file": str(path),
                    })
                    made += 1

        print(f"{len(mutants)} mutants of {len(seeds)} golden files (seed {args.seed})", file=sys.stderr)
        cases = [{"id": m["id"], "path": "/" + Path(m["file"]).relative_to(common.REPO).as_posix(),
                  "profile": m["profile"]} for m in mutants]
        guard = run_guard(cases, out)

        schemas = common.Schemas(jar, common.build_dir())
        mustang = common.Mustang(jar, common.build_dir())
        official = {}
        try:
            # In batches, so that the paths waiting in the pipe to the JVM
            # stay far below its buffer: `submit` holds a lock while it
            # writes, which the thread reading the results needs as well.
            for start in range(0, len(mutants), 64):
                batch = mutants[start:start + 64]
                futures = {m["id"]: mustang.submit(m["file"]) for m in batch}
                official |= {mid: f.result() for mid, f in futures.items()}
        finally:
            mustang.close()
        kosit = run_kosit([m["file"] for m in mutants if m["class"] == "code"], out) if args.kosit else {}
        rules = code_list_rules(jar, sorted({m["profile"] for m in mutants if m["class"] == "code"}))

        failures = collections.defaultdict(list)
        stats = collections.Counter()
        for m in mutants:
            g = guard[m["id"]]
            if not g.get("representable") or canonical(g["xml"].encode()) != canonical(Path(m["file"]).read_bytes()):
                skipped["written differently by the guard's tree"] += 1
                continue
            findings = [tuple(f) for f in g["findings"]]
            accepted = not findings
            _, xsd_errors = schemas.validate(common.parse_xml(Path(m["file"]).read_bytes()))
            xsd_valid = not xsd_errors
            report = official[m["id"]]
            official_valid = report["status"] == "valid" and not report["errors"]
            stats[(m["class"], "total")] += 1
            stats[(m["class"], "guard rejects")] += not accepted
            stats[(m["class"], "XSD rejects")] += not xsd_valid
            stats[(m["class"], "Mustang rejects")] += not official_valid
            entry = {"id": m["id"], "detail": m["detail"], "findings": findings[:5],
                     "mustang": sorted(report["errors"])[:8]}
            if accepted and not xsd_valid:
                failures["C1"].append(entry | {"xsd": xsd_errors[:2]})
            if m["class"] == "structural" and official_valid and not accepted:
                kinds = {f[0] for f in findings}
                stricter = kinds <= STRICTER or all(f[0] == "date" and f[1] == "IP-GUARD-08" for f in findings)
                if stricter:
                    stats[("structural", "blocked by stricter checks")] += 1
                else:
                    failures["C2"].append(entry)
            if m["class"] == "code":
                path, what = m["target"]
                known_rules = rules[m["profile"]].get((path, what), {})
                if not known_rules:
                    stats[("code", "no list at the position")] += 1
                    continue
                at = [f for f in findings if f[0] in ("code", "prefix") and re.sub(r"\[\d+\]", "", f[2]) == path]
                guard_rejects = bool(at)
                mustang_rejects = bool(set(report["errors"]) & set(known_rules))
                stats[("code", "compared with Mustang")] += 1
                if guard_rejects != mustang_rejects:
                    failures["C3"].append(entry | {"rules": sorted(known_rules)})
                if args.kosit and kosit.get(m["file"]) is not None:
                    official_rules = {r for r, source in known_rules.items() if source in ("CEN", "XR")}
                    guard_cen = any(f[1] in official_rules for f in at)
                    kosit_rejects = bool(kosit[m["file"]] & official_rules)
                    stats[("code", "compared with KoSIT")] += 1
                    if guard_cen != kosit_rejects:
                        failures["C3 (KoSIT)"].append(entry | {"kosit": sorted(kosit[m["file"]])[:8]})

        summary = {
            "seed": args.seed,
            "golden files": len(seeds),
            "mutants": len(mutants),
            "left out": dict(skipped),
            "by class": {f"{c}: {k}": v for (c, k), v in sorted(stats.items())},
            "failures": {k: len(v) for k, v in failures.items()},
            "seconds": round(time.monotonic() - started),
        }
        (out / "mutate-report.json").write_text(json.dumps(summary | {"details": failures}, indent=1), encoding="utf-8")
        print(json.dumps(summary, indent=1))
        for criterion, items in sorted(failures.items()):
            print(f"\n{criterion}: {len(items)} mutants", file=sys.stderr)
            for item in items[:10]:
                print(f"  {item['id']}: {item['detail']}\n    guard {item['findings']}\n    Mustang {item['mustang']}",
                      file=sys.stderr)
        if failures:
            print("\n✘ the write guard fails the mutation test (see above)", file=sys.stderr)
            return 1
        print("✔ the write guard passes the mutation test (C1, C2, C3)", file=sys.stderr)
        return 0
    except common.ToolError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
