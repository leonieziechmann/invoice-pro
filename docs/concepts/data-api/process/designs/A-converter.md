# Design A — "Converters, zero core change" (`hydrate`)

Designer A-converter · invoice-pro 0.6.0 → proposed 0.7.0 · prototype at
`<session>/exp/design-A-converter/` (repo copy in `repo/`, skeleton and
experiments in `proto/`). Every claim marked **[v]** was compiled and checked
on typst 0.15.1 **and** 0.14.2; **[i]** is inferred.

---

## 0. Pitch

The data layer is a set of **pure converters** plus **two new loom-free or
one-motif components**, and the skeleton author wires them in explicitly. A
data file becomes a _record_ (`hydrate.load`) that is already validated and
holds Typst values (datetimes, decimals, ratios, unit functions, tax
dictionaries, `id.*` identifiers). The record is then turned into exactly what
the existing API already takes: named arguments of `invoice()`
(`hydrate.args`), ONE bulk motif that emits the same frames as N `item()`
calls (`hydrate.items`), and plain calls of the existing payment components
(`hydrate.payment`). `invoice()`, every component signature and every
behaviour of `src/` stay untouched: the only edit outside new files is one
import line in `src/lib.typ` (plus the export pin test). Custom fields never
travel through loom: the record is an ordinary Typst value in the skeleton's
scope, so design code (parts, wraps, a theme chosen from data) reads it
lexically, for free, and data-dependent design like the coat of arms by post
code stays Typst. The prototype renders a realistic e-invoice (group, bundle,
line and document modifiers, three VAT brackets, exempt line, prepayment,
cash discount, factur-x.xml) from JSON **byte-identical** to the same invoice
written by hand, on both compilers, and the bulk motif cuts compile time by
26–28 % at 50 lines and 38–42 % at 300 lines.

```text
 data.json / .toml / .yaml / --input JSON        skeleton.typ (hand-made)
            │                                          │
   hydrate.load(src, read:)  ──►  record  ◄────────────┤ lexical reads (custom, design rules)
   (validate + coerce, pure)        │                  │
            ┌───────────────────────┼──────────────────┼────────────────────┐
            ▼                       ▼                  ▼                    ▼
  hydrate.args(rec, base:,   hydrate.items(rec,   hydrate.payment(rec,   hydrate.result(rec)
     sample:, theme:)          sample:)              sample:, bank:..)    (metadata of totals)
            │                       │                  │
   invoice.with(..)            ONE raw motif      bank-details / payment-terms /
   (unchanged)                 → item/group/…     direct-debit / card-payment / paid
                               frames (unchanged  (unchanged components)
                               line-items, applicators, tree, zugferd)
```

---

## 1. Data format `invoice-pro/1`

### 1.1 Principles

| Rule            | Choice                                                                                                                          | Why                                                                                                                              |
| :-------------- | :------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------- |
| Shape           | ONE JSON object per invoice; top level mirrors `invoice()`'s parameters, plus `items`, `payment`, `custom`, `format`            | hydration is a mechanical mapping; no renaming table                                                                             |
| Naming          | kebab-case, **identical** to invoice-pro's parameter and key names (`invoice-nr`, `vat-id`, `base-quantity`, `buyer-reference`) | Typst reads `d.invoice-nr`; codegen tools alias kebab keys (prior-art, verified)                                                 |
| Aliases         | none (`street`, `region`, `contact-name` of the Typst API are not in the format)                                                | one name per thing; unknown keys are errors with a hint                                                                          |
| Versioning      | required `"format": "invoice-pro/1"`; optional `"$schema"` (editor hint, ignored)                                               | Typst cannot run JSON Schema; the major is asserted                                                                              |
| Closed core     | every object is closed: an unknown key is an error with did-you-mean / alias hint                                               | typos (`plz`, `mail`, `ust-id`) are caught, not silently printed                                                                 |
| Extension       | an open `custom` object at document level, on every party and on every line row                                                 | prior art (GOBL `meta`, Stripe `metadata`, brilliant-cv `[custom]`); codegen-friendly (`x-*` keys break pydantic/typify)         |
| Absent / `null` | both mean "not given": the skeleton's `base` value or invoice-pro's default holds                                               | `auto` has no JSON spelling; `null` ≠ `none` avoids the `none` traps (tax none = implicit zero, references none = no legal refs) |
| Formats         | JSON canonical; TOML (native dates) and YAML accepted by file extension                                                         | TOML datetimes pass through unchanged (verified)                                                                                 |

### 1.2 Value encodings (one decoder per kind, `src/hydrate/decode.typ`)

