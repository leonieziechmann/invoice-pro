# Design B: integrated hydration (one `data` parameter and slots)

Status: design proposal with a working prototype, for invoice-pro 0.6.0 → 0.7.0. The prototype lives in a copy of the repository at `<session>/exp/design-B-integrated/repo` (src changes allowed there; the real repository is untouched). Every number and claim below was measured or compiled on typst 0.15.1 and 0.14.2 with `<session>/exp/design-B-integrated/verify.sh`, unless it is marked _not verified_. `<session>` = `<session>`.

---

## Executive summary

**The idea.** The skeleton is an ordinary, complete invoice with sample data, written by hand. Hydrating it changes nothing in the skeleton: invoice-pro reads the data, replaces the sample values with the real ones inside `invoice()` (before the input checks), and fills the body's slots. A slot is a place in the body that the data fills. There are two: the content of `line-items` and the new `payment(..)` block.

**What a user learns.** There are five things:

1. Compile the skeleton with `--input invoice-pro-data='<JSON>'`. Or add one line, `data: if "data" in sys.inputs { json(sys.inputs.data) }`, for files.
2. One rule. What identifies one invoice comes from the data only: number, dates, recipient, references, line items, and the details of a direct debit, card or paid invoice. Everything else (sender, bank, terms, tax settings) keeps the skeleton's value unless the data gives it.
3. `payment(..)`. Use it if the data should choose the payment method.
4. `custom`, for fields of your own. Parts read it as `ctx.custom`, the body as `info.get("custom", ..)`.
5. The data format: kebab-case keys equal to the Typst parameter names.

Nothing in the skeleton has to be marked.

**Why it is safe.** A sample value can never leak into a real invoice. Document fields are dropped when the data lacks them, and validation then reports the missing required ones (draft marker, strict panic, XML withheld). Parties are replaced as a whole, never merged. A merge could combine the skeleton's VAT ID with the data's customer.

**Why it is fast.** The data rows replace the line-items body as ONE bulk motif. It is built by a pure function of (rows, small settings), so loom's second pass is a memo hit. It measured 144 ms in pass 1 and 1.1 ms in pass 2 for 300 rows. Wall time compared with the same invoice written with `item()` calls:

| rows | 0.15.1 | 0.14.2 |
| ---: | -----: | -----: |
|    5 |   −9 % |   −7 % |
|   50 |  −21 % |  −29 % |
|  300 |  −37 % |  −38 % |

The PDFs are byte-identical (md5) on both compilers.

**What changes in the public API.** It is only extended:

- 2 new `invoice()` parameters (`data`, `custom`);
- 2 new root exports (`payment`, `data-format`);
- 1 new package input key (`invoice-pro-data`);
- 1 new metadata label (`<invoice-pro:result>`, only on hydrated invoices).

No existing signature or default changes. The non-hydrated path is byte-identical: 53 of 53 compilable integration tests and the template have equal md5s with the original and the prototype `src`.

**What I need from you (maintainer).**

- (1) Confirm the document/template classification of the borderline keys (§3.2: notes, subject, document-type, payment terms).
- (2) Accept `payment(..)` as the payment slot, instead of making `payment-terms`/`bank-details` hydratable in place (§14, rejected alternative 5).
- (3) Choose names: `data` and `custom` for the parameters, `data-format` for the namespace (§5).
- (4) Decide whether a data error should be a `data` issue (the prototype) or a panic (§9).

---

## Design decisions at a glance

| Decision      | Choice                                                                                                                    | Why                                                                                                                                           |
| :------------ | :------------------------------------------------------------------------------------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------- |
| Entry point   | `invoice(data: auto)`; `auto`/`none` read `--input invoice-pro-data`                                                      | Zero skeleton change for inline JSON. Decoding inside `invoice()` before the checks, so validation, the e-invoice and the frame see the data. |
| Files         | the skeleton reads them: `data: if "data" in sys.inputs { json(sys.inputs.data) }`                                        | A package cannot open user paths (verified on 0.14 and 0.15). One line, works on both compilers. On 0.15, `path(..)` also works.              |
| Precedence    | document keys: data only; template keys: data wins if present; design: never data                                         | A sample cannot leak; no marker to forget.                                                                                                    |
| Merge         | parties and other values replaced as a whole; `payment` and `custom` sections key by key; `null` = reset to default       | A deep merge leaks skeleton fields (VAT ID, BIC) into another counterparty or tenant.                                                         |
| Items         | the content of `line-items` is the implicit slot; data rows replace it as one bulk motif                                  | Byte-identical output, −37 to −41 % at 300 rows, no new concept for users.                                                                    |
| Payment       | new composite `payment(terms, method, bank, creditor-id, direct-debit, card, paid, ..)`                                   | Which components exist is data (paid excludes terms; only a transfer states the bank account, CII-SR-467).                                    |
| Custom fields | `invoice(custom:)`, data `custom`, party `custom`, item `custom`; sealed in ctx                                           | One named open bag per level (prior art: GOBL `meta`, Stripe `metadata`), codegen-friendly. Sealed means free however large it is.            |
| Wappen rule   | stays Typst: `theme.custom.wrap("logo", ..)` reads `view.recipient.post-code` / `ctx.custom.wappen`                       | Design is not data; data carries facts only.                                                                                                  |
| Errors        | data problems are `data` issues `schema/<path>`, the value is dropped; misuse of the Typst API panics                     | Draft report, strict panic and XML withholding work unchanged.                                                                                |
| Format        | JSON canonical (YAML/TOML work), kebab-case = Typst names, decimal strings, `"19%"`, ISO dates, `format: "invoice-pro/1"` | 1:1 with the Typst API; exact money; codegen-friendly.                                                                                        |
| Schema        | ONE declarative table in Typst drives the decoder, the precedence classes and a JSON Schema 2020-12 export                | No drift between the Typst validation and phase-2 bindings.                                                                                   |
| Speed         | bulk rows, sealed ctx data, lazy imports; no pass skipping                                                                | Memoisation is the lever (loom research P2 ≈ P3).                                                                                             |

---

## 1. Mental model

```text
skeleton.typ (hand-made, previewable)          data (JSON / YAML / TOML / inline)
  #show: invoice.with(theme, sender, samples…)        │  --input invoice-pro-data='{…}'  or  json(path)
  #line-items[ sample items ]   ← items slot          │
  #payment(terms, bank, …)      ← payment slot        ▼
                                              invoice(data: ..)
                                                ├─ resolve-data      (input.typ, always; tiny)
                                                ├─ hydrate           (apply.typ + decode.typ, lazy)
                                                │    document keys ← data only
                                                │    template keys ← data if given, else skeleton
                                                │    → effective parameters + data issues
                                                ├─ the existing type checks, normalisation, check-data
                                                ├─ inputs += hydration: metadata((items, modifiers, prepayments, payment))
                                                │          + custom: metadata(custom)
                                                └─ weave (2 passes, unchanged)
                                                     line-items › items slot: data rows → ONE bulk motif
                                                     payment(..) block: data → payment components (nested weave)
                                                     root: + placement issues, + <invoice-pro:result>
```

