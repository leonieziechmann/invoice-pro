# Component <-> Theme Contract (ground truth, invoice-pro 0.4.2)

Researcher focus: the contract between loom components ("motifs") and themes.
All paths are relative to `<repo>/` unless they start with `loom:` (= `%LOCALAPPDATA%/typst/packages/preview/loom/0.1.1/src/`) or `letter-pro:` (= `%LOCALAPPDATA%/typst/packages/preview/letter-pro/3.0.0/src/lib.typ`).
Every behavioural claim marked **[E_n]** was verified by a prototype compile with typst 0.15.1; the sources are in
`<session>/proto/component-contract/` (`e1-...typ` ... `e10-...typ`, PNG/PDF outputs next to them).

---

## 0. TL;DR for designers

1. A "theme" today is a **zero-argument function returning a flat dictionary of 7 keys** (`document, header, footer, line-items, bank-details, payment-goal, signature`), built by `base-theme` (`src/themes/base-theme/base.typ:8-50`). `invoice()` calls it once (`src/invoice.typ:180`) and puts the dict into the loom ctx as `ctx.theme` (`src/invoice.typ:291`). Components reach it as `(ctx.theme.<slot>)(ctx, view[, body])`.
2. Only **5 slots are live**: `document` (root), `line-items`, `bank-details`, `payment-goal`, `signature`. `header`/`footer` of `base-theme` are **dead code because of a Typst scoping bug** (set rule inside an `if` block, `src/themes/base-theme/base.typ:35-40`) **[E2]**. The only working footer is the DIN-5008 one (`src/themes/DIN-5008/document.typ:157-159`).
3. Everything a business would call "the letterhead" (sender block, return-address line, recipient window, annotations, reference/info block, title, place+date, folding marks, page numbers, PDF metadata, font) is rendered by **one monolithic function** `letter-document` + the external package `letter-pro` - there is no slot, no token and no callback for any of it. With `themes.blank` none of it is rendered at all **[E2]**.
4. Everything inside the table (group headers, per-item modifiers, subtotals, totals, tax rows, prepayments, amount due, **legally required tax notes**) is rendered by the single `line-items` slot. The generic renderer has ~55 flat named parameters and 16 callbacks, but groups, item cells and the legal-notes block have no callback.
5. `apply(..)` is a 5-line ctx-override motif (`src/loom-wrapper.typ:18-22`). `apply(theme: <full evaluated dict>)` **already re-themes a subtree correctly**; `apply(theme: <partial dict>)` **replaces** the theme (shallow `+`) and then either panics or - for `line-items` - silently renders the placeholder text "Line Items"; `apply(theme: <function>)` is silently turned into an empty theme **[E3]**. A deep-merging scoped override and scoped design tokens are trivially implementable with the same mechanism **[E9]**.
6. Theme draw functions are **pure content producers, run only in the draw pass, cannot emit signals**, so themes cannot corrupt calculated data or the ZUGFeRD XML. But themes currently _own_ several things that are data/compliance, not styling: PDF metadata (`set document`), the EPC-QR payload, IBAN formatting, the legal notes (small-business clause, exemption grounds), page-number wording.
7. Motifs (`info.*`, `dynamic`, components) returned from a theme function are **inert** unless the theme passes them through `eval-content(ctx, ..)`; motifs inside `context {}`/`layout()` are always inert **[E4, E6]**. Per-page furniture that mixes invoice data and page numbers works through the (currently unused) _function branch_ of `eval-content` **[E10]**.

---

## 1. Exact shape of the loom ctx seen by draw functions

### 1.1 How ctx is born

| Step | Where                                     | What                                                                                                                                                             |
| ---- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | `loom:core/context.typ:26-32`             | `empty-context = (sys: (path: (), debug: false, relative-id: 0))`                                                                                                |
| 2    | `loom:core/runtime.typ:64-65`             | `base-ctx = empty-context + inputs`, then `sys.debug`, `sys.key` set                                                                                             |
| 3    | `loom:core/runtime.typ:73-76` / `101-103` | per pass: `sys.pass = "measure"` / `"draw"`, then `ctx + injector(ctx, payload)`                                                                                 |
| 4    | `src/invoice.typ:326-328`                 | injector: `ctx + (global: payload.first(default: (:)).at("signal", default: (:)))` - i.e. `global` = the **root frame's public signal of the previous pass**     |
| 5    | `loom:core/engine.typ:89-90`              | every motif: `child-ctx = scope(ctx)`; the **same `child-ctx` is handed to the motif's own `measure` and `draw`** (`engine.typ:111`, `:123`) and to its children |

`weave(max-passes: 2, ...)` (`src/invoice.typ:323-330`) => `measure-limit = 1` (`loom:core/runtime.typ:70`): exactly **one measure-only pass** (with `global = (:)`) and **one draw pass, which re-runs every `scope` and `measure`** with `global` injected from pass 1. The convergence check (`runtime.typ:86`, needs `i > 0`) and `handle-nonconvergence` (`runtime.typ:93`, needs `measure-limit > 1`) can never fire with `max-passes: 2`.

### 1.2 Top-level keys set by `invoice()` (`src/invoice.typ:290-320`)

