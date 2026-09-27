#!/usr/bin/env python3
"""The rule registry of invoice-pro's e-invoice validation, for the tools.

  registry.py [--check] [--format] [--write-docs] [--jar PATH]

The registry, tools/zugferd/registry.json, is the one source of the
metadata of every rule whose diagnostics invoice-pro reports: the checks of
its validator (src/zugferd/rules/engine.typ, rare.typ and xrechnung.typ,
which report findings by the key of an entry). The messages are in src/zugferd/rules/messages.typ, those of the
rules of XRechnung that no other profile reports in xrechnung-messages.typ
(engine.typ loads it for a finding of a BR-DE-* rule, messages.typ only for
another rule). The package does not read the registry: engine.typ lists the
keys whose usual level is "warning" (`_warnings`), which --check compares
with the registry, and gives any other finding without a level the level
"error". The tests of tests/zugferd/ read it (the helpers of
tests/zugferd/harness.typ check every diagnostic against it), and the tools
read it here:

  load()              the registry, checked (`problems`): {"format": 1,
                      "sources": {source: artefact}, "rules": {key: entry}}
  dump(registry)      the text of registry.json: one line per field of an
                      entry, a list on one line
  reported(registry)  the ids the rules report: {id: [key, ..]}
  reported_in(registry, profile)
                      the ids the rules report in a profile: {id: [key, ..]}
  covering(registry, profile)
                      the official rules the checks implement in a profile:
                      {official id: [key, ..]}
  profiles_of(entry, rule)
                      the profiles in which an id of `covers` counts
  docs_tables(..)     the table of the rules of invoice-pro in
                      docs/docs/e-invoicing/validation.md, generated from
                      the registry and sorted by rule id
  warning_keys()      the keys of `_warnings` of engine.typ, read from its
                      Typst source
  fx_aliases(jar)     the Factur-X rules that implement an official rule of
                      EN 16931 (from the Mustang jar)

An entry (see tests/TESTING.md, "The Rule Registry", for its meaning):

  "BR-CO-25": {
    "ids": ["BR-CO-25"],                  # optional, default: [key]
    "covers": ["BR-CO-25", "FX-SCH-A-000155"],
    "source": "EN16931",                  # EN16931 FACTUR-X XRECHNUNG PEPPOL CII IP
    "versions": ["1.3.12", "1.3.16"],     # of the source's artefacts
    "profiles": ["basic-wl", "basic", "en16931", "xrechnung"],
    "id-profiles": {..},                  # optional, see below
    "scope": "payment",                   # document party line tax allowance-charge payment printed
    "terms": ["BT-9", "BT-20"],
    "level": "error",                     # or ["error", "warning"]: the first is the usual one
    "field": "payment-goal",              # the input the diagnostic names
    "summary": "...",                     # what it checks (the documentation of IP rules)
    "legal": null                         # the legal basis of a rule of invoice-pro
  }

`profiles` are the profiles in which the check can report, `id-profiles`
the profiles of each id of `covers` that applies in fewer of them, e.g.
{"BR-S-05": ["basic", "en16931", "xrechnung"]} for the rule of the lines of
an entry that BASIC WL (no lines) reports for allowances and charges only.
A rule of the Factur-X Schematron (FX-SCH-*) counts in the Factur-X
profiles only, never in XRechnung, which is not validated with it; one the
entry reports has its profiles in `id-profiles`. So `covering` and
`reported_in` are exact: an entry claims an id only in the profiles in which
its check can report it (or, for an alias, the rule it implements).
rule_coverage.py checks both against the rules of the validators of each
profile (REGISTRY), and run.py every diagnostic of the corpus against
`reported_in` (O-REGISTRY), as the helpers of the Typst tests do.

--check reports every problem: of the entries, of the keys that have no
message or no check (a key the rule modules do not name) and of the rule
ids the rule modules name that the registry does not know; a `_warnings` of
engine.typ that is not the keys whose usual level is "warning"; a
registry.json that is not in the layout of `dump`; a table of the
documentation that differs from the generated one; with the Mustang jar
($MUSTANG_JAR or --jar), `covers` that lacks a Factur-X alias of a rule it
covers or names one of another rule. --format rewrites registry.json in the
layout of `dump`, --write-docs the table of the documentation.
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
REGISTRY = HERE / "registry.json"
ENGINE = RULES / "engine.typ"
MESSAGES = RULES / "messages.typ"
# The messages of the rules of XRechnung that no other profile reports, which
# `diagnostics` of engine.typ looks up first for a key starting with BR-DE-.
XRECHNUNG_MESSAGES = RULES / "xrechnung-messages.typ"
XRECHNUNG_PREFIX = "BR-DE-"
MODULES = [
    ENGINE,
    RULES / "rare.typ",
    RULES / "xrechnung.typ",
]
DOCS = REPO / "docs" / "docs" / "e-invoicing" / "validation.md"

PROFILES = ("minimum", "basic-wl", "basic", "en16931", "xrechnung")
# The profiles validated with the Factur-X Schematron (Mustang applies none
# to XRechnung), in which its rules (FX-SCH-*) count.
FACTUR_X_PROFILES = ("minimum", "basic-wl", "basic", "en16931")
SOURCES = ("EN16931", "FACTUR-X", "XRECHNUNG", "PEPPOL", "CII", "IP")
SCOPES = ("document", "party", "line", "tax", "allowance-charge", "payment", "printed")
LEVELS = ("error", "warning")
FIELDS = {
    "covers": list, "source": str, "versions": list, "profiles": list, "scope": str, "terms": list,
    "level": (str, list), "field": str, "summary": str, "legal": (str, type(None)),
}
OPTIONAL = {"ids": list, "id-profiles": dict, "note": str}
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


def dump(registry):
    """The text of registry.json: the entries in their order, one line per
    field, a list on one line, and a field that is a dictionary
    (`id-profiles`) with one line per key (so that a change of a rule is a
    change of its lines)."""

    def value(v):
        return json.dumps(v, ensure_ascii=False)

    def members(items, indent):
        items = list(items)
        out = []
        for i, (key, v) in enumerate(items):
            comma = "," if i < len(items) - 1 else ""
            if isinstance(v, dict) and v:
                out.append(f"{indent}{json.dumps(key)}: {{")
                out += members(v.items(), indent + "  ")
                out.append(f"{indent}}}{comma}")
            else:
                out.append(f"{indent}{json.dumps(key)}: {value(v)}{comma}")
        return out

    lines = ["{", f'  "format": {value(registry["format"])},', '  "sources": {']
    lines += members(registry["sources"].items(), "    ")
    lines += ["  },", '  "rules": {']
    rules = list(registry["rules"].items())
    for i, (key, entry) in enumerate(rules):
        lines.append(f"    {json.dumps(key)}: {{")
        lines += members(entry.items(), "      ")
        lines.append("    }" + ("," if i < len(rules) - 1 else ""))
    lines += ["  }", "}"]
    return "\n".join(lines) + "\n"


def layout_problems(registry, path=REGISTRY):
    """registry.json, if it is not in the layout of `dump`."""
    if Path(path).read_text(encoding="utf-8") == dump(registry):
        return []
    return [f"{_shown(path)}: not in the layout of `dump` (run `python3 tools/zugferd/registry.py --format`)"]


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
        out += _id_profile_problems(key, entry, where)
    return out


def _id_profile_problems(key, entry, where):
    """What is wrong with `id-profiles` of an entry, and with the profiles of
    the ids it reports."""
    out = []
    id_profiles = entry.get("id-profiles", {})
    if not isinstance(id_profiles, dict):
        return out
    for rule, profiles in id_profiles.items():
        at = f"{where}.id-profiles.{rule}"
        if rule not in entry["covers"]:
            out.append(f"{at}: not a rule of `covers`")
        if not isinstance(profiles, list) or not profiles or any(p not in entry["profiles"] for p in profiles):
            out.append(f"{at}: {profiles} is no list of profiles of the entry")
            continue
        if profiles != [p for p in PROFILES if p in profiles]:
            out.append(f"{at}: not in the order {PROFILES}")
        if profiles == entry["profiles"]:
            out.append(f"{at}: the profiles of the entry (leave it out)")
        if rule.startswith("FX-") and "xrechnung" in profiles:
            out.append(f"{at}: a rule of the Factur-X Schematron does not count in XRechnung")
    for rule in ids(key, entry):
        if rule.startswith("FX-") and rule not in id_profiles:
            out.append(f"{where}.id-profiles: lacks {rule}, a rule of the Factur-X Schematron the entry reports")
    reporting = {p for rule in ids(key, entry) for p in profiles_of(entry, rule)}
    for profile in entry["profiles"]:
        if profile not in reporting:
            out.append(f"{where}.profiles: {profile}, in which it reports none of its ids")
    return out


def profiles_of(entry, rule):
    """The profiles in which an id of `covers` (or one of `ids`) counts: its
    `id-profiles`, else the profiles of the entry; a rule of the Factur-X
    Schematron counts in the Factur-X profiles only."""
    profiles = entry.get("id-profiles", {}).get(rule, entry["profiles"])
    if rule.startswith("FX-"):
        profiles = [p for p in profiles if p in FACTUR_X_PROFILES]
    return list(profiles)


def reported(registry):
    """The ids the rules report, each with the keys of the entries that
    report it: {id: [key, ..]}."""
    out = collections.defaultdict(list)
    for key, entry in registry["rules"].items():
        for rule in ids(key, entry):
            out[rule].append(key)
    return dict(out)


def reported_in(registry, profile):
    """The ids the rules report in a profile, each with the keys of the
    entries that report it there: {id: [key, ..]}."""
    out = collections.defaultdict(list)
    for key, entry in registry["rules"].items():
        for rule in ids(key, entry):
            if profile in profiles_of(entry, rule):
                out[rule].append(key)
    return dict(out)


def covering(registry, profile):
    """The official rules the checks of the registry implement in a profile,
    each in the profiles of its `id-profiles` (see `profiles_of`):
    {official id: [key, ..]}."""
    out = collections.defaultdict(list)
    for key, entry in registry["rules"].items():
        for rule in entry["covers"]:
            if profile in profiles_of(entry, rule):
                out[rule].append(key)
    return dict(out)


# ---------------------------------------------------------------- the Typst side


def message_keys(path=MESSAGES):
    """The keys of the `messages` dictionary of messages.typ (or `path`)."""
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


_WARNINGS = re.compile(r"^#let _warnings = \(", re.M)
# The tokens of an array of string literals in Typst source: whitespace,
# comments, a string, a comma and the closing parenthesis.
_ARRAY_TOKEN = re.compile(r'\s+|//[^\n]*|/\*.*?\*/|"([^"\\\n]*)"|(,)|(\))', re.S)


def warning_keys(path=ENGINE):
    """The keys of the array `_warnings` of engine.typ (or `path`), read
    from the Typst source as it is written: the rules whose usual level is
    "warning", which `diagnostics` gives a finding without a level. Anything
    but string literals and comments in the array raises ValueError, and so
    does one string without a comma, which Typst reads as a string (`in`
    would then find any part of it)."""
    text = Path(path).read_text(encoding="utf-8")
    m = _WARNINGS.search(text)
    if not m:
        raise ValueError(f"{_shown(path)}: no array `#let _warnings = (..)`")
    keys, commas, pos = [], 0, m.end()
    while True:
        token = _ARRAY_TOKEN.match(text, pos)
        if token is None:
            raise ValueError(f"{_shown(path)}: `_warnings` is not an array of string literals "
                             f"(at {text[pos:pos + 30]!r})")
        pos = token.end()
        if token.group(1) is not None:
            keys.append(token.group(1))
        commas += token.group(2) is not None
        if token.group(3) is not None:
            break
    if len(keys) == 1 and not commas:
        raise ValueError(f"{_shown(path)}: `_warnings` is a string, not an array: write `(\"{keys[0]}\",)`")
    return keys


def source_problems(registry):
    """Keys without a message or a check, rule ids of the rule modules that
    the registry does not know, and a list `_warnings` of engine.typ that is
    not the keys whose usual (first) level is "warning"."""
    out = []
    rules = registry["rules"]
    xrechnung = message_keys(XRECHNUNG_MESSAGES)
    messages = message_keys() + xrechnung
    literals = module_literals()
    for key in rules:
        if key not in messages:
            out.append(f"{key}: no message in {MESSAGES.relative_to(REPO)} or {XRECHNUNG_MESSAGES.name}")
        if key not in literals:
            out.append(f"{key}: no check names it in src/zugferd/rules/")
    for key in sorted({key for key in messages if messages.count(key) > 1}):
        out.append(f"{key}: more than one message in src/zugferd/rules/")
    for key in messages:
        if key not in rules:
            out.append(f"{key}: a message of src/zugferd/rules/ without an entry")
    # engine.typ looks a message up in xrechnung-messages.typ only for a key
    # starting with BR-DE-, and the module holds the messages of the rules
    # that only XRechnung reports, so that only a finding of XRechnung loads
    # it.
    for key in xrechnung:
        if not key.startswith(XRECHNUNG_PREFIX) or rules.get(key, {}).get("profiles") != ["xrechnung"]:
            out.append(
                f"{key}: {XRECHNUNG_MESSAGES.name} holds the rules {XRECHNUNG_PREFIX}* that only XRechnung reports"
            )
    known = set(reported(registry)) | set(rules)
    for literal in sorted(literals):
        if RULE_ID.match(literal) and literal not in known:
            out.append(f"{literal}: a rule id of src/zugferd/rules/ that the registry does not know")
    out += warning_problems(registry)
    return out


def warning_problems(registry, path=ENGINE):
    """`_warnings` of engine.typ (or `path`), if it is not the keys whose
    usual (first) level is "warning": `diagnostics` gives a finding without a
    level the level "warning" for a key of the array, "error" for any other."""
    try:
        listed = warning_keys(path)
    except ValueError as e:
        return [str(e)]
    rules = registry["rules"]
    where = f"`_warnings` of {_shown(path)}"
    usual = {key for key, entry in rules.items() if levels(entry)[0] == "warning"}
    out = []
    for key in sorted({key for key in listed if listed.count(key) > 1}):
        out.append(f"{key}: twice in {where}")
    for key in sorted(usual - set(listed)):
        out.append(f"{key}: its usual level is \"warning\", but {where} does not list it")
    for key in sorted(set(listed) - usual):
        if key in rules:
            out.append(f"{key}: in {where}, but its usual level is \"{levels(rules[key])[0]}\"")
        else:
            out.append(f"{key}: in {where}, but the registry has no such entry")
    return out


# ---------------------------------------------------------------- documentation

# The tables of the documentation (DOCS) that list rules of the registry:
# the line that starts the table, its columns, and the entries (by key) it
# lists, each with its usual level and its summary. One table: the rules of
# invoice-pro.
DOC_TABLES = (
    ("| Rule ", ("Rule", "Level", "Checks"), lambda key, entry: entry["source"] == "IP"),
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


def rule_order(key):
    """A sort key that orders rule ids by their parts, numbers by value (so
    that IP-VAT-138 comes before IP-VAT-226 and IP-DOC-02 before IP-DOC-10)."""
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", key)]


def docs_tables(registry):
    """The generated tables, in the order of DOC_TABLES, each sorted by rule
    id (see `rule_order`) so that a reader finds a rule by its id."""
    out = []
    for _, columns, select in DOC_TABLES:
        entries = sorted(
            ((key, entry) for key, entry in registry["rules"].items() if select(key, entry)),
            key=lambda item: rule_order(item[0]),
        )
        rows = [[f"`{key}`", levels(entry)[0], entry["summary"]] for key, entry in entries]
        out.append(table(rows, list(columns)))
    return out


def _table_spans(lines, path=DOCS):
    """(start, end) of the tables of the rules in the documentation (the
    lines of `path`): for each of DOC_TABLES, the first table with its
    columns."""
    spans = []
    for start, columns, _ in DOC_TABLES:
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
    covers in a Factur-X profile, or names one of no rule it covers; and
    aliases that do not count in the Factur-X profiles of the rules they
    implement (`id-profiles`). A rule of the Factur-X Schematron that the
    entry reports itself (in `ids`, e.g. the code list rule FX-SCH-A-000040
    of MINIMUM and BASIC WL) needs no rule it implements."""
    out = []
    fx_profiles = set(FACTUR_X_PROFILES)
    for key, entry in registry["rules"].items():
        covers = set(entry["covers"])
        official = {r for r in covers if not r.startswith("FX-")}
        wanted = set()
        for rule in official:
            if fx_profiles & set(profiles_of(entry, rule)):
                wanted |= aliases.get(rule, set())
        named = {r for r in covers if r.startswith("FX-")}
        reported = set(ids(key, entry))
        for rule in sorted(wanted - named):
            out.append(f"rules.{key}.covers: lacks the Factur-X alias {rule}")
        for rule in sorted(named - wanted - reported):
            out.append(f"rules.{key}.covers: {rule} is no Factur-X alias of a rule it covers")
        for rule in sorted(named & wanted - reported):
            owners = [o for o in official if rule in aliases.get(o, set())]
            expected = [p for p in FACTUR_X_PROFILES if any(p in profiles_of(entry, o) for o in owners)]
            if profiles_of(entry, rule) != expected:
                out.append(f"rules.{key}.id-profiles: the alias {rule} counts in {profiles_of(entry, rule)}, "
                           f"the rules it implements in {expected}")
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="check the registry, the rule modules and the documentation")
    ap.add_argument("--format", action="store_true", help="rewrite registry.json in the layout of `dump`")
    ap.add_argument("--write-docs", action="store_true", help="rewrite the table of the rules in the documentation")
    ap.add_argument("--jar", default=os.environ.get("MUSTANG_JAR"), help="Mustang-CLI-2.14.0.jar, for the aliases")
    args = ap.parse_args(argv)
    try:
        registry = load()
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    if args.format:
        REGISTRY.write_text(dump(registry), encoding="utf-8")
    if args.write_docs:
        write_docs(registry)
    found = layout_problems(registry) + source_problems(registry) + docs_problems(registry)
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
