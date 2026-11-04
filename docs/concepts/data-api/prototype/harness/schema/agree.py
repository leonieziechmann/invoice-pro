#!/usr/bin/env python3
"""Agreement of python-jsonschema (committed schema) and data.check on
arbitrary fixtures, independent of their expectation labels: agree when both
accept, both reject, the decoder accepts a documented leniency (a JSON
number for a decimal) that the schema rejects, or the decoder rejects a
value by a documented decoder-only rule (a base quantity of 0: the positive
decimal is a plain pattern for the code generators, invoice-pro asks for at
least 0.0001).
usage: agree.py schema.json fixtures.json typst-report.json"""
import json, sys
from jsonschema import Draft202012Validator, FormatChecker
schema, fixtures, typst = (json.load(open(p)) for p in sys.argv[1:4])
v = Draft202012Validator(schema, format_checker=FormatChecker()); tres = {r["name"]: r["report"] for r in typst}
ok = 0; bad = []
for c in fixtures:
    errs = list(v.iter_errors(c["doc"])); py = not errs; t = tres[c["name"]]["valid"]
    lenient = (not py) and t and all("is not of type 'string'" in e.message or "is not valid under any of the given schemas" in e.message for e in errs)
    decoder_only = py and not t and all(i["path"].endswith("/base-quantity") for i in tres[c["name"]]["issues"])
    agree = py == t or lenient or decoder_only
    print(f'{"OK " if agree else "XX "} {c["name"]:<26} D-expect={c["expect"]:<8} schema={"valid" if py else "invalid":<7} check={"valid" if t else "invalid"}{"  (lenient)" if lenient else ""}{"  (decoder-only)" if decoder_only else ""}')
    ok += agree; bad += [] if agree else [c["name"]]
print(f"\n{ok}/{len(fixtures)} agree; disagreements: {bad}"); sys.exit(1 if bad else 0)
