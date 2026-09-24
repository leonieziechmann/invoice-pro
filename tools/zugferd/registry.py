#!/usr/bin/env python3
"""The rule registry of invoice-pro's e-invoice validation, for the tools.

  registry.py [--check] [--write-docs] [--jar PATH]

The registry, src/zugferd/rules/registry.json, is the one source of the
metadata of every rule whose diagnostics invoice-pro reports: the checks of
its validator (src/zugferd/rules/engine.typ, rare.typ, xrechnung.typ, which
report findings by the key of an entry) and the rules of the XML write
guard (IP-GUARD-*). The messages are in src/zugferd/rules/messages.typ.
Typst reads the file only when a check fails (JSON is the format it reads
fastest); the tools read it here:

  load()              the registry, checked (`problems`): {"format": 1,
                      "sources": {source: artefact}, "rules": {key: entry}}
  reported(registry)  the ids the rules report: {id: [key, ..]}
  covering(registry, profile)
                      the official rules the checks implement in a profile:
                      {official id: [key, ..]}
  docs_tables(..)     the tables of the rules of invoice-pro in
                      docs/docs/e-invoicing.md, generated from the registry
  fx_aliases(jar)     the Factur-X rules that implement an official rule of
                      EN 16931 (from the Mustang jar)

An entry (see src/zugferd/rules/engine.typ for its meaning):

  "BR-CO-25": {
    "ids": ["BR-CO-25"],                  # optional, default: [key]
    "covers": ["BR-CO-25", "FX-SCH-A-000155"],
    "source": "EN16931",                  # EN16931 FACTUR-X XRECHNUNG PEPPOL CII IP
    "versions": ["1.3.12", "1.3.16"],     # of the source's artefacts
    "profiles": ["basic-wl", "basic", "en16931", "xrechnung"],
    "scope": "payment",                   # document party line tax allowance-charge payment printed
    "terms": ["BT-9", "BT-20"],
    "level": "error",                     # or ["error", "warning"]: the first is the usual one
    "field": "payment-goal",              # the input the diagnostic names
    "summary": "...",                     # what it checks (the documentation of IP rules)
    "legal": null                         # the legal basis of a rule of invoice-pro
  }

--check reports every problem: of the entries, of the keys that have no
message or no check (a key the rule modules do not name) and of the rule
ids the rule modules name that the registry does not know; tables of the
documentation that differ from the generated ones; with the Mustang jar
($MUSTANG_JAR or --jar), `covers` that lacks a Factur-X alias of a rule it
covers or names one of another rule. --write-docs rewrites the tables.
"""

import argparse
import collections
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
RULES = REPO / "src" / "zugferd" / "rules"
REGISTRY = RULES / "registry.json"
MESSAGES = RULES / "messages.typ"
MODULES = [RULES / "engine.typ", RULES / "rare.typ", RULES / "xrechnung.typ"]
GUARD_REPORT = REPO / "src" / "zugferd" / "guard" / "report.typ"
DOCS = REPO / "docs" / "docs" / "e-invoicing.md"

PROFILES = ("minimum", "basic-wl", "basic", "en16931", "xrechnung")
SOURCES = ("EN16931", "FACTUR-X", "XRECHNUNG", "PEPPOL", "CII", "IP")
SCOPES = ("document", "party", "line", "tax", "allowance-charge", "payment", "printed")
LEVELS = ("error", "warning")
FIELDS = {
    "covers": list, "source": str, "versions": list, "profiles": list, "scope": str, "terms": list,
    "level": (str, list), "field": str, "summary": str, "legal": (str, type(None)),
}
OPTIONAL = {"ids": list, "note": str}
# A rule id has a number (the family prefixes of the VAT categories, e.g.
# "BR-S", are no rule ids).
RULE_ID = re.compile(r"^(?=.*\d)(?:BR|CII|PEPPOL|FX|IP)-[A-Z0-9]+(?:-[A-Za-z0-9]+)*$")


def load(path=REGISTRY):
    """The registry as a dictionary; fails with the problems `problems`
    finds."""
    registry = json.loads(Path(path).read_text(encoding="utf-8"))
    found = problems(registry)
    if found:
        raise ValueError(f"{path}:\n  " + "\n  ".join(found))
    return registry


