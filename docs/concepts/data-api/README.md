# invoice-pro data API (phase 1): programmatic invoices from one data format

Status: concept for review, second draft (2026-11-03), target release 0.7.0. Proposed tier: the API (`invoice(data:, custom:)`, `invoice-data`, `payment`) is experimental, the data format `invoice-pro/1` is provisional (Q29). Nothing of it is in `src/` yet. What exists is this concept and a prototype: ten patches on top of 0.6.0 (`df934a7`) in [`prototype/`](prototype/README.md), with examples, data, the sources of its test harness and a script that reproduces the core proofs. The prototype implements the unified design of the exploration ([`process/designs/synthesis.md`](process/designs/synthesis.md), "the synthesis"). Four independent verifiers checked it in three rounds, with two fix rounds in between ([`process/review/verification.md`](process/review/verification.md)). Three critics then reviewed the first draft ([`process/review/draft-1.md`](process/review/draft-1.md); the critiques are `process/review/critique-*.md`), and Appendix E lists what this draft changed. This document describes the design **as prototyped**. Where the prototype differs from the synthesis, the text says so and cites the entry of [`process/prototype/deviations.md`](process/prototype/deviations.md) as "dev. n". Every number names its source and its compiler: the build report ([`process/prototype/build.md`](process/prototype/build.md)), the verification report, a design prototype, a critique, or a measurement made for this draft ("measured for this revision", with its method). _Proposed_ marks what was not built. Compilers: everything was verified on Typst **0.15.1 and 0.14.2** unless a line says otherwise. Paths that start with `src/`, `tests/`, `tools/`, `template/` or `docs/` are relative to the repository root; `process/` and `prototype/` are relative to this document; `<session>` is the scratch directory of the exploration, which is not part of the repository. Question numbers are those of §14; the synthesis and the process files number the questions differently (Appendix D maps them). The `typst` blocks carry no package import: they assume `#import "@preview/invoice-pro:<version>": *`. Blocks that write `..party` also assume a dictionary `party` with `sender`, `recipient`, `invoice-nr` and `date`; blocks that read files (`wappen/*.svg`, `d.json`, `batch.json`) assume them next to the skeleton. All `typst` blocks are typstyle-0.15.1-clean and compile against the prototype on both compilers. Shell lines write `@preview/invoice-pro:<version>` where a version is needed.

---

## Executive summary

**The idea.** You design an ordinary invoice in Typst, with sample values: the _skeleton_. It previews like any invoice. To produce a real invoice, a program hands over one JSON object in the format `invoice-pro/1`, and invoice-pro _hydrates_ the skeleton with it. The data replaces what identifies one invoice: the number, the dates, the recipient, the references, the line items, the details of a direct debit, card or paid invoice, and the custom fields. The skeleton's own values for these are samples: `data:` replaces every document key, so the data carries the whole invoice, not only its rows. The issuer's settings (letterhead, bank, payment terms, tax settings) keep the skeleton's values unless the data gives them. The design never comes from data. Problems in the data become ordinary `data` issues of the existing validation levels: a draft with markers and no e-invoice under `"draft"`, one panic that lists every problem under `"strict"`.

**The workflow.**

1. Design `skeleton.typ` by hand and preview it: `typst compile skeleton.typ`.
2. Make it a skeleton (§2.0): add one line, `#let record = invoice-data.load(read: p => read(p, encoding: none))`, and pass `data: record` to `invoice`. If the data carries payment details, write one `payment(..)` block instead of `payment-terms(..)` and `bank-details(..)`. Inline JSON without a payment section needs no change at all.
3. Hydrate it with one flag per invoice: `typst compile --pdf-standard a-3b skeleton.typ out/2026-0042.pdf --input invoice-pro-data-file=data/2026-0042.json` (Typst does not create `out/`; run `mkdir -p out` first).

**What is added.** Two `invoice()` parameters (`data`, `custom`), two root exports (`invoice-data` with 10 names, and `payment`), three `--input` keys, one metadata label (`<invoice-pro-result>`), one reserved party key (`custom`) and one region key (`normalize.vat-rates`). The PDF of an invoice that is not hydrated does not change: per compiler, 1105 documents compile to the same PDF bytes or the same error on 0.6.0 and on the prototype, except 9 that pass a misspelt data key, which now panics on purpose (P2, §11). These changes are not pure extensions, and §9 justifies each: near-miss data keys panic, which reserves the prefix `invoice-pro-data*` (L7); `import *` binds two more names (L5); every `line-items` body gains one loom level (L9); a party key `custom` no longer warns (L13); the region key (L15, which still has a defect, Q41); two bug fixes on the shared path (L29, L30).

**Cost.** About 30–40 maintainer-days for 0.7.0 as recommended: S0–S6 26–35.5 d, the bug fixes S8 1.5–2 d and the speed PRs S7a and S7b 2.5–3 d (§12; rough estimates). The change adds 4970 Typst lines to `src/` (+15 % of 32 813) and grows the published `src/` by 25 %, from 1 131 975 to 1 413 689 bytes; 108 015 of these bytes are the two JSON Schemas, which no Typst code reads (Q37; measured for this revision on the prototype tree). The largest maintenance cost: until S7c and S7d land, the rows engine is a second implementation of the line-item cascade, guarded only by the equivalence suite (§13, risk 1).

**Speed.** The line items of the data become one bulk loom motif instead of one motif per row, and loom's second pass is a cache hit. A hydrated 300-row e-invoice takes 0.571× (Typst 0.15.1) and 0.568× (0.14.2) of the time of the same invoice written by hand on 0.6.0, with byte-identical PDFs (pooled medians of 29 runs). At 50 rows it is 0.67–0.80×. At 5 rows there is no gain (0.96–1.12×): a typical small invoice takes about 0.46 s either way, and the package import is a quarter of it (§7.0). Every invoice pays for the new code: the package import runs about 1.2–1.5 ms longer, which misses the synthesis' budget of 0.2 ms, and a hand-written invoice runs 0.4–0.5 % more instructions (§7.3).

**Prototype.** Ten proofs. After the last verification round, equivalence (P1), no regression (P2), the payment block (P6) and the coat of arms (P7) pass on both compilers. Crash-freedom (P4) holds on the fault corpora (0 hard aborts in 69 faults and in 1406 corpus runs per compiler), but three classes of hostile input still stop the build (two of them only under PDF/A), and the performance budget for the import is missed. §11.5 lists what is open. None of it changes the Typst API; O3, O4, O8 and O10 tighten the provisional format. The sources of the test harness are in [`prototype/harness/`](prototype/harness/README.md); its generator reproduces the committed conformance fixtures byte for byte.

**What I need from you** (§14, grouped by the stage that needs the answer; each decision has a recommendation and the consequence of the alternative). Before S1: Q1 data errors as issues or panics; Q5 which e-invoice rules that depend only on the data become data issues. Before S2: Q6 the role of `document-type`; Q7 custom fields replaced or merged; Q19 three names; Q41 the VAT rates of a customised region. Before S3 and S4: Q4 the binding point of the line items; Q10 the component guards on the data path. Before S5 and S6: Q2 a restated budget for the package import; Q3 the performance gate on instruction counts; Q36 the shipped template as a skeleton.

## Requirement coverage