Without data, every step is the one of 0.6.0. The only additions on this path are a wrapper motif inside `line-items` and the `payment` block, if the skeleton uses it. Output is byte-identical (§12).

## 2. The user's view

The skeleton below is the prototype's `skeleton.typ` (compiled). It is a normal invoice. The only hydration-specific line is the optional file line.

```typst
#import "@preview/invoice-pro:0.7.0": *

// ---- design rule: a coat of arms by the recipient's post code -------------
// (the data supplies only the fact: the post code, or `custom.wappen`)
#let arms = (
  muenchen: image("wappen/muenchen.svg", alt: "Wappen München"),
  berlin: image("wappen/berlin.svg", alt: "Wappen Berlin"),
  hamburg: image("wappen/hamburg.svg", alt: "Wappen Hamburg"),
)
#let arms-by-plz = ("8": "muenchen", "1": "berlin", "2": "hamburg")
#let wappen(ctx, view, inner) = {
  let plz = view.recipient.at("post-code", default: none)
  let key = ctx.at("custom", default: (:)).at("wappen", default: none)
  if key == none and plz != none {
    key = arms-by-plz.at(plz.first(), default: none)
  }
  if key == none or key not in arms { return inner(ctx, view) }
  let ctx = ctx
  ctx.theme.options.logo.image = arms.at(key)
  inner(ctx, view)
}

#show: invoice.with(
  // the one line that lets the CLI hand over a FILE (a package cannot open it)
  data: if "data" in sys.inputs { json(sys.inputs.data) },
  theme: theme.classic.with(theme.custom.wrap("logo", wappen)),
  locale: locale.de-de,
  zugferd: "en16931",
  // template: the issuer, kept unless the data gives `sender`
  sender: (
    name: "Entsorgung Süd GmbH",
    address: "Industriestraße 7",
    city: "80339 München",
    country: "DE",
    vat-id: "DE123456789",
    tax-nr: "143/123/45678",
    contact: (
      name: "Buchhaltung",
      phone: "+49 89 1234567",
      email: "rechnung@entsorgung-sued.example",
    ),
  ),
  // samples: a hydrated invoice takes these from the data only
  recipient: (
    name: "Erika Mustermann",
    address: "Musterweg 1",
    city: "10115 Berlin",
    country: "DE",
  ),
  invoice-nr: "MUSTER-0001",
  date: datetime(year: 2026, month: 1, day: 15),
  custom: (tarif: "Grundversorgung"),
)

Tarif: #info.get("custom", "tarif")

#line-items[
  #item("Leerung Restmüll 120 l", quantity: 4, unit: unit.pcs, price: 12.5)
  #item("Sperrmüllabholung", price: 45)
]

#payment(
  terms: (days: 14),
  bank: (
    bank: "Musterbank",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  ),
  creditor-id: "DE98ZZZ09999999999",
)

#signature()
```

```text
typst compile skeleton.typ                                            # preview: Berlin arms, MUSTER-0001, transfer + QR
typst compile skeleton.typ --input invoice-pro-data="$(cat inv.json)" # inline: zero code
typst compile --root . skeleton.typ --input data=data/2026-0042.json  # file: needs the one `data:` line
```

Results of the three runs (both compilers, PDF/A-3b, `factur-x.xml` attached in each):

- **Preview:** "Rechnung MUSTER-0001", the Berlin arms, payment terms with bank details and the EPC QR code.
- **Inline** (`data/inline.json`, Munich post code, card): "Rechnung 2026-0043". The sample recipient is gone, the Munich arms come from the post code, and the card sentence replaces the transfer and the QR code. `custom.tarif` keeps the skeleton's "Grundversorgung", because the data has no `custom`.
- **File** (`data/2026-0042.json`): "Rechnung 2026-0042". It has the Hamburg arms (by `custom.wappen`), groups, a bundle split by VAT rate, an item discount and a document surcharge. The data chooses the direct debit; the creditor ID and the 14-day terms come from the skeleton. Tarif "Gewerbe M".

## 3. Precedence and merge rules

### 3.1 The rules

Layers, from lowest to highest: invoice() defaults < skeleton arguments < data.

| #   | Rule                                                                                                                                                                                                                                                                                   | Applies to                                                                                                                                                                                     |
| :-- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R1  | **Design is never data.** The format has no key for it, so data cannot change it.                                                                                                                                                                                                      | `theme`, `locale`, `references`, `zugferd`, `zugferd-errors`, `validation`; layout arguments of components (`show-column`, `qr-code`, `show-reference`, …); the body text; the signature image |
| R2  | **Document keys come from the data alone.** The skeleton's value is a preview sample: it is dropped when hydrating. Absent or `null` gives the parameter default (`date` → today, `recipient` → `(:)`, others → `none`). Missing required data is reported by the existing validation. | class `document` (§3.2)                                                                                                                                                                        |
| R3  | **Template keys keep the skeleton's value unless the data gives the key.** A value from the data replaces the skeleton's as a whole. `null` resets it to the parameter default.                                                                                                        | class `template` (§3.2)                                                                                                                                                                        |
| R4  | **Sections apply key by key.** `payment` and `custom` are sections: each of their keys follows R2 or R3 on its own. A `null` section resets the whole section (`payment: null` → no payment block; `custom: null` → no custom fields).                                                 | `payment.*`, `custom.*`                                                                                                                                                                        |
| R5  | **The items slot is replaced, never appended.** When hydrating, the whole content of `line-items` is a sample, and `items` + `modifiers` + `prepayments` of the data take its place. Absent means empty, and validation then reports "line-items" missing.                             | `items`, `modifiers`, `prepayments`                                                                                                                                                            |
| R6  | **An explicit `data:` wins over `--input invoice-pro-data`.** `auto` and `none` both mean "read the input if present".                                                                                                                                                                 | the `data` parameter                                                                                                                                                                           |

There is no deep merge. Parties, `city`, `contact`, tax objects, `terms` and `bank` are values. Rejected alternative 2 (§14) shows why: a merge lets a sample or another tenant's VAT ID or BIC survive next to the data's name.

### 3.2 Classification of every top-level key (from `schema.typ`, the single source)