| key                                                                                                                                                                      | type / content                                                                                                                                                                                                                                                                                         | line           |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------- |
| `theme`                                                                                                                                                                  | **evaluated** theme dict (`theme()`), 7 keys                                                                                                                                                                                                                                                           | `:180`, `:291` |
| `locale`                                                                                                                                                                 | evaluated locale dict: `strings, format, normalize, currency, tax, meta, resolve-plural, lang` [E1]                                                                                                                                                                                                    | `:181`, `:292` |
| `format`                                                                                                                                                                 | alias of `locale.format` (identical value [E1])                                                                                                                                                                                                                                                        | `:293`         |
| `sender`, `recipient`                                                                                                                                                    | normalized party dicts (`logic/country.typ:640-664`): user keys + `name, address-lines, address, city, name-inline, address-inline, city-inline, country (dict w/ code), city-name, post-code, state, tax-nr, vat-id`; root adds `extra` as array of pairs (`src/components/root.typ:33-34`, `:52-53`) | `:295-296`     |
| `delivery-address`                                                                                                                                                       | normalized party or `none` (also mirrored into `recipient.delivery-address`, `:239-241`)                                                                                                                                                                                                               | `:297`         |
| `invoice-date`                                                                                                                                                           | datetime                                                                                                                                                                                                                                                                                               | `:299`         |
| `subject`                                                                                                                                                                | **already joined** `"<subject> <invoice-nr>"` string/content (`:245`)                                                                                                                                                                                                                                  | `:300`         |
| `references`                                                                                                                                                             | raw: array of pairs / builder fns / preset fn (`:257-288`); normalized only inside root.draw                                                                                                                                                                                                           | `:301`         |
| `invoice-nr`, `customer-nr`, `order-nr`, `order-date`, `project`, `contract-nr`, `quote-nr`, `delivery-note-nr`, `preceding-invoice-nr`, `due-date`, `payment-reference` | pass-through                                                                                                                                                                                                                                                                                           | `:302-313`     |
| `tax`                                                                                                                                                                    | document default tax dict                                                                                                                                                                                                                                                                              | `:315`         |
| `tax-mode`                                                                                                                                                               | `"exclusive"`/`"inclusive"`                                                                                                                                                                                                                                                                            | `:316`         |
| `tax-exempt-small-biz`                                                                                                                                                   | bool                                                                                                                                                                                                                                                                                                   | `:317`         |
| `zugferd`                                                                                                                                                                | `none` or profile string                                                                                                                                                                                                                                                                               | `:319`         |
| `sys`                                                                                                                                                                    | `(path: ((kind, idx), ...), debug, relative-id, key: <invoice-pro:0.4.2>, pass: "measure" or "draw")` [E1]                                                                                                                                                                                             | loom           |
| `global`                                                                                                                                                                 | see 1.3                                                                                                                                                                                                                                                                                                | `:326-328`     |

### 1.3 `global` (injector + root)

- Measure pass: `global = (:)`; root.scope pads it with zeros: `global.total.{net,gross,due,prepaid} = decimal(0)`, `global.formated-total.* = "0"` (`src/components/root.typ:75-89`).
- Draw pass, **as seen by all children of root** (line-items, bank-details, signature, `dynamic`, ...): the root public signal of pass 1 = `(total: (net, gross, due, prepaid) as decimals, formated-total: (...) as strings, bank: <bank-details public signal or none>)` (`src/components/root.typ:137-141`). Verified [E1]. Note `global.bank.payment-amount` is **stale (`0`)** here when `payment-amount: auto`, because in pass 1 the bank component saw zero totals (`src/components/bank-details.typ:125-129`).
- Draw pass, **as seen by `theme.document` and by header/footer evaluated through `eval-content`**: root.draw overwrites `global` with values of the _current_ (draw-pass) measure (`src/components/root.typ:290-294`) -> everything fresh (`payment-amount: 209.90` in [E1]).

### 1.4 Keys added by scope mutators (visible to the component's own draw fn = what the theme slot receives)

| Component                                              | Adds / changes in ctx                                                                                                                                                                                                                                                                                       | Source                                                                                                                   |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| root                                                   | pads `sender.*`/`recipient.*` with **visible placeholder strings** like `"#recipient.address"`; `invoice-date`, `subject`, `references`, `invoice-nr` defaults; `locale.lang`, `locale.meta.region`, `locale.format.date`; `theme.document` default; `zugferd`; `global.*` zeros; `sys.path += ("root", i)` | `src/components/root.typ:15-90`                                                                                          |
| root **draw only** (seen by `theme.document` + footer) | `references` -> **normalized array of `(label, value)` pairs**; `items` (raw item signals), `item-data` (raw totals/taxes/prepayments/discounts/surcharges), `payment-goal` (signal or none), `bank` (signal or none), fresh `global`                                                                       | `src/components/root.typ:282-296`                                                                                        |
| line-items                                             | `input-gross`, `tax`, `tax-mode`, `tax-exempt-small-biz`, `show-column` (merged dict of 9 flags), `show-total`, `show-information`, `locale.strings`, `locale.format.*` panic-defaults, `theme.line-items` default                                                                                          | `src/components/line-items.typ:78-134`                                                                                   |
| bank-details                                           | `sender.name` (derive), `text`, `reference`, `theme.bank-details`, `global.total.gross`                                                                                                                                                                                                                     | `src/components/bank-details.typ:82-107`                                                                                 |
| payment-goal                                           | `locale.format.{currency,date}`, `theme.payment-goal`, `global.total.gross`                                                                                                                                                                                                                                 | `src/components/payment-goal.typ:22-45`                                                                                  |
| signature                                              | `sender.name` (derive), `locale.strings`, `theme.signature`                                                                                                                                                                                                                                                 | `src/components/signature.typ:21-33`                                                                                     |
| item / bundle / group / modifier / prepayment          | data cascade keys (`description, quantity, base-quantity, unit, date, item-price, item-total, input-gross, tax, item-id, reference, modifier, label, name, method, bundle-*, group-description, modifier-amount, prepayment-amount`) - never reach a theme because these motifs have no draw                | `src/components/item.typ:169-248`, `bundle.typ:89-168`, `group.typ:65-120`, `modifier.typ:55-74`, `prepayment.typ:75-96` |
| `apply(..)`                                            | any named arg, shallow `ctx + args.named()`                                                                                                                                                                                                                                                                 | `src/loom-wrapper.typ:18-22`                                                                                             |

Full key list dumped at runtime [E1] for `theme.document`: `sys, theme, locale, format, sender, recipient, delivery-address, invoice-date, subject, references, invoice-nr, customer-nr, order-nr, order-date, project, contract-nr, quote-nr, delivery-note-nr, preceding-invoice-nr, due-date, payment-reference, tax, tax-mode, tax-exempt-small-biz, zugferd, global, items, item-data, payment-goal, bank`.
For `theme.line-items`: the 26 base keys + `input-gross, show-column, show-total, show-information` (no `items`/`item-data`!). For `theme.bank-details`: base + `text, reference`. `theme.signature` / `theme.payment-goal`: base only.

**Implication:** ctx is an untyped, flat, shared namespace in which data (`tax`), per-instance presentation flags (`show-column`), system fields (`sys`), services (`locale`, `theme`) and cascade scratch keys (`label`, `description`, `name`, `date`, `text`, `reference`) all live side by side. Any new theming key (`tokens`, `style`, ...) must avoid these names; `label`, `name`, `text`, `date`, `description`, `reference`, `unit`, `tax` are already taken by data cascades.