| #   | Requirement (maintainer)                                                                                                                                             | Mechanism                                                                                                                                                                                                                             | Evidence                                                                                                                                                                                                                                                                                                                                              | Where      |
| :-- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------- |
| 1   | One uniform data format, read from a file or from the system inputs                                                                                                  | `invoice-pro/1`: one JSON object per invoice; TOML and YAML decode to the same values. `--input invoice-pro-data=<JSON>`, `--input invoice-pro-data-file=<path>` (read by the skeleton's one-line callback), stdin, a 0.15 `path`     | P7: file, inline, stdin (redirect and pipe), TOML, YAML and the 0.15 path give one PDF (md5 `32b0b6d5d449` on 0.15.1, `679ee994c66b` on 0.14.2), equal to the hand-written twin on 0.6.0                                                                                                                                                              | §3, §5     |
| 2   | Extensible: custom fields                                                                                                                                            | Open `custom` bags at document, party and line level; every other object is closed                                                                                                                                                    | Unit test and custom probe of the build (`ctx.custom` via `info.get` and `dynamic`, `ctx.recipient.custom`); `view.items[i].custom` of data rows (§6.1)                                                                                                                                                                                               | §3.8, §6.1 |
| 3   | Extensible: change something by a field value, such as a coat of arms by post code                                                                                   | The skeleton decides in Typst: a static theme patch chosen at document level from `invoice-data.values(record)` and `invoice-data.party(..)`; a draw-time wrap as the fallback; rules must tolerate absent and mistyped values (§2.1) | P7: 80331 → Bavaria, 20095 → Hamburg, 10115 → Berlin, 50667 → neutral, `custom.wappen` overrides; 28 logo crops checked by eye; the static patch keeps the e-invoice print checks active, the wrap does not                                                                                                                                           | §2.1, §6.2 |
| 4   | Easy integration: build and design an invoice by hand, then hydrate the data into the skeleton                                                                       | `invoice(data: auto)`; a role per key (design, issuer, document); re-entry, so the signature's own defaults apply; the `line-items` body and `payment(..)` are the binding points; §2.0 lists what an existing invoice needs          | P1: 0 failures over a 36-case matrix, 1000-row cases, 13 edge fixtures and 660+ generated cases, byte-identical (XML included) to the hand-written invoice on 0.6.0; P3: no sample value leaks into a hydrated invoice. Ease: the shipped template becomes a skeleton with three added lines and the `payment(..)` swap, md5-identical to 0.6.0 (Q36) | §2, §4     |
| 5   | Fast: skip loom steps where possible                                                                                                                                 | One bulk motif instead of one motif per row; pass 2 is a memo hit; sealed payloads; lazily imported modules                                                                                                                           | P9: 300 rows 0.571× / 0.568×; 50 rows 0.67–0.80×; 5 rows no gain; no contract module in the trace of an invoice without data                                                                                                                                                                                                                          | §7         |
| 6   | Design and appearance stay in Typst; only the data is exchanged                                                                                                      | No design key in the format (closed objects); `theme`, `locale`, `references`, `zugferd`, `zugferd-errors`, `validation` pass through unchanged                                                                                       | Committed schema: every object `additionalProperties: false` except the three `custom` bags and the typed `extra` maps (label → text); P10: the 7 design parameters are classified and never read from data                                                                                                                                           | §3.1, §4.2 |
| 7   | Extend the APIs, do not change them; justify every change                                                                                                            | 2 parameters, 2 root exports, 3 input keys, 1 label, 1 reserved party key, 1 region key; every other change is internal, hydrated-only, a bug fix or one of the ⚠ rows of §9                                                         | P2: 1105 documents per compiler unchanged except the intended near-miss panic; §9 marks and justifies L5, L7, L9, L13, L15, L16 and the bug fixes                                                                                                                                                                                                     | §9         |
| 8   | Phase 1: a general interface for the Typst CLI; phase 2 (native bindings) is not in scope. Inferred, not the maintainer's words: phase 1 should not stand in its way | CLI conventions with exit codes and a result record; committed JSON Schemas, conformance fixtures, code generation                                                                                                                    | P5: schema and decoder agree on 135 + 51 fixtures, and on 3154 mutations except the documented leniencies and 57 python-jsonschema trailing-newline cases; pydantic, TypeScript and Rust types generate and round-trip; P8: the result record is schema-valid in 450 of 450 cases, `typst eval` (0.15) and `typst query` (0.14) give the same JSON    | §5, §10    |

**Not in 0.7.0**, although the request or the roadmap could be read to ask for it:

- **Items alone from a file in a hand-written invoice** (the roadmap's "Data Loading": "load invoice items directly from JSON, CSV, or YAML"). `data:` hydrates the whole invoice: a skeleton that sets its own number and recipient and passes `data: (format: "invoice-pro/1", items: ..)` gets a draft, because its document keys are samples (measured for this revision: 4 problems, the number, the date, the recipient's name and address). Workaround: map the rows to `item(..)` calls as in 0.6.0, or put the whole invoice into the data. The roadmap checkbox stays open (Q33).
- **Document keys computed from the data** (`derive`) and **declared, typed custom fields** (Q17).
- **A result in the same compile** (Q18) and **a machine-readable failure** of a strict build (§5.9, Q42).
- **A one-process batch of e-invoices**: a PDF carries one `factur-x.xml`. Print invoices without an e-invoice work in one document today (§5.3, Q31).
- **`item(custom:)`** for hand-written rows (Q30) and **a locale key in the data**; the skeleton chooses the locale by a value (§6.2, Q32).
- **Native bindings** (phase 2).

## Design decisions at a glance

| #   | Decision                         | Choice                                                                                                                                                                                                | Why                                                                                                                                                     | Alternative / question                                          |
| :-- | :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------ | :-------------------------------------------------------------- |
| 1   | Entry point                      | `invoice(data: auto)`; `auto` reads `--input invoice-pro-data`; also a record, a dictionary, JSON bytes or text, a 0.15 `path`                                                                        | Data issues must join `invoice()`'s own checks: draft markers, the strict panic, the withheld XML                                                       | Converters and `.with` (design A); body-only hydration (App. B) |
| 2   | Precedence                       | A role per key: design (never data), issuer (the skeleton's value unless the data gives it), document (from the data only; the skeleton's value is a sample)                                          | A sample can never leak into a real invoice (P3)                                                                                                        | Presence-only override (leaked `MUSTER-0001` into a clean XML)  |
| 3   | Defaults of absent document keys | **Re-entry**: the hydrated call calls `invoice(..effective, data: <marker>, body)` and leaves absent document keys out, so the signature's defaults apply                                             | No second copy of the defaults that could drift                                                                                                         | A private defaults table                                        |
| 4   | Merge                            | No deep merge: parties, `city`, `contact`, tax objects, `terms`, `bank` and `custom` are replaced as a whole; the `payment` section applies key by key                                                | A merge can pair one party's VAT ID or BIC with another party's name or IBAN                                                                            | Q20 (partial sender)                                            |
| 5   | Custom fields                    | Role document: the data's `custom` replaces the skeleton's sample `custom` as a whole                                                                                                                 | The same no-leak rule as every per-invoice value                                                                                                        | Key-by-key merge, Q7                                            |
| 6   | Files                            | `--input invoice-pro-data-file=<path>`, opened by the skeleton: `invoice-data.load(read: p => read(p, encoding: none))`; JSON, TOML or YAML by extension; stdin via `/dev/stdin`                      | A package cannot open the user's files (0.14 and 0.15)                                                                                                  | A user-defined key per skeleton                                 |
| 7   | One source                       | A data input that nothing consumes, a misspelt data key, or two sources → panic with the one-line fix                                                                                                 | Otherwise a strict build ships the sample invoice                                                                                                       | Ignore them (Q24)                                               |
| 8   | Line items                       | One bulk motif (design C's engine) emits the frames that `item`/`group`/`bundle`/`discount`/`surcharge`/`prepayment` would emit                                                                       | Byte-identical output, 0.57× time at 300 rows                                                                                                           | A motif per row                                                 |
| 9   | Binding point of the items       | The body of `line-items` (implicit); an optional `invoice-data.items[..]` marker keeps static rows; at most one, asserted                                                                             | An existing invoice hydrates its items without marks (its payment needs `payment(..)`, §2.0); a fixed fee is still possible                             | Marker required, or implicit only (Q4)                          |
| 10  | Payment                          | A `payment(..)` block that places `payment-terms`, `bank-details`, `direct-debit`, `card-payment` or `paid`                                                                                           | Which payment components exist is data; one means per invoice (CII-SR-467/470)                                                                          | Data-aware `payment-terms`/`bank-details` (Q11)                 |
| 11  | Decoder                          | Generic over one descriptor table (design D), crash-free: every value is pattern-checked before `decimal()`, `datetime()` or a constructor sees it                                                    | Typst has no try/catch; one descriptor gives the decoder, both JSON Schemas, the docs and the roles                                                     | Hand-written decoders per key                                   |
| 12  | Encodings                        | Decimal strings, `"19%"`, ISO dates, `{start, end}` periods, UN/ECE unit codes or `{code, display}`, tax `"19%"` or an object; `null` and an optional `""` mean absent                                | Exact money, bit-exact rates, one spelling per concept for code generators, spreadsheet cells                                                           | Unit names and tax presets (Q21)                                |
| 13  | Errors                           | A data problem is a class-`data` issue `schema/<JSON Pointer>`; Typst misuse, a foreign format major and an unconsumed input panic                                                                    | Reuses draft/strict/none unchanged; ids are machine-readable                                                                                            | Always panic (Q1)                                               |
| 14  | Namespace                        | `invoice-data`: `format`, `input-key`, `file-key`, `load`, `decode`, `check`, `values`, `party`, `items`, `schema`                                                                                    | `invoice(data:)` with a prefix, because `data` alone would be shadowed by `#let data = json(..)`; no Typst builtin shadowed by `import invoice-data: *` | `hydrate`, `data-format` (Q19)                                  |
| 15  | Result                           | `<invoice-pro-result>` (`invoice-pro-result/1`) on hydrated invoices, or with `--input invoice-pro-result=1`; loaded lazily                                                                           | Pipelines read totals and the outcome; invoices without data pay nothing                                                                                | On every invoice (Q8)                                           |
| 16  | Data-dependent design            | A static theme patch chosen at document level from `invoice-data.values(record)`                                                                                                                      | Keeps the e-invoice checks of printed content (IP-PRINT-03, IP-PERIOD-03) active                                                                        | A draw-time wrap (documented fallback)                          |
| 17  | Data-dependent parameters        | Issuer keys: Typst expressions on `values` in the skeleton; document keys: a `derive` hook in 0.7.x                                                                                                   | No expression language in data; a small 0.7.0 surface                                                                                                   | `derive` in 0.7.0 (Q17)                                         |
| 18  | Speed                            | One bulk motif; a pure `compute(rows, env)`, so pass 2 is a memo hit; sealed payloads; lazy modules; loom's two passes kept                                                                           | Skipping pass 1 would gain only 0–5 % more and couple format and skeleton                                                                               | A single pass (rejected, §7.2)                                  |
| 19  | Schemas and conformance          | JSON Schema 2020-12 for the data and the result, generated from the descriptor, committed under `src/contract/`; a drift command (CI step proposed, S1); 135 conformance fixtures and their generator | "Valid for the schema" must mean "accepted by invoice-pro"                                                                                              | Generate at release only                                        |
| 20  | Versioning                       | `"format": "invoice-pro/1"` or `"invoice-pro/1.<minor>"`, required; SchemaVer; `$id` with the format major only, on the docs site                                                                     | Producers state the contract; `scripts/check-version` is unaffected                                                                                     | Optional `format` (Q27)                                         |
| 21  | Tier                             | API experimental, format provisional                                                                                                                                                                  | Precedent: `from-data`, `zugferd`                                                                                                                       | Provisional throughout (Q29)                                    |

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

- **The skeleton is an ordinary invoice.** Without data it renders its samples like any invoice, and an invoice without data renders byte-identical to 0.6.0 (P2). A skeleton needs no marks for its items; a data `payment` section needs the `payment(..)` block (§2.0).
- **Hydration happens inside `invoice()`.** The data's values pass the same type checks, legal checks and e-invoice rules as values written in Typst, so a data problem is reported where every other problem is reported, and an incomplete e-invoice is never attached. One known exception remains: a locale whose `infer-tax` was replaced keeps its region's list of VAT rates, so the data path refuses a rate that the hand-written path accepts (L15, Q41).
- **No default is copied.** A document key that the data lacks is left out of the re-entered call, so `invoice()`'s own signature decides. A new default in a later release applies to hydrated invoices automatically.

## 2. The workflow, step by step

### 2.0 Make an existing invoice a skeleton

An ordinary invoice hydrates from inline JSON without any change, as long as the data has no `payment` section:

```typst
#show: invoice.with(..party)

#line-items[
  #item("Sperrmüllabholung", price: 45)
]
```

```sh
typst compile invoice.typ --input invoice-pro-data="$(cat d.json)"
```

What else an invoice needs depends on the data and on what the skeleton does with it:

| Change                                                                                            | Needed when                                                                                             |
| :------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------ |
| none                                                                                              | inline JSON (`--input invoice-pro-data`) without a `payment` section                                    |
| the `load` line and `data: record`                                                                | a data file, stdin, or a design rule that reads the data (§2.5)                                         |
| `payment(..)` instead of `payment-terms(..)`, `bank-details(..)` and the other payment components | the data has a `payment` section; otherwise a draft with the issue `schema/payment`, and `strict` stops |
| the per-invoice values gathered in a `sample` dictionary (§2.1)                                   | only for a design rule that should also preview the samples                                             |
| `invoice-data.items[..]` around the sample rows                                                   | a row that stays on every invoice (§2.4)                                                                |

The shipped template (`template/invoice.typ`, which `typst init` installs) needs the first three. This is the whole diff:

```diff
+#let record = invoice-data.load(read: p => read(p, encoding: none))
+
 #show: invoice.with(
+  data: record,
   theme: theme.bold, // the look, see THEMES above
@@
-#payment-terms(days: 14)
-
-#bank-details(
-  bank: "Musterbank",
-  iban: "DE07100202005821158846",
-  bic: "EXAMPLEBICX",
+#payment(
+  terms: (days: 14),
+  bank: (
+    bank: "Musterbank",
+    iban: "DE07100202005821158846",
+    bic: "EXAMPLEBICX",
+  ),
 )
```

Measured for this revision, with `--creation-timestamp 1767225600`: the converted template gives the same PDF as the unchanged template on 0.6.0, on 0.15.1 (`881821b7318c`; with `--pdf-standard a-3b` `ba5d9a49b5de`) and on 0.14.2 (`8a1c8b464422`, `c7e98da669bc`), the md5s of P2. Hydrated under `strict` from a file with a direct debit and a creditor ID, it gives a final invoice with `factur-x.xml` on both compilers. §3.11's data relies on the skeleton's creditor ID, which the template lacks, so with that file the converted template stops with "`payment.creditor-id` is required", as it should. The prototype leaves the template unchanged; Q36 asks whether 0.7.0 ships it as a skeleton.

### 2.1 Design the skeleton

The skeleton below is the prototype's `prototype/examples/skeleton.typ` without its header comment and import line. It previews alone, and it hydrates without edits.

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

**Rules must tolerate incomplete data.** The decoder drops invalid values and rows, so `invoice-data.values(record)` can lack any key, the required ones included, and custom fields are untyped. A rule that assumes a key or a type stops the compile with a Typst error, and the draft that would show the data's problems never appears. That is why the rule above reads every value with `.at(.., default: none)`, tests `type(..)` before it calls a method or `in`, and passes a possibly absent party to `invoice-data.party(..)`, which accepts `none`. The requirements critique measured the difference on both compilers: the same rule written without these guards (`values.recipient`, `.post-code.starts-with("8")`) aborts on 3 of 3 incomplete files (no recipient, a city without post code, a numeric post code), and the rule above compiles them all, also with `"custom": {"wappen": 5}`. A `default:` parameter of `values` would replace the `shown` idiom (_proposed_, Q43).

**The post-code rule is illustrative.** The first digit does not determine a Land: 88xxx is in Baden-Württemberg, and 1xxxx and 2xxxx span several Länder. A real rule reads a table of the project, for example a CSV turned into a dictionary. In the requirements critique an 8246-row table cost no measurable time (0.532 s against 0.526 s, medians of 7, 0.15.1).

### 2.2 Preview, then hydrate

```sh
# preview: the skeleton with its samples
typst compile skeleton.typ

# one invoice from a file (the canonical way); .toml, .yaml and .yml work by extension
mkdir -p out
typst compile --pdf-standard a-3b skeleton.typ out/2026-0042.pdf \
  --input invoice-pro-data-file=data/2026-0042.json

# for sending: any problem stops the build with exit code 1
typst compile --pdf-standard a-3b skeleton.typ out/2026-0042.pdf \
  --input invoice-pro-data-file=data/2026-0042.json --input invoice-pro-validation=strict
```

`--pdf-standard a-3b` is needed for a conforming PDF/A-3 Factur-X/ZUGFeRD file; without it the XML is still attached, but the file is not fully compliant. Inline JSON, stdin, batches, results and a pipeline are in §5.

**Paths.** The skeleton's `read` callback opens the data file, so a relative path resolves against the skeleton file, not against the shell's working directory, and `/…` against the project root (`--root`, by default the skeleton's folder). The data file must lie under the root. With the skeleton in `skel/` and the data in `data/`, run from the project folder:

```sh
typst compile --root . skel/skeleton.typ out/2026-0042.pdf \
  --input invoice-pro-data-file=/data/2026-0042.json
```

The same command with `data/2026-0042.json` fails with "file not found (searched at …/skel/data/2026-0042.json)" (measured for this revision). Pipelines should write root-relative paths.

**A preview with real data.** An editor or the web app has no `--input`. To see the skeleton with a real data file while designing, inject the file through `load`'s `inputs:` parameter. A data input on the CLI replaces it, and the condition keeps inline JSON from counting as a second source (R7):

```typst
#let preview = if "invoice-pro-data" in sys.inputs { (:) } else {
  (invoice-pro-data-file: "d.json")
}
#let record = invoice-data.load(
  read: p => read(p, encoding: none),
  inputs: preview + sys.inputs,
)

#show: invoice.with(data: record, ..party)

#line-items[
  #item("Leerung Restmüll 120 l", quantity: 4, unit: unit.pcs, price: 12.5)
]
```

Checked for this revision on both compilers: alone, the block shows `d.json`; `--input invoice-pro-data-file=…` and `--input invoice-pro-data=…` replace it. Remove the injection before the skeleton goes into production; otherwise a forgotten `--input` produces the preview's invoice.

### 2.3 What the data replaces

The data file is §3.11's example. Results of P7 on both compilers:

| Shown on the invoice    | Skeleton alone                         | Hydrated with `2026-0042.json`                                                                                                  |
| :---------------------- | :------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------ |
| Title                   | "Rechnung MUSTER-0001"                 | "Rechnung 2026-0042"                                                                                                            |
| Recipient               | Erika Mustermann, 10115 Berlin         | Bayerische Beispiel AG, 80331 München                                                                                           |
| Coat of arms            | Berlin (post code 10115 of the sample) | München (`custom.wappen` overrides the Bavarian arms that 80331 would pick)                                                     |
| Custom text             | "Tarif: Grundversorgung"               | "Tarif: Gewerbe M"                                                                                                              |
| Line items              | the two sample rows                    | the data's rows: 7 invoice lines (items, a group, a bundle), a surcharge, a prepayment                                          |
| Letterhead, creditor ID | the skeleton's                         | the skeleton's (issuer keys the data does not give)                                                                             |
| Payment                 | transfer with account and EPC-QR code  | the data's direct debit with the debtor's IBAN; no payee account (`bank-details`) and no QR code (CII-SR-467); the data's terms |
| E-invoice               | EN 16931 XML attached                  | EN 16931 XML attached, 0 errors; totals net 532.59, VAT 85.12, due 517.71                                                       |

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

| Skeleton                                | Inline `--input invoice-pro-data`                                          | `--input invoice-pro-data-file` | Design rules on the data at evaluation time |
| :-------------------------------------- | :------------------------------------------------------------------------- | :------------------------------ | :------------------------------------------ |
| any 0.7.0 invoice, no change            | hydrates its items (`data: auto`); a `payment` section needs `payment(..)` | panics with the one-line fix    | no (draw-time rules only, §6.2)             |
| with the `load` line and `data: record` | hydrates                                                                   | hydrates                        | yes (`invoice-data.values(record)`)         |
| `data: none`                            | panics: the input would be unused                                          | panics                          | –                                           |

A package cannot open a path the user names, on 0.14 or 0.15. The file must be read by a function written in the skeleton, which is why `load` takes `read: p => read(p, encoding: none)`. A relative path resolves against the skeleton, `/…` against the project root, and the file must lie under the root (§2.2).

## 3. The data format `invoice-pro/1`

The format is declared once, in a descriptor table (`src/contract/schema.typ`, prototype). The decoder, both JSON Schemas, the roles of the hydration and the reference tables below are read from it.

### 3.1 Principles

1. **One JSON object is one invoice.** JSON is canonical. TOML and YAML files decode to the same values (chosen by file extension); TOML dates arrive as native datetimes and are accepted. A UTF-8 byte order mark at the start of a file is tolerated.
2. **The canonical subset of the Typst API.** Keys are the kebab-case names of `invoice()`, of the party dictionaries and of the components. Where the Typst API has aliases (`street`, `region`, a flat `contact-name`, `phone` and `email`, a ship-to `location-id`, unit names), the format keeps exactly one spelling.
3. **A closed core with named open bags.** Every object is closed (`additionalProperties: false`). An unknown key is a data issue with a did-you-mean hint and, in parties, the hint of the e-invoice alias table (`plz` → "write the post code into `city`"). Openness lives only in the three `custom` bags and in the `extra` maps of the parties (label → text, printed only).
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
- the amount range: `|price| × max(|quantity|, 1) ÷ min(base-quantity, 1) < 10^18`, computed in floats. The bound is conservative: a quantity below 1 or a base quantity above 1 does not lower it, and float rounding already refuses a price of `"999999999999999999"` (checked for this revision with `check()`; O23);
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
- _hydrated only_ (`payment(..)`): a method whose required details are missing (`"method": "card"` without `card`, `"direct-debit"` without a mandate) is an issue, and its component is left out. The schema and `check()` accept `{"method": "card"}` alone (checked for this revision; O15, Q34). The decoder catches only a details object that lacks its required key (a `direct-debit` object without `mandate`, a `card` object without `last4`);
- _hydrated only_ (`payment(..)`, dev. 25b, 42): a credit note or a self-billed invoice drops a cash discount, a direct debit or a card payment with a data issue, whether the data's or the skeleton's (their senders pay; the components panic for Typst authors). The same treatment is still missing for the raw components `direct-debit(..)` and `card-payment(..)` in a skeleton (Q10);
- _hydrated only_ (dev. 25c, 41): a transfer without any account is an issue when the data chose it, when it replaced the skeleton's own method, or when the data says paid by transfer. A skeleton's own transfer without a bank stays as written (it equals the hand-written components);
- a data `bank` with another method (card, direct debit, paid cash or card) is left out **without** an issue, like the skeleton's own account: an invoice states one payment means (CII-SR-467), and `bank` is standing issuer data (dev. 41, Q12);
- a `bank` without IBAN stays a partial object, so the decoder and `bank-details` each report it (two issues, by design, dev. 25); a `direct-debit` without `mandate` is likewise reported by the decoder and by the payment block. Both issues of the mandate carry the same id, `schema/payment/direct-debit/mandate`: the draft report counts it once, the strict panic and the result twice. For `prototype/data/bad.json` that gives "ENTWURF · 6 Probleme", "invoice-pro found 7 problems" and 7 result issues (measured for this revision; O16).

### 3.8 Custom fields

| Level    | Where in the data                                                              | Where the skeleton reads it                                                                                                                                          | Stored                                                    |
| :------- | :----------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------- |
| document | `custom`                                                                       | at evaluation time `invoice-data.values(record).custom`; theme parts and wraps `ctx.custom.x`; the body `info.get("custom", "x", default: ..)`, `dynamic(ctx => ..)` | `ctx.custom`, sealed in `metadata`, so its size costs ≈ 0 |
| party    | `sender.custom`, `recipient.custom`, `delivery-address.custom`, `payee.custom` | `ctx.recipient.custom`, `view.recipient.custom`, `info.get("recipient", "custom", "x")`, at evaluation time through `values`                                         | the normalised party (unsealed: keep it small)            |
| item     | `items[..].custom` at any depth                                                | `view.items[i].custom`, `view.entries[j].custom` in table parts, wraps and hooks                                                                                     | the item signal                                           |

v1 bags are open and untyped. Declared, typed custom fields with a schema export are a 0.7.x follow-up (Q17).

### 3.9 Limits the decoder checks and the schema does not

The JSON Schema cannot state these without breaking the code generators (a `maxLength` on every string makes typify wrap every string in a newtype; `if`/`then` makes it panic). They are pinned by `decoder-only` conformance fixtures.

| Rule                                                                                         | Why                                                                                                                                                                      | Source    |
| :------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------- |
| a decimal has at most 28 significant digits                                                  | `decimal()` aborts on 29–30 digits, which the pattern admits                                                                                                             | dev. 4    |
| the amount range, a conservative float bound (§3.6); `base-quantity` ≥ 0.0001 after rounding | the guards of `calc-item`                                                                                                                                                | dev. 4    |
| a text has at most 10 000 characters                                                         | a longer unbroken word exceeds the 32 767-byte string limit of PDF/A                                                                                                     | dev. 4    |
| `invoice-nr`, `subject`, a party `name` (all lines) at most 4000 characters                  | they become the PDF title, description and author, which PDF/A writes in UTF-16 (the schema has `maxLength: 4000` on the plain strings; the lines total is decoder-only) | dev. 37   |
| strings inside `custom` at most 10 000 characters                                            | the same PDF/A limit, when a skeleton prints them                                                                                                                        | dev. 37   |
| no noncharacters U+nFFFE, U+nFFFF in a text or a custom string                               | no font has a glyph; PDF/A stops                                                                                                                                         | dev. 37   |
| a date's year is 1–9899                                                                      | Typst aborts past 9999-12-31 (a Rust panic, exit 101); the due date adds up to 36 500 days                                                                               | dev. 4    |
| nesting at most 8, rejected before the descent                                               | the totals bug (L24) and Typst's call-depth limit (reached at depth ≥ 24)                                                                                                | dev. 4    |
| the region's VAT rates                                                                       | `infer-tax` panics on an unknown rate                                                                                                                                    | dev. 7    |
| the modifier VAT scope                                                                       | "modifier has no items to take its VAT category from" crashed all four design prototypes                                                                                 | synthesis |

### 3.10 Versioning

- `format` is required: `"invoice-pro/1"` (minor 0) or `"invoice-pro/1.<minor>"` (the minor the data needs). Version numbers of any length are read without an integer overflow (fix 1).
- SchemaVer: a new optional key is a new minor; a rename, a removal or a changed meaning is a new major. Closed objects keep additions additive.
- Data written for a newer minor: an unknown key's message adds "The data is written for invoice-pro/1.2; this invoice-pro reads invoice-pro/1.0: update invoice-pro, or leave the key out."
- Another major: `invoice()` panics with "invoice data is in format "invoice-pro/2"; this invoice-pro reads invoice-pro/1 only. Convert the data, or use an invoice-pro that reads invoice-pro/2."; `invoice-data.check` reports it as an issue.
- Every key records `since` (`x-invoice-pro-since` in the schema; 189 annotations, counted in the committed schema). The `$id` carries the format major only, not the package version, so `scripts/check-version` is unaffected. The schemas are to be hosted on the documentation site (patch 0010): `https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/invoice.schema.json` and `…/invoice-pro/1/result.schema.json`.

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

The type list of `data` omits `path`, which the parameter accepts on 0.15; S2 corrects the doc comment.

### 4.2 Hydration: re-entry and the precedence rules

**The algorithm** (`src/invoice.typ` +95 lines in the prototype; the rest lives in the lazily imported `src/contract/hydrate.typ`):

1. If `data` is the internal _applied marker_ (sealed `metadata((kind: "invoice-pro-applied", ..))`), this is the second call: go to step 5.
2. If `data` is `auto` or `none` and no `--input` key starts, after normalisation, with `invoiceprodata`, the invoice is not hydrated: the 0.6.0 path runs unchanged. This scan over the keys of `sys.inputs` is the main run-time cost that the branch adds to an invoice without data. The other new code that runs without data is the items slot around every `line-items` body (one loom level, L9) and root's payment and result hooks (L11); §7.3 has the measured cost.
3. Otherwise `hydrate(data, given)` resolves the source (the R7 checks, §8.1), decodes it into a record unless it is one, panics on another format major, runs the region pass with the locale's region and VAT rates, and builds the effective arguments from the class of each parameter (`invoice-params` in `src/contract/schema.typ`):
   - `design`: passed through unchanged (`theme`, `locale`, `references`, `zugferd`, `zugferd-errors`, `validation`, `tax-nr`);
   - `issuer`: `values.at(key, default: <the skeleton's value>)`;
   - `document` (and `custom`, dev. 9): inserted only when the data has the key. **An absent key is left out, so the signature's own default applies**;
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

**The classes of the 35 `invoice()` parameters** (P10): design 7, document 17, issuer 9, data 1 (`data`), body 1. Typst cannot list a function's parameters, so `tools/contract/signature.py` parses the signature and the `hydrate(..)` call and fails when a parameter is unclassified, when a classified key no longer exists, or when a class is unknown. It runs on 0.14 through `typst query` and is wired into `.github/workflows/tests.yaml` (dev. 33, 47). That CI step runs `python3` inside `nix develop`, whose dev shell lists no Python, so it works only with the runner's system Python (O14). Its parser still has blind spots (O6).

The test covers `invoice()` only. The format also mirrors twelve components: the rows engine replays `item`, `group`, `bundle`, `discount`, `surcharge`, `modifier` and `prepayment`, and `payment(..)` places `payment-terms`, `bank-details`, `direct-debit`, `card-payment` and `paid`. A new parameter of one of them gets no data key, and nothing fails; a changed cascade is caught only by the equivalence suite. S3 extends the coverage table to these components (each parameter is a data key or explicitly Typst-only), and `MAINTENANCE.md` gets the rule (§12).

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

A record is a sealed `metadata((kind: "invoice-pro-record", format, origin, values, issues, fatal))` value: opaque in the loom context (hashed once), unmistakable for raw data, layout-free. `origin` (`"input"`, `"file"` or `"value"`) is what R7 checks: a record made by `decode` together with a CLI data input panics as two sources (dev. 13). `load` without a data input returns `none` without loading any contract module (dev. 13), so the `load` line costs a preview nothing. The `invoice-data.items[..]` marker does load `src/contract/rows.typ` in every preview that uses it; the live preview of a skeleton was not measured (O21).

Two doc comments above need a fix. The one of `items` says that the sample is "never traversed"; since dev. 43 a hydrated marker walks its sample once to find a nested marker, but never weaves it (S3 corrects the comment). The one of `load` mentions "a dictionary an embedder passes": a Rust embedder can pass a dictionary through `Library::with_inputs` (not verified), while typst-py 0.15.0 accepts text only and raises a `TypeError` for a dictionary (requirements critique).

`values(..)` and `party(..)` return internal representations: the decoded values (unit functions, tax dictionaries, `id.*` values) and the output of the internal `normalize-party` (`post-code`, `city-name`, `country`, `*-inline`). Exporting them makes these shapes part of the experimental API (L32), so a change to `normalize-party` or to a decoded type becomes an API change.

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
- `view.items[i].custom` and `view.entries[j].custom`: the custom fields of data rows (checked on 0.15.1 for the first draft and on 0.14.2 by the accuracy critique: for §3.11 the first line has `(behaelter: "RM-1100-0815")`, the others `none`). Hand-written rows have none until `item(custom:)` exists (Q30).
- `ctx.<party>.custom`: the reserved print-only party key.
- `ctx.hydration` (sealed) and root's `payment-blocks` and `has-line-items`: internal; parts must not read them.

## 5. CLI conventions

### 5.1 Input keys

| Key                      | Value                                                                          | Read by                                     | Notes                                                                                                                         |
| :----------------------- | :----------------------------------------------------------------------------- | :------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------- |
| `invoice-pro-data`       | one invoice as JSON text (a Rust embedder may pass a dictionary: not verified) | the package (`invoice(data: auto)`, `load`) | the OS caps its size (§5.8)                                                                                                   |
| `invoice-pro-data-file`  | a path; JSON, TOML or YAML by extension                                        | the skeleton's `read` callback, via `load`  | relative to the skeleton, `/…` from the root; the file lies under `--root`; stdin through a `dev/stdin` link (§5.2); any size |
| `invoice-pro-result`     | `1`                                                                            | root                                        | emit `<invoice-pro-result>` on an invoice without data too; read from `sys.inputs` directly (dev. 12)                         |
| `invoice-pro-validation` | `draft`, `strict` or `none` (0.6.0)                                            | `resolve-level`                             | overrides `invoice(validation:)`                                                                                              |

Any other key whose lower-case form without `-`, `_` and `.` starts with `invoiceprodata` panics as a near miss (dev. 26). The hint names `invoice-pro-data-file` when the key contains `file` and `invoice-pro-data` otherwise, so `invoice-pro-data-fil` gets "did you mean --input invoice-pro-data=…? The data keys are invoice-pro-data (JSON text) and invoice-pro-data-file (a path)." (O17). The rule reserves every `invoice-pro-data*` key: a skeleton that reads a key of its own such as `--input invoice-pro-data-dir=batch` panics with "is not a key invoice-pro reads" (measured for this revision), so the docs must state the reserved prefix. Other `invoice-pro-*` keys stay free for skeletons (Q24).

**One JSON document, not one key per field.** "Aus den sysparametern" could also mean `--input invoice-nr=… --input date=…`. The format uses one key per invoice instead: inputs are strings only, the format is nested (parties, rows, payment), and one schema then covers one document. A skeleton can still let a key of its own override one field, by merging it into the data it passes:

```typst
#let file = sys.inputs.at("f", default: "d.json")
#let nr = sys.inputs.at("nr", default: none)
#let data = json(file)

#show: invoice.with(
  data: if nr == none { data } else { data + (invoice-nr: nr) },
  ..party,
)

#line-items[
  #item("Sperrmüllabholung", price: 45)
]
```

With `--input nr=2026-0043` the invoice carries that number instead of the one in `d.json` (checked for this revision on both compilers). No `invoice-pro-data*` key may be given at the same time (R7); `derive` (Q17) would make this declarative.

### 5.2 One invoice

```sh
# preview: the skeleton's samples
typst compile skeleton.typ

# a file (the canonical way); .toml, .yaml and .yml by extension, TOML dates are native
mkdir -p out
typst compile --pdf-standard a-3b skeleton.typ out/2026-0042.pdf \
  --input invoice-pro-data-file=data/2026-0042.json

# inline JSON: no skeleton code needed
typst compile --pdf-standard a-3b skeleton.typ out.pdf \
  --input invoice-pro-data="$(cat data/2026-0042.json)"

# stdin (POSIX): a link dev/stdin in the project keeps the root narrow (as run.sh does)
mkdir -p dev && ln -sfn /dev/stdin dev/stdin
generate-invoice | typst compile --root . --pdf-standard a-3b skeleton.typ out.pdf \
  --input invoice-pro-data-file=/dev/stdin

# production: any problem stops with exit code 1; a reproducible default date
typst compile --pdf-standard a-3b --creation-timestamp "$SOURCE_DATE_EPOCH" \
  skeleton.typ out.pdf \
  --input invoice-pro-data-file=d.json --input invoice-pro-validation=strict
```

On 0.15 a skeleton may also pass a `path` made in its own file, `data: path("data/2026-0042.json")` (P7: md5-identical to the file route; on 0.14 `path` is the deprecated drawing function and fails with "expected array, found string"). `load(read:)` is the portable way. A 0.15 `path` to a `.toml` or `.yaml` file is decoded by its extension (fix 1). For stdin, `--root /` with an absolute skeleton path works too, but it lets the skeleton read the whole file system.

**Reproducible builds.** The md5 identities in this concept hold per machine and font set. A production pipeline pins both: `--font-path fonts/ --ignore-system-fonts` for the fonts (§8.5 names a font-dependent PDF/A stop), and `--package-path` or a filled package cache for builds without network.

### 5.3 Batch

An e-invoice PDF carries exactly one `factur-x.xml`, so a batch is one compile per invoice. The portable way is parallel processes; a bad file fails alone.

```sh
mkdir -p out
printf '%s\n' data/*.json | xargs -P 4 -I{} sh -c \
  'typst compile -j 1 --pdf-standard a-3b skeleton.typ "out/$(basename {} .json).pdf" \
     --input invoice-pro-data-file={} --input invoice-pro-validation=strict'
```

Measured in the research and the design prototypes (not on the consolidated prototype, 0.15.1): 20 invoices on 4 cores took 9.1 s as sequential processes, 3.0 s as 4 parallel processes and 4.95 s as one 0.15 bundle ([`process/research/typst-cli.md`](process/research/typst-cli.md)); design D compiled 5 files as 4 parallel processes in 1979 ms. The 0.15 bundle export (`--features bundle --format bundle`: one compile, one PDF per invoice, each with its own XML) is experimental in Typst and needs the skeleton written as a function of a record. It is a follow-up (Q31), not part of the 0.7.0 API.

**Print invoices in one document.** Without an e-invoice, many invoices can share one PDF and one process, which pays the package import once (§7.0). The skeleton becomes a function of one record:

```typst
// Many print invoices in one PDF, without e-invoices (a PDF carries one
// factur-x.xml). The skeleton is a function of one record.
#let skeleton(record) = invoice(data: record, ..party)[
  #line-items[#item("Muster", price: 1)]
]

#for record in json("batch.json") { skeleton(record) }
```

`batch.json` is an array of `invoice-pro/1` objects. Checked for this revision on both compilers: three records give three pages and three result records with `status: ok`. The requirements critique measured 20 two-row print invoices: 9.1 s as 20 processes against 3.0 s as one document on 0.15.1, and 10.4 s against 4.3 s on 0.14.2 (`-j 1`, single runs on the shared VM). With `zugferd` set, the second invoice stops with "attempted to attach file factur-x.xml twice". Under `strict`, one bad record stops the whole document.

### 5.4 Getting results back

```sh
# 0.15: a second compile
typst eval 'query(<invoice-pro-result>).first().value' --in skeleton.typ \
  --input invoice-pro-data-file=d.json
# 0.14 (and 0.15, with a deprecation warning)
typst query skeleton.typ '<invoice-pro-result>' --field value --one \
  --input invoice-pro-data-file=d.json
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
- `<ip-issue>`, the label of the draft report's entries, stays internal. The first draft documented a query of it; that would have made an internal label and its record shape a CLI contract. The result's `issues[]` is the documented channel, also for an invoice without data (`--input invoice-pro-result=1`).

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

The report is `{"format": "invoice-pro-check/1", "valid": .., "issues": [{"id", "path", "key", "message", "fix"}]}`, byte-identical on both compilers and through `eval` and `query` (P5). The result record's `issues[]` has another shape (§5.9, Q42). `check` covers what the decoder checks. A hydrated invoice can report more: rules that need the skeleton (a credit note with the skeleton's cash discount, coverage), the legal checks and the e-invoice rules (dev. 40, Q34).

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

Under the default level `draft`, a hydrated invoice with problems exits 0 and writes a PDF with the draft badge and no XML. A pipeline therefore passes `strict` (Q39).

### 5.7 Typst 0.14 and 0.15

| Concern           | 0.14.2                                     | 0.15.1                                                |
| :---------------- | :----------------------------------------- | :---------------------------------------------------- |
| inline JSON       | `json(bytes(sys.inputs.k))`                | the same (`json.decode` is removed in 0.15: not used) |
| file              | the skeleton's `read` callback             | the same, or a `path` value                           |
| results           | `typst query` (a second compile)           | `typst eval` (a second compile); `query` deprecated   |
| layout-free check | a `typst query -` stub                     | `typst eval '{..}'`                                   |
| batch             | processes; print invoices in one document  | the same; bundle export (experimental, follow-up)     |
| decoder           | no 0.15-only function                      | the same; identical reports on both (P5)              |
| signature test    | through `typst query` (0.14 has no `eval`) | `typst eval`                                          |

### 5.8 Operating-system limits

- **Linux:** at most 128 KiB per argument. `--input invoice-pro-data=<JSON>` of a 1000-row tree invoice (`t-1000.json`, 213 KB) fails with "Argument list too long" before Typst starts; the 126 KB `b-1000.json` still works (verification round 0). Files and `/dev/stdin` give identical PDFs.
- **Windows:** about 32 767 characters for the whole command line, no `/dev/stdin`, painful JSON quoting in a shell, and 0.15 rejects backslashes in Typst paths: use files with forward slashes (OS documentation; not tested).
- **macOS:** `ARG_MAX` of about 1 MiB for all arguments together (OS documentation; not tested).
- Files are the documented default; inline JSON is for small invoices and tests.

### 5.9 A pipeline

The phase-1 interface is the PDF, the exit code and the result record. A strict build that fails exits 1 and writes no result. Typst exits 1 for every error (bad data, a missing font, a mistake in the skeleton), and the reason is free text on stderr. The panic texts start with stable prefixes ("invoice data:", "invoice-pro found n problems"), but 0.7.0 does not make them a contract. To learn why a build failed, a program compiles again as a draft and reads the result:

```sh
# 1. cheap: the decoder's rules, without layout (0.15)
typst eval '{ import "@preview/invoice-pro:<version>": invoice-data; invoice-data.check(json("data/d.json")).valid }'
# 2. the deliverable: exit code 0 (final) or 1
typst compile --pdf-standard a-3b skeleton.typ out/d.pdf \
  --input invoice-pro-data-file=data/d.json --input invoice-pro-validation=strict
# 3. on exit 1: why (a second compile, as a draft)
typst eval 'query(<invoice-pro-result>).first().value.issues' --in skeleton.typ \
  --input invoice-pro-data-file=data/d.json --input invoice-pro-validation=draft
```

If step 3 fails too, the cause lies outside the data issues: an e-invoice rule error under `zugferd-errors: "panic"`, the default (§8.5; a skeleton with `zugferd-errors: "report"` gets a draft with `e-invoice.status: "draft"` instead), a font, or the skeleton itself. The two issue lists still differ in shape: `check()` reports `{id, path, key, message, fix}`, the result `{id, class, path, message, ref}`. For `prototype/data/bad.json`, `check()` gives 6 issues and the draft's result 7, because the result also holds the payment block's copy of the mandate issue (measured for this revision; O16, O18). Both should be one shape before `invoice-pro-result/1` is frozen (Q42).

## 6. Extensibility

### 6.1 Custom fields at three levels

The levels, keys and readers are in §3.8. What they cost and how a skeleton previews them:

- **Document `custom`** is sealed in `metadata`, so its size costs about nothing (the invoice-api research measured an unsealed bag of 2500 leaves at +48 % compile time at 50 lines and +76 % at 300; sealed ≈ 0). The skeleton previews it with `invoice(custom: ..)`; the data's `custom` replaces that sample as a whole (Q7).
- **Party `custom`** is a reserved print-only key of every party. It travels unsealed with the normalised party, so keep it small (the theming research measured 2000 unsealed entries at about 2.4× slower).
- **Item `custom`** rides in the item signal into `view.items[i].custom` and `view.entries[j].custom` (verified on both compilers; designs A, B and C verified it with an unchanged EN 16931 XML). Printed per-row text belongs in `description` or `note`. Item custom fields serve theme authors, whose table part or wrap reads them, and pipelines. Hand-written sample rows cannot carry them yet (Q30), so a preview cannot show them.
- invoice-pro never prints a custom field, never interprets it and never writes it into the e-invoice. The skeleton decides what to do with it.

### 6.2 Changes that depend on a field value

The rule stays: **the data states facts, the skeleton states rules.** Every rule must tolerate absent and mistyped values (§2.1).

| Need                                                                         | Mechanism                                                                                            | Runs at    | E-invoice "is it printed" checks       | Verified                                                       |
| :--------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------- | :--------- | :------------------------------------- | :------------------------------------------------------------- |
| change the design by a value (coat of arms by post code)                     | **a static theme patch** from `invoice-data.values(record)` and `invoice-data.party(..)` (§2.1)      | evaluation | active (`page-content` false)          | P7, both compilers                                             |
| change the design by a value without the `load` line, or by a computed value | `theme.custom.wrap(..)` or `part(..)` reading `ctx` and `view` (below)                               | draw       | IP-PRINT-03 and IP-PERIOD-03 "unknown" | P7 (`page-content` true); the block below on 0.15.1 and 0.14.2 |
| print a value                                                                | `info.get("custom", "x", default: ..)`, `dynamic(ctx => ..)`, `view.items[i].custom` in a table part | draw       | –                                      | P7 ("Tarif: Gewerbe M")                                        |
| change an **issuer** parameter by a value                                    | a Typst expression on `values` in the skeleton (below)                                               | evaluation | –                                      | the block below                                                |
| change a **document** parameter by a value                                   | a `derive: values => values` hook on `load`/`decode` (_proposed_, 0.7.x, Q17)                        | evaluation | –                                      | design D's prototype                                           |
| choose the whole design at document level                                    | plain Typst on `values` (`theme: if .. { .. } else { .. }`)                                          | evaluation | active                                 | design D's prototype                                           |
| choose the locale by a value (the recipient's language)                      | plain Typst on `values`: `locale: if lang == "en" { .. } else { .. }` (below)                        | evaluation | –                                      | the block below, both compilers                                |

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

The locale is design, so the format has no locale key (Q32). The skeleton can still choose one by a value of the data:

```typst
#let record = invoice-data.load(read: p => read(p, encoding: none))
#let values = invoice-data.values(record)
#let custom = if values != none { values.at("custom", default: none) }
#let lang = if type(custom) == dictionary { custom.at("lang", default: none) }

#show: invoice.with(
  data: record,
  locale: if lang == "en" { locale.en-de } else { locale.de-de },
  ..party,
)

#line-items[
  #item("Sperrmüllabholung", price: 45)
]
```

With `"custom": {"lang": "en"}` in the data, the title reads "Invoice 2026-0042"; without it, "Rechnung" (checked for this revision on both compilers).

Images chosen by data are opened in the skeleton: a closure written there resolves paths against the skeleton, even when the package calls it. Map data values to files through a dictionary, as `arms` does, and never concatenate a data string into a path.

### 6.3 Why the data has no expressions

The maintainer's rule is that design and appearance change in Typst only. An expression language in the data (JSONLogic, a template string, `eval`) would move rules out of the skeleton, where the preview shows them, into data that other programs write. It would also make untrusted data executable, break the code generators of phase 2 and give every rule two places to live. The cases the requirement names are covered by Typst code on facts: a rule in the skeleton reads `values`, `party(..)`, `ctx.custom` or `view` and decides. What is still missing is a hook for document keys (`derive`, Q17).

### 6.4 How the format evolves

- **A new optional key** is one descriptor entry (type, business term, role, binding point, `since`, a sentence of documentation) and a new minor. It appears in the decoder, both JSON Schemas and the reference tables at once. The drift command (§10.1) shows a difference until the committed schemas are regenerated; a CI step that fails on it is proposed for S1.
- **A new value type** is one constructor in `src/contract/types.typ`, its branches in the decoder and the exporter, and conformance fixtures.
- **A new `invoice()` parameter** must be classified (design, document, issuer) or the signature test fails (§4.2).
- **A rename, a removal or a new meaning** is a new major; `invoice()` then panics on the old major with the conversion hint (§3.10).
- Custom part names keep the package-prefix rule of the theme API (`acme/wappen`).

## 7. Performance

### 7.0 A typical invoice

Most invoices have fewer than ten rows, and there the time goes elsewhere:

- **Absolute time.** A 5-row invoice with an EN 16931 e-invoice took 0.455 s written by hand on 0.6.0 and 0.456 s hydrated on 0.15.1, and 0.494 s against 0.482 s on 0.14.2 (verification round 1, untraced wall clock). Pooled over 16 runs in round 2, the ratios at 5 rows are 0.96–1.12×.
- **Composition.** The same invoice runs 1.850 G instructions by hand and 1.894 G hydrated on 0.15.1 (1.804 G and 1.839 G on 0.14.2; round 2). The root import alone runs 514 M instructions (479 M on 0.14.2) and takes 165.5 ms (183.2 ms) untraced: about a quarter of the invoice (round 2, P9.root-import-delta). In the requirements critique (0.15.1, medians of 9, `-j 1`), an empty document took 0.068 s, a document that only imports the package 0.245 s, and a small hydrated invoice 0.444 s.
- **Consequence.** For one small invoice, hydration neither helps nor hurts. For many small print invoices, the lever is the number of processes, not loom: one document for all of them pays the import once (§5.3: 3.0 s instead of 9.1 s for 20 invoices in the critique's run on 0.15.1). An e-invoice needs a process of its own.

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

Final verification round (round 2), hydrated invoice against the same invoice written by hand on pristine 0.6.0, untraced wall clock, PDFs md5-identical in every cell. Kinds: `b` basic items, `r` rich items (gross prices), `t` a tree of groups, bundles and modifiers (`prototype/harness/gen/gen.py`, design C's generator). "e-invoice" is `zugferd: "en16931"`; `auto` picks XRechnung for these recipients.

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

- **Series spread.** Single series of the 300-row b invoices (en16931 and auto, both compilers) range from 0.552 to 0.611; 2 of 12 series medians are above 0.6 and about 35 % of paired rounds exceed it. The instruction ratio (0.561/0.562) is stable (Q3).
- **Small invoices.** Below about 10 rows the fixed cost of hydration (loading the contract modules, decoding, the result hook) cancels the loom savings. The synthesis expected −16 % at 5 rows; the prototype does not reach it.
- **Decoder** (`check()`, ×8 copies with every leaf distinct, so the memo cannot flatter it): 0.15.1 / 0.14.2 b 0.152 / 0.166, r 0.243 / 0.312, t 0.320 / 0.361 ms per row (11 rounds); a second series of 15 rounds gave r 0.229 / 0.251 and t 0.292 / 0.301. Instructions per row: r 800 k / 907 k, t 839 k / 952 k. All within the 0.4 ms budget; the first verification round had measured 0.44–0.68 ms per row before the hot-path work (dev. 34, 48).
- **Package import.** The root import parses +17.1 KiB (+6.1 KiB outside comment lines) and runs +3.84 M (0.15.1) / +3.88 M (0.14.2) instructions more than 0.6.0, +0.75 % / +0.81 % of 514 M / 479 M, about **+1.2 ms / +1.5 ms** at the import's own rate. Wall clock and trace spans cannot resolve it (±10–20 ms on the shared VM). The builder's estimate of 0.6–0.9 ms was too low. The largest parts: `invoice.typ` +1932 B of code, `public/invoice-data.typ` +972 B, `line-items.typ` +899 B, `root.typ` +730 B, `public/payment.typ` +450 B. No `src/contract/*` module and no `components/payment.typ` is in the root import (Q2).
- **Invoices without data.** Wall clock cannot see a difference: hand-written invoices on the prototype tree took 0.962–1.043× (round 0) and 0.84–1.17× (round 1, the noise floor) of the time on 0.6.0. Instruction counts, measured for this revision (cachegrind, `--jobs 1`, the hand-written b invoices with an EN 16931 e-invoice, one run each, PDFs identical on both trees): b-5 1848.7 → 1858.2 M (+0.51 %) on 0.15.1 and 1802.7 → 1811.7 M (+0.50 %) on 0.14.2; b-300 22 517.8 → 22 612.6 M (+0.42 %) and 22 570.9 → 22 679.1 M (+0.48 %). At 5 rows that is 2.3–2.5 times the import delta, and it grows with the rows (+95 M and +108 M at 300), so most of it is likely the items slot's extra loom level, which every row passes. It was not profiled (Q2).
- **`payment(..)` against the components.** The template with `payment(..)` instead of `payment-terms` and `bank-details` runs +16.7 M instructions without data (+0.72 %: 2.337 against 2.320 G, cachegrind, one run each, 0.15.1); the wall clock is within noise (0.761 s against 0.754 s, medians of 11; requirements critique).
- **Lazy modules.** No `src/contract/*` module appears in the traces of the benchmark invoices without data, the template or the hand-written 300-row invoices (34 of 34, both compilers); `components/payment.typ` appears only for a skeleton that calls `payment(..)`.
- **Where the time goes now.** The rest of a hydrated invoice is the unchanged layout and e-invoice code; the table part dominates the tree invoices (build report; §7.6 has design C's trace).
- **Not measured:** the live preview of a skeleton (`typst watch`, `tools/perf/measure.py --watch`) with the `load` line, the marker and a data file. The maintainer accepted the live preview as the criterion for small invoices (`tools/perf/README.md`, "Live preview"); S5 measures it (O21).
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

| Budget (synthesis)                                 | Prototype                                                                            | Proposal                                                                                                                               |
| :------------------------------------------------- | :----------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------- |
| hydrated b-300 ≤ 0.6× hand-written, both compilers | passes pooled (0.567–0.579× over both variants and compilers), thin in single series | gate on **instruction counts** (0.561×) with the same 0.6 threshold, or on pooled medians of many runs (Q3)                            |
| decoder ≤ 0.4 ms per row                           | passes (0.15–0.36)                                                                   | keep; measure with distinct leaves (identical rows are memo hits)                                                                      |
| root import delta ≤ 0.2 ms                         | **missed**: ≈ 1.2–1.5 ms (+0.75–0.81 %)                                              | restate as ≤ 1 % of the root import's instructions, gated on an import-only document (S5; needs valgrind in the flake), or ≤ 2 ms (Q2) |
| `src/contract/*` in `LAZY_MODULES`                 | done in `tools/perf/gate.py`                                                         | keep                                                                                                                                   |
| invoices without data unchanged                    | P2: byte-identical; +0.4–0.5 % instructions (§7.3)                                   | keep; add an instruction gate for a hand-written 5- and 300-row invoice (≤ +1 %, S5)                                                   |

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

- The id is `schema/<JSON Pointer>` (`schema/items/0/price`), one per path. The draft report deduplicates by id; the strict panic and the result do not, so a problem that two layers report counts twice there (O16). Q19 asks whether the prefix should follow the class, `data/…`, as theme issues use `theme/…`. The result's `issues[].path` holds the pointer; the message shows the dotted path for humans.
- Keys: `schema-type`, `schema-enum`, `schema-unknown-key`, `schema-required`, `schema-exactly-one`, `schema-exclusive`, `schema-length`, `schema-period`, `schema-nesting`, `schema-placement`, `schema-tax-zero`, `schema-tax-rate`, `schema-range`, `schema-character`, `schema-unbound`, `schema-version`.
- Messages are English in the house style: path, value, allowed set, did-you-mean, the fix. Values quoted in a message are cut by grapheme clusters, never by bytes (fix 1). Party keys use the e-invoice alias table for hints (`plz`, `mail`, `ust-id`, …).
- _Not built_ (L16, Q26): the localized texts `strings.validation.issues.schema-*` in the six language files and the report chip "Daten / Data"; the report shows these issues with the chip "Pflichtangabe" today.
- _Found while writing this concept_ (0.15.1 and 0.14.2, also in `check(region:)`): when an earlier row was dropped, the region pass reports the index of the decoded rows, not of the data. `[{"name": "X", "tax": "19%"}, {"name": "Y", "price": "10.00", "tax": "16%"}]` gives `schema/items/0` (no price) and `schema/items/0/tax` for the 16 % of row 1. The region pass must keep the data's index (§11.5).

### 8.3 Drop semantics

An invalid value is left out. An object that then lacks what it needs (a line without a price) is left out as a whole, except the objects marked `partial` in the descriptor (the document, parties, contact, bank, payment, terms, custom), whose gaps the legal checks then name. invoice-pro's own code does not crash a draft on bad data, outside the open paths of §11.5 (O1–O3); a rule written in the skeleton can, unless it tolerates absent values (§2.1). A strict build never ships bad data.

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

Kinds: `new-parameter`, `new-export`, `new-cli-input`, `new-label`, `new-view-key`, `new-locale-key`, `behaviour-change`, `bugfix`, `internal`, `locale-strings`, `template`, `tooling`, `docs`. **⚠** marks a change that is not a pure extension; its justification is in the last column. L1–L26 follow the synthesis; L27–L31 are new in the prototype; L32–L35 are new in this draft (L32 names a surface that the prototype creates, L33–L35 are proposals). _Proposed_ marks what the prototype does not contain.

| #   | Change                                                                                                                                                                                                                                                       | File(s)                                                                                                                                                  | Kind                                                            | Justification                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| :-- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| L1  | `invoice(data: auto)`                                                                                                                                                                                                                                        | `src/invoice.typ`                                                                                                                                        | new-parameter                                                   | The single entry point. It must sit inside `invoice()`, so that `check-data`, the draft markers, strict and the XML withholding see the real values. `invoice()` rejects unknown arguments today, so no caller passes `data`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| L2  | `invoice(custom: none)`                                                                                                                                                                                                                                      | `src/invoice.typ`                                                                                                                                        | new-parameter                                                   | The documented, sealed home of document-level custom fields and of their preview samples.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| L3  | The hydrated branch: key scan, lazy `hydrate(..)`, re-entry, issues next to `check-data`, sealed `hydration` and `custom`                                                                                                                                    | `src/invoice.typ` (+95 lines), `src/contract/hydrate.typ` (new, lazy)                                                                                    | internal                                                        | No behaviour without data (P2); no copied defaults.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| L4  | Root export `invoice-data` (10 names) ⚠                                                                                                                                                                                                                     | `src/public/invoice-data.typ` (new facade), `src/contract/api.typ` (lazy), `src/lib.typ` (+1)                                                            | new-export                                                      | The contract's public face, layout-free (CI, phase 2). Not `data`, which `#let data = json(..)` would shadow. Its `values` and `party` return internal shapes (L32). ⚠ as L5.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| L5  | Root export `payment(..)` ⚠                                                                                                                                                                                                                                 | `src/public/payment.typ` (new facade), `src/components/payment.typ` (new, lazy), `src/lib.typ` (+1)                                                      | new-export                                                      | Which payment components exist is data. ⚠ `import *` now also binds `payment` and `invoice-data`: a user binding of that name made _before_ the import is replaced (one made after it still wins; P2 probes: 2 documents). The same holds for every root export added since 0.1.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| L6  | The pinned export list gains `invoice-data` and `payment`                                                                                                                                                                                                    | `tests/theme/exports/test.typ`                                                                                                                           | tooling                                                         | The test pins the root exports exactly.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| L7  | `--input invoice-pro-data`, `invoice-pro-data-file`, `invoice-pro-result`; near-miss keys panic ⚠                                                                                                                                                           | `src/contract/input.typ` (new), `src/invoice.typ`, `src/components/root.typ`                                                                             | new-cli-input, behaviour-change                                 | "One input = one JSON document", with the package prefix and an injectable `inputs:` (precedent `invoice-pro-validation`). ⚠ A data key that nothing consumes, or a misspelt one (`invoice-pro-data-fil`), now panics, also on an invoice without data: the only 9 of 1105 documents per compiler that differ in P2. The rule is a prefix rule, so it reserves every `invoice-pro-data*` key, also one that a skeleton reads itself (`invoice-pro-data-dir` panics). 0.6.0 documents no such prefix, but none of these keys does anything there, so no working document depends on invoice-pro reading them, and the panic keeps a strict build from shipping a sample invoice. The docs must state the reserved prefix (S6). `invoice-pro-result` is read from `sys.inputs` directly, not through an injectable `inputs:` (dev. 12), so tytanic cannot test it (O22). |
| L8  | Label `<invoice-pro-result>` (`invoice-pro-result/1`)                                                                                                                                                                                                        | `src/contract/result.typ` (new, lazy), `src/contract/result-schema.typ`, `src/components/root.typ`                                                       | new-label                                                       | A machine-readable result for pipelines and phase 2; only on hydrated invoices or with `--input invoice-pro-result=1`; the PDF bytes stay the same (P8).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| L9  | `_items-slot` around the body of `line-items`; hydrated, the body is replaced by the bulk motif ⚠                                                                                                                                                           | `src/components/line-items.typ` (+36, −2)                                                                                                                | behaviour-change (also without data)                            | Without data the slot passes the children through (P2: the same bytes). ⚠ Every invoice weaves one more motif: one more loom level, one more traceback frame in a panic inside the body (4 catch tests; the messages are equal), and likely most of the +0.4–0.5 % instructions of a hand-written invoice (§7.3).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| L10 | Rows engine and the explicit marker                                                                                                                                                                                                                          | `src/contract/rows.typ` (new)                                                                                                                            | internal                                                        | Byte-identical to the components (P1).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| L11 | Root: `payment-blocks` and `has-line-items` in its view, coverage issues, payment-block issues, the result element                                                                                                                                           | `src/components/root.typ` (+26)                                                                                                                          | behaviour-change (data, `payment(..)` or the result input only) | Data is never dropped silently; the coverage code is loaded only when hydrated (dev. 11).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| L12 | `unsealed()` and `dynamic` unwrap a sealed `ctx.custom`                                                                                                                                                                                                      | `src/theming/access.typ`, `src/components/dynamic.typ`                                                                                                   | internal (+ context contract)                                   | Custom fields travel sealed (≈ 0 cost) yet read as a dictionary; `ctx.custom` becomes a documented context key.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| L13 | `custom: false` (print-only) in `_address-keys` and in `payee` of `party-keys` ⚠                                                                                                                                                                            | `src/zugferd/model.typ` (+3)                                                                                                                             | behaviour-change                                                | ⚠ A party key `custom` no longer raises the IP-KEY-01 warning, also on a hand-written invoice (visible only with `zugferd-errors: "report"`; default PDFs identical). Today such a key is unknown, printed nowhere and written nowhere, so one warning less is the only change. It reserves the name for the documented party bag (dev. 32).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| L14 | `view.items[i].custom`, `view.entries[j].custom` for data rows                                                                                                                                                                                               | `src/contract/rows.typ`                                                                                                                                  | new-view-key                                                    | An additive key in the item signal; hand-written rows lack it until `item(custom:)` (Q30).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| L15 | Regions declare their VAT rates (`normalize.vat-rates`), with a base entry `none` ⚠                                                                                                                                                                         | `src/locale/region/{base,de,at,ch,fr,it,es}.typ`                                                                                                         | new-locale-key                                                  | One source for the pre-check, so a data `"16%"` is an issue instead of `infer-tax`'s panic. ⚠ `normalize` is documented (`docs/docs/api-reference/locale/base.md`, `locale.custom.normalize(..)`), so `vat-rates` is a new public region key and needs docs (S2). The locale factory rejects undeclared region keys, hence the base entry (dev. 10). ⚠ Defect: a locale patch that replaces `infer-tax` inherits the region's list, so the data path refuses `"16%"` where `tax: 16%` written by hand with the same locale compiles (reproduced for this revision on both compilers; O19). The fix is proposed for S2 (Q41).                                                                                                                                                                                                                                          |
| L16 | `strings.validation.issues.schema-*` and the chip "Daten / Data" in the 6 language files ⚠ (_proposed_)                                                                                                                                                     | `src/locale/lang/*.typ`                                                                                                                                  | locale-strings                                                  | Localized report texts for the new issue keys. ⚠ A user locale built on `locale.custom` without them falls back to English; existing texts are unchanged. Not built (dev. 19; Q26).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| L17 | Descriptor, types, decoder, exporter, hydration, input, result and API modules; committed `invoice.schema.json` and `result.schema.json`                                                                                                                     | `src/contract/*` (new)                                                                                                                                   | internal                                                        | One source of truth; published files must live under `src/` (Q37 asks whether the bundle carries them); a drift command compares `schema()` with the committed files (verified by hand, P5; a CI step is proposed for S1).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| L18 | `src/contract/*` and `src/components/payment.typ` in `LAZY_MODULES`; the hydrated-300 gate entry (_proposed_)                                                                                                                                                | `tools/perf/gate.py` (+15)                                                                                                                               | tooling                                                         | Guards the import budget and the memo-hit property. The prototype extends `LAZY_MODULES` only; its 300-row gate is a script (dev. 18).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| L19 | Signature test, conformance fixtures, contract unit test, CI step; _proposed_: the fixture generator, the schema comparator, the fault corpus, the equivalence generator and a CLI test script as flake apps and CI jobs, codegen as an optional nightly job | `tools/contract/signature.py`, `tests/data/**`, `.github/workflows/tests.yaml` (+7); proposed: `tools/contract/*` from `prototype/harness/`, `flake.nix` | tooling                                                         | §4.2, §10, §12. The synthesis listed the fault corpus, the codegen job and the equivalence generator here. The prototype kept them in its harness, which this draft commits as a record (`prototype/harness/`); its generator reproduces the committed fixtures byte for byte.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| L20 | `format-item` builds a plain dictionary (S7a, _proposed_, own PR)                                                                                                                                                                                            | `src/components/line-items.typ`                                                                                                                          | internal                                                        | Byte-identical; −0.02× on the gate (side branch `proto-s7a`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| L21 | Exact page-count seed for layout iteration 1 (S7b, _proposed_, own PR)                                                                                                                                                                                       | `src/theming/frame.typ`                                                                                                                                  | internal                                                        | Removes a full second layout of long invoices; exact by construction; md5-identical on 123 documents in the engine judge's re-run of design C.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| L22 | `item()` measures through a shared pure `item-signal` (S7c, _proposed_, own PR) ⚠                                                                                                                                                                           | `src/components/item.typ`, `src/logic/line-signal.typ` (new)                                                                                             | internal                                                        | One implementation of the item cascade for hand-written and data rows (the real cure for drift); hand-written −20 to −37 %. ⚠ The largest internal change to a stable component: signature and output unchanged (123 and 31 documents md5-identical in the engine judge's re-run of design C), but the loom scope internals of `item` change.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| L23 | `group`, `bundle`, `modifier`, `prepayment` on shared resolvers (S7d, _proposed_, own PR) ⚠                                                                                                                                                                 | `src/components/*.typ`, `src/logic/line-signal.typ`                                                                                                      | internal                                                        | Completes L22; same justification and gate.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| L24 | `collect-signals(depth: 10)` in `calculate-modifier` (_proposed_, own bugfix PR) ⚠                                                                                                                                                                          | `src/logic/modifier-applicator.typ`                                                                                                                      | bugfix                                                          | ⚠ Changes the totals of invoices nested 10 levels or deeper, which are silently wrong today (deep items printed but missing from the totals). The format caps nesting at 8 until it lands.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| L25 | `modifier(name, amount: "-0.50")` converts a string amount like `discount`/`surcharge` (_proposed_, own bugfix PR) ⚠                                                                                                                                        | `src/components/modifier.typ`                                                                                                                            | bugfix                                                          | ⚠ A string amount that crashes in `normalize.money` today renders; no working document changes.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| L26 | Docs: api-reference pages `invoice-data` and `payment`, a guide "Generate invoices from data", registries, doc tests (_proposed_)                                                                                                                            | `docs/docs/**`, `docs/DOCUMENTATION.md`, `tests/TESTING.md`, `tests/docs/**`, `MAINTENANCE.md`                                                           | docs                                                            | House obligations (§12).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| L27 | `payment-terms`: a cash discount on a credit note or self-billed invoice that the data made is left out with a data issue                                                                                                                                    | `src/components/payment-terms.typ` (+13, −3)                                                                                                             | behaviour-change (hydrated only)                                | The data, not the skeleton's author, caused the conflict; the panic stays for Typst authors and the preview (dev. 42).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| L28 | `modifier-applicator`: a modifier that no VAT group can take is left out with a data issue                                                                                                                                                                   | `src/logic/modifier-applicator.typ` (+13)                                                                                                                | behaviour-change (hydrated only)                                | The decoder cannot see totals; written in Typst it still panics (dev. 28).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| L29 | `_one-line` prints the ellipsis when not even one cluster of a long text fits the header line ⚠                                                                                                                                                             | `src/theming/parts/frame.typ`                                                                                                                            | bugfix (own PR)                                                 | ⚠ 0.6.0 crashed (`none.trim`) on an invoice number of about 400 characters, also hand-written. Output of every document that compiled before is unchanged (dev. 29).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| L30 | `registration` prints `sender.management` given as lines, one per line ⚠                                                                                                                                                                                    | `src/theming/parts/frame.typ`                                                                                                                            | bugfix (own PR)                                                 | ⚠ 0.6.0 aborted with "cannot join content with array", also hand-written, although the sender docs type it as lines. 50 of 50 such probes crash on 0.6.0 and compile on the prototype; the 72 text and content probes are identical (dev. 39).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| L31 | `check-data` rejects blank names on the hand-written path (_proposed_, own bugfix PR) ⚠                                                                                                                                                                     | `src/validation/data.typ`                                                                                                                                | bugfix                                                          | ⚠ Would change reports of invoices without data that pass `name: ("", "")` today; the data path already rejects blank required texts (dev. 35).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| L32 | The shapes that `invoice-data.values(..)` and `invoice-data.party(..)` return                                                                                                                                                                                | `src/contract/api.typ`, `src/logic/country.typ` (`normalize-party`)                                                                                      | new-export (contract)                                           | The decoded values (unit functions, tax dictionaries, `id.*` values) and the normalised party (`post-code`, `city-name`, `country`, `*-inline`) become experimental API with the namespace (§4.3). A change to `normalize-party` or to a decoded type is then an API change; the docs list the keys (S6).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| L33 | `template/invoice.typ` as a skeleton: the `load` line, `data: record`, `payment(..)` (_proposed_, Q36)                                                                                                                                                       | `template/invoice.typ`                                                                                                                                   | template                                                        | The same PDF bytes as 0.6.0 on both compilers, with and without `--pdf-standard a-3b` (§2.0, measured for this revision); golden XML and thumbnail unchanged. `typst init` then gives a hydratable skeleton.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| L34 | `invoice-data.values(record, default: ..)` (_proposed_, Q43)                                                                                                                                                                                                 | `src/public/invoice-data.typ`, `src/contract/api.typ`                                                                                                    | new-parameter                                                   | The values of the data, else the given samples: replaces the `shown` idiom of §2.1, without a new name.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| L35 | One issue shape in `check()` and the result, `{id, class, path, key, message, fix, ref}` (_proposed_, Q42)                                                                                                                                                   | `src/contract/api.typ`, `src/contract/result.typ`, `src/contract/result-schema.typ`                                                                      | behaviour-change (new API only)                                 | A binding reads one shape wherever it gets issues. Only possible before `invoice-pro-result/1` is frozen.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |

**Not changed:** every existing parameter, default and export; `template/invoice.typ` in the prototype (its PDF md5 equals 0.6.0 with and without `--pdf-standard a-3b`, its metadata count stays 6; L33 proposes the skeleton form); `tools/zugferd/bt-disposition.toml` (the format feeds existing inputs; the descriptor's 112 `x-en16931` annotations are a second map of business terms to inputs, which S1 checks against it); `<ip-issue>`, the internal label of the draft report (§5.4).

**Not an API change, but felt by every invoice:** the root import runs about 1.2–1.5 ms longer, and a hand-written invoice runs 0.4–0.5 % more instructions (§7.3, Q2). The published package grows by 25 % (Q37).

## 10. Phase-2 hooks

Phase 2 (native bindings) is not in scope. Phase 1 leaves it these artefacts, all generated from or checked against the one descriptor:

1. **JSON Schemas** (2020-12): `src/contract/invoice.schema.json` (757 subschemas, 92 `$ref`s, 48 patterns) and `src/contract/result.schema.json`, generated by `invoice-data.schema()` and committed. Every object is closed except the `custom` bags and the `extra` maps (label → text); `kind` discriminators carry `const` and `default: "item"`; `$defs` for decimal, percent, date, period, unit, tax and identifier; annotations (counted in the committed schema) `x-en16931` (112), `x-invoice-pro-role` (33), `x-invoice-pro-bind` (4) and `x-invoice-pro-since` (189). Cross-field rules are `dependentSchemas`: every validator enforces them and the three generators ignore them, whereas `oneOf`/`not` made the TypeScript generator type `price` as `{[k: string]: unknown}` and `if`/`then` makes typify panic (dev. 21). Both schemas are metaschema-valid for python-jsonschema 4.26.0 and ajv 8.17.1 in strict mode. **Drift command:** `typst eval '{ import "/src/lib.typ": invoice-data; invoice-data.schema() }' --pretty | diff - src/contract/invoice.schema.json`; byte-identical through `eval` (0.15) and `query` (0.14, 0.15) (P5, run by hand). The prototype has no CI step for it; S1 adds one.
2. **Conformance fixtures:** `tests/data/conformance/fixtures.json`, 135 cases (48 valid, 67 invalid, 12 decoder-only, 8 lenient, among them default model dumps with up to 145 nulls; a real pydantic dump has 143), and `check-all.typ`, which runs `invoice-data.check` over all of them without layout. Schema (python-jsonschema and ajv) and decoder agree on all 135 and on design D's 51 (P5). The generator is `prototype/harness/schema/make_fixtures.py`, which reproduces the committed file byte for byte when the pydantic model of `codegen.sh` is present; `schema/compare.py` there is the comparator (both re-run for this revision: byte for byte, 135 of 135 agree). _Proposed:_ a CI job that requires this agreement on both compilers.
3. **Code generation** (round 2): datamodel-codegen 0.88.0 / pydantic 2.13.5 (1003 lines for the data, 273 for the result), json-schema-to-typescript 15.0.4 (968 / 204; `tsc --strict` 0 errors on 2062 valid documents), cargo-typify 0.8.0 (8265 / 2201 lines; 1050 of 1060 valid documents deserialize and round-trip unchanged). Kebab-case names become field aliases or `serde(rename)` everywhere. Known limits of the tools: serde rejects integers written as `14.0`, which JSON Schema allows (dev. 46); python-jsonschema lets `$` match before a trailing newline (57 mutations such as `"EUR\n"` pass it and fail ajv, pydantic-core and `check`); the generated pydantic model does not enforce "exactly one of `price`, `total`"; typify types the result's `format` as any value because its `const` has no `"type": "string"`. _Proposed:_ a nightly CI job that generates and compiles all three. It brings Python, Node and Rust toolchains into the flake, so it is optional for 0.7.0 (S1).
4. **Transport contract:** one `--input` key carries one JSON document. Embedders pass JSON text as the value of `invoice-pro-data`: typst-py 0.15.0 accepts strings only and raises a `TypeError` for a dictionary (requirements critique). A Rust embedder can put a dictionary into `Library::with_inputs`, which `load` accepts; this was not verified. Data larger than about 100 KiB goes through `invoice-pro-data-file`. A binding is: serialize the model, compile the skeleton, read the exit code and the result.
5. **Result contract** `invoice-pro-result/1` (§5.4), strings only, with its own schema: 450 of 450 hydrated records and 165 of 165 records of invoices without data are valid for python-jsonschema, ajv, pydantic, typify and `tsc`; 59 of 59 broken records are rejected by python-jsonschema and ajv (P8).
6. **Golden pairs:** the generated data/hand-written pairs (design C's `gen.py` and `eq.sh`, now in `prototype/harness/`) can ship as fixtures that a binding replays (md5 per compiler). _Proposed._
7. **Versioning:** the data format (`invoice-pro/1[.minor]`, SchemaVer, `since` per key), the result format (`invoice-pro-result/1`) and the package version (in the result) move independently. A binding targets a format major. The `$id`s carry the format major only and point at the documentation site: `https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/invoice.schema.json` and `…/1/result.schema.json` (patch 0010). The docs build must publish them there (Q28).
8. **Layout-free primitives:** `check` and `schema` through `typst eval` (0.15) or a `typst query -` stub (0.14), for validation before rendering.

## 11. Prototype and verification

### 11.1 What was built

The prototype is a branch of a clone of the repository, exported as ten patches on 0.6.0 (`df934a7`), in [`prototype/patches/`](prototype/patches/). [`prototype/README.md`](prototype/README.md) lists the files by area. In total: 39 files, +33 177 / −11 lines, of which 23 550 are conformance fixtures and 4113 the two committed schemas. The sources of the prototype's test harness are in [`prototype/harness/`](prototype/harness/README.md), without outputs.

| Patch | Content                                                                                                                                                                                                                                           |
| :---- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0001  | contract core (descriptor, types, decoder, exporter, input, hydrate, result), `invoice(data:, custom:)` with re-entry, the rows engine behind the items slot and the marker, `payment(..)`, region VAT rates, sealed `ctx.custom`, party `custom` |
| 0002  | crash-free decoder rules, item modifiers without `tax`, the committed schemas, conformance fixtures                                                                                                                                               |
| 0003  | contract unit test, signature-coverage test, `LAZY_MODULES`                                                                                                                                                                                       |
| 0004  | decoder hot path                                                                                                                                                                                                                                  |
| 0005  | coverage issues in the lazy contract module                                                                                                                                                                                                       |
| 0006  | fix round 1: crash-free decoding, codegen-friendly schema, payment and R7 checks, result fixes, the lazy `payment` facade; also the `frame.typ` ellipsis bug fix (L29)                                                                            |
| 0007  | `components/payment.typ` in `LAZY_MODULES`                                                                                                                                                                                                        |
| 0008  | fix round 2: `""` absent for every optional key, PDF/A-safe texts, a total `check()`, the nested marker with data, a faster decoder, the signature scanner; also the bug fix `management` as lines (L30)                                          |
| 0009  | a cash discount period of at most 36 500 days                                                                                                                                                                                                     |
| 0010  | the schemas' `$id` on the documentation site (after the last verification round; no other change)                                                                                                                                                 |

Not in the prototype: L16 (localized issue texts), the L18 gate entry, L20–L25 (speed PRs and two bug fixes), L26 (docs), L31 (blank names in `check-data`), L33–L35 (this draft's proposals), and CI jobs for code generation, conformance and the schema drift check (they exist as scripts in `prototype/harness/`). The shared-path bug fixes L29 and L30 are mixed into the feature patches 0006 and 0008; S8 splits them out into their own PRs. tytanic was not available: the test files are compiled directly, and their assertions panic on failure.

### 11.2 The ten proofs

Status after the last verification round (round 2, after fix 2), both compilers.

| Proof | What it shows                                                      | Status                    | Numbers                                                                                                                                                                                                                                                                                                                                                                                                         |
| :---- | :----------------------------------------------------------------- | :------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1    | hydrated == hand-written on 0.6.0 (PDF md5, embedded XML included) | pass                      | 0 failures: matrix b/r/t × 5/50/300 × e-invoice none/auto (36), 1000 rows (8), 13 edge fixtures (nested and dated bundles, `apply` around the marker, static rows, inclusive + small business AT, prepayments), 662 generated cases incl. 88 blank-optional cases; §3.11: `32b0b6d5d449` / `679ee994c66b`                                                                                                       |
| P2    | no regression of invoices without data                             | pass                      | 1105 documents per compiler: 1013 identical PDFs + 83 identical errors + 9 intended near-miss panics; the 313 test documents with PDF/A-3b: 253 + 60, 0 differ; template md5 `881821b7318c` / `ba5d9a49b5de` (0.15.1, plain / a-3b) and `8a1c8b464422` / `c7e98da669bc` (0.14.2), equal to 0.6.0                                                                                                                |
| P3    | no sample leaks; every R7 panic with its fix; skeleton misuse      | pass (one minor gap)      | 31 checks per compiler; 16 nested-marker variants panic with and without data; strict exits 1 on every issue file of the corpora; 0 sample strings in 1221 PDFs. Gap: a marker inside `context` or inside an item's description is not seen                                                                                                                                                                     |
| P4    | crash-freedom on bad data                                          | **fail** (three findings) | 0 hard aborts in the fault corpus, v3 and r1 (§8.4). Open: noncharacters quoted in issue messages stop PDF/A (10 files; an 11th with a 40 000-character custom key, O8); raw `direct-debit(..)`/`card-payment(..)` with credit-note data (24 runs); unassigned/private-use code points and C0 controls (13 of 2201 valid documents)                                                                             |
| P5    | schema == decoder; code generation                                 | partial                   | 135 + 51 fixtures and 171 + 1958 targeted cases agree (python == ajv on all); the 3154 mutations agree except the documented leniencies (with ajv: 31 schema-only, 56 lenient, 1 decoder-only, 31 path-only) and 57 python-jsonschema trailing-newline cases; pydantic, TypeScript and Rust as in §10. Open: C0-only and format-character-only required texts pass; tax rates allow 6 decimals, the e-invoice 4 |
| P6    | `payment(..)` matrix                                               | pass                      | without data md5 == the components for 5 methods; hydrated == hand-written; BT-81 58/59/54/10/58; 102 data cases, 24 twin pairs, 95 schema agreements, 0 failures. No external validator (Mustang, KoSIT) was available                                                                                                                                                                                         |
| P7    | sources and the coat of arms                                       | pass                      | file, inline, stdin, TOML, YAML, 0.15 path one md5; 80331/85221 → Bavaria, 20095 → Hamburg, 10115 → Berlin, 50667/01067 → neutral, override → München; 28 logo crops byte-identical across compilers and checked by eye; `prints-of` false/false/true                                                                                                                                                           |
| P8    | the result contract                                                | partial (one fail)        | `eval` == `query` on 450 of 450; valid for 5 validators; no record without data or input. Fail: for 11 of 344 records with an invisible format character in BT-1 or BT-44, the result strips it and the XML keeps it                                                                                                                                                                                            |
| P9    | performance                                                        | partial                   | gate 0.571× / 0.568× pooled (passes, thin margin); decoder 0.15–0.36 ms/row (passes); lazy 34 of 34; root import ≈ +1.2–1.5 ms (**misses** 0.2 ms); 5 rows no gain                                                                                                                                                                                                                                              |
| P10   | every `invoice()` parameter classified                             | partial (one fail)        | 35 parameters (design 7, document 17, issuer 9, data 1, body 1); 23 of 23 earlier mutations caught. Open: 8 of 15 new mutations get the wrong verdict (a commented-out copy of the signature, a `"` in a content default, a reformatted `hydrate(..)` call)                                                                                                                                                     |

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
# in a clone of this repository; needs git, bash 4 or later, GNU md5sum, Typst 0.14 or 0.15,
# python3 (pdfdetach optional)
TYPST_BIN=typst docs/concepts/data-api/prototype/run.sh ../data-api-proof
```

`run.sh` clones the repository twice, checks out `df934a7`, applies the patches with `git am` to one clone and compiles the examples against both. It checks 12 things: the skeleton alone; hydrated from a file, inline JSON, stdin and TOML, each md5-identical to the hand-written twin on 0.6.0; a missing invoice number gives a draft without an embedded file, and `strict` stops; the post codes 80331, 20095, 10115 and 50667 and the custom override pick the right arms. Re-run for this revision, after the header comment of `skeleton.typ` changed: 12 of 12 PASS on 0.15.1 (`32b0b6d5d449`) and on 0.14.2 (`679ee994c66b`). The builder's harness (the generators, the fault corpus, the comparators, the benchmark scripts) is committed as sources in [`prototype/harness/`](prototype/harness/README.md). Re-run from there for this revision on 0.15.1, in the work layout of `run.sh`: the equivalence generator and script (12 of 12 identical at 5 and 50 rows), the fixture generator (byte for byte), both schema comparators (135 of 135, 51 of 51), the fault corpus (69 faults, 0 hard aborts) and the misuse checks (31 of 31). The verifiers' scripts and corpora and all outputs stayed in `<session>/exp/unified/` and are not part of the repository; [`process/review/verification.md`](process/review/verification.md) records every command and result.

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
| O14 | The CI step of `signature.py` was wired but not run (no nix in the sandbox); it runs `python3` inside `nix develop`, whose dev shell lists no Python. tytanic was not available                                                                                         | process  | S1 makes `signature.py` a flake app; S1/S2 port the tests to tytanic                                                 |
| O15 | `"method": "card"` or `"direct-debit"` without its details passes the JSON Schema and `check()`; only a hydrated `payment(..)` reports it (§3.7)                                                                                                                        | medium   | a decoder rule and a `dependentSchemas` entry: a method needs its details (S1)                                       |
| O16 | The decoder and `payment(..)` report a direct debit without mandate under the same id; strict and the result count it twice (`bad.json`: badge 6, strict 7, result 7)                                                                                                   | low      | deduplicate by id before strict and the result (S2)                                                                  |
| O17 | The near-miss hint suggests `invoice-pro-data` for `invoice-pro-data-fil` (§5.1)                                                                                                                                                                                        | low      | suggest the nearer of the two keys (S2)                                                                              |
| O18 | `check()` and the result report issues in two shapes (§5.9)                                                                                                                                                                                                             | medium   | one shape before `invoice-pro-result/1` is frozen (Q42, S5)                                                          |
| O19 | A locale that replaces `infer-tax` inherits the region's VAT list: data `"16%"` is refused where `tax: 16%` written by hand compiles (L15)                                                                                                                              | medium   | Q41 (S2)                                                                                                             |
| O20 | The shipped template is no skeleton for payment data: a `payment` section gives the coverage issue, a data file panics (§2.0)                                                                                                                                           | decision | Q36 (S6)                                                                                                             |
| O21 | Not measured: the live preview of a skeleton (`typst watch`) with the `load` line, the marker (which loads `src/contract/rows.typ`) and a data file                                                                                                                     | process  | `measure.py --watch` on a skeleton (S5)                                                                              |
| O22 | tytanic cannot pass `--input`: the R7 panics, `--input invoice-pro-result` and the CLI matrix need a script; root reads `invoice-pro-result` from `sys.inputs` directly (dev. 12)                                                                                       | process  | a CLI test script and CI job (S2, S5); make the result request injectable like `validation` (S5)                     |
| O23 | The amount-range guard is a conservative float bound: a price of 999 999 999 999 999 999 is refused (§3.6)                                                                                                                                                              | low      | compute it exactly with decimals (S1)                                                                                |
| O24 | Two doc comments are stale: `items` says "never traversed" (dev. 43); `invoice(data:)` omits `path` from its types                                                                                                                                                      | low      | S2, S3                                                                                                               |

## 12. Implementation plan

Branch `feature-data-api` (the maintainer's convention for large features), the concept at `docs/concepts/data-api/` (this folder), a GitHub issue first, so that each PR can say "Refs #N" (the roadmap item "Data Loading" exists, the issue does not, Q35). Each stage is a PR that ports the prototype's patches into `src/` with tytanic tests; the open fixes of §11.5 and the answers of §14 land in the stage that owns the code. Effort in maintainer-days (d), as rough ranges; the high end assumes the recommended answers of §14.

| Stage                         | Content                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Effort              | Tests the stage needs                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Docs, registries, CI                                                                                                                                                                                                                                                                             |
| :---------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S0 Concept                    | this document, `process/`, `prototype/` with the harness; the issue; the answers to §14                                                                                                                                                                                                                                                                                                                                                                                     | 1–1.5 d             | prettier 3.6.2; typstyle 0.15.1 on every block; no versioned imports                                                                                                                                                                                                                                                                                                                                                                                                                                                          | –                                                                                                                                                                                                                                                                                                |
| S8 Bug fixes (may land first) | L29 ellipsis and L30 `management` as lines, split out of patches 0006 and 0008; L24 `collect-signals` depth (then raise the nesting cap in a minor); L25 modifier string amount; L31 blank names in `check-data`; separate PRs                                                                                                                                                                                                                                              | 1.5–2 d             | a regression test each (an invoice number too long for the header line, a `management` array, depth-12 totals, a string amount, a blank name); the full suite unchanged                                                                                                                                                                                                                                                                                                                                                       | CHANGELOG entries; the issue test registry of `tests/TESTING.md`                                                                                                                                                                                                                                 |
| S1 Contract core              | L17, L4, L32: `src/contract/{types,schema,decode,export,input,api}.typ`, `src/public/invoice-data.typ`, the committed schemas, the conformance fixtures; the fixes O1, O3, O4, O7, O8, O15, O23; Q13; Q43 (L34); Q5 if accepted (+1.5–2.5 d: the data-only e-invoice rules in the decoder, through the existing `id.*` checks and the code lists of `src/zugferd/`, not as copies); the harness tools that become gates move from `prototype/harness/` to `tools/contract/` | 6–8 d (+ Q5)        | tytanic `tests/data/contract/` with its `.gitignore` (load with injected `inputs:`: inline, file, both, file without `read`, TOML, YAML, BOM; values, `null` and `""`, party, region rates); `tests/data/conformance/` with a CI job that compares python-jsonschema and ajv with `check` on both compilers; the fault corpus as a CI job (0 hard aborts); the schema drift check; a check of the `x-en16931` annotations against `tools/zugferd/bt-disposition.toml`; the decoder budget; codegen as an optional nightly job | `flake.nix`: Python with `jsonschema` in the dev shell, or flake apps for `signature.py`, the comparator and the fault corpus; ajv; `tests/TESTING.md`: the new `tests/data/` category (it sits next to the `tests/data-test.typ` utility; consider `tests/contract/`), the suites, the CI table |
| S2 `invoice()` integration    | L1–L3, L7, L12, L13, L15, L16 (localized `schema-*` texts, the "Daten / Data" chip); the hardened signature test (O6); the fixes O16, O17, O19 (Q41), O24; Q19, Q39                                                                                                                                                                                                                                                                                                         | 5–6.5 d             | the precedence matrix (every document and issuer key: absent, given, `null`, `""`); sample-leak tests (missing number, date, recipient, items → draft, no XML; strict panics); misuse; the integration tests and the template md5; `ctx.custom` through `unsealed()` and `info.get`; party `custom` without IP-KEY-01; a replaced `infer-tax` with data rates; `tests/theme/report-lang` with the new keys; a CLI test script outside tytanic for the R7 panics (O22)                                                         | `docs/docs/api-reference/locale/{base,custom,index}.md` (`vat-rates`); `invoice/index.md` (the parameter table)                                                                                                                                                                                  |
| S3 Items                      | L9–L11, L14, L28: the rows engine, the slot, the marker (O9), coverage issues, the hydrated modifier issue; the coverage table of the twelve mirrored components (§4.2)                                                                                                                                                                                                                                                                                                     | 4.5–6 d             | the generated equivalence suite as a CI gate, ported from `prototype/harness/` (0.6.0 hand-written vs hand-written on the new tree vs hydrated, md5 and XML: b/r/t × 5/50/300 × e-invoice none/auto × both compilers); the edge fixtures; slot misuse (two markers, a nested marker, a marker inside a group, items without `line-items`); a hydrated population in `zugferd-corpus`, so that P1 becomes a permanent CI property                                                                                              | `theme/parts.md` (`view.items[i].custom`); the component rule in `MAINTENANCE.md` (below)                                                                                                                                                                                                        |
| S4 `payment(..)`              | L5, L27, O2 (Q10); the rename of Q19 if accepted                                                                                                                                                                                                                                                                                                                                                                                                                            | 2.5–3.5 d           | the means matrix (transfer, direct debit, card, paid cash, paid by transfer) with and without data: BT-81, CII-SR-467/470, paid + terms excluded, missing mandate or last4 → issue, credit notes; without data md5 == the components; hydrated e-invoices in the list of `validate-all-zugferd` (Mustang and KoSIT, which CI already runs; O12) and in `zugferd-golden`                                                                                                                                                       | the pages of `payment-terms` and `bank-details` (their hydrated variant); "Validated Test Suites" of `tests/TESTING.md`                                                                                                                                                                          |
| S5 Result, CLI, perf gate     | L8, L18, O5, O18 (Q42, L35); the result request injectable (O22); the live preview of a skeleton (O21)                                                                                                                                                                                                                                                                                                                                                                      | 3–4 d               | the result validates against its schema; `typst query` (0.14) == `typst eval` (0.15); no record without data, PDF bytes unchanged by the input; the CLI matrix (inline, file, stdin, TOML, YAML, 0.15 path → one md5) as a script and CI job; instruction gates on both compilers: the hydrated 300-row ratio, an import-only document (Q2), a hand-written 5- and 300-row invoice; `check-package-bundle` compiles one hydrated invoice offline from the published files                                                     | `tools/perf/README.md`; `flake.nix`: valgrind for the perf gate                                                                                                                                                                                                                                  |
| S6 Docs                       | L26: api-reference pages `invoice-data` and `payment`, a guide "Generate invoices from data" (the recipe of §2.0, the skeleton, defensive rules, paths, the preview with data, the CLI, the coat of arms as a static patch, batches, results, a pipeline), the data-format reference generated from the descriptor (with a drift check); the template as a skeleton (L33, Q36); the reserved `invoice-pro-data*` prefix                                                     | 4–6 d               | a verbatim doc test under `tests/docs/<page>-<example>/` for every block; `scripts/check-docs-examples` (skip markers for blocks that read a data file)                                                                                                                                                                                                                                                                                                                                                                       | `docs/DOCUMENTATION.md` code block registry, `tests/TESTING.md` registry, `MAINTENANCE.md` (below), both READMEs, the intro, the `info` page (`info.get("custom", ..)`), the schemas under the docs site's `schema/invoice-pro/1/` (Q28); the roadmap entry stays open or is split (Q33)         |
| **0.7.0 feature**             |                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | **26–35.5 d**       | (S0–S6 without Q5; the synthesis estimated 23.5 d, the first draft 21.5 d)                                                                                                                                                                                                                                                                                                                                                                                                                                                    |                                                                                                                                                                                                                                                                                                  |
| S7 Speed PRs (Q15)            | S7a plain-dictionary `format-item` (1 d), S7b exact page seed (1.5–2 d), S7c `item()` on `item-signal` (2–3 d), S7d the other components on shared resolvers (4–5 d); API-neutral, separate PRs                                                                                                                                                                                                                                                                             | 8.5–11 d            | each: the full suite md5 on both compilers, the equivalence suite, a before/after perf table                                                                                                                                                                                                                                                                                                                                                                                                                                  | –                                                                                                                                                                                                                                                                                                |
| **0.7.0 as recommended**      | S0–S6, S8, S7a and S7b                                                                                                                                                                                                                                                                                                                                                                                                                                                      | **about 30–40.5 d** | (+1.5–2.5 d with Q5)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |                                                                                                                                                                                                                                                                                                  |
| S9 Follow-ups (0.7.x)         | `derive` and declared custom fields (Q17), the result attachment (Q18), `item(custom:)` (Q30), bundle batches (Q31), a `locales:` map (Q32), items from a file for the marker (Q33), explicit none (Q23)                                                                                                                                                                                                                                                                    | –                   | per feature                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | per feature                                                                                                                                                                                                                                                                                      |

The ranges grow against the first draft because the critiques found work that the plan had left out: S1 gained seven fixes and the CI tools, S2 the region defect and the CLI tests, S4 the existing e-invoice CI, S5 the instruction gates, the bundle check and the issue shape, S6 more pages and the template.

New items for `MAINTENANCE.md` (a section "Data format"):

- **Descriptor change:** regenerate both schemas with `typst eval` and commit them (the drift check fails otherwise, once S1 wires it into CI); a new key gets `since` and a new minor in `src/contract/schema.typ`; regenerate the conformance fixtures with the generator that `tools/contract/` takes over from `prototype/harness/schema/make_fixtures.py`, or extend it; check the `x-en16931` annotations against `tools/zugferd/bt-disposition.toml`; publish the schemas on the docs site.
- **Version bump:** nothing in the schemas (their `$id` carries the format major only); the result's `package` field reads `typst.toml`; the new docs pages with versioned imports go on the bump checklist.
- **A new `invoice()` parameter:** classify it in `invoice-params` (the signature test fails otherwise).
- **A change to a line-item or payment component** (`item`, `group`, `bundle`, `discount`, `surcharge`, `modifier`, `prepayment`, `payment-terms`, `bank-details`, `direct-debit`, `card-payment`, `paid`): mirror it in `src/contract/rows.typ` or `src/components/payment.typ` and in the descriptor, or mark the parameter Typst-only in the component coverage table; the equivalence suite must pass on both compilers.
- **A new contract module:** add it to `LAZY_MODULES`.

## 13. Risks and known gaps

1. **Drift between the components and the rows engine.** The engine replays the scope cascades of `item`, `group`, `bundle`, `modifier` and `prepayment`. Mitigation: the equivalence suite as a CI gate (S3), the component coverage table and its MAINTENANCE rule (§4.2, §12), then one implementation through shared pure resolvers (S7c, S7d). Until then `calculate-item-data`, `calculate-bundle`, `calculate-modifier` and the unit and tax resolution are pseudo-contracts.
2. **Memo sensitivity.** The gain depends on `env` being identical in both loom passes. A change that puts `ctx.global` or `sys` into `env` silently loses about half of it. Mitigation: the perf gate (§7.5) and a comment at `env-of`.
3. **Re-entry discipline.** A new `invoice()` parameter must be classified, or the hydrated branch would pass it on wrongly. Mitigation: the signature test, whose parser still has blind spots (O6).
4. **The nested weave in `payment(..)`.** It weaves its components with `loom.core.intertwine` in measure and again in draw; a loom upgrade that changes `intertwine` or path semantics must be tested against it.
5. **Decoder and schema are two interpreters of one table.** Mitigation: the differential fixtures and code generation in CI on both compilers.
6. **Crash paths.** Any missed pre-validation aborts a batch process. Mitigation: the corpora in CI; O1–O3 are open.
7. **Layout dominates after the fast path.** 1000-line invoices still take 9–18 s in design C's runs. Mitigation: S7b; a theme concept for keep-together and the table part.
8. **No gain for small invoices.** Below about 10 rows hydration is as fast as hand-written, not faster (§7.3). The value of the feature there is the workflow, not the speed.
9. **The cost for every invoice:** the import runs about +1.2–1.5 ms (+0.75–0.81 % of its instructions), and a hand-written invoice +0.4–0.5 % instructions in all (§7.3, Q2).
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
23. **Rules in skeletons can abort on incomplete data** (§2.1). A rule that assumes a key or a type loses the draft that would show the data's problems. Mitigation: the guide's defensive pattern, tested with incomplete data, and `values(.., default:)` (Q43).
24. **A second map of business terms.** The descriptor's 112 `x-en16931` annotations duplicate `tools/zugferd/bt-disposition.toml`. Mitigation: a consistency check (S1).
25. **The harness is a record.** `prototype/harness/` runs in no CI job, so it will drift from the code once the gates are ported. Mitigation: port what becomes a gate in S1, S3 and S5; keep the rest as the record of the exploration.

## 14. Open questions for the maintainer

The questions are grouped by the stage that needs the answer, most consequential first within a group. Each decision gives the recommendation, the alternative and what the alternative changes in this concept: sections, ledger rows, the stage and the days. The numbers are stable across drafts (Q36–Q44 are new in this one); Appendix D maps them to the synthesis' numbers, which the process files use.

### 14.1 Please confirm

These were settled by the prototype or by this draft, and nothing in the verification speaks against them.

- **Q25 YAML and TOML.** JSON is canonical; TOML and YAML are read by file extension and give md5-identical PDFs (P7).
- **Q27 `format` required.** A missing `format` is an issue; another major panics.
- **Q28 The schema host.** `https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/…` (patch 0010). Action item of S6: the docs build must publish the two files there, or the `$id`s point at nothing.
- **Q35 Branch, folder and issue.** Open the GitHub issue first, rename the branch to `feature-data-api` (the harness branch is `claude/invoice-pro-programmatic-generation-1uwaga`), and keep the concept at `docs/concepts/data-api/` with `process/` and `prototype/`, as the theming concept did.
- **Q38 The harness as a record.** This draft commits the harness sources in `prototype/harness/`, without outputs and without the verifiers' corpora. S1, S3 and S5 port what becomes a CI gate into `tools/contract/` and `tests/`. The alternative, moving the whole harness into `tools/` now, costs 1–2 d in S0 and leaves more code to maintain.
- **Q44 `<ip-issue>` stays internal.** The result's `issues[]` is the documented channel (§5.4), so the label of the draft report and its record shape do not become a CLI contract.

### 14.2 Decide before S1 (the format and the decoder)

- **Q1 Data errors: issues or panics?** _Recommendation:_ class-`data` issues: a draft previews incomplete data with a report and no XML; `strict` is for sending and CI (implemented; 0 hard aborts on the corpora outside §11.5). _Alternative:_ always panic. That loses the draft preview and every machine-readable issue: §8.1 and §8.3 change, the result has no `issues`, Q42 falls away, and S1 and S2 shrink by about 1 d.
- **Q5 E-invoice rules that depend only on the data.** Wrong identifier check digits (IP-ID-01), unknown country or currency codes (BR-CL-14, BR-CL-04), tax rates with more than 4 decimals (IP-DEC-01) and a rate on a zero-rated category (BR-Z-05) pass `check()` and stop the default compile. _Recommendation:_ check them in the decoder as data issues in 0.7.0, so that `check()` predicts them and a draft shows them. The decoder calls the existing `id.*` checks and the code lists of `src/zugferd/` instead of copying the rules; the rules that need the whole invoice (IP-DOC-03, IP-PAY-06) stay with the e-invoice engine. Cost: S1 +1.5–2.5 d. _Alternative:_ document that pipelines use `zugferd-errors: "report"` and read `e-invoice.status`; no work, but `check()` stays blind to these stops (§8.5).
- **Q34 The scope of `check()`.** It checks what the decoder checks. A hydrated invoice can report more: the skeleton's rules, coverage, a payment method without its details (O15), the legal and the e-invoice rules. _Recommendation:_ document this in 0.7.0, and move O15 and, with Q5, the data-only e-invoice rules into the decoder (S1). _Alternative:_ a `check(.., skeleton:)` that compiles the skeleton without layout: later, if asked for, several days.
- **Q9 Printable characters.** Noncharacters are rejected (dev. 37). Open: C0 controls and texts of only format characters (`\p{Cf}`) give empty or invisible XML values; unassigned and private-use code points stop PDF/A. _Recommendation:_ reject C0 controls other than TAB, LF and CR, do not count `\p{Cf}` as filling a required text, and document unassigned and private-use characters as font-dependent, as for hand-written invoices (O3, S1). _Alternative:_ reject `\p{Cn}` and `\p{Co}` too. A private-use glyph of a custom font then cannot be used; S1 +0.25 d.
- **Q37 The JSON Schemas in the package.** The two committed schemas are 108 015 bytes, 7.6 % of the published `src/` after the change, and no Typst code reads them: `invoice-data.schema()` generates them, and their `$id`s point at the docs site. _Recommendation:_ keep them in the repository for review and the drift check, but leave them out of the bundle (`"/src/contract/*.schema.json"` in the `exclude` of `typst.toml`; `check-package-bundle` then proves that nothing needs them). _Alternative:_ ship them, so that a user finds them in the package cache, at +108 KB for every download. Either way S1, no extra days.
- **Q13 An object with every key absent.** `"terms": {"days": ""}` from a spreadsheet replaces the skeleton's terms with empty terms. _Recommendation:_ an optional object whose keys are all absent is itself absent, so the skeleton's terms apply (S1, +0.25 d: the decoder and fixtures). _Alternative:_ keep "replaced as a whole" literally and document it in §3.3; no work.
- **Q43 A shorter safe form for design rules.** The defensive rule of §2.1 is long, and a short rule aborts on incomplete data. _Recommendation:_ `invoice-data.values(record, default: sample)`, which returns the samples without data and the values with data (L34, S1, +0.25 d, no new name), and a guide that shows the defensive pattern. _Alternative:_ also a getter such as `invoice-data.get(values, "recipient", "city", "post-code", default: none)` that accepts `none` on the way: one more name, the namespace grows to 11. Or the docs only.
- **Q14 `""` for typed keys.** _Recommendation:_ keep the reader leniency (an optional `""` is absent for every type) and a schema that accepts `""` for texts only, so that producers' generated types stay precise (implemented, dev. 36). _Alternatives:_ accept `""` in the schema, which turns generated dates and enums into unions (§10.3's results change); or reject it in the decoder, which breaks spreadsheet exports (the 88 blank-optional equivalence cases of fix 2 change).
- **Q21 One spelling for units and taxes.** _Recommendation:_ UN/ECE codes (any Rec 20 code) or `{code, display}`; tax `"19%"` or an object, no presets (implemented). _Alternative:_ also unit names and presets such as `"exempt"`: a second spelling for each concept, which broke the Rust generator; S1 +1 d.
- **Q22 JSON numbers.** _Recommendation:_ rejected for texts (the fix is shown), tolerated exactly for decimals (implemented). _Alternative:_ strings only: the `lenient` fixtures become invalid, and producers that write numbers get issues.
- **Q23 An explicit none.** _Recommendation:_ `null` is absent everywhere in v1; cancelling a cascaded value per child is not expressible. _Alternative:_ `null` = `none` where meaningful, which conflicts with generated model dumps: the fixtures with 145 nulls change their meaning.

### 14.3 Decide before S2 (`invoice()` integration)

- **Q41 The VAT rates of a customised region** (L15, O19). A locale that replaces `infer-tax` inherits the region's `vat-rates`, so the data path refuses a rate that the replaced `infer-tax` accepts for hand-written values. _Recommendation:_ the locale patch engine sets `vat-rates` to `none` when a patch replaces `normalize.infer-tax` without giving `vat-rates`; the region pass then leaves the rate to `infer-tax`, as for hand-written values (S2, +0.5 d with tests). _Alternatives:_ the region pass trusts any replaced `infer-tax`, which needs a way to tell it from the region's own; or the docs say that a custom `infer-tax` must also set `vat-rates`, which costs nothing and leaves a trap in every custom region.
- **Q6 The role of `document-type`.** _Recommendation:_ issuer: a credit-note skeleton stays a credit note unless the data says otherwise (implemented). `subject`, `notes` and `currency` are issuer keys too; `customer-nr` and `project` are document keys. _Alternative:_ document (design D). A credit-note skeleton hydrated without the key then silently becomes an invoice; §3.4 and the descriptor change, no days.
- **Q7 Custom fields: replaced or merged?** _Recommendation:_ the data's `custom` replaces the skeleton's sample `custom` as a whole (implemented): no sample can leak; constants belong in Typst code, defaults in `default:`. _Alternative:_ a key-by-key merge over `invoice(custom:)`. A sample value can then survive, so P3 no longer holds for custom fields; §3.8, decision 5 and R2 change.
- **Q19 Names.** Settled by the prototype and kept: `invoice(data:, custom:)`, `invoice-data` (10 names), `payment`, `invoice-data.items`, `<invoice-pro-result>`, the `invoice-pro-data*` keys; no builtin shadowed, and the export test pins them. Three names are cheap to change now and expensive later:
  - `payment(bank: (bank: "Musterbank", ..))` and the data's `payment.bank.bank` read badly, and the parameter's own doc calls it "the account to pay to". _Recommendation:_ rename the outer key to `account` (`payment(account: (bank: .., iban: ..))`, data `payment.account`; EN 16931 calls BG-17 the payment account). _Alternative:_ keep `bank`, which mirrors `bank-details`. The rename touches `payment.typ`, the descriptor, the schema and the fixtures (S4, +0.5 d).
  - The issue ids `schema/<pointer>` belong to class `data`, while theme issues use the prefix of their class (`theme/…`). _Recommendation:_ `data/<pointer>`; the keys `schema-<kind>` keep naming the rule that failed. _Alternative:_ keep `schema/`. S2, +0.25 d.
  - `custom` gets a third meaning next to `theme.custom` and `locale.custom`, which are helper namespaces. _Recommendation:_ keep `custom`: the request says "custom felder", and `invoice(custom:)` holds fields, not helpers. _Alternative:_ `fields`; S2, +0.25 d.

  Considered and dropped for the namespace: `hydrate`, `data-format`. Decision 14 says why the namespace is not called `data`.

- **Q39 The validation level of a pipeline.** Under the default `draft`, a hydrated invoice with problems exits 0 (§5.6). _Recommendation:_ keep `draft` as the default, because a preview with data is a design-time use (§2.2), and make `--input invoice-pro-validation=strict` the documented pipeline form (§5.9, the guide). _Alternative:_ a data input implies `strict` unless `validation` is given; a skeleton previewed with real data then stops instead of showing the draft. S2, +0.25 d either way.
- **Q24 Sources and misspelt keys.** _Recommendation:_ an explicit `data:` value plus a data input panics, and so does a near miss of the two data keys (implemented). This reserves every `invoice-pro-data*` key (§5.1); other `invoice-pro-*` keys stay free for skeletons. _Alternatives:_ data wins or input wins, which hides a pipeline mistake; or catch every unknown `invoice-pro-*` key, which would change invoices without data that read keys of their own.
- **Q20 A partial sender** (a clerk per invoice, letterheads of several tenants). _Recommendation:_ `sender` is replaced as a whole; a per-invoice contact comes later through `derive`. _Alternative:_ "a data party without `name` completes the skeleton's". That is a deep merge for one key, with the risk of pairing one tenant's VAT ID with another's name (decision 4); S2 +0.5 d.
- **Q26 Localized issue texts in 0.7.0.** _Recommendation:_ yes (L16 in S2): `schema-*` texts in the six languages and the chip "Daten / Data" instead of "Pflichtangabe". _Alternative:_ English messages first. L16 and its ⚠ then leave 0.7.0, S2 shrinks by about 1 d, and data issues keep the chip "Pflichtangabe".
- **Q29 Tier.** _Recommendation:_ `invoice-data`, `payment` and `invoice(data:, custom:)` experimental, the format `invoice-pro/1` provisional. _Alternative:_ provisional throughout. Every change in 0.7.x then needs a changelog entry and a migration note.

### 14.4 Decide before S3 and S4 (items, payment)

- **Q4 The binding point of the items.** _Recommendation:_ the `line-items` body by default, and the optional `invoice-data.items[..]` marker (at most one, a direct child, `apply` transparent) for static rows (implemented, P1 edge fixtures). _Alternatives:_ a required marker: a forgotten marker would drop the data unless a coverage issue catches it (S3 +0.5 d). Or implicit only: the marker and its misuse rules go (S3 −0.5 d), and no fixed fee is possible.
- **Q10 Guards of the components on the data path.** The prototype turns a credit-note conflict into a data issue for `payment(..)` and `payment-terms(discount:)` (dev. 25, 42), but the raw `direct-debit(..)` and `card-payment(..)` still panic (O2, rated high). _Recommendation:_ one rule: when hydrated, what a component would stop on because of the data becomes a data issue, and the component is left out; written in Typst, it still panics (S4, +0.5 d). _Alternative:_ panic on the data path too; a batch then aborts on one file, and §8.1 changes.
- **Q11 `payment-terms` and `bank-details` as binding points.** _Recommendation:_ no: `payment(..)` is the one binding point of the `payment` section, and a skeleton that uses the single components gets the coverage issue `schema/payment` with the fix. _Alternative:_ make both components data-aware: five components with data rules instead of one block (S4 +1.5–2 d), and the shipped template would hydrate payment data unchanged.
- **Q12 A data `bank` with another method.** _Recommendation:_ leave it out without an issue, like the skeleton's own account (implemented, dev. 41): `bank` is standing issuer data, and an invoice states one payment means. _Alternative:_ a data issue, which also flags a wrong IBAN that is never used; S4 +0.25 d.
- **Q16 The nesting cap.** _Recommendation:_ cap 8 now; fix `collect-signals` in a bugfix PR (L24, S8) and raise the cap in a minor. _Alternative:_ keep the cap and the bug: L24 leaves S8 (−0.5 d), and deep invoices written by hand keep wrong totals.

### 14.5 Decide before S5 and S6 (result, CLI, performance, docs)

- **Q2 Restate the root-import budget.** The synthesis' 0.2 ms is missed: the prototype adds +3.84 M / +3.88 M instructions (+0.75 % / +0.81 %), about 1.2–1.5 ms, for every invoice; a hand-written invoice runs +0.4–0.5 % instructions in all (§7.3). What remains is the documented API: the two parameters and the re-entry hook, the items slot, root's hooks, the two documented facades, the regions' VAT lists. _Recommendation:_ restate it as "≤ 1 % of the root import's instructions" (or ≤ 2 ms), with a deterministic gate on an import-only document in S5 (valgrind in the flake). _Alternative:_ keep 0.2 ms. That needs an undocumented `..args` wrapper around `invoice()`, which loses the signature, its docs and the editor hints, or facades without doc comments (+1–2 d).
- **Q3 The performance gate.** The wall-clock ratio of the hydrated 300-row invoice passes pooled (0.567–0.579×), but 2 of 12 series medians exceed 0.6 on the shared VM. _Recommendation:_ gate on instruction counts (0.561× / 0.562×, stable) with the threshold 0.6, and state openly that invoices below about 10 rows gain nothing (S5). _Alternative:_ keep a wall-clock gate and widen the margin with S7a and S7b first; both then become required for 0.7.0.
- **Q36 The shipped template as a skeleton.** As shipped, `template/invoice.typ` panics on `--input invoice-pro-data-file` and turns data with a `payment` section into a draft. Converted as in §2.0, its PDF stays byte-identical to 0.6.0 on both compilers (measured for this revision). _Recommendation:_ ship the converted template in S6 (L33), with three comment lines on hydration; its golden XML and thumbnail stay as they are. _Alternative:_ keep the template an invoice without data and show the conversion in the guide only. New users then start from a file that cannot take a data file.
- **Q42 One issue shape.** `check()` reports `{id, path, key, message, fix}`, the result `{id, class, path, message, ref}` (§5.9). _Recommendation:_ one shape in both, `{id, class, path, key, message, fix, ref}` (L35, S5, +0.5 d), before `invoice-pro-result/1` is frozen. _Alternative:_ document the mapping; every binding then handles two shapes for the life of the major.
- **Q8 When is `<invoice-pro-result>` emitted?** _Recommendation:_ hydrated invoices and `--input invoice-pro-result=1` (implemented; no cost without data). _Alternative:_ every invoice, once it is measured at ≤ 1 ms without loading the descriptor; that cost then joins the budget of Q2.
- **Q15 The internal speed PRs in 0.7.0?** _Recommendation:_ S7a and S7b with 0.7.0, as separate API-neutral PRs, because they are the margin of the perf gate; S7c and S7d when convenient; a cheaper keep-together check goes to a theme concept. _Alternative:_ all later: 0.7.0 shrinks by 2.5–3 d, and the gate keeps its thin wall-clock margin.
- **Q18 A result in the same compile** (`--input invoice-pro-result=attach`, a JSON file next to `factur-x.xml`). _Recommendation:_ 0.7.x, after Mustang and KoSIT accept a PDF with the extra attachment. _Alternative:_ in 0.7.0 as an opt-in experiment: S5 +1–1.5 d and a validator run with the extra attachment.
- **Q31 Batches in one process.** Print invoices already work in one document (§5.3). _Recommendation:_ document that pattern in 0.7.0; e-invoices stay one process each; a 0.15 bundle pattern (or helper) later. _Alternative:_ an `invoice-data.batch` now: one more name, S5 +1 d, and still one PDF per e-invoice.

### 14.6 Later (0.7.x; no work in 0.7.0)

- **Q17 Declared typed custom fields and a `derive` hook.** _Recommendation:_ 0.7.x, as `load(.., extensions:, derive:)`, with names that shadow no builtin. _Alternative:_ in 0.7.0 (design D, the user judge): the 0.7.0 surface grows by two parameters and a schema export for custom fields; S1 +2–3 d.
- **Q30 `item(custom:)`.** _Recommendation:_ 0.7.x, for preview parity with data rows, and freeze `view.items[i].custom` in the part contract. _Alternative:_ in 0.7.0, a new parameter of a stable component; S3 +0.5 d.
- **Q32 A locale key in the data.** _Recommendation:_ no locale key in the v1 format: a locale is design, and its customisations are closures. The skeleton already selects the locale by a value of the data (§6.2). Later perhaps a `locales: (de: .., en: ..)` map that the data selects by name. _Alternative:_ a `locale` key that names a built-in locale; S1 +0.5 d, and customised locales still need Typst.
- **Q33 Items alone from data in a hand-written invoice** (`invoice-data.items(rows: ..)`, the roadmap's "Data Loading"). _Recommendation:_ 0.7.x; rows from Typst code are code, so bad rows panic. In 0.7.0 the roadmap checkbox stays open, or the entry is split into "invoices from data (0.7.0)" and "items from a file (0.7.x)". _Alternative:_ in 0.7.0; S3 +1–1.5 d.

---

## Appendix A: provenance

**Process.**

1. Research: nine readers produced the ground truth of the repository, with path:line evidence.
2. Designs: four proposals, each with a working prototype in a copy of the repository: A converters, B integrated, C performance, D contract.
3. Judgement: three judges (maintainer, engine, user) scored and ranked them; the panel digest merged their findings.
4. Synthesis: one unified design on base D with grafts from A, B, C and the judges, plus one new mechanism (re-entry), checked in a feasibility prototype.
5. Prototype: the synthesis built as one branch, with a self-check of ten proofs on both compilers.
6. Verification: four independent verifiers in three rounds (0, 1, 2), with two fix rounds (fix 1, fix 2) in between; then patch 0010.
7. This concept, first draft.
8. Review: three critics (accuracy, maintainer, requirements) reviewed the first draft, each with its own runs against the prototype; this second draft applies their findings (Appendix E).

**Sources** (in `process/`, kept as produced; local paths are replaced by `<session>`, `<unified>` and `<repo>`):

| Kind      | Files                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| :-------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| research  | [conventions](process/research/conventions.md), [invoice-api](process/research/invoice-api.md), [line-items](process/research/line-items.md), [loom-engine](process/research/loom-engine.md), [payments-misc](process/research/payments-misc.md), [prior-art](process/research/prior-art.md), [theming-data-flow](process/research/theming-data-flow.md), [typst-cli](process/research/typst-cli.md), [validation-zugferd-locale](process/research/validation-zugferd-locale.md) |
| designs   | [A-converter](process/designs/A-converter.md), [B-integrated](process/designs/B-integrated.md), [C-performance](process/designs/C-performance.md), [D-contract](process/designs/D-contract.md)                                                                                                                                                                                                                                                                                   |
| verdicts  | [verdict-maintainer](process/designs/verdict-maintainer.md), [verdict-engine](process/designs/verdict-engine.md), [verdict-user](process/designs/verdict-user.md), [\_panel-digest](process/designs/_panel-digest.md)                                                                                                                                                                                                                                                            |
| synthesis | [synthesis](process/designs/synthesis.md)                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| prototype | [build](process/prototype/build.md), [deviations](process/prototype/deviations.md); the code in [`prototype/`](prototype/README.md), the harness in [`prototype/harness/`](prototype/harness/README.md)                                                                                                                                                                                                                                                                          |
| review    | [verification](process/review/verification.md); the first draft [draft-1](process/review/draft-1.md) and its critiques [critique-accuracy](process/review/critique-accuracy.md), [critique-maintainer](process/review/critique-maintainer.md), [critique-requirements](process/review/critique-requirements.md)                                                                                                                                                                  |

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
5. **A result on every invoice that loads the descriptor** (design D): 4.79 ms traced for every invoice, 2.29 ms of it the descriptor.
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
16. **One `--input` key per field** (`--input invoice-nr=…`): inputs are strings only, the format is nested, and one schema covers one document; a skeleton can still merge a value of a key of its own into the data (§5.1).

## Appendix C: evidence index

In the repository (relative to this document):

- [`prototype/patches/`](prototype/patches/): the ten patches; [`prototype/run.sh`](prototype/run.sh): the 12 core checks; [`prototype/harness/`](prototype/harness/README.md): the sources of the builder's harness (generators, the fault corpus, comparators, benchmark scripts); [`prototype/examples/`](prototype/examples/): `skeleton.typ`, `handwritten.typ` (the 0.6.0 twin of §3.11), `skeleton-path.typ` (0.15 `path`), `wappen/*.svg`; [`prototype/data/`](prototype/data/): `2026-0042.json`, `2026-0042.toml`, the `broken-*.json` and `w-*.json` cases.
- [`process/prototype/build.md`](process/prototype/build.md) (the builder's self-check), [`process/prototype/deviations.md`](process/prototype/deviations.md) (49 decisions), [`process/review/verification.md`](process/review/verification.md) (rounds 0–2, fix 1, fix 2, still open), [`process/review/draft-1.md`](process/review/draft-1.md) and the three `critique-*.md` (the review of the first draft).

In the scratch directory of the exploration (not in the repository):

- `<session>/exp/unified/`: the prototype's clone (`repo/`, branch `proto`, and `repo-s7a/`, branch `proto-s7a`), a pristine clone, the harness `proto/` with its outputs (its sources are now in `prototype/harness/`), the runbook `README.md`, the verifiers' directories `verify-{equivalence,robustness,contract,features-perf}/` and the fix rounds `fix1/`, `fix2/`, `vr2/`.
- `<session>/exp/design-{A-converter,B-integrated,C-performance,D-contract}/`: the design prototypes; `<session>/judge-engine/`, `<session>/exp/judge-user/`, `<session>/judge/`: the judges' runs; `<session>/exp/synth/`: the re-entry feasibility check; `<session>/design/SYNTHESIS.md`: the synthesis.

## Appendix D: question numbers of the synthesis

The synthesis numbered its 23 questions differently, and the process files (`deviations.md`, `build.md`, `verification.md`) use those numbers: dev. 9 "Q3" is this concept's Q7, dev. 12 "Q6" is Q18.

| Synthesis | Q1  | Q2  | Q3  | Q4  | Q5  | Q6  | Q7  | Q8  | Q9  | Q10 | Q11 | Q12 | Q13 | Q14 | Q15 | Q16 | Q17 | Q18 | Q19 | Q20 | Q21 | Q22 | Q23 |
| :-------- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| Concept   | Q1  | Q6  | Q7  | Q4  | Q8  | Q18 | Q17 | Q19 | Q20 | Q21 | Q22 | Q23 | Q24 | Q16 | Q15 | Q25 | Q27 | Q28 | Q29 | Q30 | Q31 | Q32 | Q33 |

The concept's Q2, Q3, Q5, Q9–Q14, Q26, Q34 and Q35 came from the prototype and its verification (first draft); Q36–Q44 came from the review of the first draft.

## Appendix E: changes since draft 1

The first draft is kept as [`process/review/draft-1.md`](process/review/draft-1.md). The three critiques found no error in the design, two blockers in the plan and many corrections. What this draft changed:

- **Accuracy** ([critique](process/review/critique-accuracy.md)). §3.7 marks "a method without its details" as a rule of the hydrated `payment(..)` only (O15, Q34). The near-miss hint is quoted as the prototype prints it (O17). Duplicate issue ids are documented (O16), and so is the conservative amount guard (O23). §4.2 no longer calls the key scan the only run-time cost. The stale doc comments are noted (O24), and the `a-3b` wording is corrected. The commands create `out/`. The trace figures of §7.3, whose source is not in the repository, are gone. The schema counts are marked as counted, and the corrected figures are: 145 nulls, 10 + 1 files for P4, 0.567–0.579× pooled, the series spread, the 3154 mutations with their exceptions. The summary says "two of them only under PDF/A" and "none of it changes the Typst API". The drift check is a manual command with a proposed CI step. Corrected attributions: the engine judge's re-run, 4.79 ms. Further fixes: the payee account in §2.3, the `extra` maps, `docs/DOCUMENTATION.md`, dev. 9 cited.
- **Maintainer** ([critique](process/review/critique-maintainer.md)). B1: the harness sources are committed in `prototype/harness/`, with re-runs from there, and L19 lists the tools again. B2: L15 is a new public region key, and its defect is reproduced (O19, Q41). The summary states the cost and names the non-extensions. Ledger changes: L32 for the exported shapes, L9 "also without data", the reserved `invoice-pro-data*` prefix in L7 and §5.1. `<ip-issue>` is no longer documented (Q44). The template is a question (Q36, L33). §14 is split into confirmations and decisions by stage, with consequences, and Appendix D maps the numbers. The plan has ranges and the left-out work (the existing e-invoice CI, the flake, the tytanic limits, the bundle check, the registries, the BT map check), and the total is restated. Also added: component coverage (§4.2, `MAINTENANCE.md`), the no-data cost (§7.3, with instruction counts measured for this revision), the status of P8 and P10, the names (Q19), the pipeline level (Q39), the split of L29 and L30, and the header of `skeleton.typ` and the status line of the synthesis copy.
- **Requirements** ([critique](process/review/critique-requirements.md)). Rules must tolerate absent values (§2.1, §8.3, Q43). New: the recipe for an existing invoice (§2.0) and the "Not in 0.7.0" list with the roadmap item (Q33). Performance: the typical invoice (§7.0) and the one-document print batch (§5.3). CLI: paths (§2.2), a pipeline and the issue shapes (§5.9, Q42), the design-time preview (§2.2), one key per field (§5.1, Appendix B), fonts and offline packages (§5.2). Also: the locale by a value (§6.2, Q32), the post-code rule marked as illustrative, item custom fields, the typst-py claim, the inferred requirement, codegen as optional, and the cost of `payment(..)`.
- **Not applied.** The format reference (§3.2–§3.7) stays in the body; the maintainer critique suggested an appendix. The data format is the first thing the request asks for, and the decision document should show it where it is decided; S6 generates the docs reference from the descriptor anyway. The prototype stays as verified: the B2 fix, the issue shape, the near-miss hint and the other code changes are proposals for S1–S6 (O15–O24), not patches.
