# invoice-pro data API (phase 1): programmatic invoices from one data format

Status: concept for review (2026-11-03), target release 0.7.0. Proposed tier: the API (`invoice(data:, custom:)`, `invoice-data`, `payment`) is experimental, the data format `invoice-pro/1` is provisional (Q29). Nothing of it is in `src/` yet. What exists is this concept and a prototype: ten patches on top of 0.6.0 (`df934a7`) in [`prototype/`](prototype/README.md), with examples, data and a script that reproduces the core proofs. The prototype implements the unified design of the exploration ([`process/designs/synthesis.md`](process/designs/synthesis.md), "the synthesis"). Four independent verifiers checked it in three rounds, with two fix rounds in between ([`process/review/verification.md`](process/review/verification.md)). This document describes the design **as prototyped**. Where the prototype differs from the synthesis, the text says so and cites the entry of [`process/prototype/deviations.md`](process/prototype/deviations.md) as "dev. n". Every number comes from the build report ([`process/prototype/build.md`](process/prototype/build.md)), the verification report or a design prototype, and names its compiler; _proposed_ marks what was not built. Compilers: everything was verified on Typst **0.15.1 and 0.14.2** unless a line says otherwise. Paths that start with `src/`, `tests/`, `tools/` or `docs/` are relative to the repository root; `process/` and `prototype/` are relative to this document; `<session>` is the scratch directory of the exploration, which is not part of the repository. The `typst` blocks carry no package import: they assume `#import "@preview/invoice-pro:<version>": *`. Blocks that write `..party` also assume a dictionary `party` with `sender`, `recipient`, `invoice-nr` and `date`. All `typst` blocks are typstyle-0.15.1-clean and compile against the prototype on both compilers. Shell lines write `@preview/invoice-pro:<version>` where a version is needed.

---

## Executive summary

**The idea.** You design an ordinary invoice in Typst, with sample values: the _skeleton_. It previews like any invoice. To produce a real invoice, a program hands over one JSON object in the format `invoice-pro/1`, and invoice-pro _hydrates_ the skeleton with it. The data replaces what identifies one invoice: the number, the dates, the recipient, the references, the line items, the details of a direct debit, card or paid invoice, and the custom fields. The issuer's settings (letterhead, bank, payment terms, tax settings) keep the skeleton's values unless the data gives them. The design never comes from data. Problems in the data become ordinary `data` issues of the existing validation levels: a draft with markers and no e-invoice under `"draft"`, one panic that lists every problem under `"strict"`.

**The workflow.**

1. Design `skeleton.typ` by hand and preview it: `typst compile skeleton.typ`.
2. Add one line to it: `#let record = invoice-data.load(read: p => read(p, encoding: none))`, and pass `data: record` to `invoice`. The line is needed for data files and for design rules that read the data (§2.5).
3. Hydrate it with one flag per invoice: `typst compile --pdf-standard a-3b skeleton.typ out/2026-0042.pdf --input invoice-pro-data-file=data/2026-0042.json`.

**What is added.** Two `invoice()` parameters (`data`, `custom`), two root exports (`invoice-data` with 10 names, and `payment`), three `--input` keys, one metadata label (`<invoice-pro-result>`) and one reserved party key (`custom`). Nothing changes for an invoice that is not hydrated: per compiler, 1105 documents compile to the same PDF bytes or the same error on 0.6.0 and on the prototype, except 9 that pass a misspelt data key, which now panics on purpose (P2, §11). The few changes that are not pure extensions are listed and justified in §9.

**Speed.** The line items of the data become one bulk loom motif instead of one motif per row, and loom's second pass is a cache hit. A hydrated 300-row e-invoice takes 0.571× (Typst 0.15.1) and 0.568× (0.14.2) of the time of the same invoice written by hand on 0.6.0, with byte-identical PDFs (pooled medians of 29 runs). At 50 rows it is 0.67–0.80×. At 5 rows there is no gain (0.96–1.12×). The package import gets about 1.2–1.5 ms slower for every invoice, which misses the synthesis' budget of 0.2 ms (§7).

**Prototype.** Ten proofs. After the last verification round, equivalence (P1), no regression (P2), the payment block (P6) and the coat of arms (P7) pass on both compilers. Crash-freedom (P4) holds on the fault corpora (0 hard aborts in 69 faults and in 1406 corpus runs per compiler), but three classes of hostile input still stop a PDF/A build, and the performance budget for the import is missed. §11.5 lists what is open; none of it changes the API.

**What I need from you** (§14; each question has a recommendation): Q1 data errors as issues or panics; Q2 a restated budget for the package import; Q3 the performance gate on instruction counts instead of wall clock; Q4 the binding point of the line items; Q5 which e-invoice rules that depend only on the data should become data issues; Q6 the role of `document-type`; Q7 custom fields replaced or merged.

## Requirement coverage

