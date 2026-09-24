#!/usr/bin/env python3
"""Generator of the e-invoice conformance corpus.

Writes Typst invoices plus a manifest (`manifest.json`) into a build
directory. Every case states what the runner (`tools/zugferd/run.py`) must
observe: the expected class, the rules invoice-pro must report and the facts
the XML must carry (the semantic oracles).

Populations
  legal        pairwise (greedy all-pairs) over the dimensions below, plus a
               seeded random sample, restricted by `allowed()` to legal,
               complete real-world invoices -> AGREE_VALID, all oracles green
  mutation     a legal invoice with one required input removed ->
               AGREE_INVALID and invoice-pro names the rule, or, for a
               detail the law requires on the printed invoice (custom
               references of the DIN 5008 letter), STRICTER and its own rule
  metamorphic  twins that must agree on amounts: bundle quantity 1 vs 2,
               reversed line order, items split into two lines, another
               profile, another currency
  adversarial  legal invoices with unusual but valid input forms (content,
               Unicode, numbers as post codes, ...) -> no crash, no lost data
  random       nightly: random invoices WITHOUT the legal constraints ->
               invoice-pro and the official validators agree, or invoice-pro
               applies one of its own rules or stops with its own message
               (no FN/FP/CRASH)

The cases are written to <out>/<id>.typ and import `/src/lib.typ` and the
harness `/tools/zugferd/harness.typ`, so <out> must be inside the repository
(the Typst root). The same seed gives the same cases.

Usage: gen.py [--out DIR] [--seed N] [--population legal|pr|nightly]
              [--legal-extra N] [--random N]
"""

import argparse
import itertools
import json
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import common  # noqa: E402

DIMS = {
    "profile": ["minimum", "basic-wl", "basic", "en16931", "xrechnung", "auto"],
    # "ch-fr": a Swiss seller, identified by its legal registration
    # identifier, supplies goods from Germany to France through its German
    # fiscal representative (BG-11), which holds its VAT registration.
    "route": ["de-de", "de-fr", "de-at", "de-us", "de-ch", "at-de", "fr-fr", "ch-ch", "ch-fr"],
    # "e-code": exempt items with the VATEX code of the exemption (BT-121).
    "tax": ["s", "s2", "s-e", "s-z", "e2", "e-code", "ae", "k", "g", "o", "smallbiz"],
    "mode": ["exclusive", "inclusive"],
    "mods": ["none", "item-pct", "item-abs", "doc-pct", "doc-abs-disc", "doc-abs-sur", "bundle2-pct", "free-ship"],
    "amounts": ["plain", "fractional", "large", "credit-line"],
    # "legal": both parties identified by their legal registration identifier
    # (BT-30, BT-47) instead of VAT IDs; the seller states its tax number.
    "ids": ["vat", "taxnr", "vat+taxnr", "id", "gln", "legal"],
    "payment": ["bank+days", "bank+due", "nobank+days", "bank+immediate", "direct-debit", "card", "paid"],
    # "period": the service period of the invoice (`service-period`).
    "delivery": ["none", "addr", "dates-all", "dates-mixed", "period"],
    "lines": [1, 3, 8],
    # "din-5008-refs": the DIN 5008 letter with references of its own, which
    # print what the law requires (IP-PRINT-03, IP-PERIOD-03).
    "theme": ["blank", "din-5008", "din-5008-refs"],
    # Document type (BT-3): 380, 381, 384, 389.
    "doctype": ["invoice", "credit-note", "corrected", "self-billed"],
    # Invoice notes (BT-21/22), note and country of origin of an item
    # (BT-127, BT-159), a factoring company as payee (BG-10).
    "extras": ["none", "notes", "item-data", "payee"],
    # The currency of the locale, or US dollars (BT-5).
    "currency": ["default", "usd"],
}

# The simplest value of every dimension (minimizer target, mutation base).
SIMPLE = {
    "profile": "en16931",
    "route": "de-fr",
    "tax": "s",
    "mode": "exclusive",
    "mods": "none",
    "amounts": "plain",
    "ids": "vat",
    "payment": "bank+days",
    "delivery": "none",
    "lines": 1,
    "theme": "blank",
    "doctype": "invoice",
    "extras": "none",
    "currency": "default",
}

EU = {"de", "fr", "at"}

