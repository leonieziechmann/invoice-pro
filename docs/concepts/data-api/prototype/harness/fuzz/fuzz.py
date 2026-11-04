#!/usr/bin/env python3
"""P4 fault corpus: the engine judge's 38 single-fault documents
(<session>/judge-engine/scripts/fuzz.py, unified format: prepayments are
top-level, periods are objects) plus the faults the judges found later.
usage: fuzz.py TYPST [zf] [default|draft] [names...]
  -> one line per fault; exit code = hard aborts + wrong outcomes
Two modes (the decision on Q1: a hydrated invoice stops on any problem):
- default: no level is given, so a fault must end in the deliberate strict
  stop that lists the problems and ends with the debug hint, or in a clean
  PDF; a draft PDF would be a broken invoice shipped by default;
- draft: `--input invoice-pro-validation=draft`, the debug view: a fault
  must give a PDF; a draft (badge) carries no embedded file.
A hard abort is any other failed compile, except the deliberate format-major
panic (and, with zf=auto, e-invoice rule errors, which stop the compile by
design)."""
import json, copy, subprocess, sys, os, re
HERE = os.path.dirname(os.path.abspath(__file__)); U = os.path.dirname(os.path.dirname(HERE))
T = sys.argv[1]; zf = sys.argv[2] if len(sys.argv) > 2 else "none"; rest = sys.argv[3:]
mode = rest.pop(0) if rest and rest[0] in ("default", "draft") else "default"; only = rest
def first(d): return d["items"][0]
def nest(n):
    g = {"name": "Tief", "price": "1.00"}
    for i in range(n): g = {"kind": "group", "name": f"G{i}", "items": [g]}
    return g
def prepay(d, amt): d.setdefault("prepayments", []).append({"amount": amt})
def nullfill(schema, doc, node=None):
    """What a generated model dumps (pydantic model_dump(), serde without
    skip_serializing_if): every optional property the document leaves out is
    written as null, recursively, following the JSON Schema."""
    defs = schema["$defs"]
    def resolve(s):
        while "$ref" in s: s = defs[s["$ref"].split("/")[-1]]
        return s
    def fill(s, v):
        s = resolve(s)
        for alt in s.get("anyOf", []) + s.get("oneOf", []):
            a = resolve(alt)
            if isinstance(v, dict) and a.get("type") == "object":
                ok = all(k in a.get("properties", {}) for k in v) and all(
                    "const" not in resolve(a["properties"][k]) or resolve(a["properties"][k])["const"] == v.get(k, resolve(a["properties"][k])["const"])
                    for k in a.get("properties", {}) if k == "kind")
                if ok: return fill(a, v)
            if isinstance(v, list) and a.get("type") == "array": return fill(a, v)
        if isinstance(v, dict) and s.get("type") == "object" and s.get("additionalProperties") is False:
            out = {}
            for k, ps in s.get("properties", {}).items():
                out[k] = fill(ps, v[k]) if k in v else None
            return out
        if isinstance(v, list) and "items" in s: return [fill(s["items"], x) for x in v]
        return v
    return fill(schema, doc)