| class         | keys                                                                                                                                                                                                                                                                                               |
| :------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| document (R2) | `invoice-nr`, `date`, `due-date`, `service-period`, `customer-nr`, `order-nr`, `order-date`, `project`, `contract-nr`, `quote-nr`, `delivery-note-nr`, `preceding-invoice-nr`, `preceding-invoice-date`, `payment-reference`, `recipient`, `delivery-address`, `items`, `modifiers`, `prepayments` |
| template (R3) | `sender`, `payee`, `currency`, `subject`, `document-type`, `notes`, `tax`, `tax-mode`, `tax-exempt-small-biz`                                                                                                                                                                                      |
| section (R4)  | `payment` (`terms`, `method`, `bank`, `creditor-id` = template; `direct-debit`, `card`, `paid` = document); `custom` (template, key by key)                                                                                                                                                        |
| meta          | `format`, `$schema` (checked, then dropped)                                                                                                                                                                                                                                                        |

Consequences, all verified:

- The sample `invoice-nr` "MUSTER-0001" did not leak into `bad.json`, which lacks a number. It was reported as "Fehlt: Rechnungsnummer" instead.
- `custom: null` printed an empty "Tarif:".
- `payment: null` removed the block. EN 16931 then stopped with IP-PAY-06; with `"due-date": "2026-04-01"` the XML carries `DueDateDateTime 20260401` (BT-9, not BT-20 text).
- The sample date is dropped, so the date falls back to today (pin it with `--creation-timestamp`).

## 4. The data format "invoice-pro/1"

### 4.1 Top level and conventions

- **One JSON object = one invoice.** JSON is the canonical format; YAML and TOML decode to the same dictionaries. TOML dates arrive as native datetimes and are accepted.
- **Keys** are kebab-case and equal to the Typst parameter or dictionary-key names (`invoice-nr`, `vat-id`, `base-quantity`, `item-id`). Hydration is therefore a mechanical mapping. Codegen maps the names to snake_case or camelCase through aliases (verified in prior-art research for TypeScript, pydantic and typify).
- **`format`**: optional; if present, it must be `"invoice-pro/1"` (anything else is an issue). Absent means 1. **`$schema`**: optional, for editors (`urn:invoice-pro:data:1`).
- **Closed objects.** An unknown key is an issue with a did-you-mean hint and the e-invoice alias hints (`plz` → "Did you mean `city`? Write the post code into `city`, …"), and the value is ignored. Open bags are named `custom`.
- **Absent vs `null`**: absent = "not given" (R2/R3); `null` = the parameter default. Inside objects, `null` is passed on as `none`.

### 4.2 Encodings

