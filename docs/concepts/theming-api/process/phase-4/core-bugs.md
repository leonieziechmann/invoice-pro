# Core bugs found during phase 4 (verified against invoice-pro 0.4.2)

I checked all 10 claims against the real 0.4.2 code, working on a copy (<session>/v2/core-bugs, called CB below). The project repo was not changed. Each repro is in CB/tests/cNN-\*.typ. Every one compiles and behaves the same on typst 0.15.1 (Windows) and 0.14.2 (WSL, script CB/run-014.sh, outputs in CB/out014). Only the expected BT-10 panic in c08 fails to compile, on both versions. I tried the main fixes in a patched copy, CB/dbg (throwaway; the patches are listed per bug).

- Confirmed and affecting 0.4.2: 1 (units never pluralise; a real bug, not user error), 2, 3, 6, 7, 8, 9, 10.
- Claim 3 is worse than reported. Any item-id makes factur-x.xml fail the schema check (Mustang 2.14: "schema validation fails", GlobalID after Name). A dictionary item-id is silently dropped by a missing `return` in to-item-id. The `buyer` id is never written. After the fix the XML validates (Mustang reports "valid").
- Claim 4 is false. The default renderer prints "Verwendungszweck: <invoice-nr>". But while checking it I found a real, related bug (bug 11 below): invoice(payment-reference:) is ignored everywhere, and the XML payment reference (BT-83) is always the invoice number. The printed reference and the one in the XML can therefore differ.
- Claim 5 does not exist in 0.4.2. There is no emphasis box there. It is a bug in the prototype's totals part (v2 base/final src/theming/parts/body.typ:78). I confirmed it in the prototype copy CB/proto. It only needs fixing if a preset keeps a filled totals box.
- Claim 7: in 0.4.2 there is no panic (the 'notes returned no content' panic is prototype-only). The small-business clause is just left out silently when the language code equals the region code and the region has no legal text for the scheme. That hits test-locale (base/base) and any custom override like de-de plus tax(small-enterprise-special-scheme: tax.outside-scope()). All shipped locales have the legal text and are not affected.
- Claim 8 is documented behaviour (en16931 with a German seller and buyer is switched to xrechnung). The error message still confuses users, and forcing XRechnung's BT-10 and seller-contact rules onto domestic B2B is worth reconsidering.
- Claim 9: the root component asks for a top-level locale "lang" key that the locale factory never provides, so the language is always 'de'. Effects: letter-pro prints "Seite x von y" in en/fr/it invoices, hyphenation is German, and the PDF language is de. The one-line fix makes it print "Page 1 of 9" for en.
- Claim 10: `set page` sits inside an if block, so it has no effect outside it. This hits the blank theme (and any theme built on base-theme). The DIN-5008 footer takes a separate path and works. The fix (set ... if ...) works.
- Claim 6: fix idea tested standalone on both compilers: an unbreakable rowspan cell keeps an item's rows together (CB/tests/c06-rowspan-proof.typ).

Side observations, not written up as bugs:

- When the unit column is hidden, the table notes print 'Menge für alle Artikel: 1' (also seen in the English invoice).
- In c06 at off=55, the repeated table header ends up on page 2 with no item rows under it, only the totals (same as the design review's totals-widow finding).

I did not run scripts/run-all.sh; this task has no prototype runner, and all evidence is repro compiles.

## XML item identifiers: any item-id makes factur-x.xml schema-invalid, dict item-id silently dropped, buyer id never emitted, plain string mapped to GTIN (0160)

- Verified: true
- Affects 0.4.2: true
- Severity: compliance
- Location: src/utils/coercion.typ:92 (dict branch value not returned; the trailing `return none` wins); src/zugferd/build.typ:410-421 (buyer never emitted; string -> GlobalID 0160) and 461-464 (item-ids appended after ram:Name, which breaks the XSD order); docs/docs/api-reference/line-items/index.md:70
- Repro: CB/tests/c03-itemid.typ (compile with --pdf-standard a-3b, extract with pdfdetach). Output: item-id "ART-4711" -> <ram:SpecifiedTradeProduct><ram:Name>String id</ram:Name><ram:GlobalID schemeID="0160">ART-4711</ram:GlobalID>; item-id (seller:,buyer:,standard:) -> <ram:SpecifiedTradeProduct><ram:Name>Dict id</ram:Name></ram:SpecifiedTradeProduct> (all ids lost). Mustang 2.14 validate: 'Error 18: schema validation fails ... Invalid content was found starting with element GlobalID. One of Description,... is expected', summary invalid. Same on 0.14.2 (CB/out014/x/factur-x.xml). With the fix in CB/dbg: GlobalID, SellerAssignedID, BuyerAssignedID, Name in order; Mustang summary valid.
- Fix: coercion.typ: `return (seller: ..., buyer: ..., standard: ...)` in the dictionary branch. build.typ: emit `item-ids + ("ram:Name": name)` so the order is GlobalID, SellerAssignedID, BuyerAssignedID, Name; add `if item-id.buyer != none { item-ids.insert("ram:BuyerAssignedID", item-id.buyer) }`. Trap for plain strings: in 0.5.0 map a plain string to SellerAssignedID (article number), or only use GlobalID 0160 when the string is a valid GTIN-8/12/13/14 (digits plus mod-10 check digit), else SellerAssignedID. Update the docs line and add an XML regression test that checks element order and all three ids.

## Units never pluralise (preset units and singular/plural dicts always show singular: '2 day', '24 piece', '2,5 Stunde')

- Verified: true
- Affects 0.4.2: true
- Severity: major
- Location: src/components/item.typ:185 (and the same pattern in src/components/bundle.typ:112)
- Repro: CB/tests/c01-units.typ -> CB/out/c01-1.png (en-de: '2 day', '24 piece', '2,5 hour', dict unit (singular: "Stunde", plural: "Stunden") at qty 3 -> '3 Stunde', default unit '3 piece'); page 2 de-de: '2 Tag', '2,5 Stunde'. Plain string unit "Stunde" prints '3 Stunde' = user choice (a string has no plural form; pass a dict or a unit preset). Same on 0.14.2. With the fix in CB/dbg: '2 days', '24 pieces', '2,5 hours', '1 hour', '3 Stunden', '2 Tage', '2,5 Stunden'.
- Fix: The plural logic (logic/unit.typ resolve and resolve-plural in each language) works, but the quantity passed in is `ctx.at("quantity", default: 1)`. `ctx` is the parent context at scope time, so this item's own quantity (derived in the same batch) is never seen and plurals always get 1. Use `quantity: if quantity != auto { coercion.to-decimal(quantity) } else { ctx.at("quantity", default: decimal("1")) }`. Do the same in bundle.typ with the bundle quantity argument.

## Payment sentence says 'Gesamtbetrag'/'total amount' but prints the amount due when prepayments exist

- Verified: true
- Affects 0.4.2: true
- Severity: major
- Location: src/components/payment-goal.typ:49 (total = due); src/themes/base-theme/payment-goal.typ:21; strings src/locale/lang/de.typ:130, en.typ:130, fr.typ:139, es.typ:141, it.typ:141, base.typ:148
- Repro: CB/tests/c02-c04-c05.typ -> CB/out/c02-1.png: totals show Gesamtbetrag 1.190,00 €, Anzahlung -500,00 €, Fälliger Betrag 690,00 €; the sentence reads 'Bitte überweisen Sie den Gesamtbetrag in Höhe von 690,00 € innerhalb von 14 Tagen'. Same on 0.14.2.
- Fix: In payment-goal measure, also expose `has-prepayments: ctx.global.total.at("prepaid", default: 0) > 0` (or compare due with gross). Add a locale string payment.text-due (de: 'Bitte überweisen Sie den fälligen Betrag in Höhe von _#sum_ #deadline ...', en: 'the amount due of', fr: 'le montant restant dû de', it: "l'importo dovuto di", es: 'el importe pendiente de') and a custom.payment(text-due:) override. The renderer picks text-due when there are prepayments.

## An item row and its description (and modifier) rows split across a page break

- Verified: true
- Affects 0.4.2: true
- Severity: major
- Location: src/themes/components/line-items/table.typ:388-535 (build-item-rows: top cap, main row, description row, modifier rows and bottom cap are separate table rows; left-spacer at 407)
- Repro: CB/tests/c06-split.typ with --input off=58 -> CB/out/c06-off58-2.png: item 8's title is the last row of page 1; page 2 starts with the repeated header, then 'Beschreibung zu Position 8 ...' alone with no title or amount. A sweep of offsets 40..110 hits this every 15mm (off=58/61, 73/76, 88/91, ...). Same on 0.14.2 (CB/out014/c06.pdf). Fix proof: CB/tests/c06-rowspan-proof.typ with keep=1 never starts a page with a DESC row (0.15.1 and 0.14.2); keep=0 does at off=0/8/11.
- Fix: Make the item's left spacer column a single `table.cell(rowspan: <number of rows of this item>, breakable: false, ...)` that covers the top cap, main row, description row(s), modifier rows and bottom cap, instead of one spacer per row. Typst (0.12+, verified on 0.14.2/0.15.1) then keeps all rows an unbreakable rowspan covers on one page. Alternative: render title and description in one cell. Watch very long descriptions: an unbreakable item taller than a page overflows, so fall back to breakable when the description is long (or accept the overflow).

## ctx.locale.lang is always 'de': text.lang, hyphenation, PDF language and page labels ('Seite x von y') are German for en/fr/it/es locales

- Verified: true
- Affects 0.4.2: true
- Severity: major
- Location: src/components/root.typ:62 (ensure("lang", "de") on a key the factory never provides) and root.typ:158 (set text(lang: ctx.locale.lang))
- Repro: CB/tests/c09-lang.typ: 'LANGPROBE en-de text.lang=de', 'fr-fr text.lang=de', 'it-it text.lang=de'; the footer reads 'Seite 1 von 9' for en-de/fr-fr/it-it (also visible in CB/out/c01-1.png, an English invoice with 'Seite 1 von 2'). Same on 0.14.2. With the fix in CB/dbg: 'text.lang=en ... Page 1 of 9', 'text.lang=fr'.
- Fix: src/locale/factory.typ returns strings.meta.lang but no top-level `lang`, so ensure("lang", "de") always wins. Use `set text(lang: ctx.locale.strings.meta.lang, region: region-code)`, or add `lang: final-lang.meta.lang` to the factory result and drop the 'de' default. Guard against the base language code 'base' (fall back to 'en').

## invoice(payment-reference:) is ignored; XML BT-83 is always the invoice number, even when bank-details(reference:) prints something else

- Verified: true
- Affects 0.4.2: true
- Severity: major
- Location: src/components/bank-details.typ:92 (put("reference", ctx.invoice-nr)); src/zugferd/build.typ:706 ("ram:PaymentReference": invoice-nr-str)
- Repro: CB/tests/c11-payref.typ (payment-reference: "VZ-PAYREF-99", bank-details(reference: "BANK-REF-7"), invoice-nr RE-2026-042): the PDF prints 'Verwendungszweck: BANK-REF-7', factur-x.xml has <ram:PaymentReference>RE-2026-042, and VZ-PAYREF-99 appears nowhere. CB/tests/c02-c04-c05.typ: with payment-reference set and no bank reference, the bank block prints RE-2026-042. Found while checking claim 4.
- Fix: bank-details scope: default the reference to `ctx.at("payment-reference", default: none)`, falling back to ctx.invoice-nr (matching docs/docs/api-reference/invoice/references.md:104). build.typ: BT-83 = bank.text or bank.reference from the bank signal if present, else ctx.payment-reference, else invoice-nr, so the printed text, EPC-QR and XML always agree.

## base-theme header/footer slots never render (set page inside an if block)

- Verified: true
- Affects 0.4.2: true
- Severity: minor
- Location: src/themes/base-theme/base.typ:35-40
- Repro: CB/tests/c10-slots.typ (themes.blank.with(header: [HEADERPROBE], footer: [FOOTERPROBE])): pdftotext finds 0 probes on 0.15.1 and 0.14.2. With the fix in CB/dbg both probes render.
- Fix: `set` rules only apply inside their block, so the page setup ends with the `if`. Replace with `set page(header: eval-content(ctx, header)) if header != none and header != []` and the same for footer, before `document(ctx, body)` (verified; the argument is only evaluated when the condition holds). DIN-5008's own footer takes a different path (letter-generic) and is not affected.

## Small-business clause silently omitted when lang code equals region code and the region scheme has no grounds (test-locale, custom overrides)

- Verified: true
- Affects 0.4.2: true
- Severity: minor
- Location: src/themes/components/line-items/global-info.typ:113-118
- Repro: CB/tests/c07-smallbiz.typ with tax-exempt-small-biz: true: A test-locale (lang 'base' = region 'base') has no clause; B de-de + locale.custom.tax(small-enterprise-special-scheme: tax.outside-scope()) has no clause; C en-de with the same override prints 'No VAT is charged due to small business exemption.'; D de-de prints '§ 19 UStG ...'. No panic in 0.4.2 (the 'notes returned no content' panic is prototype-only). All shipped locales have grounds and are not affected. Same on 0.14.2.
- Fix: In the lang-eq-region branch, fall back to the translated legal.vat-exemption text when legal-grounds is none (as the else branch does): `if legal-grounds != none {push legal-grounds} else {push grounds}`. Optionally warn/validate when small-biz mode ends up with no text at all.

## zugferd 'en16931' with German seller and buyer is promoted to 'xrechnung'; a missing BT-10 panics with a message about profile 'xrechnung'

- Verified: true
- Affects 0.4.2: true
- Severity: minor
- Location: src/zugferd/build.typ:650-657 (promotion) and 832-860 (xrechnung-only messages)
- Repro: CB/tests/c08-bt10.typ (zugferd: "en16931", de-de, DE seller and buyer, no buyer-reference): 'panicked with: e-invoicing (profile 'xrechnung') requires a buyer reference (BT-10). Set 'buyer-reference' or 'leitweg-id' on the recipient.' Same on 0.14.2 (message quoted). The promotion is documented in docs/docs/e-invoicing.md:65 and api-reference/invoice/index.md:194.
- Fix: Minimum: word the messages as "zugferd: \"en16931\" between two German parties is issued as XRechnung 3.0 (see docs); XRechnung requires a buyer reference (BT-10) ...". Better (maintainer decision): only promote when explicitly asked (zugferd: "xrechnung") or when a leitweg-id/buyer-reference is present (B2G). Plain EN 16931 is enough for German B2B, and forcing BT-10 and BG-6 on B2B invoices is stricter than the law requires. In 0.5.0 this becomes an e-invoice issue in the validation levels.

## Default bank-details renderer never prints the payment reference (claim refuted)

- Verified: false
- Affects 0.4.2: false
- Severity: cosmetic
- Location: src/themes/base-theme/bank-details.typ:46-50
- Repro: CB/tests/c02-c04-c05.typ -> CB/out/c02-1.png: the default renderer prints 'Verwendungszweck: RE-2026-042' (invoice-nr default) and 'Verwendungszweck: EXPLICIT-REF' for reference:. Same on 0.14.2. Nothing prints only when invoice-nr is none and no reference is given. The real defect nearby is the payment-reference inconsistency reported separately.
- Fix: None needed for the claim. See the payment-reference bug. The observation probably came from a prototype look or a test without invoice-nr.

## Totals emphasis box renders left-aligned (prototype only, not 0.4.2)

- Verified: true
- Affects 0.4.2: false
- Severity: cosmetic
- Location: prototype v2/final (and base) src/theming/parts/body.typ:78
- Repro: 0.4.2 has no emphasis box (render-totals in src/themes/components/line-items/totals.typ has no fill option). Prototype: CB/proto/tests/c05.typ (theme.modern, copy of v2/final) -> CB/proto/out/c05-1.png: the tinted totals box sits at the left edge of the text column instead of the right.
- Fix: Wrap as `align(right, block(fill: o.emphasis-fill, inset: t.spacing.md, radius: 2pt, width: o.width, render-totals(..., totals-width: 100%)))`. Put the width on the filled block and let the inner grid fill it; right-align the block (use the layout's totals alignment if one is added). Only matters if a final preset (corporate/soft) keeps a filled totals box; modern is being removed.
