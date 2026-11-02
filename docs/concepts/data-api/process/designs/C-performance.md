# Design C — "Decode once, one motif, sealed data": performance-first hydration

Status: design proposal with a working prototype (typst 0.15.1 and 0.14.2).
Prototype: `<session>/exp/design-C-performance/` — `repo/` (invoice-pro 0.6.0 +
this design), `base/` (pristine 0.6.0), `repo-nofmt/` (this design minus the
format-item refactor, to isolate effects), `repo-item/` (+ `item()` on the shared
pure resolver), `repo-x/` (+ layout experiments), `proto/` (skeletons, data,
generator, equivalence, regression and benchmark scripts; runbook in
`../README.md` of the prototype). `<session>` =
`<session>`.

## 1. Pitch

A hydrated invoice should not only look exactly like the same invoice written by
hand — it should be built faster than it. Design C gets there with four rules:

1. **Decode once, before loom.** The data document is decoded at evaluation time
   by one pure (memoized) function into Typst values; every problem becomes a
   class-`data` validation issue. Nothing is parsed inside the loom tree.
2. **Feed invoice() arguments, not ctx.** One new parameter `invoice(data:)`
   merges the decoded values into invoice()'s own arguments, so check-data, the
   draft markers, the strict panic and the e-invoice see hydrated values exactly
   like hand-written ones.
3. **One motif for all line items.** A slot `hydrate.items[sample]` in the
   skeleton's `line-items` emits — from ONE raw motif and a pure function of
   (rows, small environment) — exactly the frames N `item`/`group`/`bundle`/
   `discount`/`surcharge`/`prepayment` motifs would emit. Downstream
   (applicators, resolve-tree, line-items view, theme, ZUGFeRD) is untouched.
   Loom's second pass becomes a memo hit; the sample rows are never traversed.
4. **Never put bulk data unsealed into ctx; never load what is not used.**
   Custom fields and the decoded rows travel sealed (like the theme); the
   hydration modules are imported inside the functions that need them.

Measured on the prototype (wall-clock medians, typst 0.15.1, PDFs md5-identical
to the same invoice written by hand in every run, ZUGFeRD/XRechnung XML
included): **−46 to −55 % at 300–1000 lines (basic), −41 to −46 % for rich
e-invoices, −36 to −38 % for deeply grouped invoices, −31 to −37 % at 50
lines**; 0.14.2 the same (−44 to −48 % at 300). Two internal changes found on
the way are part of the proposal: (a) `item()` itself uses the bulk path's pure
resolver — one implementation, no drift, and hand-written invoices get
**−20 to −37 %**; (b) an exact page-count seed for layout iteration 1 removes a
full second layout of the items table of long invoices (hydrated b-300:
**−63 %**, rich e-invoice r-300: **−66 %** vs. today's hand-written invoice;
hand-written invoices −20 to −27 % from the seed alone). All byte-identical;
§8 has every number.

## 2. Workflow

1. The user designs an ordinary invoice in Typst — theme, layout, letterhead,
   rules such as a coat of arms by post code — with **sample values** where the
   data will go. It compiles and previews like any invoice.
2. Three marks make it a skeleton (each is a no-op without data):
   - `data: hydrate.input(read: p => json(p))` on `invoice()` (one line);
   - `#hydrate.items[ …sample items… ]` inside `line-items`;
   - `#payment(..)` instead of `payment-terms` + `bank-details` (only if the
     payment means vary per invoice).
3. Hydrate from the CLI: `typst compile skeleton.typ out.pdf --input
invoice-pro-data-file=data/2026-0042.json` (file) or `--input
invoice-pro-data='{…}'` (inline). Data wins over the samples; design stays.

```typst
#import "@preview/invoice-pro:0.7.0": *

// a data-dependent DESIGN rule (stays in Typst): coat of arms by post code
#let arms = ("8": "wappen/muenchen.svg", "1": "wappen/berlin.svg", "2": "wappen/hamburg.svg")
#let wappen(ctx, view, inner) = {
  let custom = ctx.at("custom", default: none)
  let chosen = if custom != none { custom.at("wappen", default: none) }
  let plz = view.recipient.at("post-code", default: none)
  let path = if chosen != none { "wappen/" + chosen + ".svg" } else if plz != none {
    arms.at(plz.first(), default: none)
  }
  if path == none { return inner(ctx, view) }
  let ctx = ctx
  ctx.theme.options.logo.image = image(path, alt: "Wappen") // opened in THIS file
  inner(ctx, view)
}

#show: invoice.with(
  data: hydrate.input(read: p => json(p)),   // ← hydration
  theme: theme.classic.with(
    theme.custom.logo(image: image("wappen/default.svg", alt: "Logo")),
    theme.custom.wrap("logo", wappen),
  ),
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (                                   // static letterhead (merged with data)
    name: "Entsorgung Süd GmbH", address: "Industriestraße 7", city: "80339 München",
    country: "DE", vat-id: "DE123456789", tax-nr: "143/123/45678",
    contact: (name: "Buchhaltung", phone: "+49 89 1234567", email: "rechnung@entsorgung-sued.example"),
  ),
  // samples — replaced by the data
  recipient: (name: "Erika Mustermann", address: "Musterweg 1", city: "10115 Berlin", country: "DE"),
  invoice-nr: "MUSTER-0001",
  date: datetime(year: 2026, month: 1, day: 15),
  custom: (tarif: "Grundversorgung (Muster)"),
)

Tarif: #info.get("custom", "tarif") \
Kundennummer: #info.customer-nr

#line-items[
  #hydrate.items[                             // ← slot: sample rows
    #item("Leerung Restmüll 120 l", quantity: 4, unit: unit.pcs, price: 12.5)
    #item("Sperrmüllabholung", price: 45)
  ]
]

#payment(                                     // ← block: means chosen by data
  terms: (days: 14),
  bank: (bank: "Musterbank", iban: "DE89370400440532013000", bic: "COBADEFFXXX"),
  creditor-id: "DE98ZZZ09999999999",
)

#signature()
```

This file is `proto/skeleton.typ`; with `data/invoice.json` it renders the
München coat of arms (post code 80331), "Tarif: Gewerbe Plus", groups, a bundle,
an exempt line, a surcharge, a prepayment and a SEPA direct debit with cash
discount, and embeds a valid EN 16931 `factur-x.xml`. Without data it renders
the samples with the Berlin arms.

## 3. Data format `invoice-pro/1`

### 3.1 Principles

| Principle                          | Rule                                                                                                                                                                 | Why (performance-first reading)                                                                                |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| One document                       | One JSON (or TOML/YAML) object per invoice.                                                                                                                          | One decode call, memoized as a whole.                                                                          |
| Names = Typst names                | Every key is the kebab-case name of an existing invoice-pro parameter or dict key (`invoice-nr`, `service-period`, `base-quantity`, `item-id`, …).                   | The decoder maps 1:1, no rename table; errors name the same path the Typst API uses.                           |
| Nested tree for line items         | `items` mirrors the body of `line-items`: groups and bundles hold `items`.                                                                                           | A tree maps directly onto the frame tree the motifs emit; the bulk function recurses once, no id/parent joins. |
| Values pre-resolvable at eval time | Money/quantities as decimal strings, percentages as `"19%"`, dates as ISO strings, units as names/codes, tax as rate or object.                                      | Everything is converted to Typst values ONCE, before weave; the per-row work inside loom is arithmetic only.   |
| Absent = default, null = none      | An absent key keeps the skeleton value (or the default); JSON `null` means `none` where `none` is meaningful; an invalid value means "not given" (never the sample). | Same semantics as Typst's auto/none; no sample leaks.                                                          |
| Closed core + named open bags      | Unknown keys are data issues with did-you-mean; free data goes into `custom` (document, line).                                                                       | Typos are caught; codegen tools model `custom` as a map.                                                       |
| Versioned                          | `"format": "invoice-pro/1"` (optional, default 1). A different major panics with an update hint.                                                                     |                                                                                                                |
| No logic in data                   | No expressions, no eval. Rules live in the skeleton.                                                                                                                 | Data stays a pure value: hashable, memoizable.                                                                 |

### 3.2 Top level

