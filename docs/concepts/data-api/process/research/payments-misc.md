# Research: Payment and other body components

Phase-1 reader `payments-misc` of the data-API exploration (2026-11-02). Facts marked [v] were verified (read or run), [i] are inferences. `<repo>` is the repository root, `<session>` the scratch directory of the exploration (not part of the repository).

## Summary

I read all 8 components plus their logic, the theme parts, root and loom, and ran 10 experiments with typst 0.15.1 (two also on 0.14.2). Most of their inputs are flat scalars (str, int, enum, decimal-like). Four kinds of values need converting before a data file can feed them: dates, percentages, money, and content/images. Verified: payment-terms(date: "2026-09-01") is printed raw and lands in the e-invoice as payment-terms text (BT-20), not as a due date (BT-9). Root collects the signals. bank-details may appear several times. payment-terms, direct-debit, card-payment and paid may each appear once, and paid cannot be combined with payment-terms. Which components appear is itself data (the customer pays by transfer, direct debit or card, or has already paid), so a fixed skeleton cannot simply be filled in: it needs a payment slot or block that is chosen from the data. Bank account and creditor ID belong to the sender and stay fixed; terms, mandate, card details and paid method/date change per invoice. Layout knobs (show-reference, qr-code, signature image, where the block sits) belong in the skeleton. dynamic()/info.\* resolve dotted paths against ctx when drawing. With custom data they work as text placeholders, including conditionals such as a coat of arms per postal code (via closures or format:). Custom data can already reach ctx through `recipient: (custom: ..)`, because normalize-party keeps unknown keys, or through apply(), which is scoped to its children and invisible to the frame. dynamic CANNOT bind component parameters (verified: a mandate, a date or a signature name given as dynamic prints nothing). It also has real gaps: info.due-date, info.iban and info.bic are empty in the body; info.total.due and info.total.prepaid are always empty; info.iban in a footer without bank-details stops the compile; the country fields print a raw dictionary. Speed: these components cost little to measure (about 1–2 ms per pass). The one expensive step is drawing the EPC-QR code (sepay calling a WASM plugin, about 40 ms of a 400 ms compile). payment-terms, bank-details and paid read the totals and payment means that root only publishes after the first pass, so they are one reason that pass is needed. direct-debit, card-payment and signature do not depend on it.

## Key facts