# Test parties. All identifiers carry valid check digits, so that checks of
# check digits never turn a legal case red.
SELLER = {
    "de": dict(
        name="Muster GmbH",
        address="Hauptstraße 1",
        city='(name: "Berlin", post-code: "10115")',
        country="de",
        vat="DE123456788",
        taxnr="30/123/45678",
        legal='id.register("HRB 4711", court: "Amtsgericht Charlottenburg")',
        legal_fact=["", "Amtsgericht Charlottenburg, HRB 4711"],
        locale="de-de",
        currency="EUR",
        rates=("19%", "7%"),
        iban="DE89370400440532013000",
        bic="COBADEFFXXX",
        contact='(name: "Max Muster", phone: "+49 30 1234567", email: "rechnung@muster.example")',
    ),
    "at": dict(
        name="Muster GmbH",
        address="Mariahilfer Straße 1",
        city='(name: "Wien", post-code: "1060")',
        country="at",
        vat="ATU12345675",
        taxnr="12 345/6789",
        legal='id.register("FN 123456 a", court: "Handelsgericht Wien")',
        legal_fact=["", "Handelsgericht Wien, FN 123456 a"],
        locale="de-at",
        currency="EUR",
        rates=("20%", "10%"),
        iban="AT611904300234573201",
        bic="BKAUATWWXXX",
        contact='(name: "Max Muster", phone: "+43 1 1234567", email: "rechnung@muster.example")',
    ),
    "fr": dict(
        name="Muster SARL",
        address="1 Rue de Rivoli",
        city='(name: "Paris", post-code: "75001")',
        country="fr",
        vat="FR40303265045",
        taxnr="303265045",
        legal='id.siret("303 265 045 00011")',
        legal_fact=["0009", "30326504500011"],
        locale="fr-fr",
        currency="EUR",
        rates=("20%", "5.5%"),
        iban="FR1420041010050500013M02606",
        bic="PSSTFRPPPAR",
        contact='(name: "Max Muster", phone: "+33 1 23456789", email: "facture@muster.example")',
    ),
    "ch": dict(
        name="Muster AG",
        address="Bahnhofstrasse 1",
        city='(name: "Zürich", post-code: "8001")',
        country="ch",
        vat="CHE123456788",
        taxnr="CHE-123.456.788",
        legal='id.uid-ch("CHE-123.456.788")',
        legal_fact=["0183", "CHE123456788"],
        locale="de-ch",
        currency="CHF",
        rates=("8.1%", "2.6%"),
        iban="CH9300762011623852957",
        bic="UBSWCHZH80A",
        contact='(name: "Max Muster", phone: "+41 44 1234567", email: "rechnung@muster.example")',
    ),
}
# `iban` is the account a credit note is paid to, the one a direct debit
# collects from, and the seller's account on a self-billed invoice (where the
# recipient is the seller).
BUYER = {
    "de": dict(
        name="Kunde AG",
        address="Domstraße 5",
        city='(name: "Köln", post-code: "50667")',
        country="de",
        vat="DE987654328",
        legal='id.register("HRB 12345", court: "Amtsgericht Köln")',
        legal_fact=["", "Amtsgericht Köln, HRB 12345"],
        email="eingang@kunde.example",
        iban="DE75512108001245126199",
    ),
    "fr": dict(
        name="Client SAS",
        address="10 Avenue Foch",
        city='(name: "Lyon", post-code: "69001")',
        country="fr",
        vat="FR61954506077",
        legal='id.siren("954 506 077")',
        legal_fact=["0002", "954506077"],
        email="compta@client.example",
        iban="FR7630006000011234567890189",
    ),
    "at": dict(
        name="Kunde GmbH",
        address="Ringstraße 7",
        city='(name: "Graz", post-code: "8010")',
        country="at",
        vat="ATU87654324",
        legal='id.register("FN 654321 b", court: "Landesgericht für ZRS Graz")',
        legal_fact=["", "Landesgericht für ZRS Graz, FN 654321 b"],
        email="buchhaltung@kunde.example",
        iban="AT483200000012345864",
    ),
    "us": dict(
        name="Acme Inc.",
        address="350 Fifth Avenue",
        city='(name: "New York", post-code: "10118")',
        country="us",
        vat=None,
        legal='"EIN 12-3456789"',
        legal_fact=["", "EIN 12-3456789"],
        email="ap@acme.example",
        iban=None,
    ),
    "ch": dict(
        name="Kunde AG",
        address="Marktgasse 1",
        city='(name: "Bern", post-code: "3011")',
        country="ch",
        vat="CHE987654326",
        legal='id.uid-ch("CHE-987.654.326")',
        legal_fact=["0183", "CHE987654326"],
        email="kreditoren@kunde.example",
        iban="CH5604835012345678009",
    ),
}
# Number format of the printed amounts per locale: (decimal sign, group sign).
NUMBER_FORMAT = {"de-de": (",", "."), "de-at": (",", "."), "fr-fr": (",", "\u00a0"), "de-ch": (".", "'")}
GROUNDS = {
    "e1": "Steuerfrei nach § 4 Nr. 21 UStG",
    "e2": "Steuerfrei nach § 4 Nr. 14 UStG",
    "ae": "Steuerschuldnerschaft des Leistungsempfängers",
    "k": "Steuerfreie innergemeinschaftliche Lieferung",
    "g": "Steuerfreie Ausfuhrlieferung",
    "o": "Nicht im Inland steuerbare Leistung",
}
CATEGORY = {"ae": "AE", "k": "K", "g": "G", "o": "O"}
# The VATEX code of the exemption of the "e-code" items (BT-121), medical care
# (Art. 132(1)(c) of the VAT Directive, § 4 Nr. 14 UStG).
EXEMPTION_CODE = "VATEX-EU-132-1C"
# The German fiscal representative of the Swiss seller of route "ch-fr"
# (§ 22a UStG), which holds its VAT registration (BT-63).
TAX_REPRESENTATIVE = dict(
    name="Fiskalvertretung Muster GmbH",
    source='(name: "Fiskalvertretung Muster GmbH", address: "Steuerweg 3", '
    'city: (name: "Frankfurt am Main", post-code: "60311"), country: country.de, vat-id: "DE136695976")',
    vat="DE136695976",
    country="DE",
)
# The references of the "din-5008-refs" theme: everything the law requires
# on the printed invoice, i.e. the date of the supply (service-time) and the
# seller's tax number or VAT identifier.
REFERENCES = ("invoice-nr", "invoice-date", "service-time", "due-date", "seller-tax-nr", "seller-vat-id",
              "buyer-vat-id")
# Identifiers of the "id" and "gln" variants of the `ids` dimension.
SELLER_ID = "SUP-70025"
SELLER_GLN = "4000001123452"
BUYER_GLN = "4000001987658"
CONSTRUCTOR = {"ae": "reverse-charge", "k": "intra-community", "g": "export", "o": "outside-scope"}
PERIOD = ("20260801", "20260831")
ITEM_PERIOD = "(datetime(year: 2026, month: 8, day: 1), datetime(year: 2026, month: 8, day: 31))"
# Document type code (BT-3) of every value of the `doctype` dimension.
TYPE_CODE = {"invoice": "380", "credit-note": "381", "corrected": "384", "self-billed": "389"}
# The invoice a credit note or a corrected invoice refers to (BT-25, BT-26).
PRECEDING = ("RE-2026-0815", "datetime(year: 2026, month: 8, day: 3)", "20260803")
# A SEPA direct debit of the German seller (BT-89, BT-90) and a card (BT-87, BT-88).
MANDATE = "M-2026-017"
CREDITOR_ID = "DE98ZZZ09999999999"
CARD = ("1234", "Erika Kunde")
# A paid invoice: paid in cash on the invoice date (BT-81 = 10).
PAID = ('"cash"', "datetime(year: 2026, month: 9, day: 1)", "10")
# Invoice notes as (subject code, text) (BT-21, BT-22), a note (BT-127) and
# the country of origin (BT-159) of the last item.
NOTES = [("", "Lieferung frei Haus."), ("AAI", "Es gelten unsere Allgemeinen Geschäftsbedingungen.")]
ITEM_NOTE = "Seriennummer 4711-0815"
ITEM_ORIGIN = "IT"
# A factoring company the buyer pays (BG-10), with its own account.
PAYEE = dict(
    name="Factoring Bank AG",
    source='(name: "Factoring Bank AG", global-id: id.gln("4000001543212"), '
    'legal-id: id.register("HRB 12345", court: "Amtsgericht Frankfurt am Main"))',
    ids=[["0088", "4000001543212"]],
    legal_id=["", "Amtsgericht Frankfurt am Main, HRB 12345"],
    iban="DE02120300000000202051",
)


def parties(f):
    s, b = f["route"].split("-")
    return s, b


