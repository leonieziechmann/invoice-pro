# Theme internals - ground truth of the current implementation (invoice-pro 0.4.2)

Scope: every file under `src/themes/` (2,484 lines) plus the call sites that feed the slots
(`src/invoice.typ`, `src/components/{root,line-items,bank-details,payment-goal,signature}.typ`,
`src/loom-wrapper.typ`) and the external layout dependency `@preview/letter-pro:3.0.0`.
All paths are relative to `<repo>/` unless stated otherwise.
Claims marked **[E#]** were verified by compiling an experiment in
`scratchpad/proto/theme-internals/` (file names listed in the appendix).

---

## 0. TL;DR

1. A _theme_ is nothing but a **zero-argument function returning a dictionary of slot functions**
   (`invoice.typ:106,180`). `base-theme` (`src/themes/base-theme/base.typ:8-50`) is the only producer;
   `themes.blank` _is_ `base-theme`, `themes.DIN-5008(...)` returns `base-theme.with(document:, line-items:)`.
2. There are **5 live slots** (`document`, `line-items`, `bank-details`, `payment-goal`, `signature`) and
   **2 dead slots** (`header`, `footer`): the `set page(header/footer)` in `base.typ:35-40` sits inside an
   `if { }` block, so the set rule is scoped to that block and never reaches the document **[E2, E11]**.
3. The line-items renderer is a 4-layer parameter pipeline with **50 named parameters, 16 of them callbacks**,
   but **none of it is reachable from the published package**: `themes` exports exactly `blank` and
   `DIN-5008` **[E12]**, Typst cannot import package sub-paths **[E8]**, and `DIN-5008` forwards only
   2 of the 50 parameters (`color-row-odd/even`). Everything else is "replace the whole slot" (= rewrite
   ~1,700 lines).
4. The _real_ design defaults live in the thin wrapper `base-theme/line-items.typ:5-39`, **not** in the
   generic component. The generic component's own defaults produce a broken layout (overlapping rows)
   and inverted row striping **[E6a, E6c]**. There are up to 4 competing default values per token.
5. `bank-details`, `payment-goal`, `signature` have **zero style parameters**; the DIN document has 6.
   Header typography, logo, info block, page-2+ header/footer, paper size, page numbering format,
   watermark are not configurable.
6. Business/legal logic is embedded in theme renderers: legal notices (section 19 UStG clause, exemption
   grounds, markers) in `global-info.typ`, zero-tax suppression in `totals.typ`, EPC-QR generation in
   `bank-details.typ`, PDF metadata in `DIN-5008/document.typ`. A custom slot silently loses them.
7. Three crash/visual bugs found in parameter combinations that the signatures advertise
   (column reorder, hidden total column + groups, table-footer colspan / header-bg gaps).
8. The loom `ctx` already _is_ a cascade: slots are resolved late from `ctx.theme.<slot>`, and
   `#apply(theme: dict)[...]` overrides a slot for a subtree today **[E19]**.

---

## 1. SLOT MAP

### 1.0 How a theme is consumed

| Step                 | Where                                                                                                              | What happens                                                                                                                                  |
| -------------------- | ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| user passes `theme:` | `src/invoice.typ:21`                                                                                               | default `themes.DIN-5008()`; validated only as `function` (`invoice.typ:106`)                                                                 |
| evaluation           | `src/invoice.typ:180`                                                                                              | `let eval-theme = theme()` - called with **no arguments** (contrast: locale is called with `(base-language, base-region)`, `invoice.typ:181`) |
| injection            | `src/invoice.typ:290-291,323-330`                                                                                  | the resulting dict becomes `ctx.theme` via `weave(inputs: ...)`                                                                               |
| slot lookup          | `root.typ:312`, `components/line-items.typ:500`, `bank-details.typ:143`, `payment-goal.typ:55`, `signature.typ:42` | `(ctx.theme.<slot>)(ctx, view[, body])` in the motif's **draw** pass                                                                          |
| fallbacks            | `root.typ:71`                                                                                                      | missing `document` -> identity `(.., body) => body`                                                                                           |
|                      | `components/line-items.typ:131-133`                                                                                | missing `line-items` -> literal `[Line Items]`                                                                                                |
|                      | `bank-details.typ:96-100`, `payment-goal.typ:34-38`, `signature.typ:30-32`                                         | missing slot -> `panic("theme::<slot> is not provided")` (inconsistent with the two above)                                                    |

Consequences verified by experiment:

- Any `() => dictionary` works as a theme; unknown keys are silently ignored; partial dicts work **[E18]**.
- `themes.blank` must be passed **uncalled**; `themes.blank()` fails the `function` check **[E9]**.
  `themes.DIN-5008` must be passed **called**; passing it uncalled yields the misleading
  `"theme::payment-goal is not provided"` panic **[E10]** (because `theme()` then returns another
  function, not a dict). `tests/TESTING.md:228` even documents "`themes.blank` is a value, not a function".
- `ctx.theme` is ordinary ctx data, so `#apply(theme: themes.blank() + (signature: ...))[...]`
  overrides a slot for a subtree only **[E19]**.

### 1.1 `base-theme` - the slot container

`src/themes/base-theme/base.typ:8-50`

```typst
#let base-theme(
  document: (ctx, body) => body,        // (ctx, content) => content
  header: none,                         // content (may contain motifs)   -- DEAD, see below
  footer: none,                         // content (may contain motifs)   -- DEAD, see below
  line-items: render-line-items,        // (ctx, dictionary, content) => content
  bank-details: render-bank-details,    // (ctx, dictionary) => content
  payment-goal: render-payment-goal,    // (ctx, dictionary) => content
  signature: render-signature,          // (ctx, dictionary) => content
) = ( document: <wrapped>, header:, footer:, line-items:, bank-details:, payment-goal:, signature: )
```

- The returned `document` is a wrapper (`base.typ:34-42`) that is _supposed_ to install
  `set page(header: eval-content(ctx, header))` / `footer` and then call the user's `document`.
  Because each `set page` is inside `if ... { set page(...) }`, it has no effect on
  `document(ctx, body)` on line 41. **Verified: neither header nor footer render, for `blank` and
  for `DIN-5008().with(header:, footer:)` [E2, E11].**
- `header`/`footer` are also copied into the dict (`base.typ:43-44`) but nothing reads `ctx.theme.header/footer`.
- `eval-content` (`src/loom-wrapper.typ:24-34`) runs `loom.core.intertwine(ctx, it, draw: true)` so
  that `info.*`/`dynamic` motifs inside header/footer resolve against ctx. It also supports a
  function form, which neither `set page(header:)` nor letter-pro's `footer` can accept (unused path).
- `themes.blank = base-theme` (`src/themes/blank/blank.typ:3`). "Blank" is therefore **not** blank for
  line-items/bank/payment/signature - it only has an identity `document`. The docs describe it as
  applying "zero visual formatting" (`docs/docs/api-reference/theme.md:66`), which is only true for the page.

### 1.2 `ctx` - what every slot can read

Dumped at runtime **[E-ctx]** (`theme-internals/ctx-dump.json`). Origin: `invoice.typ:290-320` inputs,
`root.typ:15-90` scope defaults, injector `invoice.typ:326-328` (`ctx.global`).

Common keys (all slots):

| key                                                                                                                                                  | type / shape                                                                                                                                                                                                                                                                                                                  | origin                                                                                                                                     |
| ---------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `sys`                                                                                                                                                | loom internals                                                                                                                                                                                                                                                                                                                | loom                                                                                                                                       |
| `theme`                                                                                                                                              | dict of slots (`document, header, footer, line-items, bank-details, payment-goal, signature`)                                                                                                                                                                                                                                 | `invoice.typ:291`                                                                                                                          |
| `locale`                                                                                                                                             | `(strings: dict, format: (percent,date,time,number,currency,currency-fine: fn), normalize: (money, money-fine, infer-tax: fn), currency: (code, symbol, decimals, decimals-fine), tax: (default-vat, small-enterprise-special-scheme: (rate, category, label, grounds)), meta: (region: str), resolve-plural: fn, lang: str)` | `locale/factory.typ:66-74`; **`lang` is never provided by `build-locale`, so `root.typ:62` always defaults it to `"de"`** (see smell S-17) |
| `format`                                                                                                                                             | duplicate of `locale.format`                                                                                                                                                                                                                                                                                                  | `invoice.typ:293`                                                                                                                          |
| `sender`, `recipient`                                                                                                                                | `(name, address, city, vat-id, tax-nr, extra: array of (k,v) pairs, address-lines: array, name-inline, address-inline, city-inline, country: (name, code, show-always, parse-city, format-address, format-inline), city-name, post-code, state, ...user keys)`                                                                | `invoice.typ:208-218`, `root.typ:18-54`                                                                                                    |
| `delivery-address`                                                                                                                                   | `none` or normalized party                                                                                                                                                                                                                                                                                                    | `invoice.typ:297`                                                                                                                          |
| `invoice-date`                                                                                                                                       | `datetime`                                                                                                                                                                                                                                                                                                                    | `invoice.typ:299`                                                                                                                          |
| `subject`                                                                                                                                            | `str`/content - already `"<subject> <invoice-nr>"` joined                                                                                                                                                                                                                                                                     | `invoice.typ:245`                                                                                                                          |
| `references`                                                                                                                                         | **document slot: normalized array of `(label, value)` pairs (`root.typ:280-285`); all other slots: the raw user value, possibly a function/preset [E18]**                                                                                                                                                                     |                                                                                                                                            |
| `invoice-nr, customer-nr, order-nr, order-date, project, contract-nr, quote-nr, delivery-note-nr, preceding-invoice-nr, due-date, payment-reference` | `none`/str/content/datetime                                                                                                                                                                                                                                                                                                   | `invoice.typ:302-313`                                                                                                                      |
| `tax`                                                                                                                                                | `(rate: decimal, category, label, grounds)`                                                                                                                                                                                                                                                                                   |                                                                                                                                            |
| `tax-mode`                                                                                                                                           | `"exclusive"`/`"inclusive"`                                                                                                                                                                                                                                                                                                   |                                                                                                                                            |
| `tax-exempt-small-biz`                                                                                                                               | bool                                                                                                                                                                                                                                                                                                                          |                                                                                                                                            |
| `zugferd`                                                                                                                                            | `none`/profile string                                                                                                                                                                                                                                                                                                         |                                                                                                                                            |
| `global`                                                                                                                                             | `(total: (net, gross, due, prepaid: decimal), formated-total: (net, gross, due, prepaid: str), bank: (iban, bic, reference, text, payment-amount) or none)`                                                                                                                                                                   | injector; **one pass stale in child slots** (e.g. `global.bank.payment-amount` is `0` in child slots but `1539.64` in the document slot)   |

Extra keys per slot:

| slot                        | additional ctx keys                                                                                                                                                                                                                                                 |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `document`                  | `items` (raw items), `item-data` (raw: `items, taxes (dict keyed "0.19-S"), net-total, gross-total, unmodified-net-total, due-total, prepaid-total, prepayments, tax-mode, discounts, surcharges`), `payment-goal` (`days,date,total`), `bank` (`root.typ:282-296`) |
| `line-items`                | `input-gross: bool`, `show-column: dict of auto/bool`, `show-total: bool`, `show-information: bool` (`components/line-items.typ:92-108`)                                                                                                                            |
| `bank-details`              | `text`, `reference` (`components/bank-details.typ:87-94`)                                                                                                                                                                                                           |
| `payment-goal`, `signature` | none                                                                                                                                                                                                                                                                |

Note the asymmetry: only the `document` slot sees the fresh, root-augmented ctx (`root.typ:282-312`);
every other slot sees its own scope ctx (`loom .../core/engine.typ:89,123`).

### 1.3 Slot: `document`

- **Contract:** `(ctx, body) => content`. `body` is the fully drawn invoice body. Called from `root.typ:312`.
- **Default (`blank`)**: identity (`base.typ:11`).
- **DIN-5008 implementation**: factory `letter-document(form:, font:, hole-mark:, folding-marks:, margin:, footer:)`
  -> `(ctx, body) => content` (`src/themes/DIN-5008/document.typ:25-34`).
- **ctx fields read** (`document.typ`): `subject` (36), `references` (37), `sender.extra` (39),
  `recipient.extra` (41), `sender.name/address/city/extra` (60-63), `zugferd` (67), `invoice-date` (75,175-178),
  `recipient.name/address/city` (128-130), `sender.name-inline/address-inline/city-inline` (134-135),
  `sender.city-name` (168-169), `locale.format.date` (176).
- **Side effects inside the theme**: `set document(title, author, date, description, keywords)` (66-78),
  `set text(font:)` (80), `set text(hyphenate: true)` + `set par(justify: true)` for the body (183-184),
  and via letter-pro `set page(paper: "a4", margin, background: marks, footer-descent: 0%, footer: ...)`
  (`letter-pro/3.0.0/src/lib.typ:132-195`).
- **Returns:** `letter-generic(...)[ title-row + body ]`.
- Structure produced: header band (subject left, sender block right) -> address zone (return address line,
  optional annotations from `recipient.extra`, recipient) -> reference-signs grid -> title row
  (`heading(subject)` + "City, **date**") -> body.

### 1.4 Slot: `line-items`

- **Contract:** `(ctx, view, body) => content` (`components/line-items.typ:500`).
  `body` is the drawn residue of the `line-items[...]` children (items draw nothing, so it is a sequence
  of spaces - verified `sequence([ ], [ ], ...)`); the default renderer appends it after the notices
  (`components/line-items/line-items.typ:168`).
- **view shape** (built in `components/line-items.typ:460-472`; types verified **[E-ctx]**):

```
view = (
  items:    array<item>,            // only kind == "item", flat
  entries:  array<item | group-header | group-footer>,   // render order
  discounts:  array<global-modifier>,
  surcharges: array<global-modifier>,
  prepayments: array<prepayment>,
  taxes:    array<tax>,
  total:            (net: str, gross: str, due: str, prepaid: str),   // formatted
  unmodified-total: (net: str, gross: str),                            // formatted
  layout-information: (
    show-pos, show-descriptions, show-modifier, show-dates, show-quantity, show-units,
    show-unit-price, show-total-price, show-tax-rates,          // bool, resolved from show-column
    show-total, show-global-information,                         // bool
    has-dates, multiple-dates, multiple-quantities, multiple-units,
    multiple-tax-rates, has-global-modifier, has-prepayments,   // bool facts
  ),
  tax-mode: "exclusive" | "inclusive",
  tax-exempt-small-biz: bool,
)

item = (                                   // components/line-items.typ:150-214, 217-222
  kind: "item", pos: str ("1.1"), level: int,
  name: content, description: content, has-description: bool,
  date: str (formatted) , has-date: bool,
  quantity: str, base-quantity: str, unit: content,
  price: str, total: str, unmodified-total: str,                // formatted currency
  tax: (rate: str "19%", category: str "S"),
  discounts: array<item-modifier>, has-discounts: bool,
  surcharge: array<item-modifier>, has-surcharge: bool,         // NB singular key
  item-id: none | dict, has-item-id: bool,
  reference: none | str, has-reference: bool,
)
item-modifier   = (name: content, label: content|none, description: content, has-description: bool,
                   display: str, absolute: str, is-percent: bool)
global-modifier = (name: content, label: content|none, description: content,
                   display: content, absolute: str, is-percent: bool,
                   split: array<(tax: (rate: content, category: content), amount: content)>)   // () for relative
group-header = (kind: "group-header", pos, level, name: content, description: content|none, has-description)
group-footer = (kind: "group-footer", pos, level, name: content, subtotal: str, raw-subtotal: decimal)
tax        = (rate: content, raw-rate: decimal, raw-amount: decimal, category: content,
              amount: content, grounds: none|str|content, marker: none|str)
prepayment = (name, label, date, reference, description, method: content|none, amount: content, value: decimal)
```

Observations that matter for a frozen contract:

- The view is **pre-formatted**; raw numbers exist only for `taxes[].raw-*`, `prepayments[].value`,
  `group-footer.raw-subtotal`. A theme cannot e.g. colour negative totals or re-format amounts.
  (Raw totals are in `ctx.global.total`.)
- Types are inconsistent: same concept is `str` in one place and `content` in another
  (`items[].tax.rate: str` vs `taxes[].rate: content`; item-modifier `display: str` vs
  global-modifier `display: content`).
- Naming is inconsistent: `discounts` (plural) vs `surcharge` (singular) on items, but
  `surcharges` at top level; `has-discounts` vs `has-surcharge`; `formated-*` typo in ctx.
- Delivered but **never rendered by the default theme**: `level` (no indentation of nested groups),
  `item-id`, `reference`, modifier `description`, `split`, prepayment `reference/description/method`
  (grep over `src/themes` finds no reader).
- **Default implementation:** see section 2.
- **ctx fields read:** `locale.strings.line-items.{position, description, quantity, unit-price, vat, total, net, gross, subtotal, discount, surcharge}`
  (`table.typ:55-56,89-90,203,308-316,664,863`), `locale.strings.summary.{sum,total,excluding,including,vat-tax,prepayment,amount-due}`
  (`totals.typ:5-176`), `tax-mode` (`totals.typ:7,166`), `locale.meta.region`, `locale.strings.meta.lang`,
  `locale.strings.{summary,legal,global-info}`, `locale.tax.small-enterprise-special-scheme.grounds` (`global-info.typ:14-17,81-85`).
- **Returns:** content = table + `v(-1em)` + totals + notices + body.

### 1.5 Slot: `bank-details`

- **Contract:** `(ctx, view) => content` (`components/bank-details.typ:143`).
- **view** (`components/bank-details.typ:109-130`):
  `(sender: (name: str, bank: str, iban: str, bic: str), qr-code: (size: length = 5em, display: bool = true),
reference: none|str, text: none|str, show-reference: bool, payment-amount: decimal)`.
  Note that `qr-code.size/display` and `show-reference` are _visual_ options that live on the **component**,
  not on the theme.
- **ctx read:** `locale.strings.bank-details.{account-holder, bank, iban, bic, reference}`, `locale.currency.code`
  (`base-theme/bank-details.typ:5-7`).
- **Does:** builds the EPC QR code itself (`bank-details.typ:13-29`: only when currency is EUR; amount only if
  `>= 0.1`; `text` wins over `reference`), formats IBAN via `ibanator`. **Returns** a two-column grid (text | QR).
- **Parameters:** none.

### 1.6 Slot: `payment-goal`

- **Contract:** `(ctx, view) => content` (`components/payment-goal.typ:55`).
- **view:** `(days: none|int, date: none|datetime|str|content, total: decimal)` (`payment-goal.typ:47-51`) - raw decimal here, unlike line-items.
- **ctx read:** `locale.strings.payment.{text, deadline-date, deadline-days, deadline-soon}`, `locale.format.{date, currency}`.
- **Returns:** the sentence produced by the locale function `payment.text(sum, deadline)`; bold emphasis of the
  amount is baked into the _locale string_ (`src/locale/lang/en.typ:130`: `*#sum*`). **Parameters:** none.

### 1.7 Slot: `signature`

- **Contract:** `(ctx, view) => content` (`components/signature.typ:42`).
- **view:** `(name: str|content|none, signature: none|content)`.
- **ctx read:** `locale.strings.signature.closing`.
- **Returns:** unbreakable block: `v(1em)`, closing, `v(1em)`, signature content, name. **Parameters:** none.

### 1.8 Slots `header` / `footer`

Declared as `content` that may contain motifs (`base.typ:12-19`), but dead (section 1.1).
The only working footer is DIN-5008's own `footer:` parameter, which is forwarded to letter-pro
(`din-5008.typ:30`, `document.typ:157-159`) and therefore renders **only on page 1**
(`letter-pro lib.typ:190-192`) **[E14]**.

---

## 2. INTERNAL STRUCTURE OF LINE-ITEMS RENDERING

### 2.1 Layers

```
themes.DIN-5008(color-row-odd, color-row-even, ...)          src/themes/DIN-5008/din-5008.typ:6-37
  └─ base-theme/line-items.typ  render-line-items(ctx,data,body, color-row-odd, color-row-even)   :5-39
       = the "design defaults" preset: hard-codes 20 further tokens and forwards
       └─ components/line-items/line-items.typ  render-line-items(ctx,data,body, ~50 named params)  :6-169
            ├─ columns.typ   get-column-metadata(data, column-order)          (result unused here, :69)
            ├─ table.typ     render-table(ctx, data, 31 named params)          :135-927
            │     └─ columns.typ get-column-metadata (again, :277)
            ├─ v(-1em)                                                         :111
            ├─ totals.typ    render-totals(ctx, data, 22 named params)   if layout.show-total   :113-159
            ├─ global-info.typ render-global-info(ctx, data, color-desc, size-small)             :161-166
            └─ body                                                            :168
```

`base-theme/line-items.typ` additionally contains four unexported experimental presets
(`render-line-items-elegant` :42, `-vibrant` :242, `-luxury` :279, `-informational` :297).
They compile **[E1]** but are referenced nowhere (not in tests, docs, or exports) and show rough edges
(elegant/luxury headers collide - "ITEMDESCRIPTION", "QtyUnit Price" - because a directional inset
dict _replaces_ the default and drops the x-inset; informational hard-codes an English "Final Note" text, :315).
They are valuable as evidence of what the author wants themes to be able to do:
letter-spaced uppercase labels, pill-shaped coloured header cells, accent colour reuse
(`accent.lighten(95%)`), double-rule totals, modifiers in a table aligned with the item table,
per-item bottom rules, custom table footer.

### 2.2 Columns (`columns.typ:1-53`)

- Fixed vocabulary: `pos` (auto width, if `layout.show-pos`), `description` (always, `1fr`), then the
  keys of `column-order` filtered by `available-cols` = `quantity`, `unit-price`, `tax-rate`, `total-price`
  (`columns.typ:13-18`), each `auto` width.
- Unknown keys in `column-order` are silently dropped **[E6a]**. Units and dates are not columns; they are
  rendered inside the quantity cell (`table.typ:459-476`) and the title cell (`table.typ:19-27`).
- Returns `(cols, active-keys, total-count, desc-idx, total-idx, percent-idx, left-count)`.
  `percent-idx` = the column left of `total-price` (used for the "(- 10%)" modifier cell).
- The physical table has `total-count + 2` columns: a left and a right **spacer column** carry the
  item-inset and the item-stroke (`table.typ:918`).

### 2.3 Table (`table.typ:135-927`)

- `styles` dict handed to callbacks (`table.typ:225-248`): `color-subtitle, color-desc, color-discount,
color-surcharge, color-row-odd, color-row-even, size-subtitle, size-small, weight-bold, header-bg,
header-color, header-repeat, stroke-header-top/-bottom, stroke-table-bottom (auto resolved), item-inset,
item-stroke, cell-inset, header-cell-inset (normalized to left/right/top/bottom)`. Not included:
  `stroke-thin`, `stroke-regular`, alignments, `tax-suffix-style`.
- Header (`table.typ:305-348`): labels from locale, wrapped in `*strong*`; the unit-price and total
  labels get a tax suffix "(net)"/"(gross)"; each label goes through `render-header(ctx, content, styles)`
  (the column key is **not** passed); `table.header(repeat: header-repeat)` with rule / zero-height
  spacer cells / cells / spacer / rule.
- Per item (`build-item-rows`, `table.typ:362-700`) - an "item card" of up to 6 row kinds:
  top cap (item-inset.top, item-stroke top/left/right) -> main row (pos, title, one cell per active key)
  -> description row (colspan from `description-colspan`) -> one row per item discount / surcharge
  (label | percent | absolute) -> item subtotal row (only if modifiers) -> bottom cap -> zero-height separator.
  All cells of an item share `fill: bg`.
- Groups: `build-group-header-rows` (:702-796) and `build-group-footer-rows` (:798-898); `fill: none`;
  ~70% of the code is a copy of `build-item-rows` scaffolding (line-cell, spacers, caps, align resolution).
- Final assembly (`table.typ:917-926`): `table(columns: (auto,)+cols+(auto,), stroke: none, header, ..rows, empty, ..table-footer, hline(stroke-table-bottom))`.

### 2.4 Totals (`totals.typ:300-464`)

Two-stage design:

1. **Stylers** produce a `(label, value)` content pair per line: `render-subtotal`, `render-total-net`,
   `render-total-gross`, `render-discount`, `render-surcharge`, `render-tax`, `render-prepayment`,
   `render-amount-due` - all `(ctx, value-or-dict, styles) => (content, content)` (`totals.typ:5-179`).
2. `totals-cell-wrapper(ctx, content, styles)` wraps each half into a `grid.cell`/`table.cell`
   (`totals.typ:392-396`), giving `elements = (subtotal, modifiers[], net-total?, taxes[], grand-total,
prepayments[], amount-due?)` (`totals.typ:405-461`).
3. **Body builder** `render-totals-body(ctx, data, styles, elements) => content` decides order, rules
   (thin/thick), spacing and the container (`totals.typ:191-296`): right-aligned `box(width: totals-width)`
   with a 2-column `grid`.

- `styles` dict here (`totals.typ:329-342`) is a **different** dict from the table one:
  `color-discount, color-surcharge, color-vat-label, size-small, size-total, weight-bold, stroke-thin,
stroke-thick, totals-width, totals-row-gutter, totals-col-gutter, totals-align`.
- Logic inside: 0 %-taxes are filtered out (`totals.typ:430-447`), `net-total` only in exclusive mode,
  `amount-due` only with prepayments.

### 2.5 Global info / legal notices (`global-info.typ:3-166`)

~150 lines of **business logic** (which sentences are required) and ~10 lines of rendering
(`pad(top: 1em, text(size: size-small, fill: color-desc, infos.join(linebreak)))`, :156-165).
Produces: uniform-tax statement, uniform unit, uniform quantity, uniform date, small-business clause
(with locale/region-dependent wording), tax-exemption grounds with `*` markers. Only two style params; no callback.

### 2.6 What is parameterizable via `.with(...)` and what is not

**Parameterizable on the generic `render-line-items` (`components/line-items/line-items.typ:6-67`)**

| group            | parameters                                                                                                                                                                                                                                                                                               |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| colours          | `color-subtitle, color-desc, color-row-odd, color-row-even, color-discount, color-surcharge, color-vat-label, header-bg, header-color`                                                                                                                                                                   |
| sizes/weight     | `size-subtitle, size-small, size-total, weight-bold`                                                                                                                                                                                                                                                     |
| strokes          | `stroke-thin, stroke-regular, stroke-thick, stroke-header-top, stroke-header-bottom, stroke-table-bottom, item-stroke`                                                                                                                                                                                   |
| spacing          | `cell-inset, item-inset, header-cell-inset, totals-width, totals-row-gutter, totals-col-gutter, totals-align`, (`item-internal-inset` - **dead**, never forwarded, :29)                                                                                                                                  |
| structure        | `column-order, description-colspan, header-repeat, tax-suffix-style ("newline"/"inline"/"accent"/none, or dict keyed `unit-price`/`total`), align-header, align-body` (auto / array by visible index / dict by key / function / single value; `table.typ:177-193`)                                       |
| table callbacks  | `render-title(ctx,item,layout,styles)`, `render-description(ctx,item,layout,styles)`, `render-modifier(ctx,mod,styles,is-discount:) -> (label,percent,absolute)`, `render-header(ctx,content,styles)`, `render-table-footer(ctx,total-cols,styles) -> array`, `render-tax-suffix(ctx,is-net,styles,key)` |
| totals callbacks | the 8 stylers, `totals-cell-wrapper`, `render-totals-body`                                                                                                                                                                                                                                               |

**Not parameterizable (hard-coded)**

- the column vocabulary and widths (`columns.typ:9,11,13-18,22`); no custom column, no per-column cell renderer
  (`table.typ:459-483` is an if-chain), no way to show `item-id`, `reference`, date or unit as own column;
- header label text per column (locale only; `render-header` does not receive the key);
- pos cell, item-subtotal row (`table.typ:631-687`), group header/footer rows (`:702-898`), group fill, nesting indentation;
- the glue spacings `v(-1em)` (`line-items.typ:111`), `v(.5em)` (`totals.typ:282`), `pad(top: 1em)` (`global-info.typ:158`);
- order of table / totals / notices / body; notices rendering; placement of totals relative to the table;
- tax amount colour (`text(fill: black)`, `totals.typ:177`), prepayment colour (= `color-discount`, `totals.typ:140,144`);
- bold mechanism of header labels (`*strong*`, `table.typ:308-316`) - `weight-bold` does not affect them.

**Reachability:** all of the above is reachable _only_ through the internal path
`/src/themes/components/line-items/line-items.typ` (as the repo's own tests do: `tests/issues/issue-41/test.typ:11-13`,
`tests/issues/issue-39/test.typ:12-14`). Users of `@preview/invoice-pro` cannot import it **[E8, E12]**.
The only public handle is the wrapper obtained by the trick `themes.blank().line-items`
(accepts only `color-row-odd/even`) **[E16]**; any other parameter errors with
`unexpected argument` **[E3, E3b]**.

### 2.7 `color-row-odd` / `color-row-even` end to end

1. `themes.DIN-5008(color-row-odd: none, color-row-even: rgb("e2e8f0"))` - `din-5008.typ:13-14`
2. -> `render-line-items.with(color-row-odd:, color-row-even:)` (base-theme wrapper) - `din-5008.typ:32-35`
3. wrapper signature `base-theme/line-items.typ:9-10`, forwards at `:18-19`
4. generic `render-line-items` (`components/line-items/line-items.typ:13-14`), forwards to `render-table` at `:76-77`
5. `render-table` params `table.typ:147-148` -> `styles.color-row-odd/even` `:230-231`
6. `build-item-rows`: `bg = if resolved-odd { styles.color-row-odd } else { styles.color-row-even }` `:376-380`
7. `line-cell = table.cell.with(fill: bg, ...)` `:388-394` -> every cell of the item card incl. caps and spacer columns
8. parity: `display-index` counts only `kind == "item"` entries (`table.typ:902-914`), so group rows do not
   shift the alternation; group header/footer rows use `fill: none` (`:711,:807`).

Cost of exposing one token: **4 signatures + 3 forwarding sites** (commit `890fecb` "expose line item row colors on DIN-5008"
did exactly this). Also note the **default flips between layers**: generic/table default is
`odd: e2e8f0, even: none`; wrapper/DIN default is `odd: none, even: e2e8f0` **[E1 luxury/vibrant vs default, E6c]**.

---

## 3. HARD-CODED VISUAL CONSTANTS INVENTORY

Legend: **P** = already a parameter somewhere in the pipeline (but mostly not publicly reachable), **H** = hard literal.

### 3.1 Page / letter (DIN-5008) - `src/themes/DIN-5008/document.typ`, `din-5008.typ`

| path:line                              | value                                                                                            | controls                                                                            | P/H           |
| -------------------------------------- | ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- | ------------- |
| din-5008.typ:7, document.typ:26        | `form: "A"`                                                                                      | DIN 5008 form A/B (validated `din-5008.typ:19`)                                     | P (public)    |
| din-5008.typ:8, document.typ:27        | `font: "Liberation Sans"`                                                                        | document font (duplicated default)                                                  | P (public)    |
| din-5008.typ:10-11, document.typ:29-30 | `hole-mark: true`, `folding-marks: true`                                                         | margin marks                                                                        | P (public)    |
| din-5008.typ:13-14                     | `none` / `rgb("e2e8f0")`                                                                         | row striping                                                                        | P (public)    |
| din-5008.typ:16, document.typ:32       | `margin: (:)`                                                                                    | margin override dict (left/right/top/bottom only)                                   | P (public)    |
| document.typ:53-56                     | `25mm / 20mm / 20mm / 20mm`                                                                      | left/right/top/bottom margin (duplicates letter-pro defaults)                       | H default     |
| document.typ:66-70                     | `"Invoice"`, `"ZUGFeRD"`, `"Factur-X"`                                                           | PDF keywords (English, not localized, not a visual but set by the theme)            | H             |
| document.typ:72-78                     | `set document(...)`                                                                              | PDF title/author/date/description                                                   | H (in theme!) |
| document.typ:80                        | `set text(font: font)`                                                                           | global font; overrides a user's outer `set text(font:)` **[E13]**                   | -             |
| document.typ:82-86                     | pad left/right/top = margins, `bottom: 5mm`                                                      | letterhead band padding                                                             | H             |
| document.typ:88                        | `10pt`                                                                                           | letterhead text size (absolute; ignores user `set text(size:)`)                     | H             |
| document.typ:91                        | `columns: (1fr, 1fr)`                                                                            | letterhead: subject left / sender right                                             | H             |
| document.typ:92                        | plain `subject`                                                                                  | what is shown top-left (no logo slot)                                               | H             |
| document.typ:93                        | `width: 100%, height: 5.5cm`                                                                     | sender block box (overflows the 27 mm header into the info-block area)              | H             |
| document.typ:94                        | `align(right)`                                                                                   | sender block alignment                                                              | H             |
| document.typ:95                        | `strong(name)`                                                                                   | sender name weight                                                                  | H             |
| document.typ:99                        | `parbreak()`                                                                                     | gap between address and extras                                                      | H             |
| document.typ:103                       | `breakable: false`                                                                               | extras block                                                                        | H             |
| document.typ:105-108                   | `columns: 2`, `align: (left+horizon, right+horizon)`, `column-gutter: .4em`, `row-gutter: .75em` | sender extras grid                                                                  | H             |
| document.typ:112                       | `[key:]`                                                                                         | extras label format                                                                 | H             |
| document.typ:45-46                     | `[k: v]` joined `", "`                                                                           | recipient annotations format                                                        | H             |
| document.typ:135                       | `[address-inline, city-inline]`                                                                  | return-address line format                                                          | H             |
| document.typ:143                       | `align(bottom)`, `pad(bottom: .65em)`                                                            | return address placement in duobox                                                  | H             |
| document.typ:165                       | `columns: (1fr, auto)`                                                                           | title row                                                                           | H             |
| document.typ:166                       | `heading(subject)`                                                                               | title = Typst default level-1 heading (bold 1.4em); restyle only via user show rule | H             |
| document.typ:173-178                   | `[city, ]` + `strong(date)`                                                                      | place/date format and weight                                                        | H             |
| document.typ:183-184                   | `hyphenate: true`, `justify: true`                                                               | body text                                                                           | H             |
| root.typ:158                           | `set text(lang:, region:)`                                                                       | language (always "de", see S-17)                                                    | -             |

### 3.2 DIN geometry inherited from `@preview/letter-pro:3.0.0` (`%LOCALAPPDATA%/typst/packages/preview/letter-pro/3.0.0/src/lib.typ`)

| line              | value                                                                                                                                                                                                                               | controls                                                                                                |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 19-29             | A: fold marks `87mm`, `87+105mm`, header `27mm`; B: `105mm`, `105+105mm`, header `45mm`                                                                                                                                             | form geometry                                                                                           |
| 133-134           | `paper: "a4"`, `flipped: false`                                                                                                                                                                                                     | paper (forces A4: user `set page("a5")` is ignored **[E5]**)                                            |
| 138-160           | marks at `dx: 5mm`; fold `length: 2.5mm`; hole mark `dy: 148.5mm`, `length: 4mm`; `stroke: 0.25pt + black`                                                                                                                          | marks (set as page `background`, so a user background/watermark is overwritten **[E13]**)               |
| 162-194           | `footer-descent: 0%`; `pad(top: 12pt, bottom: 12pt)`; grid rows `(0.65em, 1fr)`, `row-gutter: 12pt`; page number right-aligned; "Seite x von y"/"Page x of y" chosen by `text.lang`; **footer content only `if current-page == 1`** | footer + page numbering (param `page-numbering` exists in letter-pro but is not exposed by invoice-pro) |
| 198-221           | address zone: `pad(left: 20mm, right: 10mm)`, grid `columns: (85mm, 75mm)`, `rows: 45mm`, `column-gutter: 20mm`; info box `pad(top: 5mm)` (info box unused by invoice-pro)                                                          | window position                                                                                         |
| 223               | `v(12pt)`                                                                                                                                                                                                                           | gap below address zone                                                                                  |
| 226-244           | reference grid `columns: (45.77mm x3, 25mm)`, `rows: 24pt`, `gutter: 12pt`; label `8pt`, value `10pt`                                                                                                                               | reference signs ("Bezugszeichenzeile")                                                                  |
| 281-298           | sender-box `85mm x 5mm`, text `7pt`, `pad(left: 5mm)`, `underline(offset: 2pt)`                                                                                                                                                     | return address line                                                                                     |
| 303-308           | annotations `7pt`, `pad(left: 5mm, bottom: 2mm)`                                                                                                                                                                                    | annotation zone                                                                                         |
| 313-318           | recipient `10pt`, `pad(left: 5mm)`                                                                                                                                                                                                  | recipient                                                                                               |
| 337-345 / 387-407 | duobox rows `(17.7mm, 27.3mm)`; tribox rows `(5mm, 12.7mm, 27.3mm)`                                                                                                                                                                 | address field partition                                                                                 |

### 3.3 Line-item design defaults - `src/themes/base-theme/line-items.typ:5-39` (the values users actually see)

| line | token             | value                                           | controls                                         |
| ---- | ----------------- | ----------------------------------------------- | ------------------------------------------------ |
| 9    | color-row-odd     | `none`                                          | fill of 1st,3rd,... item                         |
| 10   | color-row-even    | `rgb("e2e8f0")` (slate-200)                     | fill of 2nd,4th,... item                         |
| 16   | color-subtitle    | `luma(80)`                                      | only the "(net)/(gross)" header suffix           |
| 17   | color-desc        | `luma(100)`                                     | item description, group description, notices     |
| 20   | color-discount    | `rgb("b22222")`                                 | discounts (item + totals) **and prepayments**    |
| 21   | color-surcharge   | `rgb("333333")`                                 | surcharges                                       |
| 22   | color-vat-label   | `rgb("475569")` (slate-600)                     | tax line labels in totals                        |
| 23   | size-subtitle     | `0.85em`                                        | item/group "Subtotal" label                      |
| 24   | size-small        | `0.85em`                                        | descriptions, dates, modifier labels, notices    |
| 25   | size-total        | `1.2em`                                         | grand total + amount due                         |
| 26   | weight-bold       | `"bold"`                                        | item name, group name, subtotals, totals         |
| 27   | stroke-thin       | `0.5pt`                                         | header bottom rule, thin totals rules            |
| 28   | stroke-regular    | `1pt`                                           | header top rule, table bottom rule               |
| 29   | stroke-thick      | `2pt`                                           | thick totals rules                               |
| 30   | cell-inset        | `.4em`                                          | every body cell                                  |
| 31   | item-inset        | `.3em`                                          | padding of the item card (caps + spacer columns) |
| 32   | header-cell-inset | `(x: .4em, y: .6em)`                            | header cells                                     |
| 33   | totals-width      | `66%`                                           | width of totals box                              |
| 34   | totals-row-gutter | `0.6em`                                         | totals row spacing                               |
| 35   | tax-suffix-style  | `"newline"`                                     | "(net)" placed under the header label            |
| 36   | align-header      | `(center, left, right, center, center, center)` | by _visible_ column index                        |
| 37   | align-body        | `(center, left, right, right, right, right)`    | by _visible_ column index                        |

Strokes are bare lengths, so their paint is inherited: a user `set table.hline(stroke: blue)` recolours the
item-table rules but not the totals rules (which are `grid.hline`) **[E13]**.

### 3.4 Competing defaults of the same tokens in lower layers

| token                                                  | table.typ                               | totals.typ                 | generic line-items.typ            | wrapper (3.3)        |
| ------------------------------------------------------ | --------------------------------------- | -------------------------- | --------------------------------- | -------------------- |
| color-row-odd / even                                   | `e2e8f0` / `none` (:147-148)            | -                          | `e2e8f0` / `none` (:13-14)        | `none` / `e2e8f0`    |
| cell-inset                                             | `(x: 0.4em)` (:154)                     | -                          | `(x: 0.4em)` (:27)                | `.4em`               |
| item-inset                                             | `(y: 0.25em)` (:152)                    | -                          | `(y: .5em, x: 1em)` (:28)         | `.3em`               |
| header-cell-inset                                      | `(top: .5em, bottom: .5em)` (:162)      | -                          | same (:31)                        | `(x: .4em, y: .6em)` |
| description-colspan                                    | `auto` (= 1) (:165)                     | -                          | `("quantity","unit-price")` (:40) | (inherits generic)   |
| align-header/body                                      | `auto` (:167-168)                       | -                          | `auto` (:54-55)                   | arrays               |
| totals-col-gutter / totals-align                       | -                                       | `1em` / `right` (:326-327) | `1em` / `right` (:34-35)          | (inherits)           |
| header-bg / header-color / header-repeat / item-stroke | `none`/`black`/`true`/`none` (:153-158) | -                          | same (:30,43-45)                  | (inherits)           |
| all colours/sizes/strokes                              | repeated identically (:139-150)         | repeated (:316-323)        | repeated (:11-25)                 | repeated             |

Using the generic component with its own defaults yields overlapping rows (no vertical cell inset) **[E6a]**.

### 3.5 Hard literals inside the table - `src/themes/components/line-items/table.typ`

| line                    | value                                                                                     | controls                                |
| ----------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------- |
| 14                      | `spacing: 0.4em`                                                                          | gap between item name and date          |
| 22-24                   | `size-small`, `style: "italic"`                                                           | item date under the name                |
| 37                      | `par(leading: 0.35em)`                                                                    | description leading                     |
| 51                      | `"−"` / `"+"`                                                                             | modifier signs                          |
| 63-68                   | `↳`                                                                                       | item-modifier label prefix glyph        |
| 77                      | `(sign display)`                                                                          | percent format in parentheses           |
| 96-100                  | `block(spacing: 0.2em)`, `size: 0.8em`, `weight: "regular"`, `align(center)`, `[(label)]` | "newline" tax suffix                    |
| 104                     | `0.8em`, regular                                                                          | "inline" tax suffix                     |
| 106                     | `0.7em`, bold, `fill.lighten(20%)`, `upper`                                               | "accent" tax suffix                     |
| 196-198                 | pos `center`, description `left`, rest `right`                                            | default alignment                       |
| 250                     | `set par(justify: false)`                                                                 | table text                              |
| 308-316                 | `*...*`                                                                                   | header labels bold via strong           |
| 314,316                 | suffix on `unit-price` and `total` only                                                   | which headers get "(net)"               |
| 322                     | `inset: 0pt`                                                                              | spacer cells                            |
| 339-348                 | rule / cells / rule sandwich, `repeat`                                                    | header structure                        |
| 388-394                 | `stroke: none`, `align: auto`                                                             | body cell base                          |
| 437                     | `[#index]` regular weight                                                                 | position cell                           |
| 470                     | `[qty unit]`                                                                              | quantity + unit in one cell             |
| 478                     | `[rate category]` e.g. "19% S"                                                            | tax cell format                         |
| 516,572,580,587,595,603 | `cell-inset + (top: 0pt)`                                                                 | description / modifier rows tighten top |
| 660-664,672             | bold + `size-subtitle` label, bold value                                                  | item subtotal row                       |
| 731                     | `item-inset.top + 0.4em`                                                                  | extra space above a group header        |
| 744                     | bold                                                                                      | group position                          |
| 765                     | `spacing: 0.35em`                                                                         | group name/description gap              |
| 767-769                 | bold, `size: 1.05em`                                                                      | group name                              |
| 774-775                 | `size-small`, `color-desc`                                                                | group description                       |
| 711, 807                | `fill: none`                                                                              | group rows never striped                |
| 861-863, 871            | bold `size-subtitle` `[Subtotal <group>]`, bold value                                     | group footer                            |
| 890                     | `item-inset.bottom + 0.2em`                                                               | space below a group footer              |
| 918-920                 | `(auto,) + cols + (auto,)`, `stroke: none`, `align: auto`                                 | table                                   |
| columns.typ:9,11,22     | `auto`, `1fr`, `auto`                                                                     | column widths                           |

### 3.6 Hard literals in totals - `src/themes/components/line-items/totals.typ`

| line               | value                                                                                                                                  | controls                                           |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| 8,10               | `[Sum (net):]` regular                                                                                                                 | subtotal label format                              |
| 17-22              | bold label `[Total net:]` + bold value                                                                                                 | net total                                          |
| 27-36              | bold + `size-total`                                                                                                                    | grand total                                        |
| 58-66, 90-98       | label `size-small` + colour; value colour; `[(− x%) #h(0.5em) − abs]`                                                                  | global discount / surcharge                        |
| 139-146            | `color-discount`, `size-small`, `[− amount]`, `[ (date)]`                                                                              | prepayment (no own colour token)                   |
| 152-161            | bold + `size-total`                                                                                                                    | amount due                                         |
| 172                | `super[marker]`                                                                                                                        | exemption marker                                   |
| 174-177            | label `color-vat-label` `[excl. Tax 19% (S):]`; value **`fill: black`**                                                                | tax lines                                          |
| 197-198            | `inset: 0pt`                                                                                                                           | null rows / spacers                                |
| 209-276            | thick after modifiers, thin before taxes (exclusive), thick before/after grand total, thin before prepayments, thick around amount due | rule rhythm                                        |
| 282                | `v(.5em)`                                                                                                                              | gap above totals (only net mode or with modifiers) |
| 285-291            | `align(totals-align)`, `box(width: totals-width)`, `columns: (1fr, auto)`, `align: (left, right)`                                      | container                                          |
| line-items.typ:111 | `v(-1em)`                                                                                                                              | pulls totals up against the table's bottom rule    |

### 3.7 Notices, bank details, signature

| path:line                             | value                                                                                | controls                                                |
| ------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------- |
| global-info.typ:7-8                   | `luma(100)`, `0.85em`                                                                | notice colour/size (params)                             |
| global-info.typ:108,147               | `super[marker] + [ ]`                                                                | marker                                                  |
| global-info.typ:158-162               | `pad(top: 1em)`, join by line break                                                  | notices block                                           |
| base-theme/bank-details.typ:19        | `>= 0.1`                                                                             | QR amount threshold (logic)                             |
| :22-23                                | `width/height: view.qr-code.size` (default `5em`, `components/bank-details.typ:118`) | QR size (component param)                               |
| :32                                   | `width: 100% - qr size`                                                              | block width                                             |
| :34-37                                | `columns: (auto, 1fr)`, `align: top`, `gutter: 1em`, `stroke: none`                  | text / QR grid (QR always right of text)                |
| :39                                   | `par(leading: 0.4em)`                                                                | line spacing                                            |
| :40                                   | `number-type: "lining"`                                                              | figures                                                 |
| :41-49                                | `[Label: value]`, IBAN and reference bold                                            | row format                                              |
| :50                                   | `h(6.5cm)`                                                                           | min-width hack for the text column                      |
| :53                                   | `block(width: size)`                                                                 | QR container                                            |
| base-theme/signature.typ:5-8          | `breakable: false`, `v(1em)`, `v(1em)`                                               | signature block                                         |
| locale/lang/en.typ:130 (and siblings) | `*#sum*`                                                                             | bold amount in payment sentence (styling inside locale) |

### 3.8 Preset-only literals (unexported) - `src/themes/base-theme/line-items.typ`

elegant: label `0.75em`, `tracking: 0.2em`, bold, upper (:44-45); `2pt + black` / `0.5pt + black` rules (:53-56);
`header-cell-inset: (y: .8em)`, `cell-inset: (y: .4em)`, `item-stroke: (bottom: .5pt + gray)`, `item-inset: (y: .4em, x: .2em)`,
`totals-width: 50%` (:57-61); double rule via `spacer(2pt)` (:200-201); `v(-1em)` (:225).
vibrant: accent `#ec4899` (:243), `accent.lighten(95%)` (:249), `2pt + accent` (:252), pill `radius: 1em`, `outset: (x: -.2em)`,
`pad(x: 2em, y: .75em)`, white bold `0.8em` (:260-272).
luxury: gold `#b8860b` (:280), `red.darken(20%)`, `blue.darken(20%)`, `2pt + black`, `1pt + gold`, inset `.5em` (:286-292).
informational: `#2563eb` (:304), footer `1pt + black`, inset `1.5em/1em`, `0.8em`, `luma(100)`, English text (:305-319).

---

## 4. WHAT CAN A USER CUSTOMIZE TODAY?

### 4.1 Works today (published package)

| goal                                                         | how                                                                                                        | evidence                                    |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| form A/B, font, fold/hole marks, row stripe colours, margins | `themes.DIN-5008(form:, font:, hole-mark:, folding-marks:, color-row-odd:, color-row-even:, margin:)`      | `din-5008.typ:6-18`, docs `theme.md:27-35`  |
| first-page footer with live data                             | `themes.DIN-5008(footer: [... #info.iban ...])`                                                            | `tests/integration/footer-dynamic/test.typ` |
| own page setup                                               | `themes.blank` + native `#set page(...)`/`#set text(...)` before `#show: invoice.with(...)`                | `tests/docs/api-theme-blank/test.typ`       |
| replace a whole slot                                         | `themes.blank.with(document: (ctx, body) => ...)`, `themes.DIN-5008().with(signature: (ctx, view) => ...)` | tests `references-defaults`, [E16]          |
| hand-written theme                                           | `theme: () => (line-items: ..., ...)`                                                                      | [E18]                                       |
| subtree override of a slot                                   | `#apply(theme: themes.blank() + (signature: ...))[...]`                                                    | [E19]                                       |
| scale the body typography                                    | outer `#set text(size: 9pt)` - all line-item sizes are em-relative                                         | [E13]                                       |
| restyle the title                                            | outer `#show heading: set text(...)`                                                                       | [E13]                                       |
| recolour item-table rules                                    | outer `#set table.hline(stroke: <paint>)` (accident of bare-length strokes)                                | [E13]                                       |
| logo / stamp hack                                            | `#set page(foreground: place(...))`                                                                        | [E13]                                       |
| static running header                                        | outer `#set page(header: ...)` (survives letter-pro; but `info.*` does not resolve there)                  | [E14]                                       |
| hide/show columns, totals, notices                           | component params `line-items(show-column:, show-total:, show-information:)`                                | `components/line-items.typ:26-34`           |
| QR size/visibility, reference visibility                     | component params `bank-details(qr-code: (size:, display:), show-reference:)`                               | `components/bank-details.typ:37-47`         |
| stripe colours on blank                                      | `themes.blank.with(line-items: themes.blank().line-items.with(color-row-even: ...))`                       | [E16]                                       |

### 4.2 Impossible or painful today

| goal                                                                                          | status                                                                                                                                | why                                                                                                                                                                      |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| accent / brand colour for totals, tax labels, discounts                                       | impossible publicly                                                                                                                   | tokens exist (`color-vat-label`, `color-discount`, ...) but `DIN-5008` does not forward them; wrapper rejects them [E3, E3b]; generic component not importable [E8, E12] |
| tax amount colour                                                                             | impossible even internally                                                                                                            | `text(fill: black)` `totals.typ:177`                                                                                                                                     |
| font sizes (small text, totals size, header 10pt, address 10pt/7pt, reference 8pt/10pt)       | line-items: internal only; letterhead/address: impossible                                                                             | `document.typ:88`, letter-pro literals                                                                                                                                   |
| heading/secondary font, font weights per role                                                 | impossible (one `font` string)                                                                                                        | `document.typ:80`                                                                                                                                                        |
| table header style (background, text colour, uppercase, pills)                                | internal only; and `header-bg` leaves a gap at the spacer column, tax suffix ignores `header-color`                                   | [E6a, E17]                                                                                                                                                               |
| logo placement / letterhead layout                                                            | impossible without replacing `document`                                                                                               | `document.typ:82-125` hard grid; `letter-document` not exported, so replacing means re-implementing DIN 5008 on top of letter-pro (~160 lines) and re-doing PDF metadata |
| DIN information block (right of address)                                                      | impossible                                                                                                                            | letter-pro `information-box` never passed (`document.typ:148-156`)                                                                                                       |
| adding a column (SKU, date, unit, discount %) or custom cell formatting                       | impossible                                                                                                                            | fixed vocabulary `columns.typ:13-18`, if-chain `table.typ:459-483`; unknown keys silently dropped [E6a]                                                                  |
| reordering columns                                                                            | crashes when `total-price` is not last and an item has a modifier                                                                     | `table.typ:610` "missing argument: body" [E6b]                                                                                                                           |
| hiding the total column with groups/modifiers                                                 | crashes                                                                                                                               | `table.typ:183` via `:851` "cannot compare none and integer" [E15]                                                                                                       |
| page 2+ header / running footer with invoice data                                             | impossible with DIN                                                                                                                   | `header`/`footer` slots dead [E2, E11]; letter-pro footer is page-1 only [E14]; outer `set page(header:)` cannot resolve `info.*` [E14]                                  |
| page-number format / language                                                                 | impossible                                                                                                                            | letter-pro `page-numbering` not exposed; language always "de" (S-17), so `locale.en-de` prints "Seite 1 von 2" [E1]                                                      |
| paper size (US Letter, A5) with the DIN look                                                  | impossible                                                                                                                            | letter-pro forces `paper: "a4"` [E5]                                                                                                                                     |
| watermark ("DRAFT", "PAID", "COPY")                                                           | background overwritten by letter-pro marks; only `foreground` hack                                                                    | [E13]                                                                                                                                                                    |
| bank-details layout (QR left/below, boxed, columns), payment sentence style, signature layout | replace whole slot; QR/EPC logic must then be re-implemented                                                                          | `bank-details.typ:13-29`                                                                                                                                                 |
| custom line-items look while keeping legal notices                                            | not possible publicly; internally only via callbacks; a full replacement loses section 19 / exemption notices and 0 %-tax suppression | `global-info.typ`, `totals.typ:430-447`                                                                                                                                  |
| group (section) styling, nested indentation                                                   | impossible                                                                                                                            | no callbacks, `level` unused                                                                                                                                             |
| dark or tinted table header that also covers full width                                       | internal only and visually broken                                                                                                     | [E17]                                                                                                                                                                    |
| per-document-type variations (credit note, reminder, offer)                                   | not addressed by themes at all                                                                                                        | -                                                                                                                                                                        |

---

## 5. CODE SMELLS / INCONSISTENCIES RELEVANT TO AN API FREEZE

**Contract / naming**

- **S-1 Factory convention differs per theme.** `themes.blank` (uncalled) vs `themes.DIN-5008()` (called);
  wrong usage gives a type error in one case and an unrelated panic in the other [E9, E10]. The locale API,
  by contrast, is uniform (`locale.de-de` is always passed uncalled, customized with `.with(...)`).
- **S-2 "blank" is not blank** - it is `base-theme` with full default renderers (`blank.typ:3`).
- **S-3 Dead slots.** `header`/`footer` of `base-theme` never render (`base.typ:35-40`, set rule scoped to the
  `if` block) although commit `23788cb` advertises them. DIN-5008 has a second, different `footer` concept (page 1 only).
- **S-4 Slot fallbacks inconsistent**: identity / `[Line Items]` / panic (section 1.0).
- **S-5 Slot signatures inconsistent**: `line-items(ctx, data, body)` vs others `(ctx, view)`; the parameter is
  called `data` in renderers but `view` in components; callbacks use five different shapes
  (`(ctx,item,layout,styles)`, `(ctx,mod,styles,is-discount:)`, `(ctx,content,styles)`, `(ctx,total-cols,styles)`,
  `(ctx,data,styles,elements)`).
- **S-6 `render-tax-suffix`'s 4th argument changes meaning**: custom callbacks get the column key, the default gets
  the style type (`table.typ:264-274`); the key is `"total"` while the column is `"total-price"` (`table.typ:316`).
- **S-7 Naming drift**: `render-total-gross` -> element `grand-total`; `render-total-net` -> `net-total`;
  `totals-cell-wrapper` lacks the `render-` prefix; `color-subtitle` only colours the tax suffix; `size-subtitle`
  only sizes subtotal labels; `discounts` vs `surcharge`; `formated-total`; theme dir `DIN-5008` vs kebab-case elsewhere.
- **S-8 Two sentinels for "default"**: `auto` in `line-items.typ`, converted to `none` (`:130-157`), and
  `totals.typ:345-401` accepts both.
- **S-9 Two different `styles` dicts** (table vs totals) with overlapping but unequal keys; callbacks cannot rely
  on a stable token set; `stroke-regular` is in neither.

**Duplication**

- **S-10 Defaults repeated in up to 5 places** with diverging values (section 3.4); DIN defaults duplicated between
  `din-5008.typ:6-18` and `document.typ:25-33`; margins duplicated from letter-pro.
- **S-11 Parameter plumbing by hand**: ~50 parameters forwarded one by one through 3-4 signatures
  (`line-items.typ:71-166`); each newly exposed token is a multi-file change.
- **S-12 Copy-pasted row builders**: `line-cell`/spacers/caps/alignment resolution repeated in item, group-header
  and group-footer builders (`table.typ:388-418, 708-726, 804-822`); alignment resolution repeated ~10 times.
- **S-13 Discount/surcharge/prepayment label resolution duplicated** 5 times (`table.typ:53-69`, `totals.typ:41-56, 71-88, 103-126`,
  `base-theme/line-items.typ:80-115`).
- **S-14 Zero-tax detection duplicated 3 times** with different predicates, comparing formatted content such as
  `[0,0%]` (`totals.typ:433-443`, `global-info.typ:92-101, 134-140`).
- **S-15 `to-string` re-implemented** in `document.typ:7-18` (exists in `utils/coercion.typ:35`).

**Leaky abstractions / coupling**

- **S-16 Business and legal logic inside theme renderers**: legal notices (`global-info.typ`), tax listing rules
  (`totals.typ:430-447`), EPC-QR rules (`bank-details.typ:13-29`), PDF metadata and keywords
  (`document.typ:66-78`), city-name extraction (`document.typ:20-23,168-172`). Replacing a slot silently drops
  compliance-relevant output. The `blank` theme produces no PDF metadata at all.
- **S-17 `ctx.locale.lang` is never set** (`locale/factory.typ:66-74` has no `lang`; `root.typ:62` defaults to `"de"`),
  so `set text(lang:)` is always German and letter-pro prints German page numbers for every locale [E1].
- **S-18 ctx differs per slot and is partially stale**: only `document` sees normalized `references`, `items`,
  `item-data`, `bank`, `payment-goal`; other slots get raw `references` (may be a function) and one-pass-old
  `ctx.global.bank` [E-ctx, E18].
- **S-19 Spacer columns leak into callbacks**: `render-table-footer` receives `total-cols` but the table has
  `total-cols + 2` columns, so the advertised `colspan: total-cols` footer stops short [E17]; `header-bg` does not
  fill the spacer columns [E17]; the elegant preset needs a transparent dummy label to align its modifier table
  (`base-theme/line-items.typ:129-138`).
- **S-20 View is pre-formatted and type-inconsistent** (str vs content; almost no raw numbers) - section 1.4.
- **S-21 Visual options split between component and theme** (`qr-code.size`, `show-reference`, `show-column` on
  components; colours on theme) without a stated rule.
- **S-22 Styling inside locale strings** (`*#sum*`, `en.typ:130`).
- **S-23 Two tax-mode sources**: `ctx.tax-mode` (`totals.typ:7,166`) vs `data.tax-mode` (everywhere else).
- **S-24 Index-based alignment arrays** depend on which columns are currently visible (`base-theme/line-items.typ:36-37`,
  `table.typ:182-187`); dict form exists but the default uses the fragile array form.
- **S-25 Directional inset dicts replace instead of merge** (`normalize-directional`, `table.typ:207-214`):
  `(y: .8em)` silently zeroes x and makes headers collide (elegant/luxury presets) [E1]; for strokes the missing
  sides become `0pt` instead of `none`.

**Dead code / robustness**

- **S-26** `item-internal-inset` param never used (`line-items.typ:29`); `meta` computed and unused (`line-items.typ:69`);
  top-level `totals-cell-wrapper` function unused and shadowed (`totals.typ:184-188`); `is-sub-item` unused
  (`table.typ:366`); `col-tracker` variables unused; `types` imported but unused in `table.typ:1` and `totals.typ:1`; `coercion` and the wildcard `loom-wrapper` import
  in `themes/base.typ:3,6` are only re-exported, never used (`types` reaches `din-5008.typ:19` through that wildcard re-export); `unit` dictionary branches unreachable because the view
  already converted units to content (`table.typ:461-468`, `global-info.typ:50-55`); `bank-details(account-holder-text:)`
  declared and unused (`components/bank-details.typ:43`); four unexported presets.
- **S-27 Almost no validation** in the theme layer: only `form` (`din-5008.typ:19`) and `color-desc`
  (`global-info.typ:10`) use `types.require`, while every other public API validates each argument with
  `types.require(value, "scope::name", ...)`.
- **S-28 Crashes in advertised parameter space**: `column-order` with `total-price` not last + item modifier
  (`table.typ:610`, missing body) [E6b]; `show-column: (total-price: false)` + group footer or item modifier
  (`table.typ:183/851`, and `indices.total - indices.desc` with `none` at `:592,:659,:858`) [E15].
- **S-29 Layout by negative space**: `v(-1em)` (`line-items.typ:111`), `h(6.5cm)` (`bank-details.typ:50`),
  `height: 5.5cm` sender block overflowing a 27 mm header (`document.typ:93`).
- **S-30 Emphasis by two mechanisms**: `*strong*` (header labels, bank details, date) vs `text(weight: weight-bold)`
  (names, totals), so a user `show strong` rule and the `weight-bold` token each hit only half of the bold text [E13].

---

## 6. IMPLICATIONS FOR THE DESIGNERS (facts, not proposals)

- The **stable seam that already exists** is: theme = `() => dict`; slots = late-bound functions read from `ctx.theme`;
  customization idiom = `.with(...)` (same as locale's `locale.de-de.with(...)`); ctx cascade + `apply` for subtree overrides.
- The **token vocabulary already exists informally** (section 3.3): ~22 tokens in 5 groups (colour, size, weight, stroke,
  spacing) plus structural options. What is missing is a single source of truth, a transport that is not
  hand-plumbed, and public reachability.
- The **callback layer already exists** for table cells and totals (16 callbacks: 6 table, 10 totals) and the elegant/vibrant presets show
  the intended expressive range; missing are callbacks for columns, group rows, item-subtotal row, notices,
  and any structure at all for letterhead, bank details, payment sentence and signature.
- Anything frozen in v0.5.0 must decide where **legally required output** (notices, QR payload, PDF metadata, zero-tax
  rule) lives, because today it is lost whenever a slot is replaced.
- The `view` dictionaries become public API at the freeze; their naming/type inconsistencies (section 1.4) and the
  per-slot ctx asymmetry (section 1.2) would be frozen with them.
- letter-pro is the hard boundary for DIN customization (A4, page-1 footer, background marks, fixed sizes,
  page-number language). Running headers/footers, info block, logo and non-A4 paper all require either bypassing
  or wrapping it.

---

## Appendix: experiments (all under `scratchpad/proto/theme-internals/`)

| id       | file                                                        | result                                                                                                                                                         |
| -------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| E-ctx    | `ctx-dump.typ` -> `ctx-dump.json`                           | runtime schema of ctx and view per slot                                                                                                                        |
| E1       | `preset-{default,elegant,vibrant,luxury,informational}.typ` | all compile; header collisions in elegant/luxury; inverted striping; "Seite 1 von 2" with `locale.en-de`                                                       |
| E2       | `e2-header.typ`                                             | `DIN-5008().with(header:, footer:)` compiles, renders neither                                                                                                  |
| E3 / E3b | `e3-extra-param.typ`, `e3b-base-wrapper-param.typ`          | `unexpected argument: color-discount`                                                                                                                          |
| E5       | `e5-paper.typ`                                              | `set page("a5")` ignored under DIN-5008                                                                                                                        |
| E6a      | `e6a-unknown-col.typ`                                       | unknown column key silently dropped; generic defaults overlap rows; `header-bg` gap; tax suffix unreadable on dark header                                      |
| E6b      | `e6b-reorder.typ`                                           | crash `table.typ:610`                                                                                                                                          |
| E6c      | `e6c-reorder-nomods.typ`                                    | reorder works without modifiers; generic default stripes odd rows                                                                                              |
| E8       | `e8-pkg-subpath.typ`                                        | package sub-path import is a Typst error                                                                                                                       |
| E9 / E10 | `e9-blank-called.typ`, `e10-din-uncalled.typ`               | type error / misleading panic                                                                                                                                  |
| E11      | `e11-blank-header.typ`                                      | blank theme `header:`/`footer:` not rendered                                                                                                                   |
| E12      | `e12-members.typ`                                           | `themes` exports exactly `("blank", "DIN-5008")`                                                                                                               |
| E13      | `e13-setrules.typ`                                          | which outer set/show rules reach through DIN-5008 (size yes, font no, background no, foreground yes, heading yes, `table.hline` paint yes, `strong` partially) |
| E14      | `e14-footer-pages.typ`                                      | DIN footer only on page 1; outer `set page(header:)` persists but `info.*` is empty there                                                                      |
| E15      | `e15-no-total-col.typ`                                      | crash `table.typ:183`                                                                                                                                          |
| E16      | `e16-li-slot-dict.typ`                                      | `themes.blank().line-items.with(color-row-*)` works                                                                                                            |
| E17      | `e17-footer-colspan.typ`                                    | table footer `colspan: total-cols` stops short; header fill gap on the right                                                                                   |
| E18      | `e18-handwritten.typ`                                       | hand-written partial theme dict works; `ctx.references` is a raw function in child slots                                                                       |
| E19      | `e19-apply-theme.typ`                                       | `#apply(theme: ...)` overrides a slot for a subtree                                                                                                            |