def levels(entry):
    return [entry["level"]] if isinstance(entry["level"], str) else list(entry["level"])


def ids(key, entry):
    return list(entry.get("ids", [key]))


def problems(registry):
    """What is wrong with the entries of a registry (a list of texts)."""
    out = []
    if registry.get("format") != 1:
        out.append("format: 1 expected")
    sources = registry.get("sources", {})
    if sorted(sources) != sorted(SOURCES):
        out.append(f"sources: {sorted(SOURCES)} expected")
    rules = registry.get("rules", {})
    for key, entry in rules.items():
        where = f"rules.{key}"
        for name, kind in FIELDS.items():
            if name not in entry:
                out.append(f"{where}: no {name}")
            elif not isinstance(entry[name], kind):
                out.append(f"{where}.{name}: {type(entry[name]).__name__}")
        for name in entry:
            if name not in FIELDS and name not in OPTIONAL:
                out.append(f"{where}: unknown field {name}")
        if any(name not in entry or not isinstance(entry[name], kind) for name, kind in FIELDS.items()):
            continue
        for rule in ids(key, entry):
            if not RULE_ID.match(rule):
                out.append(f"{where}.ids: {rule} is no rule id")
        if entry["source"] not in SOURCES:
            out.append(f"{where}.source: {entry['source']}")
        if entry["scope"] not in SCOPES:
            out.append(f"{where}.scope: {entry['scope']}")
        if not entry["profiles"] or any(p not in PROFILES for p in entry["profiles"]):
            out.append(f"{where}.profiles: {entry['profiles']}")
        elif entry["profiles"] != [p for p in PROFILES if p in entry["profiles"]]:
            out.append(f"{where}.profiles: not in the order {PROFILES}")
        if not levels(entry) or any(level not in LEVELS for level in levels(entry)) or len(set(levels(entry))) != len(levels(entry)):
            out.append(f"{where}.level: {entry['level']}")
        for rule in entry["covers"]:
            if not RULE_ID.match(rule) or rule.startswith("IP-"):
                out.append(f"{where}.covers: {rule} is no official rule")
        if entry["source"] == "IP":
            if entry["covers"]:
                out.append(f"{where}.covers: a rule of invoice-pro covers no official rule")
            if not all(rule.startswith("IP-") for rule in ids(key, entry)):
                out.append(f"{where}.ids: a rule of invoice-pro reports ids of IP-* only")
        else:
            if entry["legal"] is not None:
                out.append(f"{where}.legal: only for rules of invoice-pro")
            if not set(ids(key, entry)) <= set(entry["covers"]):
                out.append(f"{where}.covers: lacks the ids it reports")
            if not entry["versions"]:
                out.append(f"{where}.versions: the artefact versions are missing")
        for term in entry["terms"]:
            if not re.fullmatch(r"(BT|BG)-\d+", term):
                out.append(f"{where}.terms: {term}")
        if not entry["summary"].strip() or not entry["field"].strip():
            out.append(f"{where}: empty summary or field")
    return out


def reported(registry):
    """The ids the rules report, each with the keys of the entries that
    report it: {id: [key, ..]}."""
    out = collections.defaultdict(list)
    for key, entry in registry["rules"].items():
        for rule in ids(key, entry):
            out[rule].append(key)
    return dict(out)


def covering(registry, profile):
    """The official rules the checks of the registry implement in a profile:
    {official id: [key, ..]}."""
    out = collections.defaultdict(list)
    for key, entry in registry["rules"].items():
        if profile in entry["profiles"]:
            for rule in entry["covers"]:
                out[rule].append(key)
    return dict(out)


# ---------------------------------------------------------------- the Typst side


def message_keys(path=MESSAGES):
    """The keys of the `messages` dictionary of messages.typ."""
    text = Path(path).read_text(encoding="utf-8")
    start = text.index("#let messages = (")
    end = text.index("\n)\n", start)
    return re.findall(r'^  "([^"]+)": ', text[start:end], re.M)


