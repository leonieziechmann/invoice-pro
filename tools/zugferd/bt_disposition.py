"""Every business term of EN 16931 has a disposition in invoice-pro.

tools/zugferd/bt-disposition.toml says for every business term (BT-1 to
BT-165; BT-4 is not defined) and business group (BG-1 to BG-32) of the
semantic model of EN 16931-1 what invoice-pro does with it:

  input        an input of invoice-pro states it   (`input`: which one)
  derived      invoice-pro derives it              (`source`: from what)
  unsupported  invoice-pro does not state it       (`reason`: why)

The check fails when a term has no entry, an entry names no term of EN 16931,
or a disposition lacks its input, source or reason. So no business term is
left without a decision, and a value without an input of its own cannot end
up in another business term unnoticed (issue #42). scripts/zugferd-corpus
runs it before the corpus.

Usage: bt_disposition.py [TABLE]
"""

import argparse
import sys
import tomllib
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
TABLE = HERE / "bt-disposition.toml"

# The business terms and groups of EN 16931-1:2017.
TERMS = [f"BT-{n}" for n in range(1, 166) if n != 4] + [f"BG-{n}" for n in range(1, 33)]

# The key each disposition needs, next to `name`.
DISPOSITIONS = {"input": "input", "derived": "source", "unsupported": "reason"}
OPTIONAL = {"note"}


def load(path):
    """The parsed table (raises tomllib.TOMLDecodeError)."""
    return tomllib.loads(Path(path).read_text(encoding="utf-8"))


def check(table):
    """The problems of a parsed table, as messages; [] if it is complete."""
    terms = table.get("terms")
    if not isinstance(terms, dict):
        return ["the table has no [terms] table"]
    problems = [f"{term}: has no disposition" for term in TERMS if term not in terms]
    known = set(TERMS)
    for term, entry in terms.items():
        if term not in known:
            problems.append(f"{term}: is no business term of EN 16931 (BT-1 to BT-165 without BT-4, BG-1 to BG-32)")
            continue
        if not isinstance(entry, dict):
            problems.append(f"{term}: must be a table with `name` and `disposition`")
            continue
        if not str(entry.get("name", "")).strip():
            problems.append(f"{term}: has no `name`")
        disposition = entry.get("disposition")
        if disposition not in DISPOSITIONS:
            problems.append(f"{term}: disposition {disposition!r} is none of {', '.join(DISPOSITIONS)}")
            continue
        key = DISPOSITIONS[disposition]
        if not str(entry.get(key, "")).strip():
            problems.append(f"{term}: a disposition {disposition!r} needs `{key}`")
        unknown = sorted(set(entry) - {"name", "disposition", key} - OPTIONAL)
        if unknown:
            problems.append(f"{term}: unknown keys {', '.join(unknown)} (a {disposition!r} term has `{key}`)")
    return problems


def counts(table):
    """How many terms have each disposition."""
    return Counter(entry.get("disposition") for entry in table.get("terms", {}).values() if isinstance(entry, dict))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("table", nargs="?", default=str(TABLE), help="default: tools/zugferd/bt-disposition.toml")
    args = ap.parse_args(argv)
    try:
        table = load(args.table)
    except (OSError, tomllib.TOMLDecodeError) as e:
        print(f"✘ {args.table}: {e}")
        return 1
    problems = check(table)
    if problems:
        for problem in problems:
            print(f"  {problem}")
        print(f"✘ {len(problems)} problems in {args.table}: every business term of EN 16931 needs a disposition.")
        return 1
    summary = ", ".join(f"{name} {count}" for name, count in sorted(counts(table).items()))
    print(f"✔ {len(TERMS)} business terms of EN 16931 have a disposition ({summary}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