| type              | JSON                                                                                                                                                   | Typst value                                             | notes                                                                                                                                                                   |
| :---------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| text              | `"…"`                                                                                                                                                  | str                                                     | a JSON integer is accepted (`42` → `"42"`); other types are issues                                                                                                      |
| lines             | `"…"` or `["line 1", "line 2"]`                                                                                                                        | str / array                                             | `name`, `address`, `legal-info`                                                                                                                                         |
| date              | `"YYYY-MM-DD"` (TOML date)                                                                                                                             | datetime                                                | calendar-checked (`2026-02-30` is an issue, not a crash)                                                                                                                |
| period            | date or `[start, end]`                                                                                                                                 | datetime / (datetime, datetime)                         | end ≥ start                                                                                                                                                             |
| amount            | `"12.50"` (JSON number accepted)                                                                                                                       | decimal                                                 | regex-checked before `decimal()`; a float goes through `decimal(str(x))`, which is exact (49.90 → 49.9; not `to-decimal`'s 49.899999999999999)                          |
| percent           | `"19%"`                                                                                                                                                | ratio                                                   | `float(n) / 100 * 100%`, bit-exact with the literal (9.975% verified)                                                                                                   |
| amount-or-percent | `"10%"` relative / `"5.00"` absolute                                                                                                                   | ratio / decimal                                         | modifiers, prepayments                                                                                                                                                  |
| tax               | `"19%"`, `"exempt"`, `"reverse-charge"`, `"intra-community"`, `"export"`, `"outside-scope"`, `"zero"`, or `{rate, category, grounds, code, label}`     | the dictionary of the matching `tax.*` constructor      | `"19%"` = `tax.vat(19%)`, which every region's `infer-tax` returns for its known rates, but it never panics on an unknown rate. `"0%"` is an issue (name the category). |
| unit              | a unit name (`"hour"`, `"pcs"`, 76 names), a UN/ECE code (`"HUR"`, 18 codes), `{code, display}` or free text                                           | `unit.*` function / dict / str                          | free text behaves as in the Typst API                                                                                                                                   |
| identifier        | `"…"`, `{"gln": ".."}`, `{"duns"}`, `{"siren"}`, `{"siret"}`, `{"uid-ch"}`, `{"leitweg"}`, `{"register": .., "court": ..}`, `{"scheme": .., "id": ..}` | `id.*` result (check digits → IP-ID-01) or the raw dict | `id`, `global-id`, `legal-id`, `electronic-address`, `buyer-reference`, `leitweg-id`, `location-id`                                                                     |
| city              | `"10115 Berlin"` or `{post-code, name, state, display, inline-display}`                                                                                | str / dict                                              | a numeric `post-code` is an issue (leading zeros)                                                                                                                       |
| country           | ISO alpha-2 `"DE"`                                                                                                                                     | str                                                     |                                                                                                                                                                         |
| currency          | ISO 4217 `"EUR"`                                                                                                                                       | str (upper-cased)                                       |                                                                                                                                                                         |
| item-id           | `"A-1"` or `{seller, buyer, standard}`                                                                                                                 | str / dict                                              |                                                                                                                                                                         |
| notes             | `"…"` or `["…", {text, subject-code}]`                                                                                                                 | as Typst                                                |                                                                                                                                                                         |
| last4             | `"4242"` (4–6 digits, a string)                                                                                                                        | str                                                     |                                                                                                                                                                         |

### 4.3 Objects (complete; `schema.typ` is authoritative, `<session>/exp/design-B-integrated/invoice-data.schema.json` is the generated JSON Schema)

**Parties** mirror `zugferd/model.typ party-keys`, plus `custom`:

- **address keys (all roles):** `name`, `address`, `street`, `city`, `country`, `region`, `extra` (dict or pairs, printed), `custom` (open, never written to the e-invoice).
- **seller (`sender`):** the address keys and `id`, `global-id`, `legal-id`, `trading-name`, `vat-id`, `tax-nr`, `legal-info`, `tax-representative` (object with the address keys and `vat-id`), `electronic-address`, `contact` (`{name, phone, email}`), `contact-name`, `phone`, `email`, `register`, `management`.
- **buyer (`recipient`):** the address keys and `id`, `global-id`, `legal-id`, `trading-name`, `vat-id`, `electronic-address`, `contact`, `contact-name`, `phone`, `email`, `buyer-reference`, `leitweg-id`, `order-nr`, `po-nr`, `contract-nr`, `delivery-note-nr`, `delivery-address` (ship-to), `tax-nr`, `customer-nr`, `customer-id`, `order-date`, `project`, `quote-nr`.
- **ship-to (`delivery-address`):** the address keys and `id`, `location-id`, `global-id`.
- **payee:** `name` (required), `id`, `global-id`, `legal-id`, `custom`.

**Line items** form a tree in `items`, with a `kind` discriminator.

- **item** (`kind` absent or `"item"`):
  - `name` (required);
  - exactly one of `price` and `total`;
  - optional: `description`, `quantity`, `base-quantity`, `unit`, `date` (date or period), `input-gross`, `tax`, `item-id`, `reference`, `note`, `origin`, `modifiers` (item-level), `custom`.
- **group**: `kind: "group"`, `name`, `items` (required); optional `description`, `show-subtotal`, `tax`, `input-gross`, `date`, `unit` (cascaded to the children like `group(..)`).
- **bundle**: `kind: "bundle"`, `name`, `items` (required); optional `description`, `quantity`, `base-quantity`, `unit`, `date`, `input-gross`, `tax`, `item-id`, `reference`, `modifiers` (bundle-level).
- **modifier** (in `modifiers` at document, bundle or item level): `kind` (`"discount"` | `"surcharge"` | `"modifier"`), `name` and `amount` are required; optional `label`, `description`, `tax` (pins the modifier to one VAT group), `input-gross`.
- **prepayment** (in `prepayments`): `amount` (required, absolute or `"30%"`); optional `name`, `label`, `date`, `reference`, `description`, `method`.
- **Nesting limit: 8 levels** of groups and bundles. Deeper is an issue, because `collect-signals(depth: 10)` drops deeper items from the totals (line-items research).

**Payment** (`payment` section):

- `terms`: `{days, date, discount}`; `discount` is `{days, percent, basis}` or an array of them.
- `method`: `"transfer"` | `"direct-debit"` | `"card"` | `"paid"`.
- `bank`: `{name, bank, iban, bic}`.
- `creditor-id`.
- `direct-debit`: `{mandate (required), debtor-iban}`.
- `card`: `{last4 (required), holder, kind: "credit" | "debit"}`.
- `paid`: `{method: cash|cheque|online|transfer|card|direct-debit, date}`.

**Custom**: any JSON object, at document level, on parties and on items.

### 4.4 Complete example (`data/2026-0042.json`, compiled; `custom.wappen` drives the Wappen rule)

```json
{
  "$schema": "urn:invoice-pro:data:1",
  "format": "invoice-pro/1",
  "invoice-nr": "2026-0042",
  "date": "2026-03-02",
  "service-period": ["2026-02-01", "2026-02-28"],
  "customer-nr": "K-10077",
  "order-nr": "PO-2026-118",
  "recipient": {
    "name": "Hafenbäckerei Petersen KG",
    "address": "Große Elbstraße 12",
    "city": { "post-code": "20457", "name": "Hamburg" },
    "country": "DE",
    "vat-id": "DE987654321",
    "contact": {
      "name": "Jan Petersen",
      "email": "buchhaltung@hafenbaeckerei.example"
    },
    "custom": { "bezirk": "Hamburg-Mitte" }
  },
  "items": [
    {
      "name": "Leerung Restmüll 1100 l",
      "quantity": "8",
      "unit": "pcs",
      "price": "38.90",
      "tax": "19%",
      "custom": { "behälter": "RM-1100-0815" }
    },
    {
      "name": "Leerung Bioabfall 240 l",
      "quantity": "8",
      "unit": "pcs",
      "price": "9.75",
      "tax": "19%",
      "modifiers": [
        { "kind": "discount", "name": "Bio-Rabatt", "amount": "10%" }
      ]
    },
    {
      "kind": "group",
      "name": "Sonderleistungen",
      "items": [
        {
          "name": "Sperrmüllabholung",
          "date": "2026-02-17",
          "price": "45.00",
          "tax": "19%"
        },
        {
          "name": "Behälterreinigung",
          "quantity": "2",
          "unit": "pcs",
          "price": "15.00",
          "tax": "19%"
        }
      ]
    },
    {
      "kind": "bundle",
      "name": "Starterpaket Gewerbe",
      "quantity": "1",
      "items": [
        { "name": "Wertstofftonne 240 l", "price": "29.00", "tax": "19%" },
        { "name": "Sortierleitfaden (Druck)", "price": "4.50", "tax": "7%" }
      ]
    }
  ],
  "modifiers": [
    { "kind": "surcharge", "name": "Energiekostenzuschlag", "amount": "2.5%" }
  ],
  "payment": {
    "method": "direct-debit",
    "direct-debit": {
      "mandate": "MND-2025-0815",
      "debtor-iban": "DE02120300000000202051"
    }
  },
  "custom": { "tarif": "Gewerbe M", "wappen": "hamburg" }
}
```

Result:

- Net 502.15 €; VAT 94.53 € (19 %) and 0.32 € (7 %); gross 597.00 €.
- The payment sentence reads "per Lastschrift eingezogen".
- The XML is valid EN 16931.
- The PDF is byte-identical to `handwritten.typ`, the same invoice written with `item`/`group`/`bundle`/`surcharge`/`payment-terms`/`direct-debit`.

### 4.5 Versioning and extension

- **SchemaVer-style evolution.** A new optional key keeps `invoice-pro/1`. A rename, a removal or a changed meaning makes it `invoice-pro/2`, and the decoder then names the migration.
- **Extension** goes only through `custom` bags. There are no `x-` keys: they break the generated pydantic and typify models (prior-art research).
- **Rules about data values stay Typst code in the skeleton.** There is no expression language and no `eval`.

## 5. API surface (all new; nothing existing changes)

```text
invoice(..existing.., custom: none, data: auto)[body]

  data:   auto | none | dictionary | bytes | str | path(0.15)
          auto/none: JSON of `--input invoice-pro-data` if given, else not hydrated.
          dictionary: parsed data (json(..), toml(..), yaml(..), or a Typst dict; Typst
                      values such as datetime, ratio, unit.*, id.*, tax.* pass through).
          bytes / str: JSON text (a str that does not start with "{" panics with the
                      one-line fix: "A package cannot open a file by its path: write
                      `data: json(\"…\")`").
  custom: none | dictionary   fields of your own; the data's `custom` adds key by key.
          Sealed in ctx (metadata): read by parts as ctx.custom (unsealed for them, like
          ctx.theme), by the body as info.get("custom", "key"), by dynamic paths.

payment(terms: none, method: auto, bank: none, creditor-id: none,
        direct-debit: none, card: none, paid: none,
        show-reference: true, qr-code: (:))
  Writes: paid(..)            if method = "paid"   (never together with terms)
          payment-terms(..terms) otherwise, if terms != none
          direct-debit(..)    if method = "direct-debit" (creditor-id + direct-debit.mandate)
          card-payment(..)    if method = "card"         (card.last4)
          bank-details(..bank, show-reference, qr-code)   only for a transfer: an invoice
                              states one payment means (BT-81, CII-SR-467: verified that
                              direct debit + bank-details fails EN 16931)
  method auto = the method whose details are given, else "transfer".
  Hydrated: the data's `payment` section applies key by key (R4). A missing mandate or
  last4 is a data issue, and that component is left out (no panic).

data-format            (namespace; for tools and tests, imported lazily)
  .version             "invoice-pro/1"
  .input-key           "invoice-pro-data"
  .schema()            -> dictionary: JSON Schema 2020-12 generated from schema.typ
  .decode(data)        -> (values, issues): what invoice() would take and report,
                          without rendering

<invoice-pro:result>   metadata emitted by root on hydrated invoices:
  (format, invoice-nr, date, currency, total: (net, gross, prepaid, due),
   taxes: ((category, rate, basis, amount), ..), issues: ((id, class, message), ..),
   e-invoice: "attached" | "withheld" | "none")   — strings only
```

Internal (no API): `src/hydration/{schema,decode,apply,input,rows,result}.typ`, plus the private `_items-slot` motif in `line-items.typ`.

Naming:

- `data` follows the prior art (invoice-maker, casoon: `data:`), and `custom` follows GOBL `meta` and Stripe `metadata`.
- The namespace is `data-format`, not `data`. A root export `data` would replace a user's `#let data = json(..)` written before `#import "…": *`, which is a (small) breaking risk.

## 6. CLI usage

```bash
# preview the skeleton (sample data)
typst compile skeleton.typ

# single invoice, inline (zero skeleton code). Linux: ≤128 KiB per argument; Windows ~32K chars total
typst compile --pdf-standard a-3b skeleton.typ out.pdf --input invoice-pro-data="$(cat inv.json)"

# single invoice from a file (skeleton has `data: if "data" in sys.inputs { json(sys.inputs.data) }`)
typst compile --root . --pdf-standard a-3b skeleton.typ out.pdf --input data=invoices/2026-0042.json
#   0.15 only: `data: path(sys.inputs.data)` also works (verified)
#   TOML/YAML: `data: toml(sys.inputs.data)` – TOML dates arrive as datetimes (verified)

# stdin (POSIX): the path resolves under --root /
cat inv.json | typst compile --root / /abs/skeleton.typ out.pdf --input data=/dev/stdin   # verified

# production: stop on any problem; reproducible default date
typst compile … --input invoice-pro-validation=strict --creation-timestamp 1767225600

# batch: one process per invoice (an e-invoice PDF carries one factur-x.xml), in parallel
ls invoices/*.json | xargs -P4 -I{} sh -c \
  'typst compile --root . --pdf-standard a-3b skeleton.typ "out/$(basename {} .json).pdf" --input data={} --input invoice-pro-validation=strict'

# results for programs
typst eval  'query(<invoice-pro:result>).first().value' --in skeleton.typ --input data=inv.json   # 0.15
typst query skeleton.typ '<invoice-pro:result>' --field value --one --input data=inv.json         # 0.14 (deprecated in 0.15)
typst query skeleton.typ '<ip-issue>' --field value --input data=inv.json   # every issue (draft level)

# the JSON Schema (no layout)
typst eval '{ import "@preview/invoice-pro:0.7.0": data-format; json.encode(data-format.schema()) }'   # 0.15
printf '#import "@preview/invoice-pro:0.7.0": data-format\n#metadata(data-format.schema())<s>' \
  | typst query - '<s>' --field value --one                                                         # 0.14
```

Measured: the schema dump through a local file is equal on 0.15 eval and 0.14 query, and the result record works on both. The two `@preview` one-liners were run only through a local file that imports the prototype `src`. The CLI can only import the published package.

0.14 vs 0.15 differences:

- `path` values work only on 0.15.
- `typst eval` exists only on 0.15; there, `query` is deprecated.
- 0.15's bundle export (one PDF per invoice in one process) is experimental. It would need the skeleton as a function and is not part of phase 1.
- Everything else is identical on 0.14.2 and 0.15.1 (all tests above ran on both).

## 7. Extensibility

### 7.1 Custom fields: where they live, who reads them

| level     | Typst API                       | data                                | stored                                                                  | read by                                                                                                              |
| :-------- | :------------------------------ | :---------------------------------- | :---------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------- |
| document  | `invoice(custom: (..))`         | `"custom": {..}` (adds key by key)  | `ctx.custom`, sealed in `metadata`                                      | parts and wraps: `ctx.custom.x` (unsealed for them); body: `info.get("custom", "x")`; `dynamic(ctx => ctx.custom.x)` |
| party     | `recipient: (.., custom: (..))` | `"recipient": {.., "custom": {..}}` | `ctx.recipient.custom` (normalised party keeps it)                      | `view.recipient.custom.x` in frame parts; `info.get("recipient", "custom", "x")`                                     |
| line item | (not in `item()` yet; see O6)   | `items[].custom`                    | the item signal, so `view.items[i].custom` and `view.entries[i].custom` | an items-table part or wrap                                                                                          |

`custom` is added to the e-invoice party-keys table as print-only (`false`). Verified: the original raises IP-KEY-01 for `recipient.custom`, the prototype does not. Keep document-level custom data in `invoice(custom:)` or the data's `custom`: that one is sealed, so its size costs nothing. A party's `custom` travels unsealed, so keep it small (theming research: 2000 unsealed entries ≈ 2.4× slower).

### 7.2 Data-dependent design (the Wappen rule)

The data carries facts: the post code inside `recipient.city`, or a selector such as `custom.wappen`. The skeleton owns the rule, as ordinary Typst code (§2). The rule runs in a `theme.custom.wrap("logo", ..)`, which swaps `options.logo.image` and calls the built-in renderer. That keeps the logo's height and its on-dark plate, and it works on all 10 presets (theming research). Images load from the user's file, because the closures are defined there.

Verified:

- Berlin arms for the preview (10115);
- Munich arms for inline data (80539);
- Hamburg arms through `custom.wappen` overriding the post-code rule.

Other places the same rule can sit:

- a frame function cell, `(ctx, view) => ..`;
- a prefixed custom part (`acme/wappen`);
- the body, via `#info.get(ctx => ..)`.

## 8. Performance

What is skipped, and how:

1. **N item motifs become ONE bulk motif.** The items slot's measure calls `slot-frames(rows, settings-of(ctx))`. It is a pure function of the decoded rows and a small, pass-independent settings dict: the locale, the sealed theme, the path, the cascades. It never takes `sys.pass` or `global`. It emits exactly the frames `item`/`group`/`bundle`/`modifier`/`prepayment` emit, through the unchanged `calculate-item-data`, `calculate-modifier` and `calculate-bundle`. loom's second pass is a Typst memo hit: 144 ms in pass 1, 1.1 ms in pass 2 for 300 rows (traced).
2. **No per-row hashing of the full ctx.** No mutator ops run per row (about 22 µs per op, about 2.4 ms per item per pass).
3. **Bulk data is sealed in the ctx.** `hydration` and `custom` travel as `metadata(..)`. Their hash is computed once, so they cost about 0 however large they are (+38 to +76 % when unsealed, per the research).
4. **Lazy imports.** The decoder, the precedence rules, the bulk rows and the result record are imported only by a hydrated invoice. The new always-loaded code (`input.typ`, `payment.typ`, the `data-format` facade) costs about 0.6 ms of package import (traced, 3 runs).
5. **Samples are not counted.** In hydration mode the sample children of `line-items` are still traversed but discarded. With 2 samples the cost is within noise (see "no samples" below).
6. **No pass skipping.** With the bulk motif, a single pass saves only 0 to 5 % more (loom research P3 ≈ P2), and it would couple the format to the skeleton.

Measurements. Wall clock, round-robin, with `--pdf-standard a-3b` and `zugferd: "en16931"` (validation and XML included), EPC QR code included. The "handwritten" baseline is the same invoice written with N `item()` calls (`bench/gen.py`). Medians of 5 runs (0.15.1) and of 3 runs (0.14.2), on a shared 4-core VM (±10 %):

| rows | 0.15.1 handwritten | 0.15.1 hydrated | 0.15.1 hydrated, no samples | 0.14.2 handwritten | 0.14.2 hydrated |
| ---: | -----------------: | --------------: | --------------------------: | -----------------: | --------------: |
|    5 |            0.517 s |  0.469 s (−9 %) |                     0.481 s |            0.500 s |  0.465 s (−7 %) |
|   50 |            1.216 s | 0.962 s (−21 %) |                     1.013 s |            1.414 s | 1.005 s (−29 %) |
|  300 |            6.324 s | 3.980 s (−37 %) |                     3.822 s |            6.082 s | 3.745 s (−38 %) |

An earlier round, with the slower decoder, gave −1 / −24 / −40 % (0.15.1) and −3 / −23 / −41 % (0.14.2). In every configuration the output is byte-identical (md5) to the handwritten PDF.

Where the hydrated 300-row compile spends its time (traced, total 4.37 s):

- layout: 2.91 s (the theme table's keep-together, 3 iterations; the next bottleneck, outside this feature);
- bulk rows: 145 ms (pass 1);
- `hydrate()`: 150 ms, traced before the decoder optimisation. Untraced it is now 108 ms (0.36 ms/row), down from 194 ms, after switching to ASCII regex classes and path-free parsers that Typst memoises.
- `payment` block: 54 ms (EPC QR draw ≈ 40 ms).

Possible next steps (not prototyped):

- a specialised item-row decoder, without the generic interpreter;
- cheaper keep-together in the table theme;
- `format-item` without `mutator.batch` (line-items research: about 10× faster in a microbenchmark).

## 9. Validation and error model

| situation                                                                                                                   | mechanism                                                                                                     | under draft               | under strict             | under none                                                                            |
| :-------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------ | :------------------------ | :----------------------- | :------------------------------------------------------------------------------------ |
| wrong type or encoding in the data (`"38,90"`, `"2026-02-30"`, numeric post code, `"0%"` tax, unknown unit object)          | `data` issue `schema/<json-path>`; the value is left out, an invalid row as a whole                           | report row + XML withheld | panic listing everything | dropped silently ("off means off"); the e-invoice rules still follow `zugferd-errors` |
| unknown key                                                                                                                 | `data` issue with did-you-mean or the e-invoice alias hint (`plz` → `city`, with a hint); `fix: custom.<key>` | ″                         | ″                        | ″                                                                                     |
| a required value missing in the data (`items[1]` without price/total, `payment.direct-debit.mandate`, `payment.card.last4`) | `data` issue; the object is left out                                                                          | ″                         | ″                        | ″                                                                                     |
| document field missing (number, recipient, …)                                                                               | the existing `check-data` rows (R2 makes them fire)                                                           | inline marker ‹fehlt: …›  | panic                    | nothing                                                                               |
| data the skeleton has no place for (`payment` without a `payment(..)` block; items without `line-items`)                    | `data` issue in root                                                                                          | report                    | panic                    | nothing                                                                               |
| JSON that does not parse                                                                                                    | Typst's own error (`json()` cannot be caught)                                                                 | hard error                | hard error               | hard error                                                                            |
| `--input invoice-pro-data=<path>` or `data: "file.json"`                                                                    | panic with the fix                                                                                            | panic                     | panic                    | panic                                                                                 |
| misuse of the Typst API (`payment(method: "cash")`, `custom: 5`)                                                            | `types.require` panic                                                                                         | panic                     | panic                    | panic                                                                                 |

Issues are injected at `invoice.typ` next to `check-data("invoice", "input", ..)`, so no new class or locale label is needed. Issue ids are unique per path, which lets the report dedupe; the payment block's issues are deduped by id against the decoder's. Messages in the house style (verified output):

```text
invoice-pro found 9 problems (validation: "strict"; preview them with validation: "draft" or --input invoice-pro-validation=draft):
  1. invoice::invoice-nr is missing; every invoice needs a unique, sequential number (§ 14 Abs. 4 Nr. 4 UStG; EN 16931 BT-1)
  2. `date` must be a date "YYYY-MM-DD", got "2026-02-30".
  3. `kunde` is not a key of the invoice data. Fields of your own go into `custom`.
  4. `recipient.plz` is not a key of the invoice data. Did you mean `city`? Write the post code into `city`, e.g. `city: "10115 Berlin"` or `city: (name: "Berlin", post-code: "10115")`. Fields of your own go into `custom`.
  5. `recipient.city.post-code` must be a text (a number would lose leading zeros), got 20457.
  6. `items[0].price` must be a decimal number such as "12.50", got "38,90".
  7. `items[1].tax` is 0%: a rate of zero needs its category, e.g. {"category": "E", "grounds": ".."}, "reverse-charge" or "zero".
  8. `items[2].unit` must be a unit name ("hour"), a code ("HUR") or {"code", "display"}, got (code: "C62", lable: "x").
  9. `payment.direct-debit.mandate` is required.
```

```text
error: panicked with: --input invoice-pro-data=data/2026-0042.json is no JSON object. A package cannot open files: read the file in your document, e.g. `invoice(data: if "data" in sys.inputs { json(sys.inputs.data) })` and pass `--input data=<path>`.
error: panicked with: The data has a `payment` section, but the skeleton has no `payment(..)` block: replace `payment-terms`/`bank-details` by `payment(terms: .., bank: ..)`.
```

The generated JSON Schema accepts `2026-0042.json`, `inline.json` and `data-300.json`. It rejects `bad.json` at 7 of the decoder's 9 places, checked with Python jsonschema 4.26, Draft 2020-12, with the format checker. The two places the schema cannot see are semantic: `"0%"` needs a category, and a field invalid for one specific reason. The Typst decoder is the authority; the schema is a necessary condition.

## 10. API change ledger

| change                                                         | file                                                         | kind                  | justification                                                                                                                                                                                                    |
| :------------------------------------------------------------- | :----------------------------------------------------------- | :-------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `invoice(data: auto)`                                          | src/invoice.typ                                              | new-parameter         | The single entry point. It must sit inside invoice(), so that check-data, the e-invoice and the frame see the data (body-only hydration gives false 'missing' issues and embeds wrong XML: validation research). |
| `invoice(custom: none)`                                        | src/invoice.typ                                              | new-parameter         | The documented home for document-level custom fields; sealed; the Typst side of the data's `custom`.                                                                                                             |
| `payment(..)` root export                                      | src/components/payment.typ, src/lib.typ, tests/theme/exports | new-export            | The payment slot: which payment components exist is data. Also a convenience for hand-written invoices.                                                                                                          |
| `data-format` root export                                      | src/public/data-format.typ                                   | new-export            | JSON Schema, decoder and version, for tools and phase 2. Lazy (no import cost).                                                                                                                                  |
| reads `--input invoice-pro-data` when `data` is auto/none      | src/hydration/input.typ                                      | behaviour-change      | Additive: only when the namespaced key is given (precedent `invoice-pro-validation`).                                                                                                                            |
| data issues joined to the input issues                         | src/invoice.typ                                              | behaviour-change      | Only for hydrated invoices; reuses the draft/strict/withholding machinery.                                                                                                                                       |
| items slot wrapper around the `line-items` body                | src/components/line-items.typ                                | internal-refactor     | Without data its measure passes the children through and its draw returns the body. Output is byte-identical (53/53 integration tests + template, md5).                                                          |
| payment-block issues, placement issues, `<invoice-pro:result>` | src/components/root.typ                                      | behaviour-change      | Only when `payment(..)` is used or the invoice is hydrated; the label is new.                                                                                                                                    |
| `custom: false` in `_address-keys` and `payee`                 | src/zugferd/model.typ                                        | behaviour-change      | A party's `custom` bag no longer raises IP-KEY-01. No other key changes.                                                                                                                                         |
| `dynamic` and `unsealed()` unseal `ctx.custom`                 | src/components/dynamic.typ, src/theming/access.typ           | new-export (contract) | Makes `ctx.custom` a public ctx key next to ctx.theme and ctx.locale. Internal mechanics only.                                                                                                                   |

No existing parameter, default, export or signal shape changes.

## 11. Phase-2 hooks

- **One schema, in Typst.** `schema.typ` declares every object, field type, requirement, precedence class and EN 16931 BT number. The decoder interprets it, so the precedence rules and the validation cannot drift. `data-format.schema()` emits JSON Schema 2020-12: closed objects, `custom` bags, `$defs`, enums, `format: date`, and amounts as `string|number` with a pattern. Bindings generate their types from it (pydantic, TypeScript and typify all handle kebab keys through aliases).
- **A stable transport contract.** One `sys.inputs` key, `invoice-pro-data`, carries one JSON document. That matches what typst-py, typst-rb and go-wasm already do (`sys_inputs: dict[str, str]`). For large data, the binding writes a file and passes `--input data=<path>`.
- **Validation without rendering.** `data-format.decode(data)` returns the issues (about 150 ms via `typst eval`, no layout). A binding can check data before a full compile.
- **A machine-readable result.** `<invoice-pro:result>` holds totals, VAT breakdown, issues and the e-invoice state, as plain strings.
- **Fixtures.** `data/2026-0042.json` plus `handwritten.typ` form a golden pair (md5-identical), the pattern for binding round-trip tests.
- **Embedders** (Rust `Library::with_inputs(Dict)`) can pass a dictionary. `resolve-data` accepts dictionary, bytes, str and path.

## 12. Prototype

Path: `<session>/exp/design-B-integrated/`.

| file                                                             | purpose                                                                                                                                               |
| :--------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `repo/src/hydration/schema.typ` (495 lines)                      | the format as data, plus the JSON Schema generator                                                                                                    |
| `repo/src/hydration/decode.typ` (635)                            | the interpreter: typed values and issues, no panics                                                                                                   |
| `repo/src/hydration/apply.typ` (79)                              | the precedence rules R2–R4, `payment-args`                                                                                                            |
| `repo/src/hydration/input.typ` (48)                              | `resolve-data` and the input key (always loaded)                                                                                                      |
| `repo/src/hydration/rows.typ` (316)                              | bulk frames for item/group/bundle/modifier/prepayment                                                                                                 |
| `repo/src/hydration/result.typ` (41)                             | `<invoice-pro:result>`                                                                                                                                |
| `repo/src/components/payment.typ` (197)                          | the payment slot (nested weave, like `eval-content`)                                                                                                  |
| `repo/src/public/data-format.typ` (27)                           | the lazy facade                                                                                                                                       |
| `src.diff`                                                       | all src changes. Existing files: invoice.typ +125, root.typ +46, line-items.typ +20/−2, access.typ +4/−1, model.typ +3/−1, dynamic.typ +3, lib.typ +2 |
| `skeleton.typ`, `handwritten.typ`, `data/*.json`, `wappen/*.svg` | the demo and the golden pair                                                                                                                          |
| `bench/gen.py`, `bench/timeit.py`, `bench/results-*.txt`         | benchmarks                                                                                                                                            |
| `invoice-data.schema.json`                                       | the generated JSON Schema                                                                                                                             |
| `verify.sh`, `verify.log`                                        | reproduces §2, §8 (md5), §9 and §11, plus the regression suite (`regress/run.sh`)                                                                     |

Results:

- The same skeleton compiles on 0.15.1 and 0.14.2 in three ways (alone, inline JSON, file), each with a valid factur-x.xml.
- Hydrated == handwritten (md5) for the full example, and for 5, 50 and 300 rows, on both compilers.
- Draft: 9 issues, XML withheld. Strict: panic listing all 9. Misuse panics with a fix.
- The JSON Schema dump is equal on 0.15 eval and 0.14 query.
- The original and the prototype `src` give equal md5 on 53 of 53 compilable integration tests and the template. The 8 others fail identically on both: tytanic-only `catch`, a missing file, a duplicate attachment.
- The exports pin test passes with `payment` and `data-format`.
- Also verified: TOML data, the 0.15 `path` value, stdin, JSON floats exact, party `custom` without IP-KEY-01, and typstyle 0.15.1 clean on all changed files.

## 13. Risks

- **The classification is a judgment.** A skeleton with a fixed recipient (monthly invoice to one customer) cannot keep it: the data must carry it. Fixed line items (a "Grundgebühr") must be in the data as well (O2 proposes an explicit slot).
- **`payment(..)` is a new composite.** Skeletons written with `payment-terms`/`bank-details` get no payment hydration. They get a clear error instead, but users must switch. The composite also encodes payment rules (one payment means, paid excludes terms), which must track the components.
- **Nested weave in `payment(..)`.** It uses `loom.core.intertwine` inside a motif (precedent: `eval-content` and item modifiers). A loom upgrade that changes intertwine or path semantics must be tested against it. In the draw pass the block weaves its components twice: once in measure, once in draw, the second mostly as memo hits.
- **Two producers of the same signals.** `rows.typ` re-implements the scope logic of `item`/`group`/`bundle`/`modifier`/`prepayment`. Cascade details can drift: a raw-ratio tax, the bundle date, the small-business override, label resolution. Mitigations: refactor the shared pure parts out of the components, and make the md5 golden pair (motif vs data) a CI test. Covered so far: items with units, taxes, dates, descriptions, item discounts, groups, a two-rate bundle and a document surcharge. Prepayments, nested bundles, `apply` cascades around `line-items`, inclusive tax mode and small business are not yet compared byte for byte.
- **Decoder speed.** 0.36 ms per row is acceptable (108 ms at 300 rows, against 2.3 s saved), but it is the largest hydration-specific cost.
- **Samples are still woven.** In hydration mode they are traversed and discarded: about 2.4 ms per sample per pass. That is noise for 2 samples, but a skeleton with 50 samples pays about 0.25 s.
- **Under `validation: none`, invalid values are dropped silently.** This follows "off means off", but a dropped row changes the totals.
- **Labels.** Schema issues show the class chip "Pflichtangabe/Required data", which is a bit off for a type error. A dedicated `strings.validation.issues.schema` key (6 languages) would fix it.
- **A data-driven Wappen** (wrap/part) sets `prints-of(..).page-content = true`, which weakens the e-invoice "is it printed" checks (theming research). A follow-up could be a `logo.image` callback or a 'decorative' flag.
- **Inline JSON is capped** by the OS: about 128 KiB per argument on Linux, about 32K characters on Windows. Files are the default for real use.
- **A new root name `payment`** can replace a user variable of that name defined before `import *`. Every new export carries this low risk.
- **Shared VM.** Measurements ran on a shared 4-core VM (±10 % per run). The relative results agree across both compilers and two rounds.

## 14. Rejected alternatives

1. **Explicit `sample(..)` markers on skeleton values.** They are one more concept, and a forgotten marker leaks a sample (an invoice number, a VAT ID) into a real invoice. The fixed classification (R2) is leak-proof with zero edits.
2. **Deep merge of parties (also as an RFC 7386 merge patch).** The sample recipient's `vat-id` survives under the data's customer name. A multi-tenant sender keeps the template's BIC next to the data's IBAN. A producer cannot know which keys to null.
3. **Presence-only override (an absent key keeps the skeleton value).** Leaks the sample `invoice-nr`/`customer-nr` when the data omits them.
4. **A separate converter, `invoice.with(..skeleton).with(..invoice-args(d))`.** It needs skeleton edits, replaces parties shallowly, and does not reach the body (items, payment). Two mechanisms to learn instead of one.
5. **In-place hydration of `payment-terms`/`bank-details`/`direct-debit`.** A component cannot create a sibling the skeleton lacks (data "card", skeleton without `card-payment`), and the logic would spread over five components.
6. **A body-level `hydrate(data)` component.** The input checks report false 'missing' issues, and schema issues neither withhold the XML nor stop strict (validation research).
7. **Skipping loom's measure pass with precomputed totals.** It adds only 0 to 5 % on top of the bulk motif, couples the format to everything totals-relevant in the skeleton, and risks a silently stale `global`.
8. **Package-side file reading (`--input invoice-pro-data=@file`).** Impossible: a package resolves paths inside itself on 0.14 and 0.15.

## Appendix A: open questions (with recommendation)

- **O1 Borderline classes.** `notes`, `subject` and `document-type` are template here, and so are the payment `terms`; `project` and `customer-nr` are document. _Recommendation:_ keep. A per-skeleton override (`hydrate: (keep: ("recipient",))`) only if users ask.
- **O2 Fixed rows next to data rows.** An explicit `items-slot()` marker inside `line-items` could mark where the data rows go and keep the rest of the body as template (a fixed fee, a fixed discount). _Recommendation:_ 0.7.x follow-up. The implicit whole-body slot covers phase 1.
- **O3 Locale from data.** _Recommendation:_ no (it is design, and customisations are closures). Later a `locales: (de: .., en: ..)` map that the data selects by name.
- **O4 Payment terms as text (BT-20).** `due-date` in data is a date only. _Recommendation:_ add `payment.terms.text` later; never reuse `due-date` for text.
- **O5 Data errors.** Keep them as `data` issues (prototype) or panic like misuse? _Recommendation:_ issues (draft previews of incomplete data; `strict` for sending), plus a localised `schema` label.
- **O6 `item(custom:)`.** _Recommendation:_ add, for preview parity with `items[].custom`, and freeze `view.items[i].custom` in the part contract.
- **O7 Names.** `data`/`custom` parameters and the `data-format` namespace; or `hydrate:`? _Recommendation:_ `data` (prior art) and `data-format`.
- **O8 Result record.** Emit it always, or only when hydrated (prototype)? _Recommendation:_ always, once measured. It is one metadata element.
- **O9 Schema `$id`.** It is a URN placeholder. Use a docs URL with a version path?
- **O10 Batch in one process.** Allow `data:` arrays or a bundle helper on 0.15? _Recommendation:_ no for phase 1; use parallel processes (3.0 s for 20 e-invoices on 4 cores, CLI research).