| #   | Requirement (maintainer)                                                                                                           | Mechanism                                                                                                                                                                                                                         | Evidence                                                                                                                                                                                                                                                      | Where      |
| :-- | :--------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :--------- |
| 1   | One uniform data format, read from a file or from the system inputs                                                                | `invoice-pro/1`: one JSON object per invoice; TOML and YAML decode to the same values. `--input invoice-pro-data=<JSON>`, `--input invoice-pro-data-file=<path>` (read by the skeleton's one-line callback), stdin, a 0.15 `path` | P7: file, inline, stdin (redirect and pipe), TOML, YAML and the 0.15 path give one PDF (md5 `32b0b6d5d449` on 0.15.1, `679ee994c66b` on 0.14.2), equal to the hand-written twin on 0.6.0                                                                      | §3, §5     |
| 2   | Extensible: custom fields                                                                                                          | Open `custom` bags at document, party and line level; every other object is closed                                                                                                                                                | Unit test and custom probe of the build (`ctx.custom` via `info.get` and `dynamic`, `ctx.recipient.custom`); `view.items[i].custom` of data rows (§6.1)                                                                                                       | §3.8, §6.1 |
| 3   | Extensible: change something by a field value, such as a coat of arms by post code                                                 | The skeleton decides in Typst: a static theme patch chosen at document level from `invoice-data.values(record)` and `invoice-data.party(..)`; a draw-time wrap as the fallback                                                    | P7: 80331 → Bavaria, 20095 → Hamburg, 10115 → Berlin, 50667 → neutral, `custom.wappen` overrides; 28 logo crops checked by eye; the static patch keeps the e-invoice print checks active, the wrap does not                                                   | §2.1, §6.2 |
| 4   | Easy integration: build and design an invoice by hand, then hydrate the data into the skeleton                                     | `invoice(data: auto)`; a role per key (design, issuer, document); re-entry, so the signature's own defaults apply; the `line-items` body and `payment(..)` are the binding points                                                 | P1: 0 failures over a 36-case matrix, 1000-row cases, 13 edge fixtures and 660+ generated cases, byte-identical (XML included) to the hand-written invoice on 0.6.0; P3: no sample value leaks into a hydrated invoice                                        | §2, §4     |
| 5   | Fast: skip loom steps where possible                                                                                               | One bulk motif instead of one motif per row; pass 2 is a memo hit; sealed payloads; lazily imported modules                                                                                                                       | P9: 300 rows 0.571× / 0.568×; 50 rows 0.67–0.80×; 5 rows no gain; no contract module in the trace of an invoice without data                                                                                                                                  | §7         |
| 6   | Design and appearance stay in Typst; only the data is exchanged                                                                    | No design key in the format (closed objects); `theme`, `locale`, `references`, `zugferd`, `zugferd-errors`, `validation` pass through unchanged                                                                                   | Committed schema: every object `additionalProperties: false` except the three `custom` bags; P10: the 7 design parameters are classified and never read from data                                                                                             | §3.1, §4.2 |
| 7   | Extend the APIs, do not change them; justify every change                                                                          | 2 parameters, 2 root exports, 3 input keys, 1 label, 1 reserved party key; every other change is internal, hydrated-only or a bug fix                                                                                             | P2: 1105 documents per compiler unchanged except the intended near-miss panic; §9 marks and justifies L5, L7, L13, L15, L16 and the bug fixes                                                                                                                 | §9         |
| 8   | Phase 1: a general interface for the Typst CLI. Phase 2 (native bindings) is not in scope, but phase 1 should not stand in its way | CLI conventions with exit codes and a result record; committed JSON Schemas, conformance fixtures, code generation                                                                                                                | P5: schema and decoder agree on 135 + 51 fixtures and 3154 mutations; pydantic, TypeScript and Rust types generate and round-trip; P8: the result record is schema-valid in 450 of 450 cases, `typst eval` (0.15) and `typst query` (0.14) give the same JSON | §5, §10    |

## Design decisions at a glance

| #   | Decision                         | Choice                                                                                                                                                                           | Why                                                                                                                                  | Alternative / question                                          |
| :-- | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------- |
| 1   | Entry point                      | `invoice(data: auto)`; `auto` reads `--input invoice-pro-data`; also a record, a dictionary, JSON bytes or text, a 0.15 `path`                                                   | Data issues must join `invoice()`'s own checks: draft markers, the strict panic, the withheld XML                                    | Converters and `.with` (design A); body-only hydration (App. B) |
| 2   | Precedence                       | A role per key: design (never data), issuer (the skeleton's value unless the data gives it), document (from the data only; the skeleton's value is a sample)                     | A sample can never leak into a real invoice (P3)                                                                                     | Presence-only override (leaked `MUSTER-0001` into a clean XML)  |
| 3   | Defaults of absent document keys | **Re-entry**: the hydrated call calls `invoice(..effective, data: <marker>, body)` and leaves absent document keys out, so the signature's defaults apply                        | No second copy of the defaults that could drift                                                                                      | A private defaults table                                        |
| 4   | Merge                            | No deep merge: parties, `city`, `contact`, tax objects, `terms`, `bank` and `custom` are replaced as a whole; the `payment` section applies key by key                           | A merge can pair one party's VAT ID or BIC with another party's name or IBAN                                                         | Q20 (partial sender)                                            |
| 5   | Custom fields                    | Role document: the data's `custom` replaces the skeleton's sample `custom` as a whole                                                                                            | The same no-leak rule as every per-invoice value                                                                                     | Key-by-key merge, Q7                                            |
| 6   | Files                            | `--input invoice-pro-data-file=<path>`, opened by the skeleton: `invoice-data.load(read: p => read(p, encoding: none))`; JSON, TOML or YAML by extension; stdin via `/dev/stdin` | A package cannot open the user's files (0.14 and 0.15)                                                                               | A user-defined key per skeleton                                 |
| 7   | One source                       | A data input that nothing consumes, a misspelt data key, or two sources → panic with the one-line fix                                                                            | Otherwise a strict build ships the sample invoice                                                                                    | Ignore them (Q24)                                               |
| 8   | Line items                       | One bulk motif (design C's engine) emits the frames that `item`/`group`/`bundle`/`discount`/`surcharge`/`prepayment` would emit                                                  | Byte-identical output, 0.57× time at 300 rows                                                                                        | A motif per row                                                 |
| 9   | Binding point of the items       | The body of `line-items` (implicit); an optional `invoice-data.items[..]` marker keeps static rows; at most one, asserted                                                        | Every existing invoice hydrates without marks; a fixed fee is still possible                                                         | Marker required, or implicit only (Q4)                          |
| 10  | Payment                          | A `payment(..)` block that places `payment-terms`, `bank-details`, `direct-debit`, `card-payment` or `paid`                                                                      | Which payment components exist is data; one means per invoice (CII-SR-467/470)                                                       | Data-aware `payment-terms`/`bank-details` (Q11)                 |
| 11  | Decoder                          | Generic over one descriptor table (design D), crash-free: every value is pattern-checked before `decimal()`, `datetime()` or a constructor sees it                               | Typst has no try/catch; one descriptor gives the decoder, both JSON Schemas, the docs and the roles                                  | Hand-written decoders per key                                   |
| 12  | Encodings                        | Decimal strings, `"19%"`, ISO dates, `{start, end}` periods, UN/ECE unit codes or `{code, display}`, tax `"19%"` or an object; `null` and an optional `""` mean absent           | Exact money, bit-exact rates, one spelling per concept for code generators, spreadsheet cells                                        | Unit names and tax presets (Q21)                                |
| 13  | Errors                           | A data problem is a class-`data` issue `schema/<JSON Pointer>`; Typst misuse, a foreign format major and an unconsumed input panic                                               | Reuses draft/strict/none unchanged; ids are machine-readable                                                                         | Always panic (Q1)                                               |
| 14  | Namespace                        | `invoice-data`: `format`, `input-key`, `file-key`, `load`, `decode`, `check`, `values`, `party`, `items`, `schema`                                                               | Named after the parameter; `data` would be shadowed by `#let data = json(..)`; no Typst builtin shadowed by `import invoice-data: *` | `hydrate`, `data-format` (Q19)                                  |
| 15  | Result                           | `<invoice-pro-result>` (`invoice-pro-result/1`) on hydrated invoices, or with `--input invoice-pro-result=1`; loaded lazily                                                      | Pipelines read totals and the outcome; invoices without data pay nothing                                                             | On every invoice (Q8)                                           |
| 16  | Data-dependent design            | A static theme patch chosen at document level from `invoice-data.values(record)`                                                                                                 | Keeps the e-invoice checks of printed content (IP-PRINT-03, IP-PERIOD-03) active                                                     | A draw-time wrap (documented fallback)                          |
| 17  | Data-dependent parameters        | Issuer keys: Typst expressions on `values` in the skeleton; document keys: a `derive` hook in 0.7.x                                                                              | No expression language in data; a small 0.7.0 surface                                                                                | `derive` in 0.7.0 (Q17)                                         |
| 18  | Speed                            | One bulk motif; a pure `compute(rows, env)`, so pass 2 is a memo hit; sealed payloads; lazy modules; loom's two passes kept                                                      | Skipping pass 1 would gain only 0–5 % more and couple format and skeleton                                                            | A single pass (rejected, §7.2)                                  |
| 19  | Schemas and conformance          | JSON Schema 2020-12 for the data and the result, generated from the descriptor, committed under `src/contract/` with a drift check; 135 conformance fixtures                     | "Valid for the schema" must mean "accepted by invoice-pro"                                                                           | Generate at release only                                        |
| 20  | Versioning                       | `"format": "invoice-pro/1"` or `"invoice-pro/1.<minor>"`, required; SchemaVer; `$id` with the format major only, on the docs site                                                | Producers state the contract; `scripts/check-version` is unaffected                                                                  | Optional `format` (Q27)                                         |
| 21  | Tier                             | API experimental, format provisional                                                                                                                                             | Precedent: `from-data`, `zugferd`                                                                                                    | Provisional throughout (Q29)                                    |

---

## 1. Mental model and pipeline

> **The data states facts, the skeleton states rules and design, and `invoice()` decides what wins.**

```text
 skeleton.typ (written by hand, previews alone)        one JSON object, "invoice-pro/1"
   theme, locale, zugferd   design: never data           --input invoice-pro-data=<JSON>
   sender, bank, terms      issuer: kept unless the      --input invoice-pro-data-file=<path>
                            data gives them                (opened by the skeleton's `read`)
   invoice-nr, recipient,   document: samples, dropped   invoice(data: <record | dict | bytes | str | path>)
   line-items body, custom  when hydrated                        |
              \                                                  |
               +--------------> invoice(data: auto, ..) <--------+
                                  | 1 resolve the source: one source, nothing unconsumed (R7)
                                  | 2 decode once (pure, memoized): typed values + data issues
                                  |   `schema/<JSON Pointer>`; another format major panics
                                  | 3 region pass: VAT rates of the locale's region
                                  | 4 roles: design = skeleton, issuer = data else skeleton,
                                  |   document = data only
                                  | 5 RE-ENTER invoice(..effective, data: <applied marker>, body):
                                  v   absent document keys are left out -> the signature's defaults
                   the 0.6.0 path: type checks, normalisation, check-data, theme;
                   the data issues join the issue list (draft markers, strict panic, XML withheld)
                                  |
                   loom weave, two passes (unchanged)
                     line-items: the body is the items slot (or the invoice-data.items[..] marker)
                       -> ONE motif: compute(rows, env) emits item/group/bundle/modifier/
                          prepayment frames; the samples are dropped; pass 2 is a memo hit
                     payment(..): the data's payment section, key by key
                     root: coverage issues, validation level, e-invoice, result record
                                  v
   PDF (final or draft)  +  factur-x.xml (attached or withheld)  +  <invoice-pro-result>
```

Three properties carry the design:

- **The skeleton is an ordinary invoice.** Without data it renders its samples like any invoice, and an invoice without data renders byte-identical to 0.6.0 (P2). A skeleton needs no marks to be hydratable.
- **Hydration happens inside `invoice()`.** The data's values pass the same type checks, legal checks and e-invoice rules as values written in Typst, so a data problem is reported where every other problem is reported, and an incomplete e-invoice is never attached.
- **No default is copied.** A document key that the data lacks is left out of the re-entered call, so `invoice()`'s own signature decides. A new default in a later release applies to hydrated invoices automatically.

## 2. The workflow, step by step

### 2.1 Design the skeleton

The skeleton below is the prototype's `prototype/examples/skeleton.typ` without its import line. It previews alone, and it hydrates without edits.

```typst
// The data the CLI hands over (inline JSON or a file read here, so its path
// resolves against this project); `none` without input: the samples render.
#let record = invoice-data.load(read: p => read(p, encoding: none))
#let values = invoice-data.values(record)

// Samples: what identifies one invoice. Hydrated, they are dropped.
#let sample = (
  invoice-nr: "MUSTER-0001",
  date: datetime(year: 2026, month: 1, day: 15),
  recipient: (
    name: "Erika Mustermann",
    address: "Musterweg 1",
    city: "10115 Berlin",
    country: "DE",
  ),
  custom: (tarif: "Grundversorgung"),
)
// The values this invoice shows: the data's, else the samples.
#let shown = if values == none { sample } else { values }

// A design rule (Typst, never data): the coat of arms by the recipient's post
// code; the custom field `wappen` may name one directly. It is chosen here, at
// document level, as a static logo patch: the built-in logo part stays, so the
// e-invoice checks of printed content stay active.
#let arms = (
  bayern: "wappen/bayern.svg",
  berlin: "wappen/berlin.svg",
  hamburg: "wappen/hamburg.svg",
  muenchen: "wappen/muenchen.svg",
)
#let arms-by-plz = ("8": "bayern", "1": "berlin", "2": "hamburg")
#let wappen = {
  let custom = shown.at("custom", default: none)
  let key = if type(custom) == dictionary { custom.at("wappen", default: none) }
  if type(key) != str or key not in arms {
    let who = invoice-data.party(shown.at("recipient", default: none))
    let plz = who.at("post-code", default: none)
    key = if type(plz) == str and plz != "" {
      arms-by-plz.at(plz.first(), default: none)
    }
  }
  let file = if type(key) == str and key in arms { arms.at(key) } else {
    "wappen/neutral.svg"
  }
  image(file, alt: "Wappen")
}

#show: invoice.with(
  data: record,
  // design: never data
  theme: theme.classic.with(theme.custom.logo(image: wappen, height: 18mm)),
  locale: locale.de-de,
  zugferd: "en16931",
  // issuer: kept unless the data gives `sender`
  sender: (
    name: "Entsorgung Süd GmbH",
    address: "Industriestraße 7",
    city: "80339 München",
    country: "DE",
    vat-id: "DE123456789",
    contact: (
      name: "Buchhaltung",
      phone: "+49 89 1234567",
      email: "rechnung@entsorgung-sued.example",
    ),
  ),
  ..sample,
)

Tarif: #info.get("custom", "tarif", default: "Standard")

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

What makes it a skeleton, beyond an ordinary invoice:

- the `load` line and `data: record` (§2.5 says when you can leave them out);
- the per-invoice values are collected in `sample` and spread into `invoice`, so a design rule can read "the data's values, else the samples" (`shown`);
- `payment(..)` instead of `payment-terms(..)` plus `bank-details(..)`: it is the binding point of the data's `payment` section (§4.4).

### 2.2 Preview, then hydrate

```sh
# preview: the skeleton with its samples
typst compile skeleton.typ

# one invoice from a file (the canonical way); .toml, .yaml and .yml work by extension
typst compile --pdf-standard a-3b skeleton.typ out/2026-0042.pdf \
  --input invoice-pro-data-file=data/2026-0042.json

# for sending: any problem stops the build with exit code 1
typst compile --pdf-standard a-3b skeleton.typ out/2026-0042.pdf \
  --input invoice-pro-data-file=data/2026-0042.json --input invoice-pro-validation=strict
```

`--pdf-standard a-3b` is needed for the Factur-X/ZUGFeRD attachment. Inline JSON, stdin, batches and results are in §5.

### 2.3 What the data replaces

The data file is §3.11's example. Results of P7 on both compilers:

| Shown on the invoice    | Skeleton alone                         | Hydrated with `2026-0042.json`                                                         |
| :---------------------- | :------------------------------------- | :------------------------------------------------------------------------------------- |
| Title                   | "Rechnung MUSTER-0001"                 | "Rechnung 2026-0042"                                                                   |
| Recipient               | Erika Mustermann, 10115 Berlin         | Bayerische Beispiel AG, 80331 München                                                  |
| Coat of arms            | Berlin (post code 10115 of the sample) | München (`custom.wappen` overrides the Bavarian arms that 80331 would pick)            |
| Custom text             | "Tarif: Grundversorgung"               | "Tarif: Gewerbe M"                                                                     |
| Line items              | the two sample rows                    | the data's rows: 7 invoice lines (items, a group, a bundle), a surcharge, a prepayment |
| Letterhead, creditor ID | the skeleton's                         | the skeleton's (issuer keys the data does not give)                                    |
| Payment                 | transfer with account and EPC-QR code  | the data's direct debit; no account printed (CII-SR-467); the data's terms             |
| E-invoice               | EN 16931 XML attached                  | EN 16931 XML attached, 0 errors; totals net 532.59, VAT 85.12, due 517.71              |

The hydrated PDF is byte-identical to the same invoice written by hand on 0.6.0 (`prototype/examples/handwritten.typ`): md5 `32b0b6d5d449` on 0.15.1 and `679ee994c66b` on 0.14.2, the same for the file, inline JSON, stdin, TOML, YAML and the 0.15 `path` (P7).

### 2.4 A fixed fee next to the data rows

By default the whole body of `line-items` is a sample. To keep a row on every invoice, put the sample rows into the explicit marker; rows outside it stay:

```typst
#show: invoice.with(..party)

#line-items[
  #item("Grundgebühr", price: 9.9) // static: on every invoice
  #invoice-data.items[
    #item("Leerung Restmüll 120 l", quantity: 4, unit: unit.pcs, price: 12.5)
  ]
]
```

Without data the marker renders its sample exactly as written. With data, the data's rows take its place and the sample is never woven (it is held in a closure). A `line-items` may hold at most one marker, as a direct child (an `apply(..)` around it is allowed, dev. 1); a second marker, also one nested in a marker's sample, panics (dev. 2, 43).

### 2.5 When the `load` line is needed

| Skeleton                                | Inline `--input invoice-pro-data` | `--input invoice-pro-data-file` | Design rules on the data at evaluation time |
| :-------------------------------------- | :-------------------------------- | :------------------------------ | :------------------------------------------ |
| any 0.7.0 invoice, no change            | hydrates (`data: auto`)           | panics with the one-line fix    | no (draw-time rules only, §6.2)             |
| with the `load` line and `data: record` | hydrates                          | hydrates                        | yes (`invoice-data.values(record)`)         |
| `data: none`                            | panics: the input would be unused | panics                          | –                                           |

A package cannot open a path the user names, on 0.14 or 0.15. The file must be read by a function written in the skeleton, which is why `load` takes `read: p => read(p, encoding: none)`. A relative path resolves against the skeleton, `/…` against the project root.

## 3. The data format `invoice-pro/1`

The format is declared once, in a descriptor table (`src/contract/schema.typ`, prototype). The decoder, both JSON Schemas, the roles of the hydration and the reference tables below are read from it.

### 3.1 Principles

1. **One JSON object is one invoice.** JSON is canonical. TOML and YAML files decode to the same values (chosen by file extension); TOML dates arrive as native datetimes and are accepted. A UTF-8 byte order mark at the start of a file is tolerated.
2. **The canonical subset of the Typst API.** Keys are the kebab-case names of `invoice()`, of the party dictionaries and of the components. Where the Typst API has aliases (`street`, `region`, a flat `contact-name`, `phone` and `email`, a ship-to `location-id`, unit names), the format keeps exactly one spelling.
3. **A closed core with named open bags.** Every object is closed (`additionalProperties: false`). An unknown key is a data issue with a did-you-mean hint and, in parties, the hint of the e-invoice alias table (`plz` → "write the post code into `city`"). Openness lives only in the three `custom` bags.
4. **Facts, not rules.** No expression language, no `eval`, no theme, locale or layout in the data. Rules are Typst code in the skeleton (§6.3).
5. **Exact values.** Money and quantities are decimal strings, percentages carry `%`, dates are ISO strings.
6. **A lenient reader, a strict writer.** The JSON Schema says what producers must write. The decoder also reads four things that the schema rejects or does not type, each pinned by a `lenient` conformance fixture: JSON `null` (absent), JSON numbers where a decimal is expected (converted exactly through their shortest representation, after the same pattern check), native TOML dates, and `""` for an optional key of any type (dev. 36; the schema accepts `""` for texts only, because a `""` alternative would turn a generated date or enum type into a union).

### 3.2 Encodings

| Type       | JSON encoding                                                                                                                                                                                   | Typst value after decoding                                                                                                                       | Notes                                                                                                                                                                                                                             |
| :--------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| text       | `"2026-0042"`                                                                                                                                                                                   | `str`                                                                                                                                            | A JSON number is an issue (fix: `"42"`). At most 10 000 characters; `invoice-nr`, `subject` and a party `name` at most 4000 (§3.9). The noncharacters U+nFFFE and U+nFFFF are an issue.                                           |
| lines      | `"Muster GmbH"` or `["Muster GmbH", "Einkauf"]`                                                                                                                                                 | `str` / `array`                                                                                                                                  | `name`, `address`, `legal-info`, `management`. A required `lines` needs one filled line.                                                                                                                                          |
| decimal    | `"120.00"`, `"-5"`, `"0.5"`; pattern `^-?[0-9]{1,20}(\.[0-9]{1,10})?$`                                                                                                                          | `decimal`, scale kept (`"12.30"` stays 12.30)                                                                                                    | `"12,30"` and `"1e3"` are issues. At most 28 significant digits (`decimal()` rejects more; dev. 4). A JSON number is tolerated: `str(x)` must match the pattern, then `decimal(str(x))`, which is exact (49.90 → 49.9).           |
| integer    | `14`                                                                                                                                                                                            | `int`                                                                                                                                            | `"14"` is an issue; `14.0` is accepted, as JSON Schema does (dev. 23, 46).                                                                                                                                                        |
| boolean    | `true`                                                                                                                                                                                          | `bool`                                                                                                                                           |                                                                                                                                                                                                                                   |
| percent    | `"19%"`, `"2.5%"`, `"9.975%"`; pattern `^[0-9]{1,3}(\.[0-9]{1,6})?%$`                                                                                                                           | `ratio` = `float(n) / 100 * 100%`                                                                                                                | Bit-identical with the Typst literal (`infer-tax` and the VAT groups compare with `==`). A rate as `tax` must be > 0 (`percent-positive`), a cash discount in (0 %, 100 %) with at most 2 decimals (dev. 22, 38).                 |
| amount     | `"50.00"` (absolute) or `"10%"` (relative)                                                                                                                                                      | `decimal` / `ratio`                                                                                                                              | Modifiers and prepayments; never negative (`kind` gives the sign).                                                                                                                                                                |
| date       | `"2026-11-02"`                                                                                                                                                                                  | `datetime`                                                                                                                                       | Calendar-checked before `datetime()` (`"2026-02-30"` is an issue, not a crash). Years 1–9899 (dev. 4: Typst aborts past 9999-12-31, and a due date adds the payment days). TOML dates are native. A bare string is always a date. |
| period     | a date, or `{"start": "…", "end": "…"}`                                                                                                                                                         | `datetime` / `(datetime, datetime)`                                                                                                              | `end ≥ start`. No array form.                                                                                                                                                                                                     |
| tax        | `"19%"` (standard rate of the locale's region) or `{"category": "S" \| "Z" \| "E" \| "AE" \| "K" \| "G" \| "O" \| … (22 UNTDID 5305 codes), "rate"?, "grounds"?, "code"?: "VATEX-…", "label"?}` | `"19%"`: the ratio, resolved by the region's `infer-tax` as `tax: 19%` does; object: `tax.new(rate, category, label:, grounds:, code:)` (dev. 6) | `"16%"` in region `de` is an issue that names the object form (`infer-tax` would panic); the region pass leaves the value out, not the row (dev. 7). Category `S` needs a rate > 0.                                               |
| unit       | a UN/ECE Rec 20 code `"HUR"` (pattern `^[A-Z0-9]{2,3}$`), or `{"code"?: "KWH", "display": "kWh"}`                                                                                               | the 18 known codes: the localized, pluralized `unit.*`; other codes: `(code, display: code)`; object: `(code, display)`                          | Any Rec 20 code is accepted. `{display}` alone is a free-text unit; its XML code comes from the alias table, as in Typst.                                                                                                         |
| identifier | `"DE123"` or `{"scheme": "gln" \| "duns" \| "siren" \| "siret" \| "uid-ch" \| "leitweg" \| "register" \| "EM" \| "<4-digit ICD>", "id": "…", "court"?}`                                         | named schemes: the `id.*` constructor; others: `(scheme, id)`                                                                                    | Check digits of named schemes are checked by the e-invoice rule IP-ID-01, not by the decoder (Q5).                                                                                                                                |
| city       | `"10115 Berlin"` or `{"name": "Berlin", "post-code"?: "10115", "state"?}`                                                                                                                       | `str` / dictionary                                                                                                                               | A numeric `post-code` is an issue (leading zeros). The structured form gives design rules the post code without parsing.                                                                                                          |
| country    | `"DE"` (pattern `^[A-Za-z]{2}$`)                                                                                                                                                                | `str`                                                                                                                                            | `"Germany"` is an issue. A well-formed but unknown code (`"QQ"`) passes the decoder and stops at the e-invoice code list (BR-CL-14, Q5).                                                                                          |
| currency   | `"EUR"` (pattern `^[A-Z]{3}$`)                                                                                                                                                                  | `str`                                                                                                                                            | `"EURO"` is an issue; `"ZZZ"` stops at the code list (BR-CL-04, Q5).                                                                                                                                                              |
| enum       | `"exclusive"`                                                                                                                                                                                   | `str`                                                                                                                                            | did-you-mean on a typo                                                                                                                                                                                                            |
| item-id    | `"A-1"` (the seller's) or `{"seller"?, "buyer"?, "standard"?}`                                                                                                                                  | `str` / dictionary                                                                                                                               | BT-155/156/157                                                                                                                                                                                                                    |
| notes      | `"…"` or `["…", {"text": "…", "subject-code": "AAI"}]`                                                                                                                                          | as `invoice(notes:)`                                                                                                                             | BG-1 (BT-21/22)                                                                                                                                                                                                                   |
| custom     | any JSON object                                                                                                                                                                                 | a dictionary, values as decoded; `null` inside a bag stays `none`                                                                                | Never interpreted, never written into the e-invoice. Strings inside at most 10 000 characters, no noncharacters (dev. 37).                                                                                                        |

### 3.3 Absent, `null` and `""`

- **Absent ≡ `null` ≡ "not given"**, at every level, including the `kind` discriminator (`"kind": null` is an item). Generated models (pydantic `model_dump()`, serde without `skip_serializing_if`) write `null` for every unset field; the conformance fixtures contain such dumps, one with 143 nulls.
- **An optional `""` is absent, whatever the key's type** (dev. 36): a text, date, period, decimal, percent, amount, tax, unit, enum, integer, boolean or object, and `kind` (then the default case). This makes empty cells of spreadsheets and forms harmless. The schema accepts `""` for texts only; for typed keys it is the fourth reader leniency (§3.1). In the cross-field rules (exactly one, at most one, …) both the schema and the decoder count `""` as absent.
- **A required `""` is "must not be empty".** A required text needs at least one character that is not Unicode White_Space (the schema writes the class out, because `\s` differs between Python, ECMAScript and Rust, dev. 45), and a required `lines` needs a filled line (dev. 23). Before this rule, a blank recipient name gave a final e-invoice with BT-44 `,`.
- "Not given" means: for a document key, the `invoice()` default (`none`, or `(:)` for `recipient`); for an issuer key, the skeleton's value; inside line items, the component's `auto` (the cascade from group, `line-items`, `apply` or `invoice(tax:)`).
- `[]` clears an issuer list, such as the skeleton's `notes`.
- v1 cannot express an explicit `none` that cancels a cascaded value inside the items tree (a child without its group's `unit`): write the group without the key (Q23).
- `null` as an array element is an issue (`/items/3`), never skipped.
- _Open (Q13):_ an object whose keys are all absent still counts as given. `{"payment": {"terms": {"days": ""}}}` decodes to `terms: {}`, which replaces the skeleton's terms as a whole with empty terms, and no issue is raised (verification round 2).

### 3.4 The document (top level)

Roles: `doc` = from the data only (the skeleton's value is a sample), `iss` = the skeleton's value unless the data gives the key (then replaced as a whole), `→` = a binding point in the body, `meta` = checked, not passed on. **R** = required by the JSON Schema (`format`, `invoice-nr`, `date`, `recipient`, `items`).

| Key                      | Type                                                                                                                            | R   | Role            | Absent →                                                                                | EN 16931           |
| :----------------------- | :------------------------------------------------------------------------------------------------------------------------------ | :-- | :-------------- | :-------------------------------------------------------------------------------------- | :----------------- |
| `$schema`                | text                                                                                                                            |     | meta            | not read (editor hint)                                                                  |                    |
| `format`                 | `"invoice-pro/1"` or `"invoice-pro/1.<minor>"`                                                                                  | R   | meta            | issue `schema/format`; another major panics                                             |                    |
| `invoice-nr`             | text (≤ 4000)                                                                                                                   | R   | doc             | `none` → check-data "missing" (inline marker ‹fehlt: Rechnungsnummer›)                  | BT-1               |
| `date`                   | date                                                                                                                            | R   | doc             | issue `schema/date`; the value falls back to today (pin it with `--creation-timestamp`) | BT-2               |
| `document-type`          | `"invoice"`, `"credit-note"`, `"corrected"`, `"prepayment"`, `"self-billed"`, `"self-billed-credit-note"` or a UNTDID 1001 code |     | iss (Q6)        | the skeleton's (`auto` = 380)                                                           | BT-3               |
| `currency`               | currency                                                                                                                        |     | iss             | the skeleton's (`auto` = the locale's)                                                  | BT-5               |
| `due-date`               | date                                                                                                                            |     | doc             | `none`                                                                                  | BT-9               |
| `service-period`         | period                                                                                                                          |     | doc             | `none`                                                                                  | BT-72, BG-14       |
| `subject`                | text (≤ 4000)                                                                                                                   |     | iss             | the skeleton's (`auto`)                                                                 | (title)            |
| `notes`                  | notes                                                                                                                           |     | iss             | the skeleton's; `[]` clears                                                             | BG-1               |
| `customer-nr`            | text                                                                                                                            |     | doc             | `none`                                                                                  | printed only       |
| `order-nr`               | text                                                                                                                            |     | doc             | `none`                                                                                  | BT-13              |
| `order-date`             | date                                                                                                                            |     | doc             | `none`                                                                                  | printed only       |
| `project`                | text                                                                                                                            |     | doc             | `none`                                                                                  | BT-11              |
| `contract-nr`            | text                                                                                                                            |     | doc             | `none`                                                                                  | BT-12              |
| `quote-nr`               | text                                                                                                                            |     | doc             | `none`                                                                                  | printed only       |
| `delivery-note-nr`       | text                                                                                                                            |     | doc             | `none`                                                                                  | BT-16              |
| `preceding-invoice-nr`   | text                                                                                                                            |     | doc             | `none`                                                                                  | BT-25              |
| `preceding-invoice-date` | date                                                                                                                            |     | doc             | `none`                                                                                  | BT-26              |
| `payment-reference`      | text (≤ 140)                                                                                                                    |     | doc             | `none` (= the invoice number)                                                           | BT-83              |
| `sender`                 | seller (§3.5)                                                                                                                   |     | iss             | the skeleton's letterhead                                                               | BG-4               |
| `recipient`              | buyer (§3.5)                                                                                                                    | R   | doc             | `(:)` → check-data "missing" (name, address)                                            | BG-7               |
| `delivery-address`       | ship-to (§3.5)                                                                                                                  |     | doc             | `none`                                                                                  | BG-13, BG-15       |
| `payee`                  | payee (§3.5)                                                                                                                    |     | iss             | the skeleton's                                                                          | BG-10              |
| `tax`                    | tax                                                                                                                             |     | iss             | the skeleton's (`auto`)                                                                 | BG-23              |
| `tax-mode`               | `"exclusive"` or `"inclusive"`                                                                                                  |     | iss             | the skeleton's                                                                          |                    |
| `tax-exempt-small-biz`   | boolean; `true` excludes `tax`                                                                                                  |     | iss             | the skeleton's                                                                          | BT-118 = E, BT-120 |
| `items`                  | row array (§3.6)                                                                                                                | R   | → items slot    | the sample is dropped; empty → check-data "no line items"                               | BG-25              |
| `modifiers`              | modifier array (§3.6)                                                                                                           |     | → items slot    | none                                                                                    | BG-20, BG-21       |
| `prepayments`            | prepayment array (§3.6)                                                                                                         |     | → items slot    | none                                                                                    | BT-113             |
| `payment`                | payment (§3.7)                                                                                                                  |     | → `payment(..)` | the skeleton's block: issuer settings kept, document details dropped                    | BG-16 … BG-19      |
| `custom`                 | custom                                                                                                                          |     | doc (Q7)        | `none` (the skeleton's sample custom is dropped)                                        |                    |

- **Document types** are exactly those `invoice()` accepts (dev. 24): the six names, where `self-billed-credit-note` maps to code 261, and the UNTDID 1001 codes of `src/logic/document-type.typ` (including the two-digit codes 71–84; codes that `invoice()` rejects, such as `001` or `999`, are issues).
- **Small business vs. tax, across layers** (dev. 8): the data's `"tax-exempt-small-biz": true` drops the skeleton's `tax`; the data's `tax` under the skeleton's exemption is an issue `schema/tax` (`invoice()` would panic); both in the data at once is an issue too.
- **Not in the format** (design or configuration, skeleton only): `theme`, `locale`, `references` (the header layout; its values come from the keys above), `zugferd`, `zugferd-errors`, `validation`, `tax-nr` (the deprecated `invoice()` parameter), the layout options of the components (`show-column`, `show-total`, `qr-code`, `show-reference`, …), the signature.

### 3.5 Parties

Every party has `name` (lines, **R**; at most 4000 characters with all its lines, joined by a space as the PDF metadata takes them), `address` (lines), `city`, `country`, `extra` (label → text, printed only, order kept) and `custom` (an open bag; printed by invoice-pro nowhere, never written into the e-invoice).

| Party (`invoice()` key)      | Further keys (type → EN 16931)                                                                                                                                                                                                                                                                                                                                                                                            |
| :--------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| seller (`sender`)            | name BT-27, address BT-35/36, city BT-37/38 (state BT-39), country BT-40; `trading-name` BT-28; `id`, `global-id` identifier BT-29; `legal-id` identifier BT-30; `vat-id` BT-31; `tax-nr` BT-32; `legal-info` lines BT-33; `electronic-address` identifier BT-34; `contact` `{name, phone, email}` BG-6; `tax-representative` `{name R, address, city, country, vat-id R}` BG-11; `register`, `management` (printed only) |
| buyer (`recipient`)          | name BT-44, address BT-50/51, city BT-52/53 (state BT-54), country BT-55; `trading-name` BT-45; `id`, `global-id` BT-46; `legal-id` BT-47; `vat-id` BT-48; `electronic-address` BT-49; `contact` BG-9; `buyer-reference` **or** `leitweg-id` BT-10 (the schema forbids both); `tax-nr` (printed only)                                                                                                                     |
| ship-to (`delivery-address`) | name BT-70, address BT-75/76, city BT-77/78, country BT-80; `id`, `global-id` BT-71                                                                                                                                                                                                                                                                                                                                       |
| payee (`payee`)              | `name` R BT-59, `id`, `global-id` BT-60, `legal-id` BT-61, `custom`; no address keys, no `extra`                                                                                                                                                                                                                                                                                                                          |

The key sets mirror `party-keys` of `src/zugferd/model.typ` minus its aliases. `custom` becomes a known print-only key there (L13), so `ctx.recipient.custom` and `view.recipient.custom` reach theme parts without an IP-KEY-01 warning. Party custom fields travel unsealed in the loom context; keep them small and put large payloads into the document's `custom`, which is sealed. `management` given as lines prints one line per entry; in 0.6.0 it crashed, also when written by hand (dev. 39, a bug fix).

### 3.6 Line items

`items` is the print-ordered tree that mirrors the body of `line-items`. A row's `kind` is `"item"` (the default, also when absent, `null` or `""`), `"group"` or `"bundle"`. The bulk motif emits, in this order, the frames of `items`, then `modifiers`, then `prepayments`: what a hand-written body in that order produces. A bundle's modifiers follow its items, as in a hand-written bundle.

**item** → `item(name, ..)`

| Key             | Type            | Absent →                                                | Feeds `item(..)`                                                   | EN 16931     |
| :-------------- | :-------------- | :------------------------------------------------------ | :----------------------------------------------------------------- | :----------- |
| `kind`          | `"item"`        | item                                                    | –                                                                  |              |
| `name`          | text, **R**     | the row is dropped, with an issue                       | `name`                                                             | BT-153       |
| `description`   | text            | `auto` (cascade)                                        | `description`                                                      | BT-154       |
| `quantity`      | decimal         | `auto` (cascade, else 1)                                | `quantity`                                                         | BT-129       |
| `base-quantity` | decimal > 0     | `auto` (1)                                              | `base-quantity`                                                    | BT-149       |
| `unit`          | unit            | `auto` (cascade)                                        | `unit`                                                             | BT-130       |
| `price`         | decimal         | exactly one of `price`/`total`, else the row is dropped | `price` (net, or gross with `inclusive`)                           | BT-146       |
| `total`         | decimal         |                                                         | `total`                                                            | BT-131       |
| `date`          | period          | `auto` (cascade)                                        | `date`                                                             | BG-26        |
| `tax`           | tax             | `auto` (cascade, `line-items(tax:)`, `invoice(tax:)`)   | `tax`                                                              | BG-30        |
| `input-gross`   | boolean         | `auto`                                                  | `input-gross`                                                      |              |
| `item-id`       | item-id         | `auto`                                                  | `item-id`                                                          | BT-155 … 157 |
| `reference`     | text            | `auto`                                                  | `reference`                                                        | BT-133       |
| `note`          | text            | `auto`                                                  | `note`                                                             | BT-127       |
| `origin`        | country         | `auto`                                                  | `origin`                                                           | BT-159       |
| `modifiers`     | item-modifier[] | none                                                    | the item's discounts and surcharges                                | BG-27, BG-28 |
| `custom`        | custom          | none                                                    | the item signal → `view.items[i].custom`, `view.entries[j].custom` |              |

**group** → `group(name, ..)[..]`: `kind: "group"` **R**, `name` **R**, `description`, `show-subtotal`, and the cascaded `tax`, `input-gross`, `date`, `unit`; `items` **R** (item, group or bundle). No `modifiers`: put them on the items, as in Typst.

**bundle** → `bundle(name, ..)[..]`: `kind: "bundle"` **R**, `name` **R**, `description` (absent: built from its items, as `bundle()` does), `quantity`, `base-quantity`, `unit`, `date`, `input-gross`, `tax`, `item-id`, `reference`; `items` **R**, at least one (item or bundle, no group); `modifiers`. One printed line per VAT rate, as `bundle()`.

**modifier** (document and bundle level) → `discount(..)` / `surcharge(..)`: `kind` **R** (`"discount"` or `"surcharge"`), `name` **R** (the reason, BT-97/BT-104), `amount` **R** (BT-92/BT-99, a percentage BT-94/BT-101), `label`, `description`, `tax` (pins it to one VAT category; absent = split over the VAT groups), `input-gross`.

**item-modifier** (in an item's `modifiers`): the same without `tax` (dev. 3). `item.typ` panics when a modifier of an item pins another VAT category, so the format has no such key; `tax` there is an unknown-key issue.

**prepayment** (in `prepayments`) → `prepayment(amount, ..)`: `amount` **R** (`"100.00"` or a share of the gross total `"30%"`, BT-113), `name`, `label`, `date`, `reference`, `description`, `method`.

**Rules the decoder checks.** They replace the guards of the components, which do not run for data rows:

- groups and bundles nest at most **8** levels; deeper rows are rejected before they are decoded (dev. 4). `collect-signals(depth: 10)` in `calculate-modifier` silently drops deeper items from the totals today (L24);
- a document or bundle modifier without `tax` needs at least one valid taxed row in its scope, after invalid rows were dropped;
- exactly one of `price` and `total`; `base-quantity` > 0, and ≥ 0.0001 after rounding to 4 decimals (the guard of `calc-item`);
- `|price × quantity ÷ base-quantity| < 10^18`;
- `note` and `origin` are dropped from items inside a bundle (design C's rule); a bundle without a valid item is dropped;
- a row that lacks what it needs is dropped as a whole and reported; a valid row never depends on an invalid sibling; never more than the offending row is dropped.

Hydrated only, `modifier-applicator` turns one more guard into a data issue (dev. 28): an absolute modifier without `tax` whose items have no VAT group, or whose two or more groups add up to 0, is left out with the issue `schema/modifiers`. Written in Typst, the same modifier still panics.

### 3.7 Payment

A transfer is `"payment": {"terms": {"days": 14}, "method": "transfer", "bank": {"iban": "DE75…", "bic": "SOLADEST600"}}`; a direct debit gives `"method": "direct-debit"` and `"direct-debit": {"mandate": .., "debtor-iban": ..}` instead, plus `creditor-id` when the skeleton has none (§3.11 shows one).

| Key            | Type                                                                                                                                                       | Role | Absent →                                                                 | EN 16931                          |
| :------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------- | :--- | :----------------------------------------------------------------------- | :-------------------------------- |
| `terms`        | `{days? (0–36 500) \| date? \| text?, discount?: [{days R (1–36 500), percent R (0 % < p < 100 %, ≤ 2 decimals), basis?}]}`; at most one of days/date/text | iss  | the skeleton's `payment(terms:)`                                         | BT-20 (text, Skonto), BT-9 (date) |
| `method`       | `"transfer"`, `"direct-debit"`, `"card"` or `"paid"`                                                                                                       | iss  | the method whose details are given, else the skeleton's, else a transfer | BT-81                             |
| `bank`         | `{iban R, bic?, bank?, name?}`                                                                                                                             | iss  | the skeleton's account (replaced as a whole)                             | BG-17 (BT-84/85/86)               |
| `creditor-id`  | text                                                                                                                                                       | iss  | the skeleton's                                                           | BT-90                             |
| `direct-debit` | `{mandate R, debtor-iban?}`                                                                                                                                | doc  | dropped: a sample mandate never survives                                 | BG-19 (BT-89, BT-91)              |
| `card`         | `{last4 R (4–6 digits, text), holder?, kind?: "credit" \| "debit"}`                                                                                        | doc  | dropped                                                                  | BG-18 (BT-87/88)                  |
| `paid`         | `{method?: "cash" \| "cheque" \| "online" \| "transfer" \| "card" \| "direct-debit", date?}`                                                               | doc  | dropped                                                                  | BT-81, BT-113                     |

`payment.terms.text` is the only way to write free-text payment terms (BT-20). This removes the trap of the Typst API that a string `due-date` is terms text: in the data a bare string is always a date.

Rules (schema and decoder unless marked):

- at most one of `direct-debit`, `card` and `paid`; never `paid` together with `terms`;
- details without `method` select their method; details of one method with another `method` (`"method": "transfer"` with `card`) are an issue and left out (dev. 25a);
- a method whose required details are missing (no mandate, no last4) is an issue, and its component is left out;
- _hydrated only_ (`payment(..)`, dev. 25b, 42): a credit note or a self-billed invoice drops a cash discount, a direct debit or a card payment with a data issue, whether the data's or the skeleton's (their senders pay; the components panic for Typst authors). The same treatment is still missing for the raw components `direct-debit(..)` and `card-payment(..)` in a skeleton (Q10);
- _hydrated only_ (dev. 25c, 41): a transfer without any account is an issue when the data chose it, when it replaced the skeleton's own method, or when the data says paid by transfer. A skeleton's own transfer without a bank stays as written (it equals the hand-written components);
- a data `bank` with another method (card, direct debit, paid cash or card) is left out **without** an issue, like the skeleton's own account: an invoice states one payment means (CII-SR-467), and `bank` is standing issuer data (dev. 41, Q12);
- a `bank` without IBAN stays a partial object, so the decoder and `bank-details` each report it (two issues, by design, dev. 25); a `direct-debit` without `mandate` is likewise reported by the decoder and by the payment block.

### 3.8 Custom fields

| Level    | Where in the data                                                              | Where the skeleton reads it                                                                                                                                          | Stored                                                    |
| :------- | :----------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------- |
| document | `custom`                                                                       | at evaluation time `invoice-data.values(record).custom`; theme parts and wraps `ctx.custom.x`; the body `info.get("custom", "x", default: ..)`, `dynamic(ctx => ..)` | `ctx.custom`, sealed in `metadata`, so its size costs ≈ 0 |
| party    | `sender.custom`, `recipient.custom`, `delivery-address.custom`, `payee.custom` | `ctx.recipient.custom`, `view.recipient.custom`, `info.get("recipient", "custom", "x")`, at evaluation time through `values`                                         | the normalised party (unsealed: keep it small)            |
| item     | `items[..].custom` at any depth                                                | `view.items[i].custom`, `view.entries[j].custom` in table parts, wraps and hooks                                                                                     | the item signal                                           |

v1 bags are open and untyped. Declared, typed custom fields with a schema export are a 0.7.x follow-up (Q17).

### 3.9 Limits the decoder checks and the schema does not

The JSON Schema cannot state these without breaking the code generators (a `maxLength` on every string makes typify wrap every string in a newtype; `if`/`then` makes it panic). They are pinned by `decoder-only` conformance fixtures.

| Rule                                                                                    | Why                                                                                                                                                                      | Source    |
| :-------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------- |
| a decimal has at most 28 significant digits                                             | `decimal()` aborts on 29–30 digits, which the pattern admits                                                                                                             | dev. 4    |
| `\|price × quantity ÷ base-quantity\| < 10^18`; `base-quantity` ≥ 0.0001 after rounding | the guards of `calc-item`                                                                                                                                                | dev. 4    |
| a text has at most 10 000 characters                                                    | a longer unbroken word exceeds the 32 767-byte string limit of PDF/A                                                                                                     | dev. 4    |
| `invoice-nr`, `subject`, a party `name` (all lines) at most 4000 characters             | they become the PDF title, description and author, which PDF/A writes in UTF-16 (the schema has `maxLength: 4000` on the plain strings; the lines total is decoder-only) | dev. 37   |
| strings inside `custom` at most 10 000 characters                                       | the same PDF/A limit, when a skeleton prints them                                                                                                                        | dev. 37   |
| no noncharacters U+nFFFE, U+nFFFF in a text or a custom string                          | no font has a glyph; PDF/A stops                                                                                                                                         | dev. 37   |
| a date's year is 1–9899                                                                 | Typst aborts past 9999-12-31 (a Rust panic, exit 101); the due date adds up to 36 500 days                                                                               | dev. 4    |
| nesting at most 8, rejected before the descent                                          | the totals bug (L24) and Typst's call-depth limit (reached at depth ≥ 24)                                                                                                | dev. 4    |
| the region's VAT rates                                                                  | `infer-tax` panics on an unknown rate                                                                                                                                    | dev. 7    |
| the modifier VAT scope                                                                  | "modifier has no items to take its VAT category from" crashed all four design prototypes                                                                                 | synthesis |

### 3.10 Versioning

- `format` is required: `"invoice-pro/1"` (minor 0) or `"invoice-pro/1.<minor>"` (the minor the data needs). Version numbers of any length are read without an integer overflow (fix 1).
- SchemaVer: a new optional key is a new minor; a rename, a removal or a changed meaning is a new major. Closed objects keep additions additive.
- Data written for a newer minor: an unknown key's message adds "The data is written for invoice-pro/1.2; this invoice-pro reads invoice-pro/1.0: update invoice-pro, or leave the key out."
- Another major: `invoice()` panics with "invoice data is in format "invoice-pro/2"; this invoice-pro reads invoice-pro/1 only. Convert the data, or use an invoice-pro that reads invoice-pro/2."; `invoice-data.check` reports it as an issue.
- Every key records `since` (`x-invoice-pro-since` in the schema; 189 annotations). The `$id` carries the format major only, not the package version, so `scripts/check-version` is unaffected. The schemas are to be hosted on the documentation site (patch 0010): `https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/invoice.schema.json` and `…/invoice-pro/1/result.schema.json`.

### 3.11 A complete example

`prototype/data/2026-0042.json`. The recipient's structured post code 80331 drives the skeleton's coat-of-arms rule; the custom field `wappen` overrides it. Custom fields appear at all three levels.

```json
{
  "$schema": "https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/invoice.schema.json",
  "format": "invoice-pro/1",
  "invoice-nr": "2026-0042",
  "date": "2026-11-02",
  "service-period": { "start": "2026-10-01", "end": "2026-10-31" },
  "customer-nr": "K-10077",
  "order-nr": "PO-7781",
  "project": "Gewerbeentsorgung 2026",
  "notes": [
    "Vielen Dank für Ihren Auftrag.",
    {
      "text": "Leistungen gemäß Rahmenvertrag RV-2025-03.",
      "subject-code": "AAI"
    }
  ],
  "recipient": {
    "name": "Bayerische Beispiel AG",
    "address": ["Marienplatz 8", "z. Hd. Einkauf"],
    "city": { "name": "München", "post-code": "80331" },
    "country": "DE",
    "vat-id": "DE987654321",
    "buyer-reference": "04011000-1234512345-06",
    "electronic-address": "einkauf@beispiel-ag.example",
    "contact": {
      "name": "Max Einkauf",
      "email": "einkauf@beispiel-ag.example"
    },
    "custom": { "segment": "enterprise", "bezirk": "Altstadt-Lehel" }
  },
  "items": [
    {
      "name": "Leerung Restmüll 1100 l",
      "quantity": "8",
      "unit": "H87",
      "price": "38.90",
      "tax": "19%",
      "date": { "start": "2026-10-01", "end": "2026-10-31" },
      "item-id": { "seller": "RM-1100" },
      "custom": { "behaelter": "RM-1100-0815" }
    },
    {
      "kind": "group",
      "name": "Sonderleistungen",
      "show-subtotal": true,
      "items": [
        {
          "name": "Sperrmüllabholung",
          "date": "2026-10-17",
          "price": "45.00",
          "tax": "19%"
        },
        {
          "name": "Behälterreinigung",
          "quantity": "2",
          "unit": "H87",
          "price": "15.00",
          "tax": "19%",
          "modifiers": [
            { "kind": "discount", "name": "Kulanz", "amount": "50%" }
          ]
        },
        {
          "name": "Gutachten Abfallbilanz",
          "total": "80.00",
          "tax": {
            "category": "E",
            "grounds": "Steuerfrei nach § 4 Nr. 21 UStG",
            "code": "VATEX-EU-132"
          }
        }
      ]
    },
    {
      "kind": "bundle",
      "name": "Starterpaket Gewerbe",
      "quantity": "1",
      "unit": "SET",
      "items": [
        { "name": "Wertstofftonne 240 l", "price": "29.00", "tax": "19%" },
        { "name": "Sortierleitfaden (Druck)", "price": "4.50", "tax": "7%" }
      ],
      "modifiers": [
        { "kind": "discount", "name": "Paketpreis", "amount": "3.50" }
      ]
    },
    {
      "name": "Strom Presscontainer",
      "quantity": "120",
      "unit": { "code": "KWH", "display": "kWh" },
      "price": "0.32",
      "tax": "19%"
    }
  ],
  "modifiers": [
    { "kind": "surcharge", "name": "Energiekostenzuschlag", "amount": "2.5%" }
  ],
  "prepayments": [
    {
      "amount": "100.00",
      "name": "Abschlag Oktober",
      "date": "2026-10-05",
      "reference": "AB-2026-0117"
    }
  ],
  "payment": {
    "terms": { "days": 14, "discount": [{ "days": 7, "percent": "2%" }] },
    "method": "direct-debit",
    "direct-debit": {
      "mandate": "MND-2025-0815",
      "debtor-iban": "DE02120300000000202051"
    }
  },
  "custom": {
    "tarif": "Gewerbe M",
    "wappen": "muenchen",
    "kampagne-ende": "2026-12-31"
  }
}
```

Hydrating the skeleton of §2.1 with this file gives "Rechnung 2026-0042" with the München arms, the skeleton's letterhead and creditor ID, the data's terms (14 days, 2 % within 7 days) in place of the skeleton's terms, the direct-debit sentence without an account or QR code, "Tarif: Gewerbe M" and an attached EN 16931 XML. Its result record (§5.4) states net 532.59, VAT 85.12, gross 617.71, prepaid 100.00 and due 517.71 EUR, three VAT groups (19 %, 7 %, exempt with VATEX-EU-132) and 7 invoice lines.

## 4. The Typst API

### 4.1 `invoice()`: two new parameters

They follow `validation` and precede `body`; callers name them, so the position is invisible. The doc comments are the prototype's.

```typst
#let invoice(
  // … the parameters of 0.6.0, unchanged, up to `validation` …
  /// Fields of your own, which invoice-pro does not interpret: theme parts
  /// read them as `ctx.custom`, the body as `info.get("custom", ..)`. A
  /// preview sample: a hydrated invoice takes its custom fields from the data
  /// alone.
  /// -> none | dictionary
  custom: none,
  /// The data of the invoice (format "invoice-pro/1"), to hydrate this call
  /// as a skeleton. What identifies one invoice (number, dates, recipient,
  /// delivery address, references, line items, the details of a direct
  /// debit, card or paid invoice, custom fields) then comes from the data
  /// alone: the skeleton's values for it are preview samples. The issuer's
  /// settings (sender, payee, currency, subject, document type, notes, tax
  /// settings, payment terms, method and bank) keep the skeleton's value
  /// unless the data gives them, as a whole. Design never comes from data.
  /// Problems in the data are `data` issues (see `validation`).
  ///
  /// `auto`: the JSON of `--input invoice-pro-data` if it is given, else the
  /// invoice is not hydrated. Also: a record of `invoice-data.load(..)` or
  /// `invoice-data.decode(..)`, a dictionary (`json(..)`, `toml(..)`,
  /// `yaml(..)`), JSON as bytes or text, or (Typst 0.15) a `path`.
  /// -> auto | none | dictionary | bytes | str | content
  data: auto,
  /// The content of the invoice, typically containing line-items and other components.
  /// -> content
  body,
) = {
  /* … */
}
```

### 4.2 Hydration: re-entry and the precedence rules

**The algorithm** (`src/invoice.typ` +95 lines in the prototype; the rest lives in the lazily imported `src/contract/hydrate.typ`):

1. If `data` is the internal _applied marker_ (sealed `metadata((kind: "invoice-pro-applied", ..))`), this is the second call: go to step 5.
2. If `data` is `auto` or `none` and no `--input` key starts, after normalisation, with `invoiceprodata`, the invoice is not hydrated: the 0.6.0 path runs unchanged. At run time, this is the only cost of an invoice without data: one scan over the keys of `sys.inputs` (the parse cost of the new code is in §7.3).
3. Otherwise `hydrate(data, given)` resolves the source (the R7 checks, §8.1), decodes it into a record unless it is one, panics on another format major, runs the region pass with the locale's region and VAT rates, and builds the effective arguments from the class of each parameter (`invoice-params` in `src/contract/schema.typ`):
   - `design`: passed through unchanged (`theme`, `locale`, `references`, `zugferd`, `zugferd-errors`, `validation`, `tax-nr`);
   - `issuer`: `values.at(key, default: <the skeleton's value>)`;
   - `document` (and `custom`): inserted only when the data has the key. **An absent key is left out, so the signature's own default applies**;
   - any other class panics as an internal error (dev. 33).
4. It re-enters: `return invoice(..effective, data: <applied marker>, body)`. The marker carries the data issues and the sealed body sections (`rows`, `payment`, the format). Issues `schema-required` of `/invoice-nr`, `/recipient`, `/recipient/name` and `/items` are dropped from it, because `check-data` reports these once, with the inline marker and the legal reference.
5. The second call runs the existing type checks and normalisation on the effective values. The marker's issues join `check-data`'s issues. `hydration: metadata(sections)` and `custom: metadata(custom)` join the loom inputs only when given, sealed like the theme.

**The rules** (layers, lowest first: the `invoice()` defaults, then the skeleton's arguments, then the data):

| #   | Rule                                                                                                                                                                                     | Applies to                                                                                |
| :-- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------- |
| R1  | **Design is never data.** The format has no key for it.                                                                                                                                  | theme, locale, references, zugferd, zugferd-errors, validation, layout options, body text |
| R2  | **Document keys come from the data alone.** Absent: the signature's default (re-entry). Missing required data is reported by `check-data` and the decoder.                               | role `document` (§3.4), `custom`                                                          |
| R3  | **Issuer keys keep the skeleton's value unless the data gives the key**, which then replaces it as a whole. The small-business exemption and `tax` exclude each other across layers.     | role `issuer`                                                                             |
| R4  | **The payment section applies key by key** by its roles (§3.7).                                                                                                                          | `payment.*`                                                                               |
| R5  | **The items slot is replaced, never appended.** The sample at the binding point is dropped; `items`, `modifiers` and `prepayments` take its place. Rows outside an explicit marker stay. | binding point (§4.5)                                                                      |
| R6  | **No deep merge.** Parties, `city`, `contact`, tax objects, `terms`, `bank` and `custom` are values.                                                                                     | everywhere                                                                                |
| R7  | **One source.** A data input and an explicit non-record `data:` together panic; an input nothing consumes panics; a misspelt data key (`invoice-pro-data-fil`) panics (dev. 26).         | `data`, `--input`                                                                         |
| R8  | **`null` and an optional `""` are absent** (§3.3).                                                                                                                                       | everywhere                                                                                |

**The classes of the 35 `invoice()` parameters** (P10): design 7, document 17, issuer 9, data 1 (`data`), body 1. Typst cannot list a function's parameters, so `tools/contract/signature.py` parses the signature and the `hydrate(..)` call and fails when a parameter is unclassified, when a classified key no longer exists, or when a class is unknown. It runs on 0.14 through `typst query` and is wired into `.github/workflows/tests.yaml` (dev. 33, 47). Its parser still has blind spots (§11.5).

### 4.3 The `invoice-data` namespace

`src/public/invoice-data.typ` is a facade: each function imports its module inside its body, so the package import parses only these signatures and doc comments. `import invoice-data: *` shadows no Typst builtin. The doc comments below are the prototype's; the bodies are elided.

```typst
/// The invoice data format this version reads: `"invoice-pro/1"`.
/// -> str
#let format = "invoice-pro/1"

/// The `--input` key that carries the data of one invoice as JSON text.
/// -> str
#let input-key = "invoice-pro-data"

/// The `--input` key that names a data file (JSON, TOML or YAML), opened by
/// the skeleton's `read` callback (see `load`).
/// -> str
#let file-key = "invoice-pro-data-file"

/// Decodes and validates data without rendering: a record for
/// `invoice(data:)`, `values` and `check`. Never panics on bad data (problems
/// become issues with JSON Pointers); `region` adds the region checks
/// invoice() makes with its locale (e.g. `"16%"` is no VAT rate of `"de"`).
/// -> content
#let decode(
  /// A dictionary (`json(..)`, `toml(..)`, `yaml(..)`), JSON as bytes or
  /// text, or (Typst 0.15) a `path`.
  /// -> dictionary | bytes | str
  data,
  /// -> none | str
  region: none,
) = {
  /* … */
}

/// The record of the data the CLI hands over, for `invoice(data: ..)`:
/// the JSON text of `--input invoice-pro-data` (or a dictionary an embedder
/// passes), or the file named by `--input invoice-pro-data-file`, opened with
/// `read`. A package cannot open your files: pass
/// `p => read(p, encoding: none)`, written in your file; a relative path
/// resolves against that file, `/…` against the project root, `/dev/stdin`
/// reads stdin (with `--root /`). The file extension picks the decoder
/// (`.json`, `.toml`, `.yaml`, `.yml`; a UTF-8 BOM is tolerated). `none`
/// without input: the skeleton renders its samples.
/// -> none | content
#let load(
  /// The skeleton's reader, `p => read(p, encoding: none)`. Without it, a
  /// given `--input invoice-pro-data-file` panics with this fix.
  /// -> none | function
  read: none,
  /// The CLI inputs; injectable for tests (tytanic cannot pass `--input`).
  /// -> dictionary
  inputs: sys.inputs,
) = {
  /* … */
}

/// A JSON-friendly validation report, layout-free (CI, phase-2 bindings):
/// `(format: "invoice-pro-check/1", valid: bool,
///   issues: ((id, path, key, message, fix), ..))`. What the decoder checks
/// (the JSON Schema and its own rules); an invoice can still report more
/// when it is hydrated (rules of the skeleton, the e-invoice rules). Data
/// that is no object (`none`, an array, a number, text that is not a JSON
/// object) is an issue, never an error; JSON text that does not parse
/// stops like `json(..)`.
/// -> dictionary
#let check(
  /// -> dictionary | bytes | str | content
  data,
  /// -> none | str
  region: none,
) = {
  /* … */
}

/// The decoded, typed values of a record (datetimes, decimals, ratios, unit
/// functions, tax dictionaries, `id.*` values, custom bags as given): for
/// design decisions in the skeleton at evaluation time. `none` for `none`.
/// -> none | dictionary
#let values(
  /// -> none | content
  record,
) = {
  /* … */
}

/// A party as invoice() normalises it (`post-code`, `city-name`, `country`,
/// `*-inline`), for design decisions before invoice() runs: the post code of
/// `"80331 München"` or of `(name: "München", post-code: "80331")`.
/// -> dictionary
#let party(
  /// -> none | dictionary
  party,
  /// The region of a party without a country (the skeleton's locale region).
  /// -> str
  region: "de",
) = {
  /* … */
}