| Kind          | Encoding in data                                                                                                                                                                                                                                                    | Typst value                      | Notes                                                                                                                                                                                             |
| :------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --- | ---------------------------- |
| text          | `"..."`                                                                                                                                                                                                                                                             | str                              | a JSON number is an error ("quote it: \"42\"") — numbers crash themes (`vat-id: 123`)                                                                                                             |
| lines         | `"..."` or `["line 1", "line 2"]`                                                                                                                                                                                                                                   | str \| array                     | name, address, legal-info, management                                                                                                                                                             |
| date          | `"YYYY-MM-DD"` (TOML date)                                                                                                                                                                                                                                          | datetime                         | calendar-checked first (datetime() panics on 2026-02-30 and there is no try/catch)                                                                                                                |
| date-or-text  | `"YYYY-MM-DD"` or `{"text": "..."}`                                                                                                                                                                                                                                 | datetime \| str                  | due-date, order-date, payment-terms date, paid date: a bare string in Typst means BT-20 TEXT, so text is explicit                                                                                 |
| period        | date, `[start, end]` or `{"start", "end"}`                                                                                                                                                                                                                          | datetime \| (datetime, datetime) | end ≥ start checked                                                                                                                                                                               |
| decimal       | `"12.30"` (canonical); JSON int/float tolerated                                                                                                                                                                                                                     | decimal                          | float via `decimal(str(x))` (exact shortest repr, not the lossy `to-decimal`),                                                                                                                    | x   | ≥ 1e15 rejected, ≤ 28 digits |
| percent       | `"19%"`                                                                                                                                                                                                                                                             | ratio                            | `float(n) / 100 * 100%`: bit-exact with the literal (infer-tax compares with `==`)                                                                                                                |
| amount        | `"10%"` (relative) or `"5.00"` (absolute)                                                                                                                                                                                                                           | ratio \| decimal                 | modifiers, prepayments                                                                                                                                                                            |
| int, bool     | JSON int, bool                                                                                                                                                                                                                                                      | int, bool                        |                                                                                                                                                                                                   |
| enum          | listed strings                                                                                                                                                                                                                                                      | str                              | did-you-mean                                                                                                                                                                                      |
| tax           | `"19%"` (region infers category, like Typst `tax: 19%`) · preset `"exempt"`, `"reverse-charge"`, `"intra-community"`, `"export"`, `"outside-scope"`, `"zero"` · `{"category": "S"\|"E"\|…22 UNTDID 5305, "rate"?: "19%", "grounds"?, "code"?: "VATEX-…", "label"?}` | tax dict                         | objects are built with the category's own constructor (`tax.vat`, `tax.exempt`, …) so they equal hand-written taxes; `{"category": "S", "rate": "16%"}` avoids infer-tax's panic on unknown rates |
| unit          | unit-module name (`"hour"`, `"h"`, `"pcs"`, `"set"`), UN/ECE code (`"HUR"`, 18 codes) → localized unit; other text verbatim; `{"code", "display"}`                                                                                                                  | unit fn \| str \| dict           |                                                                                                                                                                                                   |
| id            | `"..."` (no scheme) or `{"scheme": "gln"\|"duns"\|"siren"\|"siret"\|"uid-ch"\|"leitweg"\|"register"\|"<4-digit ISO 6523>", "id": "...", "court"?}`                                                                                                                  | `id.*` value                     | named schemes go through the `id.*` constructors (check digits → IP-ID-01); one object type, codegen-friendly                                                                                     |
| e-address     | e-mail string or `{"scheme": "<EAS>", "id"}`                                                                                                                                                                                                                        | str \| dict                      |                                                                                                                                                                                                   |
| item-id       | `"..."` (seller id) or `{"seller", "buyer", "standard"}`                                                                                                                                                                                                            |                                  |                                                                                                                                                                                                   |
| country       | ISO 3166 alpha-2 (`"DE"`, any case) or `{"code", "name"}`                                                                                                                                                                                                           |                                  |                                                                                                                                                                                                   |
| city          | `"80331 München"` or `{"name", "post-code", "state"?}` (strings)                                                                                                                                                                                                    |                                  | post codes as strings (leading zeros)                                                                                                                                                             |
| extra         | `{"label": "value"}` or `[["label", "value"]]`                                                                                                                                                                                                                      |                                  | printed pairs                                                                                                                                                                                     |
| notes         | `"..."` or `["...", {"text", "subject-code"}]`                                                                                                                                                                                                                      |                                  | BT-21/22                                                                                                                                                                                          |
| currency      | ISO 4217                                                                                                                                                                                                                                                            | upper-case str                   |                                                                                                                                                                                                   |
| locale        | `"de-de"` etc.                                                                                                                                                                                                                                                      | locale fn                        | honoured only as the skeleton's `locales:` allows                                                                                                                                                 |
| document-type | `"invoice"`, `"credit-note"`, `"corrected"`, `"prepayment"`, `"self-billed"`, or a UNTDID 1001 code                                                                                                                                                                 | str \| int                       |                                                                                                                                                                                                   |
| custom        | any object                                                                                                                                                                                                                                                          | dictionary                       | never interpreted, never enters loom                                                                                                                                                              |

### 1.3 Document keys (complete)

