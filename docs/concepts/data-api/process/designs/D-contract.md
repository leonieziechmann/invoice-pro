# Design D — "Contract first": one descriptor, four artefacts (`invoice-data`)

Status: design proposal with a working prototype, for invoice-pro 0.6.0 → 0.7.0. The prototype is a copy of the repository at `<session>/exp/design-D-contract/repo` (the real repository is untouched). `<session>` = `<session>`. Every claim marked _verified_ was compiled on typst 0.15.1 **and** 0.14.2 by `<session>/exp/design-D-contract/verify.sh` (21/21 checks pass), `tools/regress.sh` (non-hydrated regression) or `tools/bench.py` (timings). Two files are adopted from design B's prototype and say so in their header: `src/contract/rows.typ` (the bulk line-items motif) and `src/components/payment.typ` (the payment block); everything about the contract (descriptor, decoder, exporter, result, CLI, extensions, conformance) is D's own.

---

## Executive summary

**The idea.** The data format is not described in prose and then implemented twice. It is ONE table of Typst dictionaries, `src/contract/schema.typ` (36 objects, 180 keys), each key with its type, EN 16931 business term, precedence role, default, example and one sentence of documentation. Four things are _interpreted_ from that table, never hand-written per key:

1. the **decoder/validator** in Typst (`contract/decode.typ`, generic over the table): JSON/TOML/YAML → Typst values, every problem a `data` issue at a JSON Pointer;
2. the **JSON Schema 2020-12** for editors and phase-2 code generators (`invoice-data.schema()`, dumpable without layout in ~160 ms);
3. the **reference documentation** (`invoice-data.reference()`, Markdown tables, 379 lines generated);
4. the **precedence** of hydration (which value wins, skeleton or data: the `role` of each key).

The same type vocabulary describes the **result contract** `invoice-pro-result/1`: a labelled metadata `<invoice-pro-result>` that every invoice publishes (totals, VAT breakdown, issues with JSON Pointers, e-invoice outcome and diagnostics), with its own JSON Schema. And a skeleton's **own fields** are declared with the same vocabulary (`fields.typ`), so they are decoded, validated, typed and exported into _that skeleton's_ JSON Schema.

**What a user writes.** One line in the skeleton binds it to the contract; nothing else in the design changes:

```typst
#let record = invoice-data.load(read: p => read(p, encoding: none), extensions: fields)
#show: invoice.with(..design, ..samples, data: record)
```

Plus `payment(..)` instead of `payment-terms`/`bank-details` if the data chooses the payment method. Without the line, `--input invoice-pro-data=<JSON>` still hydrates any skeleton (zero code); the line adds files, stdin and declared fields.

**What is proven** (prototype, both compilers):

- hydrated skeleton ≡ the same invoice hand-written with `item()` calls: **byte-identical PDF and XML** (demo invoice with group, bundle, item and document modifiers, prepayment, Skonto, custom field, Wappen; and 5/50/300-row benchmarks);
- **51/51 conformance fixtures**: python `jsonschema` on the exported schema and the Typst decoder agree (valid, invalid, and the documented leniencies), and the Typst reports are identical on 0.14.2 and 0.15.1;
- the exported schema generates models with **datamodel-codegen (pydantic v2), json-schema-to-typescript and typify (Rust)**; the codegen run caught a real contract defect (two spellings per unit) that was fixed in the table;
- non-hydrated invoices: **53/53 compilable integration tests byte-identical** to the original src although every invoice now emits `<invoice-pro-result>`;
- strict: any data problem → exit code 1, no PDF; draft: report page, XML withheld, `status: "draft"` in the result.

**Speed** (median of 5, round-robin, same PDF): hydrated vs hand-written

| rows |                 0.15.1 |                 0.14.2 |
| ---: | ---------------------: | ---------------------: |
|    5 |   512 → 458 ms (−11 %) |    506 → 468 ms (−8 %) |
|   50 | 1317 → 1121 ms (−15 %) | 1387 → 1131 ms (−18 %) |
|  300 | 6384 → 4417 ms (−31 %) | 6542 → 4495 ms (−31 %) |

**API change**: only extensions — 1 `invoice()` parameter (`data: auto`), 2 root exports (`invoice-data`, `payment`), 3 sys.inputs keys (`invoice-pro-data`, `invoice-pro-data-file`, `invoice-pro-result`), 1 label (`<invoice-pro-result>`), 1 reserved print-only party key (`custom`). No signature, default or output changes.

**What I need from you (maintainer)**

1. Accept the descriptor table as the normative definition of the format (and its generated JSON Schema committed under `src/contract/` with a CI drift check), §2, §13.
2. Accept that _every_ invoice publishes `<invoice-pro-result>` (zero output change, verified), §8.
3. Confirm the encodings that differ from the Typst API: money as decimal strings, units as UN/ECE codes only, `null` = absent, `due-date` always a date, §2.2.
4. Confirm the role of the borderline keys (document vs issuer: `subject`, `notes`, `document-type`, `currency`), §6.
5. Choose the canonical `$id` host for the schemas (prototype: `https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/…`), §2.8.

---

## Design decisions at a glance

| Decision               | Choice                                                                                                                                                   | Why                                                                                                                                            |
| :--------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------- |
| Source of truth        | one descriptor table in Typst (`contract/schema.typ`)                                                                                                    | Decoder, JSON Schema, docs and precedence cannot drift: they read the same table.                                                              |
| Type vocabulary        | 18 constructors (`text`, `decimal`, `percent`, `amount`, `date`, `period`, `enum`, `ref`, `array`, `map`, `union`, `tagged`, …) + `field()` + `object()` | Small enough to interpret three ways; also used for the result and for a skeleton's own fields.                                                |
| Entry point            | `invoice(data: auto)`; `auto` reads `--input invoice-pro-data`                                                                                           | Data issues must be raised inside invoice() (draft markers, strict, XML withholding); zero-code CLI hydration.                                 |
| Decoding API           | `invoice-data.decode/load` → a **sealed record** (metadata content)                                                                                      | Layout-free and callable anywhere (CI `check`, skeleton logic); cannot be confused with raw data; costs nothing in the loom context.           |
| Files                  | the skeleton's `read` callback: `load(read: p => read(p, encoding: none))`                                                                               | A package cannot open user paths (verified); the closure resolves against the skeleton. JSON, TOML, YAML by extension; stdin via `/dev/stdin`. |
| Precedence             | `role` per key: `document` (data only, sample dropped) / `issuer` (skeleton unless data gives it)                                                        | A sample can never leak into a real invoice; the JSON Schema marks the legally needed keys `required`.                                         |
| Binding points         | `bind` per section: items → `line-items` slot, `payment` → `payment(..)`, `custom` → `ctx.custom`                                                        | Explicit and checked: data that the skeleton has no binding point for is a `data` issue (coverage check).                                      |
| Line items             | ONE bulk motif inside `line-items` emits the item frames (adopted from B)                                                                                | Byte-identical output; the per-item loom cost disappears.                                                                                      |
| Custom fields          | open `custom` bag on document, parties and items; **declared** fields make a level closed and typed                                                      | Prior art (GOBL `meta`, Stripe `metadata`); declared fields give typo detection, typed values and a typed phase-2 model.                       |
| Data-dependent changes | Typst rules in the skeleton (theme `wrap`/part, `info.get`), plus a `derive` hook at eval time                                                           | Design stays Typst; `derive` changes _parameters_ (notes, tax), which a draw-time rule cannot.                                                 |
| Errors                 | data problem → issue `schema/<JSON Pointer>` (class `data`), value dropped; Typst misuse → panic; other major version → panic                            | Reuses the validation levels unchanged; ids are machine-readable paths into the data.                                                          |
| Format                 | JSON canonical (TOML/YAML read too), kebab-case Typst names, decimal strings, `"19%"`, ISO dates, UN/ECE unit codes, `null` = absent                     | 1:1 with the Typst API; exact money; generated models write `null` for unset fields.                                                           |
| Versioning             | `"format": "invoice-pro/1"` or `"invoice-pro/1.<minor>"`; SchemaVer rules; `$id` without package version                                                 | A newer minor is explained in unknown-key messages; another major panics with a clear message.                                                 |
| Result                 | `<invoice-pro-result>` on every invoice, format `invoice-pro-result/1`, own JSON Schema; opt-in PDF attachment; bundle sidecar                           | Phase 2 needs totals and status back; one compile on both compilers with the attachment.                                                       |
| Conformance            | differential fixtures (jsonschema vs decoder) + codegen in CI                                                                                            | "Valid for the schema" must mean "accepted by invoice-pro".                                                                                    |
| Speed                  | bulk motif, sealed record and descriptor, lazy imports                                                                                                   | Memoisation is the lever (loom research); decode ≈ 0.4 ms/row.                                                                                 |