---

## 2. Per-component contract

Signature conventions today: `document: (ctx, body) => content`; `line-items: (ctx, view, body) => content`; `bank-details | payment-goal | signature: (ctx, view) => content` (`src/themes/base-theme/base.typ:9-31`). loom's draw signature is `(ctx, public, view, body)` (`loom:data/primitives.typ:75-77`); **all components drop `public` (the raw frame)** before calling the theme.

### 2.1 root (`src/components/root.typ`)

- **Theme access:** `(ctx.theme.document)(ctx, body)` (`:312`).
- **Missing slot:** `ensure("theme", "document", (.., body) => body)` (`:71`) -> silent pass-through. Because `nest` replaces any non-dictionary by `(:)` (`loom:lib/mutator.typ:86`), a `ctx.theme` that is not a dict (e.g. user passed `themes.DIN-5008` un-called, so `theme()` returns a function) is **silently replaced by an empty theme**; the user then gets the misleading panic `theme::signature is not provided` or the "Line Items" placeholder **[E7]**. `types.require(theme, ..., function)` (`src/invoice.typ:106`) cannot catch this. Conversely `theme: themes.blank()` fails the type check. Note the public asymmetry: `themes.blank` (un-called) vs `themes.DIN-5008()` (called) (`src/themes/blank/blank.typ:3`, `src/themes/DIN-5008/din-5008.typ:6-37`).
- **measure -> view:** `(item-data, payment-goal, bank, total, formated-total)` (`:143-149`); public = `(total, formated-total, bank)` (`:137-141`). Asserts max. one `line-items` and one `payment-goal` (`:96-99`, `:114-117`).
- **draw does much more than delegate** (`:153-313`):
  - `set text(lang: ctx.locale.lang, region: ...)` (`:154-158`) - a style rule issued by the component (this is what makes letter-pro print "Seite x von y").
  - normalizes `references` (builder closures `ctx => (label, value)`, presets, pairs, dict) into `(label, value)` pairs, dropping empty values (`:160-280`). This happens **in draw**, so children never see normalized references; only `theme.document`/footer do.
  - merges `items, item-data, payment-goal, bank, global` into ctx (`:282-296`).
  - `pdf.attach("/factur-x.xml", build-zugferd-xml(...))` (`:298-310`) - see section 6.
- **Leaky presentation in the component:** placeholder strings (`"#sender.name"`, ... `:19-27`, `:38-46`) that are printed verbatim when data is missing (visible in [E7] output: `#recipient.address`); `subject` pre-joined with invoice number in `invoice.typ:245` (theme cannot style "Rechnung" and the number separately, nor omit the number).

### 2.2 line-items (`src/components/line-items.typ`)

- **Theme access:** `draw: (ctx, _, view, body) => (ctx.theme.line-items)(ctx, view, body)` (`:500`). `body` = the already-drawn residual content inside `#line-items[...]` (stray text between items; items themselves draw nothing) - [E1] shows `sequence([ ], ..., [stray text inside line-items], ...)`. The default renderer appends it after the legal notes (`src/themes/components/line-items/line-items.typ:168`).
- **Missing slot:** `ensure("line-items", (..) => [Line Items])` (`:131-133`) -> **silent placeholder text instead of an error** [E3c, E3d].
- **view (what the theme gets)** (`:460-472`), verified [E1]:
  - `items`: formatted item dicts; `entries`: flat ordered list of `kind: "item" | "group-header" | "group-footer"` with `pos` (`"1.2"` strings computed in `src/logic/tree.typ:49,101`) and `level`.
  - item fields: `name, description` (content, `[]` when none), `date` (formatted string), `quantity, base-quantity, price, total, unmodified-total` (**locale-formatted strings**), `unit` (content), `tax: (rate: "21%", category)`, `discounts/surcharge` (arrays of `(name, label, description, display, absolute, is-percent, has-description)`, signs stripped with `calc.abs`), `item-id, reference`, flags `has-description, has-date, has-discounts, has-surcharge, has-item-id, has-reference` (`:150-214`).
  - `discounts, surcharges` (global modifiers incl. per-tax `split`), `prepayments` (`name,label,date,reference,description,method,amount (content), value (decimal)`), `taxes` (`rate, raw-rate, raw-amount, category, amount, grounds, marker`), `total` / `unmodified-total` (formatted strings), `tax-mode`, `tax-exempt-small-biz`.
  - `layout-information`: 11 resolved `show-*` booleans + 7 facts (`has-dates, multiple-dates, multiple-quantities, multiple-units, multiple-tax-rates, has-global-modifier, has-prepayments`) (`:407-458`).
- **Raw numbers are withheld.** Except `taxes[].raw-rate/raw-amount`, `prepayments[].value`, `group-footer.raw-subtotal`, the view only contains formatted strings/content. The raw data exists in `public.signal.item-data` (`:483-495`) but draw discards `public`, and `ctx.items/item-data` are only added by root.draw for `document`. A theme cannot e.g. colour negative amounts, right-align on the decimal separator with its own formatter, draw a bar, or re-format currency.
- **Presentation logic that lives in the component:**
  - all number/date/percent formatting (`:148-214`, `:329-339`);
  - column auto-visibility policy (`show-quantity` iff multiple quantities or units, etc., `:419-458`). The theme receives only resolved booleans, so it cannot tell "user forced it" from "auto", and **a theme cannot supply different defaults** (e.g. "always show unit price");
  - footnote marker alphabet `("*", "**", "***", "****")`, then `"*5"` (`:255-275`);
  - label resolution for modifiers/prepayments from locale strings in _measure_ (`src/components/modifier.typ:98-116`, `src/components/prepayment.typ:109-118`) - and the theme resolves `auto` labels **again** (`src/themes/components/line-items/table.typ:53-59`, `totals.typ:41-46`, `:71-76`, `:103-108`);
  - prepayment date formatting (`src/components/prepayment.typ:129-135`);
  - hierarchical position format `"1.1.4"` (`src/logic/tree.typ:49`, `:101`);
  - English-only bundle auto-description joiner `", " / " and "` and bracket descriptor `"(19% S)"` (`src/logic/calc-bundle.typ:38-48`, `:95`).