| Key                       | Kind                           | Feeds                                                      | BT               |
| :------------------------ | :----------------------------- | :--------------------------------------------------------- | :--------------- |
| `$schema`                 | text                           | ignored                                                    |                  |
| `format`                  | `"invoice-pro/1"`              | **required**                                               |                  |
| `locale`                  | locale                         | `invoice(locale:)` via `locales:`                          |                  |
| `currency`                | currency                       | `invoice(currency:)`                                       | BT-5             |
| `document-type`           | document-type                  | `invoice(document-type:)`                                  | BT-3             |
| `invoice-nr`              | text                           | `invoice(invoice-nr:)`                                     | BT-1             |
| `date`                    | date                           | `invoice(date:)`                                           | BT-2             |
| `service-period`          | period                         | `invoice(service-period:)`                                 | BT-72 / BG-14    |
| `subject`                 | text                           | `invoice(subject:)`                                        |                  |
| `customer-nr`, `quote-nr` | text                           | same-named params                                          |                  |
| `order-nr`                | text                           |                                                            | BT-13            |
| `order-date`              | date-or-text                   |                                                            |                  |
| `project`                 | text                           |                                                            | BT-11            |
| `contract-nr`             | text                           |                                                            | BT-12            |
| `delivery-note-nr`        | text                           |                                                            | BT-16            |
| `preceding-invoice-nr`    | text                           |                                                            | BT-25            |
| `preceding-invoice-date`  | date                           |                                                            | BT-26            |
| `due-date`                | date-or-text                   |                                                            | BT-9 \| BT-20    |
| `payment-reference`       | text                           |                                                            | BT-83            |
| `notes`                   | notes                          |                                                            | BT-21/22         |
| `tax`                     | tax                            | `invoice(tax:)` = default of the items                     |                  |
| `tax-mode`                | `"exclusive"` \| `"inclusive"` |                                                            |                  |
| `tax-exempt-small-biz`    | bool                           | (excludes `tax`)                                           |                  |
| `sender`                  | seller party                   | `invoice(sender:)` (merged onto the skeleton's letterhead) | BG-4             |
| `recipient`               | buyer party                    | `invoice(recipient:)`                                      | BG-7             |
| `delivery-address`        | ship-to party                  |                                                            | BG-13/15         |
| `payee`                   | payee                          |                                                            | BG-10            |
| `items`                   | row tree                       | `hydrate.items`                                            | BG-25, BG-20/21  |
| `payment`                 | payment object                 | `hydrate.payment`                                          | BG-16..19, BT-20 |
| `custom`                  | custom                         | the skeleton (lexically)                                   |                  |

**Parties** (all: `name` lines, `address` lines, `city`, `country`, `extra`, `custom`):

- seller `sender`: + `id`, `global-id`, `legal-id` (id), `trading-name`, `legal-info` (lines), `vat-id`, `tax-nr`, `tax-representative` (address keys + `vat-id`), `electronic-address`, `contact` `{name, phone, email}`, `phone`, `email`, `register`, `management` (printed only).
- buyer `recipient`: + `id`, `global-id`, `legal-id`, `trading-name`, `vat-id`, `electronic-address`, `contact`, `phone`, `email`, `buyer-reference` / `leitweg-id` (id; BT-10), `order-nr`, `contract-nr`, `delivery-note-nr`, `delivery-address` (ship-to); printed only: `tax-nr`, `customer-nr`, `order-date`, `project`, `quote-nr`.
- ship-to `delivery-address`: + `id`, `location-id`, `global-id`.
- `payee`: `name`, `id`, `global-id`, `legal-id`, `custom`.

These sets mirror `party-keys` of `src/zugferd/model.typ:357-407` minus aliases;
a pin test (proposed) keeps them equal.

### 1.4 Line items: one tree with a `kind` discriminator

`items` is an array of rows; `kind` defaults to `"item"`.

| kind                     | keys                                                                                                                                                                                                                                                                        | required                       | may contain                       |
| :----------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------- | :-------------------------------- |
| `item`                   | `name`, `description`, `quantity`, `base-quantity`, `unit`, `price` \| `total`, `input-gross`, `tax`, `date` (period), `item-id`, `reference`, `note` (BT-127), `origin` (BT-159), `modifiers: [{kind: discount\|surcharge, name, amount, label?, description?}]`, `custom` | `name`, one of `price`/`total` | —                                 |
| `group`                  | `name`, `description`, `show-subtotal`, `tax`, `input-gross`, `date`, `unit`, `items`, `custom`                                                                                                                                                                             | `kind`, `name`, `items`        | item, group, bundle               |
| `bundle`                 | `name`, `description`, `quantity`, `base-quantity`, `unit`, `input-gross`, `tax`, `date`, `item-id`, `reference`, `items`, `custom`                                                                                                                                         | `kind`, `name`, `items`        | item, bundle, discount, surcharge |
| `discount` / `surcharge` | `name`, `label`, `description`, `amount` (≥ 0), `input-gross`, `tax` (pinned; absent = split over VAT groups)                                                                                                                                                               | `kind`, `name`, `amount`       | — (top level or in a bundle)      |
| `prepayment`             | `amount`, `name`, `label`, `date` (date-or-text), `reference`, `description`, `method`                                                                                                                                                                                      | `kind`, `amount`               | — (top level only)                |

Placement follows the components' guards (prepayment only at top level,
modifiers not in groups). Nesting is capped at 8 levels because
`calculate-modifier` collects only 10 deep (silent wrong totals otherwise,
modifier-applicator.typ:188).

### 1.5 Payment

```json
"payment": {
  "terms": { "days": 30, "date": "2026-04-01", "discount": [{ "days": 10, "percent": "2%", "basis": "500.00" }] },
  "bank": { "name": "..", "bank": "..", "iban": "..", "bic": "..", "reference": "..", "text": "..", "payment-amount": ".." },
  "direct-debit": { "mandate": "M-17", "creditor-id": "DE98ZZZ09999999999", "debtor-iban": "DE02.." },
  "card": { "last4": "0042", "holder": "..", "kind": "credit" },
  "paid": { "method": "cash|cheque|online|transfer|card|direct-debit", "date": "2026-03-02" }
}
```

`bank` and `terms.discount` take one object or an array. WHICH components
exist is data: `paid` excludes `terms` (and a text due-date) — checked as a
data error; `direct-debit`/`card`/`paid` (non-transfer) suppress the
skeleton's transfer account; paid _by transfer_ keeps it (CII-SR-470).

---

## 2. Example data (complete, canonical; `proto/data/2026-0042.json`)

```json
{
  "$schema": "../schema/invoice-pro-data-1.schema.json",
  "format": "invoice-pro/1",
  "invoice-nr": "2026-0042",
  "date": "2026-03-02",
  "service-period": { "start": "2026-02-01", "end": "2026-02-28" },
  "currency": "EUR",
  "order-nr": "PO-77812",
  "order-date": "2026-01-20",
  "project": "Digitales Bürgeramt",
  "payment-reference": "RE 2026-0042",
  "notes": [
    "Vielen Dank für die gute Zusammenarbeit.",
    {
      "text": "Leistungen gemäß Rahmenvertrag RV-2025-03.",
      "subject-code": "AAI"
    }
  ],
  "sender": {
    "contact": {
      "name": "Jana Kraus",
      "phone": "+49 30 1234567-12",
      "email": "j.kraus@musterfirma.de"
    }
  },
  "recipient": {
    "name": "Landeshauptstadt München – IT-Referat",
    "address": ["Agnes-Pockels-Bogen 21", "z. Hd. Frau Dr. Seidl"],
    "city": "80339 München",
    "country": "DE",
    "vat-id": "DE129521671",
    "email": "rechnungseingang@muenchen.de",
    "buyer-reference": "04011000-1234512345-06",
    "custom": { "tarif": "Rahmenvertrag Kommunal", "kostenstelle": "4711-IT" }
  },
  "items": [
    {
      "kind": "group",
      "name": "Phase 1 – Konzeption",
      "description": "Workshops und Fachkonzept",
      "items": [
        {
          "name": "Anforderungsworkshop",
          "quantity": "2",
          "unit": "day",
          "price": "1200.00",
          "date": "2026-02-03",
          "custom": { "ticket": "BA-101" }
        },
        {
          "name": "Fachkonzept",
          "quantity": "16",
          "unit": "HUR",
          "price": "125.00",
          "modifiers": [
            { "kind": "discount", "name": "Kommunalrabatt", "amount": "10%" }
          ],
          "custom": { "ticket": "BA-102" }
        }
      ]
    },
    {
      "kind": "bundle",
      "name": "Arbeitsplatz-Paket",
      "quantity": "3",
      "unit": "set",
      "items": [
        { "name": "Notebook", "price": "980.00" },
        { "name": "Dockingstation", "price": "189.90" },
        {
          "name": "Einrichtung",
          "quantity": "1.5",
          "unit": "hour",
          "price": "95.00"
        }
      ]
    },
    {
      "name": "Fachbuch Verwaltungsdigitalisierung",
      "quantity": "2",
      "price": "49.90",
      "tax": "7%",
      "item-id": { "seller": "B-0815", "standard": "9783161484100" }
    },
    {
      "name": "Schulung (Bildungsleistung)",
      "total": "800.00",
      "tax": {
        "category": "E",
        "grounds": "Steuerfrei nach § 4 Nr. 21 UStG",
        "code": "VATEX-EU-132-1I"
      }
    },
    {
      "kind": "discount",
      "name": "Projektrabatt",
      "amount": "250.00",
      "tax": "19%"
    },
    { "kind": "surcharge", "name": "Reisekostenpauschale", "amount": "2%" },
    {
      "kind": "prepayment",
      "amount": "1000.00",
      "name": "Abschlag",
      "date": "2026-02-15",
      "reference": "AB-2026-0007"
    }
  ],
  "payment": {
    "terms": { "days": 30, "discount": { "days": 10, "percent": "2%" } }
  },
  "custom": { "project-lead": "Dr. Theo Brandt", "cost-center": "KST-310" }
}
```

