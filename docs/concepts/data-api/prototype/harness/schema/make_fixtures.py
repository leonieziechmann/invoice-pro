#!/usr/bin/env python3
"""Conformance fixtures (design D's make_fixtures.py, trimmed format): the
good example plus mutations, each tagged with what the contract promises:
  valid        - the JSON Schema and invoice-data.check accept it
  invalid      - both reject it (on the same branch)
  lenient      - the decoder reads it, the schema (writer's contract) does not
  decoder-only - schema-valid, but a rule only the decoder can check rejects it
                 (VAT scope of a modifier, nesting depth, amount range)
plus default model dumps (every unset optional field written as null).
usage: make_fixtures.py good.json schema.json out.json"""
import json, copy, sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fuzz"))
src, schema_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
good = json.load(open(src)); schema = json.load(open(schema_path))
cases = []
def case(name, expect, f):
    d = copy.deepcopy(good); f(d); cases.append({"name": name, "expect": expect, "doc": d})
def setp(path, v):
    def f(d):
        o = d
        for k in path[:-1]: o = o[k]
        o[path[-1]] = v
    return f
def delp(path):
    def f(d):
        o = d
        for k in path[:-1]: o = o[k]
        del o[path[-1]]
    return f
def nest(n):
    g = {"name": "Tief", "price": "1.00"}
    for i in range(n): g = {"kind": "group", "name": f"G{i}", "items": [g]}
    return g
