# Design panel digest

Four designs (A converter, B integrated, C performance, D contract) were judged by three judges with distinct lenses. Scores are sums of five criteria (1–10 each).

| Judge      | Ranking                                                 | Totals                                                             |
| :--------- | :------------------------------------------------------ | :----------------------------------------------------------------- |
| maintainer | B-integrated > A-converter > D-contract > C-performance | B-integrated 37, A-converter 36, D-contract 35, C-performance 30   |
| engine     | D-contract > B-integrated > C-performance > A-converter | A-converter 29, B-integrated 36.5, C-performance 33, D-contract 37 |
| user       | D-contract > B-integrated > A-converter > C-performance | D-contract 42, B-integrated 33, A-converter 32, C-performance 27   |

## Synthesis

Base: D-contract (contract first). It already contains B's integration model: invoice(data: auto), document/issuer roles, payment(..), the whole-body items slot and coverage issues. On top it has the strongest error model (0 hard aborts in 38 faults) and phase-2 tooling (one descriptor for decoder, JSON Schema, docs and roles; 51/51 conformance; pydantic/TS/Rust codegen). It ranked first for two judges, and its total is highest (D 114, B 106.5, A 97, C 90). Trimmed for the base: the namespace shrinks to 10 names, the result is no longer always-on, the copied defaults are replaced by re-entry, and the type constructors, batch, reference and derive are deferred. B's rows.typ and D's forked payment.typ are swapped for C's engine and B's single payment file.

### Grafts

