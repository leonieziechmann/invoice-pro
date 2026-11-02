# Research: Validation, e-invoice and locale

Phase-1 reader `validation-zugferd-locale` of the data-API exploration (2026-11-02). Facts marked [v] were verified (read or run), [i] are inferences. `<repo>` is the repository root, `<session>` the scratch directory of the exploration (not part of the repository).

## Summary

I built a working data-file → skeleton prototype. One JSON file, decoded by about 150 lines of user-space Typst, produced a valid XRechnung 3.0 whose XML is byte-identical to the same invoice written by hand. The decoding cost was within run-to-run noise. Validation has two kinds of data checks. (a) `check-data` has 8 rows for the `invoice` kind: 6 'input' rows run inside invoice() on its own arguments, and 2 'measure' rows run in root's measure. (b) Separate data issues for the IBAN, creditor ID and debtor IBAN. Every data issue has class "data", the only blocking class. Under draft, any data issue withholds the XML; strict panics with all messages; none runs nothing. This leads to the main integration constraint: hydration must feed invoice() arguments (or the input checks must move into root). It cannot work only at body level. The e-invoice model reads only the root ctx (fed by invoice() arguments) plus the line-items, payment-terms, bank-details, direct-debit, card-payment and paid signals. So the data format must be able to express all of these. Measured minimum per profile: MINIMUM needs nr, date, names, address/city, a VAT ID and one item. BASIC WL, BASIC and EN16931 also need payment terms or a due date (IP-PAY-06). XRechnung also needs the seller contact (name, phone, email), a buyer-reference, a buyer electronic address and a payment means. Several typed values need a string encoding. Hand-built tax dicts must carry all 4 keys (rate/category/label/grounds), so hydration should call tax.new(). Units given as strings print verbatim ('DAY'), so codes should map to the localized unit.* functions. Countries already accept 'DE'. Typed IDs need an explicit form like {"gln": ".."}. Percent strings must be parsed as float(n)/100*100%: this is bit-exact with the literal, which matters because infer-tax compares rates with ==, while '\*1%' is not exact for every rate. A schema error in the data should become a class-"data" issue (id 'schema/<path>', field: none) appended at invoice.typ:547-561. That gives the draft report, the strict panic and XML withholding for free. In the experiment, issues emitted from the body appeared in the report, but the XML with wrong data was still embedded, even under strict. Locale is config, but it can be looked up by name (dictionary(locale).at("en-de"), 30 names). A name in the data file cannot carry .with(locale.custom...) customizations, so the skeleton should own the locale.

## Key facts