def resolved_profile(f):
    """The profile the XML must announce (BT-24).

    Explicit profiles are exact. `auto` is XRechnung for a buyer in Germany
    when the invoice satisfies it (here: it has payment instructions,
    BR-DE-1), otherwise EN 16931. The buyer of a self-billed invoice is its
    sender, and its seller, the recipient, has no contact (BG-6), which
    XRechnung requires: EN 16931.
    """
    if f["profile"] != "auto":
        return f["profile"]
    _, b = parties(f)
    if f["doctype"] == "self-billed":
        return "en16931"
    return "xrechnung" if b == "de" and f["payment"] != "nobank+days" else "en16931"


def allowed(f):
    """Legal constraints: only complete, legal real-world invoices.

    Works on partial feature dictionaries, so that it can prune value pairs:
    a rule only applies when all dimensions it reads are given.
    """
    g = f.get
    route, tax, prof, ids, pay = g("route"), g("tax"), g("profile"), g("ids"), g("payment")
    doc, extras, currency = g("doctype"), g("extras"), g("currency")
    s, b = route.split("-") if route else (None, None)
    if tax and route:
        # Reverse charge: cross-border within the EU or domestic (section 13b UStG).
        if tax == "ae" and route not in ("de-de", "de-fr", "de-at", "at-de"):
            return False
        # Intra-community supply: between two different EU member states (for
        # route "ch-fr", from Germany, where the fiscal representative holds
        # the seller's VAT registration).
        if tax == "k" and not (route == "ch-fr" or (s in EU and b in EU and s != b)):
            return False
        # The fiscal representative of route "ch-fr" supplies goods to France.
        if route == "ch-fr" and tax != "k":
            return False
        # Export and non-taxable supplies: to a buyer outside the EU.
        if tax in ("g", "o") and (b not in ("us", "ch") or s == "ch"):
            return False
        if tax == "smallbiz" and route not in ("de-de", "fr-fr", "ch-ch"):
            return False
        if tax in ("e2", "e-code", "s-z") and s != b:
            return False
    if ids and tax:
        # K, G and AE need the seller VAT ID; O (and the small business
        # scheme coded O) leaves out VAT IDs, so it needs `tax-nr` or `id`.
        if tax in ("k", "g", "ae") and ids == "taxnr":
            return False
        if tax in ("o", "smallbiz") and ids in ("vat", "gln"):
            return False
        # Parties identified by their legal registration identifiers have no
        # VAT IDs, which K and G need.
        if tax in ("k", "g") and ids == "legal":
            return False
    # The Swiss seller of route "ch-fr" states the legal registration
    # identifier and its fiscal representative, not a VAT ID or tax number of
    # its own; the buyer of the intra-community supply states its VAT ID.
    if route == "ch-fr" and ids and ids not in ("vat", "id", "gln"):
        return False
    # A reverse charge identifies the buyer by its legal registration
    # identifier instead of its VAT ID (BR-AE-02) only at home (e.g. section
    # 13b UStG); across borders the law requires the VAT ID (IP-VAT-226).
    if ids == "legal" and tax == "ae" and route and s != b:
        return False
    # MINIMUM identifies the seller by its VAT ID or its legal registration
    # identifier (BR-CO-26), not by a tax number or `id`.
    if prof == "minimum" and ids and (ids == "taxnr" or (tax in ("o", "smallbiz") and ids != "legal")):
        return False
    # XRechnung needs payment instructions (BR-DE-1); `auto` falls back.
    if prof == "xrechnung" and pay == "nobank+days":
        return False
    # The sender of a credit note or a self-billed invoice pays the amount:
    # by credit transfer to the recipient's account (which the US buyer has
    # none of), or paid already (e.g. in cash); no direct debit, card payment
    # or payee.
    if doc in ("credit-note", "self-billed"):
        if pay in ("direct-debit", "card") or extras == "payee":
            return False
        if b == "us" and pay and pay not in ("nobank+days", "paid"):
            return False
    # The own date of a credit note is not the date of the supply, so it
    # states one only with dates; an intra-community supply needs it
    # (BR-IC-11).
    if doc == "credit-note" and tax == "k" and g("delivery") in ("none", "addr"):
        return False
    # A self-billed invoice swaps the parties (the recipient is the seller):
    # at home, with VAT IDs, not in XRechnung (its seller contact and buyer
    # reference would change places too), goods delivered to the issuer.
    if doc == "self-billed":
        if route and route not in ("de-de", "fr-fr", "ch-ch"):
            return False
        if tax and tax not in ("s", "s2", "s-e", "s-z", "e2", "e-code"):
            return False
        if prof in ("xrechnung", "auto") or ids in ("taxnr", "legal") or g("delivery") == "addr":
            return False
    # A SEPA direct debit of the German seller, in euro, from an account in
    # the euro area (so not for the exports to the US and Switzerland).
    if pay == "direct-debit":
        if route and (s != "de" or b not in ("de", "fr", "at")):
            return False
        if currency == "usd" or tax in ("g", "o"):
            return False
    # The payee receives a credit transfer.
    if extras == "payee" and pay and pay not in ("bank+days", "bank+due", "bank+immediate"):
        return False
    # US dollars for exports and supplies outside the scope of VAT to the US
    # and Switzerland, which state no VAT amount (Art. 230 of the VAT
    # Directive would require it in the national currency as well).
    if currency == "usd":
        if (tax and tax not in ("g", "o")) or (route and route not in ("de-us", "de-ch")) or doc == "self-billed":
            return False
    if g("mods") == "free-ship" and tax in ("s2", "s-e", "s-z"):
        return False  # the shipping charge has a single VAT group to go to
    if g("mods") == "bundle2-pct" and g("lines") == 1:
        return False
    if g("amounts") == "credit-line" and g("lines") == 1:
        return False
    if g("delivery") == "dates-mixed" and g("lines") == 1:
        return False
    return True


