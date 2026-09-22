## designer looks-a (<session>/v2/looks-a)

report: NOT WRITTEN: the harness refused to write REPORT.md (subagents may not write report files). The report content is carried in these fields. Evidence logs: looks-a/out/run-all-0151.log (0.15.1: 95/95 ok

### elegant alt=counsel/chancery layout=din-5008-b (existing layout: form B's 37 mm letterhead zone gives the centred letterhead room; on din-5008-a the renderer puts the logo beside the name) new=

audience: Law firms, notaries, tax advisers, auditors, management consultancies. Gallery: German law and tax partnership, de-DE, hourly fees in two mandate groups plus disbursements.
checks: m015=true m014=true contrast=true pdf=true
file: <session>/v2/looks-a/src/theming/looks/elegant.typ
renders:

- <session>/v2/looks-a/gallery/elegant-din-5008-b-1.png
- <session>/v2/looks-a/gallery/elegant-din-5008-b-2.png
- <session>/v2/looks-a/gallery/elegant-a4-digital-logo-1.png
- <session>/v2/looks-a/gallery/elegant-a4-digital-logo-2.png
- <session>/v2/looks-a/gallery/matrix-elegant.png
- <session>/v2/looks-a/gallery/stress-totals.png
- <session>/v2/looks-a/out014/gallery-elegant-1.png
  intent: The page reads like a letter from a chambers: a centred letterhead in widely spaced Libertinus Serif capitals over a short ink rule, one hairline family for every divider, and no filled areas at all. Hierarchy comes from typography alone: labels in small spaced capitals, the document word centred between hairlines, semibold item names, and the payable amount set between a thin rule and the accountant's double rule. The single colour is a deep ink blue (#1c2a48), used only for the letterhead, labels and the total, so the invoice stays quiet, credible and cheap to print. TOKENS: primary #1c2a48; text #1e1e1e; text-muted #5a5f69; border t=>primary.lighten(45%); tint t=>primary.lighten(94%); fon
  friction:
- F1 Footer styling eats the legal footer's margin. A region inset adds height, and looks may not change margin.bottom, so a look's footer decoration can trigger the footer-fit panic (no preview) with data that fits under classic. elegant needed inset 0.8mm and fine 7pt to keep classic's headroom. Fix
- F4 `parts` is not look-safe, so the centred letterhead cannot put the logo above the name (DIN hosts (logo, sender), US hosts (sender, logo)). Workaround: part("logo", none), and the sender renderer draws the logo itself, which drops a logo a user placed elsewhere. Fix: arrange functions get named c
- F5 `arrange` is atomic and couples alignment with the layout's column spec (4/3/2 columns). Centring footer blocks needed four wraps. Fix: a look-safe `cell-align` field applied to the cells of whatever arrange the layout set.
- F3 Replacing totals means rebuilding its logic from the pre-formatted v1 view (order per tax mode, modifier labels, prepayments, payable row). The 0% tax filter lives in the default renderer, not in measure as concept §5.4 says, so a custom renderer that forgets it prints a 0% row (compliance footgu
- F6 items-table has no hook for header label style, and render-table/render-totals hard-code weight "bold", ignoring weights.strong. Workaround: show strong (the header uses _.._) and show text.where(weight: "bold") inside a wrap, which depends on renderer internals. Fix: items-table.header-text-styl
- F7 There is no label font/size role, so the spaced-capital label voice is a constant in the look that brand() cannot reach. Fix: additive token fonts.label (default t => t.fonts.body), maybe sizes.label, read by the built-in labels.

### bold alt=studio/poster layout=a4-digital (existing layout; also verified on din-5008-a and us-letter-10 at 110 ppi) new=

audience: Creative and branding agencies, design, photo and motion studios, marketing and event agencies. Gallery: Berlin brand and motion studio, en-DE (English), 8 project items, a 5% package discount.
checks: m015=true m014=true contrast=true pdf=true
file: <session>/v2/looks-a/src/theming/looks/bold.typ
renders:

- <session>/v2/looks-a/gallery/bold-a4-digital-1.png
- <session>/v2/looks-a/gallery/bold-a4-digital-2.png
- <session>/v2/looks-a/gallery/bold-din-5008-a-1.png
- <session>/v2/looks-a/gallery/bold-us-letter-10-1.png
- <session>/v2/looks-a/gallery/matrix-bold.png
- <session>/v2/looks-a/gallery/stress-totals.png
- <session>/v2/looks-a/out014/gallery-bold-1.png
  intent: The invoice opens like a poster: a full-width block in one vivid ultramarine carries the document word in oversized grotesque type (sizes.title 5.8em) and the amount due as a second focal point, with a cropped disc in a derived shade as a geometric accent. Everything else is disciplined: labels in the embedded DejaVu Sans Mono, heavy black rules over the table and the footer, a light tint of the seed for zebra rows, and the payable total repeated on a solid colour bar. All colours derive from the one seed (a light brand flips the text to black and the disc to a lighter shade), so it stays playful but unmistakably an invoice. TOKENS: primary #2b2bd9; text #111114; text-muted #5b5b66; border #
  friction:
- F1 (critical) With realistic data, a top stroke plus 1.2mm inset on `footer` overflowed sn-010130-left/right and panicked where classic passed. An all-mono font fallback also overflowed a4-digital. Workaround: the rule hangs under the page-number region (from: 1, a descender-free folio c / t, 0.6mm
- F2 The contrast check hard-codes the default renderers' semantics: options::title::fill on colors::background panicked (1:1) because bold's title sits on the primary block. The pairs a replaced part draws (on-primary on the disc) are invisible to it. Workaround: do not set title.fill; choose the dis
- F8 Typst warns once per missing family in a fallback chain, has no generic sans-serif, and embeds only a serif and a mono. A mono last resort was wider and broke the footer fit. Workaround: the chain ends in the embedded Libertinus Serif, and every look runs with --ignore-system-fonts in run-all. Fi
- F7 No fonts.label/mono token: the DejaVu Sans Mono label voice is a constant in the look, unreachable by brand(). Fix: additive fonts.label token (default t => t.fonts.body) read by built-in labels.
- F9 The frame view lacks the payment due date, so the block cannot show 'Due 12 Oct'. Fix: view.payment.due (value, text) in the frame view (payment envelope).
- F10 A part cannot tell a window region from a flow region except via view.region.height (length vs auto). Fix: view.region.place in the frame view.
- F11 The heavy table header rule reuses strokes.regular, which the continuation header and others also read; only the rule colour is an option. Fix: items-table.rule-weights (header, body, bottom) defaulting to the stroke tokens.
- F3/F6 as for elegant: totals rebuilt from the v1 view including the 0% filter (fix: view v2 totals rows, 0% filtered in measure); header labels via a show strong hack (fix: items-table.header-text-style, honour weights.strong).
- F12 Full-bleed blocks are impossible from a part (no margins in the view); accepted, since geometry belongs to the layout. F13 page-number.format replaces the locale label entirely; bold uses c / t. Observed core bug outside theming: units do not pluralise ('2 day', '24 piece', '2,5 Stunde') in ever

## designer looks-b (<session>/v2/looks-b)

report: NOT WRITTEN: the harness refused REPORT.md ("subagents should return findings as text"); the full report is in the final assistant message. Evidence logs: <session>/...

### technical alt=ledger/blueprint layout=a4-digital new=

audience: IT freelancers, software houses, engineering and consulting offices (B2B, POs, projects, hours)
checks: m015=true m014=true contrast=true pdf=true
file: <session>/v2/looks-b/src/theming/looks/technical.typ
renders:

- <session>/v2/looks-b/out/gallery/technical-a4-digital-1.png
- <session>/v2/looks-b/out/gallery/technical-a4-digital-2.png
- <session>/v2/looks-b/out/gallery/technical-us-letter-10-1.png
- <session>/v2/looks-b/out/gallery/technical-us-letter-10-2.png
- <session>/v2/looks-b/out/gallery/technical-3pages-1.png
- <session>/v2/looks-b/out/gallery/technical-3pages-2.png
- <session>/v2/looks-b/out/gallery/technical-3pages-3.png
- <session>/v2/looks-b/out/gallery/technical-embedded-fonts-1.png
- <session>/v2/looks-b/out/wsl014/g-technical-1.png
  intent: A spec-sheet invoice: a clean sans for prose and monospace for every number, code and label (invoice number, positions, quantities, amounts, IBAN). A fine rule grid replaces fills (hairlines between items, heavier rules around the header and at the table end), and `// SECTION ───` markers in the accent colour. The only colour block is the payable amount, set inverted in primary like a terminal selection. Tokens: primary #155e75, text #0f172a, text-muted #526070, border #c3cbd5; body (Inter, Liberation Sans, Arial, Libertinus Serif); fonts.heading holds the mono face, DejaVu Sans Mono; base 9.5pt, title 2.2em; strokes 0.3/0.5/0.8/1.6pt; spacing 0.5/0.72em. Options: zebra (none, none), totals
  friction:
- F-T1: no mono/numeric font token (fonts.figures is only tabular|proportional). technical uses fonts.heading as its mono face, so brand(heading-font:) also changes the figures. Fix: add fonts.mono (or fonts.numeric), default t => t.fonts.body, read by the items-table, totals and references figures.
- F-T2: restyling the table means replacing items-table and totals and re-deriving the whole v1 view (column model, labels, basis suffix, modifier rows, subtotals, groups, zebra/row fill, totals order for both tax modes, prepayment and amount due): about 150 lines per look plus the 180-line kit.typ. F
- F-T3: the concept (§5.4) says measure suppresses 0 % tax rows, but view.taxes still contains them and only the default render-totals filters (totals.typ is-zero). A replaced totals part without the filter prints 0 % VAT lines. Fix: move the filter into measure.
- F-T4: the line-items composite hardcodes v(-1em) between table and totals (parts/body.typ), so replaced totals must compensate. Replacing the composite would bypass the internal call-part and its required-part guard. Fix: take the gap from spacing.md and export a public theme.parts.call(ctx, name, v
- F-T5: the frame's par(justify: true) leaks into body parts and spreads table cells apart. Fix: call body parts with justify off.
- F-T6: totals.emphasis-fill is contrast-checked as colors.text on the fill, so any dark fill fails even when the part writes on-primary on it; the total bar uses colors.primary directly instead. Fix: add totals.emphasis-text (auto = on-color(fill)) and check that pair.
- F-C1: the contrast pairs are fixed in core; accent used as text (labels, markers) cannot be registered. The look uses legible() and tests/looks-b.typ asserts the pair. Fix: checks.pairs (fg and bg derivations), or a derived colors.accent-text token.
- F-S3: regions have text but no par (leading), so a look cannot tighten footer leading to gain footer-fit headroom. Fix: a region par field.
- F-P2 (most serious): the footer-fit check turns font fallback into a compile error. With a mono last-resort body, technical panicked on a4-digital when only embedded fonts existed (footer 19.6mm, room 18.2mm); with Inter and a 2.2mm footer rule inset it panicked on sn-010130 (19.2mm vs 18.2mm). Fixe
- F-L1: the locale has no section labels (Payment, Details); the look carries a 5-language table. Fix: strings.sections.\*.
- F-L2: options such as title.layout are silently ignored by replaced parts. Fix: document per option that only the built-in renderer reads it.
- F-V1: an envelope window is only detectable as view.region.height != auto. Fix: view.region.place or a window flag.
- F-V2: the default bank-details renderer never prints the payment reference although show-reference defaults to true; the look prints it.
- F-A1: a 1fr column inside an auto-width cell collapses (Typst behaviour); the first title draft overlapped. kv now uses (auto, auto). Docs note for part authors.
- F-P1: Typst warns once per missing font family in a chain; chains are kept at 4 families or fewer, and the mono voice uses the embedded DejaVu Sans Mono, so it renders identically everywhere without warnings.

### soft alt=friendly/hearth layout=a4-digital new=

audience: cafés, bakeries, caterers, wellness and health practices, small retail, B2C services for private customers
checks: m015=true m014=true contrast=true pdf=true
file: <session>/v2/looks-b/src/theming/looks/soft.typ
renders:

- <session>/v2/looks-b/out/gallery/soft-a4-digital-1.png
- <session>/v2/looks-b/out/gallery/soft-din-5008-b-1.png
- <session>/v2/looks-b/out/gallery/soft-din-5008-b-2.png
- <session>/v2/looks-b/out/gallery/soft-3pages-1.png
- <session>/v2/looks-b/out/gallery/soft-3pages-2.png
- <session>/v2/looks-b/out/gallery/soft-3pages-3.png
- <session>/v2/looks-b/out/gallery/soft-embedded-fonts-1.png
- <session>/v2/looks-b/out/wsl014/g-soft-1.png
  intent: Warm but serious: a large serif title (Rechnung / Invoice), number and date in rounded pastel pills, a coloured recipient label, and the items in one rounded card with round position badges and dotted, menu-like separators. Totals sit in a tinted rounded card with the amount due in the serif voice, and a separate 'So bezahlen Sie' card holds the EPC-QR, so a private customer finds what, how much and how to pay at a glance. Type 10.5pt, relaxed spacing; tint and border derive from the one seed, and the brand colour used as text is made legible (legible(primary, tint)). Tokens: primary #9c3d26, text #33261f, text-muted #6b5a50, tint derived #ffede8, border derived #e9c0b5; body (Segoe UI, Libe
  friction:
- F-S1: no radius token, although rounded corners carry the look (the default totals block also hardcodes radius 2pt); radii are derived from spacing.md. Fix: a shapes.radius token (sm/md) read by the default totals emphasis block.
- F-S2: regions have fill and stroke (look-safe) but no radius, so rounded surfaces can only be drawn inside parts. Fix: a look-safe, derivable region radius field.
- F-C1: the contrast pairs are fixed in core; primary used as text (headings, badges, amount due) and text or sign colours on the look's own tint cards cannot be registered. The look uses legible(primary, tint) and tests/looks-b.typ asserts ink on tint, ink on background, decrease-color on tint and te
- F-T2: the rounded table card with badges and dotted rules required replacing items-table and totals and re-deriving the full v1 view (shared kit.typ). Fix: view v2 columns, cells and totals.rows, or row parts.
- F-T3: the 0 % tax filter had to be copied from the default renderer (kit.is-zero-tax), because view.taxes still contains 0 % rows, contrary to §5.4.
- F-T4: v(-1em) hardcoded between table and totals in the line-items composite; soft totals start with v(1.2em) to undo it.
- F-T5: the frame's par(justify: true) leaked into table cells (visible gaps in 'Brunch-Buffet „Sonntags-glück“'); every renderer resets it. Fix: call body parts with justify off.
- F-L1: no locale strings for 'How to pay' / 'Thank you'; the look carries a 5-language fallback table. Fix: strings.sections.\*.
- F-V1: envelope-window detection via view.region.height only; the recipient label and tint cards are suppressed in fixed regions for OCR safety, and nothing in core guards it. Fix: view.region.place or a window flag, plus a lint against fills on regions hosting the recipient.
- F-L2: options for built-in renderers (title.layout) are ignored by the replaced title; document per option which renderer reads it.
- F-P1: every missing family in a font chain is a compile warning, so the body chain is Segoe UI / Liberation Sans / Libertinus Serif and a brand font such as Nunito is meant to come via brand(font:). The heading voice uses the embedded Libertinus Serif, so it renders identically everywhere.
- F-P2: footer-fit depends on font metrics and data; the soft footer (dotted rule, inset 2.4mm) passed all 8 layouts with system and embedded fonts and n=14 multi-page, but with little headroom. Fix: footer-fit follows the Q3 validation levels.
- Incidental (not caused by the looks): test-locale with tax-exempt-small-biz panics with 'notices returned no content' for every preset, classic included. render-global-info drops the small-business clause when the region has no legal grounds. It passes with locale.de-de.

## designer looks-c (<session>/v2/looks-c)

report: NOT WRITTEN: the harness blocked writing REPORT.md (it refuses report files from subagents). The full report content (design intent, patch code, tokens and options, contrast figures, the 0.15.1 and 0.

### compact alt=ledger/wholesale layout=a4-dense (new, experimental, in src/theming/layouts.typ). Margins 13/14/24/16mm, footer-descent 25%. A slim letterhead (logo + sender) above ONE header row: recipient | info-block | title. It exists because a look cannot move parts between regions (friction F-1). The look itself works on all 10 layouts. new=a4-dense

audience: Wholesalers, distributors and B2B suppliers issuing collective invoices over several delivery notes, with 40-80+ lines, item numbers and trade units.
checks: m015=true m014=true contrast=true pdf=true
file: <session>/v2/looks-c/src/theming/looks/compact.typ
renders:

- <session>/v2/looks-c/out/gallery/compact-1.png
- <session>/v2/looks-c/out/gallery/compact-2.png
- <session>/v2/looks-c/out/gallery/compact-din-5008-a-1.png
- <session>/v2/looks-c/out/gallery/compact-din-5008-a-2.png
- <session>/v2/looks-c/out/gallery/compact-us-letter-10-en-1.png
- <session>/v2/looks-c/out/gallery/compact-us-letter-10-en-2.png
- <session>/v2/looks-c/out/lc-0.14.2/g-compact-nofonts-1.png
  intent: (1) A dense working document a clerk can scan line by line: 8.5pt type, single-line rows on a quiet zebra, tabular figures, item-number and unit columns, regular-weight names. Measured: 58 rows fit on page 1 and 80 items fit on 2 pages on a4-dense. (2) Hierarchy comes from structure, not decoration. A filled navy column header repeats on every page. Delivery-note groups are level-2 table headers: Typst keeps each one with its first row and repeats it on the next page (needs Typst 0.14+, verified on 0.14.2). A boxed totals block has a filled 'GESAMTBETRAG' row. (3) Continuation is explicit: 'Fortsetzung auf Seite 2 -> Seite 1 von 2' at the foot of page 1, and a header line on every following
  friction:
- F-1: `parts` is not a look-safe field, so a look cannot put `title` next to the recipient. The efficient one-row header therefore needed a whole new layout (a4-dense). Fix: a look-safe move such as custom.place-part("title", into: "address"), limited to standard parts and flow regions and re-checked
- F-2: The identity check reads repr() of the first-page output, so a title part cannot use layout(), measure() or context: the check then reports that the number is missing. Seen with the luxury title; worked around with unbreakable boxes and a weak h(). Fix: core wraps view.document.number and date.
- F-3: The locale has no strings for 'continued on page n', 'item no.' or the 'unit' column, so the look carries hardcoded tables for 5 languages (looks/common.typ ui-strings). Fix: add strings.document.continued-on, strings.line-items.item-id and strings.line-items.unit.
- F-4: page-label is private to parts/frame.typ, and the page-number.format callback gets (current, total) without ctx, so it cannot localise. I copied the fallback and replaced the whole page-number part. Fix: ship strings.document.page (Q5) and change the format signature to (current, total, ctx).
- F-5: View v1 has no normalised totals, so a replaced totals part must rebuild the exclusive/inclusive order, the 0% filter, modifier labels, prepayments and which row is emphasised (common.totals-rows, about 40 lines). Fix: view v2 view.summary: array<(kind, label, value, final)>.
- F-6: The line-items composite inserts v(-1em), tuned to the default table, so every replaced totals part must compensate. Fix: take the spacing from a token or a line-items.gap option.
- F-7: There is no public table kit, so a new table style re-implements columns, groups, modifiers, zebra and row styles (about 150 lines). The default table also hardcodes bold names and ignores weights.strong. Fix: add view.columns and a row model, and make the default table read weights.strong.
- F-8 (defect): item(item-id: (seller: ..)) arrives in the line-items view as none; only strings survive, and the ZUGFeRD XML then maps them to GTIN (GlobalID, scheme 0160), which is wrong for seller article numbers. Fix: propagate dict item-ids in components/line-items.typ and logic/calc-item.typ, an
- F-11: An arrange function gets (ctx, cells) without region geometry, and a dict arrange can only be replaced whole (atomic). Fix: signature (ctx, cells, region), and allow patching arrange.align alone.
- F-13 (defect in the default totals part, seen in the base modern render out/base-modern-2.png): with emphasis-fill the tinted box renders left-aligned instead of right-aligned.
- F-14: Every missing family in a font fallback chain prints an 'unknown font family' warning on 0.14 and 0.15. Checked with --ignore-system-fonts: the look falls back to Libertinus Serif and still reads well. Fix: document it and keep shipped chains short.
- F-17: A carry-over subtotal (R21) and a '(continued)' marker on a repeated group header are both impossible in Typst tables.

### luxury alt=maison/noir layout=a4-band (new, experimental, in src/theming/layouts.typ). A4 digital with a 44mm full-bleed band hosting logo + sender. The band is a FIXED first-page region, so it is tagged for PDF/UA and pushes the body down. It is a separate layout because a full-bleed band is geometry (R20), which a look may not set. On other layouts the look paints the layout's own letterhead region inside the margins instead. new=a4-band

audience: Premium brands, boutique hotels, fashion houses, jewellers and fine dining: few lines, high amounts, the invoice as part of the brand experience.
checks: m015=true m014=true contrast=true pdf=true
file: <session>/v2/looks-c/src/theming/looks/luxury.typ
renders:

- <session>/v2/looks-c/out/gallery/luxury-1.png
- <session>/v2/looks-c/out/gallery/luxury-multipage-1.png
- <session>/v2/looks-c/out/gallery/luxury-multipage-2.png
- <session>/v2/looks-c/out/gallery/luxury-din-5008-b-1.png
- <session>/v2/looks-c/out/gallery/luxury-us-letter-10-1.png
- <session>/v2/looks-c/out/lc-0.14.2/g-luxury-nofonts-1.png
  intent: (1) An onyx full-bleed first-page band carries a centred monogram and the name in wide-tracked champagne display capitals. Below it the white page has no fills: champagne returns only as hairlines, a 14mm rule under the spaced title word and a fine double rule around the amount due. (2) Champagne text on white fails contrast (2.25:1), so every accent-hued text on the page is legible(accent, background) = #836f46 (4.85:1). The band text is legible(accent, primary) (7.72:1), so a light brand colour still gets legible band text. (3) The typography is a high-contrast serif for display (Playfair/Bodoni with a Libertinus fallback), a Garamond body, tracked capitals for every label, italic descript
  friction:
- F-9: There is no token for accent-coloured text on the page. Gold cannot be used as text on white, so every renderer derives legible(accent, background) itself (accent-ink helper). Fix: token colors.accent-text: t => legible(t.colors.accent, t.colors.background); luxury is the consumer that justifie
- F-10: checks.min-contrast only knows the core colour pairs, so colours that a replaced part introduces (accent-ink) are invisible to it; I verified them separately in tests/looks-c.typ. Fix: a look-level checks.pairs list of (fg, bg, name) derivations.
- F-2: The identity check reads repr() and cannot see inside layout(): the responsive title (one line vs stacked) failed with 'number does not appear'. Worked around with box + weak h(). Fix: labelled metadata that the check queries after layout.
- F-11: An arrange function gets no region geometry, and a dict arrange is atomic, so centring the footer columns meant writing an arrange function that builds n equal columns. Fix: pass the region to arrange and allow patching arrange.align alone.
- F-12: inset is the only look-safe spacing field. It is padding inside the fill, and a look's inset replaces the layout's semantic spacing (e.g. the a4-digital letterhead's bottom 6mm). Fix: separate a look-safe inset (inside the fill) from a layout-owned space-after/outset.
- F-15: A full-bleed band that hosts required parts must be a fixed region, because a background region is an untagged artifact (PDF/UA). This works but is non-obvious. Fix: document 'full-bleed band = fixed region' in the layout docs.
- F-16: A replaced title part silently ignores title.layout, and the user gets no signal. Fix: parts declare which options they honour, and resolve warns about the rest (did-you-mean style).
- F-3/F-4/F-5/F-6/F-7 as for compact: missing locale strings, private page-label and a format callback without ctx, no normalised totals view, the v(-1em) in the composite, no table kit. Luxury needed the same workarounds as compact.
- Note: Typst 0.14+ level-2 table headers made group continuation work (the repeated 'SUITE BELVEDERE' header on page 2), verified on 0.14.2; no compiler bump needed.

## designer looks-d (<session>/v2/looks-d)

report: NOT WRITTEN: the harness refused REPORT.md ("Subagents should return findings as text, not write report files"). All report content (validation, tokens, options, friction log) is in this output. Patch

### corporate alt=enterprise/ledger layout=a4-sidebar (new, EXPERIMENTAL, plain layout dict in src/theming/layouts.typ, exported as theme.layout.a4-sidebar). It has a 58 mm tinted rail: a fixed first-page region (tagged, reserve: false, brand: true) hosting logo, sender, contact, register and bank-account, plus a pages:'rest' background band with the logo. Body column 124 mm; no window, no marks. The look uses no sidebar names and works on all layouts. new=a4-sidebar

audience: Larger companies, holdings and B2B enterprises: shared-service accounting, invoicing driven by purchase orders, many references per invoice.
checks: m015=true m014=true contrast=true pdf=true
file: <session>/v2/looks-d/src/theming/looks/corporate.typ
renders:

- <session>/v2/looks-d/gallery/corporate-a4-sidebar-1.png
- <session>/v2/looks-d/gallery/corporate-a4-sidebar-2.png
- <session>/v2/looks-d/gallery/corporate-din-5008-a-1.png
- <session>/v2/looks-d/gallery/corporate-din-5008-a-2.png
- <session>/v2/looks-d/gallery/v0.14.2-corporate-a4-sidebar-1.png
- <session>/v2/looks-d/gallery/matrix-corporate-9-layouts.png
  intent: A two-colour brand system: a deep primary (navy #15325b) carries the structure (table header, grand-total bar, serif display title, kickers), and a brass accent (#c9972c) appears only as rules and markers, never as text. The information architecture is strict: number and date are key facts in the title; references form a labelled 'Invoice details' table (tiles with accent ticks on DIN); Payment and Bank details are labelled sections; the grand total (or amount due) sits in a primary bar with on-primary text. On its default a4-sidebar layout, the supplier identity and all legal data (contact, register, VAT ID, account) live in a tinted brand rail, so the main column holds only what the custom
  friction:
- [validation] scripts/looks-d-check.sh has 34 checks, 34/34 ok on typst 0.15.1 (out/check-0.15.1.txt) and 34/34 on 0.14.2 in WSL (out/check-0.14.2.txt). The checks: both looks on the 8 layouts plus a4-sidebar; a 3-page n=34 run with continuation header, repeated table header, 'Page x of 3' and a foot
- [tokens/options] colors: primary #15325b, accent #c9972c, text #18202b, text-muted #556070, border #c6cdd7; tint is a derivation oklch(95.5%, min(C\*0.25, 0.018), hue of primary), giving #e9f1fd for the default seed. fonts: heading 'Libertinus Serif' (embedded); body is the schema default. sizes: bas
- [contrast] text/bg 16.4, text-muted/bg 6.38, text-muted/tint 5.6, on-primary/primary 12.81, title/bg 12.81, header text/header fill 12.81, decrease colour/bg 6.68. Every use of the primary colour as text goes through legible(primary, background).
- F2 (frame) The footer-fit check allows the footer to reach the paper edge. It compares the footer height with margin.bottom - footer-descent, which is the space down to the sheet edge. With a realistic 4-line register block, footer text ended 3.5-5 mm from the bottom edge on din-5008-a (this gallery
- F3 A look cannot ADD content. Custom prefixed parts must be hosted by a region, region parts are not look-safe, and validate-parts rejects unhosted custom parts. So I could not add rail section labels (Contact/Register/Bank), a project bar or a notices heading. Fix: look-safe region(name, prepend:/a
- F4 There is no totals row model. Replacing totals means re-deriving the row order (exclusive: subtotal/modifiers/net/taxes/grand; inclusive: grand/taxes; prepayments/amount due) and filtering 0% taxes, which view.taxes still contains, contrary to concept section 5.4. I wrote a ~50-line totals-rows()
- F5 Options are layout-blind. totals.width 52% is 88 mm on a4-digital but 61 mm in the 124 mm sidebar column, so labels wrapped into 3 lines. Derivations see tokens only, and body views carry no width. Workaround: layout(size => max(ratio\*width, 85mm)) inside the part. Fix: totals.width: (ratio, min:
- F6 Missing locale labels: 'Bill to', 'Payment', 'Bank details', 'Invoice details', short 'No.'/'Date', 'Scan to pay'. I hard-coded a de/en/fr/it/es table in common.label(), which users cannot override through locale.custom. Fix: a provisional strings.labels (or strings.theme) group, and theme.custom
- F7 A part cannot tell whether it is inside an envelope window (the 'Bill to' kicker must not appear there). Heuristic: view.region.height != auto. Fix: view.region.place, plus a region flag window: true exposed as view.region.window.
- F8 Contrast checks cover only token pairs. Primary used as text (kickers, sender name, continuation header) is unchecked, so a pale brand would pass the checks and be unreadable. Workaround: legible() everywhere, tested with #9fd8f5. Fix: a derived token colors.primary-text = legible(primary, backgr
- F9 The built-in legal parts (company, contact, register, bank-account) hard-code fill text-muted and the fine size, ignoring the region's text.fill. A primary-filled (dark) rail would make them unreadable, so the a4-sidebar rail had to be tint. Fix: inherit the region text fill, or add an on-surface
- F10 Typst warns once per missing font family, so fallback chains ('Source Sans 3', 'Liberation Sans', 'Arial', ..) print warnings on every compile. Both looks therefore keep the default body font and use embedded faces for their character. No API fix possible (Typst limitation); document it and cons
- F13 spacing.sm/md drive both the table cell insets and the region gaps. Raising them for table air also widens the address/info column gutter. Fix: items-table.row-inset, or a token spacing.row.
- F14 The (rows:) arrangement hard-codes row-gutter 0 and ignores gap, and there is no spring cell. To pin the legal block to the foot of the rail, a4-sidebar had to use the experimental arrange function. Fix: honour gap as row-gutter and allow 1fr springs in stacks.
- F15 The frame sets par(justify: true) for the body, and body parts inherit it. The first totals renders showed stretched labels ('excl. Tax 19%'), so every renderer must set par(justify: false). Fix: a body-justification token or region par field, and built-in cell renderers that set justify: fals
- F16 Region order (reading order) belongs to the layout, so on DIN the references strip always precedes the title. Optional fix: a look-safe order/weight field for flow regions only.
- F17 A sidebar that is tagged on page 1 and an artifact on later pages needs two regions (rail + rail-rest) with duplicated fill, stroke and inset. Fix: parts: (first:, rest:) on a margin-only pages:'all' fixed region.

### craft alt=workshop/sturdy layout=din-5008-a (no new geometry needed: window envelopes and DIN paper are standard in the trades) new=

audience: Trades and crafts businesses (Handwerk: electricians, carpenters, painters, installers). Most invoices are printed or faxed, sent in DIN window envelopes, often to private customers.
checks: m015=true m014=true contrast=true pdf=true
file: <session>/v2/looks-d/src/theming/looks/craft.typ
renders:

- <session>/v2/looks-d/gallery/craft-din-5008-a-1.png
- <session>/v2/looks-d/gallery/craft-din-5008-a-2.png
- <session>/v2/looks-d/gallery/craft-a4-digital-1.png
- <session>/v2/looks-d/gallery/craft-a4-digital-2.png
- <session>/v2/looks-d/gallery/v0.14.2-craft-din-5008-a-1.png
- <session>/v2/looks-d/gallery/matrix-craft-9-layouts.png
  intent: Print first: every section is a ruled box and hierarchy comes only from weight, size and stroke. No fill carries meaning, so a black-and-white laser print, a copy or a fax loses nothing; the brand colour (#b8400f) only marks the company name and the thick letterhead rule. It reads like a work order: form labels and headings are set in DejaVu Sans Mono capitals (embedded in every Typst build, so identical everywhere), and the order data (customer no., order, execution period, site address from delivery-address) sits in a ruled form under the address. It is big and calm: 10.5pt base, a large title with number and date in a ruled box, airy table rows, a totals box ending in a 2.5pt rule with GE
  friction:
- [validation] Same 34-check script (scripts/looks-d-check.sh), all ok on typst 0.15.1 and 0.14.2: 9 layouts, a 3-page n=34 run on DIN, gallery, a-3b + ZUGFeRD, ua-1 with an SVG image logo that has alt text, min-contrast 4.5 x 9 layouts x 3 brands. The gallery also passed a-3b and ua-1 on din-5008-a a
- [tokens/options] colors: primary #b8400f, text black, text-muted #3d3d3d, border black. fonts: heading 'DejaVu Sans Mono' (embedded); body is the default. sizes: base 10.5pt, small 0.88em, fine 7pt, large 1.3em, title 2.2em. strokes: hairline 0.5, thin 0.75, regular 1.25, thick 2.5pt. spacing: sm 0.
- [contrast] text/bg 21.0, text-muted/bg 10.86, text-muted/tint 8.68, on-primary/primary 5.56, primary as text 5.56 (an unchecked pair, handled with legible()), decrease colour/bg 8.15.
- F1 There is no line-height control, and the body flow is unreachable. No leading token or option exists, region text only takes set text arguments, and the frame's body paragraphs (salutation, the § 35a note) can be reached by no part. Craft can only wrap items-table and payment-terms with set par(l
- F2 (frame) The footer-fit check lets the footer run to the paper edge, and a look cannot raise margin.bottom. Craft's footer rule and inset plus a realistic 4-line register block (with a tax number) made footer text end about 3.7 mm above the edge on a4-digital without an error. Earlier, fine 7.5pt
- F11 (existing table renderer) An item and its description are separate table rows, and the description row has top inset 0. When a page break falls between them, the description prints directly under the repeated header rule on the next page, touching it. This affects any look; craft's airier rows e
- F12 items-table has too few knobs, and its renderer (937 lines) is not public. Monospaced capital column headers and a hairline between every row are impossible without replacing the whole table. Fix: options items-table.header-text-style (set text dict), row-rule (none | stroke), group-style; longe
- F3 A look cannot add content: a Meisterbetrieb or trade-seal badge in the letterhead is impossible, because parts are not look-safe and unhosted custom parts are rejected. Fix: look-safe region prepend/append cells, or a region-level wrap.
- F4 There is no totals row model (shared with corporate). Craft reuses common.totals-rows(), which duplicates the default renderer's tax-mode logic and 0% filtering. Fix: view.totals-rows plus totals.row-style.
- F6 Missing locale labels (Rechnungsempfänger, Zahlung, Bankverbindung, Nr., Datum, GiroCode) are hard-coded in common.label(). Fix: strings.labels and theme.custom.strings(..).
- F7 The 'bill to' label decision uses view.region.height != auto as a window heuristic. Fix: view.region.window/place.
- F15 Parts inherit the frame's justified body; the payment, totals and bank blocks must each set par(justify: false). Fix: a region par field or body justification token.
- F16 On DIN the references form precedes the title (region order belongs to the layout). A look-safe order for flow regions would let craft put RECHNUNG first.

# DESIGN REVIEW

report: NOT WRITTEN: the harness refused REPORT.md because subagents may not write report files. The full review is in this structured output. Evidence files: <session>/v2/design-review/out/ (same/_.png = all 8 looks on identical data n=4, teal brand; bold-longtitle-1.png; lt-sheet.png = long-title test; luxury-darklogo-1.png; base-_.png). Private test copies: design-review/l{a,b,c,d}. Typst 0.14.2 spot check (WSL, --ignore-system-fonts, n=12): all 8 looks compile. Page counts on 0.15.1 with the same body, n=4 (n=8): classic 1 (2), modern 1 (1), elegant/din-b 2 (2), bold/a4-digital 2 (2), bold/din-a 2 (2), technical 1 (1), soft/a4-digital 1 (2), soft/din-b 2 (2), compact 1 (1), luxury 1 (1), corporate/a4-sidebar 1 (2), craft/din-a 2 (2), craft/a4-digital 2 (2). Problems that affect more than one look: (1) Footer text ends 4-5mm above the sheet edge with no error on bold (DIN-A), corporate (DIN-A), craft (a4-digital), compact (a4-dense), elegant (a4-digital p2) and luxury (p2). (2) The totals block widows to the next page without any table row (elegant a4-digital, technical us-letter, corporate). (3) technical and soft show no 'Page 1 of n' on page 1 of multi-page invoices. (4) Core bugs seen in the renders: units do not pluralise ('2,5 Stunde', '24 piece'); the payment sentence says 'Gesamtbetrag' but prints the amount due (soft gallery); the continuation header runs subject and number together with no separator (looks-b kit); dict item-id is dropped and strings are mapped to GTIN (compact F-8, compliance); the default bank-details renderer omits the reference; the default totals emphasis box is left-aligned; item and description rows split across a page break (craft F11); test-locale in small-business mode panics with 'notices returned no content'.
contact: <session>/v2/design-review/contact-sheet.png

- elegant -> ship-after-fixes as "elegant" scores={"distinctiveness":7,"professionalism":9,"legibility":8,"audience-fit":9,"api-cleanliness":6}
  must-fix: A 4-item invoice needs 2 pages on its default din-5008-b while classic fits on 1 (out/same/elegant-din-5008-b-n4-\*.png). Page 2 holds only the closing. Collapse the 3-line centred title block (word / number and place-date / subject) to 2 lines, and cut the item row gap by about 30%. | On a4-digital the totals move alone to page 2 with no table context (looks-a/gallery/elegant-a4-digital-logo-2.png). There, 'Seite 2 von 2' sits about 1mm above the footer hairline and the last footer line (Steuernummer) ends about 5mm above the sheet edge. Give the folio at least 2mm clearance and depend on the footer-clearance fix. | On sn-010130-right the return-address hairline runs about 6mm past the right text margin (out/same/elegant-sn-1.png): x=858px against a column edge of 831px. | part('logo', none) plus drawing the logo inside sender silently drops a logo a user placed in another region. Document this in the preset docs, or adopt the API fix (arrange with named cells). | Merge with luxury into one serif family (see luxury): shared parts, two presets.
  nice: Adopt luxury's lighter table voice (italic descriptions, tracked group headers) if it works through options rather than a replaced items-table. | Replace the show strong / text.where(weight: 'bold') hacks in the items-table wrap with items-table.header-text-style once it exists.

- bold -> ship-after-fixes as "bold" scores={"distinctiveness":10,"professionalism":7,"legibility":8,"audience-fit":9,"api-cleanliness":5}
  must-fix: The poster block is about 50mm tall (sizes.title 5.8em, 12mm gap above the word). It pushes a 4-item invoice onto 2 pages, and page 2 holds only 'Sincerely, Atelier Nord GmbH' (out/same/bold-a4-digital-n4-2.png); the same happens on din-5008-a. Cut the block to about 36-38mm (title about 4.6em, 7mm gap). n=4 must fit on 1 page on a4-digital and DIN A. | A single long title word overflows the block, runs through 'AMOUNT DUE / 3.608,08 EUR' and is clipped by the block's clip: true (out/bold-longtitle-1.png, 'Abschlagsrechnung'). Measure the word and step the size down until it fits the 1fr column (layout()/measure; this needs the identity-check fix or a box plus weak-h workaround), or wrap with hyphenation. | On din-5008-a the footer register column wraps to 5 lines, and 'VAT ID' ends about 5mm above the sheet edge (looks-a/gallery/bold-din-5008-a-1.png, y≈1263/1286px at 110ppi). The '1 / 2' folio sits directly on the 1.6pt footer rule. Give it at least 2mm clearance, or shorten the DIN footer arrangement. | Label the payable bar with the same words as the block: 'Amount due' when prepayments exist, 'Total' otherwise (already correct in stress-totals; add a regression test).
  nice: Use a lighter disc shade on very dark seeds: with #111 the disc and block merge. | Pull the mono label voice into a fonts.mono token once it exists, so that brand() can reach it.

- technical -> ship-after-fixes as "technical" scores={"distinctiveness":9,"professionalism":9,"legibility":9,"audience-fit":9,"api-cleanliness":4}
  must-fix: Multi-page invoices have no page number on page 1 (technical-3pages-1.png), while pages 2 and 3 show 'Page 2 of 3'. Show 'Page 1 of n' on page 1 whenever the total exceeds 1. | The continuation header runs subject and number together with no separator: 'Invoice — Sprint 14 and platform operations BY-2026-0917' (technical-a4-digital-2.png). Put a middle dot or column between them, and truncate the subject with an ellipsis so it cannot collide with the company name on us-letter or sn layouts. | The title stack repeats the word: 'INVOICE / BY-2026-0917 / Invoice — Sprint 14…'. When the subject starts with the document word, drop the word from the subject line. | On us-letter-10 the totals widow to page 2 while about 20mm stays free on page 1 (technical-us-letter-10-1/2.png). Keep the last item row, or at least the 'Total net' line, with the totals. | Reads fonts.heading as its mono face, so brand(heading-font:) also changes every figure. Switch to fonts.mono when that token lands (0.5.0).
  nice: Reduce the replaced-part count (10 parts plus the 180-line kit) as soon as view v2 (totals rows, columns) exists; technical is the reference consumer. | Add a short docs note that the embedded-fonts fallback (Libertinus body plus DejaVu Mono) is intentional.

- soft -> ship-after-fixes as "soft" scores={"distinctiveness":9,"professionalism":8,"legibility":8,"audience-fit":9,"api-cleanliness":4}
  must-fix: On din-5008-b a 6-line invoice pushes the 'So bezahlen Sie' card alone onto page 2 (soft-din-5008-b-2.png), and n=4 needs 2 pages on din-b. Tighten the vertical spacing: 0.85em md spacing and 2.5em title eat about 20mm. Let the payment card break with the totals, or shrink the QR to 20mm on DIN. | The payment sentence is justified and shows rivers ('das unten / angegebene Konto', soft-a4-digital-1.png). Set par(justify: false) in the payment-terms wrap. | No page number on page 1 of multi-page invoices (soft-3pages-1.png). The continuation header lacks a separator between subject and number ('…am 12.09.2026 2026-0381'). | The dotted row separators and the #e9c0b5 card stroke almost disappear in greyscale laser prints. Darken the border derivation by about 15% L, or use 0.6pt, so that the card outline survives a copy.
  nice: When deposits exist, the payment sentence should say 'fälligen Betrag', not 'Gesamtbetrag' (core string; soft's gallery is where it shows). | Take radii from a shapes.radius token once it exists.

- compact -> ship-after-fixes as "compact" scores={"distinctiveness":8,"professionalism":8,"legibility":7,"audience-fit":10,"api-cleanliness":5}
  must-fix: The references cell sits between the recipient and the RECHNUNG block with bare labels ('Steuernummer 60 145 20371 / USt-IdNr. DE814562370', compact-1.png; 'Tax ID / VAT ID' in en). Readers take these for the customer's numbers. Label the group (for example 'Ihre Angaben' / 'Unsere Angaben'), or move the seller tax IDs to the footer only. | Page 2 shows 'Seite 2 von 2' twice, in the continuation header and in the footer (compact-2.png). Drop one. | On din-5008-a the footer hyphenates the e-mail: 'rechnung@nordwerk-/bremen.de' (compact-din-5008-a-1.png). Never hyphenate URLs or e-mails in the footer: use hyphenate: false, or a box around contact values. | On a4-dense the last footer line ends about 4.5mm above the sheet edge (compact-1.png, y≈1267/1286px). Raise margin.bottom in a4-dense by 3mm (the layout is the look's own) until the clearance fix exists. | Bank details use the unstyled default renderer ('Kontoinhaber:in: …' run-on lines) under an otherwise tabular page. Wrap it into a 2-column label grid in the look's voice. | Ship a4-dense only as an experimental layout, documented as a workaround for missing look-level part placement (F-1).
  nice: Long modifier labels wrap in the 48% totals box ('Rabatt: Mengenrabatt / Rahmenvertrag RV-2024-03 (3%)'). Allow 52% or a min width. | Make the zebra slightly stronger (#e8edf4) for 8.5pt row tracking on greyscale copies.

- luxury -> merge as "prestige (luxury tokens and a4-band layout on the shared elegant serif family)" scores={"distinctiveness":6,"professionalism":9,"legibility":7,"audience-fit":9,"api-cleanliness":5}
  must-fix: Merge with elegant. On identical data (out/same/luxury-a4-band-n4-1.png vs out/same/elegant-din-5008-b-n4-1.png, and luxury-din-5008-b-1.png vs elegant-din-5008-b-1.png) both share the same body grammar: centred tracked serif letterhead, centred tracked document word over a short rule, tracked-capital labels, a hairline table, a double rule under the payable, italic secondary text. Keep one parts family and ship two presets: elegant (din-5008-b, ink, no fills) and prestige (onyx and champagne, Didone display, a4-band). | A normal dark logo vanishes on the onyx band (out/luxury-darklogo-1.png, black mark on #1c1a17). Needs brand(logo-on-dark:) or an automatic light plate or ring behind the logo when its contrast with the band is below 3:1. | Totals hierarchy is inverted: 'TOTAL 4.093,00 EUR' is bold while 'AMOUNT DUE 3.093,00 EUR' is regular display weight (luxury-1.png), so the eye lands on the wrong figure. Make the payable the heaviest figure, or set TOTAL in regular weight when prepayments exist. | Bank details stay in the plain default renderer ('Account Holder: Palais Aurelia / Bank: …') under a luxury page. Render them with the tracked-capital label grid the rest of the page uses. | The 44mm full-bleed solid band cannot print edge to edge on office printers (4-5mm unprintable rim) and is toner-heavy. Document it as digital-first, and offer the in-margin letterhead variant for print (it already exists on din-5008-b).
  nice: Champagne hairlines (#c8a96b) drop to about 25% grey in greyscale prints. Consider 0.4pt for the table rules. | Keep the Didone display fallback to Libertinus, which already looks good (lc-0.14.2/g-luxury-nofonts-1.png).

- corporate -> ship-after-fixes as "corporate (replaces the modern preset)" scores={"distinctiveness":7,"professionalism":8,"legibility":8,"audience-fit":8,"api-cleanliness":5}
  must-fix: Replace `modern` instead of shipping beside it. On a4-digital and DIN (out/same/corporate-a4d-1.png vs out/base-modern-1.png) corporate is modern plus a serif title and brass ticks: same filled header, zebra, sans body and total bar. Q9 allows the default look to evolve. | In the 124mm sidebar column the description column is too narrow, so one-line names wrap ('SAP Basis Managed / Service, tier Gold', 'Senior integration / engineering', corporate-a4-sidebar-1.png). On narrow regions, shrink the unit-price and qty columns or drop '(net)' sub-labels into the header row. | Totals widow to page 2 while about 30mm stays free on page 1 (corporate-a4-sidebar-1/2.png, corporate-din-5008-a-1/2.png). Keep the last item row with the totals. | The IBAN prints ungrouped ('DE60500400000123456789') in the bank table, while technical and elegant group it in fours. Use the grouped display form. | The rail register block wraps 'HRB / 104822' and 'M. Oyelaran'. Use non-breaking spaces in register values, or a 2mm narrower rail inset. On din-5008-a the footer ends about 5mm above the sheet edge (corporate-din-5008-a-1.png).
  nice: Use a non-IT gallery (manufacturing or logistics holding), so that corporate and technical tell different stories. | 'Discount: Framework volume rebate' wraps in the totals. The 85mm minimum width is right; consider 90mm.

- craft -> ship-after-fixes as "boxed" scores={"distinctiveness":8,"professionalism":7,"legibility":9,"audience-fit":9,"api-cleanliness":5}
  must-fix: Rows are far too airy (about 9mm per single-line item at 10.5pt), so a 4-item invoice needs 2 pages and page 2 holds only the bank box (out/same/craft-din-5008-a-n4-2.png; also a4-digital). Cut the row inset to about 0.5em (spacing.md 0.8em is too much for the table) until spacing.row exists. n=4 must fit on 1 page on din-5008-a. | The IBAN in the bank form is ungrouped ('DE21520503530001234567', craft-din-5008-a-2.png), and this audience reads it off paper and types it. Print it grouped in fours. | The payable row mixes voices: 'GESAMTBETRAG' is set in DejaVu Mono while '3.240,97 EUR' is sans. Set both in the sans bold, keeping mono only for the small form labels. | Rename to `boxed`: the name should describe the ruled-box look, not one industry (it fits labs, logistics and public-sector forms too), in line with the style-based names of the other presets.
  nice: The mono 'RECHNUNG' title makes craft share its label voice with technical and bold. Consider a heavy grotesque title (Liberation Sans Bold, embedded fallback) to separate the looks. | The table header is not yet in the mono capitals the intent describes (blocked by items-table.header-text-style).

API GAPS:

- 1. [0.5.0 BLOCKER] Footer fit, bottom margin and clearance. Needed by all 8 looks (elegant F1, bold F1/F8, technical F-P2, soft F-P2, corporate F2, craft F2; compact and luxury footers end about 5mm from the sheet edge in their own renders). Changes: margin.bottom: auto grows from the measured footer + descent + a 5mm edge clearance; a zero-height region rule (rule: (above: stroke, gap:)) excluded from the fit check; footer-fit follows the Q3 validation levels (visual overflow marker in preview, panic only at the strict level); a CI job per preset with --ignore-system-fonts; docs rule: end font chains in an embedded proportional family.
- 2. [0.5.0, compliance] Totals row model (view v2) with the 0% tax filter moved into measure, as concept §5.4 already claims. Needed by all 8 (each rebuilt totals and copied is-zero-tax). Changes: view.totals.rows: array<(kind, label, value, emphasis)> in legal order for both tax modes, incl. modifiers, prepayments and amount due; totals.row-style(kind); totals.emphasis-text (auto = on-color(fill)) checked as a pair. The rows may be provisional; the filter move may not wait.
- 3. [0.5.0 small options; row model 0.5.x/0.6] Items-table knobs, justify leak and composite gap. Needed by all 8. Changes: items-table.header-text-style; honour weights.strong in the table and totals renderers (bold is hard-coded today); row-rule (none | stroke); row inset via a spacing.row token; take the line-items gap from spacing.md instead of v(-1em); call body parts with par(justify: false). Later: a public column/row model, or row parts (items-row, totals-row).
- 4. [0.5.0, before the token freeze] Token additions. Needed by bold, technical, craft, elegant, compact (fonts), luxury and corporate (text colours), soft (radius), craft (leading), corporate (row spacing). Changes: fonts.mono or fonts.label (default t => t.fonts.body); colors.primary-text and colors.accent-text = legible(color, background); shapes.radius (sm/md); spacing.leading; spacing.row. The 23 tokens freeze with 0.5.0, so these must land now or never.
- 5. [0.5.0, additive] Contrast pairs declared by looks. Needed by bold (on-primary on the disc; title.fill check panicked), technical, soft, luxury (accent-ink), corporate and craft (primary used as text). Change: look-safe checks.pairs: array<t => (name, fg, bg)>, checked with the core pairs at checks(min-contrast:).
- 6. [0.5.0, provisional group] Locale strings for theme labels. Needed by compact, luxury, technical, soft, corporate and craft (5-language tables hard-coded in each look), bold (English constants). Changes: strings.theme / strings.sections (Bill to, Payment, Bank details, How to pay, Invoice details, continued-on, item-id, unit, page); theme.custom.strings(..) for looks and packages; page-number.format(current, total, ctx).
- 7. [0.5.0, provisional view fields] Frame and body view additions. Needed by bold, technical, soft, corporate and craft (window detection via view.region.height != auto), bold (due date in the block), corporate (width-aware totals in the 124mm column). Changes: view.region.window and view.region.place; view.payment.due (value, text) in the frame view; view.region.width in body views; totals.width: (ratio, min: length).
- 8. [0.5.0] Identity check without repr(). Needed by compact and luxury (responsive titles failed with 'number does not appear'); it also blocks the fix for bold's long-title overflow. Change: core wraps view.document.number and date.text in labelled metadata and queries after layout, so titles may use layout()/measure().
- 9. [0.5.0: cell-align and par; 0.5.x: the rest] Region and arrange extensions. Needed by elegant F4/F5, luxury F-11/F-12, compact F-11, corporate F14/F17, soft F-S2, technical F-S3, craft F1. Changes: arrange receives (ctx, cells: array<(name, content)>, region: (width, height)); look-safe cell-align; rows: honours gap and allows 1fr springs; region par field (leading, justify); region radius; split look-safe inset from a layout-owned space-after; parts: (first:, rest:) for page-1-tagged rails.
- 10. [0.6; needs a requirement re-check design] Move or add parts from a look. Needed by compact (it needed the whole a4-dense layout), elegant (logo above the name), corporate (rail section labels), craft (trade badge, title-first order on DIN). Changes: look-safe place-part(name, into:) for standard parts and flow regions, re-validated against the required parts; region prepend/append/wrap; flow-region order. Until then, ship a4-dense and a4-sidebar as experimental layouts.
- 11. [0.5.0, small] Logo on dark surfaces; legal parts on filled regions. Needed by luxury (dark logos vanish on the onyx band, out/luxury-darklogo-1.png) and corporate F9 (built-in company/contact/register/bank-account parts hard-code text-muted, so the rail cannot be dark). Changes: brand(logo-on-dark:) or an automatic light plate when logo and band contrast is below 3:1; built-in legal parts inherit the region's text fill.
- 12. [0.5.x; document in 0.5.0] Options honoured by replaced parts. Needed by luxury, technical and soft (title.layout silently ignored). Change: parts declare the options they read, and resolve warns (did-you-mean style) about options that no active renderer reads.

SET: The final set has 10 presets plus the minimal docs recipe. Each owns one visual idea that no other preset uses: classic (DIN letter, default), plain (bare), corporate (brand rail and filled header; replaces modern), elegant (typography only, no fills), prestige (dark band and metallic accent; merged from luxury as a second preset of the elegant family on a4-band), bold (poster block), technical (mono figures and a rule grid), soft (rounded cards, warm), compact (maximum density for 40-80 lines), boxed (ruled form boxes, print and fax safe; renamed from craft). The identical-data row of the contact sheet showed two real overlaps. First, luxury shares its whole body grammar with elegant (tracked serif letterhead, centred tracked title with a rule, hairline table, double-ruled payable), so it becomes a preset (look x layout), which is exactly what the concept promises. Second, corporate on a4-digital is modern plus a serif title, so corporate replaces modern (Q9 allows the default to evolve). Remaining minor overlap: bold, technical and boxed all use DejaVu Sans Mono for labels. Boxed should move its title and payable to a heavy sans. The set covers law and tax, agencies, IT and engineering, B2C cafés and practices, wholesale, premium hospitality, enterprise AP and trades. Still uncovered: healthcare and private medical billing (GOÄ/GOZ structure), associations, non-profits and donation receipts, retail and hospitality receipts in small formats (A5/A6/thermal; no layout exists), RTL and CJK markets (no look tested with mirrored layouts or CJK fonts), high-legibility or large-print readers, screen-only dark invoices, and construction progress billing (partly a data-model question).

# validation-levels

report: NOT WRITTEN: the harness refused REPORT.md ("Subagents should return findings as text"). The full spec is condensed into summary, deliverables and open_issues here. Evidence logs: <session>/v2/validation-levels/out/run-all-0151.log and out/run-all-0142.log
workdir: <session>/v2/validation-levels
Implemented Q3 as `invoice(validation: "draft" | "strict" | none)`, default "draft". `--input invoice-pro-validation=strict|draft|none` overrides it in both directions, and an invalid value panics. `run-all.sh` passes 103/103 on typst 0.15.1 and 0.14.2: the 61 existing checks plus 42 new.

Investigation: the base prototype checked the theme side but no document data. A missing number or recipient printed loom's sentinel strings ("#recipient.name", "Invoice #invoice-nr"), and ZUGFeRD silently attached XML with an empty ram:ID.

Classes:

- **Always panic (misuse):** unknown keys, wrong types, cycles, unknown parts, undefined geometry, env kind, param conflicts. No output could honour the input.
- **Follow the level:** data (invoice number, supplier/recipient name and address, supplier tax ID, line items, recipient VAT ID under reverse charge), e-invoice (the BT-49/34/10/BG-6 checks moved out of zugferd/build.typ), theme (required role not placed, required part none or empty, identity), and lint (overprint, window overlap, qr paper, fine size, alt text, PDF image, CMYK, contrast, footer fit).
- The classification is tested: 15 follow-level error cases render under draft and none; 20 misuse cases still panic under none.

Draft rendering (brand-immune rose colours, contrast at least 6.6:1):

- inline markers ‹fehlt: Rechnungsnummer›¹, substituted into the frame view so every theme shows them; real tagged text, and links only in the flow (PDF/UA-1 forbids links in artifacts, found by compiling under ua-1);
- a badge on every page and a faint watermark;
- a report page after the invoice, excluded from the page count, with class, fix and legal basis per row (§ 14 UStG plus EN 16931, national references per region).

Strict lists every problem in one panic; a single problem keeps its old message verbatim. None renders silently, and the sentinels are gone. A complete document is identical under draft and strict; all 61 existing fixtures compile under strict.

E-invoice: in draft, the XML is withheld while any data or e-invoice issue is open. The badge ("keine E-Rechnung") and a report callout say so, and ZUGFeRD/Factur-X are dropped from the keywords (verified with pypdf).

Locale: new `strings.validation` group in de/en/fr/it/es/base, using agreement-free label forms. The draft report compiles under ua-1 and a-3b.

Names: "draft" and "strict" replace the suggested visual/panic, with pointed hints for those synonyms. The level is an invoice() parameter, not a theme setting: the document decides what happens with problems; the theme decides what counts as one.
DELIVERABLES:

- src/validation/issue.typ (new): issue classes, blocking-classes (data, e-invoice), levels, the input key invoice-pro-validation, issue(), resolve-level (input wins; hints map visual->draft, panic->strict, off->none), panic-text (one issue verbatim, several as a header plus numbered list), enforce, dedupe
- src/validation/data.typ (new): data requirement rows keyed by document kind (8 invoice rows) with the German provision plus EN 16931 BT/BG, generic national references for AT/CH/FR/IT/ES, check-data(kind, when, data, region:)
- src/validation/render.typ (new): emit/collected (single metadata <ip-issue> source), marker (links only in the flow), part-marker, badge, watermark, report page (table.header, bookmarked heading)
- src/invoice.typ: new parameter validation: "draft" with doc comment; resolves the level; collects theme and input-data issues into inputs.validation
- src/components/root.typ: measured checks (line items, reverse-charge VAT ID, e-invoice-issues); enforce; factur-x.xml withheld on blocking issues; keywords (Draft; ZUGFeRD removed when withheld); ensure(.., none) replaces the '#sender.name' sentinels; author only when it is a str
- src/theming/validate.typ: follow-level findings return issue(..) instead of panicking (contrast now reports every failing pair); misuse panics unchanged; ref per required role
- src/theming/build.typ: finalize collects theme.issues; resolve-theme(theme, env:, validation: "strict")
- src/theming/frame.typ: frame view substitutes markers (party name/address, number, tax ID); artifact-view without links for furniture; render-time findings (footer fit, identity) follow the level; badge, watermark, report; page total excludes the report page
- src/theming/parts/body.typ: call-part renders a marker for a required part that is none or renders nothing (draft), panics (strict), stays silent (none)
- src/theming/parts/frame.typ: return-address joins only non-empty pieces
- src/theming/scope.typ: themed() is now a plain motif, so scoped findings follow the level (draft emits them with ids prefixed themed/)
- src/zugferd/build.typ: the builder no longer panics; its checks moved into e-invoice-issues(ctx, item-data); new helpers seller-contact-of, buyer-reference-of, effective-profile
- src/locale/lang/{base,en,de,fr,it,es}.typ: new strings.validation group (marker, missing, part-empty, badge, watermark, e-invoice-short, report-title, report-intro, report-strict, e-invoice-withheld, the four column headers, classes, 14 fields). de examples: '‹fehlt: Rechnungsnummer›', 'ENTWURF · 4 Probleme · keine E-Rechnung', 'Prüfbericht'
- tests/validation/draft.typ: real invoice with 4 open problems (invoice number, supplier tax ID, recipient address, en16931 buyer electronic address); inputs look/lang/level; self-asserts the issue ids and that the report exists
- tests/validation/strict.typ + expected.txt: 10 compile-fail cases (single, multi, e-invoice, no line items, reverse charge, footer fit, input override, invalid parameter, invalid input, misuse under none)
- tests/validation/api.typ: precedence, panic-text, theme issue ids, contrast reports all pairs, locale key parity across 6 languages, a complete invoice renders no feedback
- tests/validation/themed.typ: scoped findings under draft and strict
- tests/errors/expected.txt: deliberately changed lines 11 (contrast) and 33 (CMYK): now all failing items (2 each)
- scripts/run-all.sh: error suite runs with --input invoice-pro-validation=strict; new validation block; classification loops (103 checks)
- scripts/panic-text.awk (new): one-line panic text for both compilers (typst 0.14 prints panics quoted with \n escapes; the base runner failed all 36 error cases on 0.14.2)
- scripts/mutation.sh: CRLF->LF only (set -u\r broke it under WSL sh)
- Renders at ppi 110: out/validation/draft-classic-de-1.png (page 1), out/validation/draft-classic-de-2.png (report), out/validation/draft-modern-en-1.png, out/validation/draft-modern-en-2.png, out/validation/draft-modern-de-0142-1.png (typst 0.14.2), out/validation/none-classic-de-1.png (clean, 1 page). At ppi 70: draft-modern-{fr,it,es}-{1,2}.png, theme-case25-2.png, theme-case28-1.png
- Logs: out/run-all-0151.log and out/run-all-0142.log (103/103 each)
  OPEN:
- REPORT.md was not written: the harness blocks report files from subagents. The design spec is condensed into this output.
- Naming: please confirm "draft"/"strict"/none over the suggested visual/panic. Both synonyms produce a pointed did-you-mean either way.
- validation: none with zugferd attaches whatever XML it built, possibly incomplete ('off means off'). The alternative is to still withhold it silently on blocking issues. Needs a decision.
- Per-class levels (e.g. (data: "draft", theme: "strict")) are not built. They could be added later without breaking the string form.
- Data rows are one EU/DE rule set. CH (Art. 26 MWSTG) requires no invoice number, and § 33 UStDV receipts need no recipient; both should become rows keyed by kind or region. The national references outside DE are generic and need a legal review.
- Not checked yet: the delivery/service date (§ 14 Abs. 4 Nr. 6 UStG), which defaults to the invoice date.
- The report shows theme/lint issues as the English developer message with literal backticks; maybe localise them or render backtick spans as raw.
- strings.validation.fields/classes are depth-3 dicts. The current depth-2 locale merge replaces them wholesale on a user override until patch.typ is adopted (0.4.3). A locale.custom.validation helper is not written yet.
- Error case 17 (tests/fake.pdf is not a real PDF) is excluded from the draft render loop; strict still covers it.
- The resolved theme gains a new provisional `issues` key; the concept's §3.1/§8 tables need a row and the new classification.

# naming

report: NOT WRITTEN: the harness refused <session>/v2/naming/REPORT.md ("subagents should return findings as text"); the full rename map is in rename-map.tsv in the same folder
workdir: <session>/v2/naming
Naming review is done. The machine-readable rename map is rename-map.tsv (38 changed rows, 5 columns checked). REPORT.md was not written: the harness blocked it. Nothing in the prototype was renamed.

Evidence: tests/naming/evidence.typ (12 assertions, E1-E12) passes on typst 0.15.1 and on 0.14.2 in WSL. tests/naming/shadow-fail.typ is an intentional failure that shows the shadowing error.

Criteria, in order of weight:

- high: semantic precision; Typst's own parameter names wherever a value is passed straight to Typst; one meaning per word.
- medium: EN 16931/UNTDID terms; guessable from the locale API; no shadowing or collisions; brevity.
- low: easy to translate for German speakers.
  Frozen names are renamed at medium confidence or above, provisional ones at medium-high.

Top 10 renames:

1. region -> area (also regions, region(), view.region). `region` already means country in invoice(region:), locale.region, text(region:) and env.region, and both meanings sit in the same resolved theme dict (E3).
2. Area anchors x/y -> left/top. The exclusive pairs become left<->right and top<->bottom, so the rule explains itself.
3. The payment-goal component -> payment-terms (EN 16931 BT-20).
4. fonts.figures -> fonts.number-width. It is passed verbatim to text(number-width:).
5. line-items.decrease-color/increase-color -> discount-color/surcharge-color, matching the discount()/surcharge() components and the locale keys.
6. stationery "generated" -> none.
7. theme.resolve-theme -> theme.resolve.
8. title.layout "line"/"stacked" -> title.arrange "row"/"stack".
9. Part register -> registration.
10. Area flag brand -> stationery.

Further renames:

- sizes.base -> body; spacing.sm/md -> small/medium
- totals.emphasis-fill -> fill; title.fill -> color; bank-details.qr -> show-qr
- theme.layout.letter-digital -> us-letter-digital
- Parts: info-block -> reference-list, sender-extra -> sender-details, notices -> notes
- Document kinds: proforma -> proforma-invoice, reminder -> payment-reminder

Kept, with reasons: theme, theme.custom, theme.parts, themed, derive, all preset and standard area names, place and pages values, tint, border, text-muted, page(), title(), reset(), replace().

New names:

- Strictness setting: checks.level with "off" / "warn" / "error". A "none" level can't work because data files turn the string "none" into the value none (E4); "panic" is implementation jargon.
- New base looks: one English adjective for the visual character, not an industry, place or descriptive name. Vetted candidates: elegant, bold, compact, technical, editorial, soft, mono.

Every new name was grepped against src/ and tests/: no collisions (details in open_issues).
DELIVERABLES:

- <session>/v2/naming/rename-map.tsv - machine-readable rename map (kind, old, new, confidence, note; 38 changed rows including the new checks.level names)
- <session>/v2/naming/tests/naming/evidence.typ - 12 assertions (E1-E12) backing the collision claims: token count 23; page/title shadow Typst built-ins in the import block; env.region next to layout.regions; from-data turns "none" into none; title.fill is a text colour; figures = number-width; title.layout enum; x/y vs sides; info area vs info module; stationery default; letter-digital paper. Passes on 0.15.1 and 0.14.2
- <session>/v2/naming/tests/naming/shadow-fail.typ - intentional compile failure: `set page(..)` inside `import theme.custom: *` gives 'only element functions can be used in set rules'
- <session>/v2/naming/ - full copy of the base prototype (unmodified apart from tests/naming/ and out/)
  OPEN:
- REPORT.md was not written: the harness blocks report files from subagents. The grouped review tables, principles and top 10 are summarised here and in rename-map.tsv's notes column; the orchestrator should write REPORT.md from this output if it needs one.
- Kept with a documented shadow: inside `import theme.custom: *`, the helper `page` shadows Typst's page (a `set page` there fails; see shadow-fail.typ) and `title` shadows the Typst 0.14+ title element. Renaming page() to layout() would shadow Typst's layout() instead, and page() mirrors 5 real Typst page parameters, so I recommend keeping it and documenting the shadow.
- Two layout words are ambiguous but kept: theme.plain (preset) and theme.layout.plain (layout) share a name as a preset/default-layout pair, and colors.background vs the 'background' place value. Document both.
- Area flag brand -> stationery reuses the layout key's word with a different type (bool on an area vs a mode on the layout). The alternative is 'preprinted'. Maintainer choice.
- sender.show-extra: I recommend removing it, because it steers the part sender-extra rather than sender and is redundant with part("sender-details", none). That is a design change, not only a rename; low confidence.
- checks.level: whether it also becomes an invoice(checks:) parameter or a sys.inputs override, and which level is the default, is for the validation-levels agent. The names off/warn/error work either way. The docs must say that 'warn' draws the finding into the PDF, because Typst has no warning API.
- Outside theming scope: the locale group `summary` (totals labels) is the only place that doesn't say 'totals'; a locale rename to `totals` would make the two APIs guessable from each other. The input key `sender.extra` interacts with Q4's new sender keys.
- Low-confidence optional rows: marks.x -> marks.left, requirements where 'page-1' -> 'first-page', printed-ok -> waived-by-stationery, internal surface-of -> tint-of.
- Collision greps (src and tests): area/areas only in one comment; registration only in an internal zugferd variable; notes only in comments; resolve only in logic/unit.typ, outside the theme namespace; preset( 0 hits; level only in the line-item tree; 0 hits for reference-list, sender-details, show-qr, discount-color, surcharge-color, us-letter-digital, proforma-invoice, payment-reminder and the enum strings off/warn/error.

# country-layouts

report: NOT WRITTEN: the harness blocks subagents from writing report .md files, so the report is returned here instead. The measured evidence is in <workdir>/research/ (bands-output.txt, local copies of the source PDFs, vector measurements), <workdir>/out/envelopes-1.png (fit table), <workdir>/renders/ (proof images) and <workdir>/out/run-all-0.1{5.1,4.2}.txt.
workdir: <session>/v2/country-layouts
Every window layout now puts the recipient where it stays readable in every envelope it declares, whichever way the folded sheet slides. The suite passes 77/77 on Typst 0.15.1 and 0.14.2.

Method: the folded sheet moves inside the envelope, and Royal Mail and USPS test by tapping the letter on all four edges. So each layout's recipient box must sit, with 2 mm clearance, inside the part of the sheet that shows in every position. Outer envelope sizes overstate the play, so the check errs on the safe side. tests/envelopes.typ asserts at least 5 lines (US: 4) and at least 60 mm per line for every declared envelope.

| layout                          | folds               | recipient box                  | envelopes                                     | lines    |
| ------------------------------- | ------------------- | ------------------------------ | --------------------------------------------- | -------- |
| din-5008-a                      | 87/192              | DIN zone, text stops at 100 mm | DIN DL, C6/5, C5-A, C4-A                      | 6/6/5/5  |
| din-5008-b                      | 105/210             | same                           | DIN DL, C6/5, C5-B                            | 6/6/5    |
| sn-010130-right                 | 99/192              | x 120-198, y 54-78             | CH C5/6 right, C5 right                       | 5/5      |
| sn-010130-left                  | 99/192              | x 22-92, y 54-80               | CH C5/6 left (DIN position), C5 left, DIN DL  | 6/6/6    |
| a4-window-right (new: FR/IT/ES) | 105/210             | x 116-186, y 57-80             | FR DL + C5, IT 11x23, ES 115x225 (2 variants) | 5 in all |
| a4-window-left (new: UK)        | 105/210             | x 24-95, y 60-81               | UK DL (BS 4264), DL variant, C5               | 5 in all |
| us-letter-10                    | 3 7/8 in / 7 1/2 in | y 2.58-3.30 in                 | #10                                           | 4        |

- **Swiss fold at 192 mm:** that fold is exactly the QR-bill perforation line. A fold at 210 mm would cross the Swiss QR Code.
- **US #10:** equal thirds leave too much play, and only 3 lines survive the tap test. A 4-line address cannot pass at 10 pt with equal thirds, so I moved the fold marks.

New API:

- `theme.custom.proof(true | names)` prints both extreme window positions, the always-visible band, fold/punch lines and the recipient box, plus a legend. You print one sheet and hold it against the envelope.
- `theme.custom.envelopes(..)` lets users add their own envelope.
- `theme.layout.envelope` is a catalogue of 21 envelopes with sources; `theme.layout.for-region(region)` maps the sender's region to a layout.
- Validation fails when the folded sheet does not fit an envelope or a proof name is unknown (compile-fail cases 37-39).

Also fixed a pre-existing bug: the DIN recipient sat at the bottom of its zone instead of the top.

Mapping proposal (sender's region):

- de → din-5008-a (high confidence)
- at → din-5008-b (medium)
- ch → sn-010130-right (medium)
- fr, es → a4-window-right (medium); it → a4-window-right (low)
- gb → a4-window-left (medium)
- us → us-letter-10 (medium)

Keep din-5008-a as the classic default in 0.5.0; let classic pick by region once these layouts are stable.

Sources with confidence levels:

- High: DIN 680 via de.wikipedia; Elco product pages; SIX IG QR-bill v2.4; Swiss Post, Austrian Post, Royal Mail and USPS specs.
- Medium: INKA norm sheet; GPV/Antalis; Arpon; Cavalier; filing.com.
- Low: Blasetti (Italy); DIN C4 values; the US fold (my own derivation).
  DELIVERABLES:
- src/theming/proof.typ (new): envelope records, envelope-band, recipient-box, window-fit, proof-overlay
- src/theming/layouts.typ: envelope catalogue (21), folded(), DIN inset right 5mm, new SN geometry and folds 99/192, a4-window-right, a4-window-left, us-letter-10 folds and address, body-top values, by-region/for-region
- src/theming/schema.typ: new layout keys envelopes: () and proof: false
- src/theming/custom.typ: envelopes(..) and proof(value) helpers
- src/theming/validate.typ: envelope and proof validation (fit, anchors, names)
- src/theming/frame.typ: proof layer with measured line metrics; fix: arrange rows align applied per row
- src/public/layout.typ: exports new layouts, envelope, folded, for-region
- tests/envelopes.typ (new): fit assertions and fit table (out/envelopes-1.png)
- tests/proof.typ (new): proof render per layout (--input layout=, long=1)
- tests/semantics.typ S2/S4, tests/doc/din.typ, tests/errors cases 37-39: updated
- scripts/run-all.sh: new matrix layouts, envelopes, 7 proofs, 0.14 panic-quote stripping; all copy files converted to LF
- renders/proof-<layout>-1.png and proof-long-<layout>-1.png (110 ppi), renders/proof-sn-010130-right-2.png (QR-bill page)
- research/: bands.py and bands-output.txt (fold option study), local PDFs of every source measured, vector measurements
- out/run-all-0.15.1.txt and out/run-all-0.14.2.txt: 77/77 each
  OPEN:
- The report is returned in this output instead of REPORT.md, because the harness blocked writing .md report files.
- SN 010130, NF Z 11-001, ÖNORM A 1080 and BS 4264 are paywalled. Geometry comes from manufacturer and post data, and the Swiss sheet positions are derived from the windows.
- The Italian window (Blasetti 4x10 cm at 1.6/1.6 cm) rests only on retailer snippets. The DIN C4 values conflict between sources.
- The US 3 7/8 in top panel is my derivation, and folding machines default to equal thirds. A real test print with a #10 envelope is recommended.
- With the old SN left window (INKA, 25 mm from the bottom), sn-010130-left shows 4 lines; with the current DIN-position product it shows 6.
- Only the recipient box is checked, not the rendered recipient content. A 6-line address overflows visibly in the proof but does not fail. This could feed the none/visual/panic requirement levels.
- Double-window envelopes (US #10 double window, Swiss sender window) are not modelled. The record format supports two records, but the fit test assumes a single recipient box.
- The concept README must be updated: the DIN A listing, S2 (the left variant is no longer just two anchor patches), S4 (inset now has right: 5mm), the layout table (new layouts, SN folds) and the new layout keys.
- The base copy ships CRLF line endings, so run-all.sh fails under WSL sh. A .gitattributes rule or pre-commit hook should enforce LF.
- Typst 0.14 prints panic messages in quotes. run-all.sh now strips them so the byte-identical error comparison passes on 0.14.2 and 0.15.1.

# compat-014

report: NOT WRITTEN. The Write tool refused REPORT.md ("Subagents should return findings as text"). All findings are in this output. Raw evidence is under <session>/v2/compat-014/logs/
workdir: <session>/v2/compat-014
The prototype works on Typst 0.14.2 without changing anything in src/ (the diff against base/src is empty, ignoring line endings). I could not test exactly 0.14.0: the nix store only has 0.11.1, 0.12.0, 0.13.1, 0.14.2 and 0.15.0. On 0.13.1, loom refuses to load, so the 0.14.0 floor holds.

**Suite (61 checks).**

- The first 0.14.2 run passed 60/61. The only failure was the byte-identical compile-fail comparison, all 36 lines.
- Cause: 0.14 prints `panicked with: "<repr>"`, quoted with escaped `"`. 0.15 prints the text itself. The wording is the same in all 36 cases.
- Fix: one extra pipe in run-all.sh through the new `scripts/unquote-panic.sed`.
- Separately, run-all.sh and mutation.sh had Windows (CRLF) line endings, which made WSL `sh` abort. I converted them to LF.
- After both changes: 61/61 on 0.14.2 (WSL, token mutation included) and 61/61 on 0.15.1 (Windows).

**PDF standards on 0.14.2** (new test `tests/compat/ua.typ`, image logo with alt text):

- `ua-1` compiles for classic, modern, plain and minimal. So do p7 and the p2 einvoice document.
- `a-3b` with ZUGFeRD basic and en16931 compiles in all 4 looks. `scripts/pdf-inspect.py` confirms each file has PDF/A 3B metadata and a `factur-x.xml` attachment (AFRelationship Alternative) that inflates to a CrossIndustryInvoice.
- `a-3a,ua-1` and `a-3b,ua-1` are rejected on 0.14.2 ("only supports one PDF substandard at a time"). `a-3a,ua-1` is accepted on 0.15.0 and 0.15.1, and that file carries 3A, UA-1 and the attachment. The concept's claim holds.

**Visual parity** (77 pages at 90 ppi, fonts pinned with `--ignore-system-fonts` plus Liberation copied from Windows):

| comparison                     | identical pages |
| ------------------------------ | --------------- |
| 0.14.2 vs 0.15.1               | 71/77           |
| 0.14.2 vs 0.15.0 (both Linux)  | 71/77           |
| 0.15.0 Linux vs 0.15.1 Windows | 77/77           |

- The 6 differing pages (third-party, doc-p9, doc-passing) differ in 8 pixels by at most 2/255 of anti-aliasing, all inside the bold "ACME" rail text.
- No baseline or line-height shift anywhere, and page counts match.
- With system fonts, every difference is font fallback, not a compiler bug:
  - the `↳` discount marker is not in Liberation Sans, so each OS draws it from a different font;
  - the doc snippets p1 and p6 ask for Inter, which only Windows has; p6 falls back to Libertinus Serif and even changes page count (2 pages on Windows, 1 in WSL).

**Performance on 0.14.2** (median of 5, the machine was loaded):

| items | 0.4.2        | prototype sealed | change       | prototype unsealed                  |
| ----- | ------------ | ---------------- | ------------ | ----------------------------------- |
| 1     | 244–291 ms   | 314–382 ms       | +8 to +57 %  | 419–425 ms                          |
| 150   | 1979–2273 ms | 2096–2533 ms     | +6 to +11 %  | about 4.2 s                         |
| 400   | 4046–5450 ms | 5627–7115 ms     | +31 to +39 % | about 12.8–13.2 s (about 2x sealed) |

Windows 0.15.1 shows the same ratios (+22 / +16 / +37 %), so there is no regression specific to 0.14.

**CI recommendation.** The 0.14 job owns the visual references, rendered with pinned fonts (Liberation `.ttf` in a test fonts folder, never in the package) and compared with a tolerance. Because 0.15.x differs by at most 2/255, the 0.15 job can compare against the same references too, instead of skipping pixel checks.
DELIVERABLES:

- compat-014/scripts/run-all.sh - converted to LF line endings; the compile-fail step now pipes through unquote-panic.sed so it passes on 0.14 and 0.15
- compat-014/scripts/mutation.sh - converted to LF only
- compat-014/scripts/unquote-panic.sed - rewrites the quoted 0.14 panic output into the 0.15 form
- compat-014/scripts/pdf-standards.sh - ua-1 and a-3b+ZUGFeRD (basic and en16931) per look; checks that a-3a,ua-1 is rejected on 0.14 and accepted on 0.15
- compat-014/scripts/pdf-inspect.py - stdlib-only PDF check: pdfaid/pdfuaid metadata, factur-x.xml attachment, AFRelationship, CII content and guideline ID
- compat-014/tests/compat/ua.typ - PDF-standard test document (--input look=..., zugferd=...), image logo with alt text
- compat-014/scripts/parity-render.sh - renders the 77 parity pages (matrix, walkthroughs, p2, third-party, doc snippets, ua) with pinned or system fonts
- compat-014/scripts/parity-diff.py - Pillow/numpy pixel diff: diff share, tolerance share, bounding box, best vertical shift, side-by-side images
- compat-014/scripts/bench.sh, tests/compat/bench-n.typ, baseline-042/ (unmodified 0.4.2 src + bench-n.typ) - benchmark for 1/150/400 items, sealed vs unsealed vs 0.4.2
- compat-014/parity/{r0142,r0151,r0150lin,s0142,s0151,diff-\*,embedded-only,fonts} - renders and diff images; examples: diff-fixed/third-1.png, diff-system/doc-p6-1.png, crop-sysfont-desc.png, embedded-only/modern-1.png
- compat-014/logs/_ - run-all-0142/0151, pdf-standards-0142/0151, pdf-inspect, parity-diff-_.md, bench-0142(-run2), bench-0151-win
  OPEN:
- REPORT.md does not exist: the Write tool refuses report files from subagents. The orchestrator must build it from this output and the files in logs/.
- Exact 0.14.0 is not available offline. The 0.14.1 changelog fixes 'table headers could be tagged incorrectly', which could change the PDF/UA-1 result for the items table on 0.14.0. Either run a CI job pinned to 0.14.0 or document that PDF/UA needs 0.14.1 or newer. 0.14.2 also fixes a wasmi use-after-free, so recommend 0.14.2 or newer to users.
- Users on 0.14 see panic messages quoted and escaped. This is compiler behaviour and cosmetic, but the docs quote the 0.15 form. Tytanic compile-fail tests need the same unquote normalisation.
- fonts.body defaults to the single family 'Liberation Sans' (src/theming/schema.typ:51), which breaks the 'fonts are fallback chains' rule. With only Typst's embedded fonts, the default looks render in Libertinus Serif (parity/embedded-only/modern-1.png). Fallback chains in turn warn once per missing family on both compilers (for example arial/helvetica from the QR-bill 'regulated' chain); Typst has no way to test whether a font exists. Left unchanged because the looks owner decides this.
- Some glyphs are missing from Liberation Sans and fall back to host fonts: the ↳ discount marker (core, predates 0.5.0) and a small glyph on sn-010130 page 2. Doc snippets p1/p3/p6 use Inter, Fraunces or Source fonts without a chain ending in an always-available font; p6 changes page count between hosts.
- Core message (predates 0.5.0): with zugferd 'en16931' and locale de-de, a missing BT-10 buyer reference panics with "profile 'xrechnung' requires...", which confuses users who asked for en16931.
- The benchmarks ran on a shared, loaded machine (load average about 2.8 on 12 cores); the absolute times vary by ±30 %. Re-run scripts/bench.sh on an idle machine before release.
- The repo needs `*.sh text eol=lf` in .gitattributes. The base scripts have CRLF line endings and fail under Linux sh.