- [v] bank-details params: name auto|none|str=auto; bank none|str=none; iban none|str=none (required, a missing or invalid IBAN is reported by validation); bic none|str=none; reference auto|none|str=auto; text none|str=none (cannot be combined with reference); payment-amount auto|none|decimal|float|int|str=auto; show-reference bool=true; account-holder-text auto (declared, never used); qr-code dictionary=(:) with display:bool, size:length (qr-code is not type-checked) (src/components/bank-details.typ:51-130)
- [v] payment-terms params: days none|int=none; date none|datetime|str|content=none; discount none|dict|array=none, each (days:int>0, percent: ratio with at most 2 decimals and 0<p<100, basis?: decimal-like) (src/components/payment-terms.typ:37-58; src/logic/cash-discount.typ:24-96)
- [v] direct-debit(mandate: str|content REQUIRED, creditor-id: str|content REQUIRED, debtor-iban: none|str|content=none); card-payment(last4: str|content REQUIRED, 4-6 digits; holder: none|str|content; kind: auto|"credit"|"debit"=auto); paid(method: auto|cash|cheque|online|transfer|card|direct-debit|(code:str,name:text)=auto; date: none|datetime|str|content=none) (src/components/payment-means.typ:57-84, 162-191, 245-273)
- [v] signature(name: auto|none|str|content=auto, defaults to ctx.sender.name; signature: none|content=none). Its public signal is none, so root never collects it. (src/components/signature.typ:8-40)
- [v] dynamic(..path, default: none, format: auto) is a draw-only content-motif. path may be a closure ctx=>value, strings (split on '.'), arrays (elements NOT split) or ints. A single key goes through about 20 hard-coded shortcut fallback chains; several keys are a plain dictionary traversal plus a few nested fallbacks. format callbacks receive only the value, not ctx. (src/components/dynamic.typ:25-295, 310-327)
- [v] Root measure collects signals: line-items (at most 1), bank-details (array, the first becomes `bank`), payment-terms (at most 1), direct-debit / card-payment / paid (at most 1 each). paid and payment-terms are mutually exclusive, and paid plus a text due-date is an error. The public signal (total, formated-total, bank, payment-means) is injected as ctx.global into the next pass. (src/components/root.typ:189-303; src/invoice.typ:620-626)
- [v] Root draw ctx (used by references and by woven theme-area content) adds references, items, item-data, payment-terms, bank and global(total, formated-total, bank). It drops global.payment-means. The body ctx has only inputs + global, so it has no payment-terms and no bank. (src/components/root.typ:442-456; src/theming/frame.typ:200-203)
- [v] info.due-date, info.iban and info.bic render EMPTY in the body but work in a theme-area content cell. Every other info.\* accessor gives the same value in both places. (exp/payment-misc/e9.typ + pdftotext; dynamic.typ:58-71,132-163 read ctx.payment-terms/ctx.bank which only the root draw ctx has)
- [v] info.total.due and info.total.prepaid are always empty, because the dynamic fallback only maps total.gross/net to formated-total, although formated-total has due and prepaid (src/components/dynamic.typ:250-262; src/components/line-items.typ:354-359; exp e9)
- [v] info.iban (or bic) in a theme area without any bank-details stops the compile with 'type none has no method at' (ctx.bank is none in the root draw ctx) (exp/payment-misc/e2-nobank.typ; src/components/dynamic.typ:133-147; src/components/root.typ:449)
- [v] info.sender.country and info.recipient.country print the raw country dictionary repr; dynamic("lang") returns nothing because the fallback for the single key 'lang' is unreachable (exp e9 output; exp lang.typ (L1=«»); src/components/dynamic.typ:203-207)
- [v] A dynamic used as a component argument prints NOTHING: direct-debit(mandate: info.dynamic(..)), payment-terms(date: info.dynamic(..)), signature(name: info.dynamic(..)) and references value info.dynamic(..). The motif ends up inside draw output and is never woven, yet it passes the non-empty checks. (exp/payment-misc/e6-dyn-arg.typ ("Mandate reference: " empty, "no later than .", signature name empty, 'RefDyn' without value))
- [v] Custom fields already reach ctx: normalize-party keeps unknown keys, so recipient.custom.project-code resolves in body AND footer; recipient.post-code is parsed from city ('10115'); apply(custom: ..) makes ctx.custom visible to its children only, not to the frame or references (src/logic/country.typ:957-985; exp e1 (custom=PRJ-42, plz=10115 in BODY and FOOTER), e3 (FOOTER=NOFRAME, OUTSIDE=NOSCOPE))
- [v] Conditional output per field value (coat of arms per postal code) already works in the skeleton through dynamic closures or format: callbacks (exp e3: F=WAPPEN-BAYERN via info.dynamic(ctx => ..), G=WAPPEN-BERLIN via format: p => ..)
- [v] References accept (label, ctx => value) pairs and closures, evaluated with the root draw ctx, so custom reference rows can bind to data. A dynamic() as the value prints nothing. (src/components/root.typ:410-430; exp e5 ('Projekt PRJ-42'), e6)
- [v] An ISO date string as payment-terms date is printed raw ('bis zum 2026-09-01') and written as BT-20 text (<ram:Description>2026-09-01) instead of DueDateDateTime 20260901; a datetime gives the locale format and BT-9 (exp/payment-misc/e7.typ + pdfdetach factur-x.xml)
- [v] Precedent for data input: theme.custom.from-data turns strings into values without eval and requires an assets: p => image(p) callback because packages cannot open user paths (src/theming/data.typ:1-104)
- [v] The ctx keys 'custom' and 'data' are unused by core; invoice() has no catch-all parameter. Optional inputs join ctx only when given, because each ctx value costs time on long invoices. (grep ctx.custom/ctx.data → none; src/invoice.typ:598-617)
- [v] bank-details(account-holder-text:) is declared and never used (src/components/bank-details.typ:100; docs/concepts/theming-api/process/research/component-contract.md:370 (R11))
- [v] dynamic reads ctx.sender.bank.iban/bic as a fallback, but no other code or doc defines sender.bank: an unfinished 'bank account belongs to the sender' idea (src/components/dynamic.typ:139-147,227-246; grep 'sender.bank' in docs → none)

