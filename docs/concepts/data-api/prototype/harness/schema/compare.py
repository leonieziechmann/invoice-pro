# (design D) Differential conformance: python-jsonschema (the exported JSON Schema) vs
# the Typst decoder (invoice-data.check) on the same fixtures.
import json, sys
from jsonschema import Draft202012Validator, FormatChecker
schema = json.load(open(sys.argv[1])); fixtures = json.load(open(sys.argv[2])); typst = json.load(open(sys.argv[3]))
v = Draft202012Validator(schema, format_checker=FormatChecker())
tres = {r["name"]: r["report"] for r in typst}
def ptr(p): return "".join("/" + str(k).replace("~", "~0").replace("/", "~1") for k in p)
ok = 0; bad = []
for c in fixtures:
    errs = list(v.iter_errors(c["doc"]))
    py_valid = not errs
    py_paths = sorted({ptr(e.absolute_path) for e in errs})
    t = tres[c["name"]]
    t_paths = sorted({i["path"] for i in t["issues"]})
    exp = c["expect"]
    if exp == "valid": agree = py_valid and t["valid"]
    elif exp == "lenient": agree = (not py_valid) and t["valid"]
    elif exp == "decoder-only": agree = py_valid and (not t["valid"])
    else:
        # both reject, and every schema error path has a Typst issue on the same branch
        agree = (not py_valid) and (not t["valid"]) and all(any(tp.startswith(pp) or pp.startswith(tp) for tp in t_paths) for pp in py_paths)
    line = f'{"OK " if agree else "XX "} {c["name"]:<26} expect={exp:<8} schema={"valid" if py_valid else "invalid":<7} {py_paths}  typst={"valid" if t["valid"] else "invalid":<7} {t_paths}'
    print(line)
    if agree: ok += 1
    else: bad.append(c["name"])
print(f"\n{ok}/{len(fixtures)} agree; disagreements: {bad}")
sys.exit(0 if not bad else 1)