The recipient's post code (80339) selects the Bavarian coat of arms; the
`sender` object has no `name`, so it only completes the letterhead (the clerk).

---

## 3. The skeleton (compiled; `proto/skeleton.typ`, typstyle-clean)

```typst
#import "@preview/invoice-pro:0.7.0": *

// 1. The data. Without --input: none, so every slot shows its sample.
#let rec = hydrate.load(none, read: p => read(p, encoding: none))

// 2. Design rules that depend on data stay Typst: the coat of arms of the
//    recipient's region by post code. Paths resolve against THIS file.
#let arms = ("8": "wappen/bayern.svg", "1": "wappen/berlin.svg")
#let wappen(party) = {
  let plz = hydrate.party(party).at("post-code", default: none)
  let file = if plz == none { none } else {
    arms.at(plz.first(), default: none)
  }
  image(if file == none { "wappen/neutral.svg" } else { file }, alt: "Wappen")
}

// 3. What is the same on every invoice (design and letterhead) ...
#let letterhead = (
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "Musterfirma IT GmbH",
    address: "Friedrichstraße 100",
    city: "10117 Berlin",
    country: "DE",
    vat-id: "DE123456789",
    tax-nr: "37/123/45678",
    legal-id: id.register("HRB 123456 B", court: "Amtsgericht Charlottenburg"),
    contact: (name: "Buchhaltung", phone: "+49 30 1234567-0", email: "buchhaltung@musterfirma.de"),
  ),
)
// ... and the hand-written sample the skeleton was designed with.
#let sample = (
  invoice-nr: "MUSTER-0001",
  date: datetime(year: 2026, month: 1, day: 15),
  due-date: datetime(year: 2026, month: 1, day: 29),
  recipient: (name: "Beispielkunde AG", address: "Musterweg 5", city: "20095 Hamburg", vat-id: "DE987654321"),
)

#show: invoice.with(..hydrate.args(
  rec,
  base: letterhead,
  sample: sample,
  // design chosen from data: a STATIC logo patch (keeps the built-in `logo` part)
  theme: a => theme.classic.with(theme.custom.logo(
    image: wappen(a.at("recipient", default: none)),
    height: 18mm,
  )),
))

// Custom fields are plain values of the record: read them where you need them.
#let tarif = hydrate.get(rec, "recipient.custom.tarif", sample: "Standard")
#let lead = hydrate.get(rec, "custom.project-lead", sample: "Max Muster")
Tarif: #tarif · Projektleitung: #lead

#line-items[
  #hydrate.items(rec, sample: [
    #item("Beratung", quantity: 8, unit: unit.hour, price: 120)
    #item("Lizenz", price: 450)
  ])
]

#hydrate.payment(
  rec,
  sample: [#payment-terms(days: 14)],
  terms: (days: 14),
  bank: (bank: "Musterbank Berlin", iban: "DE75512108001245126199", bic: "SOLADEST600"),
)

#signature()
#hydrate.result(rec)
```

The workflow the maintainer asked for: the user designs this file by hand
with the `sample` values (it compiles and renders the sample with no input);
hydration is a CLI flag. Each slot (`sample:`) is replaced **as a whole**
when data is given, so sample values can never leak into a real invoice;
`base` is what is the same on every invoice. Static items can sit next to
the slot (`#item("Setup fee", ..) #hydrate.items(rec)`), also inside a
skeleton `group` — verified, numbering continues.

---

## 4. API surface (new root export `hydrate`; nothing else changes)

`src/public/hydrate.typ` is a facade whose functions import their
implementation module inside the body (lazy): the facade costs **0.08 ms** of
the root import [v], and `hydrate.load(none)` without `--input` returns before
importing the decoder.