## Implications

- The data format needs a typed conversion layer like theming/data.typ:\_coerce: ISO date strings become datetime (otherwise the e-invoice semantics change, BT-20 instead of BT-9); money as strings becomes decimal; percent as '2%' or a number becomes a ratio; card last4 must stay a string (leading zeros, the type check rejects int); content-typed params accept strings only; images (signature, coat of arms) are asset keys resolved by an assets: callback in the user document.
- Payment block hydration must be able to choose WHICH components exist, not only fill in arguments (transfer, direct-debit, card, paid; paid excludes payment-terms). Proposal: a new composite such as `payment(..)` / `payment-block(data)` that the skeleton places once and that creates bank-details / direct-debit / card-payment / paid / payment-terms from data. It is an extension; no existing component signature changes. My user-space prototype (e5-hydrate.typ) already works from sys.inputs JSON for both direct debit + terms and card + paid.
- Data vs skeleton split: DATA per invoice = payment.terms (days, date, discount), payment-reference (already an invoice param), payment means choice plus mandate / debtor-iban / card (last4, holder, kind) / paid (method, date), payment-amount override (rare), signer name. Per-sender data (bank, iban, bic, account name, creditor-id) is usually fixed in the skeleton but should be overridable for multi-tenant use; sender.bank is a natural home (dynamic already looks there). SKELETON = placement and order, show-reference, qr-code display/size, signature image, the reference preset and labels, dynamic placeholders and conditional rules.
- dynamic can be the binding mechanism for TEXT placeholders if it gets: (1) a root-level data namespace (new invoice(custom:/data:) parameter, added to ctx only when given) so it works in body, frame and references alike; (2) a specified path grammar (dotted, numeric array index, array form for keys containing dots), namespaced under 'custom.' so the single-key shortcuts cannot shadow custom fields; (3) locale-aware format presets ('date', 'currency', 'number'), because the format: callback gets no ctx; (4) fixes for due-date/iban/bic in the body (publish payment-terms or the resolved due date in root public; read global.bank), total.due/prepaid, the none-bank crash, country rendering and 'lang'; (5) optional required: true that turns a missing field into a validation issue instead of silent emptiness.
- dynamic can NOT bind component parameters. Since the data is known at eval time (json(sys.inputs.data)), parameter hydration should happen before weave: build the component arguments from data. Alternatively components read ctx data in measure when a parameter is auto. Either way it costs no extra loom pass.
- Custom display data already has data-friendly hooks: sender.extra / recipient.extra (dict or array of pairs, printed by themes) and references (dict or array of pairs). But a data-supplied references value replaces the auto legal references (invoice.typ:491-543), so the format needs an additive 'extra references' route to keep the legal defaults.
- Speed: payment-terms, bank-details and paid depend on pass-1 globals (totals, payment-means), and the measure pass is about half of weave time on 100 items (540 of 1029 ms). Skipping it would require computing totals and payment-means before weave; resolve() in logic/payment-means.typ is pure and could be reused. The EPC-QR draw (40 ms) is the only notable per-invoice cost in this group. Keep the custom data dict small: 500 keys in ctx cost +20–30% on a 100-item invoice.

## Risks