| key                                                                                                                                                       | encoding                                                                       | maps to                                |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | -------------------------------------- |
| `format`                                                                                                                                                  | `"invoice-pro/1"`                                                              | version check                          |
| `$schema`                                                                                                                                                 | string (editor hint, ignored)                                                  | —                                      |
| `invoice-nr`, `customer-nr`, `order-nr`, `project`, `contract-nr`, `quote-nr`, `delivery-note-nr`, `preceding-invoice-nr`, `payment-reference`, `subject` | string (`null` = none)                                                         | same-named invoice() params            |
| `date`                                                                                                                                                    | ISO date                                                                       | `invoice(date:)`                       |
| `service-period`                                                                                                                                          | date \| `[start, end]` \| `{start, end}`                                       | `invoice(service-period:)`             |
| `due-date`                                                                                                                                                | ISO date → BT-9; `{"text": "…"}` → payment-terms text BT-20                    | `invoice(due-date:)`                   |
| `order-date`                                                                                                                                              | ISO date \| `{"text": …}`                                                      | `invoice(order-date:)`                 |
| `preceding-invoice-date`                                                                                                                                  | ISO date                                                                       | `invoice(preceding-invoice-date:)`     |
| `currency`                                                                                                                                                | ISO 4217 string                                                                | `invoice(currency:)`                   |
| `document-type`                                                                                                                                           | `"invoice"`, `"credit-note"`, …, or UNTDID 1001 code                           | `invoice(document-type:)`              |
| `notes`                                                                                                                                                   | string \| array of string \| `{text, subject-code}`                            | `invoice(notes:)`                      |
| `tax`                                                                                                                                                     | tax (§3.5)                                                                     | `invoice(tax:)`                        |
| `tax-mode`                                                                                                                                                | `"exclusive"` \| `"inclusive"`                                                 | `invoice(tax-mode:)`                   |
| `tax-exempt-small-biz`                                                                                                                                    | bool                                                                           | `invoice(tax-exempt-small-biz:)`       |
| `sender`                                                                                                                                                  | party, **merged** key by key over the skeleton's sender (`null` removes a key) | `invoice(sender:)`                     |
| `recipient`, `delivery-address`, `payee`                                                                                                                  | party, **replaces** the skeleton's                                             | same-named params                      |
| `items`                                                                                                                                                   | array of lines (§3.4); fills the `hydrate.items` slot                          | body                                   |
| `payment`                                                                                                                                                 | payment (§3.6); fills `payment(..)`                                            | body                                   |
| `custom`                                                                                                                                                  | object, merged over `invoice(custom:)`                                         | `ctx.custom`, `info.get("custom", ..)` |

Not data (skeleton only): `theme`, `locale`, `zugferd`, `zugferd-errors`,
`validation`, `references` (layout), line-items column options, QR/show-reference
layout knobs, the signature image.

### 3.3 Parties

Keys: `name`, `address` (string or array of lines), `street`, `city` (string
`"80331 München"` or `{"post-code", "name", "state"}` — **recommended**: the
structured form gives rules the post code without parsing), `country` (ISO
alpha-2), `extra`, `vat-id`, `tax-nr`, `id`, `global-id`, `legal-id`,
`electronic-address`, `trading-name`, `legal-info`, `tax-representative`
(party), `contact` (`{name, phone, email}`), `contact-name`, `phone`, `email`,
`register`, `management`, `buyer-reference`, `leitweg-id`, `order-nr`, `po-nr`,
`contract-nr`, `delivery-note-nr`, `delivery-address` (party), `customer-nr`,
`customer-id`, `order-date`, `project`, `quote-nr`, `location-id` — exactly the
keys of `zugferd/model.typ` `party-keys`.
Identifiers (`id`, `global-id`, `legal-id`, `electronic-address`, `leitweg-id`):
string, `{"scheme": "0088", "id": "…"}`, or a single-key typed form
`{"gln" | "duns" | "siren" | "siret" | "uid-ch" | "leitweg": "…"}` /
`{"register": "HRB 4711", "court": "…"}` which goes through the `id.*`
constructors (check digits for free). All other values must be strings: a JSON
number (`"post-code": 80331`) is a data issue, not a crash in the theme.
Custom keys inside parties are NOT allowed (they collide with the e-invoice key
aliases `plz`, `mail`, … → IP-KEY-02); use `custom`.

### 3.4 Line items (`items`)

Each entry is an object with `kind` (default `"item"`):

| kind                                | keys                                                                                                                                                                                                                                                                                                     |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `item`                              | `name`\*, `description`, `quantity`, `base-quantity`, `unit`, `date` (date or period), `price` \| `total`, `input-gross`, `tax`, `item-id` (string or `{seller, buyer, standard}`), `reference`, `note`, `origin` (ISO alpha-2), `modifiers` (array of discount/surcharge/modifier, see below), `custom` |
| `group`                             | `name`_, `description`, `show-subtotal`, `tax`, `input-gross`, `date`, `unit`, `items`_                                                                                                                                                                                                                  |
| `bundle`                            | `name`_, `description`, `quantity`, `base-quantity`, `unit`, `date`, `input-gross`, `tax`, `item-id`, `reference`, `items`_ (items, bundles, discount/surcharge)                                                                                                                                         |
| `discount`, `surcharge`, `modifier` | `name`\*, `label`, `description`, `amount` (`"5%"` relative, `"5.00"` absolute; discount/surcharge positive, the kind gives the sign), `input-gross`, `tax` (pins the VAT category)                                                                                                                      |
| `prepayment`                        | `amount`\* (`"30%"` or `"1000.00"`), `name`, `label`, `date` (date or `{"text"}`), `reference`, `description`, `method`                                                                                                                                                                                  |

