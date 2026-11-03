# Invoice data hydration, phase 1: the unified design (`invoice(data:)` + `invoice-data`)

Status: synthesis of the four phase-1 designs (A-converter, B-integrated, C-performance, D-contract) and the three judgements (maintainer, engine, user), for invoice-pro 0.6.0 → 0.7.0. Every number below was measured by a design prototype or by a judge on typst 0.15.1 **and** 0.14.2, unless it is marked _(not measured)_ or _(target)_. The one mechanism that is new in this synthesis (re-entry precedence, §4.2) was checked in a feasibility prototype at `<session>/exp/synth/` (both compilers). `<session>` is the scratch directory of the exploration, which is not part of the repository. Typst blocks assume `#import "<invoice-pro>": *` and carry no versioned import (concept convention: no stale-version hits for `scripts/check-version`); shell lines write `@preview/invoice-pro:<version>`.

---

## 1. Executive summary

**The idea in one paragraph.** A user designs an ordinary invoice in Typst, with sample values: the _skeleton_. It previews like any invoice. To produce a real invoice, they hand over ONE JSON document (inline `--input invoice-pro-data=<JSON>`, a file via `--input invoice-pro-data-file=<path>`, or stdin), and invoice-pro _hydrates_ the skeleton: inside `invoice()`, before its own checks, the data replaces what identifies one invoice (number, dates, recipient, references, line items, the details of a direct debit/card/paid invoice, custom fields), keeps the issuer's settings unless the data gives them (letterhead, bank, terms, tax settings), and never touches design. The line items of the data replace the sample body of `line-items` as ONE bulk loom motif, which is byte-identical to the same invoice written with `item()` calls and 31–55 % faster at 50–1000 rows (−16 % or noise at 5 rows). Problems in the data become ordinary `data` issues: draft report and withheld XML under `validation: "draft"`, a panic listing every problem under `"strict"`.

**Base and grafts.** The base is **design D (contract first)**, because it already contains B's integration model (`invoice(data: auto)`, document/issuer roles, `payment(..)`, the whole-body items slot, coverage issues) and adds the strongest error model and phase-2 tooling (one descriptor table → decoder + JSON Schema + docs; conformance fixtures; codegen). It ranked first in two of three judgements and has the highest total (D 114, B 106.5, A 97, C 90). Grafted on:

- from **C**: the rows engine (`hydrate/items.typ`, the only one byte-identical on nested and dated bundles, `apply` cascades and explicit none), the sample held in a closure, region VAT-rate pre-checks, `{"text": ..}` for BT-20, and the API-neutral speed work (plain-dict `format-item`, shared `item-signal` resolver, exact page-count seed) as separate PRs;
- from **B**: `invoice(custom:)`, the single `payment(..)` file;
- from **A**: Wappen as a STATIC, document-level theme patch (keeps the e-invoice "is it printed" checks active), the party normaliser, the explicit slot marker for static rows, paid-by-transfer keeps the account (CII-SR-470);
- from the **judges**: panic when a data input is given but not consumed; `null` ≡ absent everywhere (generated models dump nulls); a crash-free decoder (0 hard aborts on the fault corpus); a small namespace (10 names, none shadowing builtins); the result record only on hydrated invoices or on request.

**One new mechanism resolves the last fatal flaw.** B and D copied `invoice()`'s defaults into a second table (drift, flagged by the maintainer judge). Here the hydrated branch of `invoice()` calls `invoice()` again with the effective arguments and simply leaves out every document key the data lacks, so the signature's own defaults apply. No defaults are copied anywhere (§4.2; verified: hydrated == hand-written md5 on both compilers, sample number dropped → draft "‹fehlt: Rechnungsnummer›" with XML withheld, template md5 unchanged).

**Public API: only extended.**

- 2 `invoice()` parameters: `data`, `custom`;
- 2 root exports: `invoice-data` (10 names), `payment`;
- 3 `--input` keys: `invoice-pro-data`, `invoice-pro-data-file`, `invoice-pro-result`;
- 1 metadata label: `<invoice-pro-result>`;
- 1 reserved print-only party key: `custom`.

No existing signature, default or non-hydrated output changes. The few changes that are not pure extensions (§9, marked ⚠) are each justified: a reserved party key that no longer warns, a panic on reserved input keys nobody can use today, bug fixes in separate PRs, and internal refactors with byte-identical output.

**What the maintainer must decide** (§13; each has a recommendation): Q1 data errors as issues or panics; Q2 the role of `document-type`; Q3 custom fields replaced or merged; Q4 the items binding point; Q5 when the result record is emitted; Q7 declared typed custom fields and the `derive` hook now or later; Q15 whether the internal speed PRs ship with 0.7.0.

---

## 2. Decisions at a glance