- Hydrating ISO date strings without conversion silently changes e-invoice content (BT-20 text instead of a BT-9 due date). This is verified.
- Using dynamic() for parameters looks like it works but prints nothing, and it passes the 'missing' checks (direct-debit mandate), so incomplete data could go out unnoticed. Hydration must resolve parameter values before the call.
- A fixed skeleton containing payment-terms combined with data saying 'paid' stops the compile (root.typ:229-232). Swapping components based on data is a requirement, not a nice-to-have.
- Changing dynamic's single-key shortcuts or the shape of root's public signal can break themes and parts that read ctx.global / view.bank. Fixes should add keys (e.g. publish payment-terms/due-date in root public) rather than rename them.
- Large custom data in ctx slows every component call: 500 keys in recipient.custom gave 1.59–1.73 s → 2.02–2.13 s on 100 items. Keep the custom namespace small, or resolve it outside the loom tree.
- Packages cannot read user file paths, so signature images, coat-of-arms images and logos from data need an assets callback in the user's document (precedent: theming/data.typ:94-101). Phase-2 bindings cannot hand over raw image bytes through sys.inputs (strings only).

## Open questions

- Should the custom data namespace be a new invoice(custom: ..) parameter, a generic invoice(data: ..) holding the entire hydrated dictionary, or both? It must be visible to body, frame and references, which apply() is not.
- Should payment hydration be a new composite component (payment-block) or 'auto reads ctx.data' semantics on each existing component? The composite keeps today's semantics untouched; the auto route spreads data-lookup logic over five components.
- Should bank account data move to sender.bank (as dynamic.typ already assumes), letting bank-details(iban: auto) default to it? That would be an extension that makes bank-details hydratable without arguments.
- Should root publish payment-terms / due-date in its public signal so info.due-date works in the body? That is an additive change to the global shape; check which themes read ctx.global.
- Should a missing bound field be reported through the validation system (draft marker, strict panic)? That would give the hydration layer the same strictness as typed invoice params.
- Pass-skipping: is it acceptable to compute totals and payment-means before weave from data and run weave with max-passes: 1? The risk is that the pre-computed and the measured totals disagree.

## Measurements

- Payment block cost (1-item invoice, typst 0.15.1, best of 5 wall clock, `typst compile --root $EXP p-<n>.typ`): none 0.277 s, payment-terms+bank-details(QR)+signature 0.333 s, terms+direct-debit+bank 0.314 s, paid(card)+bank 0.299 s, terms+bank with qr-code: (display: false) 0.298 s
- Trace of p-pay (`typst compile --timings t-pay.json`, inclusive, no double counting): sepay epc-qr-code → rustycure plugin 40.0 ms (the entire bank-details draw); bank-details measure ×2 passes 2.0 ms; payment-terms scope ×2 1.8 ms, measure ×2 0.9 ms; signature scope ×2 1.1 ms; root measure ×2 2.4 ms; info module creates 43 dynamic motifs on import, 3.4 ms
- 100-item invoice trace (b-plain.typ): weave 1029 ms, of which the measure loop (runtime.typ:73, pass 1) is 540 ms; total compile 2036 ms
- dynamic placeholders: 600 info.\* placeholders (p-dyn200) 0.53–0.55 s vs none 0.37–0.42 s vs 600 literal words (p-txt600) 0.70–0.86 s; closure form (p-dyn200fn) 0.63 s. dynamic itself is cheap.
- ctx size, 100 items (b-\*.typ, best of 5): plain 1.59–1.73 s; recipient.custom with 20 keys 1.68 s (within noise); recipient.custom with 500 keys 2.02–2.13 s; apply(custom: 500 keys) around everything 1.78–1.89 s
- Hydration prototype: `typst compile --root $EXP --input data=data1.json e5-hydrate.typ` (direct debit + terms with discount '2%' coerced) and data2.json (card + paid with ISO date coerced) both render correctly on 0.15.1 and 0.14.2; inline JSON through `--input 'json={...}'` with json(bytes(sys.inputs.json)) works on 0.14.2

## Notes

All experiment files are in <session>/exp/payment-misc/. Trace scripts are in <session>/scripts/ (trace2.py, bysrc.py).

#### 1. Parameter tables (verified by reading the source)

##### bank-details (src/components/bank-details.typ:51-108)