/// The explicit binding point of the data's line items inside `line-items`:
/// without data it renders `sample` exactly as written; with data the rows of
/// the data take its place and `sample` is never traversed. Rows outside it
/// stay on every invoice (a fixed fee). At most one per `line-items`, as a
/// direct child of it. Without a marker, the whole body of `line-items` is
/// the binding point.
/// -> content
#let items(
  /// -> content
  sample,
) = {
  /* … */
}

/// The JSON Schema 2020-12 of the data format (`"data"`) or of the result
/// record `<invoice-pro-result>` (`"result"`), generated from the descriptor:
/// `typst eval '{ import "@preview/invoice-pro:<version>": invoice-data;
/// invoice-data.schema() }'`.
/// -> dictionary
#let schema(
  /// -> "data" | "result"
  kind: "data",
) = {
  /* … */
}
```

A record is a sealed `metadata((kind: "invoice-pro-record", format, origin, values, issues, fatal))` value: opaque in the loom context (hashed once), unmistakable for raw data, layout-free. `origin` (`"input"`, `"file"` or `"value"`) is what R7 checks: a record made by `decode` together with a CLI data input panics as two sources (dev. 13). `load` without a data input returns `none` without loading any contract module (dev. 13), so a skeleton's preview costs nothing.

### 4.4 `payment(..)`: the payment binding point

`src/public/payment.typ` is a facade like `invoice-data`; the implementation (`src/components/payment.typ`) is imported when an invoice uses the block (dev. 30). Signature and doc comments as prototyped:

```typst
/// The payment of the invoice in one block: the payment terms, the method
/// (credit transfer, SEPA direct debit, payment card, or already paid) and the
/// account to pay to. It places `payment-terms`, `direct-debit`,
/// `card-payment` or `paid`, and `bank-details` as these arguments call for.
///
/// When the invoice is hydrated (`invoice(data: ..)`), the `payment` section
/// of the data applies key by key: `terms`, `method`, `bank` and `creditor-id`
/// keep this call's value unless the data gives them; `direct-debit`, `card`
/// and `paid` describe one invoice and come from the data only (the values
/// here are preview samples).
///
/// -> content
#let payment(
  /// The payment terms: `(days: 14)`, `(date: datetime(..))`, optionally
  /// with `discount: (days: 7, percent: 2%)` (see `payment-terms`). `none`
  /// prints none.
  /// -> none | dictionary
  terms: none,
  /// How the recipient pays: `"transfer"`, `"direct-debit"`, `"card"` or
  /// `"paid"`. `auto`: the method whose details are given, else a transfer.
  /// -> auto | "transfer" | "direct-debit" | "card" | "paid"
  method: auto,
  /// The account to pay to: `(name: .., bank: .., iban: .., bic: ..)` (see
  /// `bank-details`).
  /// -> none | dictionary
  bank: none,
  /// The SEPA creditor identifier of the sender, for `"direct-debit"`.
  /// -> none | str
  creditor-id: none,
  /// `(mandate: .., debtor-iban: ..)` of a direct debit.
  /// -> none | dictionary
  direct-debit: none,
  /// `(last4: .., holder: .., kind: ..)` of a card payment.
  /// -> none | dictionary
  card: none,
  /// `(method: .., date: ..)` of an invoice that is already paid.
  /// -> none | dictionary
  paid: none,
  /// Layout: whether the bank details print the payment reference.
  /// -> bool
  show-reference: true,
  /// Layout: the EPC QR code of the bank details, see `bank-details`.
  /// -> dictionary
  qr-code: (:),
) = {
  /* … */
}
```

What it places, by the effective method (P6, both compilers; BT-81 as stated in the XML):

| Method                 | Components                                                          | BT-81                               | Account          |
| :--------------------- | :------------------------------------------------------------------ | :---------------------------------- | :--------------- |
| `transfer`             | `payment-terms` (if terms) + `bank-details`                         | 58                                  | yes              |
| `direct-debit`         | `payment-terms` + `direct-debit(creditor-id, mandate, debtor-iban)` | 59                                  | no (CII-SR-467)  |
| `card`                 | `payment-terms` + `card-payment`                                    | 54 credit, 55 debit, 48 unspecified | no               |
| `paid`                 | `paid` only, no terms                                               | 10 cash, 20 cheque, 68 online, …    | no               |
| `paid` by `"transfer"` | `paid` + `bank-details`                                             | 58                                  | yes (CII-SR-470) |

Without data, `payment(..)` is byte-identical to writing those components by hand, on pristine 0.6.0 and on the prototype, for all five methods (P6). Hydrated, the guards that would stop a component become data issues (§3.7).

### 4.5 Binding points and coverage

- **Items.** The binding point is the explicit `invoice-data.items[..]` marker if a `line-items` has one, otherwise its whole body. Every `line-items` wraps its body in a private `_items-slot` motif (`src/components/line-items.typ`, dev. 11): without data it passes the children through (P2 byte-identical); hydrated, its measure emits `compute(rows, env-of(ctx))` from the rows engine (`src/contract/rows.typ`, imported only then) and discards the sample children. A marker holds its sample in a closure, so a hydrated invoice never weaves it.
- **Payment.** The `payment(..)` block.
- **Custom.** Always bound, as `ctx.custom`.
- **Assertions** (skeleton misuse: a panic at every validation level, with or without data): at most one marker per `line-items` (with root's existing "one `line-items`" rule, one per invoice, dev. 2); a marker must be a direct child of `line-items`, where an `apply(..)` around it is transparent (dev. 1); a marker inside a marker's sample panics also when hydrated (dev. 43; two nestings are not seen, §11.5).
- **Coverage issues** (class `data`, hydrated invoices only, built in the lazy `hydrate.typ`): data rows but no `line-items` → `schema/items`; a data `payment` section but no `payment(..)` → `schema/payment` ("replace `payment-terms`/`bank-details` by `payment(terms: .., bank: ..)`"). Data is never dropped silently by a missing binding point.
- **A cash discount on a credit note** (dev. 42): when the data's `document-type` makes a credit note or a self-billed invoice, a skeleton's `payment-terms(discount: ..)` is left out with the data issue `schema/document-type`. `payment-terms` stays no binding point for the data's terms (Q11).

### 4.6 Context additions

- `ctx.custom`: the third public context key next to `ctx.theme` and `ctx.locale`. It travels sealed in `metadata` and is unwrapped by `unsealed()` (theme parts) and by the `dynamic`/`info.get` paths (`src/theming/access.typ` +4, `src/components/dynamic.typ` +4).
- `view.items[i].custom` and `view.entries[j].custom`: the custom fields of data rows (checked on 0.15.1 for this concept: for §3.11 the first line has `(behaelter: "RM-1100-0815")`, the others `none`). Hand-written rows have none until `item(custom:)` exists (Q30).
- `ctx.<party>.custom`: the reserved print-only party key.
- `ctx.hydration` (sealed) and root's `payment-blocks` and `has-line-items`: internal; parts must not read them.

## 5. CLI conventions

### 5.1 Input keys

| Key                      | Value                                              | Read by                                     | Notes                                                                                                 |
| :----------------------- | :------------------------------------------------- | :------------------------------------------ | :---------------------------------------------------------------------------------------------------- |
| `invoice-pro-data`       | one invoice as JSON text (embedders: a dictionary) | the package (`invoice(data: auto)`, `load`) | the OS caps its size (§5.8)                                                                           |
| `invoice-pro-data-file`  | a path; JSON, TOML or YAML by extension            | the skeleton's `read` callback, via `load`  | relative to the skeleton, `/…` from the root; `/dev/stdin` with `--root /`; any size                  |
| `invoice-pro-result`     | `1`                                                | root                                        | emit `<invoice-pro-result>` on an invoice without data too; read from `sys.inputs` directly (dev. 12) |
| `invoice-pro-validation` | `draft`, `strict` or `none` (0.6.0)                | `resolve-level`                             | overrides `invoice(validation:)`                                                                      |

Any other key whose lower-case form without `-`, `_` and `.` starts with `invoiceprodata` panics as a near miss ("did you mean --input invoice-pro-data-file=…?", dev. 26). Other `invoice-pro-*` keys are not caught: a skeleton may read keys of its own with the package prefix (Q24).

### 5.2 One invoice

```sh
# preview: the skeleton's samples
typst compile skeleton.typ