| #   | Decision                         | Choice                                                                                                                                                                            | Why                                                                                                                                                                  | Alternative (rejected or open)                                                                                                               |
| :-- | :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Base design                      | D (contract first), which already contains B's integration                                                                                                                        | Highest total (114 vs 106.5/97/90); robust error model (0 hard aborts in 38 faults); phase-2 tooling verified (51/51 conformance, pydantic/TS/Rust codegen)          | B as base (maintainer's first choice; D is B plus the contract tooling)                                                                      |
| 2   | Entry point                      | `invoice(data: auto)`; `auto` reads `--input invoice-pro-data`                                                                                                                    | Data issues must join invoice()'s own validation (draft markers, strict panic, XML withholding at invoice.typ:547); zero-code inline hydration of any skeleton       | Converters and `.with` (A): needs skeleton restructuring and the internal lazy-theme channel for issues                                      |
| 3   | Precedence                       | Per key **role**: `document` = from the data only (the skeleton value is a sample and is dropped); `issuer` = the skeleton's value unless the data gives it; design is never data | A sample can never leak (verified on B, D and here); no skeleton marks                                                                                               | Presence-only override (C): leaked `MUSTER-0001` into a clean EN 16931 XML (fatal, two judges); base/sample dicts (A)                        |
| 4   | Defaults of absent document keys | **Re-entry**: the hydrated branch calls `invoice(..effective)` and omits absent document keys, so the signature's defaults apply                                                  | No second copy of the defaults (B and D drift silently); verified on both compilers (§4.2)                                                                           | A private defaults table referenced by the signature (maintainer judge); D's descriptor defaults + an explicit-vs-implicit md5 test          |
| 5   | Merge                            | No deep merge: parties, city, contact, tax, terms, bank are values replaced whole; the `payment` section applies key by key by role                                               | A merge pairs one party's VAT ID or BIC with another's name or IBAN                                                                                                  | Sender merged per field (C); "merge when the party has no `name`" (A) → Q9                                                                   |
| 6   | Custom fields precedence         | `custom` has role `document`: the skeleton's `invoice(custom:)` is a preview sample, replaced as a whole by the data's `custom`                                                   | The same no-leak rule as every per-invoice value; constants belong in Typst code                                                                                     | Key-by-key merge over the skeleton's custom (B, C, user judge) → Q3                                                                          |
| 7   | Files                            | `--input invoice-pro-data-file=<path>`, opened by the skeleton's `read` callback: `invoice-data.load(read: p => read(p, encoding: none))`                                         | A package cannot open user paths (0.14 and 0.15); one line; JSON/TOML/YAML by extension; stdin via `/dev/stdin`                                                      | A user key `data` and `json(sys.inputs.data)` (B): every skeleton invents its own key                                                        |
| 8   | Unconsumed input                 | Any `invoice-pro-data*` input that the invoice does not hydrate from → **panic** with the one-line fix                                                                            | Every other design had a silent path that shipped the SAMPLE invoice under strict (user judge)                                                                       | Ignore it                                                                                                                                    |
| 9   | Rows engine                      | C's `hydrate/items.typ` (cascade dict that tracks key presence, replaying loom's derive/ensure/put)                                                                               | The only engine byte-identical on nested and dated bundles, `apply` around the slot and explicit none (engine judge); B, D drift on the inner bundle date, A crashes | B's `rows.typ` (used by B and D)                                                                                                             |
| 10  | Items binding point              | The body of `line-items` is the implicit slot; an optional `#invoice-data.items[..]` marker restricts the slot so static rows survive; at most one marker, asserted               | Zero-mark hydration for every existing invoice; fixed fees still possible; no silent double or missing slot                                                          | Marker required (A, C: a forgotten or doubled marker drops or doubles the data silently); implicit only (B, D: cannot keep a fixed fee) → Q4 |
| 11  | Payment                          | `payment(..)` composite (B's file, one copy) + paid-by-transfer keeps the account (A)                                                                                             | Which payment components exist is data; `dynamic()` cannot bind component parameters; one means per invoice (CII-SR-467/470)                                         | Data-aware `payment-terms`/`bank-details` in place (5 components); A's `hydrate.payment` converter (bank args written twice)                 |
| 12  | Decoder                          | Generic over ONE descriptor table (D); regex pre-validation before every `decimal()`/`datetime()`/constructor; row-level drop; + C's region VAT-rate check                        | Crash-free is a hard requirement (Typst has no try/catch; D 0 aborts vs B 2, A 5, C 8); one source for decoder, schema, docs, roles                                  | Per-key hand-written decoders (A, B, C)                                                                                                      |
| 13  | Encodings                        | Decimal strings, `"19%"`, ISO dates, `{start, end}` periods, UN/ECE unit codes or `{code, display}`, tax `"19%"` or object, `null` ≡ absent, BT-20 text as `payment.terms.text`   | Exact money; bit-exact ratios; one spelling per concept (a second unit spelling crashed typify); generated models dump nulls                                         | Unit names, tax presets, period arrays (A, B, C) → Q10                                                                                       |
| 14  | Line-item shape                  | Tree `items` (item / group / bundle), separate `modifiers` arrays (document, bundle, item) and top-level `prepayments`                                                            | Fewer union members for codegen; placement rules by construction                                                                                                     | One tree with kinds discount/surcharge/prepayment (A, C)                                                                                     |
| 15  | Errors                           | Data problem → class-`data` issue `schema/<JSON Pointer>`; Typst misuse, a foreign format major, an unconsumed input → panic                                                      | Reuses draft/strict/none unchanged; ids are machine-readable                                                                                                         | Panic by default (A) → Q1                                                                                                                    |
| 16  | Namespace                        | `invoice-data` with 10 names: `format`, `input-key`, `file-key`, `load`, `decode`, `check`, `values`, `party`, `items`, `schema`                                                  | Named after the parameter (house rule); `data` would be shadowed by `#let data = json(..)`; no builtin shadowed by `import invoice-data: *`                          | D's 27 names (incl. `text`, `array`, `decimal`); `hydrate` (A, C); `data-format` (B)                                                         |
| 17  | Result                           | `<invoice-pro-result>` (`invoice-pro-result/1`, D's shape) on hydrated invoices or with `--input invoice-pro-result=1`; loaded lazily, never loads the descriptor                 | Always-on loads the descriptor at draw time (4.79 + 2.29 ms traced) and adds a metadata element to every invoice (maintainer judge)                                  | Every invoice (D, user judge) → Q5                                                                                                           |
| 18  | Data-dependent design (Wappen)   | A STATIC theme patch chosen at document level from `invoice-data.values(record)` (`theme.custom.logo(image: ..)`)                                                                 | Keeps `prints-of(theme).page-content` false, so IP-PRINT-03/IP-PERIOD-03 stay active (verified on A); a draw-time wrap sets it true                                  | Draw-time `wrap("logo", ..)` reading ctx (B, C, D): documented as the fallback for rules that need computed values                           |
| 19  | Data-dependent parameters        | Issuer keys: Typst expressions on `values` in the skeleton; document keys: a `derive` hook in 0.7.x                                                                               | Covers "change X by a field value" without an expression language; keeps the 0.7.0 surface small                                                                     | `derive` in 0.7.0 (D, user judge) → Q7                                                                                                       |
| 20  | Speed                            | One bulk motif; pure `compute(rows, env)` → pass 2 memo hit; sealed ctx payloads; lazy modules; two loom passes kept                                                              | −44 to −49 % at 300 rows for every bulk engine (same invoice); skipping pass 1 adds only 0–5 % and couples format and skeleton                                       | Single pass with precomputed `global` (rejected by all four)                                                                                 |
| 21  | Schemas and conformance          | Data and result JSON Schemas generated from the descriptor, committed under `src/contract/` with a CI drift check; differential fixtures incl. default model dumps; codegen in CI | "Valid for the schema" must mean "accepted by invoice-pro"; the codegen run found a real defect                                                                      | Generate at release only                                                                                                                     |
| 22  | Versioning                       | `"format": "invoice-pro/1"` or `"invoice-pro/1.<minor>"`, required; SchemaVer; `since` per key; `$id` carries the major only                                                      | Producers state the contract; check-version unaffected                                                                                                               | Optional `format` (B, C)                                                                                                                     |
| 23  | Tier                             | `invoice-data`, `payment`, `invoice(data:, custom:)`: experimental in 0.7.0; the format `invoice-pro/1`: provisional                                                              | Precedent: from-data, zugferd                                                                                                                                        | Provisional from the start → Q19                                                                                                             |

---

## 3. The data format `invoice-pro/1`

### 3.1 Principles

1. **One JSON object = one invoice.** JSON is canonical. TOML and YAML files decode to the same dictionaries (chosen by file extension); TOML dates arrive as native datetimes and are accepted.
2. **Canonical subset of the Typst API.** Keys are the kebab-case names of `invoice()`, the party dictionaries and the components. Where the Typst API has aliases (`street`, `region`, flat `contact-name`/`phone`/`email`, ship-to `location-id`, buyer-level `order-nr`/`po-nr`/…, unit names), the format keeps exactly ONE spelling.
3. **Closed core, named open bags.** Every object is closed (`additionalProperties: false`); an unknown key is a data issue with a did-you-mean hint and, in parties, the e-invoice alias hint (`plz` → "write the post code into `city`"). Openness lives only in `custom` (document, party, item).
4. **Facts, not rules.** No expression language, no `eval`, no theme, locale or layout in the data. Rules are Typst code in the skeleton.
5. **Exact values.** Money and quantities are decimal strings, percentages carry `%`, dates are ISO strings.
6. **Lenient reader, strict writer.** The JSON Schema says what producers must write. The decoder additionally reads, and only these (each a documented `lenient` conformance fixture): JSON `null` (≡ absent), JSON numbers where a decimal is expected (converted exactly through their shortest representation, after the same pattern check), and native TOML dates.

### 3.2 Encodings

| Type       | JSON encoding                                                                                                                                                                                                      | Typst value after decoding                                                                                                                                                                               | Notes                                                                                                                                                                                                            |
| :--------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| text       | `"2026-0042"`                                                                                                                                                                                                      | `str`                                                                                                                                                                                                    | A JSON number is an issue (fix: `"42"`; numbers crash themes, e.g. `sender.vat-id: 123`). A required text must not be empty; an optional `""` is absent.                                                         |
| lines      | `"Muster GmbH"` or `["Muster GmbH", "Einkauf"]`                                                                                                                                                                    | `str` / `array`                                                                                                                                                                                          | `name`, `address`, `legal-info`, `management`                                                                                                                                                                    |
| decimal    | `"120.00"`, `"-5"`, `"0.5"`; pattern `^-?[0-9]{1,20}(\.[0-9]{1,10})?$`                                                                                                                                             | `decimal` (scale kept: `"12.30"` stays 12.30)                                                                                                                                                            | `"12,30"`, `"1e3"` are issues. A JSON number is tolerated: `str(x)` must match the pattern (rejects `1e300`, `1e-30`), then `decimal(str(x))` (exact: 49.90 → 49.9; never the lossy `coercion.to-decimal` path). |
| integer    | `14`                                                                                                                                                                                                               | `int`                                                                                                                                                                                                    | `days`; `"14"` is an issue                                                                                                                                                                                       |
| boolean    | `true`                                                                                                                                                                                                             | `bool`                                                                                                                                                                                                   |                                                                                                                                                                                                                  |
| percent    | `"19%"`, `"2.5%"`, `"9.975%"`; pattern `^[0-9]{1,3}(\.[0-9]{1,6})?%$`                                                                                                                                              | `ratio` = `float(n) / 100 * 100%`                                                                                                                                                                        | Bit-identical with the Typst literal (infer-tax and the VAT groups compare with `==`; `float(n) * 1%` is not exact for 9.975 %).                                                                                 |
| amount     | `"50.00"` (absolute) or `"10%"` (relative)                                                                                                                                                                         | `decimal` / `ratio`                                                                                                                                                                                      | Modifiers and prepayments; never negative (the `kind` gives the sign).                                                                                                                                           |
| date       | `"2026-11-02"`                                                                                                                                                                                                     | `datetime`                                                                                                                                                                                               | Calendar-checked before `datetime()` (`"2026-02-30"` is an issue, not a crash). TOML dates native. A bare string is ALWAYS a date (BT-9), never payment-terms text.                                              |
| period     | a date, or `{"start": "…", "end": "…"}`                                                                                                                                                                            | `datetime` / `(datetime, datetime)`                                                                                                                                                                      | `end ≥ start`. No array form (one spelling).                                                                                                                                                                     |
| tax        | `"19%"` (standard rate S, must be a rate of the locale region) or `{"category": "S"\|"Z"\|"E"\|"AE"\|"K"\|"G"\|"O"\|… (22 UNTDID 5305 codes), "rate"?: "16%", "grounds"?: "…", "code"?: "VATEX-…", "label"?: "…"}` | `"19%"`: the ratio (resolved by the region's `infer-tax`, as `tax: 19%`); object: the category's `tax.*` constructor (`tax.vat`, `tax.exempt`, …) or `tax.new(..)`                                       | `"16%"` in `de` is an issue naming the object form (instead of infer-tax's panic); `"0%"` is an issue (a zero rate needs its category). No string presets (one spelling).                                        |
| unit       | UN/ECE Rec 20 code `"HUR"` (pattern `^[A-Z0-9]{2,3}$`), or `{"code"?: "KWH", "display": "kWh"}`                                                                                                                    | the 18 known codes (H87 SET PR LS HUR DAY MON ANN KGM GRM TNE MTR MTK MMT CMT KMT LTR MTQ): the localized, pluralized `unit.*` function; other codes: `(code, display: code)`; object: `(code, display)` | Any Rec 20 code is accepted (`KWH` must not be rejected); `{display}` alone is a free-text unit printed verbatim, its XML code found by the alias table (IP-UNIT-01/02) as in Typst.                             |
| identifier | `"DE123"` or `{"scheme": "gln"\|"duns"\|"siren"\|"siret"\|"uid-ch"\|"leitweg"\|"register"\|"EM"\|"<4-digit ICD>", "id": "…", "court"?: "…"}`                                                                       | named schemes: the `id.*` constructor (check digits → IP-ID-01); others: `(scheme, id)`                                                                                                                  | `id`, `global-id`, `legal-id`, `electronic-address`, `buyer-reference`, `leitweg-id`                                                                                                                             |
| city       | `"10115 Berlin"` or `{"name": "Berlin", "post-code"?: "10115", "state"?: "…"}`                                                                                                                                     | `str` / dict                                                                                                                                                                                             | A numeric `post-code` is an issue (leading zeros). The structured form gives Wappen rules the post code without parsing.                                                                                         |
| country    | `"DE"` (pattern `^[A-Za-z]{2}$`)                                                                                                                                                                                   | `str`                                                                                                                                                                                                    | `"Germany"` is an issue (it crashed B and C today).                                                                                                                                                              |
| currency   | `"EUR"` (pattern `^[A-Z]{3}$`)                                                                                                                                                                                     | `str`                                                                                                                                                                                                    | `"EURO"` is an issue (it crashed C's core path).                                                                                                                                                                 |
| enum       | `"exclusive"`                                                                                                                                                                                                      | `str`                                                                                                                                                                                                    | did-you-mean on a typo                                                                                                                                                                                           |
| item-id    | `"A-1"` (the seller's id) or `{"seller"?, "buyer"?, "standard"?}`                                                                                                                                                  | `str` / dict                                                                                                                                                                                             | BT-155/156/157                                                                                                                                                                                                   |
| notes      | `"…"` or `["…", {"text": "…", "subject-code": "AAI"}]`                                                                                                                                                             | as `invoice(notes:)`                                                                                                                                                                                     | BT-21/22                                                                                                                                                                                                         |
| custom     | any JSON object                                                                                                                                                                                                    | dictionary (values as decoded; JSON `null` inside a bag stays `none`)                                                                                                                                    | never interpreted, never written into the e-invoice                                                                                                                                                              |

### 3.3 Absent, `null`, empty

- **Absent ≡ `null` ≡ "not given"**, at every level, including the `kind` discriminator (`"kind": null` is an item; D's decoder crashed on it, user judge). Generated models (pydantic `model_dump()`, serde without `skip_serializing_if`) write `null` for every unset field; the conformance suite contains such default dumps (§10).
- For a `document` key, "not given" means the `invoice()` default (the sample is dropped): `none`, `(:)` for `recipient`. For an `issuer` key it means the skeleton's value. Inside line items it means the component's `auto` (the cascade from group, `line-items`, `apply` or `invoice(tax:)`).
- An optional `""` is absent. To clear an issuer list (the skeleton's `notes`) give `[]`.
- v1 cannot express an explicit `none` that cancels a cascaded value inside the items tree (e.g. a child without its group's `unit`): write the group without the cascaded key instead (→ Q12).
- `null` as an array element is an issue (`/items/3`), never silently skipped.

### 3.4 Document (top level): every key

Role: `doc` = data only (the skeleton's value is a sample), `iss` = skeleton unless the data gives it (as a whole), `→` = binding point in the body, `meta` = checked, then dropped. **R** = required by the JSON Schema (`required` at root: `format`, `invoice-nr`, `date`, `recipient`, `items`).

| Key                      | Type                                                                                                                                      | R   | Role            | Absent →                                                                             | Feeds                                                            | EN 16931                |
| :----------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- | :-- | :-------------- | :----------------------------------------------------------------------------------- | :--------------------------------------------------------------- | :---------------------- |
| `$schema`                | text                                                                                                                                      |     | meta            | –                                                                                    | not read (editor hint)                                           |                         |
| `format`                 | `"invoice-pro/1"` / `"invoice-pro/1.<minor>"`                                                                                             | R   | meta            | issue `schema/format`                                                                | version check; another major panics                              |                         |
| `invoice-nr`             | text                                                                                                                                      | R   | doc             | `none` → check-data "missing" (inline marker ‹fehlt: Rechnungsnummer›)               | `invoice(invoice-nr:)`                                           | BT-1                    |
| `date`                   | date                                                                                                                                      | R   | doc             | issue `schema/date` (the value falls back to today; pin with `--creation-timestamp`) | `invoice(date:)`                                                 | BT-2                    |
| `document-type`          | `"invoice"`, `"credit-note"`, `"corrected"`, `"prepayment"`, `"self-billed"`, `"self-billed-credit-note"` or a UNTDID 1001 code (`"326"`) |     | iss (Q2)        | skeleton (`auto` = 380)                                                              | `invoice(document-type:)`                                        | BT-3                    |
| `currency`               | currency                                                                                                                                  |     | iss             | skeleton (`auto` = the locale's)                                                     | `invoice(currency:)`                                             | BT-5                    |
| `due-date`               | date                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(due-date:)` (a datetime only)                           | BT-9                    |
| `service-period`         | period                                                                                                                                    |     | doc             | `none`                                                                               | `invoice(service-period:)`                                       | BG-14 (BT-73/74), BT-72 |
| `subject`                | text                                                                                                                                      |     | iss             | skeleton (`auto`)                                                                    | `invoice(subject:)`                                              | (title)                 |
| `notes`                  | notes                                                                                                                                     |     | iss             | skeleton; `[]` clears                                                                | `invoice(notes:)`                                                | BG-1 (BT-21/22)         |
| `customer-nr`            | text                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(customer-nr:)`                                          | printed only            |
| `order-nr`               | text                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(order-nr:)`                                             | BT-13                   |
| `order-date`             | date                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(order-date:)` (a datetime: printed as a localized date) | printed only            |
| `project`                | text                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(project:)`                                              | BT-11                   |
| `contract-nr`            | text                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(contract-nr:)`                                          | BT-12                   |
| `quote-nr`               | text                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(quote-nr:)`                                             | printed only            |
| `delivery-note-nr`       | text                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(delivery-note-nr:)`                                     | BT-16                   |
| `preceding-invoice-nr`   | text                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(preceding-invoice-nr:)`                                 | BT-25                   |
| `preceding-invoice-date` | date                                                                                                                                      |     | doc             | `none`                                                                               | `invoice(preceding-invoice-date:)`                               | BT-26                   |
| `payment-reference`      | text (≤ 140)                                                                                                                              |     | doc             | `none` (= the invoice number)                                                        | `invoice(payment-reference:)`                                    | BT-83                   |
| `sender`                 | seller (§3.5)                                                                                                                             |     | iss             | the skeleton's letterhead                                                            | `invoice(sender:)`, replaced whole                               | BG-4                    |
| `recipient`              | buyer (§3.5)                                                                                                                              | R   | doc             | `(:)` → check-data "missing" (name, address)                                         | `invoice(recipient:)`                                            | BG-7                    |
| `delivery-address`       | ship-to (§3.5)                                                                                                                            |     | doc             | `none`                                                                               | `invoice(delivery-address:)`                                     | BG-13, BG-15            |
| `payee`                  | payee (§3.5)                                                                                                                              |     | iss             | skeleton                                                                             | `invoice(payee:)`                                                | BG-10                   |
| `tax`                    | tax                                                                                                                                       |     | iss             | skeleton (`auto`)                                                                    | `invoice(tax:)` (the default tax of the lines)                   | BG-23 (BT-118/119)      |
| `tax-mode`               | `"exclusive"` \| `"inclusive"`                                                                                                            |     | iss             | skeleton                                                                             | `invoice(tax-mode:)`                                             |                         |
| `tax-exempt-small-biz`   | boolean (excludes `tax`)                                                                                                                  |     | iss             | skeleton                                                                             | `invoice(tax-exempt-small-biz:)`                                 | BT-118 = E, BT-120      |
| `items`                  | row[] (§3.6)                                                                                                                              | R   | → items slot    | the sample is dropped; empty → check-data "no line items"                            | ONE bulk motif emitting `item`/`group`/`bundle` frames           | BG-25                   |
| `modifiers`              | modifier[] (§3.6)                                                                                                                         |     | → items slot    | none                                                                                 | document-level `discount`/`surcharge` frames                     | BG-20, BG-21            |
| `prepayments`            | prepayment[] (§3.6)                                                                                                                       |     | → items slot    | none                                                                                 | `prepayment` frames                                              | BT-113                  |
| `payment`                | payment (§3.7)                                                                                                                            |     | → `payment(..)` | the skeleton's block (issuer settings kept, document details dropped)                | `payment(..)` → `payment-terms`/`bank-details`/`direct-debit`/…  | BG-16…19                |
| `custom`                 | custom                                                                                                                                    |     | doc (Q3)        | `none` (the skeleton's sample custom is dropped)                                     | `invoice(custom:)` → `ctx.custom`                                |                         |

Not in the format (design/config; skeleton only): `theme`, `locale`, `references` (header layout; its values come from the keys above), `zugferd`, `zugferd-errors`, `validation`, `tax-nr` (deprecated), component layout options (`show-column`, `show-total`, `show-information`, `qr-code`, `show-reference`, `account-holder-text`), the signature.

### 3.5 Parties

All parties: `name` (lines, **R**), `address` (lines), `city` (city), `country` (country), `extra` (object label → text, printed only, order kept), `custom` (open bag, print-only, never written into the e-invoice).

| Party (`invoice()` key)      | Further keys (type → EN 16931)                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| seller (`sender`)            | name BT-27, address BT-35/36, city BT-37/38 (state BT-39), country BT-40; `trading-name` text BT-28; `id`, `global-id` identifier BT-29; `legal-id` identifier BT-30; `vat-id` text BT-31; `tax-nr` text BT-32; `legal-info` lines BT-33; `electronic-address` identifier BT-34; `contact` `{name, phone, email}` BG-6 (BT-41/42/43); `tax-representative` `{name R, address, city, country, vat-id R}` BG-11 (BT-62/63); `register`, `management` (printed only) |
| buyer (`recipient`)          | name BT-44, address BT-50/51, city BT-52/53 (state BT-54), country BT-55; `trading-name` BT-45; `id`, `global-id` BT-46; `legal-id` BT-47; `vat-id` BT-48; `electronic-address` BT-49; `contact` BG-9 (BT-56/57/58); `buyer-reference` **or** `leitweg-id` identifier BT-10 (check digits verified; the schema forbids both); `tax-nr` (printed only)                                                                                                             |
| ship-to (`delivery-address`) | name BT-70, address BT-75/76, city BT-77/78, country BT-80; `id`, `global-id` BT-71                                                                                                                                                                                                                                                                                                                                                                               |
| payee (`payee`)              | `name` R BT-59, `id`, `global-id` BT-60, `legal-id` BT-61 (no address keys, no `extra`)                                                                                                                                                                                                                                                                                                                                                                           |

These sets mirror `party-keys` of `src/zugferd/model.typ:342-407` minus aliases; a pin test keeps them equal. `custom` becomes a reserved print-only key in that table (§9 L13), so `ctx.recipient.custom` / `view.recipient.custom` reach theme parts without IP-KEY-01 warnings (verified on B and D). Party custom travels unsealed in ctx: keep it small (documented limit; the theming research measured 2000 unsealed entries ≈ 2.4× slower); large payloads belong in the document `custom`, which is sealed.

### 3.6 Line items

`items` is the print-ordered tree that mirrors the body of `line-items`. A row's `kind` is `"item"` (default, also when absent or `null`), `"group"` or `"bundle"`. The bulk motif emits, in this order, the frames of `items`, then `modifiers`, then `prepayments`: exactly what a hand-written body in that order produces.

**item** → `item(name, ..)`

| Key             | Type        | Absent →                                              | Feeds `item(..)`                                                   | EN 16931           |
| :-------------- | :---------- | :---------------------------------------------------- | :----------------------------------------------------------------- | :----------------- |
| `kind`          | `"item"`    | item                                                  | –                                                                  |                    |
| `name`          | text, **R** | row dropped + issue                                   | `name`                                                             | BT-153             |
| `description`   | text        | `auto` (cascade)                                      | `description`                                                      | BT-154             |
| `quantity`      | decimal     | `auto` (cascade, else 1)                              | `quantity`                                                         | BT-129             |
| `base-quantity` | decimal > 0 | `auto` (1); `≤ 0` is an issue                         | `base-quantity`                                                    | BT-149             |
| `unit`          | unit        | `auto` (cascade)                                      | `unit`                                                             | BT-130             |
| `price`         | decimal     | exactly one of `price`/`total`, else dropped          | `price` (net, or gross with inclusive)                             | BT-146             |
| `total`         | decimal     |                                                       | `total`                                                            | BT-131             |
| `date`          | period      | `auto` (cascade)                                      | `date`                                                             | BG-26 (BT-134/135) |
| `tax`           | tax         | `auto` (cascade, `line-items(tax:)`, `invoice(tax:)`) | `tax`                                                              | BG-30 (BT-151/152) |
| `input-gross`   | boolean     | `auto`                                                | `input-gross`                                                      |                    |
| `item-id`       | item-id     | `auto`                                                | `item-id`                                                          | BT-155/156/157     |
| `reference`     | text        | `auto`                                                | `reference`                                                        | BT-133             |
| `note`          | text        | `auto`                                                | `note`                                                             | BT-127             |
| `origin`        | country     | `auto`                                                | `origin`                                                           | BT-159             |
| `modifiers`     | modifier[]  | none                                                  | `modifier` (item discounts/surcharges)                             | BG-27/28           |
| `custom`        | custom      | none                                                  | the item signal → `view.items[i].custom`, `view.entries[j].custom` |                    |

**group** → `group(name, ..)[..]`: `kind: "group"` R, `name` R, `description`, `show-subtotal` (boolean), cascades `tax`, `input-gross`, `date`, `unit` to its rows exactly like `group(..)`; `items` R (item | group | bundle). No `modifiers` (as in Typst: put them on the items).

**bundle** → `bundle(name, ..)[..]`: `kind: "bundle"` R, `name` R, `description` (absent = the automatic description from its items, as `bundle()`), `quantity`, `base-quantity`, `unit`, `date`, `input-gross`, `tax`, `item-id`, `reference`; `items` R (item | bundle); `modifiers` (bundle-level discounts/surcharges). One printed line per VAT rate, as `bundle()`.

**modifier** (in `modifiers` at document, bundle or item level) → `discount(..)`/`surcharge(..)`: `kind` R (`"discount"` | `"surcharge"`), `name` R (BT-97/104 reason), `amount` R (amount; BT-92/99, a percentage BT-94/101), `label`, `description`, `tax` (pins the modifier to one VAT category; absent = split over the VAT groups), `input-gross`.

**prepayment** (in top-level `prepayments`) → `prepayment(amount, ..)`: `amount` R (amount, `"30%"` relative; BT-113), `name`, `label`, `date` (date), `reference`, `description`, `method`.

**Rules checked by the decoder** (they replace the loom guards, which do not run for data rows):

- nesting of groups and bundles at most **8** levels (`collect-signals(depth: 10)` in `calculate-modifier` silently drops deeper items from the totals; D printed a depth-13 item that was missing from the totals);
- a document or bundle modifier without a pinned `tax` needs at least one valid taxed row in its scope, after invalid rows were dropped (all four prototypes crashed on "modifier has no items to take its VAT category from");
- exactly one of `price`/`total`; `base-quantity > 0`;
- a row that lacks what it needs is dropped as a whole and reported; a valid row never depends on an invalid sibling; never more than the offending row is dropped (A's issue mode emptied the whole invoice).

### 3.7 Payment (`payment`)

```json
"payment": {
  "terms": { "days": 14, "discount": [{ "days": 7, "percent": "2%", "basis": "100.00" }] },
  "method": "direct-debit",
  "bank": { "name": "Muster GmbH", "bank": "Musterbank", "iban": "DE75512108001245126199", "bic": "SOLADEST600" },
  "creditor-id": "DE98ZZZ09999999999",
  "direct-debit": { "mandate": "MND-2025-0815", "debtor-iban": "DE02120300000000202051" }
}
```

| Key            | Type                                                                                                                             | Role | Absent →                                                               | Feeds                                                                                  | EN 16931                          |
| :------------- | :------------------------------------------------------------------------------------------------------------------------------- | :--- | :--------------------------------------------------------------------- | :------------------------------------------------------------------------------------- | :-------------------------------- |
| `terms`        | `{days? (integer ≥ 0) \| date? (date) \| text? (text), discount?: [{days R, percent R, basis?}]}`; at most one of days/date/text | iss  | the skeleton's `payment(terms:)`                                       | `payment-terms(days:)`, `(date: <datetime>)`, `(date: <text>)` for `text`, `discount:` | BT-20 (text, Skonto), BT-9 (date) |
| `method`       | `"transfer"` \| `"direct-debit"` \| `"card"` \| `"paid"`                                                                         | iss  | the method whose details are given, else the skeleton's, else transfer | which components `payment(..)` writes                                                  | BT-81                             |
| `bank`         | `{iban R, bic?, bank?, name?}`                                                                                                   | iss  | the skeleton's account (replaced whole)                                | `bank-details(..)`                                                                     | BG-17 (BT-84/85/86)               |
| `creditor-id`  | text                                                                                                                             | iss  | skeleton                                                               | `direct-debit(creditor-id:)`                                                           | BT-90                             |
| `direct-debit` | `{mandate R, debtor-iban?}`                                                                                                      | doc  | dropped (a sample mandate never survives)                              | `direct-debit(mandate:, debtor-iban:)`                                                 | BG-19 (BT-89, BT-91)              |
| `card`         | `{last4 R (4–6 digits, text), holder?, kind?: "credit" \| "debit"}`                                                              | doc  | dropped                                                                | `card-payment(..)`                                                                     | BG-18 (BT-87/88)                  |
| `paid`         | `{method?: "cash" \| "cheque" \| "online" \| "transfer" \| "card" \| "direct-debit", date?}`                                     | doc  | dropped                                                                | `paid(method:, date:)`                                                                 | BT-81, BT-113                     |

Rules (schema and decoder): at most one of `direct-debit`/`card`/`paid`; never `paid` with `terms`; details without `method` select that method; a `method` whose required details are missing (no mandate, no last4) is a data issue and the component is left out. `payment.terms.text` is the ONLY way to write free-text payment terms (BT-20), which removes the Typst API's trap that a string `due-date` is terms text.

### 3.8 Custom fields

| Level    | Where in the data                                                              | Where the skeleton reads it                                                                                                                                      | Stored                                                  |
| :------- | :----------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------ |
| document | `custom`                                                                       | eval time: `invoice-data.values(record).custom`; theme parts/wraps: `ctx.custom.x`; body: `info.get("custom", "x", default: ..)`, `dynamic(ctx => ctx.custom.x)` | `ctx.custom`, sealed in `metadata` (any size costs ≈ 0) |
| party    | `sender.custom`, `recipient.custom`, `delivery-address.custom`, `payee.custom` | `ctx.recipient.custom`, `view.recipient.custom`, `info.get("recipient", "custom", "x")`, eval time via `values`                                                  | the normalised party (unsealed: keep small)             |
| item     | `items[..].custom` (any depth)                                                 | `view.items[i].custom`, `view.entries[j].custom` in table parts, wraps and hooks                                                                                 | the item signal                                         |

v1 bags are open and untyped. Declared, typed, schema-exported fields (D's `extensions:`) are a 0.7.x follow-up (Q7).

### 3.9 Versioning

- `format` is required: `"invoice-pro/1"` (= minor 0) or `"invoice-pro/1.<minor>"` (the minor the data needs).
- SchemaVer: a new optional key = new minor; a rename, a removal or a changed meaning = new major. Closed objects keep additions additive.
- Data with a newer minor: an unknown key's message says "the data is written for invoice-pro/1.2; this invoice-pro reads invoice-pro/1.0: update invoice-pro, or leave the key out" (verified on D).
- Another major: `invoice()` panics ("invoice data is in format "invoice-pro/2"; this invoice-pro reads invoice-pro/1 only …", verified on D); `invoice-data.check` reports it as `schema/format`.
- Every key records `since` (`x-invoice-pro-since` in the JSON Schema). The `$id` carries the format major only (`…/schema/invoice-pro/1/invoice.schema.json`), not the package version, so `scripts/check-version` is unaffected.

### 3.10 Complete example (`data/2026-0042.json`)

The recipient's structured post code `80331` drives the Wappen rule of the skeleton (§4.7); the custom field `wappen` overrides the rule with a more specific coat of arms. Custom fields appear at all three levels.

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

What hydrating the skeleton of §4.7 with this file gives (behaviour by the rules above; the totals are not quoted because this exact file has not been compiled yet, see the prototype plan): "Rechnung 2026-0042", the Munich arms (override) instead of the Bavarian arms the post code would choose, the sample recipient and sample rows gone, the letterhead, the creditor ID and the account from the skeleton (the account is not printed for a direct debit), the data's terms (14 days, 2 % within 7 days) in place of the skeleton's terms as a whole, "Tarif: Gewerbe M", the direct-debit sentence without the transfer account and QR code (CII-SR-467), EN 16931 XML attached.

---

## 4. The Typst API

### 4.1 `invoice()`: two new parameters

Placed after `validation`, before `body` (callers use names, so the position is invisible).

```typst
/// Fields of your own, which invoice-pro does not interpret: theme parts
/// read them as `ctx.custom`, the body as `info.get("custom", ..)`. A preview
/// sample: a hydrated invoice takes its custom fields from the data alone.
/// -> none | dictionary
custom: none,
/// The data of the invoice (format "invoice-pro/1"), to hydrate this call as
/// a skeleton. What identifies one invoice (number, dates, recipient,
/// delivery address, references, line items, the details of a direct debit,
/// card or paid invoice, custom fields) then comes from the data alone: the
/// skeleton's values for it are preview samples. The issuer's settings
/// (sender, payee, currency, subject, document type, notes, tax settings,
/// payment terms, method and bank) keep the skeleton's value unless the data
/// gives them, as a whole. Design never comes from data. Problems in the
/// data are `data` issues (see `validation`).
///
/// `auto`: the JSON of `--input invoice-pro-data` if it is given, else the
/// invoice is not hydrated. Also: a record of `invoice-data.load(..)` or
/// `invoice-data.decode(..)`, a dictionary (`json(..)`, `toml(..)`,
/// `yaml(..)`), JSON as bytes or text, or (Typst 0.15) a `path`.
/// -> auto | none | dictionary | bytes | str | content
data: auto,
```

### 4.2 Hydration inside `invoice()`: re-entry, roles, merge rules

**Algorithm** (the hydrated branch is a lazy import; the non-hydrated path only looks up two `sys.inputs` keys):

1. `data` is the internal _applied marker_ (sealed `metadata((kind: "invoice-pro-applied", ..))`) → this is the second call: go to 6.
2. Resolve the source (`resolve-data(data, inputs: sys.inputs)`, injectable for tests):
   - `auto`: `invoice-pro-data` given → decode it (JSON text, or a dictionary from an embedder); `invoice-pro-data-file` given → **panic** with the fix ("add `data: invoice-data.load(read: p => read(p, encoding: none))`"); both given → panic; none → not hydrated.
   - `none`: an `invoice-pro-data*` input given → panic ("the CLI hands over data, but `data: none` …"); else not hydrated.
   - a record (`invoice-data.load/decode`): use it; any present `invoice-pro-data*` key that the record did not read → panic.
   - dictionary / bytes / str / path: an `invoice-pro-data*` input is also given → panic (two sources); a `str` that does not start with `{` → panic ("a string is JSON text, not a path: a package cannot open your files …").
3. Not hydrated → the 0.6.0 path, unchanged (verified: template md5 identical, §4.2 evidence).
4. Hydrated: decode (if not yet a record; memoized), then the region-dependent checks with `locale`'s region (VAT rates of `"19%"`-style taxes); collect the issues; a record from another format major panics.
5. Build the effective arguments by role and **re-enter**: `return invoice(..effective, data: <applied marker>, body)`.
   - pass-through (design): `theme`, `locale`, `references`, `zugferd`, `zugferd-errors`, `validation`, `tax-nr`;
   - `issuer` keys: `data.at(k, default: <the skeleton's value>)`;
   - `document` keys and `custom`: inserted only when the data gives them; **absent keys are left out, so the signature's own defaults apply** — no copied defaults table;
   - the marker carries the data issues, the sealed body sections (`items`, `modifiers`, `prepayments`, `payment`) and the record's metadata (format, origin) for the result.
6. Second call: the existing type checks and normalisation run on the effective values; the marker's issues are appended next to `eval-theme.issues + check-data(..)` (invoice.typ:547); `hydration: metadata(sections)` and `custom: metadata(custom)` join the weave inputs only when given (sealed; pattern of invoice.typ:598-617).

**Evidence** (`<session>/exp/synth/`, +24 lines in `src/invoice.typ` of a repo copy, both compilers): hydrated with a dictionary == the hand-written twin (md5 `f556eb021f41` on 0.15.1, `bbc9ad6884ea` on 0.14.2); the same data without `invoice-nr` → "ENTWURF · 1 Problem · keine E-Rechnung", "Rechnung ‹fehlt: Rechnungsnummer›", 0 embedded files, and under strict the panic "invoice::invoice-nr is missing"; an injected class-`data` issue → draft report, 0 embedded files; a sample date 2020-01-01 dropped → today (01.01.2026 with `--creation-timestamp 1767225600`); the template md5 unchanged (`ba5d9a49b5de` / `c7e98da669bc`, equal to pristine).

**The rules** (layers, lowest first: `invoice()` defaults < skeleton arguments < data):

| #   | Rule                                                                                                                                                                                                           | Applies to                                                                                |
| :-- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------- |
| R1  | **Design is never data.** The format has no key for it.                                                                                                                                                        | theme, locale, references, zugferd, zugferd-errors, validation, layout options, body text |
| R2  | **Document keys come from the data alone.** Absent → the signature's default (re-entry). Missing required data is reported by check-data and the decoder.                                                      | role `document` (§3.4), `custom`                                                          |
| R3  | **Issuer keys keep the skeleton's value unless the data gives the key**, which then replaces it as a whole.                                                                                                    | role `issuer`                                                                             |
| R4  | **The payment section applies key by key** by the roles of §3.7.                                                                                                                                               | `payment.*`                                                                               |
| R5  | **The items slot is replaced, never appended.** When hydrating, the sample at the binding point is dropped; `items` + `modifiers` + `prepayments` take its place. Static rows outside an explicit marker stay. | binding point (§4.5)                                                                      |
| R6  | **No deep merge.** Parties, `city`, `contact`, tax objects, `terms`, `bank` and `custom` are values.                                                                                                           | everywhere                                                                                |
| R7  | **One source.** An `invoice-pro-data*` input and an explicit non-record `data:` value together panic; an input nobody consumed panics.                                                                         | `data`, `--input`                                                                         |
| R8  | **`null` ≡ absent** (§3.3).                                                                                                                                                                                    | everywhere                                                                                |

**Guard against drift of the role table.** A tools test (`tools/contract/signature.py`, new) parses the `invoice()` signature and fails unless every parameter is classified in the descriptor (document, issuer, pass-through, data, custom). Typst cannot introspect parameter names, so the check lives in tools, like `bt_disposition.py`.

### 4.3 The `invoice-data` namespace (`src/public/invoice-data.typ`, lazy facade)

Every function imports its module inside its body; the facade costs 0.04–0.14 ms of the root import (measured on A and C), so the 12 ms import budget is not touched. `import invoice-data: *` shadows no Typst builtin.

```typst
/// The invoice data format this version reads: `"invoice-pro/1"`.
/// -> str
#let format = "invoice-pro/1"

/// The `--input` key that carries the data of one invoice as JSON text.
/// -> str
#let input-key = "invoice-pro-data"

/// The `--input` key that names a data file (JSON, TOML or YAML), opened by the
/// skeleton's `read` callback (see `load`).
/// -> str
#let file-key = "invoice-pro-data-file"

/// The record of the data the CLI hands over, for `invoice(data: ..)`:
/// the JSON text of `--input invoice-pro-data` (or a dictionary an embedder
/// passes), or the file named by `--input invoice-pro-data-file`, opened with
/// `read`. A package cannot open your files: pass `p => read(p, encoding: none)`,
/// written in your file; a relative path resolves against that file, `/…`
/// against the project root, `/dev/stdin` reads stdin (with `--root /`). The
/// file extension picks the decoder (`.json`, `.toml`, `.yaml`, `.yml`; a UTF-8
/// BOM is tolerated). `none` without input: the skeleton renders its samples.
/// -> none | content
#let load(
  /// The skeleton's reader, `p => read(p, encoding: none)`. Without it, a given
  /// `--input invoice-pro-data-file` panics with this fix.
  /// -> none | function
  read: none,
  /// The CLI inputs; injectable for tests (tytanic cannot pass `--input`).
  /// -> dictionary
  inputs: sys.inputs,
) = {
  /* … */
}

/// Decodes and validates data without rendering: a record for `invoice(data:)`,
/// `values` and `check`. Never panics on bad data (problems become issues
/// with JSON Pointers); `region` adds the region checks invoice() makes with its
/// locale (e.g. `"16%"` is no VAT rate of `"de"`).
/// -> content
#let decode(
  /// A dictionary (`json(..)`, `toml(..)`, `yaml(..)`), JSON as bytes or text,
  /// or (Typst 0.15) a `path`.
  /// -> dictionary | bytes | str
  data,
  /// -> none | str
  region: none,
) = {
  /* … */
}

/// A JSON-friendly validation report, layout-free (CI, phase-2 bindings):
/// `(format: "invoice-pro-check/1", valid: bool,
///   issues: ((id, path, key, message, fix), ..))`.
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
/// functions, tax dictionaries, `id.*` values, custom bags as given): for design
/// decisions in the skeleton at evaluation time. `none` for `none`.
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
/// stay on every invoice (a fixed fee). At most one per invoice, as a direct
/// child of `line-items`. Without a marker, the whole body of `line-items` is
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

The record is a sealed `metadata((kind: "invoice-pro-record", format, origin, values, issues, fatal))` value: opaque in the loom ctx (hashed once), unmistakable for raw data, layout-free.

### 4.4 `payment(..)`: the payment binding point (`src/components/payment.typ`)

```typst
/// The payment block of an invoice: how the recipient pays (credit transfer,
/// SEPA direct debit, payment card, or already paid) and the terms. It writes
/// `payment-terms`, `bank-details`, `direct-debit`, `card-payment` or `paid` as
/// these arguments call for; without data its output equals writing those
/// components by hand. A hydrated invoice's `payment` section applies key by
/// key: `terms`, `method`, `bank` and `creditor-id` keep these values unless
/// the data gives them; `direct-debit`, `card` and `paid` come from the data.
/// -> content
#let payment(
  /// The arguments of `payment-terms` (`days`, `date`, `discount`); not
  /// written for a paid invoice.
  /// -> none | dictionary
  terms: none,
  /// `auto`: the method whose details are given, else a transfer.
  /// -> auto | "transfer" | "direct-debit" | "card" | "paid"
  method: auto,
  /// The account, the arguments of `bank-details` (`name`, `bank`, `iban`,
  /// `bic`, `reference`, `text`, `payment-amount`). Written for a transfer and
  /// for an invoice paid by transfer only: an invoice states one payment means.
  /// -> none | dictionary
  bank: none,
  /// The sender's SEPA creditor identifier (BT-90), for a direct debit.
  /// -> none | str
  creditor-id: none,
  /// `(mandate: .., debtor-iban: ..)` of one invoice.
  /// -> none | dictionary
  direct-debit: none,
  /// `(last4: .., holder: .., kind: "credit" | "debit")` of one invoice.
  /// -> none | dictionary
  card: none,
  /// `(method: .., date: ..)` of an invoice that is already paid.
  /// -> none | dictionary
  paid: none,
  /// Layout of `bank-details` (never data).
  /// -> bool
  show-reference: true,
  /// Layout of `bank-details` (never data).
  /// -> dictionary
  qr-code: (:),
) = {
  /* … */
}
```

Emission by effective method: `transfer` → `payment-terms` (if terms) + `bank-details`; `direct-debit` → `payment-terms` + `direct-debit(creditor-id, mandate, debtor-iban)`, no account (CII-SR-467, verified on B and C); `card` → `payment-terms` + `card-payment`, no account; `paid` → `paid` only (no terms, root forbids paid + terms), plus `bank-details` when `paid.method` is `"transfer"` (the e-invoice needs the account, CII-SR-470; verified on A as BT-81 58 with the account). Mechanism: B's file (a raw motif that builds the components in measure and weaves them by a nested `loom.core.intertwine`, precedent `eval-content`), with A's paid-by-transfer rule added; D's fork is dropped.

### 4.5 Binding points and coverage

- **Items.** The binding point is the explicit `invoice-data.items[..]` marker if the document has one; otherwise the whole body of `line-items` (wrapped by a private `_items-slot` motif, B/D mechanism: without data it passes the children through, byte-identical on 53/53 integration tests and the template). With data, the slot's measure emits `compute(rows, env-of(ctx))` from C's engine; the sample children are discarded (implicit slot: they were woven, ≈ 2.4 ms per sample row and pass, noise for a few samples) or never traversed (marker: the sample is held in the motif's closure, C mechanism).
- **Payment.** The `payment(..)` block.
- **Custom.** Always bound (`ctx.custom`).
- **Assertions** (root measure; skeleton misuse → panic at every validation level, with or without data): at most one marker; a marker must be a direct child of `line-items`.
- **Coverage issues** (class `data`, only when hydrated): data `items`/`modifiers`/`prepayments` but no `line-items` → `schema/items` ("the skeleton has no `line-items` …"); data `payment` but no `payment(..)` → `schema/payment` ("replace `payment-terms`/`bank-details` by `payment(terms: .., bank: ..)`"). Data is never dropped silently.

### 4.6 Context contract additions

- `ctx.custom`: the third public ctx key next to `ctx.theme` and `ctx.locale`; sealed in metadata, unwrapped by `unsealed()` (theme parts) and by `dynamic`/`info.get` paths.
- `view.items[i].custom` / `view.entries[j].custom`: per-line custom of data rows (hand-written rows have none until `item(custom:)`, Q20).
- `ctx.<party>.custom`: reserved, print-only party key.
- `ctx.hydration` (sealed): internal; parts must not read it.

### 4.7 The skeleton (previewable alone, hydratable without edits)

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

- **Alone:** "Rechnung MUSTER-0001", the Berlin arms (post code 10115 of the sample), the two sample rows, "Tarif: Grundversorgung", a transfer with QR code, EN 16931 XML.
- **Hydrated** (`--input invoice-pro-data-file=data/2026-0042.json`, or the same JSON inline): see §3.10. No edit of the skeleton.
- **Without the `load` line** the skeleton still hydrates from `--input invoice-pro-data` (zero code); `--input invoice-pro-data-file` then panics with the one-line fix (R7). The static Wappen rule needs `values`, so it needs the line.

A fixed fee next to the data rows (explicit marker):

```typst
#line-items[
  #item("Grundgebühr", price: 9.9) // static: on every invoice
  #invoice-data.items[
    #item("Leerung Restmüll 120 l", quantity: 4, unit: unit.pcs, price: 12.5)
  ]
]
```

The draw-time alternative for rules that need computed values (B, C, D): `theme.custom.wrap("logo", (ctx, view, inner) => ..)` reading `view.recipient.post-code` or `ctx.custom.wappen`. It works on all ten presets, but sets `prints-of(theme).page-content = true`, which turns IP-PRINT-03 and IP-PERIOD-03 into "unknown" (verified on A: classic false, logo patch false, wrap true, custom part true).

---

## 5. CLI conventions

### 5.1 Input keys (all read through functions with an injectable `inputs: sys.inputs`)

| Key                      | Value                                              | Read by                                     | Notes                                                                                                          |
| :----------------------- | :------------------------------------------------- | :------------------------------------------ | :------------------------------------------------------------------------------------------------------------- |
| `invoice-pro-data`       | one invoice as JSON text (embedders: a dictionary) | the package (`invoice(data: auto)`, `load`) | Linux ≤ 128 KiB per argument (70 KB fine, 214 KB failed); Windows ≈ 32 K characters for the whole command line |
| `invoice-pro-data-file`  | a path (JSON/TOML/YAML by extension)               | the skeleton's `read` callback via `load`   | relative to the skeleton, `/…` root-absolute; `/dev/stdin` with `--root /`; any size                           |
| `invoice-pro-result`     | `1`                                                | root                                        | emit `<invoice-pro-result>` on a non-hydrated invoice too (hydrated invoices always emit it)                   |
| `invoice-pro-validation` | `draft` \| `strict` \| `none` (existing)           | `resolve-level`                             | overrides `invoice(validation:)`                                                                               |

### 5.2 One invoice

```sh
# preview: the skeleton's samples
typst compile skeleton.typ

# a file (the canonical way for real use)
typst compile --pdf-standard a-3b skeleton.typ out/2026-0042.pdf \
  --input invoice-pro-data-file=data/2026-0042.json
#   .toml / .yaml / .yml by extension (TOML dates are native)

# inline JSON: zero skeleton code, any invoice-pro skeleton accepts it
typst compile --pdf-standard a-3b skeleton.typ out.pdf \
  --input invoice-pro-data="$(cat data/2026-0042.json)"

# stdin (POSIX): the skeleton's read callback reads /dev/stdin
generate-invoice | typst compile --root / --pdf-standard a-3b /abs/skeleton.typ out.pdf \
  --input invoice-pro-data-file=/dev/stdin

# production: any problem stops with exit code 1; reproducible default date
typst compile --pdf-standard a-3b --creation-timestamp "$SOURCE_DATE_EPOCH" skeleton.typ out.pdf \
  --input invoice-pro-data-file=d.json --input invoice-pro-validation=strict
```

On 0.15 a skeleton may also pass a `path` value made in its own file, e.g. `data: path("data/2026-0042.json")` (verified on A, B, C, D; 0.15 only); `load(read:)` is the portable way. `--pdf-standard a-3b` is needed for the Factur-X/ZUGFeRD attachment.

### 5.3 Batch (one PDF per e-invoice is mandatory)

An e-invoice PDF carries exactly one `factur-x.xml`, so a batch is one compile per invoice. The portable way is parallel processes; a bad file fails alone.

```sh
printf '%s\n' data/*.json | xargs -P 4 -I{} sh -c \
  'typst compile -j 1 --pdf-standard a-3b skeleton.typ "out/$(basename {} .json).pdf" \
     --input invoice-pro-data-file={} --input invoice-pro-validation=strict'
```

Measured (D): 5 files as 4 parallel processes 1979 ms; B: 20 e-invoices on 4 cores ≈ 3.0 s. The 0.15 bundle export (`--features bundle --format bundle`: one compile → one PDF per invoice, each with its own XML, plus `results.json`; D: 3 invoices in 1068 ms) is experimental in Typst and needs the skeleton written as a function of a record; it is a follow-up (Q21), not part of the 0.7.0 API.

### 5.4 Getting results back

```sh
# 0.15: a second compile
typst eval 'query(<invoice-pro-result>).first().value' --in skeleton.typ \
  --input invoice-pro-data-file=d.json
# 0.14 (and 0.15 with a deprecation warning)
typst query skeleton.typ '<invoice-pro-result>' --field value --one \
  --input invoice-pro-data-file=d.json
# every issue of a draft (needs validation: draft)
typst query skeleton.typ '<ip-issue>' --field value --input invoice-pro-data-file=d.json
```

Both cost a second full compile. A pipeline that only needs "deliverable or not" runs strict and checks the exit code (one compile). A single-compile result for draft pipelines (D's `--input invoice-pro-result=attach`, which embeds `invoice-pro-result.json` next to `factur-x.xml` under PDF/A-3b, verified on both compilers and extractable with `pdfdetach`) waits for an external Factur-X/XRechnung validator run (Q6).

### 5.5 Layout-free validation and schemas

```sh
# 0.15: ≈ 165 ms + ≈ 0.4 ms per row (D)
typst eval '{ import "@preview/invoice-pro:<version>": invoice-data; invoice-data.check(json("d.json"), region: "de") }'
# 0.14: a stub on stdin
printf '#import "@preview/invoice-pro:<version>": invoice-data\n#metadata(invoice-data.check(json("d.json")))<r>\n' \
  | typst query --root . - '<r>' --field value --one
# the schemas (≈ 160 ms, no layout)
typst eval '{ import "@preview/invoice-pro:<version>": invoice-data; invoice-data.schema() }' > invoice.schema.json
typst eval '{ import "@preview/invoice-pro:<version>": invoice-data; invoice-data.schema(kind: "result") }' > result.schema.json
```

`typst eval` serializes to JSON by default; decimals in Typst values would serialize as `decimal("1.20")`, which is why the result and the check report contain strings only.

### 5.6 Exit codes and status

| Outcome                                                               | Exit | PDF                                                  | `result.status` | e-invoice                     |
| :-------------------------------------------------------------------- | :--: | :--------------------------------------------------- | :-------------- | :---------------------------- |
| no problem                                                            |  0   | final                                                | `ok`            | `attached`                    |
| data or legal problems, `validation: draft`                           |  0   | draft (badge, markers, report page)                  | `draft`         | `withheld`                    |
| any problem, `strict` (parameter or `--input`)                        |  1   | none                                                 | –               | –                             |
| e-invoice rule errors, `zugferd-errors: "panic"` (default)            |  1   | none                                                 | –               | –                             |
| e-invoice rule errors, `zugferd-errors: "report"`                     |  0   | with report                                          | `ok` / `draft`  | `draft` (`invoice-draft.xml`) |
| unreadable JSON, another format major, Typst misuse, unconsumed input |  1   | none                                                 | –               | –                             |
| `validation: none`                                                    |  0   | as the data allows (invalid values dropped silently) | `unchecked`     | per `zugferd-errors`          |

### 5.7 0.14 vs 0.15

| Concern           | 0.14.2                                                                         | 0.15.1                                              |
| :---------------- | :----------------------------------------------------------------------------- | :-------------------------------------------------- |
| inline JSON       | `json(bytes(sys.inputs.k))` (same code)                                        | same (`json.decode` is removed in 0.15: never used) |
| file              | the skeleton's `read` callback                                                 | same, or a `path` value                             |
| results           | `typst query` (second compile)                                                 | `typst eval` (second compile); `query` deprecated   |
| layout-free check | `typst query -` stub                                                           | `typst eval '{..}'`                                 |
| batch             | processes                                                                      | processes; bundle export (experimental, follow-up)  |
| decoder           | no 0.15-only function (identical crash sets and reports on both, engine judge) | same                                                |

---

## 6. Extensibility

### 6.1 Custom fields at three levels

See §3.8. Document custom is sealed (size costs ≈ 0: unsealed 2500 leaves cost +48 % at 50 and +76 % at 300 lines, sealed ≈ 0, invoice-api research). Party custom is a reserved print-only key (unsealed, keep it small). Item custom rides in the item signal into `view.items`/`view.entries` (verified on A, B, C with the EN 16931 XML unchanged). The skeleton previews custom fields through `invoice(custom: ..)`.

### 6.2 Changes that depend on a field value

"Data = facts, skeleton = rules." No expression language.

| Need                                                     | Mechanism                                                                                               | Runs | E-invoice "printed?" checks        | Verified                                                            |
| :------------------------------------------------------- | :------------------------------------------------------------------------------------------------------ | :--- | :--------------------------------- | :------------------------------------------------------------------ |
| change the design by a value (Wappen by PLZ)             | **static theme patch** from `invoice-data.values(record)` + `invoice-data.party(..)` (§4.7)             | eval | active (page-content false)        | A: 10115 → Berlin, 50667 → neutral, 80331 → Bayern; prints-of false |
| change the design by a computed value (totals, due date) | `theme.custom.wrap`/`part` or a frame function cell reading `ctx`/`view`                                | draw | IP-PRINT-03/IP-PERIOD-03 "unknown" | B, C, D (wrap on all presets)                                       |
| print a value                                            | `info.get("custom", "x", default: ..)`, `dynamic(ctx => ..)`, `view.items[i].custom` in a table part    | draw | –                                  | B, C, D                                                             |
| change an **issuer** parameter by a value                | a Typst expression on `values` in the skeleton (`notes: if .. {..}`, `tax-mode:`, `payment(terms: ..)`) | eval | –                                  | plain Typst (D's `values(record)` drove a static patch)             |
| change a **document** parameter by a value               | `derive: values => values` hook on `load`/`decode` (0.7.x, Q7)                                          | eval | –                                  | D: PLZ 8… → note "Gerichtsstand München." and `custom.region` "BY"  |
| choose design at document level                          | plain Typst on `values` (`theme: if shown.custom.brand == "b" {..}`)                                    | eval | active                             | D                                                                   |

Images chosen by data are opened in the skeleton (closures written there resolve paths against the skeleton, even when the package calls them; verified in the theming research). Map data values to files through a dictionary (§4.7), never by concatenating a data string into a path.

### 6.3 Extending the format itself

A new optional key = one descriptor entry (type, BT, role, binding, since, doc) + a new minor; it appears in the decoder, both schemas and the reference docs at once. A new value type = one constructor + three interpreter branches (decode, export, docs) + conformance fixtures. Custom part names keep the package-prefix rule (`acme/wappen`).

---

## 7. Performance

### 7.1 Which loom (and other) steps are skipped

| #   | Step in today's hand-written invoice                                                                                                                                           | Unified design                                                 | Mechanism                                                                                                                                                           | Output         |
| :-- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------- |
| 1   | N `item`/`group`/`bundle`/`discount`/`surcharge`/`prepayment` motifs, each a scope of ≈ 20 `loom.mutator` ops (≈ 22 µs each, hashing the full ctx): ≈ 2.4 ms per item per pass | **skipped**: ONE raw motif                                     | the slot's measure = `compute(rows, env)` (C's engine) emits the same frames, calling the unchanged `calculate-item-data`, `calculate-modifier`, `calculate-bundle` | byte-identical |
| 2   | loom pass 2 recomputes every scope and measure (`sys.pass` and `global` differ)                                                                                                | **memo hit**                                                   | `compute` takes `(rows, env)` only; `env` = cascade subset + lite locale + style + path, identical in both passes, never `global` or `sys`                          | identical      |
| 3   | per-row hashing of the locale (215 leaves) in unit resolution                                                                                                                  | avoided                                                        | the locale travels sealed into a per-(unit, quantity) memoized helper                                                                                               | identical      |
| 4   | content modifiers on items: one nested `intertwine` per item                                                                                                                   | skipped                                                        | data modifiers are decoded dictionaries                                                                                                                             | identical      |
| 5   | sample rows of the skeleton                                                                                                                                                    | never traversed (marker) / woven and discarded (implicit slot) | closure-held sample (C) / children replaced in the slot's measure (B, D)                                                                                            | –              |
| 6   | parsing strings (decimal, date, percent, unit, tax)                                                                                                                            | once, at evaluation time                                       | the decoder is pure and memoized; the bulk compute does arithmetic only                                                                                             | –              |
| 7   | bulk data in ctx (hashed on every closure call)                                                                                                                                | sealed                                                         | `hydration` and `custom` travel as `metadata(..)`, like the theme                                                                                                   | –              |
| 8   | loading hydration code                                                                                                                                                         | lazy                                                           | `invoice-data.*`, the hydrated branch of `invoice()`, the slot engine and the result import their modules inside the function                                       | –              |
| 9   | `format-item` in line-items measure: `loom.mutator.batch` per entry (≈ 20 ops)                                                                                                 | plain dictionary (separate PR S7a)                             | same keys, same order                                                                                                                                               | byte-identical |
| 10  | layout iteration 2 re-lays out the whole body of a long invoice (iteration 1 guessed one page)                                                                                 | memo hit (separate PR S7b)                                     | exact page-count seed: multi-page margin for iteration 1 only when `items × one body line > paper height` (unique fixed point)                                      | byte-identical |
| –   | loom pass 1 (measure)                                                                                                                                                          | **kept**                                                       | bulk + one pass is within noise of bulk + two passes (b-300 3.01 vs 3.07 s; r-300-zf 4.30 vs 4.41 s); a stale precomputed `global` would be silent                  | –              |
| –   | keep-together `fits()` per entry                                                                                                                                               | kept (paid once with 10)                                       | needs the rendered height (design); a cheaper pre-check is a theme decision (Q15)                                                                                   | –              |

### 7.2 Measured numbers

Same 300-row invoice through all four bulk engines (engine judge, 3-run medians, md5-identical to hand-written):

| Engine                                        | 0.15.1             | 0.14.2    |
| :-------------------------------------------- | :----------------- | :-------- |
| hand-written, 0.6.0                           | 5.29 s             | 6.05 s    |
| A bulk motif                                  | 2.99 s (−44 %)     | −49 %     |
| B bulk motif                                  | 2.96 s (−44 %)     | −48 %     |
| **C bulk motif (the chosen engine)**          | **2.83 s (−47 %)** | **−49 %** |
| D bulk motif                                  | 2.85 s (−46 %)     | −42 %     |
| hand-written, `item()` on C's shared resolver | 3.31 s (−37 %)     | −39 %     |
| C hydrated + exact page seed                  | 2.17 s (−59 %)     | −63 %     |

50 rows (5-run medians, 0.15.1): A −37 %, B −31 %, C −41 %, D −32 %, C shared resolver hand-written −30 %.

C's matrix (`<session>/exp/design-C-performance/proto/bench/wall.json`; B = hand-written on 0.6.0, D = hydrated; medians; all md5-identical incl. XRechnung XML): b-50 1.13 → 0.78 s (−31 %), r-50-zf 1.43 → 0.90 (−37 %), t-50 1.47 → 0.97 (−34 %); b-300 5.74 → 2.82 (−51 %), r-300-zf 7.41 → 4.30 (−42 %), t-300 6.81 → 4.34 (−36 %); b-1000 20.45 → 9.12 (−55 %), r-1000-zf 25.52 → 14.30 (−44 %), t-1000 29.13 → 18.20 (−38 %); 0.14.2 b-300 5.39 → 2.88 (−47 %). At 5 rows the gain is −16/−17 % (b, r) or within noise (t).

Exact page seed (C, `repo-x`, median of 3, md5-identical): hydrated b-300 5.97 → 2.23 s (−63 %), r-300-zf 7.73 → 2.66 (−66 %), t-300 7.01 → 3.09 (−56 %); hand-written with the seed alone −21/−27/−20 %; it does not trigger below ≈ 70 lines, by design.

Traces (0.15.1, b-300): weave 3108 → 462 ms (−85 %); measure pass 1742 → 330 ms; draw pass 1366 → 132 ms; layout 2057 → 1889 ms (iterations 983/991/83 → 956/890/44), with the seed 1224 ms (iteration-2 `fits()` 333 → 1.9 ms). Rows module in the draw pass (pass 2 = memo hit): B 0.5, C 0.7, D 0.5 ms (A 7.2 ms with per-row memo). Weave measure pass by engine: C 372, B 516, A 633, D 737 ms (C's plain-dict `format-item` is the main reason).

Decoder (300 rows, traced): C 26, A 36, B 59, D 77 ms; untraced: A ≈ 85 ms, B 108 ms (0.36 ms/row), D ≈ 100–130 ms (≈ 0.4 ms/row; sealing the descriptor halved it: 606 → 262–293 ms for `check` incl. import). A Unicode `\d{1,27}` regex alone made A's decoder 3.7× slower; ASCII classes are mandatory.

Package import: facade 0.04–0.14 ms (A, C); D 140.7 vs 139.1 ms (median of 11, noise); B's eager code ≈ 0.6 ms traced. Payment block: ≈ 54 ms at 300 rows, of which the EPC QR draw ≈ 40 ms (B).

Expected for the unified design _(target, to be confirmed by the consolidated prototype)_: C's engine with D's descriptor-driven decoder (≈ +50 ms traced against C's decoder at 300 rows) and the implicit slot (≈ 2.4 ms per sample row and pass): −44 % or better at 300 rows on both compilers; −59 % or better with S7a + S7b.

### 7.3 Budgets and gates (tools/perf)

- **Perf gate:** a hydrated 300-row invoice (`kind b`, en16931) must stay ≤ 0.6 × the hand-written one on both compilers; it fails loudly when `env` leaks `sys` or `global` (pass 2 stops being a memo hit and the gain halves).
- **Decoder:** ≤ 0.4 ms per row untraced (≤ 120 ms at 300 rows); specialise the row path if exceeded.
- **Import:** root import delta ≤ 0.2 ms; `src/contract/*`, `src/hydrate/*` and `src/contract/result.typ` added to `LAZY_MODULES` (no benchmark invoice without data may load them).
- **Non-hydrated invoices:** unchanged within noise; template and integration tests md5-identical.

---

## 8. Validation and error model

### 8.1 What becomes what

| Situation                                                                                                         | Becomes                                                                                            | Level-dependent             | Example message                                                                                                                                                              |
| :---------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------- | :-------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Typst misuse (`invoice(data: 42)`, `payment(method: "x")`, two markers, a marker outside `line-items`)            | panic                                                                                              | no                          | ``variable `invoice::data` must be of auto \| none \| dictionary \| bytes \| str (JSON text) \| a record of invoice-data.load/decode, found integer``                        |
| `--input invoice-pro-data-file` without a `read` callback; an input nobody consumed; two sources                  | panic with the one-line fix                                                                        | no                          | ``--input invoice-pro-data-file=… needs one line in the skeleton, because a package cannot open your files: `data: invoice-data.load(read: p => read(p, encoding: none))`.`` |
| JSON that does not parse                                                                                          | Typst's own error (`json()` cannot be caught)                                                      | no                          |                                                                                                                                                                              |
| data in another format major                                                                                      | panic in `invoice()`; issue `schema/format` in `check`                                             | no                          | `invoice data is in format "invoice-pro/2"; this invoice-pro reads invoice-pro/1 only …`                                                                                     |
| type, pattern, enum, unknown key, required, exclusivity, period, nesting, placement, tax-rate problem in the data | class-`data` issue `schema/<JSON Pointer>`, key `schema-<kind>`; the value (or the row) is dropped | yes (draft / strict / none) | ``invoice data `items[0].price`: must be a decimal number written as a string such as "12.30", found "12,30".``                                                              |
| a region-unknown VAT rate                                                                                         | issue `schema/items/1/tax`                                                                         | yes                         | ``invoice data `items[1].tax`: 16% is no VAT rate of region de (19%, 7%); for another rate write {"category": "S", "rate": "16%"}.``                                         |
| a legally required value the legal checks cover (`invoice-nr`, `recipient.name`, address, `items`)                | reported once, by `check-data` (inline marker + § reference)                                       | yes                         | `invoice::invoice-nr is missing; every invoice needs a unique, sequential number (§ 14 Abs. 4 Nr. 4 UStG; EN 16931 BT-1)`                                                    |
| data section without a binding point                                                                              | issue `schema/items` / `schema/payment`                                                            | yes                         | ``the data has a `payment` section, but the skeleton has no `payment(..)` block: replace `payment-terms`/`bank-details` by `payment(terms: .., bank: ..)`.``                 |
| legal and e-invoice rules                                                                                         | unchanged (check-data, IBAN/creditor checks, rules engine)                                         | yes / `zugferd-errors`      |                                                                                                                                                                              |

Levels (unchanged machinery): **draft** → inline markers, badge "ENTWURF · n Probleme · keine E-Rechnung", report page, XML withheld, `status: "draft"`; **strict** → one panic listing every problem (verified with 9–12 problems on B, C, D); **none** → no invoice-pro checks, invalid values dropped silently (never back to the sample), e-invoice rules still follow `zugferd-errors`.

### 8.2 Issue ids, keys and texts

- id `schema/<JSON Pointer>` (`schema/items/0/price`), unique per path so the report dedupes; the result's `issues[].path` holds the pointer, the message shows the dotted path for humans.
- keys: `schema-type`, `schema-enum`, `schema-unknown-key`, `schema-required`, `schema-exactly-one`, `schema-exclusive`, `schema-length`, `schema-period`, `schema-nesting`, `schema-placement`, `schema-tax-zero`, `schema-tax-rate`, `schema-unbound`; English messages in the house style (path, value, allowed set, did-you-mean, fix); `strings.validation.issues.schema-*` in the 6 language files translate them, with an English fallback.
- The report shows these issues with a chip "Daten / Data" (new label) instead of "Pflichtangabe / Required data" (B and C found the mismatch).
- Party keys use the e-invoice alias table (`plz`, `mail`, `ust-id`, …) for hints.

### 8.3 Drop semantics

An invalid value is left out. An object that then lacks what it needs (a line without a price) is left out as a whole, except the objects marked `partial` in the descriptor (the document, parties, contact, bank, payment, terms), whose gaps the legal checks then name. A draft never crashes on bad data; a strict build never ships it.

### 8.4 Crash-freedom (hard requirement)

Typst has no try/catch; one converter panic aborts a whole batch process with an unhelpful message. Rules: every value is regex-checked before `decimal()`, `datetime()`, `id.*`, `tax.*` or `unit.*` see it; every type is checked before a method call (`"string has no method map"` crashed C); `in` is never applied to `none` (crashed C and D); the decoder never calls a function that can panic on a decoded value. Gate: the fault corpus `<session>/judge-engine/scripts/fuzz.py` (38 single-fault documents) plus the new faults found by the judges (base-quantity 0, country "Germany", currency "EURO", a modifier without taxed items, `kind: null`, a pydantic default dump, depth 12, 29-digit and 1e300/1e-30 numbers) must give **0 hard aborts** on both compilers, excluding the deliberate format-major panic.

---

## 9. API change ledger

Kinds: `new-parameter`, `new-export`, `new-cli-input`, `new-label`, `behaviour-change`, `internal-refactor`, `bugfix`, `locale-strings`, `tooling`. ⚠ = not a pure extension; justified in the last column.

| #   | Change                                                                                                                               | File(s)                                                                  | Kind                                                                                       | Justification                                                                                                                                                                                                                                                                                                                                                                         |
| :-- | :----------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------- | :----------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| L1  | `invoice(data: auto)`                                                                                                                | src/invoice.typ                                                          | new-parameter                                                                              | The single entry point; it must sit inside invoice() so check-data, draft markers, strict and XML withholding see the real values (body-only hydration gives false "missing" issues and embeds wrong XML). invoice() rejects unknown arguments today, so no caller can pass `data`.                                                                                                   |
| L2  | `invoice(custom: none)`                                                                                                              | src/invoice.typ                                                          | new-parameter                                                                              | The documented, sealed home of document-level custom fields and their preview samples.                                                                                                                                                                                                                                                                                                |
| L3  | Hydrated branch with re-entry (`resolve-data`, roles, applied marker, issues next to check-data, sealed `hydration`/`custom` inputs) | src/invoice.typ (+≈ 40 lines, the rest lazy in src/contract/hydrate.typ) | internal-refactor                                                                          | No behaviour without data (template md5 verified); no copied defaults.                                                                                                                                                                                                                                                                                                                |
| L4  | Root export `invoice-data` (10 names, §4.3)                                                                                          | src/public/invoice-data.typ (new), src/lib.typ (+1)                      | new-export                                                                                 | The contract's public face, layout-free (CI, phase 2). Not `data` (shadowed by `#let data = json(..)`).                                                                                                                                                                                                                                                                               |
| L5  | Root export `payment(..)` ⚠                                                                                                         | src/components/payment.typ (new), src/lib.typ (+1)                       | new-export                                                                                 | Which payment components exist is data. ⚠ Like every new root name, it replaces a user's `#let payment = ..` written BEFORE `#import "…": *` (a theoretical break; a user variable defined after the import still wins). Accepted for every export since 0.1.                                                                                                                        |
| L6  | Pinned export list gains `invoice-data`, `payment`                                                                                   | tests/theme/exports/test.typ                                             | tooling                                                                                    | The test pins root exports exactly (the only regression difference in C's 313-document run).                                                                                                                                                                                                                                                                                          |
| L7  | `--input invoice-pro-data`, `invoice-pro-data-file`, `invoice-pro-result` ⚠                                                         | src/contract/input.typ (new), src/components/root.typ                    | new-cli-input                                                                              | "One input = one JSON document" for the CLI and phase-2 bindings; `invoice-pro-` prefix and injectable `inputs:` (precedent `invoice-pro-validation`). ⚠ A given `invoice-pro-data*` that is not consumed now panics: the keys carry the package's reserved prefix and do nothing in 0.6.0, so no working document can depend on them; the panic prevents shipping a sample invoice. |
| L8  | Label `<invoice-pro-result>` (`invoice-pro-result/1`)                                                                                | src/contract/result.typ (new, lazy), src/components/root.typ             | new-label                                                                                  | Machine-readable result for pipelines and phase 2; emitted only for hydrated invoices or with `--input invoice-pro-result=1`; invisible (PDF bytes unchanged, verified on B, C, D).                                                                                                                                                                                                   |
| L9  | `_items-slot` wrapper around the `line-items` body; hydrated: the body is replaced by the bulk motif                                 | src/components/line-items.typ (+≈ 25)                                    | behaviour-change (hydrated only)                                                           | Without data the wrapper passes the children through: 53/53 integration tests and the template md5-identical (B, D).                                                                                                                                                                                                                                                                  |
| L10 | Bulk rows engine (C's `items.typ`) and the explicit marker                                                                           | src/contract/rows.typ (new)                                              | internal-refactor                                                                          | Byte-identical to the components (generated equivalence suite, §11).                                                                                                                                                                                                                                                                                                                  |
| L11 | Root: coverage issues `schema/items`, `schema/payment`; payment-block issues; marker assertions; result emission                     | src/components/root.typ (+≈ 50)                                          | behaviour-change (only with data, `payment(..)`, a marker or `--input invoice-pro-result`) | Data is never dropped silently; misplaced markers fail loudly.                                                                                                                                                                                                                                                                                                                        |
| L12 | `unsealed()` and `dynamic` unwrap a sealed `ctx.custom`                                                                              | src/theming/access.typ (+4), src/components/dynamic.typ (+3)             | internal-refactor (+ ctx contract)                                                         | Custom fields travel sealed (≈ 0 cost) yet read as a plain dictionary; `ctx.custom` becomes a documented ctx key.                                                                                                                                                                                                                                                                     |
| L13 | `custom: false` (print-only) in `_address-keys` and `payee` of `party-keys` ⚠                                                       | src/zugferd/model.typ (+3)                                               | behaviour-change                                                                           | ⚠ A party key named `custom` no longer raises the IP-KEY-01 warning. Today such a key is unknown, printed nowhere and written nowhere; the only observable change is one warning less, so nothing a user relies on breaks. It reserves the name for the documented party bag (verified: original warns, B and D do not).                                                             |
| L14 | `view.items[i].custom` / `view.entries[j].custom` for data rows                                                                      | src/contract/rows.typ                                                    | new view key                                                                               | Additive key in the item signal; hand-written rows lack it until `item(custom:)` (Q20).                                                                                                                                                                                                                                                                                               |
| L15 | Regions export their VAT rates (`vat-rates`) next to `infer-tax` ⚠                                                                  | src/locale/region/{de,at,ch,fr,it,es}.typ                                | internal-refactor                                                                          | One source of truth, so a data `"16%"` becomes an issue instead of infer-tax's panic. ⚠ An additive field of the region dictionaries; a user-built region without it skips the pre-check and behaves as `tax: 16%` does today (infer-tax decides).                                                                                                                                   |
| L16 | `strings.validation.issues.schema-*` and the "Daten / Data" chip label in the 6 language files ⚠                                    | src/locale/lang/\*.typ                                                   | locale-strings                                                                             | Localized report texts for the new issue ids. ⚠ A user locale built on `locale.custom` that lacks the keys falls back to English; existing issue texts are unchanged.                                                                                                                                                                                                                |
| L17 | Descriptor, decoder, exporter, hydration, input, result modules; committed `invoice.schema.json`, `result.schema.json`               | src/contract/_.typ (new), src/contract/_.schema.json (new)               | internal-refactor                                                                          | One source of truth; published files must live under src/; a CI drift check compares `schema()` with the committed files (like `bt_disposition.py --update-docs`).                                                                                                                                                                                                                    |
| L18 | Perf gate entry (hydrated 300 rows) and `LAZY_MODULES`                                                                               | tools/perf                                                               | tooling                                                                                    | Guards the memo-hit property and the import budget.                                                                                                                                                                                                                                                                                                                                   |
| L19 | Signature-coverage test, conformance fixtures, fault corpus, codegen job, equivalence generator                                      | tools/contract/ (new), tests/data/ (new), CI workflow                    | tooling                                                                                    | §10, §11.                                                                                                                                                                                                                                                                                                                                                                             |
| L20 | `format-item` builds a plain dictionary instead of `loom.mutator.batch` (separate PR S7a)                                            | src/components/line-items.typ                                            | internal-refactor                                                                          | Byte-identical for hand-written and hydrated invoices in every tested configuration and the repo's 313 test documents (C); 0.1–0.5 s on hydrated invoices.                                                                                                                                                                                                                            |
| L21 | Exact page-count seed for layout iteration 1 (separate PR S7b)                                                                       | src/theming/frame.typ (`invoice-span(k, seed:)`)                         | internal-refactor                                                                          | Removes a full second layout of long invoices; exact by construction (a one-page result is impossible ⇒ unique fixed point); md5-identical on 123 test documents (engine judge) and all benches.                                                                                                                                                                                      |
| L22 | `item()` measures through the shared pure `item-signal` (separate PR S7c) ⚠                                                         | src/components/item.typ, src/logic/line-signal.typ (new)                 | internal-refactor                                                                          | ONE implementation of the item cascade for hand-written and data lines (the real drift cure); hand-written −20 to −37 %. ⚠ The largest internal change to a stable component: signature and output unchanged (123/123 and 31/31 documents md5-identical, re-verified by two judges), but loom scope internals of `item` change.                                                      |
| L23 | `group`/`bundle`/`modifier`/`prepayment` on shared resolvers (separate PR S7d) ⚠                                                    | src/components/\*.typ, src/logic/line-signal.typ                         | internal-refactor                                                                          | Completes L22; same justification and gate.                                                                                                                                                                                                                                                                                                                                           |
| L24 | Fix `collect-signals(depth: 10)` in `calculate-modifier` (separate bugfix PR) ⚠                                                     | src/logic/modifier-applicator.typ:188                                    | bugfix                                                                                     | ⚠ Changes the totals of invoices nested ≥ 10 levels deep, which are silently wrong today (deep items printed but missing from the totals). The data format caps nesting at 8 until this lands; then the cap can rise.                                                                                                                                                                |
| L25 | `modifier(name, amount: "-0.50")` converts its string amount like `discount`/`surcharge` (separate bugfix PR) ⚠                     | src/components/modifier.typ                                              | bugfix                                                                                     | ⚠ A string amount that crashes in `normalize.money` today renders; no working document changes (found by C).                                                                                                                                                                                                                                                                         |
| L26 | Docs: api-reference page `invoice-data`, `payment` page, guide "Hydrate a skeleton", registries, tests/docs                          | docs/docs/\*\*, DOCUMENTATION.md, TESTING.md                             | docs                                                                                       | House obligations (code-block registry, verbatim tests, check-docs-examples skip markers for blocks that read fixtures).                                                                                                                                                                                                                                                              |

Not changed: every existing parameter, default and export; `template/invoice.typ` (it stays a non-hydrated invoice: golden XML and thumbnail untouched); `tools/zugferd/bt-disposition.toml` (the format re-feeds existing inputs; a "data key" column can be generated later).

---

## 10. Phase-2 hooks

1. **Schemas.** `invoice-data.schema()` (data) and `schema(kind: "result")` (result), JSON Schema 2020-12 generated from the descriptor: closed objects, `custom` maps, `kind` discriminators with `const` and `default: "item"` (codegen emits `Literal["item"] = "item"`), `$defs` for decimal/percent/date/period/unit/tax/identifier, root `required` = the legally needed keys, annotations `x-en16931`, `x-invoice-pro-role`, `x-invoice-pro-bind`, `x-invoice-pro-since`. Committed under `src/contract/` with a CI drift check. No `default` annotations copied from `invoice()` (issuer defaults are the skeleton's anyway).
2. **Conformance suite** (`tests/data/conformance/fixtures.json`, D's 51 cases + new): valid, invalid, lenient, and **default model dumps** (pydantic `model_dump()` with every unset field `null`, serde without `skip_serializing_if`). CI runs python-jsonschema against the schema and `invoice-data.check` against the decoder on both compilers and requires agreement (the user judge's pydantic dump would have caught D's `kind: null` crash).
3. **Codegen in CI**: datamodel-codegen (pydantic v2), json-schema-to-typescript, typify (Rust) must generate from both schemas (D: 1097/1032/7812 lines; the first typify run caught the two-spelling unit defect).
4. **Transport contract**: one `--input` key = one JSON document (`invoice-pro-data`); embedders using typst as a library (Rust `Library::with_inputs(Dict)`, typst-py `sys_inputs`) may pass a dictionary; data larger than ≈ 100 KiB goes through `invoice-pro-data-file`. A phase-2 binding is: serialize the model → compile the skeleton → read the exit code and the result.
5. **Result contract** `invoice-pro-result/1`, strings only:

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
       "net": "…",
       "tax": "…",
       "gross": "…",
       "prepaid": "…",
       "due": "…"
     },
     "taxes": [{ "category": "S", "rate": "19%", "basis": "…", "amount": "…" }],
     "lines": 9,
     "issues": [
       {
         "id": "schema/items/0/price",
         "class": "data",
         "path": "/items/0/price",
         "message": "…"
       }
     ],
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

   `status` ∈ `ok` | `draft` | `unchecked`; rates in the input encoding (`"19%"`, not `"0.19"`); `issues[].path` = JSON Pointer for data problems, `null` for legal checks; `e-invoice.status` ∈ `attached` | `withheld` | `draft` | `none`; render-time lint findings are not included (emitted during layout). Its own schema validates it (verified on D).

6. **Golden pairs**: the generated data/hand-written pairs (C's `gen.py` + `eq.sh`) ship as fixtures a binding can replay (md5 per compiler).
7. **Versioning**: the data format (`invoice-pro/1[.minor]`, SchemaVer, `since` per key), the result format (`invoice-pro-result/1`) and the package version (in the result) move independently; a binding targets a format major; `$id` = `…/schema/invoice-pro/1/invoice.schema.json`.
8. **Layout-free primitives**: `check` and `schema` via `typst eval` (≈ 160 ms + 0.4 ms/row) for pre-flight validation without rendering.

---

## 11. Implementation plan

Branch `feature-data-api`, concept at `docs/concepts/data-api/README.md` with a `process/` folder (house convention); a GitHub issue first ("Refs #N"; roadmap item "Data Loading"). Effort in maintainer-days (d), rough.

| Stage                              | Content                                                                                                                                                                                                                                                                                                                              | Effort       | Tests the stage needs                                                                                                                                                                                                                                                                                                                                                                                                            |
| :--------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S0 Concept                         | This document as the concept README, process/ folder, issue, maintainer answers to §13                                                                                                                                                                                                                                               | 1 d          | prettier 3.6.2, typstyle 0.15.1 on all blocks, no versioned imports                                                                                                                                                                                                                                                                                                                                                              |
| S1 Contract core                   | `src/contract/{types,schema,decode,export,input}.typ` (D's descriptor and generic decoder, trimmed to §3, null ≡ absent incl. `kind`, crash-free rules §8.4, unit codes by pattern, `payment.terms.text`), `src/public/invoice-data.typ` (`format`, keys, `load`, `decode`, `check`, `values`, `party`, `schema`), committed schemas | 6 d          | tytanic unit tests with injected `inputs:` (load: inline, file, both, file without read, TOML, YAML, BOM); conformance fixtures incl. model dumps (jsonschema vs `check`, both compilers, byte-identical reports); fault corpus 0 aborts; schema drift check; codegen job; decoder perf ≤ 0.4 ms/row                                                                                                                             |
| S2 invoice() integration           | L1–L3, L7 (resolve-data, R7 panics), L12, L13, L15 (region rates), L16 (strings); applied marker; sealed `hydration`/`custom` inputs                                                                                                                                                                                                 | 4 d          | precedence matrix (every document and issuer key: absent, given, `null`, `""`); sample-leak tests (missing invoice-nr/date/recipient/items → draft markers, XML withheld; strict panics); misuse panics; signature-coverage test; regression 53/53 + template md5 + C's 313-document run; `ctx.custom` via `unsealed()`/`info.get`; party `custom` → 0 IP-KEY-01                                                                 |
| S3 Items engine and binding points | C's `items.typ` as `src/contract/rows.typ`; L9 implicit slot; `invoice-data.items` marker (closure-held sample); L11 coverage and marker assertions; decoder placement/nesting/modifier-scope rules                                                                                                                                  | 5 d          | generated equivalence suite (pristine-base hand-written vs new-tree hand-written vs hydrated, md5 + XML): kinds b/r/t × 5/50/300 rows × zugferd none/auto × both compilers; edge documents (nested and dated bundles, `apply` around the slot, `line-items(tax: 19%)`, inclusive + small business AT, relative and dated prepayments, static rows + marker); slot misuse (two markers, marker outside, items without line-items) |
| S4 payment(..)                     | B's `payment.typ` (one copy) + paid-by-transfer account (A)                                                                                                                                                                                                                                                                          | 2 d          | means matrix transfer / direct-debit / card / paid cash / paid transfer × with and without data: BT-81 codes, CII-SR-467/470 clean, paid + terms excluded, missing mandate/last4 → issue; without data md5 == hand-written components                                                                                                                                                                                            |
| S5 Result, CLI, perf gate          | L8 (lazy, no descriptor import), result schema, L18                                                                                                                                                                                                                                                                                  | 2.5 d        | result validates against its schema; `typst query` (0.14) and `typst eval` (0.15) give equal JSON; non-hydrated invoices: metadata count and md5 unchanged; perf gate green on both compilers; CLI matrix inline/file/stdin/TOML/0.15 path → same md5                                                                                                                                                                            |
| S6 Docs                            | L26; Wappen walkthrough (static patch); data-format reference generated from the descriptor                                                                                                                                                                                                                                          | 3 d          | tests/docs verbatim tests for every block; check-docs-examples (skip markers for fixture-reading blocks); prettier                                                                                                                                                                                                                                                                                                               |
| **0.7.0 feature total**            |                                                                                                                                                                                                                                                                                                                                      | **≈ 23.5 d** |                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| S7 Speed PRs (API-neutral, Q15)    | S7a plain-dict `format-item` (1 d); S7b exact page seed (1.5 d); S7c `item()` on `item-signal` (2 d); S7d group/bundle/modifier/prepayment on shared resolvers (4 d)                                                                                                                                                                 | 8.5 d        | each: full regression md5 (313 documents) on both compilers, the equivalence suite, perf before/after table                                                                                                                                                                                                                                                                                                                      |
| S8 Bug fixes                       | L24 depth-10 collector (then raise the nesting cap), L25 modifier string amount                                                                                                                                                                                                                                                      | 1 d          | a depth-12 regression test (totals), a string-amount test                                                                                                                                                                                                                                                                                                                                                                        |
| S9 Follow-ups 0.7.x                | result attachment (Q6), bundle batch (Q21), declared typed fields + `derive` (Q7), `item(custom:)` (Q20), `locales:` map (Q22), CSV rows for the marker (Q23), explicit none (Q12)                                                                                                                                                   | –            | per feature                                                                                                                                                                                                                                                                                                                                                                                                                      |

---

## 12. Risks

1. **Drift between the components and the rows engine.** The engine replays the scope cascades of item/group/bundle/modifier/prepayment. Mitigation: the generated equivalence suite as a CI gate (S3), then ONE implementation through shared pure resolvers (S7c/S7d). Until S7d lands, `calculate-item-data`, `calculate-bundle`, `calculate-modifier` and unit/tax resolution are pseudo-contracts.
2. **Memo sensitivity.** The gain depends on `env` being identical in both loom passes; a future change that puts `ctx.global` or `sys` into `env` silently loses about half of it. Mitigation: the perf gate (§7.3) and a comment at `env-of`.
3. **Re-entry discipline.** A future `invoice()` parameter must be classified, or the hydrated branch drops or ignores it. Mitigation: the signature-coverage test (§4.2).
4. **Nested weave in `payment(..)`.** It weaves its components by `loom.core.intertwine` in measure and again in draw (≈ 1–2 ms); a loom upgrade that changes intertwine or path semantics must be tested against it.
5. **Decoder speed.** D's generic interpreter is ≈ 3× slower than C's specialised decoder (77 vs 26 ms traced at 300 rows); still ≈ 2–3 % of a 300-row compile. Mitigation: the decoder budget; a row path specialised from the descriptor if needed.
6. **Crash paths.** Any missed pre-validation aborts a batch process. Mitigation: §8.4 gate, fuzz corpus in CI.
7. **Decoder/schema disagreement.** Two interpreters of one table (regexes written in decode and export). Mitigation: differential fixtures and codegen in CI on both compilers.
8. **Layout dominates after the fast path** (≈ 72 % of a hydrated 300-row compile; keep-together `fits()` 23–34 %). 1000-line invoices still take 9–18 s without S7b and theme work. Mitigation: S7b; a theme concept for keep-together (Q15).
9. **Implicit slot surprises.** A fixed fee written in the `line-items` body disappears when hydrated (R5). Mitigation: docs and the marker; the preview cannot warn because it has no data.
10. **Samples still woven in the implicit slot** (≈ 2.4 ms per sample row and pass): noise for a few samples, ≈ 0.25 s for 50. Mitigation: the marker.
11. **Party custom is unsealed** (performance trap for large party payloads). Mitigation: documented limit; document custom is sealed.
12. **prints-of side effect** of draw-time rules (IP-PRINT-03/IP-PERIOD-03 "unknown"). Mitigation: the static patch as the documented pattern.
13. **Strictness surprises producers**: JSON numbers in text fields, numeric post codes, unit names, a missing `format` are issues. Mitigation: messages show the fix; the schema tells producers up front.
14. **`validation: none` drops invalid values silently**, which can change totals. Consistent with "off means off"; documented.
15. **Inline JSON limits** (≈ 128 KiB Linux, ≈ 32 K characters Windows). Files are the documented default.
16. **`typst query` is deprecated on 0.15; the bundle export is experimental.** The 0.14 path keeps `query`; bundle is a follow-up.
17. **New root names** (`payment`, `invoice-data`) shadow user variables defined before `import *` (L5).
18. **Measurements ran on a shared 4-core VM** (±10 % run to run, single runs up to ±20 %); all comparisons are round-robin medians and agree across both compilers and several designs; traced shares are indicative only.

---

## 13. Open questions for the maintainer

- **Q1 Data errors: issues or panics?** _Recommendation:_ class-`data` issues (draft previews incomplete data with a report and no XML; `strict` for sending and CI). _Alternative:_ always panic (A), which loses the draft preview.
- **Q2 Role of `document-type`.** _Recommendation:_ issuer (a credit-note skeleton stays a credit note unless the data says otherwise; as document, a credit-note skeleton hydrated without the key would silently become an invoice). `subject`, `notes`, `currency` issuer; `customer-nr`, `project` document. _Alternative:_ document (D).
- **Q3 Custom fields: replaced or merged?** _Recommendation:_ the data's `custom` replaces the skeleton's sample custom as a whole (no leak; constants belong in Typst, defaults in `default:`). _Alternative:_ key-by-key merge over `invoice(custom:)` (B, C, user judge), which lets a sample custom value survive.
- **Q4 Items binding point.** _Recommendation:_ the `line-items` body by default, the optional `invoice-data.items[..]` marker (at most one, a direct child of `line-items`) for static rows. _Alternatives:_ marker required (A, C); implicit only (B, D).
- **Q5 When is `<invoice-pro-result>` emitted?** _Recommendation:_ hydrated invoices and `--input invoice-pro-result=1`; revisit "every invoice" once it is measured at ≤ 1 ms without loading the descriptor. _Alternative:_ every invoice (D, user judge, B's O8).
- **Q6 Single-compile result (`--input invoice-pro-result=attach`).** _Recommendation:_ a 0.7.x follow-up after Mustang/KoSIT accept a PDF with the extra attachment. _Alternative:_ ship it in 0.7.0 as opt-in experimental (D, user judge).
- **Q7 Declared typed custom fields and the `derive` hook.** _Recommendation:_ 0.7.x, as `load(.., extensions:, derive:)` with field types in a sub-namespace whose names shadow no builtin (never `text`, `array`, `decimal` at the top of `invoice-data`). _Alternative:_ in 0.7.0 (D, user judge).
- **Q8 Names.** _Recommendation:_ `invoice(data:, custom:)`, namespace `invoice-data`, component `payment`, marker `invoice-data.items`, label `<invoice-pro-result>`. _Alternatives:_ `hydrate` (A, C), `data-format` (B).
- **Q9 Partial sender (a per-invoice clerk, multi-tenant letterheads).** _Recommendation:_ `sender` is replaced whole (a merge can pair another tenant's VAT ID or BIC with the data's name); a per-invoice clerk comes later through `derive` or a `sender.contact`-only rule. _Alternative:_ A's rule "a data party without `name` completes the skeleton's".
- **Q10 One spelling for units and taxes.** _Recommendation:_ UN/ECE codes (any Rec 20 code by pattern) or `{code, display}`; tax `"19%"` or an object, no presets. _Alternative:_ also accept invoice-pro unit names and the presets `"exempt"`, `"reverse-charge"` (A, B, C), which breaks clean codegen.
- **Q11 JSON numbers.** _Recommendation:_ rejected for text (fix shown), tolerated for decimals (exact). _Alternative:_ strings only everywhere.
- **Q12 Explicit none.** _Recommendation:_ `null` ≡ absent everywhere in v1; cancelling a cascaded value per child is not expressible (write the group without it). _Alternative:_ C's "null = none where meaningful", which conflicts with generated model dumps.
- **Q13 Two sources.** _Recommendation:_ an explicit `data:` value plus a present `invoice-pro-data*` input panics. _Alternatives:_ data wins (B's R6); input wins (A).
- **Q14 Nesting cap.** _Recommendation:_ cap 8 now; fix `collect-signals` in a bugfix PR in 0.7.0 and then raise the cap in a minor. _Alternative:_ keep the cap and the bug.
- **Q15 Internal speed PRs in 0.7.0?** _Recommendation:_ yes, as separate API-neutral PRs: `format-item`, exact page seed, shared item resolver, then the other resolvers; keep-together's cheaper check goes to a theme concept. _Alternative:_ later (maintainer judge: out of the feature PR).
- **Q16 YAML and TOML.** _Recommendation:_ JSON canonical; TOML and YAML supported by file extension (TOML gives native dates). _Alternative:_ JSON only.
- **Q17 `format` required.** _Recommendation:_ required (a missing one is an issue, another major panics). _Alternative:_ optional with default 1 (B, C).
- **Q18 Schema `$id` host.** _Recommendation:_ the docs site, versioned by format major only (`https://leonieziechmann.github.io/invoice-pro/schema/invoice-pro/1/…` or the real docs host).
- **Q19 Tier.** _Recommendation:_ `invoice-data`, `payment`, `invoice(data:, custom:)` experimental; the format provisional. _Alternative:_ provisional throughout.
- **Q20 `item(custom:)`.** _Recommendation:_ 0.7.x, for preview parity with data rows, and freeze `view.items[i].custom` in the part contract.
- **Q21 Batch in one process.** _Recommendation:_ processes in 0.7.0; a documented 0.15 bundle pattern (or helper) later. _Alternative:_ `invoice-data.batch` now (D).
- **Q22 Locale from data.** _Recommendation:_ no in v1 (design, customisations are closures); later a `locales: (de: .., en: ..)` map the data selects by name.
- **Q23 CSV rows for the marker** (`invoice-data.items(rows: ..)`, roadmap "Data Loading"). _Recommendation:_ 0.7.x; rows from Typst are code, so bad rows panic.

---

## Appendix A: provenance

| Element                                                                                                                                                              | From                                    |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------- |
| `invoice(data: auto)`, roles, whole-value merge, payment(..), implicit slot, coverage issues                                                                         | B (adopted by D)                        |
| Descriptor → decoder, schemas, docs; JSON Pointer issues; result shape, status, exit codes; conformance; codegen; `format` required; `$id` major only; null ≡ absent | D                                       |
| Rows engine, closure-held sample, region VAT rates, `{text}`→BT-20, perf PRs (format-item, page seed, item-signal), equivalence generator                            | C                                       |
| Static Wappen patch, `party()` normaliser, explicit marker, paid-by-transfer account, Unicode-regex lesson                                                           | A                                       |
| Unconsumed-input panic, `kind: null`, model-dump fixtures, units by pattern                                                                                          | user judge                              |
| Crash-free decoder gate, modifier-scope/base-quantity/country/currency checks, nesting cap, sample out of the weave                                                  | engine judge                            |
| Small namespace, result not always-on, no copied defaults, separate perf PRs                                                                                         | maintainer judge                        |
| Re-entry precedence                                                                                                                                                  | this synthesis (`<session>/exp/synth/`) |

## Appendix B: rejected alternatives

1. Presence-only override (C): leaks samples (verified by two judges).
2. Converters and `.with` with base/sample dictionaries (A): skeleton restructuring, issues only through the internal lazy-theme channel, silent slot hazards.
3. Copied defaults tables (B in invoice.typ, D in the descriptor): silent drift; replaced by re-entry.
4. Deep merge of parties, also as RFC 7386 merge patch: mixes identities.
5. Always-on result loading the descriptor (D).
6. 27-name namespace with builtin-shadowing type constructors (D).
7. Body-only hydration component: false "missing" issues, wrong XML embedded, strict does not stop.
8. Skipping loom's measure pass: 0–5 % on top of the bulk motif, couples format and skeleton, stale-global risk.
9. Package-side file reading: impossible on 0.14 and 0.15.
10. `x-*` data keys for extensions: break generated models; `custom` bags instead.
11. An expression language or `eval` in data: design stays Typst.

## Appendix C: evidence index (`<session>` paths)

- Designs: `design/{A-converter,B-integrated,C-performance,D-contract}.md`; research: `understand/*.md`.
- Prototypes: `exp/design-A-converter/` (static patch `proto/t-prints.typ`, payment `proto/t-pay.typ`, `repo/src/public/hydrate.typ` `party`), `exp/design-B-integrated/` (`repo/src/components/payment.typ`, `regress/run.sh`, `verify.sh`), `exp/design-C-performance/` (`repo/src/hydrate/items.typ`, `repo-item/src/logic/line-signal.typ`, `repo-x/src/theming/frame.typ`, `proto/{gen,eq.sh,regress.sh,bench}`), `exp/design-D-contract/` (`repo/src/contract/*`, `repo/conformance/`, `codegen/`, `tools/`).
- Judges: `judge-engine/` (`scripts/fuzz.py`, `work/edge-hand.typ`, `work/*-two.typ`, `leak/`), `exp/judge-user/` (pydantic dumps, slot and payment misuse), `judge/` (maintainer runs).
- Re-entry check: `exp/synth/` (`README.md`, `skel.typ`, `hand.typ`, `nodate.typ`, `repo/src/invoice.typ`).