| param               | type                                                 | default | DATA / LAYOUT                                                   | notes                                                                                                                               |
| ------------------- | ---------------------------------------------------- | ------- | --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| name                | auto \| none \| str                                  | auto    | sender-static (account holder); data only for multi-tenant use  | auto = payee name (not on a credit note), else sender name-inline, else recipient when the sender pays; becomes BT-85 only if given |
| bank                | none \| str                                          | none    | sender-static                                                   | printed only                                                                                                                        |
| iban                | none \| str                                          | none    | sender-static (the recipient's account on a credit note)        | required: a missing or invalid IBAN is a data issue (root.typ:15-60)                                                                |
| bic                 | none \| str                                          | none    | sender-static                                                   |                                                                                                                                     |
| reference           | auto \| none \| str                                  | auto    | per-invoice DATA (structured, max 35 bytes for the EPC-QR code) | auto → invoice payment-reference (as text) → invoice-nr (logic/payment-reference.typ:21-39)                                         |
| text                | none \| str                                          | none    | per-invoice DATA (unstructured, 140)                            | cannot be combined with reference (assert :127)                                                                                     |
| payment-amount      | auto \| none \| decimal-like (decimal,int,float,str) | auto    | rare DATA                                                       | auto = global.total.due ?? gross                                                                                                    |
| show-reference      | bool                                                 | true    | LAYOUT                                                          |                                                                                                                                     |
| account-holder-text | auto (unchecked)                                     | auto    | dead param                                                      | never used (R11)                                                                                                                    |
| qr-code             | dict (display: bool, size: length)                   | (:)     | LAYOUT                                                          | not type-checked; display default = transfer requested and not the recipient's account                                              |

##### payment-terms (src/components/payment-terms.typ:37-58)

| param    | type                                                                                                | default | class                                                                                  |
| -------- | --------------------------------------------------------------------------------------------------- | ------- | -------------------------------------------------------------------------------------- |
| days     | none \| int                                                                                         | none    | DATA (per customer/invoice)                                                            |
| date     | none \| datetime \| str \| content                                                                  | none    | DATA. A str is printed raw and becomes BT-20 text, not BT-9 (verified e7)              |
| discount | none \| dict \| array of (days:int>0, percent:ratio 0<p<100 with ≤2 decimals, basis?: decimal-like) | none    | DATA. percent MUST be a ratio (cash-discount.typ:64); not allowed when the sender pays |

##### direct-debit / card-payment / paid (src/components/payment-means.typ)

| comp         | param       | type                                                                                  | default        | class                                              |
| ------------ | ----------- | ------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------- |
| direct-debit | mandate     | str \| content, REQUIRED                                                              | none (asserts) | DATA per customer                                  |
|              | creditor-id | str \| content, REQUIRED                                                              | none           | sender-static (check digits verified in EUR)       |
|              | debtor-iban | none \| str \| content                                                                | none           | DATA per customer (XRechnung requires it)          |
| card-payment | last4       | str \| content, 4-6 digits REQUIRED                                                   | none           | DATA per invoice (must be a string: leading zeros) |
|              | holder      | none \| str \| content                                                                | none           | DATA                                               |
|              | kind        | auto \| "credit" \| "debit"                                                           | auto           | DATA (BT-81 48/54/55)                              |
| paid         | method      | auto \| cash\|cheque\|online\|transfer\|card\|direct-debit \| (code: str, name: text) | auto           | DATA                                               |
|              | date        | none \| datetime \| str \| content                                                    | none           | DATA (convert ISO strings)                         |

direct-debit and card-payment panic when the sender pays (:38-45). All three refuse to sit inside line-items (guards).

##### signature (src/components/signature.typ:8-40)

| param     | type                           | default            | class                                                          |
| --------- | ------------------------------ | ------------------ | -------------------------------------------------------------- |
| name      | auto \| none \| str \| content | auto (sender.name) | DATA-ish (signing clerk) or fixed                              |
| signature | none \| content                | none               | SKELETON asset (image); a data file can only name an asset key |

##### dynamic (src/components/dynamic.typ:310-327) and info (src/public/info.typ)

`dynamic(..path, default: none, format: auto)`; `info.dynamic` = `info.get` = dynamic. Pre-bound: invoice-nr, invoice-date, date, due-date, customer-nr, order-nr, order-date, project, contract-nr, quote-nr, delivery-note-nr, preceding-invoice-nr, preceding-invoice-date, payment-reference, buyer-reference, subject, iban, bic; sender.{name, trading-name, legal-id, legal-info, tax-nr, vat-id, address, city, country, email(contact.email), phone}; recipient.{name, trading-name, legal-id, tax-nr, vat-id, address, city, country, buyer-reference, customer-nr}; total.{gross, net, due, prepaid}. These are LAYOUT (binding points), never data.

##### references.\* (src/public/references.typ → src/logic/references.typ)

27 builders, each `(label: auto, value: auto)` returning `ctx => (title, value)`: tax-nr, vat-id, invoice-nr, invoice-date*, service-time*, customer-nr, buyer-reference, recipient-vat-id, recipient-tax-nr, seller-tax-nr, seller-vat-id, buyer-vat-id, payee, order-nr, order-date*, project, contract-nr, quote-nr, delivery-note-nr, delivery-address, preceding-invoice-nr, preceding-invoice-date*, due-date*, payment-reference, contact-person, contact-phone, contact-email (* = require-day check on value). 4 presets without params: preset-b2b, preset-b2g, preset-project, preset-din-5008. Which builders appear and their labels = SKELETON; values come from invoice-level data. Root evaluates them in its draw pass (root.typ:323-440), identifying builders by function identity. It also accepts (label, value), (label, ctx => value) and raw closures (verified e5: ("Projekt", ctx => ctx.recipient.custom.project-code) prints PRJ-42).

#### 2. Signals and how root collects them

| component     | frame kind                | public signal (→ root)                                                                                     | view (→ theme part)                                                                                                                                                                                                 | pass-1 global deps                                                 |
| ------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| bank-details  | "bank-details"            | (iban raw, iban-valid, qr-problems, bic raw, account-name, reference, text, payment-amount)                | v1 sender(name,bank,iban,iban-valid,bic), qr-code(size,display,payload,problems), reference, text, show-reference, report-problems, payment-amount; v2 iban(value,text,valid), payment-reference, qr(size=>content) | global.total.due/gross (amount), global.payment-means (QR default) |
| payment-terms | "payment-terms"           | = view: days, date, total, amount(value,text), amount-kind, deadline, payment-means kind, discounts(+note) | same; draw swaps ctx.locale.strings.payment for the means sentence                                                                                                                                                  | global.total.{gross,due,prepaid}, global.payment-means             |
| direct-debit  | "direct-debit"            | mandate, creditor-id (normalized), debtor-iban, creditor-id-valid, debtor-iban-valid                       | kind, text:none, details[(label,value,valid)], report-problems                                                                                                                                                      | none                                                               |
| card-payment  | "card-payment"            | last4, holder, kind                                                                                        | kind:"card", details                                                                                                                                                                                                | none                                                               |
| paid          | "paid"                    | method, kind, date, terms (printed lines → BT-20)                                                          | kind:"paid", text, details                                                                                                                                                                                          | global.total, global.payment-means                                 |
| signature     | "signature"               | none (not collected)                                                                                       | name, signature                                                                                                                                                                                                     | none                                                               |
| dynamic       | (content-motif, no frame) | passes children through                                                                                    | —                                                                                                                                                                                                                   | reads global in the draw pass                                      |

Root measure (root.typ:189-303) does the following:

- It asserts at most one line-items, payment-terms, direct-debit, card-payment and paid; paid XOR payment-terms; paid with a text due-date is forbidden.
- It calls resolve-payment-means(banks, dd, card, paid), a pure function at logic/payment-means.typ:116-136.
- Its public signal is (total, formated-total, bank = first bank-details, payment-means). The injector (invoice.typ:623-625) turns it into ctx.global for the next pass.
- Its view adds item-data, payment-terms, banks.

The root draw ctx (root.typ:442-456) adds references, items, item-data, payment-terms, bank and global = (total, formated-total, bank). Note: payment-means is dropped there. ZUGFeRD gets payment-goal = the payment-terms signal, bank, and payment-means (root.typ:518-524; zugferd/model.typ:1160-1200, 1440-1500).

#### 3. dynamic path resolution today (dynamic.typ:25-295)

1. If the first argument is a function, it is called as fn(ctx), with default on none.
2. Keys are flattened: a str containing '.' is split; array elements are added as given (no split) → dotted keys only reachable through the array form (verified I2/I3); ints become str.
3. A single key goes through the shortcut chains (invoice-nr, date, due-date via ctx.payment-terms, customer-nr, order-nr/po-nr, order-date, project, contract-nr, quote-nr, delivery-note-nr, preceding-invoice-nr, payment-reference via bank-signal, buyer-reference/leitweg-id, subject, tax-nr, vat-id, iban/bic via ctx.bank or ctx.sender.bank), else ctx.at(key).
4. Several keys are a dictionary-only traversal (no array index: verified I1), then fallbacks for locale.region(.code), region.code, locale.lang, bank.iban/bic, total.gross/net → global.formated-total.
5. Formatting: format(val) if it is a function; else datetime → locale date; array → joined with ', '; a dict with id → .id; else [#val]. A dict without id prints its repr (country, sender.extra pairs, verified).

Verified body vs footer table (e9): everything matches except due-date, iban and bic (empty in the body). total.due and total.prepaid are empty in both. country prints the dict repr. dynamic("lang") is empty (dead branch).

#### 4. What dynamic would need to become the custom-field binding

- **Data source:** ctx.custom (or ctx.data) set at root through a new invoice param, added only when given (invoice.typ:598-617 pattern). Root inputs reach the body, the frame areas (eval-content with the root draw ctx, frame.typ:200-203) and the references closures. apply(custom:) only reaches its children (verified NOFRAME/NOSCOPE).
- **Path grammar:** a documented spec for phase-2 bindings: dotted segments, numeric index on arrays, array form for keys with dots, and a 'custom.' prefix to avoid the shortcut shadowing at dynamic.typ:52-166.
- **Formatting:** presets that use ctx.locale.format (date, currency, number, percent), because format: v => .. gets no ctx; raw global values print as '119.00'.
- **Conditionals:** these already work as skeleton closures (verified WAPPEN-BAYERN / WAPPEN-BERLIN). Optional sugar: a match/switch helper (`dynamic("recipient.post-code", cases: ("80": [..]), prefix: true)`). Images come from the user document (assets).
- **Validation:** a missing bound field could raise issue() at draft or strict level instead of printing nothing.
- **Limit:** content only, draw only, no influence on computations or the XML, unusable as a component argument (verified e6). Parameter binding must happen at eval time from the parsed data, or through components reading ctx data in measure when a param is auto.

#### 5. Data-file realism

Carried by the data file:

- payment.terms {days, date (ISO), discount[{days, percent "2%", basis "100.00"}]}
- payment-reference (invoice level)
- payment.means as a choice: transfer | direct-debit {mandate, debtor-iban} | card {last4 "4242", holder, kind} | paid {method or {code, name}, date}
- payment.amount override (rare)
- signer name
- custom {..}
- optional sender.bank {iban, bic, bank, account-name} and sender.creditor-id for multi-tenant setups

Skeleton: placement and order of the payment block, show-reference, qr-code display/size, signature image, closing strings (locale), reference preset and labels, dynamic placeholders and conditional rules, extra-reference labels.

#### 6. Prototype (e5-hydrate.typ)

`json(sys.inputs.at("data"))` is read from the user document; date-of() converts ISO strings to datetime; pct() converts "2%" to a ratio; payment-block(p) creates direct-debit / card-payment / bank-details, then paid XOR payment-terms. Custom values come in through apply(custom:) and recipient.custom; references use ("Projekt", ctx => ..). Output verified for both data files: direct-debit sentence + Skonto note; card + paid sentence 'wurde am 15.08.2026 bezahlt'.