- [v] check-data covers kind 'invoice' only (0.6.0) with 8 rows: invoice-number, sender-name, sender-address, sender-tax-id, recipient-name, recipient-address (when: input) and line-items, recipient-vat-id (when: measure). (src/validation/data.typ:39-125)
- [v] Region does not change WHICH rows apply. It only changes the legal citation: DE gives the exact § of UStG, AT/CH/FR/IT/ES give a generic national reference, and every row adds 'EN 16931 BT-x'. The region is the LOCALE region, not the sender country. (src/validation/data.typ:129-144; src/invoice.typ:558 and src/components/root.typ:471 (region: lower(str(eval-locale.meta.region))))
- [v] sender-tax-id passes when vat-id or tax-nr is given, or the tax representative's is. A non-DE sender may instead give legal-id, id or global-id (BR-CO-26). A DE sender (or one without a country code) must give vat-id/tax-nr. (src/validation/data.typ:17-34)
- [v] sender-address and recipient-address pass if EITHER address OR city is non-blank (blank = none, "", [], ()). (src/validation/data.typ:7, 65, 95)
- [v] The 'input' rows run in invoice() on its own arguments (invoice-nr param, normalized sender and recipient), before weave. Hydrating invoice-nr, sender or recipient only into ctx at body level would therefore still report them as missing. (src/invoice.typ:547-561)
- [v] The 'measure' rows plus the bank and direct-debit data issues run in root's measure, then pass through enforce(issues, level). Under strict this panics with every message. (src/components/root.typ:458-477; src/validation/issue.typ:126-146)
- [v] Further class-data issues outside check-data: iban / iban-N (missing or invalid IBAN), creditor-id and debtor-iban (direct debit). epc-qr is class lint. (src/components/root.typ:15-96)
- [v] Issue classes are data/theme/lint, asserted in issue(). Only 'data' is a blocking class. Under draft, an open data issue with zugferd set withholds the XML. (src/validation/issue.typ:14,19,60-63; src/components/root.typ:483-485)
- [v] Levels: none = no check of the 3 classes (misuse still panics, and the XML is attached as zugferd-errors says). draft = inline markers, badge, watermark, report page, XML withheld, PDF keyword 'Draft'. strict = panic. `--input invoice-pro-validation=strict|draft|none` overrides the parameter. (src/validation/issue.typ:23,27,80-121; src/invoice.typ:195-214; src/components/root.typ:597)
- [v] Inline draft markers exist only for issue ids invoice-number, sender-name, sender-address, recipient-name, recipient-address and sender-tax-id. They are matched by id among the issues whose field != none. Everything else appears only in the report. (src/theming/frame.typ:49-69,117-128)
- [v] The report renders a data issue that has a `field` as 'Missing: <label>'. Otherwise it shows the localized strings.validation.issues.<key>(args), falling back to the English message with `code` spans. So a schema error should use field: none (or a key). (src/validation/render.typ:142-151,201-203)
- [v] Draft issues are emitted as metadata <ip-issue> (only under draft), and the report and badge query all of them per invoice. The CLI can therefore return them as JSON: `typst query skeleton.typ "<ip-issue>" --field value`, or `typst eval --in skeleton.typ 'query(<ip-issue>).map(m => m.value)'` on 0.15. (src/theming/frame.typ:681,863-875; src/validation/render.typ:32-44; ran both commands, got 6 issue records as JSON)
- [v] Schema issues emitted from the body as <ip-issue> metadata appear in the draft report. They do NOT withhold the XML, and under strict they do not stop the compilation: xrechnung.xml carrying wrong data (default date and tax) was embedded. (experiment bad2.json: pdfdetach -list shows xrechnung.xml under draft and under strict)
- [v] build-model reads these root ctx keys: sender, recipient, delivery-address, payee, document-type, zugferd, tax-mode, locale (currency, format.currency/currency-fine/date, strings), currency, printed, invoice-nr, title, invoice-date, buyer-reference, order-nr, po-nr, contract-nr, delivery-note-nr, preceding-invoice-nr, original-invoice-nr, preceding-invoice-date, notes, project, due-date, references, payment-reference, service-period. It also reads item-data (line-items signal), payment-goal (payment-terms signal), bank and payment-means (bank-details/direct-debit/card-payment/paid signals). (src/zugferd/model.typ:1253-1629; src/logic/payment-reference.typ:34-62; src/logic/service-period.typ:88-95; src/components/root.typ:520-526)
- [v] ctx keys buyer-reference, po-nr and original-invoice-nr are read by the model but never set by invoice(). They are orphan keys that could become new invoice() parameters as a pure extension (BT-10 is currently only reachable via recipient.buyer-reference/leitweg-id). (src/zugferd/model.typ:1529,1536,1549; src/invoice.typ:563-617 (no such keys); src/public/info.typ also reads dynamic("buyer-reference"))
- [v] Party keys known per role (true = read by the e-invoice) are listed in party-keys. Unknown keys raise IP-KEY-01 (a warning). Keys that look like known ones raise IP-KEY-02 (an error, e.g. plz, zip, ustid, siret). So custom fields must NOT be put raw into party dicts. (src/zugferd/model.typ:357-407,465-511; src/zugferd/keys.typ:98-104; tools/zugferd/registry.json:259-282; experiment custom-plz2.json → [IP-KEY-02] recipient.plz error)
- [v] Verified minimum per profile (zugferd-errors: report). minimum: no errors with name+address+city+vat-id, invoice-nr, date and 1 item. basic-wl/basic/en16931: also IP-PAY-06 (payment terms or due date needed). en16931 also warns IP-EADDR-01. xrechnung: also PEPPOL-EN16931-R010 (buyer electronic address), BR-DE-2 (seller contact), BR-DE-15 (buyer-reference), IP-PAY-06, BR-DE-1 (payment means). (experiment minimal.typ compiled for 5 profiles; pdftotext of the e-invoice report)
- [v] With zugferd: auto, a German buyer tries xrechnung, then en16931; any other buyer gets en16931. (src/zugferd/profile.typ:178-191)
- [v] A hand-built tax dictionary must contain all of rate, category, label and grounds. item(tax: (rate: 19%, category: "S")) panics. The loom record matcher requires every key, rate must be ratio/float/decimal/int (not str), and category must be one of the 22 UNTDID 5305 codes. tax.new(rate: str|ratio|..., category, label, grounds, code) fills in the defaults and accepts a string rate. (src/utils/types.typ:53-93; <loom>/src/lib/matcher.typ (Record branch); experiment a-tax-dict.typ panic; b-tax-dict.typ ok)
- [v] A ratio tax (19%) is mapped by the locale region's infer-tax using == comparisons. Unknown rates and 0% PANIC (they do not become issues). DE knows 19%, 7%; AT 20/13/10; CH 8.1/2.6/3.8; FR 20/10/5.5/2.1; IT 22/10/5/4; ES 21/10/4. (src/data/tax.typ:324-338; src/locale/region/de.typ:5-27; ch.typ:23-41; fr.typ:22-46; at/it/es.typ)
- [v] Parsing '19%' as float(n)/100*100% reproduces the Typst literal bit-for-bit (tested 9.975%, 33.333%, 12.345678%). float(n)*1%, which theme.custom.from-data uses, is NOT equal to the literal for 9.975%. (experiment ratio.typ / ratio2.typ; src/theming/data.typ:28)
- [v] An item unit given as a string (e.g. "DAY") prints verbatim ('2 DAY'), not localized. unit.day etc. are functions of the locale that give (code, name, display) with localized, pluralized names. There are 18 codes: H87 SET PR LS HUR DAY MON ANN KGM GRM TNE MTR MTK MMT CMT KMT LTR MTQ. Text units are resolved to codes for the XML via an alias table (IP-UNIT-01/02). (src/logic/unit.typ:47-180; src/zugferd/units.typ:11-31; src/zugferd/model.typ:747-760; experiment b-tax-dict.pdf)
- [v] Countries already accept ISO alpha-2 strings ('DE', 'UK'→GB, unknown codes become a custom country without a name) and dicts like {code, name}. Post codes given as numbers are rejected (leading zeros). (src/logic/country.typ:629-716,781-812)
- [v] There are 8 typed id constructors returning (scheme, id, kind, problems): gln 0088, duns 0060, siren 0002, siret 0009, uid-ch 0183, register (no scheme, court:), leitweg 0204, custom(scheme, id). They never panic: problems are reported by the e-invoice (IP-ID-01). A raw {scheme, id} dict is accepted but its check digits are not checked. (src/public/id.typ:194-416; src/logic/party-inputs.typ:10-77)
- [v] Currency is an ISO 4217 string validated by regex ^[A-Za-z]{3}$. Symbols are known for 7 currencies, and decimals by an exception table. with-currency rebuilds the formatters. (src/data/currency.typ:8-117)
- [v] Locales can be looked up by name: dictionary(locale) has 30 '<lang>-<region>' functions (lang ∈ de,en,fr,it,es; region ∈ at,ch,de,es,fr,it) plus the non-locale keys lang, region, build-locale and custom. There is no en-us or en-gb. (src/locale/locale.typ:1-47; experiment e-locale2.typ printed keys and evaluated de-de/en-ch/fr-fr)
- [v] A locale controls the language strings (labels, units, payment sentences, document titles, validation texts) and the region settings: format (date, number, currency, currency-fine, percent, time), normalize (money rounding, infer-tax), currency meta (code, symbol, decimals, decimals-fine), tax (default-vat, small-enterprise-special-scheme) and meta.region. meta.region is the default country of parties, the legal citations of check-data, text.region and (via the sender) the theme layout. Customization works through .with(locale.custom.\*), which a name string cannot express. (src/locale/factory.typ:142-189; src/locale/region/base.typ:1-103; src/locale/custom.typ (document..tax); src/invoice.typ:375-417)
- [v] A package cannot read a user's file by path: json("/data.json") inside a package resolves to the package root. The user's file must read it (json(path) or read(path, encoding: none)) and pass the dict/bytes along. Inline --input data='{json}' works up to the OS arg limit: 70 KB was fine, 214 KB failed with 'Argument list too long'. (experiment d-pkg.typ (local package via --package-path) and big-input.typ)
- [v] An ISO date in due-date as a STRING is treated as payment-terms TEXT (BT-20), not as a due date (BT-9). The same holds for payment-terms(date: str). So the hydrator must turn 'YYYY-MM-DD' into datetime for these fields. (src/zugferd/model.typ:1436-1448; src/components/payment-terms.typ:42-56)
- [v] The prototype JSON→invoice produced XML byte-identical (cmp) to the hand-written invoice and compiled in the same wall time (about 0.43-0.55 s each). Decoding 103 items costs about 30 ms (measured with typst --timings) out of the ~190 ms package import. (experiment skeleton.typ vs handwritten.typ, cmp att/xrechnung.xml att-hw/xrechnung.xml → identical; timing loop)

