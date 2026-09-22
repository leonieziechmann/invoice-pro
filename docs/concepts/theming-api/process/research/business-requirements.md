# Business Requirements for the invoice-pro Theming API

Researcher focus: what MODERN BUSINESSES need from invoice theming/branding.
Phase: UNDERSTAND (no design decisions here - only evidence, requirements, scenarios).
Date: 2026-09-20. Typst CLI used for experiments: 0.15.1. Package min compiler: 0.14.0.

Conventions

- `path:line` = file in `<repo>` unless prefixed with `letter-pro:` (= `%LOCALAPPDATA%/typst/packages/preview/letter-pro/3.0.0/src/lib.typ`).
- "EXPERIMENT" = something I compiled myself; files live in `.../scratchpad/proto/business-req/`.
- All Typst snippets in section 10 are WISH CODE (what a persona would like to type). They are not a design proposal; names are placeholders chosen to feel like the existing `locale` / `tax` / `references` APIs.

---

## 0. Executive summary

1. Every commercial invoicing product separates three things that invoice-pro currently fuses into one `themes.DIN-5008(...)` call: (a) BRAND (logo, colors, fonts, legal footer text), (b) PAGE LAYOUT / MASTER (paper, address window, letterhead background, header/footer zones, marks), (c) CONTENT STYLE (table, totals, payment block). SAP calls it "master form template vs. content form template", sevdesk calls it "Briefpapier vs. Layout", Odoo "layout x font x colors x logo", Stripe "account branding vs. invoice template".
2. The number one branding knob everywhere is the LOGO. invoice-pro has no logo concept at all (grep for "logo" in `src/`, `docs/docs/`, `README.md`: zero matches).
3. The second most requested feature in the DACH market is BRIEFPAPIER: a letterhead background with a different first page and following pages (Lexware, easybill, sevdesk, FastBill, orgaMAX, JTL all have it). With the current DIN-5008 theme this is impossible: letter-pro overrides `page.background` (letter-pro:138) and hard-codes `paper: "a4"` (letter-pro:133). EXPERIMENT confirmed both.
4. Hard technical constraints from Typst that the API must be designed around (all verified by EXPERIMENT on 0.15.1):
   - PDF images cannot be embedded when any `--pdf-standard` is active (a-3b, ua-1): "embedding PDFs is currently not supported in this export mode". => A PDF letterhead is incompatible with ZUGFeRD output. SVG/PNG/native content works. (Lexware has the exact same product restriction.)
   - `cmyk(...)` colors fail PDF/A export ("missing a CMYK profile / CMYK colors are not yet supported in this export mode"). => brand colors must be RGB-family for e-invoices.
   - PDF/UA-1 export hard-fails on an `image()` without `alt` and on a missing document title. => a logo API must carry alt text (or place it as artifact); document metadata must not be a theme responsibility (the `blank` theme fails ua-1 today).
   - Fonts cannot be shipped in a package or loaded from a theme value; an unknown family is only a warning and silently falls back. => fonts are always "family name + fallback list", never files.
   - Contrast is never checked by Typst. => if accessibility matters, the theme layer has to help.
5. Address-window geometry and paper size are regional, not purely stylistic: DE/AT left window (DIN 5008 A/B), CH traditionally RIGHT window (SN 010130; left permitted), FR right (NF Z 11-001), US #10 envelope + Letter paper, UK C5/DL left. The region schema (`src/locale/region/base.typ:30-96`) has no layout hints today; regions shipped: at, ch, de, es, fr, it (`src/locale/region/*.typ`).
6. Some page areas are regulated and must be IMMUNE to branding: the Swiss QR-bill payment part (210 x 105 mm at the bottom edge, only Arial/Frutiger/Helvetica/Liberation Sans, black, fixed sizes), the EPC QR code (min. about 2 x 2 cm, quiet zone, black on white), and the DIN address zone (min. font sizes, no blank lines).
7. Legal footers are mandatory content in DE/FR/IT/ES for corporations and conventionally live in a multi-column footer on every page. letter-pro shows the footer on page 1 only (letter-pro:190).
8. Since June 2025 the European Accessibility Act makes accessible PDFs (practically: PDF/UA + WCAG AA contrast) relevant for B2C invoices; Typst 0.14+ can produce PDF/UA-1, and the current default theme already compiles under `ua-1`, `a-3a` and `a-3a,ua-1` (EXPERIMENT). This is a differentiator worth protecting with the theming contract.
9. Automation is the natural habitat of a Typst invoice package: one theme/brand value reused for thousands of invoices, selected by data (`brand: "acme"` in JSON), loaded from json/yaml/toml, optionally from W3C DTCG design tokens (stable since 2025-10).

---

## 1. Baseline: what exists today (evidence)

| Fact                                                                                                                                                                                                                                                                                                                                            | Evidence                                                                                                                                                                                                                                                                                                                                  |
| :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Docs mark Theming API as unstable, to be locked in v0.5.0                                                                                                                                                                                                                                                                                       | `docs/docs/api-reference/theme.md:7-11`; `README.md:103`                                                                                                                                                                                                                                                                                  |
| Two themes exported: `blank`, `DIN-5008`                                                                                                                                                                                                                                                                                                        | `src/themes/themes.typ:3-4`                                                                                                                                                                                                                                                                                                               |
| DIN-5008 knobs: `form`, `font`, `hole-mark`, `folding-marks`, `color-row-odd`, `color-row-even`, `margin`, `footer` (footer is undocumented)                                                                                                                                                                                                    | `src/themes/DIN-5008/din-5008.typ:6-18`; docs table `theme.md:27-35` lacks `footer`                                                                                                                                                                                                                                                       |
| A theme is a dictionary of slot renderers: `document`, `header`, `footer`, `line-items`, `bank-details`, `payment-goal`, `signature`                                                                                                                                                                                                            | `src/themes/base-theme/base.typ:8-50`                                                                                                                                                                                                                                                                                                     |
| Page layout is delegated to `@preview/letter-pro:3.0.0`                                                                                                                                                                                                                                                                                         | `src/themes/DIN-5008/document.typ:2-5,161-163`                                                                                                                                                                                                                                                                                            |
| Paper hard-coded A4, user `set page` is overridden                                                                                                                                                                                                                                                                                              | letter-pro:132-134; EXPERIMENT `letter.typ` -> page is 595.28pt x 841.89pt although `#set page(paper: "us-letter")` was set before `#show: invoice.with(...)`                                                                                                                                                                             |
| `page.background` is overwritten by fold/hole marks, so a user-provided letterhead background disappears                                                                                                                                                                                                                                        | letter-pro:138-160; EXPERIMENT `bg.typ` -> `bg-1.png`/`bg-2.png` show no letterhead                                                                                                                                                                                                                                                       |
| Only formats: `DIN-5008-A`, `DIN-5008-B` (left window)                                                                                                                                                                                                                                                                                          | letter-pro:18-30                                                                                                                                                                                                                                                                                                                          |
| Footer rendered on first page only                                                                                                                                                                                                                                                                                                              | letter-pro:190-192                                                                                                                                                                                                                                                                                                                        |
| "Seite x von y" label is chosen by letter-pro from `text.lang` (de -> "Seite", anything else -> "Page"), not from the invoice locale strings                                                                                                                                                                                                    | letter-pro:174-180                                                                                                                                                                                                                                                                                                                        |
| BUG found on the way: `text.lang` is ALWAYS "de". `build-locale` returns no `lang` key (`src/locale/factory.typ:66-74`; the code lives at `strings.meta.lang`, e.g. `src/locale/lang/en.typ:22`), so `ensure("lang", "de")` (`src/components/root.typ:62`) always wins and `set text(lang: ctx.locale.lang, ...)` (`root.typ:158`) sets German. | EXPERIMENT `pg-en-de.typ`, `pg-fr-fr.typ`, `pg-de-de.typ`: all print "Seite 2 von 2"; probe in the fr-fr body prints `text.lang = de`, `region = FR`. Consequences: page label always German, German hyphenation for every language, and the PDF language tag is "de" for English/French invoices (an accessibility defect under PDF/UA). |
| Marks are fixed `0.25pt + black`                                                                                                                                                                                                                                                                                                                | letter-pro:141-158                                                                                                                                                                                                                                                                                                                        |
| Document metadata (title, author, keywords) is set inside the DIN theme's document function, not in core                                                                                                                                                                                                                                        | `src/themes/DIN-5008/document.typ:66-78`; consequence: `themes.blank` fails `--pdf-standard ua-1` with "missing document title" (EXPERIMENT `ua-blank.typ`)                                                                                                                                                                               |
| Colors are literals repeated in 4 files (no palette)                                                                                                                                                                                                                                                                                            | `src/themes/base-theme/line-items.typ:16-22`, `src/themes/components/line-items/line-items.typ:11-17`, `.../table.typ:139-147`, `.../totals.typ:316-318`, `.../global-info.typ:7`                                                                                                                                                         |
| Only two of those colors are user-reachable (`color-row-odd/even`)                                                                                                                                                                                                                                                                              | `src/themes/DIN-5008/din-5008.typ:13-14,32-35`                                                                                                                                                                                                                                                                                            |
| Font: single family string, no fallback list documented, no heading/numeric roles                                                                                                                                                                                                                                                               | `din-5008.typ:8`; `document.typ:80`                                                                                                                                                                                                                                                                                                       |
| No tabular figures in money columns (only `number-type: "lining"` in bank details)                                                                                                                                                                                                                                                              | grep `number-width                                                                                                                                                                                                                                                                                                                        | tabular`-> only`src/themes/base-theme/bank-details.typ:40` |
| Unexported style variants already exist for the table: elegant, vibrant, luxury, informational                                                                                                                                                                                                                                                  | `src/themes/base-theme/line-items.typ:42,242,279,297`                                                                                                                                                                                                                                                                                     |
| No logo anywhere                                                                                                                                                                                                                                                                                                                                | grep -i `logo` over `src/**`, `docs/docs/**`, `README.md`: no matches                                                                                                                                                                                                                                                                     |
| Only document type string is "Invoice"                                                                                                                                                                                                                                                                                                          | `src/locale/lang/base.typ:32-34`                                                                                                                                                                                                                                                                                                          |
| Region schema has no layout/paper/address hints                                                                                                                                                                                                                                                                                                 | `src/locale/region/base.typ:30-96`; `src/locale/region/ch.typ:43-73`                                                                                                                                                                                                                                                                      |
| ZUGFeRD requires `--pdf-standard=a-3b`                                                                                                                                                                                                                                                                                                          | `docs/docs/e-invoicing.md:39-47`                                                                                                                                                                                                                                                                                                          |
| Default invoice compiles clean under `ua-1`, `a-3b`, `a-3a`, `a-3a,ua-1`                                                                                                                                                                                                                                                                        | EXPERIMENT `ua.typ` (no errors)                                                                                                                                                                                                                                                                                                           |