---

## 1. Mental model

```text
 producer (ERP, script, phase-2 binding)            invoice-pro (Typst)
 ─────────────────────────────────────              ────────────────────────────────────────────────
 JSON / TOML / YAML  ── validates against ──►  invoice.schema.json   ◄── exported from ──┐
        │                                                                                    │
        │ --input invoice-pro-data=<JSON>            contract/schema.typ  (THE descriptor) ──┤──► reference.md
        │ --input invoice-pro-data-file=<path>               │                               │
        ▼                                                    ▼                               │
 skeleton.typ: invoice-data.load(read: ..) ──► decode.typ (generic interpreter) ──► record   │
                                                 (values + issues at JSON Pointers)  (sealed)│
                                                                    │                        │
 #show: invoice.with(..design, ..samples, data: record)             │                        │
        invoice():  roles → parameters (hydrate.typ)                │                        │
                    issues → validation (draft / strict / none)  ◄──┘                        │
                    body sections sealed in ctx.data, custom in ctx.custom                   │
        weave:      line-items slot (bulk rows) · payment(..) · theme parts read ctx.custom   │
        root draw:  <invoice-pro-result>  ── result.schema.json ◄─────────────────────────────┘
                          │
 typst query / eval ◄─────┘   (or: --input invoice-pro-result=attach → invoice-pro-result.json in the PDF)
```

Three contracts, one vocabulary: the **input** (`invoice-pro/1`), the **result** (`invoice-pro-result/1`) and the **CLI** (input keys, exit codes, files).

---

## 2. The data format `invoice-pro/1`

### 2.1 Principles

1. **Canonical subset of the Typst API.** Keys are the kebab-case names of `invoice()`, the party dictionaries and the components. Where the Typst API has aliases (`street`, `region`, flat `contact-name`/`phone`/`email`, unit names), the format keeps exactly one spelling. One encoding per concept is what makes code generation clean (the two-spelling unit enum crashed typify, §13).
2. **Closed core, named open bags.** Every object is closed (`additionalProperties: false`; the decoder reports unknown keys with did-you-mean). Openness lives only in `custom` (document, party, item), which the skeleton may close by declaring fields.
3. **Facts, not rules.** No expression language, no `eval`, no templates in data. Rules are Typst code in the skeleton.
4. **Exact values.** Money and quantities are decimal strings; dates are ISO strings; percentages carry `%`.
5. **Lenient reader, strict writer.** The JSON Schema is what producers must write. The decoder additionally reads three things, and only these (documented, tested as `lenient` fixtures): JSON `null` (= absent), JSON numbers for decimals (converted exactly via their shortest representation, never via `coercion.to-decimal`), and native TOML dates.

### 2.2 Encodings