M = {
 "tax16":      lambda d: first(d).__setitem__("tax", "16%"),
 "tax0":       lambda d: first(d).__setitem__("tax", "0%"),
 "qty_exp":    lambda d: first(d).__setitem__("quantity", "1e3"),
 "qty_29dig":  lambda d: first(d).__setitem__("quantity", "99999999999999999999999999999"),
 "qty_manydec":lambda d: first(d).__setitem__("quantity", "1.23456789012345678901234567890"),
 "qty_neg":    lambda d: first(d).__setitem__("quantity", "-2"),
 "qty_arabic": lambda d: first(d).__setitem__("quantity", "١٢"),
 "price_1e300":lambda d: (first(d).pop("total", None), first(d).__setitem__("price", 1e300)),
 "price_1e-30":lambda d: (first(d).pop("total", None), first(d).__setitem__("price", 1e-30)),
 "price_bool": lambda d: (first(d).pop("total", None), first(d).__setitem__("price", True)),
 "price_ws":   lambda d: (first(d).pop("total", None), first(d).__setitem__("price", " 12.30 ")),
 "price_big":  lambda d: (first(d).pop("total", None), first(d).__setitem__("price", "9999999999999999999999.99")),
 "baseq_zero": lambda d: d["items"].__setitem__(0, {"name": "Z", "price": "1.00", "base-quantity": "0"}),
 "date_0229":  lambda d: d.__setitem__("date", "2026-02-29"),
 "date_y0":    lambda d: d.__setitem__("date", "0000-01-01"),
 "date_num":   lambda d: d.__setitem__("date", 20260302),
 "period_rev": lambda d: d.__setitem__("service-period", {"start": "2026-02-28", "end": "2026-02-01"}),
 "items_obj":  lambda d: d.__setitem__("items", {"name": "x"}),
 "item_str":   lambda d: d["items"].__setitem__(0, "Beratung"),
 "items_empty":lambda d: d.__setitem__("items", []),
 "name_num":   lambda d: first(d).__setitem__("name", 42),
 "name_empty": lambda d: first(d).__setitem__("name", ""),
 "rcpt_str":   lambda d: d.__setitem__("recipient", "Edge AG"),
 "country_bad":lambda d: d["recipient"].__setitem__("country", "Germany"),
 "currency_bad":lambda d: d.__setitem__("currency", "EURO"),
 "vatid_num":  lambda d: d["recipient"].__setitem__("vat-id", 123),
 "unit_obj":   lambda d: first(d).__setitem__("unit", {"code": 5}),
 "unit_free":  lambda d: first(d).__setitem__("unit", "Fass"),
 "depth12":    lambda d: d["items"].append(nest(12)),
 "disc150":    lambda d: first(d).__setitem__("modifiers", [{"kind": "discount", "name": "X", "amount": "150%"}]),
 "mods_str":   lambda d: first(d).__setitem__("modifiers", "10%"),
 "prepay_huge":lambda d: prepay(d, "100000.00"),
 "tax_nocat":  lambda d: first(d).__setitem__("tax", {"rate": "19%"}),
 "tax_badcat": lambda d: first(d).__setitem__("tax", {"category": "XX"}),
 "tax_S_norate":lambda d: first(d).__setitem__("tax", {"category": "S"}),
 "pct_garbage":lambda d: first(d).__setitem__("modifiers", [{"kind": "discount", "name": "X", "amount": "abc%"}]),
 "kind_bad":   lambda d: first(d).__setitem__("kind", "grop"),
 "itemid_num": lambda d: first(d).__setitem__("item-id", 123),
 "due_text":   lambda d: d.__setitem__("due-date", "14 Tage"),
 "format2":    lambda d: d.__setitem__("format", "invoice-pro/2"),
 # ---- new faults (judges, synthesis §8.4) --------------------------------
 "kind_null":  lambda d: first(d).__setitem__("kind", None),
 "kind_num":   lambda d: first(d).__setitem__("kind", 3),
 "mod_no_items":lambda d: (d.__setitem__("items", [{"name": "ohne Preis"}]), d.__setitem__("modifiers", [{"kind": "discount", "name": "Rabatt", "amount": "10.00"}])),
 "bundle_mod_no_items":lambda d: d["items"].__setitem__(4, {"kind": "bundle", "name": "Leer", "items": [{"name": "x"}], "modifiers": [{"kind": "discount", "name": "R", "amount": "1.00"}]}),
 "bundle_empty":lambda d: d["items"].append({"kind": "bundle", "name": "Leer", "items": []}),
 "group_empty":lambda d: d["items"].append({"kind": "group", "name": "Leer", "items": []}),
 "qty_29num":  lambda d: first(d).__setitem__("quantity", 99999999999999999999999999999),
 "price_30dig":lambda d: (first(d).pop("total", None), first(d).__setitem__("price", "99999999999999999999.9999999999")),
 "amount_range":lambda d: (first(d).pop("total", None), first(d).__setitem__("price", "99999999999999999999"), first(d).__setitem__("quantity", "99999999999999999999")),
 "baseq_tiny": lambda d: first(d).__setitem__("base-quantity", "0.0000000001"),
 "null_in_array":lambda d: d["items"].append(None),
 "note_in_bundle":lambda d: d["items"][4]["items"][0].__setitem__("note", "x"),
 "group_in_bundle":lambda d: d["items"][4]["items"].append({"kind": "group", "name": "G", "items": [{"name": "a", "price": "1"}]}),
 "prepay_in_items":lambda d: d["items"].append({"kind": "prepayment", "amount": "10.00"}),
 "date_0230":  lambda d: d.__setitem__("date", "2026-02-30"),
 "smallbiz_and_tax":lambda d: (d.__setitem__("tax-exempt-small-biz", True), d.__setitem__("tax", "19%")),
 "mandate_missing":lambda d: d.__setitem__("payment", {"method": "direct-debit"}),
 "card_no_last4":lambda d: d.__setitem__("payment", {"method": "card"}),
 "paid_and_terms":lambda d: d.__setitem__("payment", {"paid": {"method": "cash"}, "terms": {"days": 14}}),
 "terms_days_and_text":lambda d: d.__setitem__("payment", {"terms": {"days": 14, "text": "sofort"}}),
 "leitweg_bad":lambda d: d["recipient"].__setitem__("leitweg-id", "123"),
 "gln_bad":    lambda d: d["recipient"].__setitem__("global-id", {"scheme": "gln", "id": "abc"}),
 "custom_str": lambda d: d.__setitem__("custom", "x"),
 "notes_num":  lambda d: d.__setitem__("notes", [1, 2]),
 "city_num_plz":lambda d: d["recipient"].__setitem__("city", {"name": "Köln", "post-code": 50667}),
 "deep_custom":lambda d: d.__setitem__("custom", {"a": {"b": [None, {"c": None}]}}),
 "item_mod_tax":lambda d: first(d).__setitem__("modifiers", [{"kind": "discount", "name": "X", "amount": "1.00", "tax": "7%"}]),
 "bundle_bq_tiny":lambda d: d["items"][4].__setitem__("base-quantity", "0.00001"),
 "pydantic_dump":"dump",
}
def main():
    base = json.load(open(os.path.join(HERE, "base.json")))
    schema = json.load(open(os.path.join(U, "repo/src/contract/invoice.schema.json")))
    names = only or list(M)
    aborts = 0; wrong = 0; out = []
    V = subprocess.run([T, "--version"], capture_output=True, text=True).stdout.split()[1]
    for name in names:
        d = copy.deepcopy(base)
        if M[name] == "dump": d = nullfill(schema, d)
        else: M[name](d)
        f = f"proto/fuzz/corpus/{name}.json"; json.dump(d, open(os.path.join(U, f), "w"), ensure_ascii=False)
        pdf = os.path.join(HERE, "out", f"{V}-{zf}-{name}.pdf"); os.makedirs(os.path.dirname(pdf), exist_ok=True)
        if os.path.exists(pdf): os.remove(pdf)
        cmd = [T, "compile", "--root", U, "--input", f"f=/{f}", "--input", f"zf={zf}", "--creation-timestamp", "1767225600", os.path.join(HERE, "sk.typ"), pdf]
        if mode == "draft": cmd += ["--input", "invoice-pro-validation=draft"]
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        stop = "in the hydrated invoice, which stops on any problem" in p.stderr
        if p.returncode == 0:
            txt = subprocess.run(["pdftotext", pdf, "-"], capture_output=True, text=True).stdout
            m = re.search(r"ENTWURF[^\n]*", txt)
            att = subprocess.run(["pdfdetach", "-list", pdf], capture_output=True, text=True).stdout.split("\n")[0]
            res = "PDF " + (m.group(0) if m else "clean") + f" ({att})"
            # a draft by default, or a draft with an e-invoice, is a wrong outcome
            if m and (mode == "default" or not att.startswith("0 ")):
                wrong += 1; res = "WRONG " + res
        elif mode == "default" and stop:
            n = len(re.findall(r"(?m)^  \d+\. |\\n  \d+\. ", p.stderr))
            hint = "To debug, render the draft with --input invoice-pro-validation=draft" in p.stderr
            if not hint or n == 0: wrong += 1
            res = f"STOP (strict by default: {n} problem(s){', debug hint' if hint else ', NO HINT'})"
        else:
            m = re.search(r"error: (.*)", p.stderr); msg = m.group(1) if m else p.stderr.strip().splitlines()[-1]
            loc = re.search(r"┌─ (\S+)", p.stderr); loc = loc.group(1) if loc else ""
            deliberate = name == "format2" and "invoice-pro/2" in msg
            # e-invoice rule errors stop the compilation by design
            # (`zugferd-errors: "panic"`, the default; SYNTHESIS.md §5.6)
            rules = "The e-invoice (ZUGFeRD" in p.stderr
            if not (deliberate or rules): aborts += 1
            kind = "PANIC (deliberate) " if deliberate else "E-INVOICE RULES (by design) " if rules else "ABORT "
            rule = re.search(r"\[((?:BR|IP|CII|PEPPOL)[^\]]*)\]", p.stderr)
            res = kind + (f"{rule.group(1)} " if rules and rule else "") + f"[{loc}] {msg[:160]}"
        print(f"{V} {name:20} {res}", flush=True)
    print(f"{V} zf={zf} mode={mode} faults={len(names)} hard-aborts={aborts} wrong-outcomes={wrong}")
    sys.exit(aborts + wrong)
if __name__ == "__main__": main()