WCAG contrast of current default palette (computed, `contrast.js`): `luma(100)` on white 5.92, on zebra `#e2e8f0` 4.80; `luma(80)` 8.06 / 6.54; `#475569` on white 7.58; `#b22222` on white 6.68, on zebra 5.42. All pass AA 4.5:1. The built-in demo accents do NOT: pink `#ec4899` 3.53:1 (also white-on-pink header pills, `line-items.typ:243-272`), gold `#b8860b` 3.25:1 (`line-items.typ:280-291`). => as soon as users can pick brand colors, contrast becomes a real risk.

---

## 2. Corporate identity requirements

### 2.1 Logo

- Stripe: two assets - square `icon` and non-square `logo` (JPG/PNG, < 512 KB, >= 128 px); logo is used on invoice PDFs; brand settings are account-wide and flow into emails, checkout, portal, hosted invoice page and PDFs. https://docs.stripe.com/invoicing/customize
- Lexware Office: JPEG/PNG <= 2 MB, recommended max 800 px wide / 230 px high, size in percent, FIVE predefined logo positions, toggle "logo on first page only". https://help.lexware.de/de-form/articles/548153-rechnungsvorlage-firmenlogo-und-briefpapier-anpassen
- Zoho: logo with resize slider; header background image/color with "apply to first page only". https://www.zoho.com/us/invoice/help/settings/templates.html
- Odoo: company logo; primary/secondary colors are auto-derived from the logo. https://www.odoo.com/documentation/18.0/applications/studio/pdf_reports.html
- Design guidance: logo top-left or top-right; hierarchy should make total due and due date findable at a glance. https://wise.com/us/blog/invoice-best-practices , https://influenceflow.io/resources/professional-invoice-design-and-branding-a-complete-guide-for-2026/
- Typst constraint: under PDF/UA-1 an image without `alt` is a compile ERROR (EXPERIMENT `img.typ`: "PDF/UA-1 error: missing alt text"). Images inside `page.background` need no alt (EXPERIMENT `embed3.typ`).

Implication: logo = content-or-image + placement preset (left / center / right / in header band / in DIN header zone) + size (height or width) + first-page-only flag + alt text. SVG should be the recommended format (vector, works in all PDF standards).

### 2.2 Colors

- Stripe exposes exactly two: brand color, accent color. Odoo: primary + secondary. sevdesk: accent from a predefined palette. Zoho: label color, font color, background color per block, hex/RGB input.
- Needed roles for an invoice (derived from the literals already in the code base): text, muted text (descriptions, `luma(100)`), subtle text (`luma(80)`), rule/border (`gray`), surface/zebra (`#e2e8f0`), header fill + header text, accent/primary, negative/discount (`#b22222`), positive/surcharge (`#333333`), tax label (`#475569`). Today these live as repeated literals (section 1).
- Swiss QR-bill style guide: "Do not use any colored areas" in the payment part; font color always black. (SIX style guide p.5)
- PDF/A: device colors need an output intent; Typst handles sRGB automatically but rejects CMYK (EXPERIMENT).

### 2.3 Typography

- Products offer closed font lists (Lexware 5 fonts; Odoo 8: Lato, Roboto, Open Sans, Montserrat, Oswald, Raleway, Tajawal, Fira Mono), or base64 web fonts in HTML templates (sevdesk), or font upload (FastBill). https://hilfe.sevdesk.de/de/articles/9382437-selbststandige-anpassung-des-layouts , https://www.fastbill.com/vorlageneditor
- DIN 5008 address field: return-address/annotation zone 8 pt recommended (min 6 pt), address zone min 8 pt, below 10 pt use a sans-serif; no blank lines in the address field. https://www.din-5008-richtlinien.de/startseite/anschriftenfeld
- Numbers: tabular lining figures (OpenType `tnum`/`lnum`) are best practice for price columns so digits align. https://www.rwt.io/typography-tips/facts-about-figures-numeric-styles-with-opentype-features/ , https://typenetwork.com/articles/opentype-at-work-figure-styles . Typst: `text(number-width: "tabular", number-type: "lining")` (EXPERIMENT `fonts.typ`). Not used in the table today.
- Typst limitation: packages cannot ship fonts; fonts come from system, `--font-path` / `TYPST_FONT_PATHS`, or web-app project files. https://typst-community.github.io/extra-docs/packages/resources.html , https://github.com/typst/typst/discussions/5013 . Unknown family = warning + silent fallback (EXPERIMENT `fonts.typ`).

Implication: font roles (body, heading, numeric/mono) each taking `str | array` fallback chains; defaults must end in a font Typst embeds or that is ubiquitous ("Liberation Sans" is the current default; it is also one of the four fonts allowed in the Swiss QR payment part). CI pipelines need documentation for `--font-path`. A "strict fonts" check is not implementable inside Typst (no font introspection) - can only be documented.

### 2.4 Letterhead / stationery

Three real-world modes:

1. PRE-PRINTED PAPER: company prints on physical letterhead. The PDF must leave header/footer zones empty (no logo, no legal footer), but keep the address window and margins. orgaMAX: "print with or without Briefpapier". https://www.orgamax.de/funktionen/angebote-rechnungen/Rechnungsprogramm/ , https://info.orgamax.de/faq-orgamax-buchhaltung/wie-verwende-ich-mein-eigenes-briefpapier-in-orgamax
2. DIGITAL LETTERHEAD AS BACKGROUND: a designer-made A4 PDF used as background layer. Universal DACH convention: a TWO-PAGE PDF, page 1 -> first page, page 2 -> all following pages (Lexware, easybill, sevdesk). Users must then adjust margins so content does not collide. https://support.easybill.de/hc/de/articles/115004153065-Briefpapier-hochladen-und-hinterlegen , https://hilfe.sevdesk.de/de/articles/9382319-individuelle-gestaltung-der-dokumente
3. GENERATED LETTERHEAD: logo + sender block + footer columns rendered by the template (what invoice-pro does today, minus logo).

E-invoice conflict: Lexware forbids Briefpapier layouts for e-invoices ("technische Konflikte", and information present only on the letterhead is not machine-readable); logo stays allowed; XRechnung layouts must contain bank details. Users are told to keep a separate plain layout for e-invoices. https://help.lexware.de/de-form/articles/547953-drucklayouts-fur-e-rechnungen . easybill requires the letterhead itself to be PDF/A for e-invoices (search summary of the easybill help article above).
Typst equivalent (EXPERIMENT `embed.typ`, `embed2.typ`, `embed3.typ`): `image("x.pdf")` errors under `--pdf-standard a-3b` and `ua-1`; the same letterhead as SVG works under a-3b, ua-1 and a-3a+ua-1, with first/following page switching via `context here().page()`.

Implication: "background" must be a first-class layout property with `first` / `rest` variants, accept arbitrary content (so users pass `image("lh.svg")`), and come with safe-zone margins per page kind. A "pre-printed" switch must suppress generated header/logo/footer without changing geometry. Docs must state: for ZUGFeRD use SVG/PNG, not PDF.

### 2.5 Multi-brand, multi-entity, white-label