- **Per-instance presentational props already exist on the component** (`show-column`, `show-total`, `show-information`, `:28-34`) and **cascade through ctx** (`put("show-column", base-col + show-column)`, `derive("show-total", ...)`, `:98-108`) - so `apply(show-column: (date: false))[...]` works today. This is the existing precedent for "instance prop > apply scope > default".

### 2.3 item, bundle, group, modifier/discount/surcharge, prepayment

All are `data-motif`/`compute-motif` (no draw; `loom:data/primitives.typ:206-282`): they only feed signals to `line-items`. **None of them reaches the theme.** Their visual representation is produced exclusively inside the `line-items` slot:

| Visible thing                                                                                              | Rendered by                                                                                                                                                 |
| ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| item main row (pos, title+date, qty+unit, unit price, tax, total)                                          | `src/themes/components/line-items/table.typ:362-491`; title via `render-title` callback (`:6-29`), cells hard-coded (`:458-489`)                            |
| item description row                                                                                       | `table.typ:493-529`, callback `render-description` (`:31-40`)                                                                                               |
| item-level discounts/surcharges + per-item subtotal                                                        | `table.typ:531-687`, callback `render-modifier` (`:42-81`); subtotal row hard-coded (`:631-687`)                                                            |
| **group header / group subtotal**                                                                          | `table.typ:702-796` / `:798-898` - **no callback, no parameter** (hard-coded `1.05em`, `+0.4em` inset, no fill)                                             |
| table header, tax suffix "(net)"                                                                           | `table.typ:305-348`, callbacks `render-header`, `render-tax-suffix`                                                                                         |
| totals block: subtotal, global discounts/surcharges, net, tax rows, gross, **prepayments**, **amount due** | `src/themes/components/line-items/totals.typ:300-464`; 8 `render-*` callbacks returning `(label, value)` pairs, `totals-cell-wrapper`, `render-totals-body` |
| bundle                                                                                                     | appears as a virtual item (`src/logic/calc-bundle.typ:50-76`) - indistinguishable from an item in the view (no `kind: "bundle"`, children not available)    |

`group.typ:68-70` puts `group-description` into ctx but nothing reads it; the description travels via the signal (`:123-129`).

### 2.4 bank-details (`src/components/bank-details.typ`)

- **Theme access:** `(ctx.theme.bank-details)(ctx, view)` (`:143`). **Missing slot -> panic** `theme::bank-details is not provided` (`:96-100`). Because `ensure` treats `none` as missing (`loom:lib/mutator.typ:149`), `base-theme.with(bank-details: none)` also panics - **`none` cannot mean "render nothing"** [E7 `none-slot`].
- **view** (`:109-130`) [E1]: `sender: (name, bank, iban, bic)`, `qr-code: (size: 5em, display: true)`, `reference`, `text`, `show-reference`, `payment-amount` (decimal; `auto` -> `global.total.due`). public = `(iban, bic, reference, text, payment-amount)` -> feeds ZUGFeRD via root (`src/components/root.typ:102-108`).
- **Leaks:** presentation defaults in the component (`qr-code.size: 5em`, `display: true`, `:117-120`; `show-reference`); `account-holder-text` is declared (`:43`) and **never used anywhere**. Inverse leak: **business logic lives in the theme** - EPC-QR generation, the EUR-only rule, the `>= 0.1` amount threshold and IBAN grouping are in `src/themes/base-theme/bank-details.typ:13-29`, `:43`. A custom theme must re-implement (or forget) them.

### 2.5 payment-goal (`src/components/payment-goal.typ`)

- `(ctx.theme.payment-goal)(ctx, view)` (`:55`); missing -> panic (`:34-38`).
- view = public = `(days, date, total)` (`:47-53`) - `total` is a raw decimal (the only slot that gets raw money). Signal also used by root for ZUGFeRD and by `dynamic("due-date")` (`src/components/dynamic.typ:75-88`).
- The default renderer (`src/themes/base-theme/payment-goal.typ:3-24`) only calls locale string functions; the **bold markup of the amount is inside the locale string** (`src/locale/lang/en.typ:127-130`: `*#sum*`) -> styling lives in locale data.

### 2.6 signature (`src/components/signature.typ`)

- `(ctx.theme.signature)(ctx, view)` (`:42`); missing -> panic (`:30-32`). view = `(name, signature)` (`:35-38`), no public signal.
- Default renderer `src/themes/base-theme/signature.typ:1-16` (hard-coded `v(1em)` spacing, locale closing).

### 2.7 dynamic / `info.*` (`src/components/dynamic.typ`, `src/public/info.typ`)

- `content-motif` with only a draw (`:40-327`); **never touches `ctx.theme`**. Resolves a ctx path with many alias fallbacks (`:67-295`), then formats: datetime via `locale.format.date`, arrays joined with `", "` (`:307-324`). Output is bare inline content - themes cannot style "dynamic values" as a class.
- `info` is a module of pre-built `dynamic(...)` motif contents (`src/public/info.typ:8-58`), designed for theme footers (`tests/integration/footer-dynamic/test.typ`).
- Side finding [E8]: `info.total.due` and `info.total.prepaid` render nothing - the fallback only handles `("total","gross"|"net")` (`src/components/dynamic.typ:281-293`) and ctx has no top-level `total`.

### 2.8 `utils/display-matcher.typ`

Pure helper copied from loom (`src/utils/display-matcher.typ:1-65`) that pretty-prints matcher schemas for `types.require` error messages. No theme relevance except: it is the package's standard for **validation error text**, which the theme API currently does not use at all (no validation of slot signatures, slot names or parameter types; only `form` is checked, `src/themes/DIN-5008/din-5008.typ:19`, and `color-desc` in `global-info.typ:10`).

### 2.9 Summary of `ensure()` defaults - three different policies

| slot                                        | default when missing/`none`/theme not a dict | behaviour                                                               |
| ------------------------------------------- | -------------------------------------------- | ----------------------------------------------------------------------- |
| `document`                                  | `(.., body) => body`                         | silent pass-through                                                     |
| `line-items`                                | `(..) => [Line Items]`                       | **silent wrong output**                                                 |
| `bank-details`, `payment-goal`, `signature` | `(..) => panic("theme::X is not provided")`  | loud, but message is misleading when the real cause is a non-dict theme |
| `header`, `footer`                          | never ensured, never read from ctx           | -                                                                       |