def pairwise(seed, candidates=3000):
    """Greedy all-pairs: every allowed value pair of two dimensions appears."""
    rnd = random.Random(seed)
    names = list(DIMS)
    uncovered = set()
    for i, j in itertools.combinations(range(len(names)), 2):
        for vi in DIMS[names[i]]:
            for vj in DIMS[names[j]]:
                if allowed({names[i]: vi, names[j]: vj}):
                    uncovered.add((i, vi, j, vj))

    def pairs(f):
        return {(i, f[names[i]], j, f[names[j]]) for i, j in itertools.combinations(range(len(names)), 2)}

    pool = []
    while len(pool) < candidates:
        f = {n: rnd.choice(DIMS[n]) for n in names}
        if allowed(f):
            pool.append(f)
    rows, unreachable = [], set()
    while uncovered - unreachable:
        best = max(pool, key=lambda f: len(pairs(f) & uncovered))
        gain = pairs(best) & uncovered
        if not gain:
            i, vi, j, vj = min(uncovered - unreachable, key=repr)
            found = None
            for _ in range(20000):
                f = {n: rnd.choice(DIMS[n]) for n in names}
                f[names[i]], f[names[j]] = vi, vj
                if allowed(f):
                    found = f
                    break
            if not found:
                unreachable.add((i, vi, j, vj))
                continue
            best, gain = found, pairs(found) & uncovered
        rows.append(best)
        uncovered -= gain
    return rows, sorted((names[i], vi, names[j], vj) for i, vi, j, vj in unreachable)


def random_cases(seed, count, legal=True):
    rnd = random.Random(seed)
    rows = []
    while len(rows) < count:
        f = {n: rnd.choice(DIMS[n]) for n in DIMS}
        if not legal or allowed(f):
            rows.append(f)
    return rows


# ---------------------------------------------------------------- rendering

PRICES = {
    "plain": ["100.00", "39.90", "250.00", "12.50", "80.00", "5.00", "999.99", "45.00"],
    "fractional": ["12.3456", "0.9999", "7.125", "1.0001", "33.3333", "0.0125", "19.99", "2.4999"],
    "large": ["125000.00", "98765.43", "250000.00", "1.00", "77777.77", "10.00", "500000.00", "3.00"],
    "credit-line": ["100.00", "-40.00", "250.00", "12.50", "-5.00", "5.00", "999.99", "45.00"],
}
QUANTITIES = {
    "fractional": ["2", "0.5", "3", "1", "12", "1", "0.125", "4"],
    "default": ["1", "2", "1", "3", "1", "10", "1", "2"],
}


def _items(f, seller, opts):
    """Typst item lines and the facts about them."""
    n = f["lines"]
    std, red = seller["rates"]
    tax = f["tax"]
    prices = PRICES[f["amounts"]]
    quantities = QUANTITIES["fractional" if f["amounts"] == "fractional" else "default"]
    by_k, names_by_k, grounds, item_mods = {}, {}, [], []
    item_data = {"item_notes": [], "item_origins": []}
    for k in range(n):
        price = "0" if f["mods"] == "free-ship" else prices[k % 8]
        qty = quantities[k % 8]
        t = None
        if tax == "s2" and k % 2 == 1:
            t = f"tax.vat({red})"
        if tax == "s-e" and k == n - 1:
            t = f'tax.exempt(grounds: "{GROUNDS["e1"]}")'
            grounds.append(("E", GROUNDS["e1"]))
        if tax == "s-z" and k == n - 1:
            t = "tax.zero()"
        if tax == "e2":
            ground = GROUNDS["e1"] if k % 2 == 0 else GROUNDS["e2"]
            t = f'tax.exempt(grounds: "{ground}")'
            grounds.append(("E", ground))
        if tax == "e-code":
            t = f'tax.exempt(grounds: "{GROUNDS["e2"]}", code: "{EXEMPTION_CODE}")'
            grounds.append(("E", GROUNDS["e2"]))
        if tax in CATEGORY:
            t = f'tax.{CONSTRUCTOR[tax]}(grounds: "{GROUNDS[tax]}")'
            grounds.append((CATEGORY[tax], GROUNDS[tax]))
        if t is None and tax != "smallbiz":
            t = f"tax.vat({std})"
        name = opts.get("item_name", "Position {n}").format(n=k + 1)
        head = [opts.get("item_label", "[{name}]").format(name=name), f"price: {price}"]
        args = []
        if t:
            args.append(f"tax: {t}")
        if f["mods"] == "item-pct" and k == 0:
            args.append("modifier: discount([Mengenrabatt], amount: 10%)")
            item_mods.append({"name": "Mengenrabatt", "charge": False, "percent": "10"})
        if f["mods"] == "item-abs" and k == 0:
            args.append("modifier: surcharge([Expresszuschlag], amount: 25.00)")
            item_mods.append({"name": "Expresszuschlag", "charge": True, "amount": "25.00"})
        if f["delivery"] == "dates-all" or (f["delivery"] == "dates-mixed" and k == 0):
            args.append(f"date: {ITEM_PERIOD}")
        # The last item is never in the bundle, which takes the first two.
        if f.get("extras") == "item-data" and k == n - 1:
            args += [f'note: "{ITEM_NOTE}"', f"origin: country.{ITEM_ORIGIN.lower()}"]
            item_data["item_notes"].append([name, ITEM_NOTE])
            item_data["item_origins"].append([name, ITEM_ORIGIN])
        # `split`: the same item in two lines, quantity 1 and the rest.
        parts = ["1", str(int(qty) - 1)] if opts.get("split") and qty.isdigit() and int(qty) >= 2 else [qty]
        by_k[k] = ["  #item(" + ", ".join(head + [f"quantity: {part}"] + args) + ")" for part in parts]
        names_by_k[k] = [name] * len(parts)
    order = list(range(n))
    if opts.get("reverse"):
        order.reverse()
    lines = [line for k in order for line in by_k[k]]
    names = [name for k in order for name in names_by_k[k]]
    if f["mods"] == "bundle2-pct":
        inner = lines[:2]
        qty = opts.get("bundle_qty", 2)
        lines = (
            [f"  #bundle([Paket], quantity: {qty})["]
            + ["  " + line for line in inner]
            + ["    #discount([Paketrabatt], amount: 10%)", "  ]"]
            + lines[2:]
        )
        names = ["Paket"] + names[2:]
    doc_mods = {
        "doc-pct": [("  #discount([Treuerabatt], amount: 3%)", {"name": "Treuerabatt", "charge": False, "percent": "3"})],
        "doc-abs-disc": [("  #discount([Gutschein], amount: 20.00)", {"name": "Gutschein", "charge": False, "amount": "20.00"})],
        "doc-abs-sur": [("  #surcharge([Versand], amount: 5.90)", {"name": "Versand", "charge": True, "amount": "5.90"})],
        "free-ship": [("  #surcharge([Versand], amount: 5.90)", {"name": "Versand", "charge": True, "amount": "5.90"})],
    }.get(f["mods"], [])
    return lines + [src for src, _ in doc_mods], names, grounds, [fact for _, fact in doc_mods], item_mods, item_data