- Invoice Ninja: up to 10 companies per account, per-entity designs (invoice, quote, credit, purchase order, delivery note, statement) and per-client design overrides. https://invoiceninja.github.io/docs/advanced-topics/templates , https://www.agencyhandy.com/white-label-invoicing-software/
- Lexware: multiple print layouts, switchable per document; count limited by plan (2 for M/L, 9 for XL). https://help.lexware.de/de-form/articles/548593-mehrere-drucklayouts-erstellen-und-verwenden
- Zoho: templates per document type and assignable per customer.
- SAP S/4HANA: logo and footer text blocks are determined per organizational unit and injected into a shared master form. https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-sap/s-4hana-cloud-output-management-customize-master-form-for-logo-and-texts/ba-p/12850036
- Stripe Connect: each merchant of record has own numbering and branding. https://docs.stripe.com/invoicing/customize
- HoneyBook / OneBill: multi-brand or multi-company under one account. https://www.onebillsoftware.com/features-archive/white-label-bill-on-behalf-of/

Implication: brand must be a plain value that can be stored in a dictionary of brands and picked by key from data. A multi-entity setup needs brand AND legal sender data AND bank details to switch together - the brand object and `sender` are adjacent concerns; the API should make bundling them trivial (e.g. an "entity profile" is just a dictionary the user spreads into `invoice.with(..profile)`), without the theme owning legal data.

### 2.6 One brand across document types

- sevdesk downloads HTML templates per type (Rechnung, Mahnung, Angebot ...); Invoice Ninja per-entity designs; Zoho: quotes, invoices, credit notes, payment receipts, sales receipts; SAP: one master form reused by many content forms.
- § 35a GmbHG applies to ALL business letters incl. offers, order confirmations, invoices, receipts. https://www.ihk.de/berlin/service-und-beratung/recht-und-steuern/kaufmaennische-pflichten/pflichtangaben-geschaeftsbrief-4336766
- invoice-pro today renders only invoices (`src/locale/lang/base.typ:32-34`), credit notes via `preceding invoice` reference (`src/invoice.typ:76`).

Implication: the theme contract must not hard-wire "invoice"; brand + page layout should be reusable for any future document kind (quote, delivery note, reminder) and for a plain letter. Document-kind-specific styling (e.g. a red accent for reminders, "STORNO"/"COPY"/"DRAFT" stamp) is a COULD.

---

## 3. How products expose customization - and where users hit limits

| Product          | Knobs                                                                                                                                                                                                                                                                                                         | Escape hatch                                                                                        | Limits users hit                                                                                                                                                                                                                                                                                                        |
| :--------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :-------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Stripe Invoicing | logo + icon, brand color, accent color; default memo, footer, up to 4 custom fields, page size A4/Letter/auto, line-item grouping, customer language; invoice rendering templates (memo/footer/custom fields/grouping only)                                                                                   | none                                                                                                | no layout, no font, no column control; templates are dashboard-only; whole third-party niche exists to replace the PDF (e.g. Ultradox). https://docs.stripe.com/invoicing/customize , https://docs.stripe.com/invoicing/invoice-rendering-template , https://help.ultradox.com/en/samples/stripe/invoicesforstripe.html |
| Zoho Invoice     | template gallery; paper A5/A4/Letter, orientation, margins; font, font size, label/font colors; background image (<= 1 MB) and color; header/footer background with first-page-only; logo resize; page numbers; column visibility and labels; totals section; per-doc-type templates; per-customer assignment | none (no HTML/CSS)                                                                                  | no custom fonts, fixed block structure. https://www.zoho.com/us/invoice/help/settings/templates.html                                                                                                                                                                                                                    |
| Invoice Ninja v5 | full HTML/CSS + Twig; Body/Header/Footer/Includes sections; page size, margins, orientation; per-entity and per-client designs                                                                                                                                                                                | everything                                                                                          | requires HTML/CSS skills; whitelisted Twig only; pagination quirks of HTML-to-PDF. https://invoiceninja.github.io/docs/advanced-topics/templates                                                                                                                                                                        |
| sevdesk          | Briefpapier PDF (1 or 2 pages) + one of 11 layouts (6 premium at EUR 3.90/month) + accent from fixed palette; logo size                                                                                                                                                                                       | downloadable HTML templates per doc type, base64 fonts/images; paid layout service by sevdesk staff | real customization = paid service or HTML hacking. https://hilfe.sevdesk.de/de/articles/9382319-individuelle-gestaltung-der-dokumente , https://hilfe.sevdesk.de/de/articles/9382437-selbststandige-anpassung-des-layouts                                                                                               |
| Lexware Office   | logo (5 positions, size %, first page only), Briefpapier 2-page PDF, 5 fonts, per-element size/weight, page number on/off + position (footer center, footer right, content area), multiple layouts                                                                                                            | none                                                                                                | 2-9 layouts by plan; no Briefpapier on e-invoices. https://help.lexware.de/de-form/articles/548055-wie-bearbeite-ich-mein-drucklayout                                                                                                                                                                                   |
| easybill         | layouts + document templates; 2-page PDF letterhead; one layout with letterhead, one with logo only                                                                                                                                                                                                           | -                                                                                                   | letterhead must be PDF/A for e-invoices. https://support.easybill.de/hc/de/articles/115004153065-Briefpapier-hochladen-und-hinterlegen                                                                                                                                                                                  |
| FastBill         | visual template editor: logo, Briefpapier PDF, own fonts, free placement; unlimited templates for all doc types on higher plans                                                                                                                                                                               | -                                                                                                   | plan-gated. https://www.fastbill.com/vorlageneditor                                                                                                                                                                                                                                                                     |
| Billomat         | DOC/DOCX/RTF templates with MERGEFIELD placeholders, repeat blocks via bookmarks, optional background                                                                                                                                                                                                         | Word                                                                                                | fragile Word field handling. https://faq.billomat.com/de/dokumente-eigene-vorlagen-mit-microsoft-word-erstellen                                                                                                                                                                                                         |
| Odoo             | 7 layouts (Light, Boxed, Bold, Striped, Bubble, Wave, Folder) x 8 fonts x primary/secondary color (auto from logo) x background (blank/demo/custom image) x logo, tagline, address, footer, paper A4/Letter                                                                                                   | Studio / QWeb XML                                                                                   | header/footer edits affect ALL reports at once. https://www.odoo.com/documentation/18.0/applications/studio/pdf_reports.html                                                                                                                                                                                            |
| SAP S/4HANA      | master form template (page size, orientation, logo placement, sender address, footer blocks) + content form templates; logos/texts maintained in separate apps and resolved per org unit                                                                                                                      | Adobe LiveCycle Designer                                                                            | heavy tooling. https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-sap/s-4hana-output-management-customize-master-form-with-logo-footer-texts/ba-p/13410126                                                                                                                                         |

Pattern that emerges (a "customization ladder"):

- Level 0: pick a preset layout.
- Level 1: brand tokens - logo, 1-2 colors, font.
- Level 2: structure toggles - logo position, page numbers, first-page-only header, footer columns, column visibility, paper, margins, marks.
- Level 3: background/letterhead.
- Level 4: replace a block renderer (header, table, totals).
- Level 5: replace the whole document function.
  Closed SaaS products stop at level 2-3 and users complain or pay for services; HTML/Word-template products jump straight to level 5 and lose non-developers. invoice-pro today offers level 0 (2 presets), a thin slice of 1-2 (font, zebra, marks), and level 4-5 via `base-theme` slots (`src/themes/base-theme/base.typ:8-32`) - the middle of the ladder (levels 1-3) is what businesses actually use and what is missing.

---

## 4. Layout standards and envelopes

| Region | Standard                                          | Paper                        | Address position on sheet                                                                                                                                                                                                              | Envelope / window                                                                                                                                                                                                               | Notes                                                                                                                                                                                                                                                                                                                                                                |
| :----- | :------------------------------------------------ | :--------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DE     | DIN 5008:2020 Form A / B                          | A4                           | Address field 85 x 45 mm, 20 mm from left edge (text at 25 mm); top at 27 mm (A) / 45 mm (B); inside: 17.7 mm return-address+annotation zone (5 lines) + 27.3 mm address zone (6 lines), address zone starts 44.7 mm (A) / 62.7 mm (B) | DL / C6/5 left window (DIN 680)                                                                                                                                                                                                 | fold marks 87 + 192 mm (A) / 105 + 210 mm (B); hole mark 148.5 mm (letter-pro:18-30,155). Info block right of address field. https://www.din-5008-richtlinien.de/startseite/anschriftenfeld , https://en.wikipedia.org/wiki/DIN_5008                                                                                                                                 |
| AT     | OENORM A 1080 (2007 ed.; reported withdrawn 2018) | A4                           | in practice DIN-like, left window                                                                                                                                                                                                      | C6/5, DL                                                                                                                                                                                                                        | low confidence on exact mm; treat as DIN preset. https://www.austrian-standards.at/en/shop/onorm-a-1080-2007-03-01~p1536064                                                                                                                                                                                                                                          |
| CH     | SN 010130 (ed. 2016-12 covers both variants)      | A4                           | traditionally address on the RIGHT; left permitted                                                                                                                                                                                     | C5 right window: old 100 x 45 mm at 65 mm from bottom / 12 mm from right; new 90 x 40 mm at 77 mm from bottom / 17 mm from right; C6/5 right: 30 mm / 15 mm; C6/5 left window 100 x 45 at 25 mm from bottom / 104 mm from right | "Die Post empfiehlt nach wie vor den rechts adressierten Brief, gestattet aber auch das Adressfeld links." Source: https://www.inka.ch/assets/files/fensternormen.pdf ; https://www.post.ch/en/sending-letters/addressing-and-designing/designing-and-packaging-letters ; https://www.wir-machen-druck.ch/schweizer-norm-couverts-drucken-lassen,category,20322.html |
| FR     | NF Z 11-001                                       | A4                           | recipient block top RIGHT: about 110 mm from left, 50 mm from top                                                                                                                                                                      | DL 220 x 110, window right                                                                                                                                                                                                      | letter folded in three equal parts. https://lexpertbusiness.com/courrier-norme-afnor-exemple/ , https://norminfo.afnor.org/norme/nf-z11-001/presentation-des-lettres/94638                                                                                                                                                                                           |
| UK     | no single binding standard (BS 4264 envelopes)    | A4                           | address approx 42 mm from top, 20 mm from left for C5                                                                                                                                                                                  | C5 229 x 162, window 90 x 44 mm, 20 mm from left, 60 mm up; DL also common                                                                                                                                                      | https://www.cavaliermailing.com/services/envelope-insertion-enclosing/a4-address-position-guide/                                                                                                                                                                                                                                                                     |
| US/CA  | de-facto                                          | Letter 8.5 x 11 in, tri-fold | address roughly 2 - 2.75 in from top, left                                                                                                                                                                                             | #10 envelope 4 1/8 x 9 1/2 in; window 1 1/8 x 4 1/2 in, 7/8 in from left, 1/2 in from bottom                                                                                                                                    | https://crst.net/guides/envelope-sizes/window , https://www.4over4.com/help/envelopes/is-there-only-one-standard-sized-window-and-window-position-on-a-10-window-envelope                                                                                                                                                                                            |