| Kind              | JSON encoding                                                                                                                                                                                                | Typst value after decoding                                    | Notes                                                                                                                                                                                                            |
| :---------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| text              | `"2026-0042"`                                                                                                                                                                                                | `str`                                                         | A JSON number is rejected (`"42"` is the fix). A required text must not be empty; an optional `""` is absent.                                                                                                    |
| lines             | `"Muster GmbH"` or `["Muster GmbH", "Einkauf"]`                                                                                                                                                              | `str` / `array`                                               | names, addresses                                                                                                                                                                                                 |
| decimal           | `"120.00"`, `"-5"`, `"0.5"` (`^-?[0-9]{1,20}(\.[0-9]{1,10})?$`)                                                                                                                                              | `decimal` (scale kept)                                        | `"12,30"`, `"1e3"` rejected. Numbers tolerated (lenient).                                                                                                                                                        |
| percent           | `"19%"`, `"2.5%"`                                                                                                                                                                                            | `ratio`, `float(n)/100*100%`                                  | bit-identical with the literal (`infer-tax` and VAT group keys compare with `==`).                                                                                                                               |
| amount            | `"50.00"` (absolute) or `"10%"` (relative)                                                                                                                                                                   | `decimal` / `ratio`                                           | modifiers, prepayments; never negative (`kind` says discount/surcharge).                                                                                                                                         |
| date              | `"2026-11-02"`                                                                                                                                                                                               | `datetime`                                                    | calendar-checked (`"2026-02-30"` rejected); TOML dates native.                                                                                                                                                   |
| period            | a date, or `{"start": "…", "end": "…"}`                                                                                                                                                                      | `datetime` / `(datetime, datetime)`                           | end ≥ start.                                                                                                                                                                                                     |
| tax               | `"19%"` (category S at that rate) or `{"category": "E", "rate"?, "grounds"?, "code"?}`                                                                                                                       | a `tax.*` dictionary                                          | `"0%"` is rejected: a zero rate needs its category (mirrors the region's `infer-tax` panic, but as an issue). Categories: the 22 UNTDID 5305 codes; S/Z/E/AE/K/G/O use the named constructors (default grounds). |
| unit              | UN/ECE Rec 20 code `"HUR"`, `"DAY"`, `"MON"`, `"ANN"`, `"H87"`, `"SET"`, `"PR"`, `"LS"`, `"KGM"`, `"GRM"`, `"TNE"`, `"MTR"`, `"MTK"`, `"MMT"`, `"CMT"`, `"KMT"`, `"LTR"`, `"MTQ"`, or `{"code"?, "display"}` | `unit.*` function (localized, pluralized) / `(code, display)` | codes only (one spelling).                                                                                                                                                                                       |
| identifier        | `"DE123"` or `{"scheme": "gln"\|"duns"\|"siren"\|"siret"\|"uid-ch"\|"leitweg"\|"register"\|"EM"\|"<ICD>", "id": "…", "court"?}`                                                                              | `id.*` result (check digits verified) or `(scheme, id)`       | named schemes go through the `id.*` constructors, so check-digit problems reach the e-invoice report (IP-ID-01).                                                                                                 |
| city              | `"10115 Berlin"` or `{"name", "post-code"?, "state"?}`                                                                                                                                                       | as Typst                                                      | structured city gives the post code without parsing (good for Wappen rules).                                                                                                                                     |
| country, currency | `"DE"`, `"EUR"`                                                                                                                                                                                              | `str`                                                         | ISO 3166-1 alpha-2 / ISO 4217.                                                                                                                                                                                   |
| enum              | `"exclusive"`                                                                                                                                                                                                | `str`                                                         | did-you-mean on a typo.                                                                                                                                                                                          |
| null              | `null`                                                                                                                                                                                                       | absent                                                        | what generated models write for unset fields; to clear an issuer list give `[]`.                                                                                                                                 |

`due-date` is always a date (BT-9). Payment-terms _text_ (BT-20) comes from `payment.terms` (days, date, Skonto), never from a string that happens to look like a date — the trap of the Typst API (`due-date: "2026-02-01"` = terms text) cannot occur.

### 2.3 Document (`invoice`) — every key

`R` = required by the schema. Role: `doc` = from the data only (the skeleton's value is a sample and is dropped when hydrated); `iss` = the skeleton's value stays unless the data gives the key; `→` = binding point.

| Key                      | Type                                                                                                                 |  R  | Role         | EN 16931      | Meaning                            |
| :----------------------- | :------------------------------------------------------------------------------------------------------------------- | :-: | :----------- | :------------ | :--------------------------------- |
| `$schema`                | text                                                                                                                 |     |              |               | editor hint, not read              |
| `format`                 | `invoice-pro/1[.minor]`                                                                                              |  R  |              |               | format and version                 |
| `invoice-nr`             | text                                                                                                                 |  R  | doc          | BT-1          | invoice number                     |
| `date`                   | date                                                                                                                 |  R  | doc          | BT-2          | issue date                         |
| `document-type`          | `invoice`, `credit-note`, `corrected`, `prepayment`, `self-billed`, `self-billed-credit-note`, or a UNTDID 1001 code |     | doc          | BT-3          | absent = 380                       |
| `currency`               | ISO 4217                                                                                                             |     | iss          | BT-5          |                                    |
| `due-date`               | date                                                                                                                 |     | doc          | BT-9          |                                    |
| `service-period`         | period                                                                                                               |     | doc          | BT-72 / BG-14 |                                    |
| `subject`                | text                                                                                                                 |     | iss          |               |                                    |
| `notes`                  | text \| (text \| {text, subject-code})[]                                                                             |     | iss          | BG-1          |                                    |
| `customer-nr`            | text                                                                                                                 |     | doc          |               | printed                            |
| `order-nr`               | text                                                                                                                 |     | doc          | BT-13         |                                    |
| `order-date`             | date                                                                                                                 |     | doc          |               | printed (as a localized date)      |
| `project`                | text                                                                                                                 |     | doc          | BT-11         |                                    |
| `contract-nr`            | text                                                                                                                 |     | doc          | BT-12         |                                    |
| `quote-nr`               | text                                                                                                                 |     | doc          |               | printed                            |
| `delivery-note-nr`       | text                                                                                                                 |     | doc          | BT-16         |                                    |
| `preceding-invoice-nr`   | text                                                                                                                 |     | doc          | BT-25         |                                    |
| `preceding-invoice-date` | date                                                                                                                 |     | doc          | BT-26         |                                    |
| `payment-reference`      | text (≤ 140)                                                                                                         |     | doc          | BT-83         | absent = invoice number            |
| `sender`                 | seller                                                                                                               |     | iss          | BG-4          | replaces the letterhead as a whole |
| `recipient`              | buyer                                                                                                                |  R  | doc          | BG-7          |                                    |
| `delivery-address`       | ship-to                                                                                                              |     | doc          | BG-13/15      |                                    |
| `payee`                  | payee                                                                                                                |     | iss          | BG-10         |                                    |
| `tax`                    | tax                                                                                                                  |     | iss          | BG-23         | default tax of the lines           |
| `tax-mode`               | `exclusive` \| `inclusive`                                                                                           |     | iss          |               |                                    |
| `tax-exempt-small-biz`   | bool                                                                                                                 |     | iss          |               | § 19 UStG etc.                     |
| `items`                  | (item \| group \| bundle)[]                                                                                          |  R  | → line-items | BG-25         | print order                        |
| `modifiers`              | modifier[]                                                                                                           |     | → line-items | BG-20/21      | document discounts/surcharges      |
| `prepayments`            | prepayment[]                                                                                                         |     | → line-items | BT-113        |                                    |
| `payment`                | payment                                                                                                              |     | → payment    | BG-16         |                                    |
| `custom`                 | custom                                                                                                               |     | → ctx.custom |               | your fields                        |

Not in the format (design/config, stays Typst): `theme`, `locale`, `references` (layout of the header; the values come from the data keys above), `zugferd`, `zugferd-errors`, `validation`, component layout options (`show-reference`, `qr-code`, `show-column`, …).

### 2.4 Parties

- **seller** (`sender`): `name` R (BT-27), `address` (BT-35), `city` (BT-37/38), `country` (BT-40), `trading-name` (BT-28), `vat-id` (BT-31), `tax-nr` (BT-32), `id` / `global-id` (BT-29), `legal-id` (BT-30), `legal-info` (BT-33), `electronic-address` (BT-34), `contact` {name, phone, email} (BG-6), `tax-representative` {name R, address, city, country, vat-id R} (BG-11), `register`, `management` (printed only), `extra` {label: text} (printed only), `custom`.
- **buyer** (`recipient`): `name` R (BT-44), `address`, `city`, `country` (BT-55), `trading-name` (BT-45), `vat-id` (BT-48), `tax-nr` (printed), `id` / `global-id` (BT-46), `legal-id` (BT-47), `electronic-address` (BT-49), `contact` (BG-9), `buyer-reference` (BT-10) **or** `leitweg-id` (BT-10, check digits verified; the schema forbids both), `extra`, `custom`.
- **ship-to** (`delivery-address`): `name` R (BT-70), `address`, `city`, `country` (BT-80), `id` / `global-id` (BT-71), `extra`, `custom`.
- **payee**: `name` R (BT-59), `id` / `global-id` (BT-60), `legal-id` (BT-61).

`custom` is a reserved **print-only** party key (one line added to `zugferd/model.typ` `party-keys`), so it reaches `ctx.sender.custom` / `view.recipient.custom` for theme parts without IP-KEY-01 warnings (verified: the demo's `recipient.custom.segment` gives 0 e-invoice warnings). An unknown party key goes through the e-invoice alias table (`zugferd/keys.typ`): `plz` → "Did you mean `city`? Write the post code into `city` …".

### 2.5 Line items

`items` is a list of rows with a `kind` discriminator (`item` default, `group`, `bundle`), mirroring the body of `line-items`:

- **item**: `name` R (BT-153), `description` (BT-154), `quantity` (BT-129), `base-quantity` (> 0, BT-149), `unit` (BT-130), exactly one of `price` (BT-146) / `total` (BT-131), `date` (period, BG-26), `tax` (BG-30), `input-gross`, `item-id` (text = seller's, or {seller BT-155, buyer BT-156, standard BT-157}), `reference` (BT-133), `note` (BT-127), `origin` (BT-159), `modifiers` (item discounts/surcharges, BG-27/28), `custom` (→ `view.items[i].custom` for theme parts).
- **group**: `kind: "group"` R, `name` R, `description`, `show-subtotal`, cascades `tax`, `input-gross`, `date`, `unit`; `items` R.
- **bundle**: `kind: "bundle"` R, `name` R, `description`, `quantity`, `base-quantity`, `unit`, `date`, `tax`, `input-gross`, `item-id`, `reference`, `items` R, `modifiers`.
- **modifier** (document, bundle or item level): `kind` (`discount` \| `surcharge`) R, `name` R (BT-97/104), `amount` R (BT-92/99), `label`, `description`, `tax` (pin to one rate), `input-gross`.
- **prepayment**: `amount` R (BT-113), `name`, `label`, `date`, `reference`, `description`, `method`.

A row that lacks what it needs (no price, an invalid required value, both price and total) is dropped as a whole and reported; a valid row never depends on an invalid sibling.

### 2.6 Payment

```json
"payment": {
  "terms":        { "days": 14, "date": "2026-11-16", "discount": [ { "days": 7, "percent": "2%", "basis": "100.00" } ] },
  "method":       "transfer" | "direct-debit" | "card" | "paid",
  "bank":         { "iban": "DE75…", "bic": "SOLADEST600", "bank": "Musterbank", "name": "Muster GmbH" },
  "creditor-id":  "DE98ZZZ09999999999",
  "direct-debit": { "mandate": "MD-17", "debtor-iban": "DE02…" },
  "card":         { "last4": "0042", "holder": "…", "kind": "credit" | "debit" },
  "paid":         { "method": "cash" | "cheque" | "online" | "transfer" | "card" | "direct-debit", "date": "2026-11-01" }
}
```

Roles inside the section: `terms`, `method`, `bank`, `creditor-id` are issuer settings (the skeleton's `payment(..)` arguments stay unless given); `direct-debit`, `card`, `paid` describe one invoice (data only). Rules in the schema and the decoder: at most one of `direct-debit` / `card` / `paid`; never `paid` with `terms`; `days` xor `date`. Details without `method` select that method.

### 2.7 Custom fields

| Level    | Where in the data                                              | Where the skeleton reads it                                                                            | Default  |
| :------- | :------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------- | :------- |
| document | `custom`                                                       | theme parts `ctx.custom`, body `info.get("custom", "key")`, Typst `invoice-data.values(record).custom` | open bag |
| party    | `sender.custom`, `recipient.custom`, `delivery-address.custom` | `ctx.recipient.custom`, `view.recipient.custom`                                                        | open bag |
| item     | `items[].custom`                                               | `view.items[i].custom` in table parts/hooks                                                            | open bag |

Declaring fields (§9) makes a level closed and typed. Document custom travels **sealed** in ctx (any size is free, §11); party custom is unsealed and should stay small (documented limit).

### 2.8 Versioning

- `"format": "invoice-pro/1"` (required) means minor 0; `"invoice-pro/1.3"` states the minor the data needs.
- SchemaVer-style: an optional key = new **minor**; a rename, removal or change of meaning = new **major**. Closed objects keep additions additive (prior art).
- Data with a newer minor: an unknown key's message says "The data is written for invoice-pro/1.2; this invoice-pro reads invoice-pro/1.0: update invoice-pro, or leave the key out" (verified).
- Another major: `invoice()` panics ("invoice data is in format "invoice-pro/2"; this invoice-pro reads invoice-pro/1 only …", verified) — no level can honour data it cannot read. `invoice-data.check` reports it as `schema/format` instead.
- Every field records `since` (`x-invoice-pro-since` in the JSON Schema). The `$id` carries the format major only (`…/schema/invoice-pro/1/invoice.schema.json`), not the package version, so `scripts/check-version` is unaffected.

### 2.9 Absent, null, empty

Absent ≡ `null` ≡ "not given" (generated models write `null`). For an optional text `""` is absent too. For an issuer key, "not given" keeps the skeleton's value; to clear a list (e.g. the skeleton's `notes`), give `[]`. For a document key, "not given" is the parameter's default (the sample is dropped).

---

## 3. Example data (complete; `repo/demo/data/2026-0042.json`, compiled)

```json
{
  "$schema": "https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/invoice.schema.json",
  "format": "invoice-pro/1",
  "invoice-nr": "2026-0042",
  "date": "2026-11-02",
  "service-period": { "start": "2026-10-01", "end": "2026-10-31" },
  "order-nr": "PO-7781",
  "customer-nr": "K-1007",
  "project": "Relaunch Webshop",
  "notes": [
    "Vielen Dank für Ihren Auftrag.",
    { "text": "Lieferung frei Haus.", "subject-code": "AAI" }
  ],
  "recipient": {
    "name": "Bayerische Beispiel AG",
    "address": "Marienplatz 8",
    "city": { "name": "München", "post-code": "80331" },
    "country": "DE",
    "vat-id": "DE987654321",
    "buyer-reference": "04011000-1234512345-06",
    "electronic-address": "einkauf@beispiel-ag.example",
    "contact": {
      "name": "Max Einkauf",
      "email": "einkauf@beispiel-ag.example"
    },
    "custom": { "segment": "enterprise" }
  },
  "items": [
    {
      "name": "Beratung Konzeption",
      "description": "Workshops und Konzept, Oktober 2026",
      "quantity": "12",
      "unit": "HUR",
      "price": "120.00",
      "tax": "19%",
      "item-id": { "seller": "SRV-CONS" },
      "custom": { "cost-center": "CC-4711" }
    },
    {
      "kind": "group",
      "name": "Literatur",
      "tax": "7%",
      "items": [
        { "name": "Fachbuch Typst", "quantity": "3", "price": "39.90" },
        {
          "name": "Fachbuch E-Rechnung",
          "price": "49.90",
          "modifiers": [
            { "kind": "discount", "name": "Mengenrabatt", "amount": "10%" }
          ]
        }
      ]
    },
    {
      "kind": "bundle",
      "name": "Starterpaket",
      "quantity": "2",
      "unit": "SET",
      "items": [
        { "name": "Lizenz", "price": "200.00", "tax": "19%" },
        { "name": "Handbuch", "price": "25.00", "tax": "7%" }
      ]
    },
    {
      "name": "Hosting",
      "quantity": "1",
      "unit": "MON",
      "price": "29.00",
      "tax": "19%",
      "date": { "start": "2026-10-01", "end": "2026-10-31" }
    }
  ],
  "modifiers": [
    { "kind": "discount", "name": "Treuerabatt", "amount": "50.00" }
  ],
  "prepayments": [
    {
      "amount": "500.00",
      "name": "Anzahlung",
      "date": "2026-10-05",
      "reference": "AZ-2026-0042"
    }
  ],
  "payment": {
    "terms": { "days": 14, "discount": [{ "days": 7, "percent": "2%" }] }
  },
  "custom": { "tarif": "Gold", "campaign-end": "2026-12-31" }
}
```

The Wappen rule uses the recipient's structured post code `80331` (→ München arms); a data file may override it with the declared field `custom.wappen` (`"hamburg"` in `2026-0043.json`). Result of this file (verified, equal on both compilers): net 2033.61, VAT 361.25, gross 2394.86, prepaid 500.00, due 1894.86, due date 2026-11-16, EN 16931 XML attached.

---

## 4. The skeleton (compiled; `repo/demo/skeleton.typ` + `fields.typ`)

```typst
#import "@preview/invoice-pro:0.7.0": *
#import "fields.typ": fields

// ONE line binds the skeleton to the data contract: inline JSON or a file
// (read here, so the path resolves against this project), decoded with the
// skeleton's declared fields. `none` without input: the samples render.
#let record = invoice-data.load(
  read: p => read(p, encoding: none),
  extensions: fields,
)

// Data-dependent design stays Typst. The coat of arms: a declared custom
// field wins, else the recipient's post code (parsed from `city`) decides.
#let arms = (
  muenchen: "wappen/muenchen.svg",
  berlin: "wappen/berlin.svg",
  hamburg: "wappen/hamburg.svg",
)
#let arms-by-plz = ("8": "muenchen", "1": "berlin", "2": "hamburg")
#let wappen(ctx, view, inner) = {
  let key = ctx.at("custom", default: (:)).at("wappen", default: auto)
  if key == auto {
    let plz = view.recipient.at("post-code", default: none)
    key = if plz != none { arms-by-plz.at(plz.first(), default: none) }
  }
  let path = if type(key) == str { arms.at(key, default: none) }
  if path == none { return inner(ctx, view) }
  let ctx = ctx
  ctx.theme.options.logo.image = image(path, alt: "Wappen")
  inner(ctx, view)
}

#show: invoice.with(
  // design: never data
  theme: theme.classic.with(theme.custom.wrap("logo", wappen)),
  locale: locale.de-de,
  zugferd: "en16931",
  // issuer settings: they stay unless the data gives them
  sender: (
    name: "Muster Consulting GmbH",
    address: "Hauptstraße 1",
    city: "10115 Berlin",
    country: "DE",
    vat-id: "DE123456789",
    contact: (name: "Erika Muster", phone: "+49 30 1234567", email: "rechnung@muster.example"),
  ),
  // samples: what identifies one invoice comes from the data only
  recipient: (name: "Beispielkunde AG", address: "Musterweg 2", city: "80331 München"),
  invoice-nr: "MUSTER-0001",
  data: record,
)

// a custom field in the body (draw-time binding)
Tarif: #info.get("custom", "tarif", default: "Standard")

#line-items[
  #item("Beispielleistung", quantity: 2, unit: unit.hour, price: 100)
]

#payment(
  terms: (days: 14),
  bank: (name: "Muster Consulting GmbH", bank: "Musterbank", iban: "DE75512108001245126199", bic: "SOLADEST600"),
  creditor-id: "DE98ZZZ09999999999",
)

#signature()
```

`fields.typ` — the skeleton's own fields, declared once; the skeleton decodes with them and the schema export includes them:

```typst
#import "@preview/invoice-pro:0.7.0": invoice-data

#let fields = (
  invoice: (
    wappen: invoice-data.field(
      invoice-data.enum("muenchen", "berlin", "hamburg", "none"),
      doc: "Coat of arms in the letterhead; absent = chosen by the recipient's post code.",
    ),
    tarif: invoice-data.field(invoice-data.text(), doc: "Customer tariff printed under the subject.", example: "Gold"),
    campaign-end: invoice-data.field(invoice-data.date(), doc: "End of the discount campaign (decoded to a datetime)."),
  ),
  item: (
    cost-center: invoice-data.field(
      invoice-data.text(pattern: "^CC-[0-9]+$", pattern-doc: "CC-<digits>"),
      doc: "Cost center of the line.",
    ),
  ),
)
```

Compiled alone (no input), the skeleton renders its samples (a complete preview, e-invoice included). Hydrated, the samples of `document` keys and of the `line-items` body disappear; the letterhead (`sender`), payment terms and bank stay unless the data overrides them.

---

## 5. API surface (all new; nothing existing changes)

### 5.1 `invoice(.., data: auto)` — one new parameter

```text
data: auto | none | dictionary | bytes | str | content(record) | path (0.15)
  auto        → the JSON of --input invoice-pro-data if given, else not hydrated
  none        → not hydrated (also ignores --input)
  dictionary  → raw data (json(..)/toml(..)/yaml(..)), decoded with the core schema
  bytes, str  → JSON text
  record      → the result of invoice-data.decode/load (with the skeleton's fields)
  path        → Typst 0.15 path made in the user's file (json(path))
```

Inside `invoice()` (lazy import, only when hydrated): decode → apply roles to the 25 data parameters → append the data issues next to `check-data` (invoice.typ:547) → seal the body sections (`ctx.data`) and the custom fields (`ctx.custom`) into the loom inputs (only when given).

### 5.2 Root export `invoice-data` (namespace; `src/public/invoice-data.typ`)

```text
invoice-data.format          = "invoice-pro/1"
invoice-data.result-format   = "invoice-pro-result/1"
invoice-data.input-key       = "invoice-pro-data"
invoice-data.file-key        = "invoice-pro-data-file"

invoice-data.load(read: none, inputs: sys.inputs, extensions: none, derive: none) -> none | record
    The record of the CLI's data: --input invoice-pro-data (JSON text, or a dictionary from an
    embedder) or --input invoice-pro-data-file read by `read` (JSON/TOML/YAML by extension, BOM
    tolerated). `inputs` is injectable for tests (house convention).
invoice-data.decode(raw, extensions: none, derive: none) -> record
    Decodes and validates without rendering. record.value = (kind, format, values, issues, fatal).
invoice-data.values(record) -> none | dictionary          the decoded, typed values
invoice-data.check(raw, extensions: none) -> (format: "invoice-pro-check/1", valid: bool,
                                               issues: ((id, path, key, message, fix), ..))
    JSON-friendly validation report, layout-free (typst eval / query stub).
invoice-data.schema(extensions: none) -> dictionary       JSON Schema 2020-12 of the input
invoice-data.result-schema() -> dictionary                 JSON Schema 2020-12 of the result
invoice-data.reference(extensions: none) -> str            Markdown reference tables
invoice-data.batch(records, render, name: rec => <invoice-nr> + ".pdf", results: "results.json")
    Several invoices in one compile: 0.15 bundle → one PDF each + results.json; else page breaks.

types for declared fields (same vocabulary as the format):
invoice-data.text(max:, pattern:, pattern-doc:, example:)   .lines()   .decimal(min:, positive:)
invoice-data.percent(min:, max:)   .amount()   .integer(min:, max:)   .boolean()   .date()
invoice-data.period()   .enum(..values)   .array(of, min:)   .map(of)   .any()
invoice-data.field(type, doc:, bt:, required:, example:, since:)
```

`extensions` = `(invoice: (key: field | type, ..), party: (..), item: (..))`. Declared levels are closed (unknown keys reported) and typed (dates → datetime, decimals → decimal); undeclared levels stay open bags. `derive` = `values => values`, Typst code of the skeleton that runs after decoding, before the values apply.

### 5.3 Root export `payment(..)` (component; adopted from design B)

```text
payment(terms: none | dictionary, method: auto | "transfer" | "direct-debit" | "card" | "paid",
        bank: none | dictionary, creditor-id: none | str, direct-debit: none | dictionary,
        card: none | dictionary, paid: none | dictionary,
        show-reference: true, qr-code: (:)) -> content
```

The binding point of `payment`. It writes `payment-terms`, `direct-debit`, `card-payment` or `paid`, and `bank-details`, as the effective arguments call for (which components exist is data). Hydrated, the section applies by the roles of §2.6.

### 5.4 Binding points (no new API)

- `line-items[..]`: its body is the sample; when the data has `items`/`modifiers`/`prepayments`, ONE motif emits their frames instead and the sample is neither measured nor drawn. `line-items` options (`show-column`, `tax`, …) stay skeleton design.
- `ctx.custom`: unsealed by `unsealed()` (theme parts) and by `dynamic` (`info.get("custom", ..)`).
- Coverage check: data with `items` but no `line-items`, or with `payment` but no `payment(..)` → a `data` issue (`schema/items`, `schema/payment`), so a section can never be dropped silently.

### 5.5 Precedence and merge (complete)

1. Design is never data (no key for theme, locale, references layout, zugferd, validation, layout options).
2. `role: document` keys: data, else the parameter default (sample dropped).
3. `role: issuer` keys: data if given (as a whole: parties are replaced, never deep-merged — a partial merge could pair the skeleton's VAT ID with another seller's name), else the skeleton's value.
4. Body sections replace the skeleton's sample content at their binding point; `payment` applies key by key by its own roles.
5. `null` = absent. The defaults used by rule 2 are the `default` of each field in the descriptor; a repository test compiles `invoice()` with the descriptor's defaults passed explicitly and implicitly and compares md5 (proposed, guards drift with the signature).

---

## 6. Role classification (for review)

| Role     | Keys                                                                                                                                                                                                                                                                                                             |
| :------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| document | invoice-nr, date, document-type, due-date, service-period, customer-nr, order-nr, order-date, project, contract-nr, quote-nr, delivery-note-nr, preceding-invoice-nr, preceding-invoice-date, payment-reference, recipient, delivery-address; payment.direct-debit/card/paid; items/modifiers/prepayments (slot) |
| issuer   | currency, subject, notes, sender, payee, tax, tax-mode, tax-exempt-small-biz; payment.terms/method/bank/creditor-id                                                                                                                                                                                              |
| custom   | `custom`: from the data only (a skeleton's defaults belong in `default:` of declared fields or in the part's `default:`)                                                                                                                                                                                         |

Borderline (please confirm): `document-type` (a skeleton for credit notes would have to state it in the data), `subject` and `notes` (issuer: the skeleton often has a fixed thank-you note; data overrides as a whole).

---

## 7. CLI usage

### 7.1 Single invoice

```bash
# preview: the skeleton's samples
typst compile skeleton.typ

# a file (any size; path resolves against the skeleton, or root-absolute "/…")
typst compile skeleton.typ out/2026-0042.pdf --input invoice-pro-data-file=data/2026-0042.json
#   .toml / .yaml / .yml by extension; TOML dates are native

# inline JSON (zero skeleton code: any invoice-pro skeleton accepts it)
#   Linux ≤ 128 KiB per argument; Windows ~32 K characters for the whole command line
typst compile skeleton.typ out.pdf --input invoice-pro-data="$(cat data/2026-0042.json)"

# stdin (POSIX): the skeleton's read callback reads /dev/stdin, so the root must be /
cat data.json | typst compile --root / skeleton.typ out.pdf --input invoice-pro-data-file=/dev/stdin

# production: any problem stops with exit code 1; reproducible default date
typst compile skeleton.typ out.pdf --input invoice-pro-data-file=d.json \
  --input invoice-pro-validation=strict --creation-timestamp "$SOURCE_DATE_EPOCH" --pdf-standard a-3b
```

All verified in package mode (`@local/invoice-pro:0.7.0` via `--package-path`) on both compilers; file, inline and stdin give the same md5.

### 7.2 Getting results back

```bash
# 0.14 (and 0.15 with a deprecation warning): a second compile
typst query skeleton.typ "<invoice-pro-result>" --field value --one --input invoice-pro-data-file=d.json
# 0.15
typst eval 'query(<invoice-pro-result>).first().value' --in skeleton.typ --input invoice-pro-data-file=d.json
# ONE compile on both compilers: the result is attached to the PDF (opt-in)
typst compile skeleton.typ out.pdf --input invoice-pro-data-file=d.json --input invoice-pro-result=attach
pdfdetach -savefile invoice-pro-result.json -o out.result.json out.pdf     # or pypdf, pdf.js, …
```

### 7.3 Validation without layout (CI, phase 2)

```bash
# 0.15: ~165 ms + ~0.4 ms per row
typst eval '{ import "@preview/invoice-pro:0.7.0": invoice-data; invoice-data.check(json("d.json")) }'
# 0.14: a stub on stdin
printf '#import "@preview/invoice-pro:0.7.0": invoice-data\n#metadata(invoice-data.check(json("d.json"))) <r>\n' \
  | typst query --root . - '<r>' --field value --one
```

### 7.4 Schemas and docs, without layout

```bash
typst eval '{ import "@preview/invoice-pro:0.7.0": invoice-data; invoice-data.schema() }' > invoice.schema.json
typst eval '{ import "@preview/invoice-pro:0.7.0": invoice-data; invoice-data.result-schema() }' > result.schema.json
# the schema of THIS skeleton (core + declared fields), from the fields file shared with the skeleton
typst eval --root . '{ import "@preview/invoice-pro:0.7.0": invoice-data; import "/fields.typ": fields;
                       invoice-data.schema(extensions: fields) }' > skeleton.schema.json
# 0.14: the same through a `typst query -` stub (verified equal to 0.15's output)
```

### 7.5 Batch (one PDF per e-invoice is mandatory)

```bash
# portable: one process per invoice, in parallel (strict; a bad file fails alone, exit 1)
printf '%s\n' data/*.json | xargs -P 4 -I{} sh -c \
  'typst compile skeleton.typ "out/$(basename {} .json).pdf" --input invoice-pro-data-file={} \
     --input invoice-pro-validation=strict --input invoice-pro-result=attach'

# 0.15 bundle (experimental): ONE compile → out/<nr>.pdf each with its own factur-x.xml + out/results.json
typst compile --features bundle --format bundle batch.typ out/ --input invoice-pro-batch=a.json,b.json,c.json
```

`batch.typ` (compiled): `#invoice-data.batch(files.map(f => invoice-data.decode(json(f), extensions: fields)), skeleton)` where `skeleton` is the design written as a function of a record (`demo/design.typ`). Measured: 3 invoices in one bundle 1068 ms; 5 files as 4 parallel processes (compile + query each) 1979 ms.

### 7.6 Exit codes and status

| Outcome                                                                  | Exit | PDF                                              | `result.status` | e-invoice                     |
| :----------------------------------------------------------------------- | :--: | :----------------------------------------------- | :-------------- | :---------------------------- |
| no problem                                                               |  0   | final                                            | `ok`            | attached                      |
| data/legal problems, `validation: draft`                                 |  0   | draft (badge, markers, report page)              | `draft`         | `withheld`                    |
| any problem, `strict` (param or `--input invoice-pro-validation=strict`) |  1   | none                                             | –               | –                             |
| e-invoice rule errors, `zugferd-errors: panic` (default)                 |  1   | none                                             | –               | –                             |
| e-invoice rule errors, `zugferd-errors: report`                          |  0   | with report                                      | `ok`/`draft`    | `draft` (`invoice-draft.xml`) |
| unreadable JSON, other format major, Typst misuse                        |  1   | none                                             | –               | –                             |
| `validation: none`                                                       |  0   | as data allows (invalid values dropped silently) | `unchecked`     | per `zugferd-errors`          |

A pipeline either runs strict and checks the exit code, or runs draft and checks `status` in the result.

### 7.7 0.14 vs 0.15

|                          | 0.14.2                                                     | 0.15.1                                                       |
| :----------------------- | :--------------------------------------------------------- | :----------------------------------------------------------- |
| decode inline JSON       | `json(bytes(..))` (same code)                              | same                                                         |
| file                     | skeleton `read` callback                                   | same, or `data: path("d.json")`                              |
| results                  | `typst query` (2nd compile) or `invoice-pro-result=attach` | `typst eval` (2nd compile), attach, or bundle `results.json` |
| layout-free check/schema | `typst query -` stub                                       | `typst eval '{..}'`                                          |
| batch                    | processes                                                  | processes, or bundle                                         |

---

## 8. The result contract `invoice-pro-result/1`

Every invoice (hydrated or not) emits `[#metadata(record)<invoice-pro-result>]` in root's draw. It is invisible: 53/53 integration tests and the template have unchanged md5 (verified on both compilers). Shape (verified output of the demo; validates against `result.schema.json` with `jsonschema`):

```json
{
  "format": "invoice-pro-result/1",
  "package": "0.7.0",
  "data-format": "invoice-pro/1.0",
  "status": "ok",
  "validation": "draft",
  "invoice-nr": "2026-0042",
  "date": "2026-11-02",
  "due-date": "2026-11-16",
  "currency": "EUR",
  "document-type": "380",
  "recipient": "Bayerische Beispiel AG",
  "totals": {
    "net": "2033.61",
    "tax": "361.25",
    "gross": "2394.86",
    "prepaid": "500.00",
    "due": "1894.86"
  },
  "taxes": [
    { "category": "S", "rate": "19%", "basis": "1824.15", "amount": "346.59" },
    { "category": "S", "rate": "7%", "basis": "209.46", "amount": "14.66" }
  ],
  "lines": 6,
  "issues": [],
  "e-invoice": {
    "requested": "en16931",
    "profile": "en16931",
    "status": "attached",
    "file": "factur-x.xml",
    "errors": 0,
    "warnings": 0,
    "diagnostics": []
  }
}
```

- Strings for decimals, percentages and dates (Typst's serialisers would write `decimal("12.30")`), ints, booleans, `null`.
- `issues[]`: `{id, class, path, message, ref?}`; `path` is the JSON Pointer for problems of the data (`/items/0/price`), `null` for legal checks (`invoice-number`).
- `e-invoice.diagnostics[]`: `{level, rule, field, message}` from the rules engine (with `zugferd-errors: report`).
- `due-date`: BT-9 as the e-invoice states it (own due date, else payment-terms date, else date + days).
- Not included (by design): render-time lint findings (footer fit, identity), which are emitted later during page layout.

---

## 9. Extensibility

### 9.1 Custom fields: open bag vs declared extensions

- **Open bag** (default): `custom` on the document, parties and items accepts any JSON; values pass through as decoded (JSON dates stay strings). Good for ad-hoc data.
- **Declared** (`extensions:`): the skeleton lists its fields with the contract's types. Effects (all verified): unknown keys in that level are reported (`custom.tariff` → schema/custom/tariff), values are validated (`custom.wappen: "bavaria"` → "must be one of "muenchen", "berlin", "hamburg", "none""; `cost-center: "4711"` → "must be CC-<digits>"), typed (`campaign-end` → datetime), and **exported**: `invoice-data.schema(extensions: fields)` produces the skeleton's schema, so a phase-2 binding gets a typed model of the custom fields too (pydantic `class Custom` with `wappen: Wappen | None`, TS `wappen?: "muenchen" | …`, Rust `enum`).
- Theme parts read `ctx.custom` (sealed, so large payloads are free), item custom via `view.items[i].custom`, party custom via `ctx.recipient.custom`.

### 9.2 Data-dependent changes: three mechanisms, one rule ("data = facts, skeleton = rules")

| Need                              | Mechanism                                                                  | When it runs           | Example (verified)                                                                            |
| :-------------------------------- | :------------------------------------------------------------------------- | :--------------------- | :-------------------------------------------------------------------------------------------- |
| change the look by a value        | theme `wrap`/custom part reading `ctx.custom` / `view.recipient.post-code` | draw                   | Wappen by PLZ (`80331` → München arms, `20095` → Hamburg via `custom.wappen`, `50667` → none) |
| print a value                     | `info.get("custom", "tarif", default: "Standard")`                         | draw                   | "Tarif: Gold"                                                                                 |
| change a **parameter** by a value | `derive: values => values` in `decode/load`                                | eval, before invoice() | PLZ `8…` → adds the note "Gerichtsstand München." and `custom.region = "BY"`                  |
| choose design at document level   | plain Typst on `invoice-data.values(record)`                               | eval                   | `theme: if values.custom.brand == "b" { … }`                                                  |

A `dynamic()` cannot bind component parameters (research), which is why `derive` exists: it is Typst code (no expression language in data), runs once, and its output is applied with the same roles. The Wappen rule needs no new mechanism; declaring `wappen` turns the override into a validated, documented, exported field.

### 9.3 Extending the format itself

A new optional key in the table = new minor; it appears in the decoder, the JSON Schema and the docs with one entry. A new type = one constructor plus three interpreter branches (decode, export, docs).

---

## 10. Validation and error model

| Situation                                                                                    | Becomes                                                                  | Level-dependent?       | Example message                                                                                                                                                              |
| :------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------- | :--------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| wrong Typst usage (e.g. `invoice(data: 42)`, `payment(method: "x")`)                         | panic                                                                    | no                     | ``variable `invoice::data` must be of auto \| none \| dictionary \| bytes \| str (JSON text) \| a record of invoice-data.decode, found integer``                             |
| `--input invoice-pro-data` not JSON / `-file` without `read`                                 | panic                                                                    | no                     | ``--input invoice-pro-data-file=… needs one line in the skeleton, because a package cannot open your files: `data: invoice-data.load(read: p => read(p, encoding: none))`.`` |
| data in another format major                                                                 | panic (invoice) / issue (check)                                          | no                     | `invoice data is in format "invoice-pro/2"; this invoice-pro reads invoice-pro/1 only. …`                                                                                    |
| type/format/enum/unknown key/required/rule problem in the data                               | `data` issue `schema/<JSON Pointer>`, key `schema-<kind>`, value dropped | yes                    | ``invoice data: `items[0].price` must be a decimal number written as a string such as "12.30", found "12,30".``                                                              |
| a required key the legal checks cover (`invoice-nr`, `recipient`, `recipient.name`, `items`) | reported once, by check-data (inline marker + § reference)               | yes                    | `invoice::invoice-nr is missing; …`                                                                                                                                          |
| data section without binding point                                                           | `data` issue `schema/items` / `schema/payment`                           | yes                    | ``the data has a `payment` section, but the skeleton has no `payment(..)` block: …``                                                                                         |
| legal/e-invoice problems                                                                     | unchanged (check-data, rules engine)                                     | yes / `zugferd-errors` |                                                                                                                                                                              |

Issue kinds (`key`): `schema-type`, `schema-enum`, `schema-unknown-key`, `schema-required`, `schema-exactly-one`, `schema-exclusive`, `schema-length`, `schema-period`, `schema-tax-zero`, `schema-tax-rate`, `schema-unbound`. Messages are English (panic text, house style: path, value, allowed set, did-you-mean); a locale may translate them via `strings.validation.issues.schema-*` (falls back to English). Party keys use the e-invoice alias table (`plz`, `mail`, `ust-id`, …).

Verified with `data/bad.json` (11 problems): draft renders with "ENTWURF · 11 Probleme · keine E-Rechnung", a report page, the XML withheld and `status: "draft"` with each issue's JSON Pointer in the result; strict exits 1 with the numbered list; under `none` the invalid values are dropped and nothing is reported ("off means off", as documented on invoice()).

Drop semantics: an invalid value is left out; an object that then lacks what it needs (a line without a price) is left out as a whole, except where the schema keeps partial objects (`partial: true`: the document, parties, contact, bank, payment, terms — the legal checks then name the gap). So a draft never crashes on bad data, and a strict build never ships it.

---

## 11. Performance

What is skipped:

1. **Per-item loom motifs** (the dominant cost: ~2.4 ms/item/pass, every mutator op hashing the whole ctx). The data rows are ONE motif inside `line-items` that emits the same `item`/`group`/`bundle`/`modifier`/`prepayment` frames from a pure function of (rows, small settings), so loom's second pass is a memo hit (design B's `rows.typ`, research P2). The applicators, tree, view, theme and e-invoice are unchanged — hence byte-identical PDFs.
2. **Hashing of bulk data**: the decoded record's body (`ctx.data`) and the custom fields (`ctx.custom`) travel sealed in `metadata`, like the theme; their size costs nothing per loom call.
3. **Hashing of the descriptor during decoding**: the recursive decoder is memoized by Typst, which hashes its arguments; passing the 36-object descriptor sealed halved the check of 300 rows (606 → 262–293 ms wall, i.e. decode ≈ 100–130 ms ≈ 0.4 ms/row; traced: 3015 decoder calls). Found by profiling the prototype; the same rule as the theme's seal.
4. **Imports**: the contract modules load only inside the functions that use them (`invoice-data.*`, the hydrated branch of invoice(), the slot, root's result). Package import (`#import "/src/lib.typ": *`, 0.15.1): 153 vs 162 ms (median of 7) and, re-measured after formatting, 140.7 vs 139.1 ms (median of 11) — original vs prototype, within noise. The result record is the only new always-run code (one small dictionary per invoice).
5. Not skipped: the measure pass (max-passes stays 2). The research measured that skipping it adds only 0–5 % on top of the bulk motif and couples the format to the skeleton.

Measurements (wall clock, median of 5, round-robin alternating order, shared 4-core VM; `tools/bench.py`; same PDF md5 in each pair; data with description, unit and 19 %/7 % per row, EN 16931 XML, payment block):

| rows | compiler | hand-written `item()` | hydrated |     Δ |
| ---: | :------- | --------------------: | -------: | ----: |
|    5 | 0.15.1   |                512 ms |   458 ms | −11 % |
|   50 | 0.15.1   |               1317 ms |  1121 ms | −15 % |
|  300 | 0.15.1   |               6384 ms |  4417 ms | −31 % |
|    5 | 0.14.2   |                506 ms |   468 ms |  −8 % |
|   50 | 0.14.2   |               1387 ms |  1131 ms | −18 % |
|  300 | 0.14.2   |               6542 ms |  4495 ms | −31 % |

Layout-free operations (median of 7): 0.15.1 `typst eval` import only 165 ms, schema export 162 ms, `check` of the demo file 165 ms, `check` of 300 rows 262–293 ms (two series); 0.14.2 `typst query` stub: import only 206 ms, `check` of 300 rows 333 ms. Decode therefore costs ≈ 0.4 ms per row, ≈ 2–3 % of the 300-row compile.

What remains for large invoices is the theme's table layout (keep-together `fits()`, 3 layout iterations), outside the data path; the format cannot fix it (research: ~5 s of 6.8 s at 500 rows).

---

## 12. API change ledger

| Change                                                                 | File                                                                    | Kind                             | Justification                                                                                                                                                                                                  |
| :--------------------------------------------------------------------- | :---------------------------------------------------------------------- | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `invoice(data: auto)`                                                  | src/invoice.typ (+93 lines, lazy hydrated branch)                       | new-parameter                    | Data issues must join the validation inside invoice() (draft/strict/XML withholding); body-only hydration gives false "missing" issues and embeds wrong XML (research). `auto` = zero-code CLI hydration.      |
| root export `invoice-data`                                             | src/public/invoice-data.typ, src/lib.typ                                | new-export                       | The contract's public face (decode/load/check/schema/result-schema/reference/batch + field types). Not `data`: a user's `#let data = json(..)` would shadow it. Must be added to tests/theme/exports/test.typ. |
| root export `payment`                                                  | src/components/payment.typ                                              | new-export                       | Which payment components exist is data (paid excludes terms); a composite binding point instead of making five components data-aware.                                                                          |
| sys.inputs `invoice-pro-data`, `invoice-pro-data-file`                 | src/contract/input.typ                                                  | new-parameter (CLI)              | "One input = one JSON document" for CLI and phase-2 bindings; the file key needs the skeleton's `read` callback.                                                                                               |
| sys.inputs `invoice-pro-result=attach`                                 | src/contract/result.typ                                                 | new-parameter (CLI)              | One-compile results on 0.14 and 0.15 (opt-in; PDF otherwise unchanged).                                                                                                                                        |
| label `<invoice-pro-result>` on every invoice                          | src/components/root.typ, src/contract/result.typ                        | new-export                       | Machine-readable result; verified zero output change (53/53 + template md5).                                                                                                                                   |
| line-items body becomes a slot when hydrated                           | src/components/line-items.typ (+26)                                     | behaviour-change (hydrated only) | The sample body is replaced by ONE bulk motif; non-hydrated behaviour identical (md5).                                                                                                                         |
| coverage issues `schema/items`, `schema/payment`; payment-block issues | src/components/root.typ (+45)                                           | new-export (issue ids)           | Data never dropped silently.                                                                                                                                                                                   |
| `unsealed()` and `dynamic` unseal `ctx.custom`                         | src/theming/access.typ (+4), src/components/dynamic.typ (+3)            | internal-refactor                | Custom fields travel sealed (perf); parts and `info.get` see plain values.                                                                                                                                     |
| reserved party key `custom` (print-only)                               | src/zugferd/model.typ (+3)                                              | new-parameter                    | Party custom fields without IP-KEY-01/02.                                                                                                                                                                      |
| new internal modules                                                   | src/contract/{types,schema,decode,export,hydrate,input,result,rows}.typ | internal-refactor                | The contract; loaded lazily.                                                                                                                                                                                   |

No existing parameter, default, export or output changes.

---

## 13. Phase-2 hooks

1. **`invoice.schema.json` (2020-12)** generated from the descriptor, committed under `src/contract/` (published files live under src/), with a CI check that `typst eval … schema()` equals the committed file (like `bt_disposition.py --update-docs`). Codegen-friendly and verified: datamodel-codegen → pydantic v2 (1097 lines; the demo file round-trips, and its default dump with 15 `null`s validates against the schema; `recipient.plz` is rejected), json-schema-to-typescript (1032 lines, `"invoice-nr": string`, `wappen?: "muenchen" | …`), typify → Rust (7812 lines, `deny_unknown_fields`, serde renames). The first typify run crashed on the two-spelling unit enum — the format now has one spelling, and **codegen belongs in CI** as a contract test.
2. **`result.schema.json`**: bindings generate the result type too (`status`, `totals`, `issues[].path`, `e-invoice`).
3. **Skeleton schemas**: `schema(extensions: fields)` gives each skeleton its typed model (custom fields included).
4. **Annotations**: `x-en16931`, `x-invoice-pro-role`, `x-invoice-pro-bind`, `x-invoice-pro-since` let a binding generate docs, mark required-by-law fields, or map to EN 16931 models.
5. **Conformance suite**: `conformance/fixtures.json` (51 cases: valid, invalid, lenient) + `tools/compare.py`: every binding can run the same fixtures against its generated model, and invoice-pro runs them against its decoder (0.14 and 0.15 agree byte for byte).
6. **Protocol**: one `sys.inputs` key = one JSON document (`invoice-pro-data`); embedders using typst as a library may pass a dictionary instead of text; results via the label, the PDF attachment or the bundle sidecar; exit code 1 = not deliverable.
7. **Layout-free primitives**: `check` and `schema` via `typst eval` (~160 ms) for pre-flight validation in bindings.

---

## 14. Prototype

Path: `<session>/exp/design-D-contract/`

| Path                                                            | What                                                                                                                |
| :-------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------ |
| `repo/src/contract/types.typ`                                   | the type vocabulary (18 constructors, `field`, `object`)                                                            |
| `repo/src/contract/schema.typ`                                  | THE descriptor: 36 objects, 180 keys, roles, BT numbers, docs, `extend()`                                           |
| `repo/src/contract/decode.typ`                                  | generic decoder/validator (JSON Pointer issues, converters to tax/unit/id values)                                   |
| `repo/src/contract/export.typ`                                  | JSON Schema 2020-12 + Markdown reference from any descriptor                                                        |
| `repo/src/contract/hydrate.typ`                                 | records, roles → invoice() parameters, payment roles, legal-check dedupe                                            |
| `repo/src/contract/input.typ`                                   | CLI keys, file/inline/stdin/dictionary, 0.15 path                                                                   |
| `repo/src/contract/result.typ`                                  | result descriptor, record, label, optional attachment                                                               |
| `repo/src/contract/rows.typ`, `repo/src/components/payment.typ` | bulk rows motif and payment block (adopted from design B)                                                           |
| `repo/src/public/invoice-data.typ`                              | the public namespace                                                                                                |
| `repo/demo/`                                                    | skeleton, fields, handwritten twin, design function, batch, data (4 good files incl. TOML, `bad.json`), Wappen SVGs |
| `repo/conformance/`                                             | fixtures + Typst batch checker                                                                                      |
| `repo/bench/`                                                   | 5/50/300-row data + hand-written twins                                                                              |
| `schema/`                                                       | exported `invoice.schema.json`, `skeleton.schema.json`, `result.schema.json`, `reference.md`                        |
| `codegen/`                                                      | generated pydantic / TypeScript / Rust models                                                                       |
| `user/`, `pkgs/`                                                | package-mode tests (`@local/invoice-pro:0.7.0`), `batch.sh`                                                         |
| `verify.sh`, `tools/`                                           | all checks, regression, benchmark, fixtures, comparison                                                             |
| `src.diff`                                                      | the full diff against the original src                                                                              |

Results (`verify.sh`, both compilers, 21/21 PASS): demo hydrated == hand-written (md5); inline == file; preview compiles; result validates against its schema (due 1894.86, XML attached); bad data → draft with XML withheld / strict exit 1; bench 5/50/300 hydrated == item() (md5); conformance 51/51; skeleton schema meta-valid and equal on 0.14/0.15, all example files valid. Plus: `tools/regress.sh` 53/53 integration tests md5-identical (7 expected-panic tests do not compile in the original either); package mode file/inline/stdin same md5, TOML hydrates, `package` reads 0.7.0 from the package's typst.toml; bundle batch 3 PDFs each with own XML + results.json; `derive` and 0.15 `path` work; result attachment readable with `pdfdetach` under PDF/A-3b on both compilers.

---

## 15. Risks

- **Descriptor/signature drift**: the descriptor's `default`s duplicate invoice()'s defaults. Mitigation: a test compiling invoice() with descriptor defaults explicit vs implicit (md5).
- **Decoder/schema drift**: two interpreters of one table can still disagree (regexes are written twice: decode.typ and export.typ). Mitigation: the differential fixtures in CI on both compilers, plus codegen in CI.
- **Rows divergence**: `rows.typ` re-implements item/bundle/group scopes; equivalence is proven for the tested shapes (groups, bundles, item/doc modifiers, prepayments, units, tax cascades, md5 at 5/50/300 rows), not for every cascade (`apply` around the slot, small-business override, `input-gross` with tax-mode inclusive). Needs motif-vs-data equivalence tests per feature.
- **Result attachment** (`invoice-pro-result=attach`): adds a second embedded file to e-invoice PDFs. PDF/A-3b export accepts it; external Factur-X/XRechnung validators were not run here (Mustang/KoSIT unavailable) — opt-in until validated.
- **`typst query` deprecation**: the 0.14 path for results and layout-free checks uses `query`, deprecated in 0.15 (still works with a warning).
- **Bundle export is experimental** and 0.15-only; the process batch is the portable default.
- **Party custom is unsealed** in ctx (performance trap for large party payloads; documented: keep it small or use document custom).
- **Prints-of side effect**: data-driven parts (the Wappen wrap) set `prints-of.page-content = true`, weakening the e-invoice "printed?" checks (research); unchanged by this design.
- **Strictness of strings**: producers that send JSON numbers for invoice numbers get a schema issue (deliberate: one encoding), which may surprise users of loose ERPs.
- **Size**: ~2,300 new lines of Typst (descriptor 835) to maintain; mitigated by generation — the per-key cost is one table entry.

---

## 16. Rejected alternatives

1. **Hand-written JSON Schema next to a hand-written decoder** — two sources of truth; prior-art research flagged the drift risk.
2. **JSON Schema as the source, interpreted in Typst** — Typst would need a JSON Schema interpreter; BT numbers, roles and conversions (tax, unit, id constructors) do not fit JSON Schema keywords cleanly.
3. **`x-*` extension keys** — break generated pydantic/typify models (research); a named `custom` bag works everywhere.
4. **Accepting several spellings** (unit names and codes, `street`/`address`) — breaks codegen (verified with typify) and doubles the contract.
5. **Body-only hydration** (a `hydrate()` component) — false "missing" issues, wrong XML embedded (research).
6. **Skipping the measure pass** — 0–5 % more after the bulk motif, couples data and skeleton (research).
7. **Results only via `typst query`** — always a second compile; the attachment and the bundle sidecar give one compile.

---

## 17. Open questions (with recommendation)

1. Commit the generated schemas to `src/contract/` with a CI drift check, or generate at release only? _Recommendation: commit + CI check (like bt-disposition)._
2. Should the result's `issues` also carry render-time lint findings? _Recommendation: no in v1 (they are emitted during layout; would need a second introspection pass)._
3. Should invoice() accept the descriptor's `default`s programmatically (e.g. a `defaults` export) to remove the duplication? _Recommendation: keep the table, add the md5 test._
4. Should `invoice-pro-result=attach` become the default for batch? _Recommendation: only after Mustang/KoSIT accept PDFs with the extra attachment._
5. Should the format allow a `locale` hint (recipient language)? _Recommendation: not in v1; a declared custom field + a Typst rule in the skeleton (`locale: if values.custom.lang == "en" {..}`) covers it without silently dropping `locale.custom` patches._
6. Should declared fields support defaults that apply without data (preview)? _Recommendation: yes in v1.1 (`default:` of `field()` → ctx.custom of the preview)._
7. Which `$id` host? _Recommendation: the docs site, versioned by format major only._
8. Tier: ship `invoice-data` and `payment` as **experimental** in 0.7.0 (precedent: from-data, zugferd), the format `invoice-pro/1` as **provisional**.