- NEW (this synthesis): re-entry precedence. The hydrated branch of invoice() calls invoice(..effective, data: <sealed applied marker>, body) and leaves out absent document keys, so the signature's own defaults apply and no defaults table is copied. This fixes the B/D drift flaw. Verified in <session>/exp/synth (both compilers): hydrated == hand-written md5 (f556eb021f41 / bbc9ad6884ea); a missing invoice-nr gives a draft with '‹fehlt: Rechnungsnummer›' and 0 embedded files, and strict panics; the sample date falls back to today; template md5 unchanged (ba5d9a49b5de / c7e98da669bc)
- C: rows engine hydrate/items.typ. Its cascade dict tracks key presence. It is the only engine byte-identical on nested and dated bundles, apply around the slot, and explicit none
- C: the explicit marker holds the sample in its closure, so the sample is never woven
- C: regions export their VAT rates next to infer-tax, so a data rate like '16%' becomes a data issue instead of a panic
- C: a bare ISO string is always a date (BT-9); free-text terms (BT-20) are written explicitly as payment.terms.text
- C: API-neutral speed PRs: plain-dict format-item; exact page-count seed; item() and later group/bundle/modifier/prepayment on the shared pure item-signal resolver
- C: generated equivalence suite gen.py + eq.sh comparing pristine-base hand-written, new-tree hand-written and hydrated by md5 and XML, as a CI gate
- B: invoice(custom:) for preview samples, sealed as ctx.custom; unsealed() and dynamic unwrap it
- B: payment(..) composite, one file (D's fork dropped)
- B: the implicit \_items-slot wrapper; non-hydrated output stays byte-identical (53/53 tests + template)
- A: Wappen as a STATIC document-level theme patch (theme.custom.logo(image: ..)) chosen from invoice-data.values(record). It keeps prints-of page-content false, so IP-PRINT-03/IP-PERIOD-03 stay active
- A: invoice-data.party() normaliser, which gives the post code from a string or a structured city
- A: optional explicit slot marker invoice-data.items[..] for static rows (fixed fee)
- A: an invoice paid by transfer keeps the bank-details account (CII-SR-470)
- A: ASCII-only regexes in the decoder (a Unicode \d regex made it 3.7x slower)
- D: descriptor-driven decoder with crash-free discipline (regex pre-validation before decimal/datetime/constructors, sealed descriptor, row-level drop); JSON Pointer issue ids schema/<pointer>; result shape with status, rates as '19%' and e-invoice diagnostics; exit-code table; format required; $id carries the major only; since per key; conformance fixtures and codegen in CI; committed schemas with a drift check
- User judge: panic when an invoice-pro-data\* input is given but not consumed (extended to every key and path)
- User judge: null ≡ absent everywhere, including kind; schema default kind 'item'; default model dumps as conformance fixtures
- User judge: units accept any UN/ECE Rec 20 code by pattern (KWH accepted); the 18 known codes are localized; {code, display} objects allowed
- Engine judge: decoder checks for base-quantity <= 0, malformed country/currency, a modifier with no taxed items in scope, nesting > 8; drop never more than the offending row; 0-abort fault-corpus gate
- Maintainer judge: small namespace with no builtin shadowing; result emitted only when hydrated or on --input invoice-pro-result=1, loaded lazily without the descriptor; speed refactors and bug fixes as separate PRs

### Decisions

- Entry point: invoice(data: auto). auto reads --input invoice-pro-data; also accepts a record, dict, bytes, JSON text or a 0.15 path
- Precedence by role. Document keys come from the data only (the skeleton value is a sample and is dropped). Issuer keys keep the skeleton's value unless the data gives them. Design is never data. Absent document keys get the signature's defaults via re-entry
- No deep merge anywhere: parties, city, contact, tax, terms, bank and custom are replaced whole. The payment section applies key by key by role (terms/method/bank/creditor-id issuer; direct-debit/card/paid document)
- custom has role document: the data's custom replaces the skeleton's sample as a whole (Q3)
- document-type is an issuer key (Q2); subject, notes, currency issuer; customer-nr, project document
- Files: --input invoice-pro-data-file read by the skeleton's callback, invoice-data.load(read: p => read(p, encoding: none)); JSON/TOML/YAML by extension; stdin via /dev/stdin with --root /
- R7: an unconsumed invoice-pro-data\* input, two sources, or the file key without read: panic with the one-line fix
- Items binding point: the line-items body by default; an optional invoice-data.items[..] marker (at most one, direct child of line-items, asserted) keeps static rows; coverage issues schema/items and schema/payment
- Rows engine: C's items.typ, a pure compute(rows, env) so pass 2 is a memo hit; two loom passes kept
- Line-item shape: tree items (item/group/bundle), separate modifiers arrays (document/bundle/item), top-level prepayments; nesting cap 8
- Encodings: decimal strings (JSON numbers tolerated exactly), '19%' (bit-exact, checked against region rates), ISO dates, {start,end} periods, UN/ECE codes or {code, display}, tax '19%' or object (no presets), identifiers via id.\* constructors, null ≡ absent
- Errors: class-data issues schema/<JSON Pointer> with localized schema-\* keys and a 'Daten/Data' chip; misuse, a foreign format major or an unconsumed input panics
- Namespace invoice-data with 10 names: format, input-key, file-key, load, decode, check, values, party, items, schema(kind: 'data'|'result')
- payment(terms, method, bank, creditor-id, direct-debit, card, paid, show-reference, qr-code): account only for a transfer or paid-by-transfer
- Result <invoice-pro-result> (invoice-pro-result/1, strings only, status ok|draft|unchecked) only on hydrated invoices or with --input invoice-pro-result=1
- Wappen: static theme patch from values (documented pattern); draw-time wrap only as a fallback, with the IP-PRINT caveat
- Data-dependent issuer parameters are Typst expressions on values; document-key changes via a derive hook deferred to 0.7.x (Q7)
- Party custom reserved as a print-only party key; item custom reaches view.items[i].custom
- Tier: invoice-data, payment, invoice(data:, custom:) experimental; format invoice-pro/1 provisional
- Batch: one process per invoice (one factur-x.xml per PDF); 0.15 bundle and result attachment are follow-ups
- Perf gates: hydrated 300 rows <= 0.6x hand-written on both compilers; decoder <= 0.4 ms/row; import delta <= 0.2 ms; new modules in LAZY_MODULES
- Signature-coverage tools test: every invoice() parameter must be classified in the descriptor (guards re-entry)

### Changes that are not pure extensions

- L5/L4 new root names payment and invoice-data: they replace a user variable of the same name defined BEFORE `import *`. This risk applies to every new export; accepted
- L7 a given invoice-pro-data\* input that is not consumed now panics. These keys carry the reserved package prefix and do nothing in 0.6.0, so no working document depends on them; the panic prevents shipping a sample invoice
- L13 custom: false in party-keys: a party key named `custom` no longer raises the IP-KEY-01 warning. Today it is printed and written nowhere, so the only effect is one warning less
- L15 regions gain an additive vat-rates field next to infer-tax; user-built regions without it skip the data pre-check and behave as tax: 16% does today
- L16 new schema-\* locale strings and a 'Daten/Data' chip label; user locales lacking them fall back to English; existing issue texts unchanged
- L9 line-items body becomes a slot when hydrated (behaviour change only with data; non-hydrated md5-identical 53/53 + template)
- L11 root emits coverage issues, marker assertions and the result only with data, payment(..), a marker or --input invoice-pro-result
- L20-L23 internal refactors (plain-dict format-item, exact page seed, item() and the other components on shared pure resolvers): signatures and output unchanged (verified md5 on 123 and 313 documents); the loom scope internals of stable components change
- L24 bugfix collect-signals(depth: 10): changes totals of invoices nested >= 10 levels, which are silently wrong today (format caps nesting at 8 until then)
- L25 bugfix modifier(amount: string) no longer crashes in normalize.money

### Open questions

- Q1 Data errors as class-data issues (rec) or always panic (A)?
- Q2 Role of document-type: issuer (rec) or document (D)?
- Q3 custom: data replaces the skeleton's sample custom whole (rec) or merges key by key (B/C/user judge)?
- Q4 Items binding: implicit line-items body plus an optional marker (rec), marker required (A/C), or implicit only (B/D)? Marker direct child of line-items only in v1?
- Q5 Result on hydrated/opt-in invoices only (rec) or on every invoice (D, user judge)?
- Q6 Single-compile result attachment (--input invoice-pro-result=attach): 0.7.x after a Mustang/KoSIT run (rec) or in 0.7.0?
- Q7 Declared typed custom fields + derive hook: 0.7.x with non-shadowing names (rec) or in 0.7.0 (D)?
- Q8 Names: invoice(data:, custom:), invoice-data, payment, invoice-data.items, <invoice-pro-result> (rec) vs hydrate/data-format
- Q9 Partial sender (per-invoice clerk, multi-tenant): replace whole (rec) or A's 'no name = complete the letterhead'?
- Q10 One spelling: UN/ECE unit codes and tax '19%'/object only (rec) or also unit names and tax presets?
- Q11 JSON numbers rejected for text, tolerated for decimals (rec) or strings only?
- Q12 null ≡ absent everywhere; explicit none to cancel a cascade not expressible in v1 (rec) vs C's null = none?
- Q13 Explicit data: plus a present input panics (rec) vs data wins (B) vs input wins (A)?
- Q14 Nesting cap 8 now, fix collect-signals in a 0.7.0 bugfix PR, then raise the cap (rec)?
- Q15 Ship the internal speed PRs (format-item, page seed, shared resolvers) in 0.7.0 as separate PRs (rec)? Cheaper keep-together to a theme concept?
- Q16 JSON canonical with TOML/YAML by extension (rec) or JSON only?
- Q17 format required (rec) or optional with default 1?
- Q18 Schema $id host: docs site, versioned by format major only (rec)
- Q19 Tier: experimental API + provisional format (rec) or provisional throughout?
- Q20 item(custom:) for preview parity in 0.7.x (rec)?
- Q21 Batch: processes in 0.7.0, 0.15 bundle helper later (rec) or invoice-data.batch now?
- Q22 Locale from data: no in v1, later a locales: map (rec)?
- Q23 CSV rows for the marker (items(rows: ..)) in 0.7.x (rec)?