Stripe picks A4 vs Letter automatically by customer geography with an explicit override `rendering.pdf.page_size = a4 | letter | auto`. https://docs.stripe.com/invoicing/customize

Implications

- Paper size and address-window rectangle are LAYOUT data, not brand data, and have sensible regional defaults. The cleanest mental model for users: `layout preset = paper + address window rect + side of info block + fold/hole mark positions + default margins`.
- A default derived from the locale REGION (de -> din-5008-a, ch -> ch-right, fr -> nf-z-11-001, us -> us-letter-10) would match the package's "smart defaults from locale" philosophy (compare `infer-tax` in `src/locale/region/ch.typ:22-40`), but must stay overridable because a Swiss company may use left-window envelopes and a German company may send digital-only.
- Fold marks depend on paper AND fold scheme (A4 -> DL/C6/5 tri-fold; A4 -> C5 half-fold at 148.5 mm; Letter tri-fold at 3.67 in). Marks should be derived from the preset, togglable, and their stroke/color themable (light gray marks are common on designed letterheads).
- letter-pro only knows DIN A/B (letter-pro:18-30); a Swiss right-window or US Letter layout needs either an upstream change or an own page scaffold.

---

## 5. Legal / regulatory content that constrains layout

### 5.1 Mandatory company footers

- DE: § 35a GmbHG / § 80 AktG / § 37a HGB: legal form and seat, register court + HRB number, all managing directors (and supervisory board chair) with surname and at least one full first name; applies to every business letter to a specific recipient including invoices; placement is free, footer is customary. https://dejure.org/gesetze/GmbHG/35a.html , https://www.frankfurt-main.ihk.de/recht/uebersicht-alle-rechtsthemen/handelsrecht/angaben-auf-geschaeftsbriefen-5279818
- FR: SIREN/SIRET, legal form + capital social, RCS + city, VAT number; B2B invoices also late-payment penalty rate and the EUR 40 recovery indemnity; EUR 15 fine per missing mention. https://www.legalplace.fr/guides/mentions-obligatoires-facture/ , https://www.entreprises.cci-paris-idf.fr/fiches-pratiques/factures-quelles-sont-les-mentions-obligatoires
- IT: art. 2250 c.c.: registered office, Registro Imprese office + number, REA, capital actually paid in, sole-shareholder status. https://www.brocardi.it/codice-civile/libro-quinto/titolo-v/capo-i/art2250.html
- ES: Registro Mercantil data (tomo, libro, folio, hoja) on invoices for sociedades mercantiles. https://www.cloudgestion.com/blog/software/factura-registro-mercantil/
- UK: Stripe explicitly names the Companies House registration number as the typical footer use case. https://docs.stripe.com/invoicing/customize

Implication: the footer is legally loaded content, typically 3-4 columns (company/address, contact, register/management/tax IDs, bank). Businesses want it (a) on every page or at least consistently, (b) generated from structured sender data with region-aware labels, (c) fully overridable. Today: `footer` is free content, first page only (letter-pro:190), undocumented.

### 5.2 Swiss QR-bill (SIX Style Guide QR-bill, pp. 4-12; https://www.six-group.com/dam/download/banking-services/standardization/qr-bill/style-guide-qr-bill-en.pdf)

- Payment part + receipt = 210 x 105 mm (A6/5), receipt 62 x 105 left, payment part 148 x 105 right, "must be positioned at the lower edge" when integrated.
- Fonts: only Arial, Frutiger, Helvetica, Liberation Sans; always black; no italic/underline. Payment part: title 11 pt bold, headings 6-10 pt bold (8 recommended), values 2 pt larger (10 recommended). Receipt: headings 6 pt, values 8 pt.
- Swiss QR code 46 x 46 mm with 5 mm quiet border; blank fields with 0.75 pt corner marks; white/natural paper, no coloured areas.
- PDF delivery: separation lines with scissors symbol, or the note "Separate before paying in" above the line (version 3).
- Languages: de, fr, it, en, rm.
  Implication for theming: (1) a regulated component must render in a BRAND-IMMUNE style scope (reset font/color/size regardless of theme); (2) the page layout must be able to RESERVE a bottom zone on the last page (or add a page) and keep the footer/page number out of it; (3) it only makes sense on A4; (4) the theme may style nothing inside but may choose scissors-vs-text separator. invoice-pro has a `ch` region (`src/locale/region/ch.typ`) but no QR-bill component yet - the theming contract should anticipate it.

### 5.3 EPC QR / GiroCode

EPC069-12 (v3.0, 2022): version <= 13, EC level M, recommended print size at least about 2 x 2 cm, needs quiet zone and dark-on-light contrast. https://www.europeanpaymentscouncil.eu/document-library/guidance-documents/quick-response-code-guidelines-enable-data-capture-initiation , https://girocodegenerator.com/en/wissen/epc-standard . Implication: QR foreground/background must not follow brand colors blindly (keep black on white or enforce high contrast); size has a floor.

### 5.4 Multi-page invoices

- "Seite x von y" plus repeating the invoice number on continuation pages is the common recommendation (lost-page detection); DIN 5008 also recommends page numbering from page 2. Lexware offers page number on/off and three positions. https://de.etc.beruf.selbstaendig.narkive.com/frarcXjl/mehrseitige-rechnung-wie-gestalten
- Carry-over ("Uebertrag"/"Zwischensumme") at page breaks is a frequent user wish (JTL, Fakturama forums) but not legally required. https://forum.jtl-software.de/threads/zwischensumme-uebertrag-bei-mehrseitigen-rechnungen-inkl-video.35856/ , https://www.fakturama.info/community/allgemeines/uebertrag-vortrag-bei-mehrseitigen-rechnungen/paged/2/
- Table header must repeat on each page (already: `table.header` at `src/themes/components/line-items/table.typ:339`).

---

## 6. E-invoicing, archival and accessibility constraints

### 6.1 PDF/A-3 (ZUGFeRD / Factur-X)

- Requirements relevant to styling: all fonts embedded (subset ok), device colors need an OutputIntent/ICC profile, no JavaScript/encryption, XMP metadata; transparency is forbidden only in PDF/A-1, allowed from PDF/A-2/3. https://gpdf.com/blog/pdfa-3-explained-and-how-to-verify/ , https://www.invoicenavigator.eu/learn/zugferd , https://itextpdf.com/blog/technical-notes/creating-zugferd-itext
- Typst supports a-1b ... a-4e and lets you combine with ua-1 (not a-4 + ua-1). https://typst.app/docs/reference/pdf/
- EXPERIMENTS (0.15.1):
  - `cmyk()` fill -> "PDF/A-3b error: the PDF is missing a CMYK profile; hint: CMYK colors are not yet supported in this export mode".
  - `color.transparentize(50%)` -> OK in a-3b, error in a-1b. The code base already uses `black.transparentize(100%)` (`src/themes/base-theme/line-items.typ:133`) - fine for a-3b, would break a-1b (irrelevant for ZUGFeRD).
  - `oklch()` and `rgb()` fine.
  - `image("*.pdf")` -> "embedding PDFs is currently not supported in this export mode" for a-3b AND ua-1. SVG fine.
- Product parallel: Lexware bans letterhead PDFs on e-invoices; easybill requires PDF/A letterheads.

### 6.2 PDF/UA and accessibility

