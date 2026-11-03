#!/usr/bin/env python3
"""Equivalence/benchmark generator (design C's gen.py, unified format).

For each kind (b basic, r rich, t tree) and size N it writes
  eq/data/<k>-<N>.json            the invoice as an invoice-pro/1 document
  eq/hand/<k>-<N>.typ             the SAME invoice written by hand (item/group/
                                  bundle/discount/prepayment calls), importing
                                  the lib given by --input lib (repo|pristine)
The hydrated variant is eq/skeleton.typ + --input invoice-pro-data-file=...
Both take --input zf=none|auto.
kinds b and r mirror tools/perf/gen_bench.py; t adds groups, bundles, bundle
discounts, item ids, notes, origins, dates, units and per-group VAT.
Unified format: units are UN/ECE codes, document modifiers and prepayments
are top-level arrays, a bundle's modifiers its own array.
"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(HERE), "eq")

def price(i): return f"{10 + (i * 37) % 400}.{i % 100:02d}"

RECIPIENT = {"name": "Acme Corp", "address": "Industrial Road 1",
             "city": {"name": "Stuttgart", "post-code": "70173"}, "country": "DE",
             "vat-id": "DE987654321", "buyer-reference": "DE123456789-12345-12"}
EXEMPT = "Steuerfrei nach § 4 Nr. 21 UStG"

def doc(kind, rows, extra=None):
    items = [r for r in rows if r.get("kind", "item") in ("item", "group", "bundle")]
    mods = [r for r in rows if r.get("kind") in ("discount", "surcharge")]
    pre = [{k: v for k, v in r.items() if k != "kind"} for r in rows if r.get("kind") == "prepayment"]
    d = {"format": "invoice-pro/1", "invoice-nr": "INV-2026-102", "date": "2026-07-08",
         "recipient": RECIPIENT, "tax": {"category": "S", "rate": "19%"}, "items": items,
         "payment": {"terms": {"days": 14}}}
    if mods: d["modifiers"] = mods
    if pre: d["prepayments"] = pre
    if kind == "r": d["tax-mode"] = "inclusive"
    if extra: d.update(extra)
    return d

def basic(n):
    return [{"name": "Position %d with a longer description text" % i, "quantity": str(i % 7 + 1),
             "unit": "HUR", "price": price(i)} for i in range(n)]

def rich(n):
    taxes = [None, "7%", {"category": "E", "grounds": EXEMPT}]
    out = []
    for i in range(n):
        r = {"name": "Position %d with a longer description text" % i, "quantity": str(i % 7 + 1),
             "unit": "HUR", "price": price(i)}
        if taxes[i % 3] is not None: r["tax"] = taxes[i % 3]
        if i % 5 == 0: r["modifiers"] = [{"kind": "discount", "name": "Stammkunde", "amount": "5%"}]
        out.append(r)
    out += [{"kind": "discount", "name": "Projektrabatt", "amount": "3%"},
            {"kind": "surcharge", "name": "Reisekosten", "amount": "150"},
            {"kind": "prepayment", "amount": "1000", "name": "Abschlag 1"}]
    return out

def tree(n):
    """groups of 10 lines; every 3rd group holds a bundle of 3 (2 VAT rates)."""
    out, i, g = [], 0, 0
    while i < n:
        kids = []
        while len(kids) < 10 and i < n:
            if g % 3 == 2 and len(kids) == 4 and i + 3 <= n:
                kids.append({"kind": "bundle", "name": "Paket %d" % i, "quantity": "2", "unit": "SET",
                             "items": [{"name": "Teil %d" % (i + k), "price": price(i + k),
                                        **({"tax": "7%"} if k == 2 else {})} for k in range(3)],
                             "modifiers": [{"kind": "discount", "name": "Paketrabatt", "amount": "10%"}]})
                i += 3
                continue
            r = {"name": "Position %d" % i, "description": "Leistung Nr. %d" % i,
                 "quantity": str(i % 4 + 1), "price": price(i), "item-id": {"seller": "A-%d" % i}}
            if i % 7 == 0: r["note"] = "Hinweis %d" % i
            if i % 11 == 0: r["origin"] = "AT"
            if i % 5 == 0: r["date"] = "2026-06-%02d" % (i % 28 + 1)
            if i % 6 == 0: r["modifiers"] = [{"kind": "surcharge", "name": "Express", "amount": "2.50"}]
            kids.append(r); i += 1
        grp = {"kind": "group", "name": "Abschnitt %d" % (g + 1), "items": kids}
        if g % 2 == 1: grp["tax"] = "7%"
        if g % 4 == 0: grp["unit"] = "HUR"
        if g % 3 == 0: grp["description"] = "Beschreibung Abschnitt %d" % (g + 1)
        out.append(grp); g += 1
    out += [{"kind": "discount", "name": "Treuerabatt", "amount": "2%"},
            {"kind": "prepayment", "amount": "10%", "name": "Abschlag", "date": "2026-06-15"}]
    return out

# ---- Typst literals of the same data, written as a person would -----------
def s(x): return json.dumps(x, ensure_ascii=False)
UNIT = {"HUR": "unit.hour", "SET": "unit.unit-set"}
def tax_lit(t):
    if isinstance(t, str): return "tax.vat(%s)" % t
    if t["category"] == "E": return "tax.exempt(grounds: %s)" % s(t["grounds"])
    if t["category"] == "S": return "tax.vat(%s)" % t["rate"]
    raise ValueError(t)
def date_lit(d):
    y, m, dd = d.split("-"); return "datetime(year: %d, month: %d, day: %d)" % (int(y), int(m), int(dd))
def mod_lit(m):
    amt = m["amount"] if m["amount"].endswith("%") else s(m["amount"])
    return "%s(%s, amount: %s)" % (m["kind"], s(m["name"]), amt)
def row_lit(r, ind="  "):
    k = r.get("kind", "item")
    if k == "item":
        a = [s(r["name"])]
        if "description" in r: a.append("description: " + s(r["description"]))
        if "quantity" in r: a.append("quantity: " + s(r["quantity"]))
        if "unit" in r: a.append("unit: " + UNIT[r["unit"]])
        a.append("price: " + s(r["price"]))
        if "tax" in r: a.append("tax: " + tax_lit(r["tax"]))
        if "date" in r: a.append("date: " + date_lit(r["date"]))
        if "item-id" in r: a.append("item-id: " + s(r["item-id"]["seller"]))
        if "note" in r: a.append("note: " + s(r["note"]))
        if "origin" in r: a.append("origin: " + s(r["origin"]))
        if "modifiers" in r: a.append("modifier: " + ", ".join(mod_lit(m) for m in r["modifiers"]))
        return ind + "#item(" + ", ".join(a) + ")\n"
    if k in ("discount", "surcharge"): return ind + "#" + mod_lit(r) + "\n"
    if k == "prepayment":
        amt = r["amount"] if r["amount"].endswith("%") else r["amount"]
        a = [amt, "name: " + s(r["name"])]
        if "date" in r: a.append("date: " + date_lit(r["date"]))
        return ind + "#prepayment(" + ", ".join(a) + ")\n"
    if k == "group":
        a = [s(r["name"])]
        if "description" in r: a.append("description: " + s(r["description"]))
        if "tax" in r: a.append("tax: " + tax_lit(r["tax"]))
        if "unit" in r: a.append("unit: " + UNIT[r["unit"]])
        return ind + "#group(" + ", ".join(a) + ")[\n" + "".join(row_lit(c, ind + "  ") for c in r["items"]) + ind + "]\n"
    if k == "bundle":
        a = [s(r["name"])]
        if "quantity" in r: a.append("quantity: " + s(r["quantity"]))
        if "unit" in r: a.append("unit: " + UNIT[r["unit"]])
        return ind + "#bundle(" + ", ".join(a) + ")[\n" + "".join(row_lit(c, ind + "  ") for c in r["items"] + r.get("modifiers", [])) + ind + "]\n"
    raise ValueError(k)

HAND_HEAD = """// Generated by gen.py: the invoice of data/%(name)s.json written by hand.
#import "/" + sys.inputs.at("lib", default: "repo") + "/src/lib.typ": *
#let zf = sys.inputs.at("zf", default: "none")
#show: invoice.with(
  theme: theme.classic,
  zugferd: if zf == "none" { none } else if zf == "auto" { auto } else { zf },
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: "DE",
    tax-nr: "143/123/45678",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@consultinggroup.de",
    ),
  ),
  recipient: (
    name: "Acme Corp",
    address: "Industrial Road 1",
    city: (name: "Stuttgart", post-code: "70173"),
    country: "DE",
    vat-id: "DE987654321",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "INV-2026-102",
  date: datetime(year: 2026, month: 7, day: 8),
  tax: tax.vat(19%%),%(extra)s
)
#line-items[
"""
HAND_TAIL = """]
#payment-terms(days: 14)
#bank-details(
  bank: "Global Business Bank",
  iban: "DE89370400440532013000",
  bic: "GBBADEFFXXX",
)
"""
KINDS = {"b": basic, "r": rich, "t": tree}
def main():
    sizes = [int(x) for x in (sys.argv[1] if len(sys.argv) > 1 else "5,50,300,1000").split(",")]
    kinds = (sys.argv[2] if len(sys.argv) > 2 else "b,r,t").split(",")
    os.makedirs(os.path.join(ROOT, "data"), exist_ok=True); os.makedirs(os.path.join(ROOT, "hand"), exist_ok=True)
    for k in kinds:
        for n in sizes:
            name = "%s-%d" % (k, n)
            d = doc(k, KINDS[k](n))
            json.dump(d, open(os.path.join(ROOT, "data", name + ".json"), "w"), ensure_ascii=False, indent=1)
            extra = '\n  tax-mode: "inclusive",' if k == "r" else ""
            rows = d["items"] + d.get("modifiers", []) + [dict(p, kind="prepayment") for p in d.get("prepayments", [])]
            body = "".join(row_lit(r) for r in rows)
            open(os.path.join(ROOT, "hand", name + ".typ"), "w").write(HAND_HEAD % {"name": name, "extra": extra} + body + HAND_TAIL)
main()