def module_literals(paths=MODULES):
    """Every string literal of the rule modules."""
    out = set()
    for path in paths:
        out.update(re.findall(r'"([^"\\\n]*)"', Path(path).read_text(encoding="utf-8")))
    return out


def guard_ids(path=GUARD_REPORT):
    """The ids of the rules of the write guard (report.typ)."""
    return set(re.findall(r'"(IP-GUARD-\d\d)"', Path(path).read_text(encoding="utf-8")))


def source_problems(registry):
    """Keys without a message or a check, and rule ids of the rule modules
    that the registry does not know."""
    out = []
    rules = registry["rules"]
    guard = guard_ids()
    messages = message_keys()
    literals = module_literals()
    for key in rules:
        if key in guard:
            continue
        if key not in messages:
            out.append(f"{key}: no message in {MESSAGES.relative_to(REPO)}")
        if key not in literals:
            out.append(f"{key}: no check names it in src/zugferd/rules/")
    for key in messages:
        if key not in rules:
            out.append(f"{key}: a message of {MESSAGES.relative_to(REPO)} without an entry")
    known = set(reported(registry)) | set(rules)
    for literal in sorted(literals):
        if RULE_ID.match(literal) and literal not in known:
            out.append(f"{literal}: a rule id of src/zugferd/rules/ that the registry does not know")
    for rule in sorted(guard):
        if rule not in rules:
            out.append(f"{rule}: a rule of {GUARD_REPORT.relative_to(REPO)} that the registry does not know")
    return out


# ---------------------------------------------------------------- documentation

# The tables of docs/docs/e-invoicing.md that list rules of the registry:
# the line that starts the table, and the entries (by key) with their columns.
DOC_TABLES = (
    ("| Rule ", "Level", lambda key, entry: entry["source"] == "IP" and not key.startswith("IP-GUARD-")),
    ("| Rule ", None, lambda key, entry: key.startswith("IP-GUARD-")),
)


def table(rows, header):
    """A Markdown table in prettier's layout: every column as wide as its
    widest cell, left-aligned."""
    widths = [max(len(row[i]) for row in [header] + rows) for i in range(len(header))]
    lines = ["| " + " | ".join(cell.ljust(widths[i]) for i, cell in enumerate(header)) + " |"]
    lines.append("| " + " | ".join(":" + "-" * (widths[i] - 1) for i in range(len(header))) + " |")
    for row in rows:
        lines.append("| " + " | ".join(cell.ljust(widths[i]) for i, cell in enumerate(row)) + " |")
    return lines


def docs_tables(registry):
    """The generated tables, in the order of DOC_TABLES."""
    out = []
    for _, level, select in DOC_TABLES:
        entries = [(key, entry) for key, entry in registry["rules"].items() if select(key, entry)]
        if level:
            header = ["Rule", "Level", "Checks"]
            rows = [[f"`{key}`", levels(entry)[0], entry["summary"]] for key, entry in entries]
        else:
            header = ["Rule", "Checks"]
            rows = [[f"`{key}`", entry["summary"]] for key, entry in entries]
        out.append(table(rows, header))
    return out


def _table_spans(lines, path=DOCS):
    """(start, end) of the tables of the rules in the documentation (the
    lines of `path`): for each of DOC_TABLES, the first table with its
    columns."""
    spans = []
    for (start, level, _), columns in zip(DOC_TABLES, (("Rule", "Level", "Checks"), ("Rule", "Checks"))):
        for i, line in enumerate(lines):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if line.startswith(start) and tuple(cells) == columns and all(i != s for s, _ in spans):
                end = i
                while end < len(lines) and lines[end].startswith("|"):
                    end += 1
                spans.append((i, end))
                break
        else:
            raise ValueError(f"{_shown(path)}: no table with the columns {columns}")
    return spans


def _shown(path):
    """A path relative to the repository where it is in it."""
    path = Path(path).resolve()
    return path.relative_to(REPO) if path.is_relative_to(REPO) else path