```text
hydrate.empty -> dictionary
  The record of "no data" (given: false).

hydrate.load(source, read: none, inputs: sys.inputs, errors: "panic") -> record
  source: none | dictionary (json()/toml()/yaml() result) | bytes (JSON) | str (JSON text
          starting with "{", else a path opened with `read`) | path (Typst 0.15)
  read:   the skeleton's reader `p => read(p, encoding: none)` (a package cannot open
          project files; the closure resolves paths against the file that defines it)
  inputs: injectable for tests (tytanic cannot pass --input)
  errors: "panic" — every invalid value is collected and the compile stops ONCE with a
          numbered list of `path` + message + fix (all validation levels: misuse rule);
          "issue"  — invalid values are dropped and become class "data" issues that
          hydrate.args hands to invoice()'s validation (draft report, strict panic,
          XML withheld, none = off)
  Precedence: --input invoice-pro-data=<json> > --input invoice-pro-data-file=<path> > source.
  Record: (given, origin, format, data: coerced document incl. custom bags,
           args: invoice args with party `custom` stripped, locale, items, payment,
           custom, issues)
  Pure: memoized by Typst; the record never enters the loom ctx.

hydrate.args(rec, base: (:), sample: (:), theme: auto, locales: auto) -> dictionary
  Without data: base + sample. With data: base with rec.args on top; sample ignored.
  Parties (sender, recipient, delivery-address, payee): a data party WITH `name` replaces
  the base party; WITHOUT `name` it is merged onto it (data keys win; nested dicts such
  as contact/city replace whole). Other keys: data replaces base.
  theme: auto = base.theme (or theme.classic); a function receives the merged args and
         returns the lazy theme (design decided from data, e.g. a logo by post code).
  locales: auto = the 30 stock locales by name; a dictionary name -> locale (keeps
           skeleton customizations); none = ignore a data `locale`. Unknown name: panic.
  errors: "issue": wraps the chosen lazy theme so its resolved `issues` carry the
  record's issues (the only zero-change channel into invoice.typ:547-561).
  Use: #show: invoice.with(..hydrate.args(rec, base: .., sample: ..))

hydrate.items(rec, sample: none) -> content
  rec: a record, or an array of raw rows (decoded on the spot, errors panic) — e.g. rows
       produced by a CSV converter in the skeleton.
  Without data: sample. With data but no rows: nothing (check-data reports "no line
  items"). Otherwise ONE raw loom motif placed inside line-items (or a skeleton group /
  bundle) whose measure returns the frames item/group/bundle/modifier/prepayment would
  emit, computed with the unchanged calculate-item-data / calculate-modifier /
  calculate-bundle. Per-row work is a pure function of (row, env) → loom's 2nd pass is
  memo hits. Per-row `custom` rides along into view.items / view.entries.

hydrate.payment(rec, sample: none, terms: (:), bank: (:), direct-debit: (:),
                card: (:), paid: (:), order: ("terms","paid","direct-debit","card","bank"))
  -> content
  Without data: sample. With data: the components the data names, each called with the
  skeleton's constant arguments below the data's (`..base, ..data`): payment-terms (unless
  paid), paid, direct-debit (creditor-id from the skeleton), card-payment, bank-details
  (data accounts always; the skeleton's account only for a transfer — no direct debit,
  no card, paid only by transfer). Layout knobs (qr-code, show-reference) live in `bank:`.

hydrate.get(rec, path, default: none, sample: auto) -> any
  Dotted lookup in rec.data ("custom.project-lead", "recipient.custom.tarif"): sample
  without data, default when the data lacks it.

hydrate.party(party, region: "de") -> dictionary
  normalize-party at document level (post-code, city-name, country.code, …) for design
  decisions before invoice() runs.

hydrate.result(rec) -> content
  A draw-only dynamic that emits <invoice-pro-result> metadata of plain strings:
  (format: "invoice-pro-result/1", origin, invoice-nr, date "YYYY-MM-DD", currency,
   total: (net, gross, prepaid, due), issues: (ids of the up-front issues)).

hydrate.schema() -> dictionary
  The format as JSON Schema 2020-12, generated from src/hydrate/spec.typ.
```

**Precedence summary.** `--input invoice-pro-data` › `--input
invoice-pro-data-file` › `source` › no data. Data › `base` (per key; parties by
the `name` rule). `sample` only without data. `theme:` hook › `base.theme` ›
`theme.classic`. `--input invoice-pro-validation` still overrides the level.

---

## 5. CLI (phase 1)

```sh
# design / preview: no data, the samples render
typst compile skeleton.typ

# a file (any size; inside --root; relative to the SKELETON file, or root-absolute "/…")
typst compile --pdf-standard a-3b --input invoice-pro-data-file=/data/2026-0042.json skeleton.typ out/2026-0042.pdf

# inline JSON (≤ 128 KiB per argument on Linux, ~32 K chars on Windows) — read by the package itself
typst compile --pdf-standard a-3b --input invoice-pro-data="$(cat data/2026-0042.json)" skeleton.typ out.pdf

# TOML / YAML by extension
typst compile --input invoice-pro-data-file=/data/2026-0043.toml skeleton.typ out.pdf

# sending / CI / batch: strict (any data issue or missing legal data stops the build)
typst compile --input invoice-pro-validation=strict --input invoice-pro-data-file=/data/x.json skeleton.typ x.pdf

# stdin (POSIX) [i: verified for read() in typst-cli research, not with this prototype]
cat x.json | typst compile --root / --input invoice-pro-data-file=/dev/stdin /abs/skeleton.typ x.pdf

# batch: one process per invoice, in parallel (one PDF per e-invoice is mandatory)
ls data/*.json | xargs -P4 -I{} sh -c 'typst compile --pdf-standard a-3b --input invoice-pro-data-file=/{} skeleton.typ out/$(basename {} .json).pdf'

# computed values back (both cost a compile)
typst query --input invoice-pro-data-file=/data/x.json skeleton.typ "<invoice-pro-result>" --field value --one   # 0.14 (deprecated in 0.15)
typst eval  --input invoice-pro-data-file=/data/x.json 'query(<invoice-pro-result>).first().value' --in skeleton.typ  # 0.15

# draft issues (incl. schema/<path> issues under errors: "issue")
typst query skeleton.typ "<ip-issue>" --field value      # 0.14
typst eval 'query(<ip-issue>).map(m => m.value)' --in skeleton.typ   # 0.15

# the JSON Schema, without layout
typst eval '{ import "@preview/invoice-pro:0.7.0": hydrate; hydrate.schema() }' > invoice-pro-data-1.schema.json   # 0.15, 0.17 s
printf '#import "@preview/invoice-pro:0.7.0": hydrate\n#metadata(hydrate.schema())<s>\n' | typst query - "<s>" --field value --one   # 0.14
```

0.14 vs 0.15: identical except `typst eval` (0.15 only; `query` warns in
0.15), the `path` source (`hydrate.load(path("data.json"))`, 0.15 only,
verified) and 0.15's experimental bundle export, for which a skeleton written
as a function `render(rec)` can loop over records with `document(..)` per
invoice [i, pattern from typst-cli research; not prototyped].

---

## 6. Extensibility