---

## 3. Visible parts with NO theme slot today

### 3.1 Rendered only inside the DIN-5008 `document` monolith (nothing in `blank`) [E2]

| Part                                                                                                                 | Rendered at                                                                                                                                                                                                                                                    | Customisable?      |
| -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| PDF metadata title/author/date/description/keywords                                                                  | `src/themes/DIN-5008/document.typ:66-78`                                                                                                                                                                                                                       | no                 |
| base font                                                                                                            | `document.typ:80`                                                                                                                                                                                                                                              | `font` param only  |
| letterhead block: subject (top-left, 10pt) + sender name/address/city + `sender.extra` key/value grid (right, 5.5cm) | `document.typ:82-125`                                                                                                                                                                                                                                          | no (no logo slot!) |
| return-address line (`sender-box`)                                                                                   | `document.typ:133-136`                                                                                                                                                                                                                                         | no                 |
| annotation zone from `recipient.extra`                                                                               | `document.typ:41-50`, `:137`                                                                                                                                                                                                                                   | no                 |
| recipient window                                                                                                     | `document.typ:127-131`, `:138-146`                                                                                                                                                                                                                             | no                 |
| information block (DIN "Informationsblock")                                                                          | letter-pro supports `information-box` (`letter-pro:106`, `:217`) but invoice-pro never passes it                                                                                                                                                               | unavailable        |
| references / "Bezugszeichenzeile"                                                                                    | data from `ctx.references` (`document.typ:37`, `:154`); layout hard-coded in `letter-pro:226-245` (4 fixed columns 45.77mm x3 + 25mm, 8pt label/10pt value; a 5th reference wraps to a new row [E4])                                                           | no                 |
| title `heading(subject)` + "City, **date**" line                                                                     | `document.typ:164-181`                                                                                                                                                                                                                                         | no                 |
| `set text(hyphenate: true)`, `set par(justify: true)` for the body                                                   | `document.typ:183-184`                                                                                                                                                                                                                                         | no                 |
| page size A4, margins, folding marks, hole mark                                                                      | `letter-pro:132-160`; params `form, hole-mark, folding-marks, margin` (`din-5008.typ:6-18`)                                                                                                                                                                    | partially          |
| **page numbering** "Seite x von y" / "Page x of y"                                                                   | `letter-pro:163-188` (wording at `:174-180`): hard-coded German if `text.lang == "de"`, **English for every other locale** (fr/es/it get English); `page-numbering` param of letter-pro exists (`letter-pro:110`) but is **not passed through** by invoice-pro | no                 |
| footer                                                                                                               | `document.typ:157-159` -> `letter-pro:190-192`: **page 1 only**                                                                                                                                                                                                | content only       |
| continuation header on page >= 2 (sender, invoice no., page)                                                         | **does not exist**; page 2 shows only the repeated table header [E4]                                                                                                                                                                                           | -                  |
| per-page background / watermark ("ENTWURF", "STORNO", "KOPIE"), logo, accent bar                                     | does not exist                                                                                                                                                                                                                                                 | -                  |

### 3.2 Rendered inside the `line-items` monolith without an own hook

- group header / group subtotal rows (`table.typ:702-898`);
- item cells other than title/description (`table.typ:458-489`);
- per-item subtotal row (`table.typ:631-687`);
- **legal/global notes block**: standard tax statement, single unit/quantity/date notes, **small-business clause (e.g. section 19 UStG), tax-exemption grounds with footnote markers** - `src/themes/components/line-items/global-info.typ:3-166`. It takes only `color-desc`/`size-small`; its _decision logic_ (when a note is legally required, marker matching `:102-111`, `:141-150`) lives in theme code. **A custom `line-items` renderer that does not call `render-global-info` silently drops legally required text.**
- `v(-1em)` glue between table and totals (`line-items.typ:111`) and inside the elegant variant (`base-theme/line-items.typ:225`).
- No unbreakable item rows: an item's title row and description row can be split across pages ([E4]: "Item 12" on page 1, its description on page 2).

### 3.3 Rendered by components without theme involvement

- `dynamic` / `info.*` output (`src/components/dynamic.typ:297-324`).
- `set text(lang, region)` (`src/components/root.typ:158`).
- Free user content between components (plain Typst, styled only by whatever `set` rules `document` left active).

### 3.4 Data in ctx that no theme ever renders

`delivery-address`, `due-date`, `customer-nr`, `order-nr`, ... are never read by theme code (grep over `src/themes`: no hit); they only appear if the user lists them in `references` (`src/logic/references.typ`). `sender.contact`, `recipient.tax-nr` likewise.

### 3.5 Dead / unreachable theme code

- `base-theme(header:, footer:)`: `if header != none { set page(header: ...) }` - the set rule is scoped to the `if` block and has no effect (`src/themes/base-theme/base.typ:35-40`) **[E2: neither mark appears, `typst query` finds no metadata]**. Also, the evaluated theme dict carries `header`/`footer` keys (`:43-44`) that nobody reads.
- `render-line-items-elegant|vibrant|luxury|informational` (`src/themes/base-theme/line-items.typ:41-321`) are referenced nowhere (not in `themes.typ`, tests or docs) - they are design sketches that show what the callback API was meant to enable.
- `eval-content`'s function branch (`src/loom-wrapper.typ:26-30`): DIN-5008 hands the closure to letter-pro, which expects content -> `error: expected content, found function` **[E4 function]**.

---

## 4. `apply(..)` and scoping theme values

### 4.1 Mechanism

```typ
#let apply(..args, body) = compute-motif(
  scope: ctx => ctx + args.named(),
  measure: (_, children) => children,
  body,
)
```

(`src/loom-wrapper.typ:18-22`). It is invoice-pro's own motif, **not** loom's `apply-motif` (`loom:lib/motifs.typ:83-109`, which filters `auto`). Properties:

- un-named `compute-motif` -> plain `motif`: `sys.path` is not extended (`loom:data/primitives.typ:239-241`), so `assert-direct-parent(ctx, "line-items", ...)` guards of items still pass (used in `template/invoice.typ:80`, `tests/issues/issue-19/test.typ:84-99`).
- `measure` returns the children frames unchanged -> signals bubble through; `resolve-tree` explicitly unpacks the nested arrays (`src/logic/tree.typ:25-35`). Verified: root still sees totals of a `line-items` wrapped in `apply` [E3c, E3e, E9].
- Shallow merge: a dict-valued key **replaces** the inherited dict.
- Static: values are fixed at call time; there is no `ctx => ...` form, so "current theme + delta" cannot be expressed by the user.
- Only affects descendants. `theme.document`, the page header/footer and the ZUGFeRD build run with **root's** ctx and are out of reach of any `apply`.
- Components consume cascaded keys via `derive(key, prop, default:)` = "explicit prop wins, `auto` inherits ctx, else default" (`loom:lib/mutator.typ:166-190`) - the package's established cascade semantics (`tax`, `unit`, `date`, `input-gross`, `label`, `modifier`, `show-column`, `show-total`).

### 4.2 What happens today with `apply(theme: ...)` **[E3]**

| Input                                                                                                       | Result                                                                                                        |
| ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| (a) `apply(theme: (signature: fn))[#signature()]`                                                           | works for the signature; inside the subtree `ctx.theme.keys() == ("signature",)` - the other 6 slots are gone |
| (b) same partial dict around `#payment-goal(...)`                                                           | `panicked with: theme::payment-goal is not provided`                                                          |
| (c) same partial dict around `#line-items[...]`                                                             | **no error; table replaced by the text "Line Items"**; totals still reach root                                |
| (d) `apply(theme: themes.DIN-5008())` (un-evaluated theme function)                                         | `nest("theme", ..)` swaps the function for `(:)` -> "Line Items" placeholder, silently                        |
| (e) `apply(theme: (themes.DIN-5008(color-row-odd: yellow, color-row-even: aqua))())` (fully evaluated dict) | **works**: subtree table is re-themed, signature default intact, root totals correct                          |

### 4.3 Can the same mechanism scope theme values? Yes **[E9]**

Prototype (`e9-scoped-tokens.typ`):

```typ
#let restyle(theme: (:), tokens: (:), body) = compute-motif(
  scope: ctx => ctx + (
    theme: loom.collection.merge-deep(ctx.at("theme", default: (:)), theme),
    tokens: loom.collection.merge-deep(ctx.at("tokens", default: (:)), tokens),
  ),
  measure: (_, children) => children,
  body,
)
```

Results: arbitrary ctx keys set by plain `apply(tokens: (accent: red))` reach the slot function (`ctx.tokens.accent`); nested `restyle` scopes inherit and deep-merge; all 7 slots stay present (`theme-keys=7`); `line-items` inside still reports to root. So both **slot overrides** and **token overrides** per subtree are feasible with zero engine changes. What is missing is only: merge semantics, normalisation (function vs dict), validation of slot names, and a reserved ctx key.

Caveat: `loom.collection.merge-deep` merges dict-valued tokens recursively - a token whose _value_ is a dict (e.g. a stroke dict or `inset: (x:, y:)`) will be merged key-wise, not replaced.

### 4.4 Today's other override idiom: `.with` chaining

Because every theme is `base-theme.with(...)`, `(themes.DIN-5008()).with(signature: (ctx, view) => ...)` works **[E7 with-override]** - later named args win. Limits: DIN-5008's own options (`font`, `form`, `margin`, `footer`) are baked into the `document` closure (`din-5008.typ:21-36`) and cannot be changed afterwards; replacing `line-items` loses the row colours; there is no way to _wrap_ (decorate) an existing slot because the previous value is not accessible.

---

## 5. Header/footer evaluation and page furniture

### 5.1 `eval-content` (`src/loom-wrapper.typ:24-34`)

```typ
#let eval-content(ctx, it) = {
  if it == none { return none }
  if type(it) == function {
    (..args) => { let res = it(..args); loom.core.intertwine(ctx, res, key: loom-key, draw: true).at(0) }
  } else {
    loom.core.intertwine(ctx, it, key: loom-key, draw: true).at(0)
  }
}
```

- A **nested, one-shot draw traversal** of arbitrary content with the caller's ctx. Returns only content; **signals are discarded** (`.at(0)`). A `bank-details` or `payment-goal` placed in a footer renders, but never reaches root/ZUGFeRD [E6].
- Called from `theme.document`, so the ctx is **root's draw ctx** (fresh `global`, normalized `references`, `items`, `item-data`, `payment-goal`, `bank`; `sys.path = (("root",0),)`, `sys.pass = "draw"`) [E4 fdump]. Subtree `apply` overrides are not visible.
- Evaluated **once per document**, not per page. The result is static content.
- Content branch: motifs outside `context` resolve ("Sender Corp / 1.569,37 EUR"); **motifs inside `context [...]` stay inert** ("[ page 1]") because `intertwine` cannot look into a context closure (`loom:core/engine.typ:225-226` atomic case) **[E4]**. Same for `layout(size => ...)` [E6].
- Function branch: returns a closure that evaluates+intertwines on each call. **Nobody calls it correctly today** (see 3.5).

### 5.2 Rule for theme authors (verified [E6])

- Content returned by a theme slot is **not** re-intertwined (`loom:core/engine.typ:122-128`): `[#info.sender.name]` inside a slot renders nothing; `eval-content(ctx, info.sender.name)` or plain `ctx.sender.name` works; whole components work through `eval-content` (but without signals).
- `body` handed to `document`/`line-items` is already drawn, so themes may wrap it in `context`, `layout`, `block`, `columns`, ... freely.
- Users may wrap components in `block/pad/align/grid/...` (engine reconstructs wrappers, `engine.typ:131-223`, [E6] block ok) but **not** in `context`/`layout` (component vanishes, no error).

### 5.3 Themable page furniture is feasible **[E10]**

Prototype `e10-page-furniture.typ`: a `document` slot doing

```typ
let hdr = eval-content(ctx, header)   // header: (page, pages) => content with info.* motifs
set page(header: context hdr(here().page(), counter(page).final().first()), footer: ..., background: context if here().page() == 1 { ... })
```