case("good", "valid", lambda d: None)
case("minimal", "valid", lambda d: d.clear() or d.update({"format": "invoice-pro/1", "invoice-nr": "1", "date": "2026-01-01", "recipient": {"name": "X"}, "items": [{"name": "A", "price": "1"}]}))
case("minor-version", "valid", setp(["format"], "invoice-pro/1.0"))
case("nulls-for-optional", "valid", lambda d: d.update({"due-date": None, "subject": None, "payee": None}) or d["items"][0].update({"description": None}))
case("kind-null", "valid", setp(["items", 0, "kind"], None))
case("period-as-date", "valid", setp(["service-period"], "2026-10-31"))
case("tax-object", "valid", setp(["items", 0, "tax"], {"category": "E", "grounds": "§ 4 Nr. 14 UStG", "code": "VATEX-EU-132-1A"}))
case("unit-object", "valid", setp(["items", 0, "unit"], {"code": "KWH", "display": "kWh"}))
case("unit-other-code", "valid", setp(["items", 0, "unit"], "KWH"))
case("unit-display-only", "valid", setp(["items", 0, "unit"], {"display": "Fass"}))
case("identifier-gln", "valid", setp(["recipient", "global-id"], {"scheme": "gln", "id": "4000001000005"}))
case("city-string", "valid", setp(["recipient", "city"], "80331 München"))
case("lines-array", "valid", setp(["recipient", "name"], ["Bayerische Beispiel AG", "Einkauf"]))
case("direct-debit-only", "valid", setp(["payment"], {"direct-debit": {"mandate": "M-1", "debtor-iban": "DE02120300000000202051"}}))
case("card", "valid", setp(["payment"], {"card": {"last4": "0042", "kind": "credit"}}))
case("paid", "valid", setp(["payment"], {"paid": {"method": "transfer", "date": "2026-11-01"}}))
case("terms-text", "valid", setp(["payment", "terms"], {"text": "Zahlbar sofort ohne Abzug."}))
case("custom-open-item", "valid", setp(["items", 0, "custom", "other"], 1))
case("custom-null-inside", "valid", setp(["custom", "leer"], None))
case("negative-quantity", "valid", setp(["items", 0, "quantity"], "-1"))
case("leap-day", "valid", setp(["date"], "2028-02-29"))
case("smallbiz-false-and-tax", "valid", lambda d: d.update({"tax-exempt-small-biz": False, "tax": "19%"}))
case("price-as-number", "lenient", setp(["items", 0, "price"], 120.5))
case("quantity-as-int", "lenient", setp(["items", 0, "quantity"], 12))
case("missing-format", "invalid", delp(["format"]))
case("missing-invoice-nr", "invalid", delp(["invoice-nr"]))
case("empty-invoice-nr", "invalid", setp(["invoice-nr"], ""))
case("number-invoice-nr", "invalid", setp(["invoice-nr"], 42))
case("unknown-root-key", "invalid", setp(["invoice_nr"], "x"))
case("unknown-party-key", "invalid", setp(["recipient", "plz"], "80331"))
case("bad-date", "invalid", setp(["date"], "2026-02-30"))
case("bad-date-format", "invalid", setp(["date"], "02.11.2026"))
case("comma-decimal", "invalid", setp(["items", 0, "price"], "38,90"))
case("price-and-total", "invalid", setp(["items", 0, "total"], "1440.00"))
case("no-price", "invalid", delp(["items", 0, "price"]))
case("percent-without-sign", "invalid", setp(["items", 0, "tax"], "19"))
case("tax-preset-string", "invalid", setp(["items", 0, "tax"], "exempt"))
case("tax-bad-category", "invalid", setp(["items", 0, "tax"], {"category": "X"}))
case("bad-kind", "invalid", setp(["items", 1, "kind"], "grup"))
case("kind-number", "invalid", setp(["items", 1, "kind"], 3))
case("group-without-items", "invalid", delp(["items", 1, "items"]))
case("group-in-bundle", "invalid", lambda d: d["items"][2]["items"].append({"kind": "group", "name": "G", "items": [{"name": "a", "price": "1"}]}))
case("unit-name", "invalid", setp(["items", 0, "unit"], "hour"))
case("bad-unit", "invalid", setp(["items", 0, "unit"], "STUNDE"))
case("bad-currency", "invalid", setp(["currency"], "EURO"))
case("bad-country", "invalid", setp(["recipient", "country"], "Germany"))
case("period-end-missing", "invalid", setp(["service-period"], {"start": "2026-10-01"}))
case("period-array", "invalid", setp(["service-period"], ["2026-10-01", "2026-10-31"]))
case("bad-enum-tax-mode", "invalid", setp(["tax-mode"], "net"))
case("negative-discount", "invalid", setp(["modifiers", 0, "amount"], "-50.00"))
case("discount-over-100", "invalid", setp(["payment", "terms", "discount", 0, "percent"], "150%"))
case("paid-and-terms", "invalid", setp(["payment", "paid"], {"method": "card"}))
case("two-means", "invalid", setp(["payment", "card"], {"last4": "1234"}))
case("terms-days-and-text", "invalid", setp(["payment", "terms", "text"], "sofort"))
case("card-last4-number", "invalid", setp(["payment"], {"card": {"last4": 42}}))
case("zero-base-quantity", "decoder-only", setp(["items", 0, "base-quantity"], "0"))
case("days-negative", "invalid", setp(["payment", "terms", "days"], -1))
case("ref-too-long", "invalid", setp(["payment-reference"], "x" * 141))
case("bad-iban", "invalid", setp(["payment"], {"bank": {"iban": "12"}}))
case("wrong-major", "invalid", setp(["format"], "invoice-pro/2"))
case("smallbiz-and-tax", "invalid", lambda d: d.update({"tax-exempt-small-biz": True, "tax": "19%"}))
case("item-modifier-tax", "invalid", setp(["items", 1, "items", 1, "modifiers", 0, "tax"], "7%"))
case("null-in-array", "invalid", lambda d: d["items"].append(None))
case("leitweg-and-reference", "invalid", setp(["recipient", "leitweg-id"], "04011000-1234512345-06"))
case("custom-not-object", "invalid", setp(["custom"], "x"))
case("depth-9", "decoder-only", lambda d: d["items"].append(nest(9)))
case("modifier-without-items", "decoder-only", lambda d: d.update({"items": [], "modifiers": [{"kind": "discount", "name": "R", "amount": "10.00"}]}))
case("amount-out-of-range", "decoder-only", lambda d: d["items"][0].update({"quantity": "99999999999999999999", "price": "99999999999999999999"}))
case("decimal-29-digits", "decoder-only", setp(["items", 0, "price"], "99999999999999999999.999999999"))
# fixer round 1: rules added or made schema-expressible
case("self-billed-credit-note", "valid", setp(["document-type"], "self-billed-credit-note"))
case("doc-type-code-326", "valid", setp(["document-type"], "326"))
case("doc-type-code-999", "invalid", setp(["document-type"], "999"))
case("blank-name-lines", "invalid", setp(["recipient", "name"], ["", ""]))
case("empty-name-array", "invalid", setp(["recipient", "name"], []))
case("spaces-name", "invalid", setp(["recipient", "name"], "   "))
case("spaces-invoice-nr", "invalid", setp(["invoice-nr"], "   "))
case("empty-sender-name", "invalid", lambda d: d.update({"sender": {"name": ""}}))
case("tax-zero", "invalid", setp(["items", 0, "tax"], "0%"))
case("tax-zero-fraction", "invalid", setp(["items", 0, "tax"], "0.000%"))
case("tax-small-rate", "valid", setp(["items", 0, "tax"], {"category": "S", "rate": "0.5%"}))
case("tax-S-without-rate", "invalid", setp(["items", 0, "tax"], {"category": "S"}))
case("tax-S-rate-zero", "invalid", setp(["items", 0, "tax"], {"category": "S", "rate": "0%"}))
case("tax-Z-without-rate", "valid", setp(["items", 0, "tax"], {"category": "Z"}))
case("discount-zero", "invalid", setp(["payment", "terms", "discount", 0, "percent"], "0%"))
case("discount-100", "invalid", setp(["payment", "terms", "discount", 0, "percent"], "100%"))
case("discount-99.5", "valid", setp(["payment", "terms", "discount", 0, "percent"], "99.5%"))
case("discount-0.01", "valid", setp(["payment", "terms", "discount", 0, "percent"], "0.01%"))
case("terms-days-36500", "valid", setp(["payment", "terms", "days"], 36500))
case("terms-days-36501", "invalid", setp(["payment", "terms", "days"], 36501))
case("terms-days-float", "valid", setp(["payment", "terms", "days"], 14.0))
case("transfer-with-card", "invalid", setp(["payment"], {"method": "transfer", "card": {"last4": "4242"}}))
case("card-with-dd-method", "invalid", setp(["payment"], {"method": "direct-debit", "card": {"last4": "4242"}}))
case("card-with-card-method", "valid", setp(["payment"], {"method": "card", "card": {"last4": "4242"}}))
case("empty-bundle", "invalid", setp(["items", 2, "items"], []))
case("country-empty", "valid", setp(["recipient", "country"], ""))
case("currency-empty", "valid", setp(["currency"], ""))
case("extra-null-value", "valid", lambda d: d.update({"sender": {"name": "S", "extra": {"Web": "x.example", "Fax": None}}}))
case("payref-140-umlauts", "valid", setp(["payment-reference"], "ä" * 140))
case("payref-141-umlauts", "invalid", setp(["payment-reference"], "ä" * 141))
case("format-huge-major", "invalid", setp(["format"], "invoice-pro/99999999999999999999"))
case("format-huge-minor", "valid", setp(["format"], "invoice-pro/1.99999999999999999999"))
case("date-year-9899", "valid", setp(["date"], "9899-12-31"))
case("date-year-9999", "decoder-only", setp(["date"], "9999-12-31"))
case("text-10001", "decoder-only", setp(["items", 0, "name"], "x" * 10001))
case("depth-30", "decoder-only", lambda d: d["items"].append(nest(30)))
# fixer round 2
# "" = absent for an optional key of any type (spreadsheet cells): the schema
# allows it for texts only (a date, decimal or enum would lose its generated type)
case("blank-due-date", "lenient", setp(["due-date"], ""))
case("blank-tax-mode", "lenient", setp(["tax-mode"], ""))
case("blank-service-period", "lenient", setp(["service-period"], ""))
case("blank-item-tax-unit-quantity", "lenient", lambda d: d["items"][0].update({"tax": "", "unit": "", "quantity": "", "base-quantity": "", "date": ""}))
case("blank-kind", "lenient", setp(["items", 0, "kind"], ""))
case("blank-terms-date", "lenient", setp(["payment", "terms", "date"], ""))
case("blank-terms-text-with-days", "valid", setp(["payment", "terms", "text"], ""))
case("blank-subject", "valid", setp(["subject"], ""))
case("blank-date-required", "invalid", setp(["date"], ""))
# PDF metadata strings (title, author): at most 4000 characters
case("invoice-nr-4000-emoji", "valid", setp(["invoice-nr"], "\U0001F600" * 4000))
case("invoice-nr-4001", "invalid", setp(["invoice-nr"], "x" * 4001))
case("subject-4001", "invalid", setp(["subject"], "x" * 4001))
case("recipient-name-4001", "invalid", setp(["recipient", "name"], "x" * 4001))
case("sender-name-lines-total", "decoder-only", lambda d: d.update({"sender": {"name": ["x" * 3000, "y" * 1001]}}))
case("noncharacter-in-name", "decoder-only", setp(["recipient", "name"], "Beispiel\uFFFE AG"))
case("custom-text-10001", "decoder-only", setp(["custom", "tarif"], "x" * 10001))
case("custom-nested-noncharacter", "decoder-only", setp(["custom", "deep"], {"a": [{"b": "\U0010FFFF"}]}))
case("management-lines", "valid", lambda d: d.update({"sender": {"name": "S", "management": ["Dr. Erika Muster", "Max Beispiel"]}}))
case("discount-2-decimals", "valid", setp(["payment", "terms", "discount", 0, "percent"], "2.55%"))
case("discount-3-decimals", "invalid", setp(["payment", "terms", "discount", 0, "percent"], "2.555%"))
case("discount-0.001", "invalid", setp(["payment", "terms", "discount", 0, "percent"], "0.001%"))
# a cash discount period of at most 100 years, as payment days
case("discount-days-36500", "valid", setp(["payment", "terms", "discount", 0, "days"], 36500))
case("discount-days-36501", "invalid", setp(["payment", "terms", "discount", 0, "days"], 36501))
# Unicode White_Space (what the decoder trims), the same in every engine
case("invoice-nr-fs", "valid", setp(["invoice-nr"], "\u001c"))
case("invoice-nr-bom", "valid", setp(["invoice-nr"], "\ufeff"))
case("invoice-nr-nel", "invalid", setp(["invoice-nr"], "\u0085"))
case("invoice-nr-nbsp-ideographic", "invalid", setp(["invoice-nr"], "\u00a0\u3000"))
# default model dumps: what pydantic model_dump() / serde write for unset fields
from fuzz import nullfill  # noqa: E402  (fuzz.py's helper; guarded main below)
cases.append({"name": "dump-good", "expect": "valid", "doc": nullfill(schema, copy.deepcopy(good))})
cases.append({"name": "dump-minimal", "expect": "valid", "doc": nullfill(schema, {"format": "invoice-pro/1", "invoice-nr": "1", "date": "2026-01-01", "recipient": {"name": "X"}, "items": [{"name": "A", "price": "1"}, {"kind": "bundle", "name": "B", "items": [{"name": "c", "price": "2"}]}]})})
# a real pydantic dump, when the generated model is there (codegen.sh)
mp = os.path.join(os.path.dirname(os.path.abspath(out)), "model.py")
gen = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "model.py")
if os.path.exists(gen):
    import importlib.util
    spec = importlib.util.spec_from_file_location("ipmodel", gen); m = importlib.util.module_from_spec(spec); sys.modules["ipmodel"] = m; spec.loader.exec_module(m)
    root = getattr(m, "InvoicePro1InvoiceData")
    obj = root.model_validate(good)
    cases.append({"name": "pydantic-model-dump", "expect": "valid", "doc": obj.model_dump(mode="json", by_alias=True)})
json.dump(cases, open(out, "w"), ensure_ascii=False, indent=1)
print(len(cases), "fixtures:", {e: sum(1 for c in cases if c["expect"] == e) for e in ("valid", "invalid", "lenient", "decoder-only")})