**Custom fields.** `custom` bags exist on the document, every party and every
row. They are validated only as "an object", kept in `rec.data`, and
**stripped** from the party dictionaries handed to `invoice()` (no IP-KEY-01
warnings, no IP-KEY-02 alias errors such as `plz`, no unsealed payload in
ctx). Where they are read:

- anywhere in the skeleton: `hydrate.get(rec, "custom.project-lead")` or plain
  `rec.data.custom` — the record is a Typst value in scope;
- theme parts, wraps and area cells **written in the skeleton** close over
  `rec` (lexical capture; the resolved theme is sealed, so this is free);
- a theme defined elsewhere becomes a function of the record
  (`#let my-theme(rec) = theme.classic.with(..)`);
- per-line `custom` travels in the item signal to `view.items` /
  `view.entries` (verified with a `wrap("line-items")` that prints tickets).

**Changes that depend on a field value (Wappen).** Data supplies facts; the
skeleton owns rules. Because the record is known at document level, the rule
can choose a **static** theme patch: `hydrate.args(.., theme: a =>
theme.classic.with(theme.custom.logo(image: wappen(a.recipient))))`. Verified:
10115 → BERLIN, 50667 → NEUTRAL, 80331/80339 → BAYERN on both compilers.
Advantage over the render-time routes (custom part, `wrap("logo")`, function
cell): the built-in `logo` part stays, so `prints-of(theme).page-content`
stays `false` (verified: classic false, logo patch false, wrap true, custom
part true) — the e-invoice "is it printed" checks (IP-PRINT-03, IP-PERIOD-03)
keep working, and lint/logo-alt checks the chosen logo at resolve time.
Image paths resolve against the skeleton (closures defined there). The
render-time routes still work for rules that need computed values (totals).

**What the format deliberately does not do.** No expression language, no
`eval`, no theme section (brand files stay `theme.custom.from-data`), no
`references` (layout; custom reference rows are skeleton code reading the
record).

---

## 7. Performance — which loom steps are skipped, measured

Skipped, with zero core change:

1. **N item / group / bundle / modifier / prepayment motifs → ONE raw motif**
   (no scope mutator chains, no guards, no per-item ctx hashing). The per-row
   function is pure in (row, env) where env excludes `sys`/`global`, so pass 2
   is memo hits: traced 300 rows, pass 1 193 ms vs pass 2 **5 ms**.
2. **No data in the loom ctx**: rows are motif arguments, custom data is
   lexical; the +48…76 % unsealed-payload trap cannot happen by construction.
3. **Decoding happens once, outside loom** (pure, memoized).

Not skipped (needs core change; see §10): pass 1 (max-passes 1 with a
precomputed `global`: 0–5 % extra in phase-1 research and couples the format
to the skeleton — rejected), `format-item`'s mutator.batch in line-items
measure (~420–500 ms traced at 300 rows), the theme table layout (3 layout
iterations, ~3.5 s traced at 300 rows — now the bottleneck).

Wall clock, `typst compile --pdf-standard a-3b`, zugferd en16931, median of 5
round-robin runs, shared 4-core VM (single runs vary up to ±0.8 s at 300).
`hand` = the same invoice as Typst literals (today), `loop` = user-space
hydration (`for r in rec.items { item(..) }`), `rows` = `hydrate.items`. All
three PDFs are md5-identical at every size.

| rows | 0.15.1 hand |  loop |          **rows** | 0.14.2 hand |  loop |          **rows** |
| ---: | ----------: | ----: | ----------------: | ----------: | ----: | ----------------: |
|    5 |     0.589 s | 0.586 | **0.492** (−16 %) |       0.597 | 0.638 | **0.505** (−15 %) |
|   50 |       1.516 | 1.576 | **1.129** (−26 %) |       1.600 | 1.625 | **1.147** (−28 %) |
|  300 |       8.155 | 7.197 | **4.756** (−42 %) |       7.988 | 7.480 | **4.918** (−38 %) |

Traced (0.15.1, 300 rows): eval 4263 → **1834 ms**; layout 1606+1563+330 vs
1544+1626+326 ms (unchanged). Decoder: 270 → 73 ms traced after replacing
Unicode `\d{1,27}` regexes (≈60 µs per match) by `[0-9]+` plus a length check
and dispatching scalars through a table; untraced ≈ 85 ms for 300 rows
(document of 300 rows: 285 ms vs 200 ms for `json()` alone, medians of 9).
Facade import: 0.08 ms. Schema dump: 0.17 s (`typst eval`, no layout).

---

## 8. Validation and error model

| Situation                                                                                                                                      | Mechanism                                                                                 | Level-dependent                                                                                                                              |
| :--------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------- |
| wrong type / encoding, unknown key, bad enum, wrong format major, bad placement, nesting > 8, price and total, negative discount, paid + terms | decode error with JSON path, message, fix                                                 | `errors: "panic"` (default): always panics, all collected, one message. `errors: "issue"`: class "data" issue `schema/<path>`, value dropped |
| skeleton misuse (`read` missing for a file, bad `locales`, bad `source`)                                                                       | panic                                                                                     | no                                                                                                                                           |
| missing legally required data (invoice-nr, names, addresses, tax id, items, recipient VAT for AE/K)                                            | existing `check-data` — the data reaches invoice()'s own arguments, so no false "missing" | yes (draft markers, strict panic, XML withheld)                                                                                              |
| invalid IBAN / creditor id / identifier check digits                                                                                           | existing data issues / IP-ID-01                                                           | yes / zugferd-errors                                                                                                                         |
| EN 16931 / XRechnung rules                                                                                                                     | existing e-invoice rules                                                                  | `zugferd-errors`                                                                                                                             |

Default panic message (verified, both compilers; 0.14 prints it quoted):

```text
error: panicked with: invoice-pro data (--input invoice-pro-data-file=data/bad.json) has 8 problems:
  1. `invoice-nr` must be a string, got 42. Fix: quote it: "42"
  2. `date` is not a calendar date: "2026-02-30".
  3. `due-date` must be a date "YYYY-MM-DD", got "14 Tage"; text such as payment terms is written {"text": "14 Tage"} (BT-20). Fix: {"text": "14 Tage"}
  4. `recipient.plz` is not a key of recipient. Use `city: {"name": .., "post-code": ..}`. Put own fields into `custom`.
  5. `items[0].price` must be a decimal string such as "12.30", got "12,30". Fix: "12.30"
  6. `items[1].kind` must be one of "item", "group", "bundle", "discount", "surcharge", "prepayment", got "dicount" Did you mean `discount`?
  7. `items[2].tax` must be a rate with a percent sign, got "19". Fix: "19%"
  8. `wappen` is not a key of the document. Put own fields into `custom`.
```