def _breakdown(f, seller, mutation):
    """The VAT breakdown (BG-23) as (category, rate) pairs, or None when it
    depends on the locale (small business scheme)."""
    if f["tax"] == "smallbiz" or mutation == "no-lines":
        return None
    std, red = (r.rstrip("%") for r in seller["rates"])
    several = f["lines"] > 1
    return {
        "s": [("S", std)],
        "s2": [("S", std), ("S", red)] if several else [("S", std)],
        "s-e": [("S", std), ("E", "0")] if several else [("E", "0")],
        "s-z": [("S", std), ("Z", "0")] if several else [("Z", "0")],
        "e2": [("E", "0")],
        "e-code": [("E", "0")],
        "ae": [("AE", "0")],
        "k": [("K", "0")],
        "g": [("G", "0")],
        "o": [("O", None)],
    }[f["tax"]]


def _due_date(f, mutation):
    """The payment due date (BT-9): 14 days after the invoice date, or the
    `due-date`; none when the amount is due at once or paid already."""
    if mutation == "no-payment-terms" or f["payment"] in ("bank+immediate", "card", "paid"):
        return None
    return "20260930" if f["payment"] == "bank+due" else "20260915"


def _account(f, seller, buyer):
    """(Typst source, IBAN) of the bank details of a credit transfer, or None.

    The account the amount is paid to: the seller's, a payee's own, and the
    recipient's on a credit note (the seller refunds the buyer) and on a
    self-billed invoice (the recipient is the seller).
    """
    if not f["payment"].startswith("bank+"):
        return None
    if f["extras"] == "payee":
        name = PAYEE["name"]
        return f'#bank-details(name: "{name}", bank: "{name}", iban: "{PAYEE["iban"]}")', PAYEE["iban"]
    if f["doctype"] in ("credit-note", "self-billed"):
        return f'#bank-details(bank: "Kundenbank", iban: "{buyer["iban"]}")', buyer["iban"]
    return f'#bank-details(bank: "Musterbank", iban: "{seller["iban"]}", bic: "{seller["bic"]}")', seller["iban"]


def _payment_facts(f, currency, account, buyer, mutation):
    """The facts of the payment means (BG-16) and of a paid invoice. The
    oracles check each one only in the profiles that state it."""
    pay = f["payment"]
    facts = {"payment_means": None, "account_name": None, "card": None, "mandate": None, "creditor_id": None,
             "debtor_iban": None, "paid": None}
    if account and mutation != "no-bank":
        # A credit transfer in euro is a SEPA credit transfer.
        facts["payment_means"] = ["58"] if currency == "EUR" else ["30"]
        if f["extras"] == "payee":
            facts["account_name"] = PAYEE["name"]
    if pay == "direct-debit":
        # A direct debit in euro is a SEPA direct debit.
        facts.update(payment_means=["59"] if currency == "EUR" else ["49"], mandate=MANDATE, creditor_id=CREDITOR_ID,
                     debtor_iban=buyer["iban"])
    if pay == "card":
        facts.update(payment_means=["54"], card=list(CARD))
    if pay == "paid":
        facts.update(payment_means=[PAID[2]], paid=True)
    return facts