renders "FIRST PAGE HEADER" on p.1, "CONT. Invoice INV-1 - Sender Corp" on p.2, footer "Sender Corp . IBAN ... . Total 279,51 EUR 2 / 2" on every page and a first-page-only background. So **page x/y, continuation headers and per-page backgrounds are all possible today if (and only if) the theme owns `set page` and calls function-valued furniture inside its own `context`**. Constraints:

- `set page` must be issued by `document` before any page content; root emits `pdf.attach` before calling `document` but this does not create a blank page (DIN + ZUGFeRD = 1 page [E5]).
- letter-pro owns `set page` in DIN-5008 (`letter-pro:132-195`) and hard-codes footer-on-page-1 and the numbering text; to theme this, invoice-pro must either pass `page-numbering`/own the footer or stop delegating `set page` to letter-pro.
- Anything per-page must come from Typst introspection (`here()`, `counter(page)`), never from loom ctx; loom adds no layout iterations of its own (pure function evaluation), Typst's normal <=5 introspection iterations apply (`counter(page).final()`).

---

## 6. ZUGFeRD / PDF metadata attachment

- **XML:** built and attached by **root.draw**: `pdf.attach("/factur-x.xml", build-zugferd-xml(ctx, view.item-data, view.payment-goal), relationship: "alternative", mime-type: "text/xml", ...)` (`src/components/root.typ:298-310`), _before_ `(ctx.theme.document)(ctx, body)` (`:312`) and outside of it. `build-zugferd-xml` (`src/zugferd/build.typ:649-...`) reads only `ctx.zugferd, sender, recipient, locale.currency, global.bank, invoice-nr, invoice-date` and further data keys plus the raw `item-data`/`payment-goal` signals - **never `ctx.theme`** (grep: no `theme` in `src/zugferd`). All inputs come from `measure`, which themes cannot influence. Verified: `blank`, `DIN-5008` and a custom `document` that wraps the body in a `block` all produce a PDF/A-3b with `factur-x.xml` and `/AFRelationship /Alternative` **[E5]**.
- **PDF metadata:** `set document(title, author, date, description, keywords)` is issued by the **DIN-5008 theme** (`src/themes/DIN-5008/document.typ:66-78`), not by root. Consequences measured in the XMP **[E5]**:
  - `blank` / any custom theme: **no `dc:title`, no author, no keywords, and `xmp:CreateDate` = compile time** instead of the invoice date (non-reproducible builds, poor archive metadata). Typst still accepts `--pdf-standard a-3b` without a title.
  - A theme can overwrite it (`set document(title: "Theme Title")` works at top level of `document`), and `set document` inside a container fails with `document set rules are not allowed inside of containers` -> a careless theme can break compilation or metadata.
  - `dc:language` is correct for every theme because root sets `text.lang/region` (`root.typ:158`).
- **Can themes interfere with e-invoicing?** Not with the XML payload. They can (a) drop/alter PDF metadata, (b) omit legally required visible content (legal notes, totals, bank data - the _visual_ part of a hybrid invoice must match the XML), (c) render components via `eval-content`, whose signals are then missing from the XML. Recommendation for designers: move `set document` and the "what must be shown" decisions out of themes; keep themes to "how it looks".
- Not theme-related but worth knowing: Typst cannot emit the Factur-X XMP extension schema (`fx:` - none found in any output [E5]).

---

## 7. Extension points, constraints and risks

### 7.1 Extension points that exist

1. `invoice.typ:290-320` `inputs` - the single place where root ctx keys are seeded (a `tokens`/`style` key, theme-provided defaults for `show-column`, etc. would go here). The theme is evaluated before `weave` (`:180`), so its result can contribute to `inputs`.
2. `ctx` cascade + `apply`/custom scope motifs (section 4) - per-subtree overrides with established `derive` semantics.
3. Slot functions `(ctx, view[, body]) => content` with full read access to ctx (locale strings/formatters, sender/recipient, totals).
4. `eval-content(ctx, content | function)` - lets theme parameters be _user content with `info._` motifs\*, incl. function-valued per-page furniture [E10].
5. The generic line-items renderer's layered API (`src/themes/components/line-items/line-items.typ:6-67`): ~25 style scalars (colors, sizes, strokes, insets, widths, aligns), structural options (`column-order`, `description-colspan`, `header-repeat`, `tax-suffix-style`), 16 callbacks (`render-title, render-description, render-modifier, render-header, render-table-footer, render-tax-suffix, totals-cell-wrapper, render-totals-body, render-subtotal, render-total-net, render-total-gross, render-discount, render-surcharge, render-tax, render-prepayment, render-amount-due`). This is effectively a private token set + part-renderers, but: only 2 of ~55 parameters are exposed publicly (`color-row-odd/even`, `src/themes/DIN-5008/din-5008.typ:13-14`, `:32-35`); parameters are threaded by hand through 3 layers (each default repeated up to 3x with **conflicting values**, e.g. `color-row-odd` default `rgb("e2e8f0")` in `line-items.typ:13`/`table.typ:147` but `none` in `base-theme/line-items.typ:9` and `din-5008.typ:13`); callbacks get two **different `styles` dicts** (`table.typ:225-248` vs `totals.typ:329-342`); `render-tax-suffix` is called with the column key when custom but with the style type when default (`table.typ:264-274`); `auto` and `none` both mean "default" in totals (`totals.typ:345-401`).
6. loom per-component lifecycle: scope (both passes) -> children -> measure (both passes) -> draw (draw pass only).
7. Public helper idiom to copy: builder functions returning `ctx => value` closures (`src/logic/references.typ:1-11`), evaluated late by root (`src/components/root.typ:200-210`) - the package's established way to make user config ctx-aware (locale-aware labels etc.).

### 7.2 Constraints a theming API must respect