def docs_problems(registry, path=DOCS):
    """The tables of the documentation that are not the generated ones."""
    lines = Path(path).read_text(encoding="utf-8").split("\n")
    out = []
    for (start, end), generated in zip(_table_spans(lines, path), docs_tables(registry)):
        if lines[start:end] != generated:
            out.append(
                f"{_shown(path)}: the table at line {start + 1} is not the one the registry generates "
                "(run `python3 tools/zugferd/registry.py --write-docs`)"
            )
    return out


def write_docs(registry, path=DOCS):
    """Rewrites the tables of the documentation with the generated ones."""
    lines = Path(path).read_text(encoding="utf-8").split("\n")
    # From the last table on, so that the positions of the others stay.
    for (start, end), generated in sorted(zip(_table_spans(lines, path), docs_tables(registry)), reverse=True):
        lines[start:end] = generated
    Path(path).write_text("\n".join(lines), encoding="utf-8")


# ---------------------------------------------------------------- Factur-X aliases


def fx_aliases(jar_path):
    """{official id: {Factur-X id}}: the rules of the Factur-X Schematrons
    whose message names an official rule (e.g. FX-SCH-A-000011, "[BR-02]"),
    and the code list rules of the Factur-X Schematron at the positions of a
    code list rule of the CEN Schematron (e.g. FX-SCH-A-000040 at the invoice
    currency code of BR-CL-04), as the tables of the write guard compile
    them."""
    sys.path.insert(0, str(HERE))
    import gen_guard

    jar = gen_guard.Jar(jar_path)
    out = collections.defaultdict(set)
    for fx in ("MINIMUM", "BASIC-WL", "BASIC", "EN16931"):
        for rule in gen_guard.load_rules(jar, gen_guard.fx_xslt(fx), "FX", gen_guard.fx_codedb(fx)):
            if rule.kind == "assert" and rule.business_id:
                out[rule.business_id].add(rule.id)
    compiler = gen_guard.load_profile(jar, "en16931", gen_guard.load_schemas(jar))
    for pos in compiler.positions:
        for lists in [pos.lists, pos.prefix] + [attr.lists for attr in pos.attrs.values()]:
            cen = {c.rule for c in lists if c.source == "CEN"}
            fx = {c.rule for c in lists if c.source == "FX" and c.rule.startswith("FX-")}
            for rule in cen:
                out[rule] |= fx
    return {rule: aliases for rule, aliases in out.items() if aliases}


def alias_problems(registry, aliases):
    """Entries whose `covers` lacks a Factur-X alias of an official rule it
    covers in a Factur-X profile, or names one of no rule it covers."""
    out = []
    fx_profiles = {"minimum", "basic-wl", "basic", "en16931"}
    for key, entry in registry["rules"].items():
        covers = set(entry["covers"])
        official = {r for r in covers if not r.startswith("FX-")}
        wanted = set()
        if fx_profiles & set(entry["profiles"]):
            for rule in official:
                wanted |= aliases.get(rule, set())
        named = {r for r in covers if r.startswith("FX-")}
        for rule in sorted(wanted - named):
            out.append(f"rules.{key}.covers: lacks the Factur-X alias {rule}")
        for rule in sorted(named - wanted):
            out.append(f"rules.{key}.covers: {rule} is no Factur-X alias of a rule it covers")
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="check the registry, the rule modules and the documentation")
    ap.add_argument("--write-docs", action="store_true", help="rewrite the tables of the documentation")
    ap.add_argument("--jar", default=os.environ.get("MUSTANG_JAR"), help="Mustang-CLI-2.14.0.jar, for the aliases")
    args = ap.parse_args(argv)
    try:
        registry = load()
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    if args.write_docs:
        write_docs(registry)
    found = source_problems(registry) + docs_problems(registry)
    if args.check and args.jar:
        found += alias_problems(registry, fx_aliases(args.jar))
    if found:
        print("The rule registry has problems:\n  " + "\n  ".join(found), file=sys.stderr)
        return 1
    rules = registry["rules"]
    print(f"✔ the rule registry: {len(rules)} entries, {len(reported(registry))} rule ids"
          + (", Factur-X aliases checked" if args.check and args.jar else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