# a file (the canonical way); .toml, .yaml and .yml by extension, TOML dates are native
typst compile --pdf-standard a-3b skeleton.typ out/2026-0042.pdf \
  --input invoice-pro-data-file=data/2026-0042.json

# inline JSON: no skeleton code needed
typst compile --pdf-standard a-3b skeleton.typ out.pdf \
  --input invoice-pro-data="$(cat data/2026-0042.json)"

# stdin (POSIX): the skeleton's read callback reads /dev/stdin
generate-invoice | typst compile --root / --pdf-standard a-3b /abs/skeleton.typ out.pdf \
  --input invoice-pro-data-file=/dev/stdin

# production: any problem stops with exit code 1; a reproducible default date
typst compile --pdf-standard a-3b --creation-timestamp "$SOURCE_DATE_EPOCH" \
  skeleton.typ out.pdf \
  --input invoice-pro-data-file=d.json --input invoice-pro-validation=strict
```

On 0.15 a skeleton may also pass a `path` made in its own file, `data: path("data/2026-0042.json")` (P7: md5-identical to the file route; on 0.14 `path` is the deprecated drawing function and fails with "expected array, found string"). `load(read:)` is the portable way. A 0.15 `path` to a `.toml` or `.yaml` file is decoded by its extension (fix 1).

### 5.3 Batch

An e-invoice PDF carries exactly one `factur-x.xml`, so a batch is one compile per invoice. The portable way is parallel processes; a bad file fails alone.

```sh
printf '%s\n' data/*.json | xargs -P 4 -I{} sh -c \
  'typst compile -j 1 --pdf-standard a-3b skeleton.typ "out/$(basename {} .json).pdf" \
     --input invoice-pro-data-file={} --input invoice-pro-validation=strict'
```

Measured in the research and the design prototypes (not on the consolidated prototype, 0.15.1): 20 invoices on 4 cores took 9.1 s as sequential processes, 3.0 s as 4 parallel processes and 4.95 s as one 0.15 bundle ([`process/research/typst-cli.md`](process/research/typst-cli.md)); design D compiled 5 files as 4 parallel processes in 1979 ms. The 0.15 bundle export (`--features bundle --format bundle`: one compile, one PDF per invoice, each with its own XML) is experimental in Typst and needs the skeleton written as a function of a record. It is a follow-up (Q31), not part of the 0.7.0 API.

### 5.4 Getting results back

```sh
# 0.15: a second compile
typst eval 'query(<invoice-pro-result>).first().value' --in skeleton.typ \
  --input invoice-pro-data-file=d.json
# 0.14 (and 0.15, with a deprecation warning)
typst query skeleton.typ '<invoice-pro-result>' --field value --one \
  --input invoice-pro-data-file=d.json
# every issue of a draft
typst query skeleton.typ '<ip-issue>' --field value --input invoice-pro-data-file=d.json
```

The record of §3.11, as the prototype emits it (0.15.1; `package` is the version in `typst.toml`, still 0.6.0 in the prototype tree):

```json
{
  "format": "invoice-pro-result/1",
  "package": "0.6.0",
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
    "net": "532.59",
    "tax": "85.12",
    "gross": "617.71",
    "prepaid": "100.00",
    "due": "517.71"
  },
  "taxes": [
    { "category": "S", "rate": "19%", "basis": "446.46", "amount": "84.83" },
    {
      "category": "E",
      "rate": "0%",
      "basis": "82.00",
      "amount": "0.00",
      "code": "VATEX-EU-132"
    },
    { "category": "S", "rate": "7%", "basis": "4.13", "amount": "0.29" }
  ],
  "lines": 7,
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

- Strings only: Typst's encoders would write `decimal("12.30")`. Money has two decimals, negative amounts an ASCII `-`, rates the input encoding (`"19%"`, at most 6 decimals) (dev. 31, 44).
- `status`: `ok`, `draft` or `unchecked` (validation `none`). `e-invoice.status`: `attached`, `withheld`, `draft` or `none`.
- `issues[].path` is the JSON Pointer of a data problem and `null` for a legal check.
- Totals follow `paid` as the XML does (BT-113 = gross, BT-115 = 0); `taxes[].code` is the BT-121 the XML states; `invoice-nr` and `recipient` are written as the XML states BT-1 and BT-44, or BT-27 on a self-billed document (dev. 31, 44; one mismatch remains, §11.5).
- It is emitted for hydrated invoices, or on request with `--input invoice-pro-result=1`. An invoice without data and without the input has no record, and the input does not change the PDF bytes (P8: 60 of 60 integration documents).

Each query costs a second full compile. A pipeline that only needs "deliverable or not" runs `strict` and checks the exit code. A result in the same compile (design D's `--input invoice-pro-result=attach`, which embeds a JSON file next to `factur-x.xml`) is a follow-up (Q18).

### 5.5 Layout-free check and schemas

```sh
# 0.15: validate without layout
typst eval '{ import "@preview/invoice-pro:<version>": invoice-data; invoice-data.check(json("d.json"), region: "de") }'
# 0.14: a stub on stdin
printf '#import "@preview/invoice-pro:<version>": invoice-data\n#metadata(invoice-data.check(json("d.json")))<r>\n' \
  | typst query --root . - '<r>' --field value --one
# the JSON Schemas of the data and of the result
typst eval '{ import "@preview/invoice-pro:<version>": invoice-data; invoice-data.schema() }' > invoice.schema.json
typst eval '{ import "@preview/invoice-pro:<version>": invoice-data; invoice-data.schema(kind: "result") }' > result.schema.json
```

The report is `{"format": "invoice-pro-check/1", "valid": .., "issues": [{"id", "path", "key", "message", "fix"}]}`, byte-identical on both compilers and through `eval` and `query` (P5). `check` covers what the decoder checks. A hydrated invoice can report more: rules that need the skeleton (a credit note with the skeleton's cash discount, coverage), the legal checks and the e-invoice rules (dev. 40, Q34).

### 5.6 Exit codes and status

| Outcome                                                                                       | Exit | PDF                                                 | `status`       | e-invoice                     |
| :-------------------------------------------------------------------------------------------- | :--: | :-------------------------------------------------- | :------------- | :---------------------------- |
| no problem                                                                                    |  0   | final                                               | `ok`           | `attached`                    |
| data or legal problems, `validation: "draft"`                                                 |  0   | draft: badge, inline markers, report page           | `draft`        | `withheld`                    |
| any problem, `strict` (parameter or `--input`)                                                |  1   | none                                                | –              | –                             |
| e-invoice rule errors, `zugferd-errors: "panic"` (default)                                    |  1   | none                                                | –              | –                             |
| e-invoice rule errors, `zugferd-errors: "report"`                                             |  0   | with report                                         | `ok` / `draft` | `draft` (`invoice-draft.xml`) |
| JSON that does not parse, another format major, Typst misuse, an unconsumed or misspelt input |  1   | none                                                | –              | –                             |
| `validation: none`                                                                            |  0   | as the data allows; invalid values dropped silently | `unchecked`    | per `zugferd-errors`          |

### 5.7 Typst 0.14 and 0.15

| Concern           | 0.14.2                                     | 0.15.1                                                |
| :---------------- | :----------------------------------------- | :---------------------------------------------------- |
| inline JSON       | `json(bytes(sys.inputs.k))`                | the same (`json.decode` is removed in 0.15: not used) |
| file              | the skeleton's `read` callback             | the same, or a `path` value                           |
| results           | `typst query` (a second compile)           | `typst eval` (a second compile); `query` deprecated   |
| layout-free check | a `typst query -` stub                     | `typst eval '{..}'`                                   |
| batch             | processes                                  | processes; bundle export (experimental, follow-up)    |
| decoder           | no 0.15-only function                      | the same; identical reports on both (P5)              |
| signature test    | through `typst query` (0.14 has no `eval`) | `typst eval`                                          |

### 5.8 Operating-system limits

- **Linux:** at most 128 KiB per argument. `--input invoice-pro-data=<JSON>` of a 1000-row tree invoice (`t-1000.json`, 213 KB) fails with "Argument list too long" before Typst starts; the 126 KB `b-1000.json` still works (verification round 0). Files and `/dev/stdin` give identical PDFs.
- **Windows:** about 32 767 characters for the whole command line, no `/dev/stdin`, painful JSON quoting in a shell, and 0.15 rejects backslashes in Typst paths: use files with forward slashes (OS documentation; not tested).
- **macOS:** `ARG_MAX` of about 1 MiB for all arguments together (OS documentation; not tested).
- Files are the documented default; inline JSON is for small invoices and tests.

## 6. Extensibility

### 6.1 Custom fields at three levels

The levels, keys and readers are in §3.8. What they cost and how a skeleton previews them:

- **Document `custom`** is sealed in `metadata`, so its size costs about nothing (the invoice-api research measured an unsealed bag of 2500 leaves at +48 % compile time at 50 lines and +76 % at 300; sealed ≈ 0). The skeleton previews it with `invoice(custom: ..)`; the data's `custom` replaces that sample as a whole (Q7).
- **Party `custom`** is a reserved print-only key of every party. It travels unsealed with the normalised party, so keep it small (the theming research measured 2000 unsealed entries at about 2.4× slower).
- **Item `custom`** rides in the item signal into `view.items[i].custom` and `view.entries[j].custom` (verified on 0.15.1 for this concept; designs A, B and C verified it with an unchanged EN 16931 XML).
- invoice-pro never prints a custom field, never interprets it and never writes it into the e-invoice. The skeleton decides what to do with it.

### 6.2 Changes that depend on a field value

The rule stays: **the data states facts, the skeleton states rules.**

| Need                                                                         | Mechanism                                                                                            | Runs at    | E-invoice "is it printed" checks       | Verified                                                       |
| :--------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------- | :--------- | :------------------------------------- | :------------------------------------------------------------- |
| change the design by a value (coat of arms by post code)                     | **a static theme patch** from `invoice-data.values(record)` and `invoice-data.party(..)` (§2.1)      | evaluation | active (`page-content` false)          | P7, both compilers                                             |
| change the design by a value without the `load` line, or by a computed value | `theme.custom.wrap(..)` or `part(..)` reading `ctx` and `view` (below)                               | draw       | IP-PRINT-03 and IP-PERIOD-03 "unknown" | P7 (`page-content` true); the block below on 0.15.1 and 0.14.2 |
| print a value                                                                | `info.get("custom", "x", default: ..)`, `dynamic(ctx => ..)`, `view.items[i].custom` in a table part | draw       | –                                      | P7 ("Tarif: Gewerbe M")                                        |
| change an **issuer** parameter by a value                                    | a Typst expression on `values` in the skeleton (below)                                               | evaluation | –                                      | the block below                                                |
| change a **document** parameter by a value                                   | a `derive: values => values` hook on `load`/`decode` (_proposed_, 0.7.x, Q17)                        | evaluation | –                                      | design D's prototype                                           |
| choose the whole design at document level                                    | plain Typst on `values` (`theme: if .. { .. } else { .. }`)                                          | evaluation | active                                 | design D's prototype                                           |

The static patch of §2.1 is the recommended pattern: it keeps the built-in logo part, so `prints-of(theme).page-content` stays false and the e-invoice checks of printed content stay active (P7: classic false, the skeleton's patch false, a draw-time wrap true).

The draw-time fallback reads hydrated values directly, so it needs no `load` line, but it turns IP-PRINT-03 and IP-PERIOD-03 into "unknown", because the theme now prints more than its data:

```typst
#let arms = (
  bayern: "wappen/bayern.svg",
  muenchen: "wappen/muenchen.svg",
)
// Fallback only: the rule runs while the frame is drawn and reads ctx and
// view. The e-invoice checks IP-PRINT-03/IP-PERIOD-03 then report "unknown".
#let logo-by-data = theme.custom.wrap("logo", (ctx, view, inner) => {
  let custom = ctx.at("custom", default: none)
  let key = if type(custom) == dictionary { custom.at("wappen", default: none) }
  let plz = view.recipient.at("post-code", default: none)
  if type(key) != str or key not in arms { key = none }
  if key == none and type(plz) == str and plz.starts-with("8") {
    key = "bayern"
  }
  if key != none { image(arms.at(key), height: 18mm) } else { inner(ctx, view) }
})

#show: invoice.with(..party, theme: theme.classic.with(logo-by-data))
```

An issuer parameter by a value of the data: the expression runs in the skeleton, and the data's own `notes` would still replace it (R3).

```typst
#let record = invoice-data.load(read: p => read(p, encoding: none))
#let values = invoice-data.values(record)
#let who = invoice-data.party(
  if values == none { party.recipient } else {
    values.at("recipient", default: none)
  },
)
#let plz = who.at("post-code", default: none)

#show: invoice.with(
  data: record,
  ..party,
  notes: if type(plz) == str and plz.starts-with("8") {
    "Gerichtsstand ist München."
  },
)

#line-items[
  #item("Sperrmüllabholung", price: 45)
]
```

Images chosen by data are opened in the skeleton: a closure written there resolves paths against the skeleton, even when the package calls it. Map data values to files through a dictionary, as `arms` does, and never concatenate a data string into a path.

### 6.3 Why the data has no expressions

The maintainer's rule is that design and appearance change in Typst only. An expression language in the data (JSONLogic, a template string, `eval`) would move rules out of the skeleton, where the preview shows them, into data that other programs write. It would also make untrusted data executable, break the code generators of phase 2 and give every rule two places to live. The cases the requirement names are covered by Typst code on facts: a rule in the skeleton reads `values`, `party(..)`, `ctx.custom` or `view` and decides. What is still missing is a hook for document keys (`derive`, Q17).

### 6.4 How the format evolves

- **A new optional key** is one descriptor entry (type, business term, role, binding point, `since`, a sentence of documentation) and a new minor. It appears in the decoder, both JSON Schemas and the reference tables at once; the drift check fails until the committed schemas are regenerated.
- **A new value type** is one constructor in `src/contract/types.typ`, its branches in the decoder and the exporter, and conformance fixtures.
- **A new `invoice()` parameter** must be classified (design, document, issuer) or the signature test fails (§4.2).
- **A rename, a removal or a new meaning** is a new major; `invoice()` then panics on the old major with the conversion hint (§3.10).
- Custom part names keep the package-prefix rule of the theme API (`acme/wappen`).

## 7. Performance

### 7.1 What is skipped

| #   | Step of a hand-written invoice                                                                                                                        | Hydrated                                                    | Mechanism                                                                                                                                                     | Status                          |
| :-- | :---------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------ |
| 1   | one `item`/`group`/`bundle`/`discount`/`surcharge`/`prepayment` motif per row, each a scope of about 20 `loom.mutator` ops that hash the full context | **skipped**: one raw motif                                  | the slot's measure is `compute(rows, env)`, which emits the same frames through the unchanged `calculate-item-data`, `calculate-bundle`, `calculate-modifier` | prototyped, byte-identical (P1) |
| 2   | loom's pass 2 recomputes every scope and measure                                                                                                      | **memo hit**                                                | `compute` takes `(rows, env)` only; `env` is identical in both passes and never holds `global` or `sys`                                                       | prototyped (P9)                 |
| 3   | per-row hashing of the locale (215 leaves) in unit resolution                                                                                         | avoided                                                     | the locale travels sealed into a per-(unit, quantity) helper                                                                                                  | prototyped                      |
| 4   | one nested `intertwine` per content modifier of an item                                                                                               | skipped                                                     | data modifiers are decoded dictionaries                                                                                                                       | prototyped                      |
| 5   | the skeleton's sample rows                                                                                                                            | never woven (marker) or woven and discarded (implicit slot) | a sample held in a closure; the slot replaces its children                                                                                                    | prototyped                      |
| 6   | parsing strings (decimal, date, percent, unit, tax)                                                                                                   | once, at evaluation time                                    | a pure, memoized decoder; the bulk motif does arithmetic only                                                                                                 | prototyped                      |
| 7   | bulk data in the loom context, hashed on every closure call                                                                                           | sealed                                                      | `hydration` and `custom` travel as `metadata(..)`, like the theme                                                                                             | prototyped                      |
| 8   | loading the hydration code                                                                                                                            | lazy                                                        | `invoice-data.*`, `payment`, the hydrated branch of `invoice()`, the slot engine and the result import their modules inside the function                      | prototyped (P9: lazy)           |
| 9   | `format-item` in the measure of `line-items`: a `loom.mutator.batch` per entry                                                                        | a plain dictionary                                          | same keys, same order (S7a)                                                                                                                                   | side branch `proto-s7a` only    |
| 10  | layout iteration 2 re-lays out the whole body of a long invoice                                                                                       | memo hit                                                    | an exact page-count seed for iteration 1 (S7b)                                                                                                                | _proposed_ (design C measured)  |
| –   | loom pass 1 (measure)                                                                                                                                 | **kept**                                                    | §7.2                                                                                                                                                          | –                               |
| –   | the keep-together `fits()` per entry                                                                                                                  | kept                                                        | needs the rendered height; a cheaper check is a theme decision (Q15)                                                                                          | –                               |

### 7.2 Why loom's first pass stays

All four designs considered a single pass with a precomputed `global` and rejected it. Design C measured bulk motif plus one pass against bulk motif plus two passes and found them within noise (0.15.1: b-300 3.01 vs 3.07 s; r-300 with e-invoice 4.30 vs 4.41 s). The bulk motif already makes pass 2 a memo hit, so the second pass costs little. A single pass would couple the format to the skeleton (every value the second pass needs would have to be precomputed from the data), and a stale `global` would give silently wrong totals.

### 7.3 Measured on the prototype

Final verification round (round 2), hydrated invoice against the same invoice written by hand on pristine 0.6.0, untraced wall clock, PDFs md5-identical in every cell. Kinds: `b` basic items, `r` rich items (gross prices), `t` a tree of groups, bundles and modifiers (`proto/gen/gen.py`, design C's generator). "e-invoice" is `zugferd: "en16931"`; `auto` picks XRechnung for these recipients.

| Rows | Kind and e-invoice | 0.15.1 ratio | 0.14.2 ratio | Notes                                                                                              |
| ---: | :----------------- | -----------: | -----------: | :------------------------------------------------------------------------------------------------- |
|  300 | b, en16931         |    **0.571** |    **0.568** | the gate cell: pooled over 29 runs per variant, 7.501 → 4.283 s (0.15.1), 7.619 → 4.324 s (0.14.2) |
|  300 | b, auto            |        0.579 |        0.567 | pooled 29 runs                                                                                     |
|  300 | b, en16931         |        0.562 |        0.561 | **instructions** (valgrind): 22.569 → 12.682 G and 22.621 → 12.693 G; deterministic                |
|  300 | r, auto            |        0.573 |        0.616 | 7 rounds                                                                                           |
|  300 | t, auto            |        0.639 |        0.660 | 7 rounds                                                                                           |
|   50 | b, en16931 / auto  |  0.685/0.699 |  0.804/0.705 | pooled 16 runs; instructions 0.703 / 0.698                                                         |
|   50 | r / t              |  0.728/0.777 |  0.668/0.754 | pooled 16 runs                                                                                     |
|    5 | b, en16931 / auto  |  1.022/0.962 |  1.116/0.989 | **no gain**; instructions 1.024 / 1.020                                                            |
|    5 | r / t              |  0.983/1.060 |  1.013/0.994 | pooled 16 runs                                                                                     |

- **Series spread.** Single series of the 300-row gate cell range from 0.552 to 0.611; 2 of 12 series medians are above 0.6 and about 35 % of paired rounds exceed it. The instruction ratio (0.561/0.562) is stable (Q3).
- **Small invoices.** Below about 10 rows the fixed cost of hydration (loading the contract modules, decoding, the result hook) cancels the loom savings. The synthesis expected −16 % at 5 rows; the prototype does not reach it.
- **Decoder** (`check()`, ×8 copies with every leaf distinct, so the memo cannot flatter it): 0.15.1 / 0.14.2 b 0.152 / 0.166, r 0.243 / 0.312, t 0.320 / 0.361 ms per row (11 rounds); a second series of 15 rounds gave r 0.229 / 0.251 and t 0.292 / 0.301. Instructions per row: r 800 k / 907 k, t 839 k / 952 k. All within the 0.4 ms budget; the first verification round had measured 0.44–0.68 ms per row before the hot-path work (dev. 34, 48).
- **Package import.** The root import parses +17.1 KiB (+6.1 KiB outside comment lines) and runs +3.84 M (0.15.1) / +3.88 M (0.14.2) instructions more than 0.6.0, +0.75 % / +0.81 % of 514 M / 479 M, about **+1.2 ms / +1.5 ms** at the import's own rate. Wall clock and trace spans cannot resolve it (±10–20 ms on the shared VM). The builder's estimate of 0.6–0.9 ms was too low. The largest parts: `invoice.typ` +1932 B of code, `public/invoice-data.typ` +972 B, `line-items.typ` +899 B, `root.typ` +730 B, `public/payment.typ` +450 B. No `src/contract/*` module and no `components/payment.typ` is in the root import (Q2).
- **Lazy modules.** No `src/contract/*` module appears in the traces of the benchmark invoices without data, the template or the hand-written 300-row invoices (34 of 34, both compilers); `components/payment.typ` appears only for a skeleton that calls `payment(..)`.
- **Where the time goes now.** The contract code is about 1 % of a traced hydrated b-300 compile (decode 27 ms, rows 44 ms, hydrate 10 ms, result 6 ms of 8.7 s, fixer round 2); the rest is the unchanged layout and e-invoice writer, and the table part dominates the tree invoices (build report).
- **Large data.** A 5000-row data file compiled clean in 166–320 s on a VM under load 12–22 (robustness round 2; an observation, not a benchmark).

### 7.4 Measured on the design prototypes (1000 rows, the page seed)

The consolidated prototype was checked at 1000 rows for equivalence only (b-1000 and t-1000 md5-identical on both compilers; 31 and 65 pages). The timings below come from design C's prototype on 0.15.1 (medians of 3–5 runs, md5-identical, [`process/designs/C-performance.md`](process/designs/C-performance.md)); its engine is the one the prototype uses, with design D's slower decoder in front of it.

| Invoice               | Hand-written 0.6.0 |    Hydrated (C) | Hand-written, seed series | Hydrated + exact page seed (S7b) |
| :-------------------- | -----------------: | --------------: | ------------------------: | -------------------------------: |
| b-300                 |             5.74 s |  2.82 s (−51 %) |                    5.97 s |                   2.23 s (−63 %) |
| r-300 with e-invoice  |             7.41 s |  4.30 s (−42 %) |                    7.73 s |                   2.66 s (−66 %) |
| t-300                 |             6.81 s |  4.34 s (−36 %) |                    7.01 s |                   3.09 s (−56 %) |
| b-1000                |            20.45 s |  9.12 s (−55 %) |                         – |                                – |
| r-1000 with e-invoice |            25.52 s | 14.30 s (−44 %) |                         – |                                – |
| t-1000                |            29.13 s | 18.20 s (−38 %) |                         – |                                – |

The page seed alone speeds up hand-written invoices by 20–27 % and does not trigger below about 70 lines. On the prototype's side branch `proto-s7a`, the plain-dictionary `format-item` (S7a) moved the b-300 gate cell from 0.57× / 0.58× to 0.55× / 0.56× and the tree invoices from 0.68–0.70× to 0.64–0.68× (build report, round-robin medians of 5).

### 7.5 Budgets and gates

| Budget (synthesis)                                 | Prototype                                           | Proposal                                                                                                    |
| :------------------------------------------------- | :-------------------------------------------------- | :---------------------------------------------------------------------------------------------------------- |
| hydrated b-300 ≤ 0.6× hand-written, both compilers | passes pooled (0.568–0.579×), thin in single series | gate on **instruction counts** (0.561×) with the same 0.6 threshold, or on pooled medians of many runs (Q3) |
| decoder ≤ 0.4 ms per row                           | passes (0.15–0.36)                                  | keep; measure with distinct leaves (identical rows are memo hits)                                           |
| root import delta ≤ 0.2 ms                         | **missed**: ≈ 1.2–1.5 ms (+0.75–0.81 %)             | restate as ≤ 1 % of the root import's instructions, or ≤ 2 ms (Q2)                                          |
| `src/contract/*` in `LAZY_MODULES`                 | done in `tools/perf/gate.py`                        | keep                                                                                                        |
| invoices without data unchanged                    | P2: byte-identical                                  | keep                                                                                                        |

The 0.2 ms budget came from designs A and C, which timed the evaluation of the facades alone and left out parsing and the hooks in `invoice()`, `line-items` and root. Reaching it would need an undocumented `..args` wrapper around `invoice()`, which loses the signature, its docs and the editor hints, or facades without doc comments (dev. 49). The ratio gate must also fail loudly when `env` leaks `sys` or `global`: pass 2 then stops being a memo hit.

### 7.6 The next bottleneck

After the bulk motif, layout dominates: in design C's trace of a hydrated b-300 invoice (0.15.1) the whole weave took 462 ms and the layout 1889 ms, of which the keep-together `fits()` of iteration 2 took 333 ms; the page seed cut that to 1.9 ms and the layout to 1224 ms. The levers, in order: S7a (≈ −0.02× on the gate), S7b (−56 % to −66 % on hydrated 300-row invoices in design C's runs: a full second layout iteration saved), then a cheaper keep-together check and the table part of the themes, which is a theme concept, not this one (Q15).

## 8. Validation and error model

### 8.1 What becomes what

| Situation                                                                                                                                     | Becomes                                                                                          | Depends on the level        | Example message (prototype)                                                                                                                                                            |
| :-------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------- | :-------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Typst misuse: `invoice(data: 42)`, two markers, a marker inside a `group`                                                                     | panic                                                                                            | no                          | ``variable `invoice::data` must be of auto \| none \| dictionary \| bytes \| str (JSON text) \| a record of invoice-data.load/decode, found integer``                                  |
| a file input without the `read` callback; an input nothing consumes; two sources; a misspelt data key                                         | panic with the one-line fix                                                                      | no                          | ``--input invoice-pro-data-file=data/x.json needs one line in the skeleton, because a package cannot open your files: `data: invoice-data.load(read: p => read(p, encoding: none))`.`` |
| JSON that does not parse                                                                                                                      | Typst's own error (`json()` cannot be caught)                                                    | no                          |                                                                                                                                                                                        |
| data in another format major                                                                                                                  | panic in `invoice()`; an issue in `check`                                                        | no                          | `invoice data is in format "invoice-pro/2"; this invoice-pro reads invoice-pro/1 only. …`                                                                                              |
| type, pattern, enum, unknown key, required, exclusivity, period, nesting, placement, tax rate, length, character                              | class-`data` issue `schema/<JSON Pointer>`, key `schema-<kind>`; the value or the row is dropped | yes (draft / strict / none) | ``invoice data: `items[0].price` must be a decimal number written as a string such as "12.30", found "12,30".``                                                                        |
| a VAT rate the region does not know                                                                                                           | issue `schema/items/1/tax`; the value is left out                                                | yes                         | ``invoice data: `items[1].tax`: 16% is no VAT rate of region de (19%, 7%); for another rate write {"category": "S", "rate": "16%"}.``                                                  |
| a legally required value (`invoice-nr`, `recipient.name`, the address, `items`)                                                               | reported once, by `check-data`: inline marker and legal reference                                | yes                         | `invoice::invoice-nr is missing; every invoice needs a unique, sequential number (§ 14 Abs. 4 Nr. 4 UStG; EN 16931 BT-1)`                                                              |
| a data section without a binding point                                                                                                        | issue `schema/items` or `schema/payment`                                                         | yes                         | ``invoice data: the data has a `payment` section, but the skeleton has no `payment(..)` block: replace `payment-terms`/`bank-details` by `payment(terms: .., bank: ..)`.``             |
| what a component would stop on, when hydrated (credit note + cash discount or direct debit, unallocatable modifier, transfer without account) | issue, the part is left out                                                                      | yes                         | ``invoice data: `payment.card.last4` is required: the payment method is "card".``                                                                                                      |
| legal and e-invoice rules                                                                                                                     | unchanged: `check-data`, IBAN and creditor checks, the rules engine                              | yes / `zugferd-errors`      | §8.5                                                                                                                                                                                   |

The levels are the unchanged machinery of 0.6.0: **draft** gives inline markers, the badge "ENTWURF · n Probleme · keine E-Rechnung", a report page, no XML and `status: "draft"`; **strict** gives one panic that lists every problem ("invoice-pro found 3 problems (validation: "strict"; preview them with validation: "draft" or --input invoice-pro-validation=draft): 1. … 2. … 3. …"); **none** checks nothing, drops invalid values silently (never back to the sample) and leaves e-invoice rules to `zugferd-errors`.

### 8.2 Issue ids, keys and messages

- The id is `schema/<JSON Pointer>` (`schema/items/0/price`), unique per path, so the report deduplicates. The result's `issues[].path` holds the pointer; the message shows the dotted path for humans.
- Keys: `schema-type`, `schema-enum`, `schema-unknown-key`, `schema-required`, `schema-exactly-one`, `schema-exclusive`, `schema-length`, `schema-period`, `schema-nesting`, `schema-placement`, `schema-tax-zero`, `schema-tax-rate`, `schema-range`, `schema-character`, `schema-unbound`, `schema-version`.
- Messages are English in the house style: path, value, allowed set, did-you-mean, the fix. Values quoted in a message are cut by grapheme clusters, never by bytes (fix 1). Party keys use the e-invoice alias table for hints (`plz`, `mail`, `ust-id`, …).
- _Not built_ (L16, Q26): the localized texts `strings.validation.issues.schema-*` in the six language files and the report chip "Daten / Data"; the report shows these issues with the chip "Pflichtangabe" today.
- _Found while writing this concept_ (0.15.1 and 0.14.2, also in `check(region:)`): when an earlier row was dropped, the region pass reports the index of the decoded rows, not of the data. `[{"name": "X", "tax": "19%"}, {"name": "Y", "price": "10.00", "tax": "16%"}]` gives `schema/items/0` (no price) and `schema/items/0/tax` for the 16 % of row 1. The region pass must keep the data's index (§11.5).

### 8.3 Drop semantics

An invalid value is left out. An object that then lacks what it needs (a line without a price) is left out as a whole, except the objects marked `partial` in the descriptor (the document, parties, contact, bank, payment, terms, custom), whose gaps the legal checks then name. A draft never crashes on bad data; a strict build never ships it.

### 8.4 Crash-freedom

Typst has no try/catch: one panic in a converter aborts a whole batch process with an unhelpful message. The decoder therefore pattern-checks every value before `decimal()`, `datetime()`, `id.*`, `tax.*` or `unit.*` sees it, checks every type before a method call, never applies `in` to `none`, and calls no function that can panic on a decoded value. Results after fix 2 (verification round 2, both compilers):

| Corpus                                                                                               | Runs per compiler | Hard aborts                                                                                                          |
| :--------------------------------------------------------------------------------------------------- | :---------------- | :------------------------------------------------------------------------------------------------------------------- |
| fault corpus (the engine judge's 38 faults, adapted, + 31 new)                                       | 69 × 2 modes      | 0 (the only stops: the deliberate format-major panic and, with an e-invoice, two IP-ID-01 rule stops)                |
| robustness corpus v3 (round 1 findings)                                                              | 455 (6 modes)     | 0 (two 400-s timeouts of a 5000-row file under load; clean on rerun)                                                 |
| robustness corpus r1                                                                                 | 951               | 0                                                                                                                    |
| `check()` over v3, v4 and the length probes                                                          | 517 files         | 0 inside `check()` (16 malformed files stop the harness's own `json()`)                                              |
| robustness corpus v4 (new: noncharacters in keys and wrong-typed values, 40 000-character values, …) | 609 (6 modes)     | **44 in 11 files**: 10 files with a noncharacter quoted in an issue message (PDF/A), one 40 000-character custom key |
| credit-note data into skeletons with raw `direct-debit(..)` or `card-payment(..)`                    | 24                | **24**: the components' own guard (Q10)                                                                              |
| every schema- and check-valid document compiled with PDF/A-3b                                        | 2201              | **13**: unassigned or private-use code points in printed texts; C0 controls in an identifier's `id` (Q9)             |

Strict exits 1 with the problem list on every issue file of the corpora (v3 48 of 48, r1 183 of 183, v4 55 of 57; the other 2 stop at the theme's own strict check). No PDF of any draft contains a sample string (294 + 345 + 582 PDFs scanned), and no draft carries an XML except 6 v4 drafts whose only problem is a theme-level check that 0.6.0 has too (§13).

### 8.5 What remains a hard stop

- **By design:** JSON that does not parse, another format major, Typst misuse, the R7 panics, `strict` with any problem, and e-invoice rule errors under `zugferd-errors: "panic"` (the default).
- **E-invoice rules that depend only on the data** (Q5): wrong check digits of a named identifier (IP-ID-01), unknown country or currency codes (BR-CL-14, BR-CL-04), a zero-rated category with a rate (BR-Z-05), a tax rate with more than 4 decimals (IP-DEC-01; the format allows 6), a credit note with a negative net total (IP-DOC-03), a transfer without terms or due date (IP-PAY-06). They stop the default compile and `check()` does not predict them; with `zugferd-errors: "report"` the invoice is a draft with `e-invoice.status: "draft"`.
- **Not data-related, the same for hand-written invoices:** a character that no installed font covers stops a PDF/A build (U+A646, CJK with `--ignore-system-fonts`, …); it depends on the fonts of the skeleton and the machine.
- **Open crash paths** of §8.4 (§11.5).

## 9. API change ledger

Kinds: `new-parameter`, `new-export`, `new-cli-input`, `new-label`, `new-view-key`, `behaviour-change`, `bugfix`, `internal`, `locale-strings`, `tooling`, `docs`. **⚠** marks a change that is not a pure extension; its justification is in the last column. L1–L26 follow the synthesis; L27–L31 are new in the prototype. _Proposed_ marks what the prototype does not contain.

| #   | Change                                                                                                                                   | File(s)                                                                                             | Kind                                                            | Justification                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| :-- | :--------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| L1  | `invoice(data: auto)`                                                                                                                    | `src/invoice.typ`                                                                                   | new-parameter                                                   | The single entry point. It must sit inside `invoice()`, so that `check-data`, the draft markers, strict and the XML withholding see the real values. `invoice()` rejects unknown arguments today, so no caller passes `data`.                                                                                                                                                                                                                                                                  |
| L2  | `invoice(custom: none)`                                                                                                                  | `src/invoice.typ`                                                                                   | new-parameter                                                   | The documented, sealed home of document-level custom fields and of their preview samples.                                                                                                                                                                                                                                                                                                                                                                                                      |
| L3  | The hydrated branch: key scan, lazy `hydrate(..)`, re-entry, issues next to `check-data`, sealed `hydration` and `custom`                | `src/invoice.typ` (+95 lines), `src/contract/hydrate.typ` (new, lazy)                               | internal                                                        | No behaviour without data (P2); no copied defaults.                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| L4  | Root export `invoice-data` (10 names) ⚠                                                                                                 | `src/public/invoice-data.typ` (new facade), `src/contract/api.typ` (lazy), `src/lib.typ` (+1)       | new-export                                                      | The contract's public face, layout-free (CI, phase 2). Not `data`, which `#let data = json(..)` would shadow. ⚠ as L5.                                                                                                                                                                                                                                                                                                                                                                        |
| L5  | Root export `payment(..)` ⚠                                                                                                             | `src/public/payment.typ` (new facade), `src/components/payment.typ` (new, lazy), `src/lib.typ` (+1) | new-export                                                      | Which payment components exist is data. ⚠ `import *` now also binds `payment` and `invoice-data`: a user binding of that name made _before_ the import is replaced (one made after it still wins; P2 probes: 2 documents). The same holds for every root export added since 0.1.                                                                                                                                                                                                              |
| L6  | The pinned export list gains `invoice-data` and `payment`                                                                                | `tests/theme/exports/test.typ`                                                                      | tooling                                                         | The test pins the root exports exactly.                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| L7  | `--input invoice-pro-data`, `invoice-pro-data-file`, `invoice-pro-result`; near-miss keys panic ⚠                                       | `src/contract/input.typ` (new), `src/invoice.typ`, `src/components/root.typ`                        | new-cli-input, behaviour-change                                 | "One input = one JSON document", with the package prefix and an injectable `inputs:` (precedent `invoice-pro-validation`). ⚠ A data key that nothing consumes, or a misspelt one (`invoice-pro-data-fil`), now panics, also on an invoice without data: the only 9 of 1105 documents per compiler that differ in P2. These keys carry the reserved prefix and do nothing in 0.6.0, so no working document depends on them, and the panic keeps a strict build from shipping a sample invoice. |
| L8  | Label `<invoice-pro-result>` (`invoice-pro-result/1`)                                                                                    | `src/contract/result.typ` (new, lazy), `src/contract/result-schema.typ`, `src/components/root.typ`  | new-label                                                       | A machine-readable result for pipelines and phase 2; only on hydrated invoices or with `--input invoice-pro-result=1`; the PDF bytes stay the same (P8).                                                                                                                                                                                                                                                                                                                                       |
| L9  | `_items-slot` around the body of `line-items`; hydrated, the body is replaced by the bulk motif                                          | `src/components/line-items.typ` (+36, −2)                                                           | behaviour-change (hydrated only)                                | Without data the slot passes the children through (P2). The traceback of a panic inside the body gains one loom frame (4 catch tests; the messages are equal).                                                                                                                                                                                                                                                                                                                                 |
| L10 | Rows engine and the explicit marker                                                                                                      | `src/contract/rows.typ` (new)                                                                       | internal                                                        | Byte-identical to the components (P1).                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| L11 | Root: `payment-blocks` and `has-line-items` in its view, coverage issues, payment-block issues, the result element                       | `src/components/root.typ` (+26)                                                                     | behaviour-change (data, `payment(..)` or the result input only) | Data is never dropped silently; the coverage code is loaded only when hydrated (dev. 11).                                                                                                                                                                                                                                                                                                                                                                                                      |
| L12 | `unsealed()` and `dynamic` unwrap a sealed `ctx.custom`                                                                                  | `src/theming/access.typ`, `src/components/dynamic.typ`                                              | internal (+ context contract)                                   | Custom fields travel sealed (≈ 0 cost) yet read as a dictionary; `ctx.custom` becomes a documented context key.                                                                                                                                                                                                                                                                                                                                                                                |
| L13 | `custom: false` (print-only) in `_address-keys` and in `payee` of `party-keys` ⚠                                                        | `src/zugferd/model.typ` (+3)                                                                        | behaviour-change                                                | ⚠ A party key `custom` no longer raises the IP-KEY-01 warning, also on a hand-written invoice (visible only with `zugferd-errors: "report"`; default PDFs identical). Today such a key is unknown, printed nowhere and written nowhere, so one warning less is the only change. It reserves the name for the documented party bag (dev. 32).                                                                                                                                                  |
| L14 | `view.items[i].custom`, `view.entries[j].custom` for data rows                                                                           | `src/contract/rows.typ`                                                                             | new-view-key                                                    | An additive key in the item signal; hand-written rows lack it until `item(custom:)` (Q30).                                                                                                                                                                                                                                                                                                                                                                                                     |
| L15 | Regions declare their VAT rates (`normalize.vat-rates`), with a base entry `none` ⚠                                                     | `src/locale/region/{base,de,at,ch,fr,it,es}.typ`                                                    | internal                                                        | One source for the pre-check, so a data `"16%"` is an issue instead of `infer-tax`'s panic. ⚠ An additive field of the region dictionaries; the locale factory rejects undeclared region keys, hence the base entry (dev. 10). A user-built region without the list skips the pre-check and behaves as `tax: 16%` does today.                                                                                                                                                                 |
| L16 | `strings.validation.issues.schema-*` and the chip "Daten / Data" in the 6 language files ⚠ (_proposed_)                                 | `src/locale/lang/*.typ`                                                                             | locale-strings                                                  | Localized report texts for the new issue keys. ⚠ A user locale built on `locale.custom` without them falls back to English; existing texts are unchanged. Not built (dev. 19; Q26).                                                                                                                                                                                                                                                                                                           |
| L17 | Descriptor, types, decoder, exporter, hydration, input, result and API modules; committed `invoice.schema.json` and `result.schema.json` | `src/contract/*` (new)                                                                              | internal                                                        | One source of truth; published files must live under `src/`; a drift check compares `schema()` with the committed files.                                                                                                                                                                                                                                                                                                                                                                       |
| L18 | `src/contract/*` and `src/components/payment.typ` in `LAZY_MODULES`; the hydrated-300 gate entry (_proposed_)                            | `tools/perf/gate.py` (+15)                                                                          | tooling                                                         | Guards the import budget and the memo-hit property. The prototype extends `LAZY_MODULES` only; its 300-row gate is a script (dev. 18).                                                                                                                                                                                                                                                                                                                                                         |
| L19 | Signature test, conformance fixtures, contract unit test, CI step                                                                        | `tools/contract/signature.py`, `tests/data/**`, `.github/workflows/tests.yaml` (+7)                 | tooling                                                         | §4.2, §10.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| L20 | `format-item` builds a plain dictionary (S7a, _proposed_, own PR)                                                                        | `src/components/line-items.typ`                                                                     | internal                                                        | Byte-identical; −0.02× on the gate (side branch `proto-s7a`).                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| L21 | Exact page-count seed for layout iteration 1 (S7b, _proposed_, own PR)                                                                   | `src/theming/frame.typ`                                                                             | internal                                                        | Removes a full second layout of long invoices; exact by construction; md5-identical on 123 documents in design C's run.                                                                                                                                                                                                                                                                                                                                                                        |
| L22 | `item()` measures through a shared pure `item-signal` (S7c, _proposed_, own PR) ⚠                                                       | `src/components/item.typ`, `src/logic/line-signal.typ` (new)                                        | internal                                                        | One implementation of the item cascade for hand-written and data rows (the real cure for drift); hand-written −20 to −37 %. ⚠ The largest internal change to a stable component: signature and output unchanged (123 and 31 documents md5-identical in design C's run), but the loom scope internals of `item` change.                                                                                                                                                                        |
| L23 | `group`, `bundle`, `modifier`, `prepayment` on shared resolvers (S7d, _proposed_, own PR) ⚠                                             | `src/components/*.typ`, `src/logic/line-signal.typ`                                                 | internal                                                        | Completes L22; same justification and gate.                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| L24 | `collect-signals(depth: 10)` in `calculate-modifier` (_proposed_, own bugfix PR) ⚠                                                      | `src/logic/modifier-applicator.typ`                                                                 | bugfix                                                          | ⚠ Changes the totals of invoices nested 10 levels or deeper, which are silently wrong today (deep items printed but missing from the totals). The format caps nesting at 8 until it lands.                                                                                                                                                                                                                                                                                                    |
| L25 | `modifier(name, amount: "-0.50")` converts a string amount like `discount`/`surcharge` (_proposed_, own bugfix PR) ⚠                    | `src/components/modifier.typ`                                                                       | bugfix                                                          | ⚠ A string amount that crashes in `normalize.money` today renders; no working document changes.                                                                                                                                                                                                                                                                                                                                                                                               |
| L26 | Docs: api-reference pages `invoice-data` and `payment`, a guide "Generate invoices from data", registries, doc tests (_proposed_)        | `docs/docs/**`, `DOCUMENTATION.md`, `tests/TESTING.md`, `tests/docs/**`, `MAINTENANCE.md`           | docs                                                            | House obligations (§12).                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| L27 | `payment-terms`: a cash discount on a credit note or self-billed invoice that the data made is left out with a data issue                | `src/components/payment-terms.typ` (+13, −3)                                                        | behaviour-change (hydrated only)                                | The data, not the skeleton's author, caused the conflict; the panic stays for Typst authors and the preview (dev. 42).                                                                                                                                                                                                                                                                                                                                                                         |
| L28 | `modifier-applicator`: a modifier that no VAT group can take is left out with a data issue                                               | `src/logic/modifier-applicator.typ` (+13)                                                           | behaviour-change (hydrated only)                                | The decoder cannot see totals; written in Typst it still panics (dev. 28).                                                                                                                                                                                                                                                                                                                                                                                                                     |
| L29 | `_one-line` prints the ellipsis when not even one cluster of a long text fits the header line ⚠                                         | `src/theming/parts/frame.typ`                                                                       | bugfix (own PR)                                                 | ⚠ 0.6.0 crashed (`none.trim`) on an invoice number of about 400 characters, also hand-written. Output of every document that compiled before is unchanged (dev. 29).                                                                                                                                                                                                                                                                                                                          |
| L30 | `registration` prints `sender.management` given as lines, one per line ⚠                                                                | `src/theming/parts/frame.typ`                                                                       | bugfix (own PR)                                                 | ⚠ 0.6.0 aborted with "cannot join content with array", also hand-written, although the sender docs type it as lines. 50 of 50 such probes crash on 0.6.0 and compile on the prototype; the 72 text and content probes are identical (dev. 39).                                                                                                                                                                                                                                                |
| L31 | `check-data` rejects blank names on the hand-written path (_proposed_, own bugfix PR) ⚠                                                 | `src/validation/data.typ`                                                                           | bugfix                                                          | ⚠ Would change reports of invoices without data that pass `name: ("", "")` today; the data path already rejects blank required texts (dev. 35).                                                                                                                                                                                                                                                                                                                                               |

**Not changed:** every existing parameter, default and export; `template/invoice.typ`, which stays an invoice without data (its golden XML and thumbnail untouched; its PDF md5 equals 0.6.0 with and without `--pdf-standard a-3b`, and its metadata count stays 6); `tools/zugferd/bt-disposition.toml` (the format feeds existing inputs).

**Not an API change, but felt by every invoice:** the root import runs about 1.2–1.5 ms longer (§7.3, Q2).

## 10. Phase-2 hooks

Phase 2 (native bindings) is not in scope. Phase 1 leaves it these artefacts, all generated from or checked against the one descriptor:

1. **JSON Schemas** (2020-12): `src/contract/invoice.schema.json` (757 subschemas, 92 `$ref`s, 48 patterns) and `src/contract/result.schema.json`, generated by `invoice-data.schema()` and committed. Every object is closed except the `custom` bags; `kind` discriminators carry `const` and `default: "item"`; `$defs` for decimal, percent, date, period, unit, tax and identifier; annotations `x-en16931` (112), `x-invoice-pro-role` (33), `x-invoice-pro-bind` (4) and `x-invoice-pro-since` (189). Cross-field rules are `dependentSchemas`: every validator enforces them and the three generators ignore them, whereas `oneOf`/`not` made the TypeScript generator type `price` as `{[k: string]: unknown}` and `if`/`then` makes typify panic (dev. 21). Both schemas are metaschema-valid for python-jsonschema 4.26.0 and ajv 8.17.1 in strict mode. **Drift check:** `typst eval '{ import "/src/lib.typ": invoice-data; invoice-data.schema() }' --pretty | diff - src/contract/invoice.schema.json`; byte-identical through `eval` (0.15) and `query` (0.14, 0.15) (P5).
2. **Conformance fixtures:** `tests/data/conformance/fixtures.json`, 135 cases (48 valid, 67 invalid, 12 decoder-only, 8 lenient, among them default model dumps with up to 143 nulls), and `check-all.typ`, which runs `invoice-data.check` over all of them without layout. Schema (python-jsonschema and ajv) and decoder agree on all 135 and on design D's 51 (P5). _Proposed:_ a CI job that requires this agreement on both compilers.
3. **Code generation** (round 2): datamodel-codegen 0.88.0 / pydantic 2.13.5 (1003 lines for the data, 273 for the result), json-schema-to-typescript 15.0.4 (968 / 204; `tsc --strict` 0 errors on 2062 valid documents), cargo-typify 0.8.0 (8265 / 2201 lines; 1050 of 1060 valid documents deserialize and round-trip unchanged). Kebab-case names become field aliases or `serde(rename)` everywhere. Known limits of the tools: serde rejects integers written as `14.0`, which JSON Schema allows (dev. 46); python-jsonschema lets `$` match before a trailing newline (57 mutations such as `"EUR\n"` pass it and fail ajv, pydantic-core and `check`); the generated pydantic model does not enforce "exactly one of `price`, `total`"; typify types the result's `format` as any value because its `const` has no `"type": "string"`. _Proposed:_ a CI job that generates and compiles all three.
4. **Transport contract:** one `--input` key carries one JSON document. Embedders that run Typst as a library (Rust `Library::with_inputs`, typst-py `sys_inputs`) may pass a dictionary as the value of `invoice-pro-data`. Data larger than about 100 KiB goes through `invoice-pro-data-file`. A binding is: serialize the model, compile the skeleton, read the exit code and the result.
5. **Result contract** `invoice-pro-result/1` (§5.4), strings only, with its own schema: 450 of 450 hydrated records and 165 of 165 records of invoices without data are valid for python-jsonschema, ajv, pydantic, typify and `tsc`; 59 of 59 broken records are rejected by python-jsonschema and ajv (P8).
6. **Golden pairs:** the generated data/hand-written pairs (design C's `gen.py` and `eq.sh`, in the prototype's harness) can ship as fixtures that a binding replays (md5 per compiler). _Proposed._
7. **Versioning:** the data format (`invoice-pro/1[.minor]`, SchemaVer, `since` per key), the result format (`invoice-pro-result/1`) and the package version (in the result) move independently. A binding targets a format major. The `$id`s carry the format major only and point at the documentation site: `https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/invoice.schema.json` and `…/1/result.schema.json` (patch 0010). The docs build must publish them there (Q28).
8. **Layout-free primitives:** `check` and `schema` through `typst eval` (0.15) or a `typst query -` stub (0.14), for validation before rendering.

## 11. Prototype and verification

### 11.1 What was built

The prototype is a branch of a clone of the repository, exported as ten patches on 0.6.0 (`df934a7`), in [`prototype/patches/`](prototype/patches/). [`prototype/README.md`](prototype/README.md) lists the files by area. In total: 39 files, +33 177 / −11 lines, of which 23 550 are conformance fixtures and 4113 the two committed schemas.

| Patch | Content                                                                                                                                                                                                                                           |
| :---- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0001  | contract core (descriptor, types, decoder, exporter, input, hydrate, result), `invoice(data:, custom:)` with re-entry, the rows engine behind the items slot and the marker, `payment(..)`, region VAT rates, sealed `ctx.custom`, party `custom` |
| 0002  | crash-free decoder rules, item modifiers without `tax`, the committed schemas, conformance fixtures                                                                                                                                               |
| 0003  | contract unit test, signature-coverage test, `LAZY_MODULES`                                                                                                                                                                                       |
| 0004  | decoder hot path                                                                                                                                                                                                                                  |
| 0005  | coverage issues in the lazy contract module                                                                                                                                                                                                       |
| 0006  | fix round 1: crash-free decoding, codegen-friendly schema, payment and R7 checks, result fixes, `frame.typ` ellipsis, the lazy `payment` facade                                                                                                   |
| 0007  | `components/payment.typ` in `LAZY_MODULES`                                                                                                                                                                                                        |
| 0008  | fix round 2: `""` absent for every optional key, PDF/A-safe texts, a total `check()`, the nested marker with data, a faster decoder, `management` as lines, the signature scanner                                                                 |
| 0009  | a cash discount period of at most 36 500 days                                                                                                                                                                                                     |
| 0010  | the schemas' `$id` on the documentation site (after the last verification round; no other change)                                                                                                                                                 |

Not in the prototype: L16 (localized issue texts), the L18 gate entry, L20–L25 (speed PRs and two bug fixes), L26 (docs), CI jobs for code generation and conformance (they exist as scripts in the harness). tytanic was not available: the test files are compiled directly, and their assertions panic on failure.

### 11.2 The ten proofs

Status after the last verification round (round 2, after fix 2), both compilers.

| Proof | What it shows                                                      | Status                    | Numbers                                                                                                                                                                                                                                                                                                   |
| :---- | :----------------------------------------------------------------- | :------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1    | hydrated == hand-written on 0.6.0 (PDF md5, embedded XML included) | pass                      | 0 failures: matrix b/r/t × 5/50/300 × e-invoice none/auto (36), 1000 rows (8), 13 edge fixtures (nested and dated bundles, `apply` around the marker, static rows, inclusive + small business AT, prepayments), 662 generated cases incl. 88 blank-optional cases; §3.11: `32b0b6d5d449` / `679ee994c66b` |
| P2    | no regression of invoices without data                             | pass                      | 1105 documents per compiler: 1013 identical PDFs + 83 identical errors + 9 intended near-miss panics; the 313 test documents with PDF/A-3b: 253 + 60, 0 differ; template md5 `881821b7318c` / `ba5d9a49b5de` (0.15.1, plain / a-3b) and `8a1c8b464422` / `c7e98da669bc` (0.14.2), equal to 0.6.0          |
| P3    | no sample leaks; every R7 panic with its fix; skeleton misuse      | pass (one minor gap)      | 31 checks per compiler; 16 nested-marker variants panic with and without data; strict exits 1 on every issue file of the corpora; 0 sample strings in 1221 PDFs. Gap: a marker inside `context` or inside an item's description is not seen                                                               |
| P4    | crash-freedom on bad data                                          | **fail** (three findings) | 0 hard aborts in the fault corpus, v3 and r1 (§8.4). Open: noncharacters quoted in issue messages stop PDF/A (11 files); raw `direct-debit(..)`/`card-payment(..)` with credit-note data (24 runs); unassigned/private-use code points and C0 controls (13 of 2201 valid documents)                       |
| P5    | schema == decoder; code generation                                 | partial                   | 135 + 51 fixtures, 171 + 1958 targeted cases (python == ajv on all) and 3154 mutations agree; pydantic, TypeScript and Rust as in §10. Open: C0-only and format-character-only required texts pass; tax rates allow 6 decimals, the e-invoice 4                                                           |
| P6    | `payment(..)` matrix                                               | pass                      | without data md5 == the components for 5 methods; hydrated == hand-written; BT-81 58/59/54/10/58; 102 data cases, 24 twin pairs, 95 schema agreements, 0 failures. No external validator (Mustang, KoSIT) was available                                                                                   |
| P7    | sources and the coat of arms                                       | pass                      | file, inline, stdin, TOML, YAML, 0.15 path one md5; 80331/85221 → Bavaria, 20095 → Hamburg, 10115 → Berlin, 50667/01067 → neutral, override → München; 28 logo crops byte-identical across compilers and checked by eye; `prints-of` false/false/true                                                     |
| P8    | the result contract                                                | pass (one fail)           | `eval` == `query` on 450 of 450; valid for 5 validators; no record without data or input. Fail: for 11 of 344 records with an invisible format character in BT-1 or BT-44, the result strips it and the XML keeps it                                                                                      |
| P9    | performance                                                        | partial                   | gate 0.571× / 0.568× pooled (passes, thin margin); decoder 0.15–0.36 ms/row (passes); lazy 34 of 34; root import ≈ +1.2–1.5 ms (**misses** 0.2 ms); 5 rows no gain                                                                                                                                        |
| P10   | every `invoice()` parameter classified                             | partial                   | 35 parameters (design 7, document 17, issuer 9, data 1, body 1); 23 of 23 earlier mutations caught. Open: 8 of 15 new mutations get the wrong verdict (a commented-out copy of the signature, a `"` in a content default, a reformatted `hydrate(..)` call)                                               |

### 11.3 What the verifiers found and what was fixed

| Round | Area          | Pass | Partial | Fail | Not run |
| :---- | :------------ | ---: | ------: | ---: | ------: |
| 0     | equivalence   |   17 |       1 |    0 |       0 |
| 0     | robustness    |    8 |       4 |   15 |       0 |
| 0     | contract      |   11 |       3 |    3 |       0 |
| 0     | features-perf |   14 |       2 |    2 |       0 |
| 1     | equivalence   |   20 |       0 |    1 |       0 |
| 1     | robustness    |   20 |       4 |    2 |       0 |
| 1     | contract      |   13 |       5 |    1 |       0 |
| 1     | features-perf |   16 |       3 |    2 |       1 |
| 2     | equivalence   |   16 |       0 |    0 |       0 |
| 2     | robustness    |    9 |       2 |    3 |       0 |
| 2     | contract      |   16 |       2 |    4 |       0 |
| 2     | features-perf |   16 |       0 |    1 |       1 |

Round 2 found new failures because it tried harder inputs, not because fixes regressed: every P1 and P2 log that should be unchanged was byte-identical across rounds.

**Fix 1** (after round 0): messages cut by grapheme clusters instead of bytes; the nesting cap before the descent; version numbers of any length; years 1–9899, payment days ≤ 36 500, texts ≤ 10 000 characters; document types exactly as `invoice()` accepts them; hydrated-only data issues for credit-note guards and unallocatable modifiers; the `frame.typ` ellipsis bugfix; near-miss data keys panic; blank required values are issues; YAML with a BOM and a 0.15 `path` to TOML; cross-field rules as `dependentSchemas`; result fixes (ASCII minus, totals of paid invoices, BT-121, two-decimal money); a transfer without account and details of another method as data issues; a decoder hot path (0.43–0.69 → 0.12–0.27 ms per row in the verifier's harness); the lazy `payment` facade; class checks in the signature test. Result: 0 hard aborts on the 317-file corpus in 6 modes, the 1413 type mutations, the 77 crash reproductions and the fault corpus.

**Fix 2** (after round 1): `""` absent for every optional key (88 of 88 cases equivalent); the PDF/A limits (4000 characters for metadata texts, 10 000 in custom bags, noncharacters); a cash discount with at most 2 decimals and 36 500 days; `management` as lines (the compile sweep went from 370 to 2128 of 2128 documents); `check()` total on non-objects; paid by transfer without account as a data issue; `payment-terms(discount:)` with credit-note data as a data issue; the nested marker with data; result rates and BT-1/BT-44; an explicit White_Space class in the schema (0 python/ajv disagreements on 171 probes); a scanner in the signature test (23 of 23 mutations); fewer calls in the decoder (−20 % instructions per tree row).

**Decided rather than fixed** (each listed in `deviations.md`): other `invoice-pro-*` typos are not near misses (dev. 26); a data bank with another method is left out without an issue (dev. 41); a bank without IBAN gives two issues (dev. 25); `""` for typed keys is a reader leniency the schema does not share (dev. 36); integers as `14.0` stay valid (dev. 46); the root import budget is missed (dev. 49).

### 11.4 How to reproduce

```sh
# in a clone of this repository; needs git, Typst 0.14 or 0.15, python3 (pdfdetach optional)
TYPST_BIN=typst docs/concepts/data-api/prototype/run.sh ../data-api-proof
```

`run.sh` clones the repository twice, checks out `df934a7`, applies the patches with `git am` to one clone and compiles the examples against both. It checks 12 things: the skeleton alone; hydrated from a file, inline JSON, stdin and TOML, each md5-identical to the hand-written twin on 0.6.0; a missing invoice number gives a draft without an embedded file, and `strict` stops; the post codes 80331, 20095, 10115 and 50667 and the custom override pick the right arms. Re-run while writing this concept: 12 of 12 PASS on 0.15.1 (`32b0b6d5d449`) and on 0.14.2 (`679ee994c66b`). The full verification harness (generators, corpora, benchmark scripts, logs) stayed in `<session>/exp/unified/` and is not part of the repository; [`process/review/verification.md`](process/review/verification.md) records every command and result.

### 11.5 Still open

| #   | Gap                                                                                                                                                                                                                                                                     | Severity | Fix (proposed)                                                                                                       |
| :-- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------- | :------------------------------------------------------------------------------------------------------------------- |
| O1  | A noncharacter (U+nFFFE/U+nFFFF) in an unknown key, a wrong-typed value, a currency or a format string is quoted verbatim in the issue message, and the draft report then stops a PDF/A build (10 files × 4 modes per compiler)                                         | high     | map unprintable characters to U+FFFD or `\u{..}` inside `clip()`/`_shown()` (`src/contract/input.typ`, `decode.typ`) |
| O2  | Credit-note or self-billed data into a skeleton with the raw components `direct-debit(..)` or `card-payment(..)` panics in `payment-means.typ` (24 runs per compiler)                                                                                                   | high     | the treatment of dev. 42 for these components: left out with a data issue when hydrated (Q10)                        |
| O3  | Unassigned (U+2FFFD, …) and private-use (U+FFFFD, U+10FFFD, …) code points in printed texts stop PDF/A; required texts of only C0 controls or only format characters pass the schema and `check` and give empty or invisible XML values                                 | medium   | reject C0 controls other than TAB/LF/CR, do not count `\p{Cf}` as filling; decide Cn/Co (Q9)                         |
| O4  | Tax rates allow 6 decimals, the e-invoice states 4 (IP-DEC-01 stops the default compile)                                                                                                                                                                                | medium   | 4 decimals for tax rates in schema and decoder (Q5)                                                                  |
| O5  | The result strips `\p{Cf}` from BT-1/BT-44, the XML keeps it (11 of 344 records)                                                                                                                                                                                        | medium   | write what the XML writes (drop the Cf removal), together with O3                                                    |
| O6  | `signature.py` misses an unclassified parameter behind a commented-out copy of the signature or a `"` in a content default, and accepts a `hydrate(..)` call that passes the wrong value                                                                                | medium   | parse with Typst itself (`typst query` of a probe) or a real tokenizer; check argument values                        |
| O7  | Found while writing this concept: after a dropped row, the region pass reports the decoded index, in `invoice()` and in `check(region:)`, on both compilers; the prototype's own `data/bad.json` gives `schema/items/0/items/0/tax` for the 16 % of `items[1].items[0]` | medium   | keep the data's index in the decoded row                                                                             |
| O8  | Keys of custom bags are not limited (a 40 000-character key stops PDF/A when a skeleton prints the bag)                                                                                                                                                                 | low      | the 10 000-character limit and the noncharacter rule for keys too                                                    |
| O9  | A marker inside `context` or inside an item's description is not seen by the nested-marker scan (output stays correct)                                                                                                                                                  | low      | document; scan item fields                                                                                           |
| O10 | An object whose keys are all absent counts as given (`terms: {}` replaces the skeleton's terms)                                                                                                                                                                         | low      | Q13                                                                                                                  |
| O11 | The import budget (≈ 1.2–1.5 ms against 0.2 ms) and the thin wall-clock margin of the 300-row gate                                                                                                                                                                      | decision | Q2, Q3                                                                                                               |
| O12 | No external Factur-X/XRechnung validator ran; CII-SR-467/470 rest on invoice-pro's own rules engine and XML inspection                                                                                                                                                  | process  | run Mustang and KoSIT on the P6 matrix before the release                                                            |
| O13 | L16 (localized `schema-*` texts, the "Daten" chip) is not built                                                                                                                                                                                                         | planned  | stage S3 (§12)                                                                                                       |
| O14 | The CI step of `signature.py` was wired but not run (no nix in the sandbox); tytanic was not available                                                                                                                                                                  | process  | stage S1/S2 port the tests to tytanic                                                                                |

## 12. Implementation plan

Branch `feature-data-api` (the maintainer's convention for large features), the concept at `docs/concepts/data-api/` (this folder), a GitHub issue first, so that each PR can say "Refs #N" (the roadmap item "Data Loading" exists, the issue does not, Q35). Each stage is a PR that ports the prototype's patches into `src/` with tytanic tests; the open fixes of §11.5 land in the stage that owns the code. Effort in maintainer-days (d), rough.

| Stage                         | Content                                                                                                                                                                                                               | Effort       | Tests the stage needs                                                                                                                                                                                                                                                                                                                                                                          | Docs and registries                                                                                                                                                                                     |
| :---------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| S0 Concept                    | this document, `process/`, `prototype/`; the issue; the answers to §14                                                                                                                                                | 1 d          | prettier 3.6.2; typstyle 0.15.1 on every block; no versioned imports                                                                                                                                                                                                                                                                                                                           | –                                                                                                                                                                                                       |
| S8 Bug fixes (may land first) | L29 ellipsis, L30 `management` as lines, L24 `collect-signals` depth (then raise the nesting cap in a minor), L25 modifier string amount, L31 blank names in `check-data`; separate PRs                               | 1.5 d        | a regression test each (an invoice number too long for the header line, a `management` array, depth-12 totals, a string amount, a blank name); the full suite unchanged                                                                                                                                                                                                                        | CHANGELOG entries                                                                                                                                                                                       |
| S1 Contract core              | L17, L4: `src/contract/{types,schema,decode,export,input,api}.typ`, `src/public/invoice-data.typ`, the committed schemas, the conformance fixtures; the fixes O1, O3, O4, O7, O8                                      | 5 d          | tytanic `tests/data/contract/` (load with injected `inputs:`: inline, file, both, file without `read`, TOML, YAML, BOM; values, `null` and `""`, party, region rates); `tests/data/conformance/` with a CI job that compares python-jsonschema and ajv with `check` on both compilers; the fault corpus as a CI job (0 hard aborts); the schema drift check; a codegen job; the decoder budget | –                                                                                                                                                                                                       |
| S2 `invoice()` integration    | L1–L3, L7, L12, L13, L15, L16 (localized `schema-*` texts, the "Daten / Data" chip); a hardened signature test (O6)                                                                                                   | 4.5 d        | the precedence matrix (every document and issuer key: absent, given, `null`, `""`); sample-leak tests (missing number, date, recipient, items → draft, no XML; strict panics); the R7 panics; misuse; the integration tests and the template md5; `ctx.custom` through `unsealed()` and `info.get`; party `custom` without IP-KEY-01; `tests/theme/report-lang` with the new keys              | –                                                                                                                                                                                                       |
| S3 Items                      | L9–L11, L14, L28: the rows engine, the slot, the marker (O9), coverage issues, the hydrated modifier issue                                                                                                            | 4 d          | the generated equivalence suite as a CI gate (0.6.0 hand-written vs hand-written on the new tree vs hydrated, md5 and XML: b/r/t × 5/50/300 × e-invoice none/auto × both compilers); the edge fixtures; slot misuse (two markers, a nested marker, a marker inside a group, items without `line-items`)                                                                                        | –                                                                                                                                                                                                       |
| S4 `payment(..)`              | L5, L27, O2                                                                                                                                                                                                           | 2 d          | the means matrix (transfer, direct debit, card, paid cash, paid by transfer) with and without data: BT-81, CII-SR-467/470, paid + terms excluded, missing mandate or last4 → issue, credit notes; without data md5 == the components; one Mustang and KoSIT run (O12)                                                                                                                          | –                                                                                                                                                                                                       |
| S5 Result, CLI, perf gate     | L8, L18 (a 300-row gate on instruction counts), O5                                                                                                                                                                    | 2 d          | the result validates against its schema; `typst query` (0.14) == `typst eval` (0.15); no record without data, PDF bytes unchanged by the input; the CLI matrix (inline, file, stdin, TOML, YAML, 0.15 path → one md5); the perf gate on both compilers                                                                                                                                         | `tools/perf/README.md`                                                                                                                                                                                  |
| S6 Docs                       | L26: api-reference pages `invoice-data` and `payment`, a guide "Generate invoices from data" (skeleton, CLI, coat of arms as a static patch, batch, results), the data-format reference generated from the descriptor | 3 d          | a verbatim doc test under `tests/docs/<page>-<example>/` for every block; `scripts/check-docs-examples` (skip markers for blocks that read a data file)                                                                                                                                                                                                                                        | `DOCUMENTATION.md` code block registry, `tests/TESTING.md` registry, `MAINTENANCE.md` (below), both READMEs, the intro, the roadmap checkbox, the schemas under the docs site's `schema/invoice-pro/1/` |
| **0.7.0 feature**             |                                                                                                                                                                                                                       | **≈ 21.5 d** | (S0–S6; the synthesis estimated 23.5 d without a prototype)                                                                                                                                                                                                                                                                                                                                    |                                                                                                                                                                                                         |
| S7 Speed PRs (Q15)            | S7a plain-dictionary `format-item` (1 d), S7b exact page seed (1.5 d), S7c `item()` on `item-signal` (2 d), S7d the other components on shared resolvers (4 d); API-neutral, separate PRs                             | 8.5 d        | each: the full suite md5 on both compilers, the equivalence suite, a before/after perf table                                                                                                                                                                                                                                                                                                   | –                                                                                                                                                                                                       |
| S9 Follow-ups (0.7.x)         | `derive` and declared custom fields (Q17), the result attachment (Q18), `item(custom:)` (Q30), bundle batches (Q31), a `locales:` map (Q32), CSV rows for the marker (Q33), explicit none (Q23)                       | –            | per feature                                                                                                                                                                                                                                                                                                                                                                                    | per feature                                                                                                                                                                                             |

New items for `MAINTENANCE.md` (a section "Data format"):

- **Descriptor change:** regenerate both schemas with `typst eval` and commit them (the drift check fails otherwise); a new key gets `since` and a new minor in `src/contract/schema.typ`; regenerate or extend the conformance fixtures; publish the schemas on the docs site.
- **Version bump:** nothing in the schemas (their `$id` carries the format major only); the result's `package` field reads `typst.toml`; the new docs pages with versioned imports go on the bump checklist.
- **A new `invoice()` parameter:** classify it in `invoice-params` (the signature test fails otherwise).
- **A new contract module:** add it to `LAZY_MODULES`.

## 13. Risks and known gaps

1. **Drift between the components and the rows engine.** The engine replays the scope cascades of `item`, `group`, `bundle`, `modifier` and `prepayment`. Mitigation: the equivalence suite as a CI gate (S3), then one implementation through shared pure resolvers (S7c, S7d). Until then `calculate-item-data`, `calculate-bundle`, `calculate-modifier` and the unit and tax resolution are pseudo-contracts.
2. **Memo sensitivity.** The gain depends on `env` being identical in both loom passes. A change that puts `ctx.global` or `sys` into `env` silently loses about half of it. Mitigation: the perf gate (§7.5) and a comment at `env-of`.
3. **Re-entry discipline.** A new `invoice()` parameter must be classified, or the hydrated branch would pass it on wrongly. Mitigation: the signature test, whose parser still has blind spots (O6).
4. **The nested weave in `payment(..)`.** It weaves its components with `loom.core.intertwine` in measure and again in draw; a loom upgrade that changes `intertwine` or path semantics must be tested against it.
5. **Decoder and schema are two interpreters of one table.** Mitigation: the differential fixtures and code generation in CI on both compilers.
6. **Crash paths.** Any missed pre-validation aborts a batch process. Mitigation: the corpora in CI; O1–O3 are open.
7. **Layout dominates after the fast path.** 1000-line invoices still take 9–18 s in design C's runs. Mitigation: S7b; a theme concept for keep-together and the table part.
8. **No gain for small invoices.** Below about 10 rows hydration is as fast as hand-written, not faster (§7.3). The value of the feature there is the workflow, not the speed.
9. **The import cost for every invoice:** about +1.2–1.5 ms (+0.75–0.81 % of the import's instructions), with or without data (Q2).
10. **The implicit slot surprises.** A fixed fee written in the `line-items` body disappears when hydrated (R5). Mitigation: the docs and the marker; the preview cannot warn, because it has no data.
11. **Samples are still woven in the implicit slot** (about 2.4 ms per sample row and pass, design measurement): noise for a few samples. Mitigation: the marker.
12. **Party custom fields are unsealed**, a performance trap for large payloads. Mitigation: a documented limit; document custom is sealed.
13. **Draw-time rules switch off two e-invoice checks** (IP-PRINT-03, IP-PERIOD-03 "unknown"). Mitigation: the static patch is the documented pattern.
14. **Strictness surprises producers:** JSON numbers in text fields, numeric post codes, unit names and a missing `format` are issues. Mitigation: every message shows the fix, and the schema tells producers up front.
15. **E-invoice rules that `check()` cannot predict** stop the default compile (§8.5, Q5).
16. **`validation: none` drops invalid values silently**, which can change totals. Consistent with "off means off"; documented.
17. **Inline JSON limits** (128 KiB per argument on Linux, about 32 K characters on Windows). Files are the documented default.
18. **`typst query` is deprecated in 0.15; the bundle export is experimental.** The 0.14 path keeps `query`; bundles are a follow-up.
19. **New root names** (`payment`, `invoice-data`) shadow user bindings made before `import *` (L5).
20. **The 4000-character metadata limit is far above what a theme can show.** An invoice number of 4000 emoji trips the theme's identity check ("the invoice number does not appear in the first-page content"), and that draft keeps its XML; a hand-written 0.6.0 invoice behaves the same.
21. **Measurements ran on a shared 4-core VM** (±10 % run to run, single runs up to ±20 %). All comparisons are round-robin or pooled medians and agree across both compilers; the deterministic instruction counts confirm the ratios.
22. **No external e-invoice validator** was available (O12), and tytanic was not run (O14).

## 14. Open questions for the maintainer

Most consequential first. "Settled by the prototype" means the prototype implemented the recommendation and the verification found nothing against it; it still needs your yes.

1. **Q1 Data errors: issues or panics?** _Recommendation:_ class-`data` issues: a draft previews incomplete data with a report and no XML; `strict` is for sending and CI (implemented; 0 hard aborts on the corpora outside §11.5). _Alternative:_ always panic, which loses the draft preview and every machine-readable issue.
2. **Q2 Restate the root-import budget.** The synthesis' 0.2 ms is missed: the prototype adds +3.84 M / +3.88 M instructions (+0.75 % / +0.81 %), about 1.2–1.5 ms, for every invoice. What remains is the documented API: the two parameters and the re-entry hook, the items slot, root's hooks, the two documented facades, the regions' VAT lists. _Recommendation:_ restate it as "≤ 1 % of the root import's instructions" (or ≤ 2 ms), measured deterministically. _Alternative:_ keep 0.2 ms, which needs an undocumented `..args` wrapper around `invoice()` (loses the signature, its docs and the editor hints) or facades without doc comments.
3. **Q3 The performance gate.** The wall-clock ratio of the hydrated 300-row invoice passes pooled (0.568–0.579×), but 2 of 12 series medians exceed 0.6 on the shared VM. _Recommendation:_ gate on instruction counts (0.561× / 0.562×, stable) with the threshold 0.6, and state openly that invoices below about 10 rows gain nothing. _Alternative:_ keep a wall-clock gate and widen the margin with S7a and S7b first.
4. **Q4 The binding point of the items.** _Recommendation:_ the `line-items` body by default, the optional `invoice-data.items[..]` marker (at most one, a direct child, `apply` transparent) for static rows (implemented, P1 edge fixtures). _Alternatives:_ marker required (a forgotten marker drops the data); implicit only (no fixed fee possible).
5. **Q5 E-invoice rules that depend only on the data.** Wrong identifier check digits (IP-ID-01), unknown country or currency codes (BR-CL-14, BR-CL-04), tax rates with more than 4 decimals (IP-DEC-01) and a rate on a zero-rated category (BR-Z-05) pass `check()` and stop the default compile. _Recommendation:_ check them in the decoder as data issues in 0.7.0 (check digits through the existing `id.*` checks, the code lists of `src/zugferd/`, 4 decimals for tax rates), so that `check()` predicts them and a draft shows them; leave the rules that need the whole invoice (IP-DOC-03, IP-PAY-06) to the e-invoice engine. _Alternative:_ document that pipelines use `zugferd-errors: "report"` and read `e-invoice.status`.
6. **Q6 The role of `document-type`.** _Recommendation:_ issuer: a credit-note skeleton stays a credit note unless the data says otherwise (implemented). `subject`, `notes` and `currency` are issuer keys too; `customer-nr` and `project` are document keys. _Alternative:_ document (design D), where a credit-note skeleton hydrated without the key silently becomes an invoice.
7. **Q7 Custom fields: replaced or merged?** _Recommendation:_ the data's `custom` replaces the skeleton's sample `custom` as a whole (implemented): no sample can leak; constants belong in Typst code, defaults in `default:`. _Alternative:_ a key-by-key merge over `invoice(custom:)`, which lets a sample value survive.
8. **Q8 When is `<invoice-pro-result>` emitted?** _Recommendation:_ hydrated invoices and `--input invoice-pro-result=1` (implemented; no cost without data). _Alternative:_ every invoice, once it is measured at ≤ 1 ms without loading the descriptor.
9. **Q9 Printable characters.** Noncharacters are rejected (dev. 37). Open: C0 controls and texts of only format characters (`\p{Cf}`) give empty or invisible XML values; unassigned and private-use code points stop PDF/A. _Recommendation:_ reject C0 controls other than TAB, LF and CR, do not count `\p{Cf}` as filling a required text, and document unassigned and private-use characters as font-dependent, as for hand-written invoices. _Alternative:_ reject `\p{Cn}` and `\p{Co}` too (a private-use glyph of a custom font then cannot be used).
10. **Q10 Guards of the components on the data path.** The prototype turns a credit-note conflict into a data issue for `payment(..)` and `payment-terms(discount:)` (dev. 25, 42), but the raw `direct-debit(..)` and `card-payment(..)` still panic (O2). _Recommendation:_ one rule: when hydrated, what a component would stop on because of the data becomes a data issue and the component is left out; written in Typst, it still panics. _Alternative:_ panic on the data path too (a batch then aborts on one file).
11. **Q11 `payment-terms` and `bank-details` as binding points.** _Recommendation:_ no: `payment(..)` is the one binding point of the `payment` section; a skeleton that uses the single components gets the coverage issue `schema/payment` with the fix. _Alternative:_ make both components data-aware (five components with data rules instead of one block).
12. **Q12 A data `bank` with another method.** _Recommendation:_ leave it out without an issue, like the skeleton's own account (implemented, dev. 41): `bank` is standing issuer data and an invoice states one payment means. _Alternative:_ a data issue, which also flags a wrong IBAN that is never used.
13. **Q13 An object with every key absent.** `"terms": {"days": ""}` from a spreadsheet replaces the skeleton's terms with empty terms. _Recommendation:_ an optional object whose keys are all absent is itself absent (the skeleton's terms apply). _Alternative:_ keep "replaced as a whole" literally and document it.
14. **Q14 `""` for typed keys.** _Recommendation:_ keep the reader leniency (an optional `""` is absent for every type) and a schema that accepts `""` for texts only, so that producers' generated types stay precise (implemented, dev. 36). _Alternatives:_ accept `""` in the schema (generated dates and enums become unions), or reject it in the decoder (spreadsheet exports break).
15. **Q15 The internal speed PRs in 0.7.0?** _Recommendation:_ S7a and S7b with 0.7.0, as separate API-neutral PRs, because they are the margin of the perf gate; S7c and S7d when convenient; a cheaper keep-together check goes to a theme concept. _Alternative:_ all later.
16. **Q16 The nesting cap.** _Recommendation:_ cap 8 now; fix `collect-signals` in a bugfix PR (L24) and raise the cap in a minor. _Alternative:_ keep the cap and the bug.
17. **Q17 Declared typed custom fields and a `derive` hook.** _Recommendation:_ 0.7.x, as `load(.., extensions:, derive:)`, with names that shadow no builtin. _Alternative:_ in 0.7.0 (design D, the user judge).
18. **Q18 A result in the same compile** (`--input invoice-pro-result=attach`, a JSON file next to `factur-x.xml`). _Recommendation:_ 0.7.x, after Mustang and KoSIT accept a PDF with the extra attachment. _Alternative:_ in 0.7.0 as opt-in experimental.
19. **Q19 Names.** Settled by the prototype: `invoice(data:, custom:)`, `invoice-data` (10 names), `payment`, `invoice-data.items`, `<invoice-pro-result>`, the `invoice-pro-data*` keys; no builtin shadowed, the export test pins them. _Alternatives:_ `hydrate`, `data-format`.
20. **Q20 A partial sender** (a clerk per invoice, letterheads of several tenants). _Recommendation:_ `sender` is replaced as a whole; a per-invoice contact comes later through `derive`. _Alternative:_ "a data party without `name` completes the skeleton's".
21. **Q21 One spelling for units and taxes.** _Recommendation:_ UN/ECE codes (any Rec 20 code) or `{code, display}`; tax `"19%"` or an object, no presets (implemented; a second unit spelling broke the Rust generator). _Alternative:_ also unit names and presets such as `"exempt"`.
22. **Q22 JSON numbers.** _Recommendation:_ rejected for texts (the fix is shown), tolerated exactly for decimals (implemented). _Alternative:_ strings only.
23. **Q23 An explicit none.** _Recommendation:_ `null` is absent everywhere in v1; cancelling a cascaded value per child is not expressible. _Alternative:_ `null` = `none` where meaningful, which conflicts with generated model dumps.
24. **Q24 Sources and misspelt keys.** _Recommendation:_ an explicit `data:` value plus a data input panics, and so does a near miss of the two data keys (implemented); other `invoice-pro-*` keys stay free for skeletons. _Alternatives:_ data wins or input wins; catch every unknown `invoice-pro-*` key (would change invoices without data).
25. **Q25 YAML and TOML.** Settled by the prototype: JSON canonical, TOML and YAML by file extension, md5-identical PDFs (P7).
26. **Q26 Localized issue texts in 0.7.0.** _Recommendation:_ yes (L16 in S2): `schema-*` texts in the six languages and the chip "Daten / Data" instead of "Pflichtangabe". _Alternative:_ English messages first.
27. **Q27 `format` required.** Settled by the prototype: required; a missing one is an issue, another major panics.
28. **Q28 The schema host.** Settled by patch 0010: `https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/…`. Open: the docs build must publish the two files there (S6), or the `$id`s point at nothing.
29. **Q29 Tier.** _Recommendation:_ `invoice-data`, `payment` and `invoice(data:, custom:)` experimental, the format `invoice-pro/1` provisional. _Alternative:_ provisional throughout.
30. **Q30 `item(custom:)`.** _Recommendation:_ 0.7.x, for preview parity with data rows, and freeze `view.items[i].custom` in the part contract.
31. **Q31 Batches in one process.** _Recommendation:_ processes in 0.7.0; a documented 0.15 bundle pattern (or helper) later. _Alternative:_ an `invoice-data.batch` now.
32. **Q32 The locale from data.** _Recommendation:_ no in v1 (a locale is design and its customisations are closures); later a `locales: (de: .., en: ..)` map that the data selects by name.
33. **Q33 CSV rows for the marker** (`invoice-data.items(rows: ..)`, the roadmap's "Data Loading"). _Recommendation:_ 0.7.x; rows from Typst code are code, so bad rows panic.
34. **Q34 The scope of `check()`.** It checks what the decoder checks; a hydrated invoice can report more (skeleton rules, coverage, the legal and e-invoice rules). _Recommendation:_ document this in 0.7.0 and, with Q5, move the data-only e-invoice rules into the decoder. _Alternative:_ a `check(.., skeleton:)` that compiles the skeleton without layout (later, if asked for).
35. **Q35 Branch, folder and issue.** _Recommendation:_ open the GitHub issue first, rename the branch to `feature-data-api` (the harness branch is `claude/invoice-pro-programmatic-generation-1uwaga`), keep the concept at `docs/concepts/data-api/` with `process/` and `prototype/`, as the theming concept did. _Alternative:_ keep the harness branch.

---

## Appendix A: provenance

**Process.**

1. Research: nine readers produced the ground truth of the repository, with path:line evidence.
2. Designs: four proposals, each with a working prototype in a copy of the repository: A converters, B integrated, C performance, D contract.
3. Judgement: three judges (maintainer, engine, user) scored and ranked them; the panel digest merged their findings.
4. Synthesis: one unified design on base D with grafts from A, B, C and the judges, plus one new mechanism (re-entry), checked in a feasibility prototype.
5. Prototype: the synthesis built as one branch, with a self-check of ten proofs on both compilers.
6. Verification: four independent verifiers in three rounds (0, 1, 2), with two fix rounds (fix 1, fix 2) in between; then patch 0010.
7. This concept.

**Sources** (in `process/`, kept as produced; local paths are replaced by `<session>`, `<unified>` and `<repo>`):

| Kind      | Files                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| :-------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| research  | [conventions](process/research/conventions.md), [invoice-api](process/research/invoice-api.md), [line-items](process/research/line-items.md), [loom-engine](process/research/loom-engine.md), [payments-misc](process/research/payments-misc.md), [prior-art](process/research/prior-art.md), [theming-data-flow](process/research/theming-data-flow.md), [typst-cli](process/research/typst-cli.md), [validation-zugferd-locale](process/research/validation-zugferd-locale.md) |
| designs   | [A-converter](process/designs/A-converter.md), [B-integrated](process/designs/B-integrated.md), [C-performance](process/designs/C-performance.md), [D-contract](process/designs/D-contract.md)                                                                                                                                                                                                                                                                                   |
| verdicts  | [verdict-maintainer](process/designs/verdict-maintainer.md), [verdict-engine](process/designs/verdict-engine.md), [verdict-user](process/designs/verdict-user.md), [\_panel-digest](process/designs/_panel-digest.md)                                                                                                                                                                                                                                                            |
| synthesis | [synthesis](process/designs/synthesis.md)                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| prototype | [build](process/prototype/build.md), [deviations](process/prototype/deviations.md); the code in [`prototype/`](prototype/README.md)                                                                                                                                                                                                                                                                                                                                              |
| review    | [verification](process/review/verification.md)                                                                                                                                                                                                                                                                                                                                                                                                                                   |

**Where each element comes from.**

| Element                                                                                                                                                              | From                                      |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------- |
| `invoice(data: auto)`, roles, whole-value merge, `payment(..)`, the implicit slot, coverage issues                                                                   | B (adopted by D)                          |
| the descriptor → decoder, schemas, docs; JSON Pointer issues; the result shape, status and exit codes; conformance; codegen; `format` required; `$id` with the major | D                                         |
| the rows engine, the closure-held sample, region VAT rates, `{text}` → BT-20, the speed PRs, the equivalence generator                                               | C                                         |
| the static coat-of-arms patch, the `party()` normaliser, the explicit marker, the paid-by-transfer account, ASCII-only regexes                                       | A                                         |
| the unconsumed-input panic, `kind: null`, model-dump fixtures, units by pattern                                                                                      | user judge                                |
| the crash-free decoder gate, modifier scope, base quantity, country and currency checks, the nesting cap                                                             | engine judge                              |
| a small namespace, the result not always on, no copied defaults, separate speed PRs                                                                                  | maintainer judge                          |
| re-entry precedence                                                                                                                                                  | the synthesis                             |
| `""` absent for every type, the PDF/A limits, the item modifier without `tax`, near-miss keys, hydrated-only data issues of the components, `dependentSchemas`       | the prototype and its verification (dev.) |

## Appendix B: rejected alternatives

1. **Presence-only override** (design C): leaks samples into real invoices (`MUSTER-0001` in a clean EN 16931 XML, found by two judges).
2. **Converters and `.with` with base and sample dictionaries** (design A): restructures the skeleton, reports issues only through an internal channel, hides slot hazards.
3. **Copied defaults tables** (B in `invoice.typ`, D in the descriptor): drift silently; replaced by re-entry.
4. **A deep merge of parties**, also as an RFC 7386 merge patch: mixes identities.
5. **A result on every invoice that loads the descriptor** (design D): 4.79 + 2.29 ms traced for every invoice.
6. **A 27-name namespace** with type constructors that shadow builtins (`text`, `array`, `decimal`; design D).
7. **A body-only hydration component**: false "missing" issues, a wrong XML attached, strict does not stop.
8. **Skipping loom's measure pass**: 0–5 % on top of the bulk motif, couples format and skeleton, risks a stale `global`.
9. **Reading files in the package**: impossible on 0.14 and 0.15.
10. **`x-*` data keys for extensions**: break generated models; the `custom` bags instead.
11. **An expression language or `eval` in the data**: design stays Typst (§6.3).
12. **An undocumented `..args` wrapper around `invoice()`** to meet the 0.2 ms import budget: loses the signature, its docs and the editor hints (dev. 49).
13. **`oneOf`/`not` and `if`/`then` for cross-field rules**, and `maxLength` on every string: break the TypeScript and Rust generators (dev. 4, 21).
14. **Passing rows by path into a sealed document**: tried in fix 2, +2 % (dev. 48).
15. **Catching every unknown `invoice-pro-*` key**: would change invoices without data that read keys of their own (dev. 26).

## Appendix C: evidence index

In the repository (relative to this document):

- [`prototype/patches/`](prototype/patches/): the ten patches; [`prototype/run.sh`](prototype/run.sh): the 12 core checks; [`prototype/examples/`](prototype/examples/): `skeleton.typ`, `handwritten.typ` (the 0.6.0 twin of §3.11), `skeleton-path.typ` (0.15 `path`), `wappen/*.svg`; [`prototype/data/`](prototype/data/): `2026-0042.json`, `2026-0042.toml`, the `broken-*.json` and `w-*.json` cases.
- [`process/prototype/build.md`](process/prototype/build.md) (the builder's self-check), [`process/prototype/deviations.md`](process/prototype/deviations.md) (49 decisions), [`process/review/verification.md`](process/review/verification.md) (rounds 0–2, fix 1, fix 2, still open).

In the scratch directory of the exploration (not in the repository):

- `<session>/exp/unified/`: the prototype's clone (`repo/`, branch `proto`, and `repo-s7a/`, branch `proto-s7a`), a pristine clone, the harness `proto/` (`selfcheck.sh`, `gen/`, `eq/`, `edge/`, `regress/`, `misuse/`, `fuzz/`, `schema/`, `payment/`, `wappen/`, `result/`, `signature/`, `bench/`), the runbook `README.md`, the verifiers' directories `verify-{equivalence,robustness,contract,features-perf}/` and the fix rounds `fix1/`, `fix2/`, `vr2/`.
- `<session>/exp/design-{A-converter,B-integrated,C-performance,D-contract}/`: the design prototypes; `<session>/judge-engine/`, `<session>/exp/judge-user/`, `<session>/judge/`: the judges' runs; `<session>/exp/synth/`: the re-entry feasibility check; `<session>/design/SYNTHESIS.md`: the synthesis.