def render(cid, f, mutation=None, opts=None):
    """Typst source and oracle facts of one case.

    `mutation` removes one required input (see MUTATIONS); `opts` holds the
    value variations of the metamorphic and adversarial cases.
    """
    opts = opts or {}
    s_code, b_code = parties(f)
    seller, buyer = dict(SELLER[s_code]), dict(BUYER[b_code])
    # The Swiss seller of route "ch-fr" invoices through its German VAT
    # registration: in euro, with its legal registration identifier and its
    # fiscal representative instead of a VAT ID (BT-31) of its own. (The
    # sender of a self-billed invoice, a random case only, is the buyer.)
    represented = f["route"] == "ch-fr" and f["doctype"] != "self-billed"
    if represented:
        seller.update(locale="de-de", currency="EUR")
    locale = opts.get("locale", seller["locale"])
    currency = "USD" if f["currency"] == "usd" else opts.get("currency", seller["currency"])
    ids, doc, extras = f["ids"], f["doctype"], f["extras"]
    # The sender of a self-billed invoice is the buyer and its recipient the
    # seller; `seller` and `buyer` stay the sender and the recipient here, and
    # the facts swap them at the end.
    self_billed = doc == "self-billed"
    seller_name = opts.get("seller_name", f'"{seller["name"]}"')
    sender = [
        f"name: {seller_name}",
        f'address: "{seller["address"]}"',
        f'city: {opts.get("seller_city", seller["city"])}',
        f'country: {opts.get("seller_country", "country." + seller["country"])}',
    ]
    if mutation != "no-seller-contact":
        sender.append(f"contact: {seller['contact']}")
    if ids in ("vat", "vat+taxnr", "id", "gln") and mutation != "no-seller-vat" and not represented:
        sender.append(f'vat-id: {opts.get("seller_vat", chr(34) + seller["vat"] + chr(34))}')
    if ids in ("taxnr", "vat+taxnr", "legal"):
        sender.append(f'tax-nr: "{seller["taxnr"]}"')
    if ids == "id":
        sender.append(f'id: "{SELLER_ID}"')
    if ids == "gln":
        sender.append(f'global-id: (scheme: "0088", id: "{SELLER_GLN}")')
    if ids == "legal" or represented:
        sender.append(f"legal-id: {seller['legal']}")
    if represented:
        sender.append(f"tax-representative: {TAX_REPRESENTATIVE['source']}")
    recipient = [
        f'address: "{buyer["address"]}"',
        f'city: {opts.get("buyer_city", buyer["city"])}',
        f'country: {opts.get("buyer_country", "country." + buyer["country"])}',
    ]
    if mutation != "no-buyer-name":
        recipient.insert(0, f'name: {opts.get("buyer_name", chr(34) + buyer["name"] + chr(34))}')
    if mutation != "no-buyer-email":
        recipient.append(f'email: "{buyer["email"]}"')
    # The buyer reference (BT-10) is the buyer's, which the recipient of a
    # self-billed invoice is not.
    if mutation != "no-buyer-reference" and not self_billed:
        recipient.append('buyer-reference: "04011000-12345-34"')
    if buyer["vat"] and mutation != "no-buyer-vat" and ids != "legal":
        recipient.append(f'vat-id: "{buyer["vat"]}"')
    if ids == "gln":
        recipient.append(f'global-id: (scheme: "0088", id: "{BUYER_GLN}")')
    if ids == "legal":
        recipient.append(f"legal-id: {buyer['legal']}")
    header = []
    if f["delivery"] == "addr":
        header.append(
            f'  delivery-address: (name: "Lager {buyer["name"]}", address: "Lagerweg 9", '
            f'city: {buyer["city"]}, country: country.{buyer["country"]}),'
        )
    if f["payment"] == "bank+due" and mutation != "no-payment-terms":
        header.append("  due-date: datetime(year: 2026, month: 9, day: 30),")
    if f["tax"] == "smallbiz":
        header.append("  tax-exempt-small-biz: true,")
    if doc != "invoice":
        header.append(f'  document-type: "{doc}",')
    if doc in ("credit-note", "corrected"):
        header.append(f'  preceding-invoice-nr: "{PRECEDING[0]}",')
        header.append(f"  preceding-invoice-date: {PRECEDING[1]},")
    if f["delivery"] == "period":
        header.append(f"  service-period: {ITEM_PERIOD},")
    if extras == "notes":
        notes = [f'(text: "{text}", subject-code: "{code}")' if code else f'"{text}"' for code, text in NOTES]
        header.append("  notes: (" + ", ".join(notes) + "),")
    if extras == "payee":
        header.append(f"  payee: {PAYEE['source']},")
    if f["currency"] == "usd":
        header.append('  currency: "USD",')
    # The DIN 5008 letter prints the references the case gives, or the
    # default ones of the theme.
    refs = opts.get("references", REFERENCES if f["theme"] == "din-5008-refs" else None)
    if refs is not None:
        header.append("  references: (" + ", ".join(f"references.{ref}()" for ref in refs) + "),")
    lines, names, grounds, doc_mods, item_mods, item_data = _items(f, seller, opts)
    if mutation == "e-no-grounds":
        lines = [line.replace(f'tax.exempt(grounds: "{GROUNDS["e1"]}")', "tax.exempt()") for line in lines]
        grounds = [g for g in grounds if g != ("E", GROUNDS["e1"])]
    if mutation == "no-lines":
        lines, names, grounds, doc_mods, item_mods = [], [], [], [], []
        item_data = {"item_notes": [], "item_origins": []}
    theme = "themes.DIN-5008()" if f["theme"].startswith("din-5008") else "themes.blank"
    profile = "auto" if f["profile"] == "auto" else f'"{f["profile"]}"'
    invoice_nr = opts.get("invoice_nr", f'"{cid}"')
    src = [
        '#import "/src/lib.typ": *',
        '#import "/tools/zugferd/harness.typ": harness',
        "",
        "#show: invoice.with(",
        f"  theme: harness({theme}),",
        f"  locale: locale.{locale},",
        f"  zugferd: {profile},",
        '  zugferd-errors: "report",',
        f'  tax-mode: "{f["mode"]}",',
        "  sender: (" + ", ".join(sender) + "),",
        "  recipient: (" + ", ".join(recipient) + "),",
        "" if mutation == "no-invoice-nr" else f"  invoice-nr: {invoice_nr},",
        "  date: datetime(year: 2026, month: 9, day: 1),",
        *header,
        ")",
        "",
        "#line-items[",
        *lines,
        "]",
    ]
    pay, terms = f["payment"], mutation != "no-payment-terms"
    if pay in ("bank+days", "nobank+days", "direct-debit") and terms:
        src.append("#payment-goal(days: 14)")
    if pay in ("bank+immediate", "card") and terms:
        src.append("#payment-goal()")
    if pay == "paid":
        src.append(f"#paid(method: {PAID[0]}, date: {PAID[1]})")
    account = _account(f, seller, buyer)
    if account and mutation != "no-bank":
        src.append(account[0])
    if pay == "direct-debit":
        src.append(f'#direct-debit(mandate: "{MANDATE}", creditor-id: "{CREDITOR_ID}", debtor-iban: "{buyer["iban"]}")')
    if pay == "card":
        src.append(f'#card-payment(last4: "{CARD[0]}", holder: "{CARD[1]}", kind: "credit")')
    period = list(PERIOD) if f["delivery"] in ("dates-all", "dates-mixed", "period") else None
    # The deliver-to country (BT-80): of the delivery address, which is the
    # recipient's warehouse, or of an intra-community supply to the buyer
    # (BR-IC-12), who is the sender of a self-billed invoice.
    ship_to = None
    if f["delivery"] == "addr":
        ship_to = buyer["country"].upper()
    elif f["tax"] == "k":
        ship_to = (seller if self_billed else buyer)["country"].upper()
    # Category O leaves out every VAT identifier (BR-O-02); so does the small
    # business scheme while it is coded O, so neither is checked there.
    without_vat_ids = f["tax"] in ("o", "smallbiz")
    profile = resolved_profile(f)
    facts = {
        "profile": profile,
        "invoice_nr": None if mutation == "no-invoice-nr" else opts.get("expect_invoice_nr", cid),
        "type_code": TYPE_CODE[doc],
        "currency": currency,
        "seller_name": opts.get("expect_seller_name", seller["name"]),
        "buyer_name": None if mutation == "no-buyer-name" else opts.get("expect_buyer_name", buyer["name"]),
        "seller_country": opts.get("expect_seller_country", seller["country"].upper()),
        # Every identifier reaches its business term (BT-29/30/31/32, BT-46/47/48).
        "seller_vat": seller["vat"]
        if ids in ("vat", "vat+taxnr", "id", "gln") and not without_vat_ids and mutation != "no-seller-vat"
        and not represented
        else None,
        "seller_tax_nr": seller["taxnr"] if ids in ("taxnr", "vat+taxnr", "legal") else None,
        "seller_ids": {"id": [["", SELLER_ID]], "gln": [["0088", SELLER_GLN]]}.get(ids),
        "seller_legal_id": seller["legal_fact"] if ids == "legal" or represented else None,
        # The seller tax representative (BG-11), from BASIC WL on.
        "tax_representative": {key: TAX_REPRESENTATIVE[key] for key in ("name", "vat", "country")}
        if represented and resolved_profile(f) != "minimum"
        else None,
        "buyer_vat": buyer["vat"]
        if buyer["vat"] and ids != "legal" and not without_vat_ids and mutation != "no-buyer-vat"
        else None,
        "buyer_ids": [["0088", BUYER_GLN]] if ids == "gln" else None,
        "buyer_legal_id": buyer["legal_fact"] if ids == "legal" else None,
        "buyer_country": opts.get("expect_buyer_country", buyer["country"].upper()),
        "ship_to_country": ship_to,
        "preceding_invoice": [PRECEDING[0], PRECEDING[2]] if doc in ("credit-note", "corrected") else None,
        "notes": [list(note) for note in NOTES] if extras == "notes" else None,
        "payee": {"name": PAYEE["name"], "ids": PAYEE["ids"], "legal_id": PAYEE["legal_id"]}
        if extras == "payee"
        else None,
        "line_names": names,
        "item_notes": item_data["item_notes"] if extras == "item-data" else None,
        "item_origins": item_data["item_origins"] if extras == "item-data" else None,
        "grounds": [] if f["tax"] == "smallbiz" else grounds,
        "doc_modifiers": doc_mods,
        "item_modifiers": item_mods,
        "period": period,
        "breakdown": _breakdown(f, seller, mutation),
        "due_date": _due_date(f, mutation),
        "iban": account[1] if account and mutation != "no-bank" else None,
        **_payment_facts(f, currency, account, buyer, mutation),
        "number_format": NUMBER_FORMAT[locale],
        "tax_mode": f["mode"],
        "skip_oracles": opts.get("skip_oracles", []),
    }
    for key in ("seller_vat", "seller_post_code", "seller_city", "buyer_post_code", "buyer_city_name"):
        if "expect_" + key in opts:
            facts[key] = opts["expect_" + key]
    if self_billed:
        # The XML states the recipient as seller (BG-4) and the sender as
        # buyer (BG-7). The buyer has no tax number in EN 16931.
        for key in ("name", "country", "vat", "ids", "legal_id"):
            facts["seller_" + key], facts["buyer_" + key] = facts["buyer_" + key], facts["seller_" + key]
        facts["seller_tax_nr"] = None
    return "\n".join(line for line in src if line != "") + "\n", facts