## Implications

- Hydration has to reach invoice()'s own arguments: `invoice(..design, ..decoded.args)`, or a new extension parameter such as `invoice(data: ..)` that decodes before invoice.typ:547. Otherwise check-data 'input' rows report hydrated invoice-nr, sender and recipient as missing. The e-invoice also reads only root ctx, and `apply` can't reach it (it scopes a subtree).
- Schema/decoding errors of a data file should be issue(id: "schema/<json-pointer>", class: "data", field: none, ref: "invoice-pro data v1", fix: <example encoding>, key: "schema-\*" (optional), args), appended to `issues` at invoice.typ:547-561. That needs no new class and gives the draft report, the strict panic (root.typ:477), XML withholding (root.typ:483) and the CLI override for free. A new class 'schema' would need issue.classes, blocking-classes and strings.validation.classes in 6 language files (render.typ:183 panics on a missing class label).
- Under `validation: none`, invalid data values still cannot be passed on (components panic in types.require). The design must decide: drop invalid values silently ('off means off') or panic like misuse.
- The data format should mirror the invoice() argument and component names (sender.contact.email, recipient.buyer-reference, payment-terms...). The e-invoice diagnostics' `field` strings already use these dotted paths (e.g. 'sender.contact.email', 'recipient.buyer-reference'), so errors map back to data-file paths almost for free. Item lines are named 'item N (name)', not 'items[N]'.
- A data file that wants a valid XRechnung must be able to express: invoice-nr, date, currency, document-type, preceding-invoice nr/date, notes {text, subject-code}, service-period, due-date, payment-reference, order/contract/delivery-note/project numbers, and full sender/recipient/delivery-address/payee/tax-representative dicts. The sender dict needs contact {name, phone, email}, vat-id, tax-nr, legal-id, trading-name, legal-info and electronic-address. The recipient dict needs buyer-reference/leitweg-id, electronic-address/email, vat-id and country. Items need name, description, quantity, base-quantity, unit, price|total, tax, item-id {seller, buyer, standard}, note, origin, date|period and modifiers. Document-level discounts/surcharges and prepayments are needed too. Payment needs bank-details (iban, bic, bank, account-name, reference/text), direct-debit (mandate, creditor-id, debtor-iban), card-payment (last4, holder, kind), paid (method, date) and payment-terms (days | date, discount [{days, percent, basis}]).
- Proposed canonical encodings: date "YYYY-MM-DD" (TOML native dates pass through); period [start, end]. Percent "19%" parsed as float(n)/100\*100%. Money and quantity as decimal strings "120.00" (JSON numbers allowed, but floats are rounded to 15 digits). Tax: "19%" (= Typst `19%`, so locale infer-tax applies) or {category, rate, code, grounds}, hydrated with tax.new(). Unit: a UN/ECE code "HUR" mapped to unit.hour for the 18 known codes, else {code, display}. Country: "DE" or {code, name}. Identifiers: single-key objects mapping 1:1 to id.<ctor>, e.g. {"gln": "..."}, {"siret": "..."}, {"leitweg": "..."}, {"register": "HRB 4711", "court": "..."}; or {scheme, id} for custom/raw; or a plain string. Electronic address: an email string or {scheme, id}. Currency: an ISO 4217 code. Locale: a name "de-de". Modifier and prepayment amounts: "10%" is relative, "5.00" is absolute (the % sign disambiguates).
- Treat JSON null and empty strings as 'not given' (auto), not as Typst `none`. This follows the existing precedent: model.typ \_is-unset (none/auto/""/[]/()) and country.typ \_states-no-country ('an empty column of imported data'). Note that `tax: none` in Typst means implicit-zero, which the e-invoice rejects (IP-TAX-01).
- Custom fields and value-dependent design (the 'Wappen per PLZ' example) should live in a separate `custom` namespace. The hydrator must strip it from party dicts, otherwise IP-KEY-01/02 fire ('plz' is a known alias → error). For the PLZ case specifically, the normalized party already exposes `post-code` (logic/country.typ normalize-party), so a skeleton can switch on ctx.recipient.post-code without any custom field.
- The CLI interface needs both an inline form (--input data='{json}', below about 128 KB) and a file form (--input data-file=path, read by the user's skeleton or template file, never by the package). The package API should accept a dict, bytes or a JSON string.
- Locale should stay with the skeleton (design/config). A data `locale` name can only select a stock locale and would silently drop .with(locale.custom..) patches. So either honor it only when the skeleton opts in, or let the skeleton provide a name→locale map. Data files should state party `country` explicitly: otherwise parties default to the locale region, which also decides the legal citations and the default VAT.
- Phase 2 hooks: issues are already machine-readable through `typst query/eval` on <ip-issue> (draft only). E-invoice diagnostics are not emitted as metadata yet; adding `metadata(result.diagnostics)<ip-einvoice-diagnostics>` would be a pure extension. A schema table kept in Typst (one source of truth for keys, types, encodings and BT numbers) could be exported to JSON Schema via `typst eval` for bindings.
- Speed: decoding is negligible next to weave and the package import. Validation adds no extra loom pass. The draft report needs a context query that already exists, and enforce is a single panic. Nothing in the validation and e-invoice path forces extra passes for hydrated data.

## Risks

- Hydrating only into ctx or the body, for example a `hydrate()` component inside the skeleton, gives wrong results. The input checks report false 'missing' issues, and schema issues neither block the XML nor fail strict: verified, the XML with the default date and tax was embedded.
- Region infer-tax PANICS on unknown or 0% rates (e.g. "16%" in a de-de skeleton). A data file with a bad rate then aborts the build instead of producing an issue, unless the hydrator pre-validates against the region's known rates (which only exist as code inside infer-tax closures).
- Comparing ratios with == makes tax inference sensitive to float representation. Using float\*1% (like theme from-data) would mis-infer some rates. Using eval() for parsing is a no-go: the theming/data.typ comment says eval is not file-sandboxed.
- Custom keys in party dictionaries collide with IP-KEY aliases (plz, zip, ustid, siret, tel...), and collisions are hard errors with zugferd-errors: panic.
- Ambiguity of string dates: due-date, order-date, payment-terms.date and paid.date take both datetime and text. A hydrator must decide by pattern, and an ISO-looking string intended as text would be converted.
- Selecting the locale from data overrides skeleton customizations silently. Also no en-us/en-gb locale exists, although the docs mention locale.en-us (docs/concepts/theming-api/process/designs/tokens-first.md:719).
- Schema issues as class 'data' show the chip 'Pflichtangabe/Required data', which is semantically a bit off for a type error. Localized schema texts require new strings.validation.issues keys in 6 language files (falling back to English is graceful).
- Inline --input JSON hits the OS argument limit (~128 KiB per arg on Linux). Large invoices need the file path variant.
- `typst query` is deprecated in typst 0.15.1 (successor: `typst eval --in`). The CLI contract for machine-readable issues must work on 0.14.x (query) and 0.15+ (eval).

## Open questions

- Under validation: none, should invalid data values be dropped silently, or panic like API misuse?
- Should a ratio-string tax ("19%") mean 'locale infer-tax' (consistent with Typst `tax: 19%`, but it panics on unknown rates) or explicitly 'standard rate S' (tax.vat)? And should unknown rates become issues?
- Should schema issues get their own class (e.g. 'schema', blocking), or reuse 'data'? Reusing 'data' avoids changes in 6 locale files and in issue.classes.
- Should the data file be allowed to select the locale at all, or should the skeleton provide a locales map (e.g. hydrate(data, locales: (de: my-de, en: my-en)))?
- Should the orphan ctx keys the model already reads (buyer-reference, po-nr, original-invoice-nr) become documented invoice() parameters, so a data file can state BT-10 at document level?
- Identifier encoding: single-key objects ({"gln": ...}) versus {"type": "gln", "id": ...}? The latter must be stripped, or the e-invoice raises IP-KEY-01 on the extra key.
- Should the e-invoice diagnostics be emitted as metadata (for phase-2 bindings and CI) even when zugferd-errors is panic or ignore?
- The check-data doc comment says measure rows are 'checked in root's draw', but the code runs them in root's measure (root.typ:458). This is a harmless doc mismatch, but relevant if the checks are moved.

## Measurements

- Ratio parsing exactness: `typst compile ratio.typ` / `ratio2.typ`. float(n)*1% == literal held for 19, 7, 8.1, 2.6, 3.8, 5.5, 2.1, 20, 22, 13, 0, 10, 4, 21 but FAILED for 9.975%. float(n)/100*100% == literal held for every value tested, including 9.975%, 33.333% and 12.345678%.
- Loader types: json('{"a":0.19,"c":3,"e":1e2}') gives float, int, float. toml 'd = 2026-03-01' gives a datetime. yaml 'd: 2026-03-01' gives the string "2026-03-01", and 'w: 0012' gives the string "0012".
- Tax dict: `typst compile a-tax-dict.typ` → panic 'variable item::tax((rate: 19%, category: "S")) must be of auto | ratio | ... (rate: .., category: ..., label: content | str, grounds: none | content | str)'. b-tax-dict.typ ok (float rate with all 4 keys; tax.new(rate: "0.07")).
- Unit strings: item(unit: "DAY", quantity: "2", price: "10.005") printed '2 DAY 10,0050 €'. unit.day prints '1 Tag'.
- Full prototype: `typst compile --root . --pdf-standard a-3b skeleton.typ` (JSON → XRechnung). The embedded xrechnung.xml contains BuyerReference 04011000-1234512345-06, GlobalID schemeID=0088, ExemptionReasonCode VATEX-EU-132-1J, Skonto line '#SKONTO#TAGE=7#PROZENT=2.00#'. `cmp` against handwritten.typ's XML → byte-identical.
- Timing (5 runs each, wall clock, typst 0.15.1, PDF/A-3b): handwritten 0.44-0.58 s; hydrated skeleton 0.43-0.51 s; import-only 0.18-0.22 s; decode-only 0.20-0.25 s; decode of 103 items 0.21-0.27 s. --timings trace: eval of decode-100.typ was 224 ms, of which 192 ms was evaluating hydrate.typ/lib import, so decoding took about 30 ms.
- Schema issues in draft: `typst compile --input data-file=bad.json skeleton.typ` → report page with 6 problems: invoice-number (check-data) plus 5 schema/\* issues; e-invoice withheld (because of invoice-number). bad2.json (schema issues only) → report shows 2 problems, but `pdfdetach -list` still shows xrechnung.xml embedded. With `--input level=strict` → exit 0 and the XML embedded.
- Machine-readable issues: `typst-0.14.2 query --root . --input data-file=bad.json skeleton.typ "<ip-issue>" --field value` → JSON array of 6 records (id, class, message, ref, fix, field, key, args, instance). `typst eval --in skeleton.typ 'query(<ip-issue>).map(m => m.value.id)'` (0.15.1) → the 6 ids.
- Profile minimums: `typst compile --input profile=<p> --pdf-standard a-3b minimal.typ` with zugferd-errors: report. minimum: factur-x.xml, no errors. basic-wl/basic/en16931: invoice-draft.xml with IP-PAY-06 (en16931 also warns IP-EADDR-01). xrechnung: 5 errors (PEPPOL-EN16931-R010, BR-DE-2, BR-DE-15, IP-PAY-06, BR-DE-1).
- Custom keys: recipient.plz with city '10115 Berlin' → IP-KEY-01 (a warning; compiles). recipient.plz with city 'Berlin' → [IP-KEY-02] error plus BR-DE-9; compilation stops.
- Package sandbox: a local package calling json("/data.json") → 'file not found (searched at pkgpath/local/probe/0.1.0/data.json)'. Passing read("/data.json", encoding: none) from the user's file works (0.14.2 and 0.15.1).
- sys.inputs size: --input data=<70 KB JSON> ok; <214 KB> → bash 'Argument list too long'.

## Notes

#### 0. Experiment files

All experiment files are under `<session>/exp/data-validation-einvoice/`:

- `invoice.json`: the proposed data file (XRechnung-complete)
- `hydrate.typ`: the prototype decoder and `hydrated-invoice`
- `skeleton.typ`: the user skeleton; reads `--input data-file=` and `level=`
- `handwritten.typ`: the same invoice written by hand (its XML is byte-identical)
- `bad.json`, `bad2.json`, `custom-key.json`, `custom-plz*.json`: the error cases
- `minimal.typ`: the per-profile minimum test
- `ratio.typ`, `ratio2.typ`: percent parsing
- `a-tax-dict.typ`, `b-tax-dict.typ`: tax dict and unit tests
- `e-locale2.typ`: locale lookup by name
- `d-pkg*.typ` and `pkgpath/`: package path sandbox test
- `big-input.typ`: the sys.inputs size test

#### 1. Requirements table of `check-data` (src/validation/data.typ:39-125)

| id (= issue id)   | field (locale label key) | when    | test (issue if true)                                     | DE reference           | BT           | fix                                | inline marker?                 |
| ----------------- | ------------------------ | ------- | -------------------------------------------------------- | ---------------------- | ------------ | ---------------------------------- | ------------------------------ |
| invoice-number    | invoice-number           | input   | blank(invoice-nr)                                        | § 14 Abs. 4 Nr. 4 UStG | BT-1         | `invoice(invoice-nr: "2026-0001")` | yes (frame.typ:128)            |
| sender-name       | sender-name              | input   | blank(sender.name)                                       | § 14 Abs. 4 Nr. 1      | BT-27        | `sender: (name: "..")`             | yes (\_party)                  |
| sender-address    | sender-address           | input   | blank(address) AND blank(city)                           | § 14 Abs. 4 Nr. 1      | BG-5         | `sender: (address:, city:)`        | yes                            |
| sender-tax-id     | sender-tax-id            | input   | not \_tax-registered(sender) (see below)                 | § 14 Abs. 4 Nr. 2      | BT-31, BT-32 | vat-id / tax-nr                    | yes (vat-id slot)              |
| recipient-name    | recipient-name           | input   | blank(recipient.name)                                    | § 14 Abs. 4 Nr. 1      | BT-44        |                                    | yes                            |
| recipient-address | recipient-address        | input   | blank(address) AND blank(city)                           | § 14 Abs. 4 Nr. 1      | BG-8         |                                    | yes                            |
| line-items        | line-items               | measure | items.len() == 0                                         | § 14 Abs. 4 Nr. 5      | BG-25        | `#line-items[#item(..)]`           | report only (body part-marker) |
| recipient-vat-id  | recipient-vat-id         | measure | some tax category in (AE, K) and blank(recipient.vat-id) | § 14a Abs. 1, 3        | BT-48        | `recipient: (vat-id:)`             | report only                    |

- `_blank(v)` treats `none`, `""`, `[]` and `()` as blank (data.typ:7).
- `_tax-registered` (data.typ:17-34) passes when any of these hold:
  - the sender gives `vat-id` or `tax-nr`;
  - the tax representative gives `vat-id` or `tax-nr`;
  - the sender's country is not DE and not none, and it gives `legal-id`, `id` or `global-id`.
- Region: `national-law` (data.typ:129-135) has entries for at, ch, fr, it and es. `reference()` joins the national reference with "EN 16931 BT-x". The region passed in is the locale's `meta.region` (invoice.typ:558, root.typ:471), not the sender's country. Only the kind `invoice` exists.
- Flow:
  - invoice() builds `issues = eval-theme.issues + check-data("invoice", "input", (invoice-nr, sender, recipient))`, only when the level is not none (invoice.typ:547-561). These go into `inputs.validation`.
  - Root's measure appends `check-data(.., "measure", (items, taxes, recipient))`, `_bank-issues(view.banks)` and `_direct-debit-issues` (root.typ:458-474), then runs `enforce(issues, level)` (root.typ:477).
  - The XML is withheld when `zugferd != none and issues.any(class in blocking-classes)` (root.typ:483-485).
  - The theme's own issues are enforced at theme build (theming/build.typ:362, theming/scope.typ:26).
  - Render-time findings (footer fit, identity, empty part) panic under strict and are emitted under draft (frame.typ:423-431).
- Other data issues:
  - iban / iban-2..: missing or invalid IBAN; ref EN 16931 BT-84; key iban-missing or iban.
  - creditor-id: BT-90.
  - debtor-iban: BT-91.
  - epc-qr: class lint.
  - All in root.typ:15-96.
- Levels (issue.typ:23,80-121; invoice.typ:195-214):
  - `none`: none of the three classes is checked. The XML follows `zugferd-errors`; with "ignore" it goes out incomplete.
  - `draft`:
    - inline markers ‹fehlt: X›: frame.typ:117-128 uses issues where `field != none`, matched by id;
    - a badge and a watermark;
    - a report page (frame.typ:863-875) listing every `<ip-issue>` of the invoice (render.typ:40-44 collected, dedupe by id);
    - the XML is withheld;
    - the PDF keyword "Draft".
  - `strict`: a panic with `panic-text` (one message verbatim, or a numbered list).
  - CLI: `--input invoice-pro-validation=strict|draft|none` wins over the parameter.
- Misuse never becomes an issue. Wrong types, unknown keys and functions given as ids all panic (issue.typ header; types.require; party-inputs.check-identifiers).

#### 2. What the e-invoice model reads (src/zugferd/model.typ:1253-1629)

`process-zugferd(ctx + (printed:), view.item-data, payment-goal: view.payment-terms, bank: view.bank, payment-means: view.payment-means)` (root.typ:520-526). Its inputs:

**Root ctx (from invoice() args → weave inputs, invoice.typ:563-617):**

- sender: seller, swapped with the recipient when self-billed. Its tax-representative is BG-11.
- recipient: buyer.
- delivery-address: BG-13/BG-15.
- payee: BG-10.
- document-type: the resolved dict with code (BT-3), credit, self-billed, sender-pays, prepayment.
- zugferd: profile.
- tax-mode.
- locale: currency meta, format.currency/currency-fine for IP-PRINT-02, format.date, and strings for payment deadline-soon and reference labels.
- currency: whether it came from the `currency` param or the locale.
- printed: what the theme prints, IP-PRINT-03.
- invoice-nr: BT-1.
- title: IP-DOC-01.
- invoice-date: BT-2.
- buyer-reference: BT-10. An orphan ctx key: invoice() never sets it.
- order-nr / po-nr: BT-13. po-nr is an orphan.
- contract-nr: BT-12.
- delivery-note-nr: BT-16.
- preceding-invoice-nr / original-invoice-nr: BT-25. original-invoice-nr is an orphan.
- preceding-invoice-date: BT-26.
- notes: BT-22/21.
- project: BT-11.
- due-date: BT-9 if a datetime, else BT-20 text.
- references: for the printed service period.
- payment-reference: BT-83, via resolve-payment-reference.
- service-period: BT-72/BG-14, via service-period-of.

**Party keys read (party-keys, model.typ:357-407):**

- seller: name, address, street, city, country, region, id, global-id, legal-id, trading-name, legal-info, vat-id, tax-nr, tax-representative, electronic-address, contact {name, phone, email}, contact-name, phone, email. Printed only, not in the e-invoice: extra, register, management.
- buyer: the address keys, id, global-id, legal-id, trading-name, vat-id, electronic-address, contact, contact-name, phone, email, buyer-reference, leitweg-id, order-nr, po-nr, contract-nr, delivery-note-nr, delivery-address. Printed only: tax-nr, customer-nr, customer-id, order-date, project, quote-nr.
- ship-to: the address keys, id, location-id, global-id.
- tax-representative: the address keys, vat-id.
- payee: name, id, global-id, legal-id.
- The electronic address falls back to the VAT ID (via the EAS table by prefix, model.typ:251-302), then to the email.

**item-data (line-items signal), read by line-models (model.typ:970-1061):**

- Per item:
  - tax {rate, category, implicit};
  - quantity, base-quantity, price, total;
  - discounts + surcharge {absolute, name};
  - item-id {seller, buyer, standard} (a str is the seller id);
  - unit, resolved to a code;
  - pos, name, description, note, date (a datetime or a period), origin.
- taxes: category, rate, basis, absolute, grounds, codes, implicit.
- Totals: net-total, gross-total, prepaid-total, due-total.
- Document level: discounts and surcharges (with split), prepayments.
- tax-mode, dates-printed.

**Payment:**

- payment-terms signal: date, days, discounts {days, percent, basis, note}.
- bank-details signal: iban, bic, account-name, reference/text.
- direct-debit: mandate, creditor-id, debtor-iban.
- card-payment: last4, holder, kind.
- paid: method, kind, terms, date.

**Profile minimums (verified):**

| profile                    | extra required beyond invoice-nr, date, names, address/city, VAT ID, 1 item                                                                                                                                                                                                            |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| minimum                    | –                                                                                                                                                                                                                                                                                      |
| basic-wl / basic / en16931 | payment-terms or due-date (IP-PAY-06); en16931 warns IP-EADDR-01 (buyer electronic address)                                                                                                                                                                                            |
| xrechnung                  | + buyer electronic address (PEPPOL-EN16931-R010); seller contact name/phone/email (BR-DE-2/5/6/7); buyer-reference (BR-DE-15); payment means (BR-DE-1); post codes and cities of the parties (BR-DE-3/4/8/9/10/11); Skonto syntax (BR-DE-18, automatic); allowed type codes (BR-DE-17) |

Rule ids present in rules/engine.typ:

- BR: BR-02, BR-03, BR-05, BR-06, BR-07, BR-09, BR-11, BR-16, BR-25, BR-48, BR-57, BR-62, BR-63, BR-CO-26, BR-S/Z/E/AE/IC/G/O families.
- IP: IP-ADDR/COUNTRY/DEC/DOC/EADDR/ID/KEY/PAY/PERIOD/PREPAID/PRINT/PROFILE/TAX/UNIT.

The diagnostics carry `field` as a dotted input path, e.g. `sender.contact.email`, `recipient.buyer-reference`, `item 2 (Consulting)`.

#### 3. Typed values: constructors and proposed encodings

| value                        | Typst API (verified)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | accepted raw forms                                                                                                                                             | proposed data encoding                                                                                                                                                                                                                                                 |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| date                         | `datetime(year:, month:, day:)`; require-day rejects time-only values                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | datetime only for date/service-period/preceding-invoice-date; due-date/order-date/paid.date/payment-terms.date also take str/content as TEXT                   | `"2026-03-01"` (ISO 8601) → datetime; TOML native dates pass through; a period is `["2026-02-01","2026-02-28"]`                                                                                                                                                        |
| percent                      | `19%`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | ratio                                                                                                                                                          | `"19%"` → `float(n)/100*100%` (bit-exact)                                                                                                                                                                                                                              |
| money / qty                  | decimal-like = decimal, int, float, str (types.typ:53); to-decimal(str)=decimal(str)                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `"120.00"` works directly; `"450,50"` panics                                                                                                                   | decimal string `"120.00"` (exact); JSON numbers allowed (floats are rounded to 15 digits, coercion.typ:3-19)                                                                                                                                                           |
| tax                          | constructors (data/tax.typ): vat(r) S, zero() Z, exempt(grounds:, code:) E, reverse-charge(grounds:, code:) AE, intra-community(grounds:, code:) K, export(grounds:, code:) G, outside-scope(grounds:, code:) O, plus mixed A, lower-rate AA, exempt-for-resale AB, vat-not-due AC, vat-previous AD, transferred B, duty-paid C, margin-travel D, margin-second-hand F, higher-rate H, margin-art I, margin-antiques J, canary-islands L, ceuta-melilla M, standard-additional N; `tax.new(rate:, category:, label:, grounds:, code:)` | ratio (→ region infer-tax, which panics on unknown or 0%) or a dict with ALL of rate/category/label/grounds; category ∈ 22 UNTDID 5305 codes (types.typ:60-83) | `"19%"` (same semantics as Typst `tax: 19%`) or `{"category":"S","rate":"19%"}`, `{"category":"E","code":"VATEX-EU-132-1J","grounds":"…"}`, `{"category":"AE"}` → tax.new / named constructor; the default grounds for AE/K/G/O come from the locale (tax.typ:378-388) |
| exemption code               | `code:` str (VATEX) on new/exempt/reverse-charge/intra-community/export/outside-scope; default codes for AE/K/G/O (model.typ:869-874)                                                                                                                                                                                                                                                                                                                                                                                                  | str                                                                                                                                                            | `"code": "VATEX-EU-132-1J"`                                                                                                                                                                                                                                            |
| unit                         | `unit.hour` etc. are functions of the locale returning (code, name, display) (logic/unit.typ); aliases such as `unit.h`, `unit.stk`, `unit.pauschal`                                                                                                                                                                                                                                                                                                                                                                                   | function; `(display:, code:)`; text (prints verbatim, code resolved via an alias table, IP-UNIT-01/02)                                                         | UN/ECE code `"HUR"` → map to the unit function for H87 SET PR LS HUR DAY MON ANN KGM GRM TNE MTR MTK MMT CMT KMT LTR MTQ; otherwise `{"code":"KWH","display":"kWh"}`                                                                                                   |
| country                      | `country.de` … (32 incl. us, uk/gb); `country.custom(code:, name:, show-always:, post-code: mask, post-code-position:)`                                                                                                                                                                                                                                                                                                                                                                                                                | ISO alpha-2 str (accepted directly), dict {code, name,...}, function                                                                                           | `"DE"`, or `{"code":"NO","name":"Norge"}` (post-code masks need country.custom; maybe a later step)                                                                                                                                                                    |
| identifiers                  | `id.gln(v)` 0088, `id.duns` 0060, `id.siren` 0002, `id.siret` 0009, `id.uid-ch` 0183, `id.register(v, court:)` (no scheme), `id.leitweg(v)` 0204, `id.custom(scheme, id)` → (scheme, id, kind, problems)                                                                                                                                                                                                                                                                                                                               | str (id without scheme), `{scheme, id}` (unchecked), typed dict                                                                                                | `{"gln":"…"}` / `{"siret":"…"}` / `{"leitweg":"…"}` / `{"register":"HRB 4711","court":"…"}` / `{"scheme":"0208","id":"…"}` / plain string; strip helper keys before passing (IP-KEY on extra keys)                                                                     |
| electronic address           | `(scheme:, id:)`; an email string becomes EM                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |                                                                                                                                                                | `"x@y.de"` or `{"scheme":"0204","id":"…"}`                                                                                                                                                                                                                             |
| currency                     | ISO 4217 str, regex `^[A-Za-z]{3}$` (data/currency.typ:49-70)                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | str                                                                                                                                                            | `"EUR"`                                                                                                                                                                                                                                                                |
| document-type                | "invoice", "credit-note", "corrected", "prepayment", "self-billed", or a UNTDID 1001 code (str/int)                                                                                                                                                                                                                                                                                                                                                                                                                                    |                                                                                                                                                                | same                                                                                                                                                                                                                                                                   |
| notes                        | str, or an array of str / {text, subject-code} (logic/notes.typ)                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |                                                                                                                                                                | same JSON                                                                                                                                                                                                                                                              |
| cash discount                | `(days: int>0, percent: 2%, basis:)` (logic/cash-discount.typ)                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |                                                                                                                                                                | `{"days":14,"percent":"2%","basis":"100.00"}`                                                                                                                                                                                                                          |
| modifier / prepayment amount | ratio (relative) or decimal-like (absolute)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |                                                                                                                                                                | `"10%"` is relative, `"5.00"` absolute                                                                                                                                                                                                                                 |
| locale                       | `locale.de-de` (a function `(..overrides, base-lang, base-region)`), customized via `.with(locale.custom.*)`                                                                                                                                                                                                                                                                                                                                                                                                                           | function                                                                                                                                                       | name `"de-de"` → `dictionary(locale).at(name)`, validated by `^[a-z]{2}-[a-z]{2}$` with the non-locale keys excluded                                                                                                                                                   |

`null` and empty values should mean "not given" (auto). Precedent: model.typ:455 `_is-unset`, and country.typ:682-686 ("an empty column of imported data").

#### 4. Schema errors in the draft/strict style

- Record: `issue("schema/" + path, "data", message, ref: "invoice-pro data v1 (" + path + ")", fix: <canonical example>, field: none, key: "schema-type"|"schema-unknown-key"|…, args: (path:, expected:, got:))`. The ids are unique per path, so `dedupe` works.
- Injection point: `issues += decode-issues` next to check-data at invoice.typ:547-561, as a new optional argument or a wrapper. This gives:
  - the draft report row (the chip is "Required data"; the message falls back to English via render.localized);
  - the strict panic (root.typ:477; panic-text lists everything together with the check-data issues);
  - XML withholding (blocking class).
- A body-level `<ip-issue>` emit is NOT enough. Verified: the report is fine, but no withholding and no strict stop.
- If a decoded value is invalid, drop it, so check-data reports it as missing where required (e.g. invoice-nr), and pre-validate everything that would otherwise panic in types.require: tax category, rate string, decimal strings, date strings, identifier types and the unknown-rate infer-tax panic.
- Localized texts are optional: add `strings.validation.issues.schema-*` in de/en/fr/it/es/base. A missing key falls back to the English message (render.typ:142-151).
- Machine-readable output: `typst query file.typ "<ip-issue>" --field value` (0.14) or `typst eval --in file.typ 'query(<ip-issue>).map(m=>m.value)'` (0.15), draft only.

#### 5. Locale

- Built by build-locale (factory.typ:142-189): (lang, strings, format, normalize, currency, tax, meta, resolve-plural).
  - Region base: base.typ:1-103.
    - meta.region;
    - currency (code, symbol, decimals, decimals-fine);
    - normalize: money, money-fine, infer-tax;
    - format: percent, date ([day].[month].[year] by default), time, number, currency, currency-fine, currency-formatters;
    - tax: default-vat, small-enterprise-special-scheme.
  - Lang: every label, the unit names (localized and pluralized), payment sentences, document titles and validation strings.
- invoice() uses the locale for:
  - default-region, which is the country of parties without `country`;
  - the theme env region (the sender's country, else the locale's);
  - the default tax (`tax: auto` → default-vat; small-biz → special scheme);
  - the currency, unless overridden by `currency:`;
  - the subject/title and the legal citations of check-data;
  - text.lang and text.region (root draw).
- Lookup by name works: `dictionary(locale)` has 30 names (de,en,fr,it,es × at,ch,de,es,fr,it) plus lang, region, build-locale and custom. There is no en-us. Prior design notes used `locale.at(d.locale)` (docs/concepts/theming-api/process/designs/user-first.md:505). That clashes with the reserved `.at` of modules/dicts, so it should be `dictionary(locale).at(name)`, or better a dedicated `locale.by-name(name)` (an extension).
- Customizations (`locale.de-de.with(locale.custom.document(invoice: "Proforma"))`) are closures and cannot be serialized. A data-file `locale` therefore can only pick stock locales, and doing so would discard the skeleton's patches.
- Recommendation: the locale is skeleton config. A data file may carry a hint (`"locale": "en-de"`) that the hydrator honors only if the skeleton opts in (a name→locale map or `locale: auto`). `currency` is data (it already has its own param).

#### 6. Package path constraint

A package cannot open user paths (verified with a local package, and theming/data.typ:43-45 states the same for 0.14). The CLI flow is:

- user skeleton/template: `#let data = if "data" in sys.inputs { json(bytes(sys.inputs.data)) } else { json(sys.inputs.at("data-file", default: "invoice.json")) }`
- then: `invoice.with(..design)` plus hydration with `data`.
  Inline JSON is limited by the OS argument length (70 KB ok, 214 KB failed).

#### 7. Prototype decoder (hydrate.typ) as reference

- Decoders return `(value, issues)`: date (regex), ratio (division form), dec (regex `^-?\d+(\.\d+)?$`), unit-of (code map), tax-of (str→ratio, dict→tax.new), id-of (type → id.<ctor>).
- `party()` converts the identifier keys.
- `decode(data)` returns `(args, items, bank, terms, issues, custom)`.
- `hydrated-invoice(data, ..design)` = `invoice(..design, ..args)[line-items + bank-details + payment-terms]`.
- About 150 lines. Its output XML is byte-identical to the hand-written invoice.