- **Themes are draw-only.** No signals, no influence on measure; keep it that way (ZUGFeRD safety). Anything that changes _what_ is shown for legal reasons must be decided in measure/view, not in a theme.
- **`max-passes: 2`:** children see `global` from the measure pass (one hop stale, e.g. `global.bank.payment-amount == 0` [E1]); only `document`/footer see fresh values. Theme features that need document-wide facts (e.g. "is there a bank-details component?", "how many groups?") must get them from root.draw's ctx or from view, not by adding new feedback loops; raising `max-passes` doubles measure cost and activates the (so far never exercised) convergence logic.
- **`ensure` treats `none` as missing** (`loom:lib/mutator.typ:149`) and **`nest` silently resets non-dicts** (`:86`): `none` cannot be a valid slot/token value under the current mutators, and a wrongly-typed `theme` degrades silently. A new API needs explicit normalisation + validation at `invoice()` and at scope time (the package has `types.require` + `display-matcher` for good messages).
- **Motifs are version-keyed**: `loom-key = <invoice-pro:0.4.2>` (`src/loom-wrapper.typ:3`). Motifs created by a _different_ copy/version of invoice-pro are invisible to the engine (inert metadata). Third-party theme packages must therefore be pure `(ctx, view) => content` functions/dicts and must not ship `info.*`/components from their own invoice-pro import - or the key must become version-independent.
- **ctx namespace is crowded** (section 1.4): reserve one key (or a `sys`-like sub-namespace) for theming.
- `set document` must stay at top level (not in containers) [E5]; `set page` must come first in `document`; `#show: invoice.with(...)` must itself be top-level.
- `intertwine` rebuilds wrapper elements generically (`loom:core/engine.typ:157-168`, `:180-196`, `:209-221`, positional-arg special cases only for `alignment, angle, dest, count`). An API that asks users to wrap components in exotic elements is fragile; `context`/`layout` wrappers make components disappear silently.
- `theme` must remain a zero-arg function for `invoice()` (`src/invoice.typ:106`, `:180`) unless that contract is deliberately changed; note the `blank` vs `DIN-5008()` call asymmetry.

### 7.3 Risks / bugs found while researching (relevant to the redesign)

| #   | Finding                                                                                                                           | Evidence                                                                                                  |
| --- | --------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| R1  | `base-theme` header/footer never render (scoped `set page` in `if`)                                                               | `src/themes/base-theme/base.typ:35-40`, [E2]                                                              |
| R2  | `line-items` missing-slot default prints "Line Items" silently                                                                    | `src/components/line-items.typ:131-133`, [E3c/d]                                                          |
| R3  | Non-dict `ctx.theme` silently becomes `(:)`; `theme: themes.DIN-5008` (un-called) passes the type check                           | `loom:lib/mutator.typ:86`, `src/invoice.typ:106`, [E7]                                                    |
| R4  | `apply(theme: partial)` drops all other slots (shallow merge)                                                                     | `src/loom-wrapper.typ:19`, [E3a-c]                                                                        |
| R5  | Function-valued footer crashes DIN-5008                                                                                           | `src/themes/DIN-5008/document.typ:157-159`, `letter-pro:190-192`, [E4]                                    |
| R6  | PDF metadata owned by DIN theme only; others get no title/author and a compile-time date                                          | `src/themes/DIN-5008/document.typ:72-78`, [E5]                                                            |
| R7  | Legal notes + EPC-QR/IBAN logic live in theme renderers; custom slot = silently lost compliance features                          | `src/themes/components/line-items/global-info.typ:29-154`, `src/themes/base-theme/bank-details.typ:13-29` |
| R8  | Page numbering text hard-coded de/en in letter-pro, not locale-driven, not configurable through invoice-pro                       | `letter-pro:174-188`                                                                                      |
| R9  | No continuation header; footer page-1 only; item rows can split across pages                                                      | `letter-pro:190-192`, [E4]                                                                                |
| R10 | Theme receives only formatted strings; raw `public` discarded in every draw                                                       | `src/components/line-items.typ:500`, `bank-details.typ:143`, `payment-goal.typ:55`, `signature.typ:42`    |
| R11 | `bank-details(account-holder-text:)` declared, never used                                                                         | `src/components/bank-details.typ:43`                                                                      |
| R12 | `info.total.due` / `info.total.prepaid` render nothing                                                                            | `src/components/dynamic.typ:281-293`, [E8]                                                                |
| R13 | Styling inside locale strings (`*#sum*`)                                                                                          | `src/locale/lang/en.typ:127-130`                                                                          |
| R14 | Placeholder strings like `#recipient.address` printed into real invoices                                                          | `src/components/root.typ:19-27`, `:38-46`, [E7 png]                                                       |
| R15 | loom `weave(observer:)` path has a typo (`engine.interwine`) - observers unusable, do not build on them                           | `loom:core/runtime.typ:116-117`                                                                           |
| R16 | Docs promise "blank applies zero visual formatting", but blank uses the full default line-items styling (zebra `e2e8f0`, colours) | `docs/docs/api-reference/theme.md:66`, `src/themes/base-theme/line-items.typ:5-39`                        |

---

## 8. Experiment index

| ID  | File (under `.../scratchpad/proto/component-contract/`)    | Question                                                           | Result                                  |
| --- | ---------------------------------------------------------- | ------------------------------------------------------------------ | --------------------------------------- |
| E1  | `e1-ctx-dump.typ` (`typst query ... "<dump>"` / `"<val>"`) | ctx keys/types per slot; view shapes                               | section 1, 2                            |
| E2  | `e2-base-header-footer.typ`                                | does `blank.with(header:, footer:)` render?                        | no (R1); blank renders no address/title |
| E3  | `e3-apply-theme.typ` (`--input variant=...`)               | `apply(theme: ...)` in 6 shapes                                    | section 4.2                             |
| E4  | `e4-din-footer.typ`                                        | DIN footer ctx, motifs in `context`, function footer, page 2       | section 5, R5, R9                       |
| E5  | `e5-zugferd.typ` (`--pdf-standard a-3b`)                   | attachment + XMP per theme                                         | section 6                               |
| E6  | `e6-theme-returns-motifs.typ`                              | motifs returned by slots / wrapped in block, context, layout       | section 5.2                             |
| E7  | `e7-theme-arg.typ`                                         | `theme:` argument shapes, `none` slot, `.with` override            | section 2.1, 2.4, 4.4                   |
| E8  | `e8-info-total.typ`                                        | `info.total.due/prepaid`                                           | R12                                     |
| E9  | `e9-scoped-tokens.typ`                                     | scoped tokens + deep-merged slot overrides via a motif             | works, section 4.3                      |
| E10 | `e10-page-furniture.typ`                                   | per-page header/footer/background mixing ctx data and page numbers | works, section 5.3                      |