# ---------------------------------------------------------------- populations

# One required input removed -> invoice-pro reports the rule.
# (id, profiles it applies to, feature overrides, expected rules)
MUTATIONS = [
    ("no-invoice-nr", ["minimum", "basic-wl", "basic", "en16931", "xrechnung"], {}, ["BR-02"]),
    ("no-buyer-name", ["minimum", "basic-wl", "basic", "en16931", "xrechnung"], {}, ["BR-07"]),
    ("e-no-grounds", ["basic-wl", "basic", "en16931", "xrechnung"], {"tax": "s-e", "lines": 3}, ["BR-E-10"]),
    ("no-seller-vat", ["basic", "en16931", "xrechnung"], {"ids": "vat"}, ["BR-S-02"]),
    ("no-buyer-vat", ["basic", "en16931", "xrechnung"], {"tax": "ae", "route": "de-fr"}, ["BR-AE-02"]),
    ("no-buyer-vat", ["basic", "en16931"], {"tax": "k", "route": "de-at"}, ["BR-IC-02"]),
    ("no-lines", ["basic", "en16931", "xrechnung"], {}, ["BR-16"]),
    ("no-payment-terms", ["en16931", "xrechnung"], {"payment": "bank+days"}, ["BR-CO-25"]),
    ("no-buyer-reference", ["xrechnung"], {}, ["BR-DE-15"]),
    ("no-seller-contact", ["xrechnung"], {}, ["BR-DE-2"]),
    ("no-bank", ["xrechnung"], {"payment": "bank+days"}, ["BR-DE-1"]),
    ("no-buyer-email", ["xrechnung"], {"route": "de-us"}, ["PEPPOL-EN16931-R010"]),
]

# A detail the law requires on the printed invoice left out of the references
# of the DIN 5008 letter -> STRICTER, and invoice-pro names its own rule.
# (id, profiles, references, expected rules)
PRINTED = [
    ("refs-no-seller-tax-id", ["en16931", "xrechnung"],
     ("invoice-nr", "invoice-date", "service-time", "buyer-vat-id"), ["IP-PRINT-03"]),
    ("refs-no-date-of-supply", ["en16931", "xrechnung"],
     ("invoice-nr", "invoice-date", "seller-tax-nr", "seller-vat-id"), ["IP-PERIOD-03"]),
]

# Unusual but valid input forms: (id, feature overrides, opts). The expected
# values are part of the opts (`expect_*`), checked by the oracles.
ADVERSARIAL = [
    ("content-names", {}, {"seller_name": "[Muster *GmbH*]", "expect_seller_name": "Muster GmbH",
                           "item_label": "[_{name}_]"}),
    ("content-invoice-nr", {}, {"invoice_nr": "[RE-#(2026)-001]", "expect_invoice_nr": "RE-2026-001"}),
    ("hyphen-invoice-nr", {}, {"invoice_nr": "[RE-2026-001]", "expect_invoice_nr": "RE-2026-001"}),
    ("vat-with-spaces", {}, {"seller_vat": '"DE 123 456 788"', "expect_seller_vat": "DE123456788"}),
    ("vat-zero-width-space", {}, {"seller_vat": '"DE\\u{200B}123456788"', "expect_seller_vat": "DE123456788"}),
    ("vat-bom", {}, {"seller_vat": '"\\u{FEFF}DE123456788"', "expect_seller_vat": "DE123456788"}),
    # A post code must be a string (leading zeros): a clear input error.
    ("post-code-number", {}, {"seller_city": '(name: "Berlin", post-code: 10115)',
                              "expect": "INPUT_ERROR", "expect_error": "sender.city.post-code` must be a string"}),
    ("city-string", {}, {"seller_city": '"10115 Berlin"', "expect_seller_post_code": "10115",
                         "expect_seller_city": "Berlin"}),
    ("city-composed", {}, {"seller_city": '"60311 Frankfurt am Main"', "expect_seller_post_code": "60311",
                           "expect_seller_city": "Frankfurt am Main"}),
    ("country-string", {"route": "de-fr"}, {"buyer_country": '"FR"', "expect_buyer_country": "FR"}),
    ("country-lowercase", {"route": "de-fr"}, {"buyer_country": '"fr"', "expect_buyer_country": "FR"}),
    ("country-content", {"route": "de-at"}, {"buyer_country": "[AT]", "expect_buyer_country": "AT"}),
    ("buyer-name-xml-chars", {}, {"buyer_name": '"Kunde <&> \\"AG\\" \'s"',
                                  "expect_buyer_name": 'Kunde <&> "AG" \'s'}),
    ("long-item-name", {}, {"item_name": "Position {n}" + " lang" * 600}),
    ("item-name-math", {}, {"item_label": "[{name} $2 times 3$]", "item_name": "Fläche {n}",
                            "skip_oracles": ["O-BT153"]}),
    ("item-name-unicode", {}, {"item_name": "Größe {n} – Ærø “quoted” 😀"}),
]