Placement rules (checked by the decoder, they replace the loom guards): a
prepayment only at the top level; a discount/surcharge at the top level or in a
bundle (in a group: use the item's `modifiers`); nesting at most 8 levels
(guards the silent depth-10 total bug of `calculate-modifier`).
Cascades are exactly those of the Typst components: a group's `tax`, `unit`,
`date`, `input-gross` cascade to its lines; a bundle's `item-id`/`reference`
cascade to its items; the `line-items(tax:)` of the skeleton and `invoice(tax:)`
apply to data lines as to hand-written ones.

### 3.5 Encodings

| value           | encoding                                                                                                                                                                                                                                                                                                            | decoded with                                                                               |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| money, quantity | decimal string `"12.30"` (exact); JSON integers accepted; JSON floats accepted via `decimal(str(x))` (shortest exact form, never the lossy 15-digit path)                                                                                                                                                           | `decimal-of`                                                                               |
| percentage      | `"19%"`, `"5.5%"`                                                                                                                                                                                                                                                                                                   | `float(n) / 100 * 100%` (bit-identical to the Typst literal; infer-tax compares with `==`) |
| amount          | `"5%"` relative \| `"5.00"` absolute                                                                                                                                                                                                                                                                                | `amount-of`                                                                                |
| date            | `"YYYY-MM-DD"` (TOML native dates pass through)                                                                                                                                                                                                                                                                     | regex + month/day check (no `datetime()` panic)                                            |
| period          | `["YYYY-MM-DD", "YYYY-MM-DD"]` \| `{start, end}`                                                                                                                                                                                                                                                                    | `period-of`, start ≤ end                                                                   |
| text date       | `{"text": "…"}`                                                                                                                                                                                                                                                                                                     | explicit: a bare string is always an ISO date (avoids the BT-9/BT-20 trap)                 |
| unit            | unit name of invoice-pro (`"hour"`, `"pcs"`, `"set"`, …), UN/ECE Rec 20 code (`"HUR"`, `"H87"`, `"DAY"`, … 18 codes), `{"display", "code"}`, or other text (printed verbatim)                                                                                                                                       | `unit-of`                                                                                  |
| tax             | `"19%"` (= Typst `tax: 19%`; must be a rate the locale region knows, else a data issue instead of the infer-tax panic), `"exempt"`, `"reverse-charge"`, or `{"category": "S"\|"Z"\|"E"\|"AE"\|"K"\|"G"\|"O"\|…, "rate"?, "grounds"?, "code"? (VATEX), "label"?}` built like the `tax.*` constructor of the category | `tax-of`                                                                                   |
| country         | ISO alpha-2                                                                                                                                                                                                                                                                                                         | as today                                                                                   |
| identifiers     | §3.3                                                                                                                                                                                                                                                                                                                | `id.*`                                                                                     |
| null            | `none` where meaningful (description, unit, date, item-id, reference, note, origin, label, name, method, and the optional top-level texts/dates)                                                                                                                                                                    |                                                                                            |

### 3.6 Payment

```json
"payment": {
  "terms": {"days": 14, "discount": [{"days": 7, "percent": "2%", "basis": "100.00"}]},
  "means": {"kind": "direct-debit", "mandate": "MANDAT-2026-117", "debtor-iban": "DE02…"},
  "bank": {"iban": "DE…", "bic": "…", "bank": "…", "name": "…", "reference": "…", "text": "…", "payment-amount": "…"}
}
```

- `terms`: `days` | `date` (ISO or `{"text"}`) | `discount` (cash discount
  list); `null` = no terms. Replaces the skeleton's terms.
- `means`: `"transfer"` (default) | `"direct-debit"` `{mandate, debtor-iban,
creditor-id?}` | `"card"` `{last4, holder, card-kind}` | `"paid"`
  `{method, date}`. Replaces the skeleton's means. One means per invoice (BT-81):
  the account (`bank-details`) is emitted for a transfer only (the e-invoice
  rule CII-SR-467 rejects bank-details next to a direct debit — found by the
  prototype); `paid` emits no terms (root forbids paid + terms).
- `bank`: merged over the skeleton's account (multi-tenant overrides).

### 3.7 Complete example

`proto/data/invoice.json` (renders `proto/out/skeleton-data.pdf`):

```json
{
  "$schema": "https://invoice-pro.example/schema/invoice-pro-1.json",
  "format": "invoice-pro/1",
  "invoice-nr": "2026-0042",
  "date": "2026-07-08",
  "service-period": ["2026-06-01", "2026-06-30"],
  "customer-nr": "K-10077",
  "order-nr": "PO-5531",
  "payment-reference": "RE 2026-0042",
  "notes": [
    "Vielen Dank für Ihren Auftrag.",
    { "text": "Leistungen gemäß Rahmenvertrag 2026.", "subject-code": "AAI" }
  ],
  "recipient": {
    "name": "Stadtwerke Musterhausen GmbH",
    "address": "Rathausplatz 3",
    "city": { "post-code": "80331", "name": "München" },
    "country": "DE",
    "vat-id": "DE811128135",
    "buyer-reference": "04011000-12345-06",
    "contact": {
      "name": "Frau Schmidt",
      "email": "einkauf@stadtwerke-musterhausen.example"
    }
  },
  "items": [
    {
      "kind": "group",
      "name": "Restmüll",
      "unit": "pcs",
      "items": [
        {
          "name": "Leerung Restmüll 240 l",
          "quantity": "13",
          "price": "18.40",
          "date": ["2026-06-01", "2026-06-30"],
          "item-id": { "seller": "RM-240" },
          "custom": { "behaelter": "B-1182" }
        },
        {
          "name": "Behältertausch",
          "price": "35.00",
          "modifiers": [
            { "kind": "discount", "name": "Kulanz", "amount": "50%" }
          ]
        }
      ]
    },
    {
      "kind": "group",
      "name": "Wertstoffe",
      "tax": "7%",
      "items": [
        {
          "name": "Biotonne 120 l",
          "quantity": "4",
          "unit": "pcs",
          "price": "9.90"
        }
      ]
    },
    {
      "kind": "bundle",
      "name": "Sperrmüll-Paket",
      "description": "Abholung und Entsorgung",
      "unit": "set",
      "items": [
        { "name": "Abholung", "price": "45.00" },
        {
          "name": "Entsorgung",
          "quantity": "0.8",
          "unit": "t",
          "price": "120.00"
        },
        { "kind": "discount", "name": "Paketpreis", "amount": "10.00" }
      ]
    },
    {
      "name": "Gutachten nach § 4 Nr. 21",
      "price": "80.00",
      "tax": {
        "category": "E",
        "grounds": "Steuerfrei nach § 4 Nr. 21 UStG",
        "code": "VATEX-EU-132"
      }
    },
    { "kind": "surcharge", "name": "Energiekostenzuschlag", "amount": "2%" },
    {
      "kind": "prepayment",
      "amount": "100.00",
      "name": "Abschlag Juni",
      "date": "2026-06-15"
    }
  ],
  "payment": {
    "terms": { "days": 14, "discount": [{ "days": 7, "percent": "2%" }] },
    "means": {
      "kind": "direct-debit",
      "mandate": "MANDAT-2026-117",
      "debtor-iban": "DE02120300000000202051"
    }
  },
  "custom": { "tarif": "Gewerbe Plus", "kundengruppe": "B2B" }
}
```

(Here `recipient.city.post-code` = "80331" drives the München arms; setting
`"custom": {"wappen": "hamburg"}` overrides the rule's choice.)

## 4. API surface (all additive)

### 4.1 `invoice(.., data: none, custom: none, body)` — two new parameters

```typst
/// Invoice data to hydrate this invoice with (data format "invoice-pro/1"):
/// a decoded dictionary (`json(..)`, `toml(..)`, `yaml(..)` in your document,
/// or `hydrate.input(..)`), raw JSON bytes, JSON text, or (0.15) a `path`.
/// The data wins over the arguments above (sender: field by field; other
/// parties replaced); its `items` fill `hydrate.items`, its `payment` the
/// `payment` block, its `custom` the custom fields. Problems in the data are
/// validation issues of class "data" (draft report, strict panic, withheld
/// XML), never panics.
/// -> none | dictionary | bytes | str
data: none,
/// Custom fields invoice-pro does not interpret, for parts, wraps and
/// `info.get("custom", ..)`; `custom` of the data is merged over it.
/// -> none | dictionary
custom: none,
```

Semantics, in order (src/invoice.typ, prototype lines ~205-250):

1. `data == none` → nothing changes; the hydration modules are not loaded.
2. `decode(data, region:)` (lazy import of `hydrate/decode.typ`; `region` =
   the locale's region, the `locale(..)` call is memoized) returns
   `(version, args, items, payment, custom, issues)`.
3. Precedence: for each of the 25 data parameters, a key present in
   `args` replaces the argument (`if "invoice-nr" in a { invoice-nr = a.invoice-nr }`).
   `sender` = merge(skeleton, data) key by key (`null` removes); `recipient`,
   `delivery-address`, `payee` are replaced. An invalid value was turned into
   the parameter default by the decoder ("not given"), so a sample never leaks.
   Then the existing type checks run unchanged.
4. `issues` are appended to `check-data(.., "input", ..)` (invoice.typ ~600):
   same report, same strict panic, same XML withholding.
5. `custom` and `hydration = (items, payment)` join the weave inputs only when
   given, **sealed** (`seal()` = `metadata(..)`, the theme's mechanism).

### 4.2 `hydrate` namespace (new root export, src/public/hydrate.typ)

Every member imports its implementation inside the function (lazy).

```typst
/// Line items in data form as ONE motif. Inside `line-items`, a `group` or a `bundle`.
/// - `invoice(data:)` holds `items` → those rows (the sample is never traversed);
/// - `rows:` given (rows of the data format, e.g. a CSV mapped in Typst) → those
///   rows (problems panic: they are code);
/// - otherwise → `sample`, exactly as written.
#let items(rows: auto, sample) -> content

/// CLI reader: `--input invoice-pro-data=<JSON>` (read by the package, ≤128 KiB on
/// Linux, also a structured value from a Rust embedder) or
/// `--input invoice-pro-data-file=<path>` (opened by `read`, a function written in
/// YOUR file — packages cannot open user files); `default` otherwise.
#let input(read: none, default: none, inputs: sys.inputs) -> none | dictionary

/// The decoded record (args, items, payment, custom, issues): inspection,
/// tests, preprocessing in Typst, decode-only validation without layout.
/// `region` ("de", ..) checks "19%"-style rates as invoice() does with its locale.
#let decode(data, region: none) -> dictionary

/// JSON Schema 2020-12 of the format, generated from the decoder's own tables.
#let schema() -> dictionary

#let input-key = "invoice-pro-data"
#let file-key = "invoice-pro-data-file"
```

### 4.3 `payment(..)` — new component (root export)

```typst
#let payment(
  terms: none,            // (days: 14) | (date: ..) | (discount: ..) | none
  bank: none,             // bank-details args: name, bank, iban, bic, reference, text, payment-amount
  means: "transfer",      // "transfer" | "direct-debit" | "card" | "paid" | (kind: .., ..args)
  creditor-id: none,      // the sender's creditor ID for direct debits (static)
  show-reference: true,   // layout (bank-details), never from data
  qr-code: (:),           // layout (bank-details), never from data
) -> content
```

Without data it builds exactly `payment-terms(..terms)` + the means component +
`bank-details(..bank)` (transfer only), i.e. what the user would write by hand
(byte-identical, verified). With data, `payment.terms`/`payment.means` replace
and `payment.bank` merges. It is a raw motif that builds the components in its
`measure` and weaves them in place (nested `loom.core.intertwine`), so root
collects the usual signals. Usable without any data.

### 4.4 Custom fields

- `ctx.custom` (frame parts, wraps, body parts: `unsealed()` unwraps it) and
  `info.get("custom", "tarif")` (dynamic unwraps it). A third contract key next
  to `ctx.theme`/`ctx.locale`.
- Per line: `custom` on a data item lands in the item signal and in
  `view.items[i].custom` / `view.entries[i].custom` for theme parts (verified
  with EN 16931 XML unchanged). For parity, `item(custom: none)` is proposed as
  a further additive parameter (not prototyped).

### 4.5 Machine-readable result: `<invoice-pro-result>`

Root's draw emits, for hydrated invoices (or with `--input invoice-pro-result=1`),
`metadata(..)<invoice-pro-result>` with plain strings only:

```json
{"format": "invoice-pro-result/1", "invoice-nr": "2026-0042", "currency": "EUR",
 "total": {"net": "517.44", "gross": "595.41", "due": "495.41", "prepaid": "100.00"},
 "taxes": [{"category": "S", "rate": "0.19", "basis": "395.45", "amount": "75.14"}, …],
 "lines": 5, "issues": [{"id": "data/items[1].tax", "class": "data", "message": "…"}],
 "e-invoice": {"profile": "en16931", "withheld": false}}
```

Invisible metadata: the PDF stays byte-identical to the hand-written one
(verified: all md5 comparisons in §8 include it).

### 4.6 Precedence summary

| source                          | wins over                  | rule                                                                       |
| ------------------------------- | -------------------------- | -------------------------------------------------------------------------- |
| data key present, valid         | skeleton argument / sample | replace (sender: per field)                                                |
| data key `null`                 | skeleton                   | `none` (sender: removes the field)                                         |
| data key present, invalid       | skeleton                   | parameter default ("not given") + data issue                               |
| data key absent                 | —                          | skeleton value stays (letterhead, samples of keys the data never mentions) |
| data `items`                    | `hydrate.items` sample     | replace whole list                                                         |
| data `payment.terms` / `.means` | `payment(terms:/means:)`   | replace                                                                    |
| data `payment.bank`             | `payment(bank:)`           | merge per key                                                              |
| data `custom`                   | `invoice(custom:)`         | shallow merge                                                              |

## 5. CLI (phase 1 interface)

All commands verified on the prototype (`--root ..` there because the prototype
imports `/repo/src/lib.typ`; with the published package `--root .` suffices).

```sh
# preview the skeleton with its samples
typst compile skeleton.typ out/sample.pdf

# hydrate from a FILE (any size; the path is opened by the skeleton's callback)
typst compile skeleton.typ out/2026-0042.pdf --input invoice-pro-data-file=data/2026-0042.json

# hydrate INLINE (package reads it itself; ≤ 128 KiB per argument on Linux, ~32 K chars Windows)
typst compile skeleton.typ out/i.pdf --input invoice-pro-data="$(cat data/2026-0042.json)"

# stdin (POSIX): the file callback reads /dev/stdin, needs --root /
generate-invoice | typst compile --root / --input invoice-pro-data-file=/dev/stdin /abs/skeleton.typ out.pdf

# CI / sending: data problems stop the build with every message
typst compile skeleton.typ out.pdf --input invoice-pro-data-file=x.json --input invoice-pro-validation=strict

# reproducible output (date default = today)
typst compile --creation-timestamp 1767225600 ...

# results back (totals, taxes, issues, e-invoice status) — one full compile
typst eval 'query(<invoice-pro-result>).first().value' --in skeleton.typ \
  --input invoice-pro-data-file=x.json --format json            # 0.15
typst query skeleton.typ '<invoice-pro-result>' --field value --one \
  --input invoice-pro-data-file=x.json                          # 0.14 (deprecated on 0.15)

# decode-only validation, no layout (~0.2 s): issues of a data file
typst eval 'import "@preview/invoice-pro:0.7.0": hydrate; hydrate.decode(json("x.json"), region: "de").issues.map(i => i.id)' --format json   # 0.15, 0.17 s

# the JSON Schema of the format (~0.2 s, no layout)
typst eval 'import "@preview/invoice-pro:0.7.0": hydrate; hydrate.schema()' --format json --pretty > invoice-pro-1.schema.json   # 0.15
printf '#import "@preview/invoice-pro:0.7.0": hydrate\n#metadata(hydrate.schema())<s>' | typst query - '<s>' --field value --one  # 0.14

# batch: one process per invoice (ZUGFeRD needs one PDF per invoice), 4-way parallel
ls data/*.json | xargs -P4 -I{} sh -c 'typst compile -j1 skeleton.typ "out/$(basename {} .json).pdf" --input invoice-pro-data-file={}'
```

0.14 vs 0.15: identical except (a) `typst eval` exists only on 0.15 (0.14:
`typst query`, deprecated on 0.15); (b) on 0.15 the skeleton may pass a `path`
value (`hydrate.input(read: p => path(p))`, verified) instead of the parsed
dict; (c) 0.15's experimental bundle export can write N PDFs + a results JSON
from one process (pattern documented in typst-cli research; not part of the API).
The input keys follow the package convention (`invoice-pro-` prefix, read
through an injectable `inputs: sys.inputs`, testable without `--input`).

## 6. Extensibility

### 6.1 Custom fields

| where    | data                                  | Typst access                                                                                                                     |
| -------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| document | `"custom": {"tarif": "Gewerbe Plus"}` | `invoice(custom: ..)` (hand-written samples), `info.get("custom", "tarif")` in the body, `ctx.custom.tarif` in parts/wraps/cells |
| line     | `items[i].custom`                     | `view.items[i].custom`, `view.entries[j].custom` (items-table replacement parts, hooks)                                          |
| party    | not allowed (IP-KEY aliases)          | put it into document `custom`                                                                                                    |

Sealed in ctx (metadata), so a 2000-entry custom bag costs the same as none
(measured by the theming research: 3.3 s → 3.2–3.8 s sealed vs 7.7–8.5 s unsealed).

### 6.2 Data-dependent design ("Wappen by PLZ")

The rule is design and stays in the skeleton; the data supplies facts. Three
equivalent hooks, all draw-time, none adds a loom pass:

- **wrap of a built-in part** (shown in §2; portable over all 10 presets):
  reads `view.recipient.post-code` and/or `ctx.custom.wappen`;
- **custom part / function cell** in an area (`theme.custom.part("acme/wappen", ..)`);
- **body**: `#info.get(ctx => ..)` or plain Typst on the decoded dict at eval time
  (`#let d = hydrate.input(..)` then `data: d` and `#if d.custom.vip [..]`) — the
  eval-time form costs nothing inside loom at all.

Images are opened in the skeleton (closures defined there resolve paths against
the skeleton, verified). Caveat inherited from today: a data-driven wrap/part
sets `prints-of(..).page-content = true`, which turns two e-invoice
"is it printed" checks into "unknown" (see risks).

### 6.3 New fields later

New optional keys are an ADDITION (format stays `invoice-pro/1`); renames or
removals bump the major. Because the decoder, the JSON Schema and the docs table
come from the same Typst tables (`hydrate/decode.typ`), adding a key is one
table row plus its conversion.

## 7. Validation and error model

| kind of problem                                    | example                                                                                                                                        | handling                                                                                                                                                              |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| misuse in the skeleton (Typst code)                | `invoice(data: 42)`, `data: "invoice.json"` (a path string)                                                                                    | panic with `invoice::data` path and fix (`a string is JSON text, not a path: a package cannot open your files. Read the file in your document …`)                     |
| unknown data format major                          | `"format": "invoice-pro/2"`                                                                                                                    | panic: update invoice-pro or write format 1                                                                                                                           |
| explicit rows in Typst (`hydrate.items(rows: ..)`) | bad row                                                                                                                                        | panic (it is code) with the same messages                                                                                                                             |
| data problem                                       | wrong type, bad encoding, unknown key, unknown kind, missing name, unknown VAT rate for the region, sign of a discount, nesting > 8, placement | issue `id: "data/<path>"`, class `data`, ref "invoice-pro data format 1", key `data-type` / `data-unknown-key` / `data-missing`; the value is dropped (→ "not given") |
| missing legally required data                      | no invoice-nr in skeleton nor data                                                                                                             | existing check-data issues (inline markers etc.)                                                                                                                      |
| e-invoice rule                                     | BR-02, CII-SR-467                                                                                                                              | existing `zugferd-errors` handling                                                                                                                                    |

Levels (verified with `proto/validate.typ` + `data/bad.json`, 12 problems):

- **draft**: badge "ENTWURF · 12 Probleme · keine E-Rechnung", report page
  listing every `data/…` issue, XML withheld (`pdfdetach -list` → 0 files);
- **strict**: compile stops with all 12 messages;
- **none**: compiles; invalid values are dropped to "not given" (never to the
  sample: `invoice-nr: 42` does not resurrect `"SAMPLE-1"`), e-invoice rules
  still follow `zugferd-errors` (here BR-02 stops it — "off means off" for the
  invoice-pro checks only).

Strict output (verbatim):

```text
error: panicked with: invoice-pro found 12 problems (validation: "strict"; preview them with validation: "draft" or --input invoice-pro-validation=draft):
  1. invoice data `itmes`: unknown key `itmes`. Did you mean `items`? Custom fields go into `custom`.
  2. invoice data `invoice-nr`: expected a string; got 42.
  3. invoice data `date`: expected an ISO date "YYYY-MM-DD"; got "08.07.2026".
  4. invoice data `recipient.plz`: unknown key `plz`. Custom fields go into `custom`.
  5. invoice data `recipient.city.post-code`: expected a string; got 80331 (write numbers such as post codes as strings: "01067").
  6. invoice data `items[0].price`: expected a decimal string such as "12.30"; got "12,50".
  7. invoice data `items[1].tax`: 16% is no VAT rate of region `de` (19%, 7%); for another rate write {"category": "S", "rate": "16%"}.
  8. invoice data `items[2].kind`: unknown kind "grop". Did you mean `group`?
  9. invoice data `items[3].name`: a item needs a `name` (a string).
  10. invoice data `items[4].amount`: a discount amount is positive (the kind gives the sign).
  11. invoice data `items[5].discout`: unknown key `discout`. Custom fields go into `custom`.
  12. invoice data `payment.terms.days`: expected an integer; got "14".
```

Why issues and not panics for data: a batch job must get a PDF (draft) or a
complete error list (strict), never a crash at the first bad value deep in a
theme (`sender.vat-id: 123` crashes frame.typ today). The decoder pre-validates
everything that would otherwise panic later: decimal strings (`decimal("12,50")`
aborts), dates (`datetime()` aborts on 2026-02-30), VAT rates (the region's
`infer-tax` panics on 16 % and 0 %), numbers in text fields.
The same decoder runs on 0.14 and 0.15 (no 0.15-only functions).
The JSON Schema (§9) catches 10 of the 12 problems before Typst runs (the region
rate and the sign rule are semantic).

## 8. Performance

### 8.1 Which loom (and other) steps are skipped, and how

| #   | step in today's hand-written invoice                                                                                                                                                       | design C                                                                         | mechanism                                                                                                                                                                                                                                             | output                                              |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| 1   | N `item` motifs: per item a scope of ~20 `loom.mutator` ops (each a memoized closure call hashing the full ctx, ~22 µs), a measure, a frame; groups/bundles/modifiers/prepayments likewise | **skipped**: one raw motif per slot                                              | `items-slot` measure = `compute(rows, env)` emitting the same frames (kinds item/group/bundle/modifier/prepayment); the scopes' cascade is replayed on a small dict; `calculate-item-data`, `calculate-modifier`, `calculate-bundle` called unchanged | byte-identical                                      |
| 2   | loom pass 2 recomputes every scope/measure (ctx differs: `sys.pass`, `global`)                                                                                                             | **memo hit**                                                                     | `compute` takes only `(rows, env)`; `env` = cascade subset + lite locale + style + path, identical in both passes                                                                                                                                     | identical                                           |
| 3   | per-row hashing of the locale (215 leaves) in unit resolution                                                                                                                              | **avoided**                                                                      | the locale is passed sealed (`metadata`) into a per-(unit, quantity) memoized helper                                                                                                                                                                  | identical                                           |
| 4   | content modifiers on items (`modifier: discount(..)`) → one nested `intertwine` per item                                                                                                   | **skipped**                                                                      | data modifiers are decoded dicts; the signal is computed directly                                                                                                                                                                                     | identical                                           |
| 5   | sample rows of the skeleton                                                                                                                                                                | **never traversed** when data is present                                         | the sample is held in the motif's closure, not as its body; woven only without data                                                                                                                                                                   | —                                                   |
| 6   | parsing strings (decimal/date/percent/unit/tax)                                                                                                                                            | **once, at eval time**                                                           | `decode` is pure and memoized; the bulk compute does arithmetic only                                                                                                                                                                                  | —                                                   |
| 7   | bulk data in ctx (hashed per closure call)                                                                                                                                                 | **sealed**                                                                       | `custom` and `hydration` travel as `metadata(..)` like the theme                                                                                                                                                                                      | —                                                   |
| 8   | `format-item` in line-items measure: `loom.mutator.batch` per entry (~20 ops)                                                                                                              | **plain dict construction** (internal refactor, helps hand-written invoices too) | same keys, same order (`base + patch` semantics)                                                                                                                                                                                                      | byte-identical (also for hand-written, all configs) |
| 9   | loading the hydration code                                                                                                                                                                 | **lazy**                                                                         | every `hydrate.*` member and `payment` import their module inside the function; invoices without data load nothing new                                                                                                                                | —                                                   |
| 10  | loom pass 1 (measure)                                                                                                                                                                      | **kept** (deliberately)                                                          | see 8.4                                                                                                                                                                                                                                               | —                                                   |
| 11  | layout iteration 2 re-laying out the whole body of a long invoice                                                                                                                          | **memo hit** (internal frame change)                                             | exact multi-page seed for iteration 1 (8.5)                                                                                                                                                                                                           | byte-identical                                      |
| 12  | keep-together `fits()` measurement per entry and iteration                                                                                                                                 | paid once instead of twice (via 11)                                              | a cheaper pre-check is a theme decision (open question)                                                                                                                                                                                               | —                                                   |

### 8.2 Wall clock: hydrated vs. the same invoice written by hand

Round-robin, alternating order, untraced `typst compile`, medians (min–max) in
seconds, shared 4-core VM (±10 % run-to-run). Variants:
**B** = pristine invoice-pro 0.6.0, invoice written by hand (`proto/hand/*.typ`,
the baseline); **H** = design C tree, same hand-written file; **D0** = design C
without the format-item refactor, skeleton + data; **D** = design C, skeleton +
data (`proto/skeleton-bench.typ` + `proto/data/*.json`). Kinds: **b** basic
(tools/perf b), **r** rich (gross prices, 3 VAT categories, item discounts every
5th line, document discount, surcharge, prepayment; with ZUGFeRD auto =
XRechnung), **t** tree (groups of 10 with subtotals, every 3rd group with a
2-VAT bundle and bundle discount, item ids, notes, origins, dates, per-group VAT
and units, document discount, relative prepayment). md5 of every PDF of a row
compared: **identical in all 16 rows** (incl. the embedded XML for `auto`).
Raw data: `proto/bench/wall.json`; script `proto/bench/run.py`.

| config             | runs | B                   | H                   | D0                  | D                   | H/B  | D0/B  | D/B   | md5       |
| ------------------ | ---- | ------------------- | ------------------- | ------------------- | ------------------- | ---- | ----- | ----- | --------- |
| 0.15.1:b-5-none    | 5    | 0.46 (0.42–0.48)    | 0.43 (0.39–0.51)    | 0.42 (0.36–0.43)    | 0.38 (0.37–0.46)    | -6 % | -8 %  | -16 % | identical |
| 0.15.1:r-5-auto    | 5    | 0.53 (0.49–0.58)    | 0.57 (0.50–0.62)    | 0.47 (0.44–0.64)    | 0.44 (0.44–0.61)    | +8 % | -11 % | -17 % | identical |
| 0.15.1:t-5-none    | 5    | 0.56 (0.53–0.73)    | 0.55 (0.52–0.63)    | 0.58 (0.54–0.68)    | 0.58 (0.47–0.74)    | -2 % | +3 %  | +3 %  | identical |
| 0.15.1:b-50-none   | 5    | 1.13 (1.12–1.25)    | 1.17 (1.09–1.22)    | 0.80 (0.74–0.85)    | 0.78 (0.76–0.86)    | +3 % | -29 % | -31 % | identical |
| 0.15.1:r-50-auto   | 5    | 1.43 (1.36–1.49)    | 1.40 (1.31–1.58)    | 0.98 (0.94–1.05)    | 0.90 (0.87–0.96)    | -2 % | -31 % | -37 % | identical |
| 0.15.1:t-50-none   | 5    | 1.47 (1.35–1.52)    | 1.39 (1.38–1.49)    | 1.04 (0.98–1.19)    | 0.97 (0.91–1.20)    | -5 % | -29 % | -34 % | identical |
| 0.15.1:b-300-none  | 5    | 5.74 (5.21–6.13)    | 5.80 (5.30–6.15)    | 3.24 (3.02–3.43)    | 2.82 (2.69–2.97)    | +1 % | -44 % | -51 % | identical |
| 0.15.1:b-300-auto  | 5    | 5.96 (5.75–6.27)    | 5.72 (5.13–6.27)    | 3.25 (3.14–3.64)    | 3.23 (2.94–3.49)    | -4 % | -46 % | -46 % | identical |
| 0.15.1:r-300-auto  | 5    | 7.41 (6.92–8.09)    | 7.32 (7.10–7.59)    | 4.39 (4.33–5.10)    | 4.30 (4.23–4.94)    | -1 % | -41 % | -42 % | identical |
| 0.15.1:t-300-none  | 5    | 6.81 (6.28–7.21)    | 6.68 (6.42–7.46)    | 4.83 (4.22–4.99)    | 4.34 (4.08–5.10)    | -2 % | -29 % | -36 % | identical |
| 0.14.2:b-300-none  | 5    | 5.39 (5.24–5.76)    | 5.21 (5.01–5.37)    | 3.19 (3.02–3.22)    | 2.88 (2.78–2.99)    | -3 % | -41 % | -47 % | identical |
| 0.14.2:r-300-auto  | 5    | 6.87 (6.59–7.15)    | 7.14 (6.67–7.28)    | 4.25 (3.98–4.45)    | 3.87 (3.61–4.25)    | +4 % | -38 % | -44 % | identical |
| 0.14.2:t-300-none  | 5    | 7.43 (7.06–7.62)    | 6.91 (6.50–7.25)    | 4.57 (4.47–4.68)    | 4.18 (3.98–4.42)    | -7 % | -38 % | -44 % | identical |
| 0.15.1:b-1000-none | 3    | 20.45 (19.17–21.35) | 19.35 (18.65–19.42) | 10.27 (10.25–10.48) | 9.12 (9.04–9.82)    | -5 % | -50 % | -55 % | identical |
| 0.15.1:r-1000-auto | 3    | 25.52 (25.13–27.61) | 25.66 (24.84–25.99) | 15.41 (14.70–16.83) | 14.30 (14.23–15.09) | +1 % | -40 % | -44 % | identical |
| 0.15.1:t-1000-none | 3    | 29.13 (28.44–29.84) | 27.88 (27.71–30.00) | 19.53 (19.52–19.73) | 18.20 (17.80–18.74) | -4 % | -33 % | -38 % | identical |

Reading: the hydrated path halves a 300- and 1000-line basic invoice
(−51 %, −55 %), takes −42 to −46 % off the rich/e-invoice ones and −36 to
−38 % off the tree kind; −31 to −37 % at 50 lines; at 5 lines it is −16 % /
−17 % for b and r and within noise (+3 %) for t (fixed costs, see 8.3). 0.14.2
behaves the same (−44 to −47 % at 300). The format-item refactor alone is worth
0.1–0.5 s on hydrated invoices (D0 → D) and is not measurable on hand-written
ones (H ≈ B: per-item motifs dominate there).

### 8.3 Where the time goes now (traced, 0.15.1, b-300-none, one `--timings` run each)

| phase (ms)                                 | B: hand-written, 0.6.0 |     D: hydrated, design C | H2: hand-written, item() on the shared resolver |
| ------------------------------------------ | ---------------------: | ------------------------: | ----------------------------------------------: |
| total (traced)                             |                   5613 |                      2619 |                                            3741 |
| import lib.typ                             |                    121 |                       145 |                                             131 |
| hydrate modules (eval, lazy)               |                      — |                         2 |                                               — |
| weave                                      |               **3108** |                   **462** |                                            1182 |
| · measure pass                             |                   1742 |                       330 |                                             742 |
| · draw pass                                |                   1366 |                       132 |                                             439 |
| · item motifs (item.typ)                   |                   2258 | 2 (samples not traversed) |                                             577 |
| · decode (eval time, before weave)         |                      — |                        26 |                                               — |
| · bulk compute (items.typ, both passes)    |                      — |                       110 |                                               — |
| layout                                     |                   2057 |                  **1889** |                                            2163 |
| · iteration 1 / 2 / 3                      |         983 / 991 / 83 |            956 / 890 / 44 |                                 961 / 1152 / 49 |
| · items table `fits()` measure, iter 1 / 2 |              395 / 372 |                 394 / 333 |                                       359 / 462 |
| · items table layout callback, iter 1 / 2  |              889 / 726 |                 853 / 659 |                                       870 / 907 |
| pdf                                        |                     75 |                        48 |                                              56 |

Weave shrinks by 85 % (3.1 s → 0.46 s); decode costs 26 ms for 300 rows. The
compile is now **72 % layout**, and within layout the items table is laid out
TWICE in full (iterations 1 and 2 get no memo hits; iteration 3 does). Traces
inflate closure-heavy code, so the shares are indicative; the wall-clock table
above is the reference. Script: `proto/trace/phase.py`.

### 8.4 Why the measure pass is NOT skipped (single pass rejected)

Skipping loom's measure pass (`weave(max-passes: 1)` with a precomputed
`global` = total, formatted total, bank, payment means) is possible and
output-identical (loom research P1/P3/P4: the totals can be computed exactly
from data before weave). Design C does not do it, for three measured reasons:

1. **It buys almost nothing once lines are bulk.** With the bulk motif the
   second pass is a memo hit; loom research measured bulk+1-pass (P3) vs
   bulk+2-pass (P2) within noise (b-300: 3.01 vs 3.07 s; r-300-zf 4.30 vs
   4.41 s; b-50: 0.83 vs 0.81 s). In this prototype's trace the whole measure
   pass of a hydrated 300-line invoice is 330 ms (§8.3) — an upper
   bound that a single pass could not reach, because the draw pass then runs cold.
2. **It couples the format to the skeleton.** Static skeleton items,
   `line-items(tax:)`, skeleton discounts, `apply` cascades and the bank details
   that decide the payment means would all have to be reproduced by a
   pre-weave computation (two code paths for totals).
3. **A stale global is silent.** A wrong precomputed total changes the payment
   sentence and the EPC-QR amount without any error.

The format stays pass-agnostic: if loom ever offers a skip-measure mode
(injector declares completeness), the decoder already has everything at eval
time.

### 8.5 The next bottleneck: layout (items table, iteration 2)

After the bulk path, layout is ~72 % of a hydrated 300-line compile. Two
findings, both verified on the prototype (`repo-x/`, experiment switches via
`--input`, PDFs md5-identical to the normal run):

**(a) Iteration 2 lays out the whole body again — because of the page-count
guess of iteration 1.** `theming/frame.typ` sizes the computed bottom margin
for a one-page footer when the invoice has ≤ 1 page (`invoice-pages() <= 1`,
no "Seite x von n" folio), and `invoice-span` answers `(first: 1, last: 1)` in
the first layout pass (no locations yet). So every multi-page invoice is laid
out once with the wrong (smaller) bottom margin, iteration 2 sees the real page
count, the margin grows, the body region changes and the items table (incl.
all `fits()` measurements) is laid out a second time; iteration 3 only
confirms. Seeding the first pass with "several pages" (`--input
ip-guess=multi` in repo-x) makes iteration 2 a memo hit:

| b-300 hydrated, traced     |   layout | iter 1 |  iter 2 | iter 3 | fits() iter 2 |    total |
| -------------------------- | -------: | -----: | ------: | -----: | ------------: | -------: |
| design C                   |     1889 |    956 |     890 |     44 |           333 |     2619 |
| design C + multi-page seed | **1224** |    983 | **241** |      — |       **1.9** | **1978** |

Wall clock (median of 3, round-robin; B = hand-written on 0.6.0, D = hydrated
design C, DG = + multi-page seed, DGX = + seed + fits() skipped; all PDFs
md5-identical; `proto/bench/layout2.json`):

| config             | runs | B                   | D                  | DG               | DGX              | D/B   | DG/B  | DGX/B | md5       |
| ------------------ | ---- | ------------------- | ------------------ | ---------------- | ---------------- | ----- | ----- | ----- | --------- |
| 0.15.1:b-300-none  | 3    | 5.40 (5.37–5.45)    | 2.87 (2.58–3.35)   | 1.97 (1.96–2.32) | 1.59 (1.56–1.77) | -47 % | -63 % | -71 % | identical |
| 0.15.1:t-300-none  | 3    | 7.19 (6.82–7.89)    | 4.20 (4.07–4.20)   | 2.99 (2.80–3.51) | 2.37 (2.18–2.42) | -42 % | -58 % | -67 % | identical |
| 0.15.1:r-300-auto  | 3    | 6.98 (6.71–7.37)    | 4.11 (3.69–4.23)   | 2.81 (2.68–2.82) | 2.28 (2.15–2.30) | -41 % | -60 % | -67 % | identical |
| 0.15.1:b-1000-none | 3    | 19.17 (17.81–20.13) | 10.27 (8.89–11.43) | 7.44 (6.89–8.30) | 5.60 (5.46–6.13) | -46 % | -61 % | -71 % | identical |

A blind "multi" seed could change the fixed point of a borderline invoice
(fits on one page with the small margin, not with the large one), so the
proposal is an EXACT seed, prototyped in `repo-x/src/theming/frame.typ`
(`--input ip-guess=exact`): every entry of the items table takes at least one
line of body text, so when `items.len() × height(one body line) > paper height`
a one-page invoice is impossible, and only then the first pass starts with the
multi-page margin (unique fixed point → same result). The frame knows the item
count in root's draw for every invoice, so this is an internal frame change that
helps hand-written invoices equally; it is independent of the data format.
Measured (median of 3; D = hydrated design C, DE = + exact seed, HE =
hand-written on the same tree + exact seed; all md5-identical; it does not
trigger below ~70 lines, by design):

| config            | runs | B                | D                | DE               | HE               | D/B   | DE/B  | HE/B  | md5       |
| ----------------- | ---- | ---------------- | ---------------- | ---------------- | ---------------- | ----- | ----- | ----- | --------- |
| 0.15.1:b-5-none   | 3    | 0.45 (0.44–0.46) | 0.42 (0.40–0.44) | 0.43 (0.39–0.46) | 0.42 (0.41–0.46) | -7 %  | -5 %  | -7 %  | identical |
| 0.15.1:t-5-none   | 3    | 0.58 (0.55–0.62) | 0.51 (0.46–0.61) | 0.48 (0.47–0.55) | 0.51 (0.49–0.51) | -12 % | -17 % | -11 % | identical |
| 0.15.1:b-50-none  | 3    | 1.26 (1.09–1.26) | 0.77 (0.69–0.85) | 0.80 (0.70–0.81) | 1.20 (1.20–1.28) | -38 % | -37 % | -4 %  | identical |
| 0.15.1:b-300-none | 3    | 5.97 (5.37–6.65) | 2.96 (2.80–3.22) | 2.23 (2.03–2.23) | 4.73 (4.40–4.98) | -50 % | -63 % | -21 % | identical |
| 0.15.1:r-300-auto | 3    | 7.73 (7.34–7.95) | 3.85 (3.67–3.97) | 2.66 (2.64–3.07) | 5.68 (5.66–5.84) | -50 % | -66 % | -27 % | identical |
| 0.15.1:t-300-none | 3    | 7.01 (6.72–7.39) | 4.10 (3.93–4.17) | 3.09 (2.84–3.19) | 5.63 (5.39–5.65) | -42 % | -56 % | -20 % | identical |

**(b) keep-together's `fits()` measurement** costs 23–34 % of a hydrated
300-line compile (skip experiment `ip-fits=skip`, identical PDFs because every
entry fits):

| config     | design C | fits() skipped |  gain | md5       |
| ---------- | -------: | -------------: | ----: | --------- |
| b-300-none |     2.68 |           2.06 | −23 % | identical |
| t-300-none |     4.08 |           2.69 | −34 % | identical |
| r-300-auto |     3.66 |           2.71 | −26 % | identical |

No data-path-specific shortcut is exact here: the decision needs the rendered
height (fonts, column width, wrapping), which is design. With (a) the
measurement is paid once instead of twice; a cheaper pre-check (e.g. one
`measure` per distinct row _shape_, or a theme option `keep-together: auto` that
measures only entries with descriptions/modifiers) is a theme decision and
listed as an open question.

### 8.6 One resolver for both paths: hand-written `item()` gets faster too

`repo-item/` moves the pure functions of the bulk path into
`src/logic/line-signal.typ` and rewrites `item()` as a data motif whose
`measure` calls the same `item-signal(env-of(ctx), .., row)` — no
`loom.mutator` scope at all. Equivalence: byte-identical PDFs for b/r/t at 5
and 50 lines (zf auto), the edge cases (§10) and the benchmark rows below.
Result (H2 = hand-written invoice on repo-item, D2 = hydrated on repo-item):

| config            | runs | B                | H                | H2               | D2               | H/B  | H2/B  | D2/B  | md5       |
| ----------------- | ---- | ---------------- | ---------------- | ---------------- | ---------------- | ---- | ----- | ----- | --------- |
| 0.15.1:b-5-none   | 3    | 0.42 (0.41–0.42) | 0.40 (0.38–0.43) | 0.37 (0.36–0.38) | 0.36 (0.34–0.41) | -3 % | -11 % | -14 % | identical |
| 0.15.1:b-50-none  | 3    | 1.09 (1.08–1.13) | 1.13 (1.07–1.15) | 0.86 (0.86–0.89) | 0.73 (0.68–0.84) | +4 % | -20 % | -32 % | identical |
| 0.15.1:b-300-none | 3    | 5.37 (5.27–5.64) | 5.23 (5.23–5.58) | 3.40 (3.39–3.55) | 2.56 (2.51–2.65) | -3 % | -37 % | -52 % | identical |
| 0.15.1:r-300-auto | 3    | 6.77 (6.48–6.98) | 6.68 (6.62–7.14) | 4.65 (4.41–4.74) | 3.68 (3.60–3.79) | -1 % | -31 % | -46 % | identical |
| 0.15.1:t-300-none | 3    | 6.56 (6.34–7.02) | 6.53 (5.98–6.67) | 5.18 (5.07–5.66) | 4.19 (3.93–4.20) | -0 % | -21 % | -36 % | identical |

0.14.2 b-300: B 5.54 s → H2 3.67 s (−34 %) → D2 2.88 s (−48 %).

So the design removes the drift risk (one implementation of the item cascade)
AND gives every existing invoice a third of the hydrated path's gain, without
any API change. The remaining gap H2 → D2 is the per-item motif overhead that
only the bulk motif removes (one loom node instead of N).

### 8.7 Summary of the levers (b-300-none, 0.15.1, wall clock medians)

| stack                                                               |       seconds |      vs. hand-written 0.6.0 | output         |
| ------------------------------------------------------------------- | ------------: | --------------------------: | -------------- |
| hand-written, invoice-pro 0.6.0 (B)                                 |       5.4–5.7 |                           — | reference      |
| hand-written, `item()` on the shared resolver (H2)                  |          3.40 |                       −37 % | identical      |
| **hydrated, design C (D)**                                          | **2.56–2.87** |            **−47 to −52 %** | identical      |
| hydrated + blind multi-page seed (DG, experiment)                   |          1.97 |                       −63 % | identical      |
| hydrated + EXACT multi-page seed in the frame (DE)                  |          2.23 | −63 % (vs 5.97 in that run) | identical      |
| hydrated + seed + no keep-together measurement (DGX, design change) |          1.59 |                       −71 % | identical here |

The first three rows are this design (API additions + internal refactors);
the seed is a recommended internal frame change that helps every multi-page
invoice; the last row is only an upper bound for a theme decision.

## 9. Phase-2 hooks (native bindings made easy)

1. **One wire contract**: one JSON document per invoice, handed over as
   `--input invoice-pro-data=<JSON>` or `--input invoice-pro-data-file=<path>`,
   or — for embedders using typst as a library — as a structured `sys.inputs`
   value (`hydrate.input` accepts a dictionary there too). typst-py/-rb/-go pass
   `dict[str, str]`: `json.dumps(model)` is the whole binding protocol.
2. **JSON Schema 2020-12 generated from the decoder's tables**
   (`hydrate.schema()`, `proto/schema/invoice-pro-1.schema.json`, 27 KB): closed
   objects, named `custom` maps, `kind` discriminators with `const`, `$defs` for
   decimal/percent/date/period/unit/tax/identifier — the codegen-friendly shape
   the prior-art research verified for TS/pydantic/typify. The schema cannot
   drift from the decoder (same source); a CI test validates the fixtures with
   both (prototype: Python `jsonschema` 4.26 accepts invoice/smoke/b/r/t data,
   flags 10 of bad.json's 12 problems).
3. **Stable error ids** `data/<path>` (`data/items[3].price`) — bindings map
   them back onto their model fields; `<invoice-pro-result>.issues` carries them.
4. **Result contract** `<invoice-pro-result>` (`invoice-pro-result/1`): totals,
   taxes, issues, e-invoice status as plain strings (no Typst reprs) — the
   binding's return value; readable with `typst eval`/`typst query`.
5. **Decode-only pre-flight** without layout: `hydrate.decode(..).issues`
   (0.17 s via `typst eval` on 0.15) — a binding can validate before rendering.
6. **Fast path is the default path**: bindings that generate 1000-line invoices
   get the bulk motif without doing anything special.
7. **Generated fixtures + byte-identity test** (`proto/gen/gen.py`,
   `proto/eq.sh`): the same invoice as data and as hand-written Typst, md5
   compared — the conformance test a binding author (or CI) can run.

## 10. Prototype — what it proves

Files (all under `<session>/exp/design-C-performance/`):

| file                                                                                            | content                                                                                                                                                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `repo/src/hydrate/decode.typ`                                                                   | decoder: encodings, tables, issues, party/payment/items, region rates (≈740 lines, mostly messages)                                                                                                                                                                                                  |
| `repo/src/hydrate/items.typ`                                                                    | bulk motif `items-slot` + pure `compute(rows, env)` replaying the item/group/bundle/modifier/prepayment scopes (≈330 lines)                                                                                                                                                                          |
| `repo/src/hydrate/payment.typ`                                                                  | `payment(..)` block (≈100 lines)                                                                                                                                                                                                                                                                     |
| `repo/src/hydrate/schema.typ`                                                                   | JSON Schema generator                                                                                                                                                                                                                                                                                |
| `repo/src/public/hydrate.typ`                                                                   | lazy facade (`items`, `input`, `decode`, `schema`)                                                                                                                                                                                                                                                   |
| `repo/src/invoice.typ`                                                                          | `data:`, `custom:`, merge, issues, sealed ctx keys                                                                                                                                                                                                                                                   |
| `repo/src/components/line-items.typ`                                                            | format-item as plain dict construction                                                                                                                                                                                                                                                               |
| `repo/src/components/root.typ`                                                                  | `<invoice-pro-result>`                                                                                                                                                                                                                                                                               |
| `repo/src/theming/access.typ`, `components/dynamic.typ`                                         | unseal `custom`                                                                                                                                                                                                                                                                                      |
| `proto/skeleton.typ`, `proto/data/invoice.json`                                                 | showcase: Wappen by PLZ, custom, groups, bundle, exempt, surcharge, prepayment, direct debit, EN 16931                                                                                                                                                                                               |
| `proto/skeleton-bench.typ`, `proto/hand/*.typ`, `proto/data/{b,r,t}-*.json`, `proto/gen/gen.py` | benchmark/equivalence pairs                                                                                                                                                                                                                                                                          |
| `proto/eq.sh`, `proto/bench/run.py`, `proto/bench/wall.json`                                    | equivalence matrix, round-robin benchmark + raw data                                                                                                                                                                                                                                                 |
| `proto/validate.typ`, `proto/data/bad.json`                                                     | error model                                                                                                                                                                                                                                                                                          |
| `proto/toml.typ`, `proto/path15.typ`, `proto/stdin.typ`                                         | TOML, 0.15 path, stdin                                                                                                                                                                                                                                                                               |
| `proto/edge-*.typ`, `proto/data/edge*.json`                                                     | edge cases: `apply` cascade around the slot, static rows before/after data rows, `line-items(tax: 19%)`, nested bundles, `total`, `base-quantity`, gross input, `unit: null`, group date/unit cascades, `modifier` kind, pinned discount, relative prepayment, small business (AT) in inclusive mode |
| `repo-item/` (+ `src/logic/line-signal.typ`)                                                    | `item()` measured through the shared pure resolver                                                                                                                                                                                                                                                   |
| `repo-x/`                                                                                       | layout experiments: `--input ip-guess=multi` (page-count seed), `--input ip-fits=skip`                                                                                                                                                                                                               |
| `proto/regress.sh`                                                                              | the repo's 313 test documents compiled against base / repo / repo-item, rendered pages compared                                                                                                                                                                                                      |
| `proto/trace/phase.py`, `proto/trace/*.json`                                                    | phase breakdown of `--timings` traces                                                                                                                                                                                                                                                                |

What it proves:

1. A JSON data document hydrates a hand-designed skeleton into a PDF that is
   **byte-identical** to the same invoice written by hand — 3 kinds × 2 sizes ×
   zugferd none/auto × 2 compilers (24 configs, eq.sh), all benchmark rows
   (5–1000 lines), 2 edge-case documents, incl. the embedded XRechnung XML.
2. Groups, bundles (nested, multi-VAT, bundle discounts), item modifiers,
   document discounts/surcharges and prepayments work from data through ONE motif.
3. The hydrated path is 31–55 % faster (§8.2); hand-written invoices gain
   20–37 % when `item()` shares the resolver (§8.6); the frame seed adds
   another ~25 % (§8.5).
4. Validation: draft/strict/none behave as specified with 12 kinds of data
   errors; inline JSON, file, stdin, TOML, a 0.15 `path`, the result metadata
   (eval and query) and the JSON Schema dump work; the Wappen rule follows the
   post code and a `custom` override.

## 11. API change ledger

| change                                                                                                                    | file                                                                      | kind                                | justification                                                                                                                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `invoice(data: none)`                                                                                                     | src/invoice.typ                                                           | new-parameter                       | the one hydration entry; must be an invoice() argument so check-data, draft markers, strict and the e-invoice see hydrated values (body-level hydration gives false "missing" issues and embeds wrong XML — validation research)                    |
| `invoice(custom: none)`                                                                                                   | src/invoice.typ                                                           | new-parameter                       | a documented home for custom fields (sealed `ctx.custom`); also lets the skeleton carry sample custom values                                                                                                                                        |
| `hydrate` namespace: `items`, `input`, `decode`, `schema`, `input-key`, `file-key`                                        | src/public/hydrate.typ, src/lib.typ                                       | new-export                          | slot, CLI reader, inspection, schema; lazy members; added to tests/theme/exports/test.typ. Named `hydrate`, not `data`, because `#let data = json(..)` would shadow a root export `data`                                                            |
| `payment(..)`                                                                                                             | src/hydrate/payment.typ, src/lib.typ                                      | new-export                          | which payment components exist is data (transfer/direct debit/card/paid; paid excludes terms; one means per invoice); dynamic() cannot bind component parameters                                                                                    |
| `<invoice-pro-result>` metadata                                                                                           | src/components/root.typ                                                   | new-export (introspection contract) | machine-readable totals/issues for CLI and phase 2; only for hydrated invoices or `--input invoice-pro-result=1`; invisible (PDF bytes unchanged)                                                                                                   |
| `unsealed()` and `dynamic` unwrap `ctx.custom`                                                                            | src/theming/access.typ, src/components/dynamic.typ                        | internal-refactor                   | custom fields travel sealed (cost ~0) yet read as a plain dict                                                                                                                                                                                      |
| `format-item` builds a dict instead of `loom.mutator.batch`                                                               | src/components/line-items.typ                                             | internal-refactor                   | removes ~20 memoized closure calls per entry in line-items' measure; same keys, same order; byte-identical for hand-written and hydrated invoices in all tested configs                                                                             |
| `item()` measures via the shared pure `item-signal` (scope without mutators)                                              | src/components/item.typ, new src/logic/line-signal.typ                    | internal-refactor                   | ONE implementation of the item cascade for hand-written and data lines (no drift); hand-written invoices get the same speed-up; byte-identical (prototype `repo-item/`)                                                                             |
| exact page-count seed for layout iteration 1 (`invoice-span(k, seed:)`; seed 2 when items × one body line > paper height) | src/theming/frame.typ (prototype repo-x, behind `--input ip-guess=exact`) | internal-refactor                   | removes a full second layout of the body (items table incl. keep-together measurements) on long invoices; exact by construction (one page impossible ⇒ unique fixed point); byte-identical in all measured configs; helps hand-written invoices too |
| regions export their VAT rates (`known-rates`)                                                                            | src/locale/region/\*.typ (prototype: table in decode.typ)                 | internal-refactor                   | data "16%" becomes a data issue instead of infer-tax's panic; one source of truth                                                                                                                                                                   |
| a data `"19%"` must be a rate of the locale region                                                                        | data format                                                               | behaviour (new format only)         | identical semantics to Typst `tax: 19%`, but reported, not panicking                                                                                                                                                                                |

No existing parameter, default or output changes. `item()`/`line-items` keep
their signatures; their internals change only in how the same values are
computed.

## 12. Risks

1. **Drift between the motif path and the data path.** The bulk motif replays
   the scopes of item/group/bundle/modifier/prepayment. Mitigation, prototyped:
   `item()` itself measures through the same pure `item-signal` (repo-item/,
   byte-identical), so items have ONE implementation; group/bundle/modifier/
   prepayment cascades should follow the same way (their scopes become
   `env`-replays used by both). Plus the generated equivalence suite
   (`gen.py` + `eq.sh`: same invoice as data and as Typst, md5 compared) in CI.
2. **Frame keys/paths differ** (`("item", i)` instead of loom's relative ids).
   Nothing reads them today (output identical); a future feature that anchors on
   frame keys must treat data frames alike.
3. **Loom guards are skipped for data rows** (`assert-direct-parent`); the
   decoder enforces the placement rules instead (prepayment top level, no
   modifier in a group, depth ≤ 8). A slot placed outside `line-items` is not
   caught yet (items would be lost) — a root-measure check is cheap to add.
4. **Two slots in one invoice would both receive `items`** (duplicated lines).
   v1 rule: one `hydrate.items` per invoice; detect a second one in root's
   measure (open question: named slots).
5. **Region rate table duplicated in the prototype** (`known-rates`); must move
   next to each region's `infer-tax`.
6. **Report chip**: a type error in data shows the chip "Pflichtangabe /
   Required data" (class `data`). Correct for blocking, slightly off in wording;
   a key `data-*` with localized texts fixes it in 6 language files.
7. **Layout is now the dominant cost** at ≥ 300 lines (§8.5): users may still
   call 1000-line invoices slow. That needs theme work, not data work.
8. **Memo-sensitivity.** The speed depends on `env` being identical in both
   passes; a future change that puts `ctx.global` or `sys` into `env` silently
   loses ~half the gain. Mitigation: a perf-gate benchmark on a hydrated
   300-line invoice (tools/perf), and a comment at `env-of`.
9. **Payment block** weaves its components in its own measure and again in
   draw (nested intertwine): ≈1–2 ms extra; root's single-means rules still
   apply (verified: bank-details + direct debit is rejected by CII-SR-467, so
   the block emits the account only for transfers).
10. **prints-of side effect** of data-driven wraps/parts (coat of arms):
    IP-PRINT-03/IP-PERIOD-03 become "unknown". Inherited; a `decorative` flag or
    a `logo.image` callback would keep them.
11. **Sample vs letterhead.** The merge rule (sender merged, other parties
    replaced, invalid → default) prevents sample leaks for parties and
    top-level values; a sample in `custom` of the skeleton survives unless the
    data overrides that key (documented: samples belong in keys the data sets).
12. **Internal refactors vs. the existing test suite.** `proto/regress.sh`
    compiled all 313 `tests/**/test.typ` of the repo against base, repo and
    repo-item (rendered pages at 30 ppi + first error line compared): 312 are
    identical for both design trees (incl. all 10 presets, line-items,
    ZUGFeRD, validation, the 30 expected-error tests); the only difference is
    `tests/theme/exports/test.typ` ("undocumented export(s) ("hydrate",
    "payment")"), i.e. the pinned export list that this change must update.
    tytanic's reference images were not used (not available); page md5 against
    the pristine tree is the stricter check anyway.
13. **Existing bug found**: `modifier(name, amount: "-0.50")` (a string, which
    its type check accepts) crashes in `normalize.money` — `discount` and
    `surcharge` convert with `to-decimal`, `modifier` does not. The data path
    converts, so data is unaffected; the component should be fixed separately.

## 13. Open questions

1. Single pass as an opt-in (`invoice(data:, passes: 1)` with totals precomputed
   from data)? Measured gain on top of the bulk path is within noise (§8.4);
   recommendation: no, revisit only if loom gets a skip-measure mode.
2. Named slots (`hydrate.items(key: "extras")` ↔ `"items": {"extras": [..]}`) for
   skeletons with several data-filled regions — needed, or one slot enough?
3. Should `item(custom: ..)` be added for parity with data lines' `custom`?
4. Localized texts for the `data-*` issue keys (6 language files) and a chip
   label "Daten" instead of "Pflichtangabe"?
5. Should the theme's `keep-together` measurement get a cheaper "obviously
   small" pre-check (theme change, benefits every invoice; §8.5)?
6. Should the hydration also accept YAML/TOML officially (they work: TOML dates
   pass through; YAML/TOML decode 4–5× slower than JSON, irrelevant at invoice
   sizes) or document JSON as canonical and the others as "works"?
7. `locale` per invoice (recipient's language) — a data key choosing among
   locales the skeleton names (`hydrate.input(.., locales: (de: .., en: ..))`)?
8. Should loom re-export / invoice-pro expose loom's `static` motif for heavy
   static skeleton content (measured −0.1–0.16 s for 120 styled blocks by the
   loom research)? Not needed for hydration itself.