Others (verified): `items[0].items[0]` a prepayment cannot be inside a group
(allowed: item, group, bundle) · `format` is "invoice-pro/2", but this
version of invoice-pro reads "invoice-pro/1" · `payment.paid` excludes
payment.terms · `--input invoice-pro-data-file=… names a file, which a
package cannot open: pass the skeleton's reader, hydrate.load(.., read: p =>
read(p, encoding: none))`.

`errors: "issue"` with the same file (verified): **draft** — badge "ENTWURF ·
10 Probleme · keine E-Rechnung", report page with the 8 schema issues (ref
"invoice-pro data format 1") plus 2 check-data issues (the dropped
invoice-nr → inline marker ‹fehlt: Rechnungsnummer›; no valid rows → no line
items), **0 attachments**; **strict** — one panic listing all 10; **none** —
no data checks ("off means off"); the e-invoice rules still run and stop on
BR-02/BR-16. Within an object, an invalid key is dropped and the valid keys
stay; a row with any error is dropped whole.

Unknown keys: closed objects everywhere except `custom`, i.e. stricter than
today's party dicts (which silently accept unknown keys despite the docs).

---

## 9. API change ledger

| Change                                                                                                                                                                                            | File                                              | Kind                             | Justification                                                                                                |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------ | :------------------------------- | :----------------------------------------------------------------------------------------------------------- |
| root export `hydrate` (facade, lazy)                                                                                                                                                              | `src/lib.typ` (+1 line), `src/public/hydrate.typ` | new-export                       | the whole feature; namespace not `data` (shadowed by `#let data = json(..)`)                                 |
| `tests/theme/exports/test.typ` lists `hydrate`                                                                                                                                                    | tests                                             | new-export                       | pinned root exports                                                                                          |
| implementation modules `spec`, `decode`, `load`, `args`, `rows`, `payment`, `result`, `schema`                                                                                                    | `src/hydrate/*.typ` (new)                         | internal-refactor (new internal) | no existing file touched                                                                                     |
| package inputs `invoice-pro-data` (inline JSON), `invoice-pro-data-file` (path for the skeleton's reader)                                                                                         | `src/hydrate/load.typ`                            | new-parameter (CLI)              | `invoice-pro-` prefix, injectable `inputs:`, input wins (precedent `invoice-pro-validation`)                 |
| metadata label `<invoice-pro-result>`                                                                                                                                                             | `src/hydrate/result.typ`                          | new-export                       | only when the skeleton places `hydrate.result`                                                               |
| relies on (unchanged) the lazy-theme protocol `theme(base:, env:)` → resolved dict with `issues` (documented at `theme.resolve`)                                                                  | —                                                 | behaviour-change: none           | the only zero-change route for `errors: "issue"`; proposal: document it as a provisional contract (doc-only) |
| reuses internal functions read-only: calculate-item-data, calculate-bundle, calculate-modifier, unit resolve, tax constructors/resolve, evaluate-modifier, normalize-party, issue(), row-style-of | —                                                 | internal-refactor: none          | they become pseudo-contracts; guarded by hydrated-vs-handwritten equivalence tests                           |
| NOT done, recommended later: fix `collect-signals(depth: 10)` in calculate-modifier                                                                                                               | `src/logic/modifier-applicator.typ:188`           | bugfix                           | silent wrong totals ≥ 10 nesting levels; the format caps at 8 meanwhile                                      |
| NOT done, optional: plain-dict `format-item` in line-items measure; cheaper keep-together in the items table                                                                                      | line-items.typ, table.typ                         | internal-refactor                | next speed bottleneck; no API change                                                                         |

No existing signature, default or behaviour changes. Template output is
md5-identical with and without the new export on both compilers [v].

---

## 10. Where "zero core change" is impossible — and the least invasive workaround

| Need                                                                         | Why impossible without core change                                 | Workaround in this design                                                                                     | Least invasive core change if the workaround is not enough                                                                                                    |
| :--------------------------------------------------------------------------- | :----------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Top-level custom fields reaching ctx / theme parts                           | `invoice()` rejects unknown args; `apply` does not reach the frame | lexical capture (record in scope), `theme: a => ..` hook, `hydrate.get`                                       | additive `invoice(data: none)` sealed in metadata + unseal in `unsealed()`/dynamic (≈10 lines, prototyped in phase 1) — not needed for anything verified here |
| Party custom keys in `ctx.recipient` / `view.recipient`                      | e-invoice reports unknown party keys (IP-KEY-01/02)                | strip `custom` before invoice(); read `rec.data.recipient.custom`                                             | one line: `custom: false` in `party-keys` (`src/zugferd/model.typ`)                                                                                           |
| Schema issues in invoice()'s validation (draft report, strict, XML withheld) | issues are built inside invoice() (invoice.typ:547-561)            | default: panic (safe in every level); opt-in `errors: "issue"` via the lazy-theme `issues` channel (verified) | doc-only: declare "a lazy theme's resolved `issues` join the invoice's validation" provisional; or additive `invoice(issues: ())`                             |
| Data-driven parameters of components (dynamic cannot bind them)              | components take values at eval time                                | the record is known at eval time: converters produce real arguments                                           | —                                                                                                                                                             |
| Payment components chosen by data                                            | a fixed skeleton with `payment-terms` + data "paid" panics         | `hydrate.payment` composite emits only what the data names                                                    | —                                                                                                                                                             |
| Per-line custom fields                                                       | `item()` rejects unknown args                                      | only data rows (bulk motif) carry `custom`                                                                    | additive `item(custom:)`                                                                                                                                      |
| Skip loom pass 1                                                             | weave call lives in invoice()                                      | not done (0–5 % on top of the bulk motif)                                                                     | additive `invoice(global:)` + max-passes 1 (phase-1 P1) — rejected: couples format and skeleton                                                               |
| `info.total.due/prepaid` empty; `info.due-date/iban` empty in the body       | dynamic fallbacks                                                  | `hydrate.result` reads `ctx.global` directly                                                                  | fix dynamic fallbacks (bugfix)                                                                                                                                |
| Data-chosen locale keeping skeleton customizations                           | locale customizations are closures                                 | `locales:` map in the skeleton                                                                                | —                                                                                                                                                             |
| Line-items/table layout cost                                                 | theme internals                                                    | —                                                                                                             | internal refactor (format-item, keep-together)                                                                                                                |

---

## 11. Phase-2 hooks

- **One source of truth**: `src/hydrate/spec.typ` (keys, kinds, BT numbers)
  drives the decoder AND `hydrate.schema()` (JSON Schema 2020-12, closed
  objects, `custom` bags, `$defs` per kind, `row` = oneOf with `kind`
  discriminators). Verified with python-jsonschema: the example validates
  with 0 errors; `bad.json` gives the same 8 errors as the Typst validator.
  Ship the generated file under `src/` (published) with a CI diff check.
- **Transport contract** = one string input: `invoice-pro-data` (JSON text)
  or `invoice-pro-data-file` (path). typst-py/typst-rb pass
  `sys_inputs: dict[str, str]` — a binding is `json.dumps(model)`.
- **Result contract** `<invoice-pro-result>` (plain strings, versioned
  `invoice-pro-result/1`); **error contract**: panic text lines
  "`<path>` <message>. Fix: <fix>" under the stable prefix "invoice-pro
  data", or `schema/<path>` issue ids in `<ip-issue>`.
- **Golden tests**: hydrated-vs-handwritten md5/XML pairs (the prototype's
  method) become fixtures that bindings can replay.
- Codegen-friendly choices: kebab keys (aliases in TS/pydantic/serde), one
  identifier object type, decimals/percents as patterned strings,
  `format: date`.

---

## 12. Prototype

Paths: `<session>/exp/design-A-converter/repo/src/hydrate/{spec,decode,load,args,rows,payment,result,schema}.typ`,
`repo/src/public/hydrate.typ`, `repo/src/lib.typ` (+1 line);
`proto/skeleton.typ`, `proto/handwritten.typ`, `proto/data/{2026-0042,numbers,bad}.json`,
`proto/data/small.toml`, `proto/bench/*`, `proto/t-*.typ`, `proto/schema/invoice-pro-data-1.schema.json`.
All new `.typ` files are typstyle 0.15.1-clean.

Results [v]:

- skeleton hydrated from `data/2026-0042.json` vs `handwritten.typ`: PDF md5
  identical (0.15.1 `d6423eecc3…`, 0.14.2 `8a0140540b…`, fixed creation
  timestamp, PDF/A-3b); `factur-x.xml` identical, and identical across both
  compilers (`5ac48f000e…`). Inline `--input invoice-pro-data` = file.
  JSON numbers (`"price": 49.9`) = strings. (One bug found and fixed on the
  way: a bundle's auto description depends on loom's absent-vs-`none`
  semantics of `derive`.)
- sample mode (no input) renders the skeleton's samples on both compilers.
- bench rows/loop/hand byte-identical at 5/50/300 rows; timings in §7.
- `errors: "issue"`: draft / strict / none behaviour as in §8.
- payment means: direct debit (BT-81 59, creditor id from skeleton), card +
  paid (54), paid by transfer (58, account kept), transfer via a 0.15 `path`
  source (58).
- TOML with native dates; static + data rows mixed, also inside a skeleton
  `group`; per-line `custom` in `view.items`; `<invoice-pro-result>` via
  `query` (0.14) and `eval` (0.15); schema dump identical on both.
- template unchanged (md5) with the extended `lib.typ`.

---

## 13. Risks

1. **Semantic drift** between the bulk motif and `item`/`group`/`bundle`
   (cascades via loom's derive/ensure, ratio taxes, small-business override).
   One drift was found by the equivalence test. Mitigation: a
   `tests/hydrate/` suite of hydrated-vs-handwritten pairs; later, an internal
   refactor that makes the item/bundle scopes call the same pure resolvers.
2. **`errors: "issue"` relies on the lazy-theme protocol** (`issues` of the
   resolved theme). Default `panic` does not.
3. **Base discipline**: data cannot _clear_ a base value (absent = keep). Per-
   invoice values belong in `sample`, never in `base`.
4. **Party `name` rule** may surprise (a full replacement needs `name`).
5. **Paths of `invoice-pro-data-file` resolve against the file that defines
   `read`** (verified gotcha); docs must recommend root-absolute `/…` paths.
6. **Remaining speed is layout** (~3.5 s traced at 300 rows): "fast" is capped
   without theme work.
7. Bundles in the bulk motif still pass the ctx (no cross-pass memo) — fine
   for few bundles.
8. A ratio tax such as `"16%"` still goes through the region's infer-tax and
   panics in `de` (as `tax: 16%` does); the object form avoids it.
9. Decoder regex pitfalls (Unicode `\d` with bounded repetition cost 60 µs
   per match); the decoder now costs ≈0.3 ms/row and should get a perf budget.
10. The internal functions the bulk motif calls become pseudo-contracts.

## 14. Open questions

1. Namespace name `hydrate` (verb) vs a noun (`record`, `invoice-data`)?
2. Default `errors: "panic"` (safe everywhere, misuse rule) or `"issue"`?
3. Promote the lazy-theme `issues` channel to a documented provisional
   contract, or add `invoice(issues:)`?
4. Party merge: keep the `name` rule, or always replace / always merge?
5. Allow party `custom` through to ctx (`custom: false` in `party-keys`) for
   frame parts written outside the skeleton?
6. Tolerate JSON numbers for money (current) or reject them?
7. Data `locale`: default `locales: auto` (stock names) or `none`?
8. Refactor the item/bundle scopes into shared pure resolvers in this feature
   or later?
9. Fix the depth-10 collector, or keep the cap of 8?
10. Ship a batch helper (0.15 bundle) in phase 1 or document it only?
11. Is theme-side speed (keep-together, format-item) in scope for "fast"?