def _case(cid, population, f, expect="AGREE_VALID", rules=(), mutation=None, opts=None, twin=None):
    opts = opts or {}
    src, facts = render(cid, f, mutation, opts)
    return {
        "id": cid,
        "population": population,
        "features": f,
        "mutation": mutation,
        "opts": opts,
        "expect": opts.get("expect", expect),
        "expect_rules": list(rules),
        "expect_error": opts.get("expect_error"),
        "twin": twin,
        "facts": facts,
        "source": src,
    }


def build(population="pr", seed=1, legal_extra=150, random_count=0):
    rows, unreachable = pairwise(seed)
    cases = []
    for k, f in enumerate(rows):
        cases.append(_case(f"pw{k:03d}", "legal", f))
    if population in ("pr", "nightly"):
        extra = random_cases(seed + 1, legal_extra if population == "pr" else legal_extra * 4)
        for k, f in enumerate(extra):
            cases.append(_case(f"rl{k:03d}", "legal", f))
        cases += metamorphic(rows)
        cases += mutations()
        cases += adversarial()
    if population == "nightly" or random_count:
        for k, f in enumerate(random_cases(seed + 2, random_count or 2000, legal=False)):
            cases.append(_case(f"ru{k:04d}", "random", f, expect="AGREE"))
    return cases, unreachable


def metamorphic(rows):
    cases = []
    bundles = [(k, f) for k, f in enumerate(rows) if f["mods"] == "bundle2-pct"]
    for k, f in bundles:
        cases.append(_case(f"mm-bundle1-{k:03d}", "metamorphic", f, opts={"bundle_qty": 1},
                           twin={"of": f"pw{k:03d}", "relation": "bundle-quantity"}))
    for k, f in enumerate(rows):
        # Reversing the lines would move other items into the bundle.
        if f["lines"] > 1 and k % 3 == 0 and f["mods"] != "bundle2-pct":
            cases.append(_case(f"mm-reverse-{k:03d}", "metamorphic", f, opts={"reverse": True},
                               twin={"of": f"pw{k:03d}", "relation": "same-totals"}))
        # Splitting an item into two lines leaves every total unchanged when
        # the line amounts are exact: net prices with two decimals, whole
        # quantities, no modifier of the item itself, no bundle.
        if (f["lines"] > 1 and f["mode"] == "exclusive" and f["amounts"] in ("plain", "large", "credit-line")
                and f["mods"] not in ("item-pct", "item-abs", "bundle2-pct")):
            cases.append(_case(f"mm-split-{k:03d}", "metamorphic", f, opts={"split": True},
                               twin={"of": f"pw{k:03d}", "relation": "same-totals"}))
        if k % 4 == 1:
            other = {"minimum": "basic-wl", "basic-wl": "basic", "basic": "en16931", "en16931": "basic",
                     "xrechnung": "en16931", "auto": "en16931"}[f["profile"]]
            g = dict(f, profile=other)
            if allowed(g):
                cases.append(_case(f"mm-profile-{k:03d}", "metamorphic", g,
                                   twin={"of": f"pw{k:03d}", "relation": "same-totals"}))
        s, _ = parties(f)
        # Another currency of the locale: not for an invoice in US dollars,
        # whose currency is set, nor for a SEPA direct debit, which is in euro.
        if (k % 4 == 2 and s == "de" and f["tax"] != "smallbiz" and f["currency"] == "default"
                and f["payment"] != "direct-debit"):
            cases.append(_case(f"mm-currency-{k:03d}", "metamorphic", f,
                               opts={"locale": "de-ch", "currency": "CHF"},
                               twin={"of": f"pw{k:03d}", "relation": "same-totals"}))
    return cases


def mutations():
    cases = []
    for name, profiles, overrides, rules in MUTATIONS:
        for prof in profiles:
            f = dict(SIMPLE, lines=3)
            f.update(overrides)
            f["profile"] = prof
            if prof == "xrechnung" and "route" not in overrides:
                f["route"] = "de-de"
            suffix = "-" + overrides["tax"] if "tax" in overrides and name == "no-buyer-vat" else ""
            cases.append(_case(f"mu-{name}{suffix}-{prof}", "mutation", f, "AGREE_INVALID", rules, name))
    for name, profiles, refs, rules in PRINTED:
        for prof in profiles:
            f = dict(SIMPLE, lines=3, theme="din-5008-refs", profile=prof)
            if prof == "xrechnung":
                f["route"] = "de-de"
            cases.append(_case(f"mu-{name}-{prof}", "mutation", f, "STRICTER", rules, opts={"references": refs}))
    return cases


def adversarial():
    cases = []
    for name, overrides, opts in ADVERSARIAL:
        f = dict(SIMPLE, lines=2)
        f.update(overrides)
        cases.append(_case(f"ad-{name}", "adversarial", f, opts=opts))
    return cases


def write(cases, out, meta):
    out = Path(out)
    common.require_under_root(out)
    # Old cases are removed, so only ever write over a generated corpus (for
    # example not over the committed regression cases).
    if any(out.glob("*.typ")) and not (out / "manifest.json").exists():
        raise common.ToolError(f"{out} holds .typ files but no manifest.json: it is not a generated corpus")
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.typ"):
        old.unlink()
    manifest = []
    for case in cases:
        (out / f"{case['id']}.typ").write_text(case["source"], encoding="utf-8")
        manifest.append({k: v for k, v in case.items() if k != "source"})
    (out / "manifest.json").write_text(
        json.dumps(dict(meta, cases=manifest), indent=1, ensure_ascii=False), encoding="utf-8"
    )


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=None, help="output directory (default: <build dir>/corpus)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--population", default="pr", choices=["legal", "pr", "nightly"],
                    help="legal: pairwise only; pr: the PR gate (default); nightly: pr + more random cases")
    ap.add_argument("--legal-extra", type=int, default=150, help="random legal cases on top of pairwise")
    ap.add_argument("--random", type=int, default=0, help="random cases without legal constraints")
    args = ap.parse_args(argv)
    out = Path(args.out) if args.out else common.build_dir() / "corpus"
    cases, unreachable = build(args.population, args.seed, args.legal_extra, args.random)
    meta = {"seed": args.seed, "population": args.population, "dims": DIMS, "unreachable_pairs": unreachable}
    try:
        write(cases, out, meta)
    except common.ToolError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    counts = {}
    for case in cases:
        counts[case["population"]] = counts.get(case["population"], 0) + 1
    print(f"{len(cases)} cases in {out}: {counts}; value pairs no legal invoice can have: {len(unreachable)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