- Typst 0.14: tagged PDF by default; PDF/UA-1 export with checks; PDF/A-xa levels. https://typst.app/blog/2025/typst-0.14/ , https://typst.app/docs/changelog/0.14.0/
- What Typst enforces under ua-1: alt text on images/equations, document title (EXPERIMENTS `img.typ`, `fonts2.typ`). What it does NOT check: contrast, reading order, table header presence (EXPERIMENT `tbl.typ` compiled without error despite no `table.header` and 3.5:1 pink 5 pt text).
- Author guidance (https://typst.app/docs/guides/accessibility/): use `table.header`/`table.footer`; mark decorative content with `pdf.artifact`; never rely on color alone; WCAG AA 4.5:1 (3:1 for large text); set `text(lang:)`; `grid`/`box`/`place` are transparent to AT and read in SOURCE order -> a theme that visually rearranges blocks must still emit them in logical order; combine "PDF/UA-1 with PDF/A-2a or PDF/A-3a".
- Law: European Accessibility Act applies from 2025-06-28 to B2C e-commerce and services; customer-facing PDFs such as invoices and statements are in scope in practice; harmonised standard EN 301 549 maps WCAG to non-web documents (reading order, table headers, contrast); transition for existing content until 2030; micro-enterprises providing services are exempt. https://www.twobirds.com/en/insights/2025/a-guide-to-navigating-the-european-accessibility-act-for-online-retailers-service-providers-and-plat , https://pdfix.net/european-accessibility-act-2025-are-your-pdfs-ready/ , https://www.levelaccess.com/compliance-overview/european-accessibility-act-eaa/ , https://www.deque.com/en-301-549-compliance/
- Status quo: default DIN theme passes `ua-1` and `a-3a,ua-1` (EXPERIMENT `ua.typ`); `blank` fails (no title). Passing the export check is not the same as being correct: the document language is tagged "de" for every locale (lang bug, section 1), which a screen reader would use to pick the wrong voice for English/French invoices.

Implications for the theme contract

1. Core (not theme) sets document title/author/lang/keywords.
2. Logo API has `alt`; decorative things (marks, bands, backgrounds, separators) go through `pdf.artifact` or `page.background`.
3. Slots must be emitted in reading order independent of visual placement.
4. Ship palettes that pass AA; offer a contrast helper (`on-color` auto black/white; optional strict check).
5. Table renderers replaced by third-party themes must keep `table.header` - part of the documented contract.
6. CI for built-in themes should compile with `--pdf-standard a-3a,ua-1`.

---

## 7. Print vs. digital-only

- Digital-first is now the norm (DE B2B e-invoice mandate: receive since 2025, send phased 2027/2028), so fold/hole marks are noise in most PDFs; yet postal sending persists for B2C, reminders, and conservative industries. Marks toggles exist today (`din-5008.typ:10-11`); default is ON.
- Office printers take RGB; CMYK matters only for offset-printed stationery, which is exactly the pre-printed-paper case where the PDF contains no brand color at all. Since Typst cannot emit CMYK under PDF/A, CMYK is a WON'T for now. https://www.vistaprint.com/hub/correct-file-formats-rgb-and-cmyk
- Ink-saving / grayscale: large solid header bands and dark fills are expensive and can turn muddy on mono lasers; zebra should be very light (the current `#e2e8f0` is about 10 % gray equivalent and prints fine) and information must not depend on hue (discount red vs. surcharge gray also differ by sign - good: `src/themes/components/line-items/table.typ:74-79`).
- A4 vs Letter: see section 4.
- A useful framing seen in orgaMAX/JTL: the same document has an OUTPUT MODE - "print on letterhead", "print on blank paper", "PDF/e-mail", "e-invoice". Mode changes: background on/off, generated header/footer on/off, marks on/off, maybe mono palette. For a Typst package this maps naturally to `sys.inputs` (e.g. `--input output=print`) read by the user's file, so the theme only needs to make each of these a simple switch.

---

## 8. Trends

- Design tokens: W3C DTCG Format Module 2025.10 is the first stable version (2025-10-28). Files `.tokens` / `.tokens.json`, media type `application/design-tokens+json`; token = `$value` (+ `$type`, `$description`, `$extensions`, `$deprecated`); groups; aliases `{group.token}` and JSON-Pointer `$ref`; `$extends`; types color (`{colorSpace, components, alpha?, hex?}`), dimension (`{value, unit: px|rem}`), fontFamily (string or array), fontWeight, typography (`{fontFamily, fontSize, fontWeight, lineHeight, letterSpacing}`), border, strokeStyle, shadow, gradient, duration, cubicBezier, transition, number. Supported by Figma, Penpot, Sketch, Tokens Studio, Style Dictionary, Terrazzo. https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/ , https://www.designtokens.org/tr/drafts/format/
  - Relevance: a brand kit exported from Figma could feed invoices directly. Typst reads JSON natively (EXPERIMENT `fonts.typ` loads `brand.json` and builds `rgb(hex)`); dimension units px/rem need mapping to pt; alias resolution needs a small resolver. Reasonable as an ADAPTER (COULD), not as the native schema.
- Brand config from data files: APITemplate/PDF.co/Docamatic-style pipelines feed JSON into templates; invoice-pro's roadmap already lists "Data Loading ... JSON, CSV, YAML" (`README.md:154`). A brand that is pure data (strings, numbers, arrays, nested dicts - no closures) can live in the same JSON/YAML/TOML as the invoice.
- Batch/CI: one theme value reused for thousands of compilations; locale docs already warn that heavy runtime patching slows compilation (`docs/docs/api-reference/locale/custom.md:10`) - theme construction should be cheap and deterministic.
- Aesthetics: two poles - classic DIN letter vs. minimal "Stripe-like" (lots of whitespace, one accent color, large amount-due, thin rules, no boxes); in between Odoo's Boxed/Bold/Striped and header-band designs (full-bleed colored band with white logo). Full-bleed bands require drawing outside margins (background layer or negative pad) - a layout capability, not just color.
- Payment UX on the document: QR codes (EPC, Swiss QR, UPI), "pay online" links/buttons - a visual block that wants accent styling but has regulated internals (section 5).

---

## 9. PRIORITIZED REQUIREMENT CATALOGUE

Priority semantics: MUST = without it the v0.5.0 API cannot claim to serve businesses; SHOULD = expected by a large share, design must at least leave room; COULD = nice, design must not block it; WON'T = explicitly out of scope for this API (now).

### A. Brand identity

| ID  | Prio   | Capability                                                                                                                                                                                           | Rationale                                                                          | Source                                                                                               |
| :-- | :----- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------- |
| R1  | MUST   | A BRAND value (logo, color roles, font roles) separate from page layout and from component renderers, reusable across themes and document kinds                                                      | Universal product pattern; enables multi-brand and doc families                    | Stripe branding; SAP master form; Odoo layout; sec. 3                                                |
| R2  | MUST   | Logo: any content/image, placement presets (left/center/right/in band), size, first-page-only, `alt` text                                                                                            | Top knob in every product; PDF/UA hard error without alt                           | Lexware; Stripe; EXPERIMENT `img.typ`; grep: no logo today                                           |
| R3  | MUST   | Semantic COLOR ROLES (primary/accent, text, muted, rule, surface/zebra, header fill + on-header text, negative, positive) replacing per-file literals; whole palette derivable from 1-2 brand colors | Users think "my brand color", not "color-row-even"; literals duplicated in 4 files | Stripe (2 colors), Odoo (2, auto); `line-items.typ:11-17`, `table.typ:139-147`, `totals.typ:316-318` |
| R4  | MUST   | FONT ROLES (body, heading, numeric) as family fallback chains; size scale; tabular lining figures by default in amount columns                                                                       | Brand fonts + robust fallback in CI; aligned digits                                | Typst font limits; tnum sources; `bank-details.typ:40` only                                          |
| R5  | SHOULD | Contrast safety: auto on-color (black/white) for fills, optional strict check >= 4.5:1, AA-compliant defaults                                                                                        | EAA/WCAG; brand accents commonly fail (pink 3.53, gold 3.25)                       | typst a11y guide; `contrast.js` results                                                              |
| R6  | SHOULD | Brand is PURE DATA and loadable from json/yaml/toml (logo as path)                                                                                                                                   | ERP/CI pipelines, non-developers swap brands                                       | README roadmap `README.md:154`; APITemplate; EXPERIMENT `brand.json`                                 |
| R7  | COULD  | Import adapter for W3C DTCG `.tokens.json` (color, dimension, fontFamily, typography, aliases)                                                                                                       | Figma/Tokens Studio brand kits                                                     | designtokens.org 2025.10                                                                             |
| R8  | MUST   | Partial override with cascading defaults (`.with(...)`/deep-merge), forward compatible when new tokens appear                                                                                        | Same promise as locale API                                                         | `locale/custom.md:14,28`                                                                             |

### B. Page layout / stationery

| ID  | Prio   | Capability                                                                                                                                                             | Rationale                                                                                                             | Source                                                                        |
| :-- | :----- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------- |
| R9  | MUST   | Paper size selectable (at least A4, US Letter; any Typst paper or custom)                                                                                              | Hard A4 today; Stripe/Zoho/Odoo all offer Letter                                                                      | letter-pro:133; EXPERIMENT `letter.typ`                                       |
| R10 | MUST   | Address-window geometry as named layout presets + custom rect: DIN 5008 A/B, CH right (SN 010130) and left, FR right (NF Z 11-001), UK C5/DL, US #10                   | Envelope windows differ by country; wrong position = unusable for post                                                | sec. 4 sources                                                                |
| R11 | SHOULD | Default layout preset inferred from locale region, always overridable                                                                                                  | Matches "smart regional defaults" philosophy (`infer-tax`)                                                            | `region/ch.typ:22-40`; Stripe `page_size: auto`                               |
| R12 | MUST   | Print marks (fold, hole) derived from preset, togglable, stylable; one-switch "digital" mode                                                                           | Digital-first sending; exists partially                                                                               | `din-5008.typ:10-11`; letter-pro:141-158                                      |
| R13 | MUST   | Page background / letterhead with separate FIRST and FOLLOWING page variants, any content (SVG/PNG/native); margins/safe zones per page kind                           | THE DACH feature; impossible today                                                                                    | Lexware, easybill, sevdesk; letter-pro:138; EXPERIMENT `bg.typ`, `embed3.typ` |
| R14 | MUST   | "Pre-printed stationery" mode: suppress generated logo/sender header/footer but keep geometry                                                                          | Physical letterhead users                                                                                             | orgaMAX; JTL forum                                                            |
| R15 | MUST   | Structured multi-column LEGAL FOOTER, every page or first-only, auto-filled from sender data with localized labels, fully overridable                                  | § 35a GmbHG, FR/IT/ES mentions; footer is page-1-only and free-form today                                             | sec. 5.1; letter-pro:190                                                      |
| R16 | MUST   | Page numbering from invoice LOCALE strings, position options, on/off; invoice number repeated on continuation pages                                                    | Lost-page detection; today the label is German for every locale (lang bug, sec. 1) and only de/en exist in letter-pro | letter-pro:174-180; `root.typ:62,158`; Lexware positions                      |
| R17 | SHOULD | Distinct compact continuation-page header (small logo, doc number, page)                                                                                               | First-page-only headers are a standard toggle                                                                         | Zoho, Lexware                                                                 |
| R18 | MUST   | Reserved REGULATED ZONES + brand-immune rendering scope (Swiss QR-bill 210 x 105 mm bottom of last A4 page; EPC QR min size/contrast; DIN address zone min font sizes) | Compliance beats branding                                                                                             | SIX style guide pp. 4-12; EPC069-12; DIN 5008                                 |
| R19 | SHOULD | Header arrangement variants (logo left / sender right, centered, band; info block right vs. reference line) without writing a renderer                                 | Level-2 knobs of the ladder                                                                                           | Lexware 5 positions; Odoo layouts                                             |
| R20 | COULD  | Full-bleed elements (colored header band, side stripe)                                                                                                                 | Modern aesthetics; needs out-of-margin drawing                                                                        | Odoo Bold/Wave; trend                                                         |
| R21 | COULD  | Carry-over / running subtotal at page breaks                                                                                                                           | Popular wish, not legally required, technically hard in Typst                                                         | JTL, Fakturama forums                                                         |

### C. Components

| ID  | Prio   | Capability                                                                                                                                                                     | Rationale                                                      | Source                                                                                 |
| :-- | :----- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------- | :------------------------------------------------------------------------------------- |
| R22 | MUST   | All built-in renderers (table, totals, payment goal, bank details, signature, header, footer) read brand tokens - one color/font change restyles the whole document coherently | Today only zebra colors are reachable                          | `din-5008.typ:32-35`                                                                   |
| R23 | SHOULD | Table style knobs: header fill/text, zebra on/off, rule weights, density, total emphasis (bold rule / band / box)                                                              | Level-2 knobs; "total due prominent"                           | Zoho; design guides; existing internal `styles` dict `base-theme/line-items.typ:16-37` |
| R24 | MUST   | Per-slot renderer override stays available as escape hatch, with a documented, stable `(ctx, data) => content` contract                                                        | Equivalent of Invoice Ninja's HTML/CSS freedom; avoids forking | `base-theme/base.typ:8-32`                                                             |
| R25 | SHOULD | Named STYLE PRESETS orthogonal to brand (classic DIN, modern-minimal, bold band, boxed)                                                                                        | Odoo: 7 layouts x brand; variants already half-exist           | `base-theme/line-items.typ:42,242,279,297`                                             |
| R26 | COULD  | Overlays/stamps (DRAFT, COPY, PAID, STORNO) as theme foreground                                                                                                                | Common in products                                             | Zoho/Invoice Ninja                                                                     |

### D. Document family and multi-brand

| ID  | Prio   | Capability                                                                                                                        | Rationale                                                          | Source                                                    |
| :-- | :----- | :-------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------- | :-------------------------------------------------------- |
| R27 | SHOULD | Theme contract is document-kind agnostic (invoice, credit note, quote, order confirmation, delivery note, reminder, plain letter) | One brand across all business letters; legal footer applies to all | § 35a GmbHG scope; SAP master form; `lang/base.typ:32-34` |
| R28 | SHOULD | Brand selection by key from data; easy bundling of brand + sender + bank as an "entity profile" spread into `invoice.with(..)`    | Agencies, holdings, franchises, white-label                        | Invoice Ninja 10 companies; Stripe Connect; SAP org units |
| R29 | COULD  | Context-sensitive theming: theme may react to ctx (e.g. ZUGFeRD -> drop background; credit note -> accent variant)                | Lexware forces separate e-invoice layout                           | Lexware e-invoice article                                 |

### E. Compliance and output

| ID  | Prio   | Capability                                                                                                                                                                                | Rationale                                                       | Source                                          |
| :-- | :----- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------- | :---------------------------------------------- |
| R30 | MUST   | Built-in themes compile under `--pdf-standard a-3b` with any valid brand (no CMYK, no PDF images required)                                                                                | ZUGFeRD is a headline feature                                   | `e-invoicing.md:39-47`; EXPERIMENTS             |
| R31 | MUST   | Built-in themes compile under `ua-1` / `a-3a,ua-1`: alt on logo, decorative = artifact, `table.header`, logical source order; document metadata set by CORE for every theme incl. `blank` | EAA; currently `blank` fails                                    | EXPERIMENT `ua-blank.typ`; `document.typ:66-78` |
| R32 | SHOULD | Guard rails with actionable panics in the `types.require` style (e.g. cmyk color + zugferd, PDF background + zugferd, QR-bill on Letter)                                                  | Typst's own errors are late and cryptic                         | `din-5008.typ:19`; EXPERIMENT messages          |
| R33 | SHOULD | Mono / ink-saving palette variant and "no large fills" option                                                                                                                             | Office printing                                                 | sec. 7                                          |
| R34 | WON'T  | CMYK/spot colors, ICC handling, bleed and crop marks                                                                                                                                      | Typst rejects CMYK in PDF/A; offset print = pre-printed mode    | EXPERIMENT `fonts.typ`                          |
| R35 | WON'T  | Shipping/loading font files via theme                                                                                                                                                     | Typst limitation; document `--font-path` instead                | typst discussions 5013                          |
| R36 | WON'T  | WYSIWYG designer, HTML/CSS or Word template import                                                                                                                                        | Outside a Typst package                                         | -                                               |
| R37 | WON'T  | Branding of e-mails, hosted pages, portals                                                                                                                                                | Outside PDF generation                                          | Stripe scope comparison                         |
| R38 | WON'T  | Embedding PDF letterheads in e-invoices                                                                                                                                                   | Typst: unsupported in standard modes -> document SVG conversion | EXPERIMENT `embed.typ`                          |

### F. Developer experience / automation

| ID  | Prio   | Capability                                                                                                                                               | Rationale                                                                 | Source                                 |
| :-- | :----- | :------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------ | :------------------------------------- |
| R39 | MUST   | Theme/brand are plain immutable values built once and reusable across documents; no global state; cheap construction                                     | Batch pipelines; package moved away from global state in 0.2.0            | `README.md:150`; `locale/custom.md:10` |
| R40 | MUST   | Stable public contract so third parties can publish theme/brand packages (like custom locale packages)                                                   | Ecosystem; agencies ship client themes                                    | `locale/custom.md:36-134`              |
| R41 | SHOULD | Validation of unknown keys / wrong types with path-style messages (`theme::brand::color::primary`)                                                       | Matches existing error style                                              | `din-5008.typ:19`                      |
| R42 | SHOULD | Output-mode friendliness: every print/digital/e-invoice difference is a single switch so users can drive it from `sys.inputs`                            | One source, several outputs                                               | orgaMAX/JTL pattern                    |
| R43 | COULD  | Brand specimen / preview helper (palette with contrast ratios, fonts, logo, sample table)                                                                | QA for designers; catches silent font fallback                            | EXPERIMENT: unknown font only warns    |
| R44 | SHOULD | Migration path: `themes.DIN-5008(form:, font:, hole-mark:, folding-marks:, color-row-*, margin:, footer:)` keeps working or has a documented 1:1 mapping | Existing users; docs promised breaking changes but README shows this call | `README.md:44`; `theme.md:27-35`       |

---

## 10. PERSONAS / SCENARIOS (with wish code)

All snippets are illustrative wish code. Shared style assumptions taken from existing APIs: kebab-case keys, dictionaries with cascading defaults, preset namespaces (`locale.en-de` -> `layouts.din-5008-a`), `.with()` for small patches, factories for new definitions.

### P1. Freelancer (DE, Kleinunternehmerin), digital-only, five minutes of setup

Wants: own logo, one accent color, nicer font, no fold marks, everything else default. Must never need to know what a "slot" is.

```typst
#show: invoice.with(
  theme: themes.DIN-5008(
    brand: (
      logo: image("logo.svg", alt: "Studio Lina Berg"),
      color: rgb("#0f766e"),          // one color -> whole palette
      font: ("Inter", "Liberation Sans"),
    ),
    marks: false,                      // digital only
  ),
  locale: locale.de-de,
  sender: (...), recipient: (...), invoice-nr: "2026-014",
)
```

Needs: R1-R4, R8, R12, R22, R44.

### P2. German GmbH with pre-printed letterhead AND a digital twin

Accounting prints reminders and some B2C invoices on physical stationery (tray 2), e-mails the rest with the designer's letterhead as background, and sends ZUGFeRD to B2B customers. Legal footer per § 35a GmbHG.

```typst
#let mode = sys.inputs.at("output", default: "pdf")   // "print" | "pdf" | "einvoice"

#let acme = brand(
  logo: image("acme.svg", alt: "ACME Maschinenbau GmbH"),
  colors: (primary: rgb("#003a70"), accent: rgb("#e2001a")),
  fonts: (body: ("Source Sans 3", "Liberation Sans")),
)

#show: invoice.with(
  theme: themes.DIN-5008(
    form: "B",
    brand: acme,
    stationery: if mode == "print" { "pre-printed" }   // nothing generated in header/footer zones
      else if mode == "pdf" {
        (first: image("letterhead-p1.svg"), rest: image("letterhead-p2.svg"))
      } else { none },                                   // e-invoice: generated header + footer
    margin: (first: (top: 45mm, bottom: 35mm), rest: (top: 30mm, bottom: 35mm)),
    marks: mode == "print",
    footer: footer.legal(columns: 4),   // built from sender: register, directors, VAT ID, bank
    page-number: (position: "footer-right"),
  ),
  sender: (
    name: "ACME Maschinenbau GmbH", ...,
    register: (court: "Amtsgericht Stuttgart", number: "HRB 12345"),
    management: ("Dr. Erika Muster", "Max Beispiel"),
    vat-id: "DE123456789",
  ),
  ...
)
```

Needs: R13-R17, R30, R38 (docs: SVG not PDF), R42.

### P3. Swiss SME with QR-bill, right-hand address window

Treuhand office in Bern, C5 envelopes with window right, invoices in de-CH and fr-CH, QR payment part at the bottom of the last page. Brand font is a serif - but the payment part must stay Liberation Sans/black.

```typst
#show: invoice.with(
  locale: locale.de-ch,                       // -> default layout would be layouts.ch-right
  theme: themes.letter(
    layout: layouts.ch-right,                 // or layouts.ch-left; or layouts.custom(address: (x: 118mm, y: 50mm, w: 85mm, h: 40mm))
    brand: (logo: image("logo.svg", alt: "Treuhand Aare AG"), color: rgb("#7a1f2b"),
            fonts: (body: ("Source Serif 4", "Libertinus Serif"))),
  ),
  ...
)
#line-items[ ... ]
#qr-bill(account: "CH44 3199 9123 0008 8901 2", reference: auto)
// theme reserves 105mm at the bottom of the last page, renders the slip in a
// brand-immune scope, adds the scissors line for PDF output
```

Needs: R10, R11, R18, R16 (de/fr/it labels), R9 (A4 enforced for QR-bill -> R32 guard).

### P4. Agency / holding with white-label brands

A billing service provider issues invoices for 12 client brands from one repo. Brand, legal sender and bank data switch together, chosen by a key in the job's JSON. Non-developers edit `brands/*.toml`.

```typst
// brands/nordlicht.toml
// [brand]   logo = "nordlicht.svg"  logo-alt = "Nordlicht Energie"
// [brand.colors] primary = "#0b3d91"  accent = "#ffb000"
// [brand.fonts]  body = ["IBM Plex Sans", "Liberation Sans"]
// [sender]  name = "Nordlicht Energie GmbH" ...
// [bank]    iban = "DE.." bic = ".."

#let job = json(sys.inputs.job)
#let entity = toml("brands/" + job.brand + ".toml")

#show: invoice.with(
  theme: themes.modern(brand: brand.from-data(entity.brand, root: "brands/")),
  sender: entity.sender,
  ..job.header,
)
#line-items(job.items)
#bank-details(..entity.bank)
```

Needs: R6, R28, R39, R40, R41 (typos in TOML keys must be reported clearly).

### P5. SaaS batch pipeline (CI, thousands of invoices per night)

Subscription SaaS renders invoices from a queue in containers: deterministic output, pinned fonts, ZUGFeRD + accessible, zero warnings tolerated, theme built once in a shared module.

```typst
// theme.typ (shared, versioned)
#let company-theme = themes.modern(
  brand: brand.from-tokens(json("design/brand.tokens.json")),   // W3C DTCG export from Figma
  layout: layouts.auto,            // from locale region of each invoice: A4/DIN vs Letter/#10
  marks: false,
)

// invoice.typ
#import "theme.typ": company-theme
#let d = json(sys.inputs.data)
#show: invoice.with(theme: company-theme, locale: locale.at(d.locale), zugferd: ..., ..d.header)
```

```bash
typst compile --font-path ./fonts --ignore-system-fonts \
  --pdf-standard a-3a,ua-1 --input data=job-81723.json invoice.typ out/81723.pdf
```

Needs: R7, R11, R30, R31, R39, R32 (fail fast), R43 (specimen in CI to catch silent font fallback).

### P6. Design-conscious studio ("Stripe-like", not a DIN letter)

Branding studio wants whitespace, a big amount-due, thin rules, no zebra, a full-bleed colored band with a white logo, custom header renderer, tabular figures - while keeping the address in the DIN window because some clients want paper.

```typst
#let studio = brand(
  logo: image("mark-white.svg", alt: "Atelier Nord"),
  colors: (primary: rgb("#111827"), accent: rgb("#6366f1"), surface: none),
  fonts: (body: "Inter", heading: "Fraunces", numeric: "Inter"),
)

#show: invoice.with(
  theme: themes.modern(
    brand: studio,
    layout: layouts.din-5008-b,
    header: (style: "band", bleed: true),            // level-2 knob
    table: (zebra: false, rules: "hairline", density: "comfortable"),
    totals: (emphasis: "large"),
  ).with(
    // level-4 escape hatch: replace one slot, still receives tokens
    payment-goal: (ctx, data) => block(fill: ctx.theme.colors.accent.lighten(90%), inset: 1em)[...],
  ),
  ...
)
```

Needs: R3, R4, R19, R20, R23, R24, R25, R5 (white-on-indigo must be contrast-checked).

### P7. Accessibility-bound public-sector supplier / B2C utility

Supplier to municipalities (XRechnung/ZUGFeRD) and B2C customers (EAA). Needs PDF/UA-1 + PDF/A-3a, AA contrast guaranteed, no information by color alone, logo alt text, screen-reader-sane order, and a statement they can show auditors.

```typst
#show: invoice.with(
  theme: themes.DIN-5008(
    brand: (
      logo: image("stadtwerke.svg", alt: "Stadtwerke Musterstadt"),
      color: rgb("#00843d"),
    ),
    accessibility: "strict",     // panic if any token pair < 4.5:1; decorative marks as artifacts
    marks: false,
  ),
  ...
)
// typst compile --pdf-standard a-3a,ua-1 ...
```

Needs: R5, R31, R32, R2 (alt), R22.

### P8. US customer / US subsidiary on Letter paper

German company's US subsidiary: Letter paper, #10 window envelope, en-US formats, no fold/hole marks in DIN positions, no VAT footer but "Remit to" block; same corporate brand as the parent.

```typst
#import "corporate.typ": corporate-brand        // same brand value as the German parent

#show: invoice.with(
  locale: locale.en-us,                          // (region not shipped yet)
  theme: themes.letter(
    layout: layouts.us-letter-10,                // paper: "us-letter", address window for #10, tri-fold marks
    brand: corporate-brand,
    footer: footer.columns([Remit to: ...], [Questions? billing\@acme.com]),
  ),
  ...
)
```

Needs: R9, R10, R11, R1 (brand reuse across entities), R15 (footer not DE-specific).

---

## 11. Tensions the designers must resolve (facts, not answers)

1. `themes.DIN-5008` currently means BOTH "DIN address geometry" and "the default look". Businesses need DIN geometry with a modern look (P6) and the default look on Swiss/US geometry (P3, P8). Layout preset and visual style are independent axes in every product studied.
2. letter-pro owns `set page` (paper, background, footer, numbering: letter-pro:132-195). R9, R13, R15, R16, R17, R18 all collide with that. Either letter-pro gains options or invoice-pro needs its own page scaffold; from the business side only the outcome matters.
3. Brand-as-pure-data (R6) vs. logo-as-content and renderer closures (R24): products solve this by keeping data (tokens, paths) and code (templates) separate. A brand file can only carry a logo PATH; resolving it needs a root directory (Typst paths are relative to the file calling `image`), so the user-side must call `image()` or pass a loader.
4. Regulated zones (R18) mean the theme cannot be a simple global `set text(...)`/`set` cascade: some components need a reset scope.
5. Accessibility source order vs. visual arrangement: header variants (R19) must reorder visually without reordering content.
6. Legal footer needs structured sender fields (register court, directors, capital) that the `sender` dictionary does not have today (`README.md:46-51` shows name/address/city/tax-nr); that is an `invoice`-header concern adjacent to theming.
7. Region-inferred layout (R11) introduces a locale -> theme dependency; today locale and theme are independent arguments of `invoice` (`README.md:43-45`).

---

## 12. Experiments index (all under `.../scratchpad/proto/business-req/`)

| File                                           | Finding                                                                                                                                                      |
| :--------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ua.typ`                                       | Default DIN invoice compiles under `ua-1`, `a-3b`, `a-3a`, `a-3a,ua-1` without errors                                                                        |
| `ua-blank.typ`                                 | `themes.blank` fails `ua-1`: "missing document title"                                                                                                        |
| `bg.typ`, `bg-1.png`, `bg-2.png`               | `set page(background: ...)` before `invoice` is wiped by DIN theme; footer page label "Seite 1 von 2"                                                        |
| `letter.typ`                                   | `set page(paper: "us-letter")` overridden -> 595.28 x 841.89 pt                                                                                              |
| `pg-en-de.typ`, `pg-fr-fr.typ`, `pg-de-de.typ` | page label is "Seite x von y" for all three locales; `text.lang` is always "de" inside the invoice body                                                      |
| `fonts.typ`                                    | unknown font = warning only; `json()` brand loading works; `number-width: "tabular"` works; `cmyk()` breaks PDF/A-3b and a-1b; transparency breaks only a-1b |
| `img.typ`                                      | image without alt = hard error under `ua-1`                                                                                                                  |
| `tbl.typ`                                      | table without `table.header` and 3.5:1 tiny text pass `ua-1` (not checked)                                                                                   |
| `embed.typ`, `embed2.typ`                      | PDF images rejected under a-3b and ua-1 ("embedding PDFs is currently not supported in this export mode")                                                    |
| `embed3.typ`                                   | SVG letterhead as page background with first/rest switching works under a-3b, ua-1, a-3a+ua-1; no alt needed in background                                   |
| `contrast.js`                                  | WCAG ratios of current defaults and demo accents                                                                                                             |

---

## 13. Source list (URLs)

Products

- https://docs.stripe.com/invoicing/customize
- https://docs.stripe.com/invoicing/invoice-rendering-template
- https://help.ultradox.com/en/samples/stripe/invoicesforstripe.html
- https://www.zoho.com/us/invoice/help/settings/templates.html
- https://invoiceninja.github.io/docs/advanced-topics/templates
- https://hilfe.sevdesk.de/de/articles/9382319-individuelle-gestaltung-der-dokumente
- https://hilfe.sevdesk.de/de/articles/9382437-selbststandige-anpassung-des-layouts
- https://help.lexware.de/de-form/articles/548153-rechnungsvorlage-firmenlogo-und-briefpapier-anpassen
- https://help.lexware.de/de-form/articles/547953-drucklayouts-fur-e-rechnungen
- https://help.lexware.de/de-form/articles/548055-wie-bearbeite-ich-mein-drucklayout
- https://help.lexware.de/de-form/articles/548593-mehrere-drucklayouts-erstellen-und-verwenden
- https://support.easybill.de/hc/de/articles/115004153065-Briefpapier-hochladen-und-hinterlegen
- https://www.fastbill.com/vorlageneditor
- https://faq.billomat.com/de/dokumente-eigene-vorlagen-mit-microsoft-word-erstellen
- https://www.odoo.com/documentation/18.0/applications/studio/pdf_reports.html
- https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-sap/s-4hana-cloud-output-management-customize-master-form-for-logo-and-texts/ba-p/12850036
- https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-sap/s-4hana-output-management-customize-master-form-with-logo-footer-texts/ba-p/13410126
- https://www.orgamax.de/funktionen/angebote-rechnungen/Rechnungsprogramm/
- https://forum.jtl-software.de/threads/rechnung-aus-briefpapier-als-email-schicken.17321/
- https://www.agencyhandy.com/white-label-invoicing-software/
- https://www.onebillsoftware.com/features-archive/white-label-bill-on-behalf-of/
- https://apitemplate.io/use-cases/invoice-automation/

Layout standards

- https://www.din-5008-richtlinien.de/startseite/anschriftenfeld
- https://en.wikipedia.org/wiki/DIN_5008
- https://www.inka.ch/assets/files/fensternormen.pdf
- https://www.post.ch/en/sending-letters/addressing-and-designing/designing-and-packaging-letters
- https://www.wir-machen-druck.ch/schweizer-norm-couverts-drucken-lassen,category,20322.html
- https://lexpertbusiness.com/courrier-norme-afnor-exemple/
- https://norminfo.afnor.org/norme/nf-z11-001/presentation-des-lettres/94638
- https://www.austrian-standards.at/en/shop/onorm-a-1080-2007-03-01~p1536064
- https://www.cavaliermailing.com/services/envelope-insertion-enclosing/a4-address-position-guide/
- https://crst.net/guides/envelope-sizes/window

Legal

- https://dejure.org/gesetze/GmbHG/35a.html
- https://www.ihk.de/berlin/service-und-beratung/recht-und-steuern/kaufmaennische-pflichten/pflichtangaben-geschaeftsbrief-4336766
- https://www.frankfurt-main.ihk.de/recht/uebersicht-alle-rechtsthemen/handelsrecht/angaben-auf-geschaeftsbriefen-5279818
- https://www.legalplace.fr/guides/mentions-obligatoires-facture/
- https://www.entreprises.cci-paris-idf.fr/fiches-pratiques/factures-quelles-sont-les-mentions-obligatoires
- https://www.brocardi.it/codice-civile/libro-quinto/titolo-v/capo-i/art2250.html
- https://www.cloudgestion.com/blog/software/factura-registro-mercantil/
- https://www.six-group.com/dam/download/banking-services/standardization/qr-bill/style-guide-qr-bill-en.pdf
- https://www.six-group.com/en/products-services/banking-services/payment-standardization/standards/qr-bill.html
- https://www.europeanpaymentscouncil.eu/document-library/guidance-documents/quick-response-code-guidelines-enable-data-capture-initiation
- https://forum.jtl-software.de/threads/zwischensumme-uebertrag-bei-mehrseitigen-rechnungen-inkl-video.35856/

PDF/A, PDF/UA, accessibility

- https://typst.app/docs/reference/pdf/
- https://typst.app/docs/guides/accessibility/
- https://typst.app/blog/2025/typst-0.14/
- https://typst.app/blog/2025/accessible-pdf/
- https://typst.app/docs/changelog/0.14.0/
- https://gpdf.com/blog/pdfa-3-explained-and-how-to-verify/
- https://www.invoicenavigator.eu/learn/zugferd
- https://itextpdf.com/blog/technical-notes/creating-zugferd-itext
- https://www.twobirds.com/en/insights/2025/a-guide-to-navigating-the-european-accessibility-act-for-online-retailers-service-providers-and-plat
- https://pdfix.net/european-accessibility-act-2025-are-your-pdfs-ready/
- https://www.levelaccess.com/compliance-overview/european-accessibility-act-eaa/
- https://www.deque.com/en-301-549-compliance/

Typography, fonts, tokens, design

- https://www.rwt.io/typography-tips/facts-about-figures-numeric-styles-with-opentype-features/
- https://typenetwork.com/articles/opentype-at-work-figure-styles
- https://typst-community.github.io/extra-docs/packages/resources.html
- https://github.com/typst/typst/discussions/5013
- https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/
- https://www.designtokens.org/tr/drafts/format/
- https://wise.com/us/blog/invoice-best-practices
- https://influenceflow.io/resources/professional-invoice-design-and-branding-a-complete-guide-for-2026/
- https://www.vistaprint.com/hub/correct-file-formats-rgb-and-cmyk

Confidence notes

- HIGH: product knob lists fetched from vendor docs (Stripe, Zoho, Lexware, Odoo, Invoice Ninja, sevdesk); SIX style guide (read from the PDF pages 4-12); Swiss window table (read from the inka.ch PDF, dated 2003 - dimensions of the "new" 90 x 40 window may have been updated in SN 010130:2016); all EXPERIMENT results.
- MEDIUM: DIN 5008 millimetre values (secondary sources + letter-pro constants agree); FR NF Z 11-001 address position (secondary sources); UK/US window positions (envelope vendor guides).
- LOW: OENORM A 1080 details (paywalled, reportedly withdrawn 2018); EPC QR minimum size (secondary sources citing EPC069-12); easybill PDF/A letterhead requirement (search snippet, page returned 403).
