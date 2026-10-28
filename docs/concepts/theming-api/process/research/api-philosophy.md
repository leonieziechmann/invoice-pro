# API Design Philosophy of invoice-pro (ground truth for the Theming API)

Researcher focus: distil how the _finished_ APIs (locale, tax, unit, references, country, info, components) are designed, so the theming API can feel native.
All paths are relative to `<repo>/` unless absolute. Loom = `%LOCALAPPDATA%/typst/packages/preview/loom/0.1.1`.
Every behavioural claim marked **[verified]** was compiled with typst 0.15.1 against the proto copy; prototype files are listed in section 7.

---

## 0. Executive summary (read this first)

1. **The dominant idiom is "a configurable thing is a _function_ that the engine calls late".** Locales are `(..overrides, base-lang, base-region) => dictionary` (`src/locale/factory.typ:37-38`), units are `(locale) => dictionary` (`src/logic/unit.typ:49-52`), reference signs are `(label:, value:) => (ctx => (title, value))` (`src/logic/references.typ:1-11`), countries are `(name:, code:, show-always:) => dictionary` (`src/logic/country.typ:238-242`). The user passes them **uncalled** (`locale: locale.en-de`, `unit: unit.hour`, `country: country.at`) and customizes with Typst's native **`.with(...)`**.
2. **Customization = base schema + cascading strict patches.** `base -> lang -> user patches` and `base -> region(lang) -> user patches`, folded with a depth-2 merge that is _supposed to_ panic on unknown keys (`src/locale/factory.typ:1-35, 52-63`).
3. **A patch DSL (`locale.custom.*`) emits namespaced patch dictionaries** with `auto` = "not set" (`src/locale/custom.typ:4-10`). The intended composition idiom is the same one loom's `mutator` uses: every helper returns a **one-element array** so helpers can be written one per line in a `{ ... }` code block and are auto-joined (`loom/src/lib/mutator.typ:104,110-128`).
4. **Surprise / latent bug [verified]:** the locale helpers use `return` _inside_ the wrapping `( {...}, )`, so they actually return a plain **dictionary**, not an array. In the documented block form (`docs/docs/api-reference/locale/index.md:55-60`) two dictionaries are joined with shallow `+`, so **all but the last `strings` patch are silently lost**. The variadic form works. The theming API should implement the _intended_ idiom, not the actual behaviour.
5. **Second latent bug [verified]:** the "invalid key" panic in `base-pull-deep-merge` calls `str(array)` (`factory.typ:27`), so users get `expected integer, float, ... found array` instead of the intended message. Unknown _groups_ and non-dictionary patches are silently ignored (`factory.typ:4, 8-13`).
6. **Themes are the outlier today:** `themes.DIN-5008()` must be _called_ (it is a factory returning `base-theme.with(...)`, `src/themes/DIN-5008/din-5008.typ:6-37`), `themes.blank` must _not_ be called (`src/themes/blank/blank.typ:3`), and passing `themes.DIN-5008` uncalled **silently renders an unstyled page** [verified], because loom's `nest("theme", ...)` replaces a non-dictionary with `(:)` (`loom/src/lib/mutator.typ:85-86`, `src/components/root.typ:71`).
7. Validation is uniform: `types.require(value, "scope::param", ..allowed)` first thing in every public function, producing `variable \`scope::param\`(repr) must be of a | b | c` (`src/utils/types.typ:5-24`). Themes already use the scope `theme::DIN-5008::form` (`din-5008.typ:19`) and slots use `theme::signature is not provided` (`src/components/signature.typ:31`).

---

## 1. Public surface map (what `#import "@preview/invoice-pro": *` gives you)

`src/lib.typ:1-25`:

| Line  | Export                                                                                                                                             | Kind                          | Notes                                                                                                                          |
| :---- | :------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------- | :----------------------------------------------------------------------------------------------------------------------------- |
| 1     | `invoice`                                                                                                                                          | function                      | root show-rule function                                                                                                        |
| 3     | `locale`                                                                                                                                           | **module namespace**          | `locale.<lang>-<region>`, `locale.custom`, `locale.lang`, `locale.region`, `locale.build-locale` (`src/locale/locale.typ:1-5`) |
| 4     | `themes`                                                                                                                                           | **module namespace (plural)** | `themes.blank`, `themes.DIN-5008` only (`src/themes/themes.typ:3-4`)                                                           |
| 6-16  | `line-items`, `item`, `discount`, `modifier`, `surcharge`, `prepayment`, `bundle`, `group`, `bank-details`, `payment-goal`, `signature`, `dynamic` | bare functions                | body components are _not_ namespaced                                                                                           |
| 18    | `apply`                                                                                                                                            | bare function                 | loom scoping primitive (`src/loom-wrapper.typ:18-22`)                                                                          |
| 20    | `tax`                                                                                                                                              | module namespace              | `public/tax/tax.typ` + `tax.special`                                                                                           |
| 21    | `date`                                                                                                                                             | bare helper                   | `#import "public/helper.typ": *` -> `date(d, m, y)` (`src/utils/helper.typ:1`)                                                 |
| 22-24 | `country`, `unit`, `references`                                                                                                                    | module namespaces             | curated re-exports                                                                                                             |
| 25    | `info`                                                                                                                                             | module namespace (aliased)    | `#import "public/info.typ" as info`                                                                                            |

Rule that emerges: **"verbs you write in the body" are bare functions; "values you pass to a parameter" live in a namespace named after that parameter** (`locale: locale.x`, `tax: tax.x`, `unit: unit.x`, `country: country.x`, `references: references.x`). The only exception is `theme: themes.x` (plural namespace, singular parameter).

**Public facade pattern.** `src/public/*.typ` files contain _only_ an import list that curates what is public; implementation lives in `src/logic/*` or `src/data/*`:

- `src/public/tax/tax.typ:1-5` re-exports 7 common constructors + `special` submodule.
- `src/public/tax/special.typ:1-19` re-exports the rare ones, grouped by comments ("margin schemes", "regional taxes", "special tax/duty scenarios").
- `src/public/unit.typ:1-11`, `src/public/references.typ:1-7`, `src/public/country.typ:1-4` same pattern.
- Internal helpers (`to-tax`, `to-tax-key`, `tax-category-db`, `make-country`, `resolve-country`, `normalize-party`, `resolve`, `make-unit`) are deliberately _not_ re-exported.

---

## 2. Design principles (with evidence)

### P1. Namespaces are Typst modules, exposed by bare `#import "path.typ"` in `lib.typ`; the facade curates

Evidence: `src/lib.typ:3-4,20,22-25`; facade lists above. Submodules are used for progressive disclosure: `tax.vat(...)` (common) vs `tax.special.margin-art(...)` (rare) - `src/public/tax/tax.typ:5`, docs `docs/docs/api-reference/tax.md:46-50` ("For less common scenarios ... the module provides a `special` submodule").

Implication for themes: `themes.<preset>`, `themes.custom.*` (patch DSL), optionally `themes.build-theme`, and "rare" things pushed into a submodule rather than flattening everything into `themes`.

### P2. Configurable things are _lazy functions_; the engine supplies the missing context

| API               | Shape                                                 | Who calls it, with what                                         | Evidence                                                                           |
| :---------------- | :---------------------------------------------------- | :-------------------------------------------------------------- | :--------------------------------------------------------------------------------- |
| locale            | `(..overrides, base-lang, base-region) => dict`       | `invoice`: `locale(base-language, base-region)`                 | `src/locale/factory.typ:37-38`, `src/invoice.typ:181`                              |
| unit              | `(locale) => (code, name, display)`                   | `item`/`bundle` via `unit-logic.resolve(unit, ctx.locale, ...)` | `src/logic/unit.typ:47-52,182-193`, `src/components/item.typ:180-188`              |
| reference sign    | `(label: auto, value: auto) => (ctx => (title, val))` | `root` draw pass: `closure(eval-ctx)`                           | `src/logic/references.typ:1-11`, `src/components/root.typ:200-210`                 |
| country           | `(name:, code:, show-always:) => dict`                | `resolve-country`: `country-opt()`                              | `src/logic/country.typ:238-242,488-491`                                            |
| region (internal) | `(lang) => dict`                                      | factory: `region(final-lang)`                                   | `src/locale/region/de.typ:3`, `src/locale/factory.typ:59`                          |
| theme (today)     | `() => dict of slot renderers`                        | `invoice`: `theme()`                                            | `src/invoice.typ:180`, `src/themes/base-theme/base.typ:8-50`                       |
| locale strings    | `(sum, deadline) => content` inside the dict          | theme renderer                                                  | `src/locale/lang/base.typ:145-148`, `src/themes/base-theme/payment-goal.typ:13-23` |

Why lazy? (a) **Dependency injection of the base schema by the running package version** - third-party locales built against v0.3 get new base keys for free: `docs/docs/api-reference/locale/custom.md:14` ("A custom locale developed for `v0.3` will work seamlessly in all future versions ... your locale will automatically fall back to the sensible defaults defined in the internal master schemas"). (b) It lets `.with(...)` be the universal customization hook (P3). (c) The region receives the _finished_ language so regional legal text can reuse translated strings (`src/locale/region/de.typ:9-11`: `lang.errors.ambiguous-tax`).

Note the asymmetry: the theme function currently receives **no** injected base (`theme()` with zero args), so it cannot benefit from (a).

### P3. `.with(...)` is the one customization verb

- Locale: `locale.en-de.with(locale.custom.document(invoice: "Proforma Invoice"))` - `docs/docs/api-reference/locale/index.md:55-60,108-113`.
- Country: `country.de.with(name: "Allemagne")` - `docs/docs/api-reference/invoice/country.md:55-60`; tested in `tests/country/test.typ:11-12`.
- Theme slots (undocumented but used throughout tests): `themes.blank.with(document: (ctx, body) => ...)` - `tests/integration/references-defaults/test.typ:7`; `themes.blank.with(line-items: generic-render-line-items.with(render-subtotal: ...))` - `tests/issues/issue-41/test.typ:25-36`.
- Inside the theme code itself: `base-theme.with(document: letter-document(...), line-items: render-line-items.with(color-row-odd: ..., color-row-even: ...))` - `src/themes/DIN-5008/din-5008.typ:21-36`.
- `invoice.with(...)` as the show rule - `docs/docs/api-reference/invoice/index.md:10`.

`.with` chains and **later wins** [verified: `l2.with(custom.document(invoice: "Storno"))` overrides an earlier `document` patch while keeping the earlier `line-items` patch]. This works because positional args accumulate left-to-right into `..overrides` and are folded in order (`factory.typ:53-56`).

### P4. Base schema + cascading merge; users only state the delta

- `base-language` "serves as the structural template (schema) for all other language files" - `src/locale/lang/base.typ:19-22`.
- `base-region` "serves as the 'Master Schema' for all regional configurations" - `src/locale/region/base.typ:1-3`.
- Concrete regions state only deltas: `de.typ` returns just `meta`, `normalize.infer-tax`, `tax` (`src/locale/region/de.typ:29-44`); `ch.typ` additionally overrides `currency` and `format` (`src/locale/region/ch.typ:43-73`).
- Pipeline: `(lang, ..user-lang-patches).fold(base-lang, base-pull-deep-merge)` then `(region(final-lang), ..user-region-patches).fold(base-region, base-pull-deep-merge)` - `src/locale/factory.typ:52-63`.
- The docs name this **"Cascading deep-merge"** - `docs/docs/api-reference/locale/base.md:9`, `custom.md:14,28`.

Merge semantics (exactly): **depth 2 only**. For each _group_ present in base and in patch, `result.insert(group-key, base-group + patch-group)` (`factory.typ:31`). Values below depth 2 are replaced wholesale [verified: patching `units.hour` with `(singular: "hr")` drops `plural`].

### P5. Strictness is intended ("panic on unknown keys") - and enforced in two layers

1. Helper layer: named parameters give Typst-native strictness for free. `locale.custom.document(invoce: "x")` -> `error: unexpected argument: invoce` [verified].
2. Merge layer: `base-pull-deep-merge` "Panics if the patch contains keys not present in the base schema" (`factory.typ:1-2,18-29`), message format: `Invalid key '<k>' found in group '<g>'. Allowed keys: ...`.

Caveats (see section 5): layer 2 is broken by `str(array)`; unknown _groups_ are not checked; non-dict patches are filtered away silently (`factory.typ:43,49`).

### P6. The patch DSL: tiny named-argument helpers that emit namespaced patches (`locale.custom`)

Full reference in section 3. Key properties:

- One helper per schema _group_, helper name == group name (`document`, `address`, `reference`, `line-items`, `summary`, `global-info`, `bank-details`, `payment`, `signature`, `legal`, `errors`; `normalize`, `format`, `tax`).
- Every parameter defaults to `auto`; `_clean-auto` removes `auto` so "only the fields the user explicitly defined" are patched (`src/locale/custom.typ:1-10`).
- The emitted patch is wrapped in a **pipeline discriminator**: `(strings: (<group>: payload))` or `(region: (<group>: payload))` (`custom.typ:23,358`). The factory routes by that top-level key (`factory.typ:44,50`).
- Intended to be used with a scoped wildcard import inside a code block: `{ import locale.custom: *; document(...); line-items(...) }` (`docs/.../locale/index.md:55-60`). The scoped import avoids polluting the user's namespace even though helper names collide with package components (`line-items`, `signature`, `bank-details`, `tax`, `document`).

### P7. The "joined one-element array" block DSL (loom heritage)

Loom's mutator ops each return `(op,)` so they can be listed in a code block and auto-join into an array: `#let nest(key, sub-ops) = (_nest-op(key, sub-ops),)` (`loom/src/lib/mutator.typ:104`), `put(...) = _auto-nest(path.pos(), ((state, read) => {...},))` (`mutator.typ:110-128`). invoice-pro uses this everywhere:

```typst
scope: ctx => loom.mutator.batch(ctx, {
  import loom.mutator: *
  derive("sender", "name", name, default: "")
  nest("theme", { ensure("signature", (..) => panic("theme::signature is not provided")) })
})
```

(`src/components/signature.typ:21-33`.)

`locale.custom` copies the pattern syntactically - `#let document(invoice: auto) = ( { ...; return (strings: (document: payload)) }, )` (`custom.typ:20-25`) - and the factory is prepared for arrays: `overrides.pos().flatten().filter(p => type(p) == dictionary)` (`factory.typ:40-44`). This is unambiguous evidence of intent: **scoped `import x: *` + one call per line + automatic joining + `.flatten()` on the receiving side**.

### P8. Presets first, constructor underneath, raw data always accepted

- Tax: 22 named constructors delegate to one `new(rate:, category:, label:, grounds:)` (`src/data/tax.typ:64-74, 237-242`). Users may also pass a bare `19%` and the locale infers the object (`src/components/item.typ:213-220`, `src/locale/region/de.typ:5-26`).
- Units: builder functions + aliases; users may also pass `"h"`, content, or `(display:, code:)` (`src/components/item.typ:129-138`, `src/utils/types.typ:78-83`).
- References: `preset-b2b()`, `preset-b2g()`, `preset-project()`, `preset-din-5008()` are zero-arg functions returning arrays of builders (`src/logic/references.typ:406-448`); arrays may mix builders, presets and literal `(label, value)` tuples (`docs/.../references.md:143-158`); dictionaries map label -> value-or-builder (`references.md:160-171`).
- Countries: 29 presets over one `make-country(...)` builder (`src/logic/country.typ:135-234`); docs publish the resulting _dictionary schema_ so users can hand-roll one (`docs/.../country.md:64-75`).
- Locales: 30 presets from `build-locale(lang, region)` (`src/locale/locale.typ:7-47`); the factory is public for package authors (`custom.md:108-122`).
- Themes (today): `DIN-5008(...)` preset over `base-theme(...)`; `blank = base-theme` (`din-5008.typ:21`, `blank.typ:3`).

Every API documents **the dictionary the constructor produces** ("Unit Dictionary Schema" `unit.md:71-81`, "Country Dictionary Schema" `country.md:64-75`, tax keys `tax.md:91-96`, base schema `locale/base.md`). Data is transparent, not opaque.

### P9. Two tiers of customization, explicitly documented

- Tier 1 "tweak": `.with(locale.custom.*)` at the call site.
- Tier 2 "author": `build-locale(lang-dict, region-fn)` for reusable/publishable locales. `docs/.../locale/custom.md:9-11`: "it is highly discouraged to use `locale.<lang>-<region>.with(...)` to architect an entirely new custom language or region. Extensive runtime patching slows down compilation times."
- Third-party packaging is a first-class goal: `custom.md:124-134` shows `#import "@preview/invoice-pro-europe-east:0.1.0": pl-pl`.

### P10. Polymorphic inputs, normalized once, consumed as one shape

- `references`: `auto | none | function | dict | array` validated at `src/invoice.typ:120-133`, normalized to `(label, value)` pairs in `src/components/root.typ:212-280`.
- `tax`: `auto | none | ratio | dict` -> tax object (`src/data/tax.typ:46-62`, `item.typ:210-226`).
- `unit`: `none | auto | str | content | dict | function` (`item.typ:129-138`) -> `logic/unit.typ:182-227`.
- `address`/`name`: `str | content | array` (`src/utils/types.typ:105-110`), normalized into `name`, `name-inline`, `address-lines`, ... (`src/logic/country.typ:639-667`).
- `country`: `none | auto | function | dictionary` (`types.typ:127-132`).
- `locale`: `resolve-locale` accepts function _or_ already-evaluated dictionary (`src/logic/unit.typ:4-11`).
- `modifier`: dict | array | content containing `#discount(...)` motifs (`item.typ:155-165`, `45-69`).
- Coercion helpers are total and pass `auto`/`none` through: `to-decimal`, `to-ratio`, `to-text`, `to-string`, `to-date` (`src/utils/coercion.typ:3-54`).

The docs call the result **"Normalized data objects"** which "the selected visual theme then consumes" (`docs/docs/api-reference/index.md:40-42`). Themes never see raw user input.

### P11. `auto` vs `none` have fixed, distinct meanings

- **`auto` = "not specified -> inherit from context (cascade), else compute/default".** Implemented by loom `derive(key, value, default:)`: "If `value` is `auto`: uses the current state value. If current state is missing: uses `default`" (`loom/src/lib/mutator.typ:159-190`). Used for every cascading parameter: `derive("tax", tax, default: m-tax.zero())` (`src/components/line-items.typ:94`), `derive("description", description)` (`item.typ:172`). Also "fetch from context": `bank-details(name: auto)` -> sender name (`src/components/bank-details.typ:11,85`), `payment-amount: auto` -> amount due (`bank-details.typ:125-129`), `subject: auto` -> locale string (`src/invoice.typ:243`), reference `label: auto, value: auto` (`references.typ:1-11`), `show-column: (pos: auto, ...)` -> data-driven visibility (`line-items.typ:59-69, 419-453`).
- **In patch helpers `auto` = "leave untouched"** (`custom.typ:1-10`).
- **`none` = "explicitly nothing / off / hidden".** `bic: none` hides the row (`docs/.../components.md:24-26,33`), `label: none` -> "no label prefix is displayed" (`src/components/modifier.typ:13-17`), `references: none` -> no block, `color-row-even: none` disables striping (`docs/.../theme.md:33-34,53`), `zugferd: none`, `footer: none` (`base.typ:19`).
- In theme render options `auto` already means "use the built-in default renderer": `render-title: auto`, `render-header: auto`, ... (`src/themes/components/line-items/line-items.typ:38-66`).
- Validation lists the sentinel literals alongside types: `types.require(name, "bank-details::name", none, auto, str)` (`bank-details.typ:49`).

Because `_clean-auto` strips only `auto`, **`none` survives as a real patch value** [verified in the feasibility sketch: `colors(row-even: none)` overrides a colour with "off"].

### P12. Callable values inside dictionaries ("strings as functions")

Where grammar matters, a schema value is a function rather than a template string: `payment.text: (sum, deadline) => [...]`, `deadline-date: date => ...`, `deadline-days: days => ...` next to plain `deadline-soon: "upon receipt"` (`src/locale/lang/base.typ:142-165`); `global-info.tax-statement: (tax-text, rate, vat-tax) => [...]` (`base.typ:100-104`); all of `format.*` and `normalize.*` (`src/locale/region/base.typ:41-85`). Consumers call them with the parenthesized-field idiom `(pay-str.text)(...)`, `(format.currency)(view.total)` (`src/themes/base-theme/payment-goal.typ:13-23`). The signature is documented in a `/// -> (args) => ret` comment right above the key (`base.typ:143-144`, `region/base.typ:42-45`).

Theme slots already follow this: `document: (ctx, body) => content`, `line-items: (ctx, dictionary, content) => content`, `bank-details|payment-goal|signature: (ctx, dictionary) => content` (`src/themes/base-theme/base.typ:9-31`). Convention: **`ctx` is always the first argument**, then the normalized `view`, then `body` if any. Sub-renderers in the line-items component use `(ctx, value, styles) => ...` (`src/themes/components/line-items/totals.typ:5,15,25,39`).

### P13. Schema groups are nouns; keys are short; metadata lives in `meta`

Language groups: `meta, document, address, reference, line-items, summary, global-info, units, bank-details, payment, signature, legal, errors` (`lang/base.typ:22-187`). Region groups: `meta, currency, normalize, format, tax` (`region/base.typ:30-96`). Group names mirror the _component_ they serve (`line-items`, `bank-details`, `payment`, `signature`) - which is why helper names collide with component names and the scoped import is needed. Identity/standards data goes in `meta` (`lang: "en"` ISO 639-1, `region: "de"` ISO 3166-1) and even the error messages are localizable schema entries (`errors.*`, `lang/base.typ:180-186`).

The evaluated locale is _re-shaped_ into a flat consumer-facing dict: `(strings, format, normalize, currency, tax, meta, resolve-plural)` (`factory.typ:66-74`) [verified keys]. I.e. **authoring shape != consumption shape**; the factory owns the mapping.

### P14. Naming conventions

- kebab-case everywhere: parameters (`tax-exempt-small-biz`, `input-gross`, `base-quantity`, `show-column`), dict keys (`vat-id`, `post-code`, `decimals-fine`), functions (`build-locale`, `payment-goal`), string enums (`"basic-wl"`, `"exclusive"`).
- User-facing identifiers use the **`-nr` suffix** (`invoice-nr`, `customer-nr`, `order-nr`, `tax-nr`, `contract-nr`, `quote-nr`, `delivery-note-nr`, `preceding-invoice-nr`) and **`-id`** for standardized identifiers (`vat-id`, `item-id`) - `src/invoice.typ:53-84`, `public/references.typ:1-7`. Locale _string keys_ use the long `-number` form (`invoice-number`, `tax-number`) - `lang/base.typ:43-66` (see inconsistency I-7).
- Boolean toggles: `show-<thing>` (`show-column`, `show-total`, `show-information`, `show-reference`, `show-subtotal`, `show-always`) or bare nouns for decorations (`hole-mark`, `folding-marks`).
- Theme style tokens today: **`<category>-<role>`** prefix families: `color-row-odd`, `color-discount`, `size-subtitle`, `weight-bold`, `stroke-thin`, `stroke-header-top`; **`<region>-<property>`** for layout: `cell-inset`, `header-bg`, `totals-width`, `totals-align`; **`render-<part>`** for replaceable sub-renderers; `align-header`/`align-body`; `column-order` (`src/themes/components/line-items/line-items.typ:11-66`). Default implementations are exported as `default-render-<part>` (`totals.typ:5-191`) so users can wrap them (`tests/issues/issue-41/test.typ:27-34`).
- Factories: `build-<thing>` (`build-locale`), low-level constructors: `new` (tax, unit data) / `make-<thing>` (internal: `make-country`, `make-unit`, `make-formatters`).
- Presets: `preset-<name>` inside `references`; elsewhere presets are just the bare name (`tax.vat`, `country.de`, `locale.de-de`, `themes.DIN-5008`).
- Standard codes are kept verbatim/upper-case when they are the standard's own spelling: `DIN-5008`, form `"A"|"B"`, tax categories `"AE"`, unit codes `"HUR"`.
- Generous aliases where users think in different vocabularies: `hour|hours|h|hr|hrs`, `metre|meter|m` (`src/logic/unit.typ:78-125`); `info.date` = `info.invoice-date`, `info.get` = `info.dynamic` (`src/public/info.typ:4-10`); context fallbacks `po-nr`, `leitweg-id`, `offer-nr`, `clerk` (`references.typ:130-143,169-182,234-243,365`).
- Private names start with `_` (`_clean-auto`, `_to-content`, `_matcher`).

### P15. Validation style: `types.require` first, domain asserts second, legal panics last

- Signature: `require(value, value-name, ..types)`; builds `choice(..types)`, renders it with `display-matcher`, asserts (`src/utils/types.typ:5-24`).
- **Message format** [verified]: `assertion failed: variable \`invoice::theme\`("x") must be of function`; `variable \`theme::DIN-5008::form\`("C") must be of "A" | "B"`; `variable \`item::price\`(true) must be of auto | decimal | int | float | str`.
- **Path format**: `<function>::<param>`; themes are already scoped `theme::<Theme>::<param>` (`din-5008.typ:19`); nested locale functions are referred to as `locale::format::currency`, `locale::normalize::money` (`line-items.typ:114-127`, `item.typ:240-245`); missing theme slots as `theme::bank-details is not provided` (`bank-details.typ:97-99`).
- Reusable named unions live in `types.typ`: `decimal-like`, `ratio-like`, `text-like`, `date-like`, `tax-like`, `unit-like`, `country-like`, `polymorphic-text`, record schemas `tax-type`, `city-type`, `party-type` (`types.typ:26-142`). Suffix **`-like`** = "anything coercible to X", **`-type`** = exact record.
- Matcher vocabulary (loom): literal, type, tuple, record, `choice`, `many`, `dict`, `any`, `exact`, `instance`; record matching is non-strict unless `strict: true` (`loom/src/lib/matcher.typ:139-230`).
- Cross-field rules are plain `assert(..., message:)` right after the type checks: "You can only specify the price or the total not both..." (`item.typ:144-147`), "Cannot specify both 'reference' and 'text'" (`bank-details.typ:66-69`).
- Errors are **educational**: the 0% tax panic lists every valid constructor with its legal paragraph (`src/locale/region/de.typ:9-18`).
- Missing context is handled by _ensuring a panicking default function_ so the error fires only when the thing is actually used: `ensure("currency", (..) => panic("locale::format::currency is not provided"))` (`line-items.typ:120-122`).

### P16. Documentation comment style

In source: `///` doc comment per function ending with `/// -> <return type>`, and **per-parameter** `///` description + `/// -> type | type` _inside_ the parameter list, directly above each parameter (tidy-style):

```typst
/// Defines and renders the bank account information for payments.
///
/// -> content
#let bank-details(
  /// The name of the account holder. Defaults to the sender's name.
  /// -> auto | none | string
  name: auto,
```

(`src/components/bank-details.typ:5-11`; same in `invoice.typ:14-35`, `item.typ:71-92`, `base-theme/base.typ:8-31`.) Schema dictionaries document each key the same way (`lang/base.typ:24-28`, `region/base.typ:15-27`). The older `custom.typ` uses the argument-list style `/// - name (auto, str): e.g., ...` + `/// -> dictionary` (`custom.typ:17-20`) - both exist; the inline style is the newer/more common one.

In the docs site (Docusaurus): per-function tables `| Key | Type | Description |` with types in backticks joined by `\|` (`docs/.../components.md:28-38`); admonitions `:::info / :::tip / :::note / :::warning / :::danger`; a **controlled vocabulary in bold**: **Cascading**, **Normalized**, **Forward/Backward Calculation**, **Grounds** (`docs/docs/api-reference/index.md:32-50`, `theme.md:13`). Each page follows: one-paragraph purpose -> predefined things (table) -> example -> customizing -> schema tables. Every non-trivial code block must be registered and ideally tested (`docs/DOCUMENTATION.md:5-12`).

### P17. Context-driven rendering; components never draw themselves

Components compute in `scope`/`measure` and delegate drawing to the theme slot: `draw: (ctx, _, view, ..) => (ctx.theme.bank-details)(ctx, view)` (`bank-details.typ:143`), `(ctx.theme.line-items)(ctx, view, body)` (`line-items.typ:500`), `(ctx.theme.document)(ctx, body)` (`root.typ:312`). `ctx` carries `theme`, `locale`, `format`, parties, references, totals (`invoice.typ:290-320`). Because `theme` is just a ctx key, `apply(theme: ...)` can re-theme a subtree (documented as power-user feature, `docs/.../components.md:137-139`). Theme content (header/footer) may itself contain motifs and is evaluated with `eval-content(ctx, ...)` (`src/loom-wrapper.typ:24-34`, `base.typ:34-42`, `tests/integration/footer-dynamic/test.typ:6-20`).

### P18. Standards and legal compliance are encoded in the API vocabulary

UNTDID 5305 categories as constructor names (`data/tax.typ:3-40`), UN/ECE Rec 20 unit codes (`data/unit.typ:8-85`), ISO 3166/639/4217 in `meta`/`currency` (`region/base.typ:14-36`), EN 16931 BT numbers in docs (`references.md:81-96`), DIN 5008 as a theme. Defaults are the _legally safe_ choice and the API refuses ambiguity (0% tax panic). A theming API "for modern businesses" is expected to keep legally mandated elements un-removable-by-accident and to name things after the standard where one exists.

### P19. Backwards compatibility is handled additively

Deprecated top-level `tax-nr` still accepted, mutually exclusive with `sender.tax-nr`, panics with a migration hint when `zugferd` is on (`invoice.typ:37-39,185-197`). Context lookups accept legacy/alias keys. Forward-compat promise for locales (`custom.md:14`). The theme doc carries the only "unstable" warning in the reference (`theme.md:7-11`), i.e. v0.5.0 is the one chance to break `themes.DIN-5008(...)`.

---

## 3. The `locale.custom` patch DSL - complete reference

Source: `src/locale/custom.typ`. Every helper has the same body shape:

```typst
#let <group>(<key>: auto, ...) = (
  {
    let payload = _clean-auto((<key>: <key>, ...))
    return (<pipeline>: (<group>: payload))
  },
)
```

`_clean-auto(d)` (`custom.typ:4-10`) drops every pair whose value is `auto`.

### 3.1 Language helpers -> `(strings: (<group>: {...}))`

| Helper         | Line | Parameters (all `auto` by default)                                                                                                                                                                                                                                                                                                                                                                  | Emits                  | Value types |
| :------------- | :--- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------- | :---------- |
| `document`     | 20   | `invoice`                                                                                                                                                                                                                                                                                                                                                                                           | `strings.document`     | str         |
| `address`      | 31   | `recipient`, `sender`                                                                                                                                                                                                                                                                                                                                                                               | `strings.address`      | str         |
| `reference`    | 61   | `tax-number`, `invoice-number`, `vat-id`, `invoice-date`, `service-time`, `customer-number`, `buyer-reference`, `recipient-vat-id`, `recipient-tax-number`, `order-number`, `order-date`, `project`, `contract-number`, `quote-number`, `delivery-note-number`, `delivery-address`, `preceding-invoice-number`, `due-date`, `payment-reference`, `contact-person`, `contact-phone`, `contact-email` | `strings.reference`    | str         |
| `line-items`   | 129  | `position`, `description`, `quantity`, `unit-price`, `price`, `total`, `vat`, `net`, `gross`, `discount`, `surcharge`, `subtotal`                                                                                                                                                                                                                                                                   | `strings.line-items`   | str         |
| `summary`      | 170  | `sum`, `vat-tax`, `total`, `including`, `excluding`                                                                                                                                                                                                                                                                                                                                                 | `strings.summary`      | str         |
| `global-info`  | 194  | `tax-statement` (fn), `unit`, `quantity`, `date`                                                                                                                                                                                                                                                                                                                                                    | `strings.global-info`  | fn / str    |
| `bank-details` | 218  | `account-holder`, `bank`, `iban`, `bic`, `reference`                                                                                                                                                                                                                                                                                                                                                | `strings.bank-details` | str         |
| `payment`      | 243  | `text` (fn), `deadline-date` (fn), `deadline-days` (fn), `deadline-soon`                                                                                                                                                                                                                                                                                                                            | `strings.payment`      | fn / str    |
| `signature`    | 263  | `closing`                                                                                                                                                                                                                                                                                                                                                                                           | `strings.signature`    | str         |
| `legal`        | 273  | `vat-exemption`                                                                                                                                                                                                                                                                                                                                                                                     | `strings.legal`        | str         |
| `errors`       | 286  | `name-missing`, `address-missing`, `city-missing`, `ambiguous-tax`, `invalid-tax`                                                                                                                                                                                                                                                                                                                   | `strings.errors`       | str         |

### 3.2 Region helpers -> `(region: (<group>: {...}))`

| Helper      | Line | Parameters                                                       | Emits              | Value types                             |
| :---------- | :--- | :--------------------------------------------------------------- | :----------------- | :-------------------------------------- |
| `normalize` | 317  | `money`, `money-fine`, `infer-tax`                               | `region.normalize` | `(number) => number`, `(number) => tax` |
| `format`    | 341  | `percent`, `number`, `currency`, `currency-fine`, `date`, `time` | `region.format`    | `(x) => str`                            |
| `tax`       | 367  | `default-vat`, `small-enterprise-special-scheme`                 | `region.tax`       | tax object                              |

### 3.3 Schema groups with **no** helper (coverage drift)

- `strings.units` (`lang/base.typ:111-130`) - no helper.
- `strings.meta`, `region.meta`, `region.currency` (`region/base.typ:31-39`) - no helper (so changing `symbol` requires overriding three `format` functions, which is exactly what the docs example does, `locale/index.md:102-116`).
- `line-items(...)` lacks `prepayment` (`lang/base.typ:82` vs `custom.typ:129-142`); `summary(...)` lacks `prepayment`, `amount-due` (`lang/base.typ:92-93` vs `custom.typ:170-176`). These keys were added to the schema later (commit d3641f9) and the hand-enumerated helpers were not updated.
- `reference(...)` _does_ have `delivery-address` in the signature (`custom.typ:77`) but not in its doc comment (`custom.typ:38-60`); the docs table lists only 5 of its 22 parameters (`locale/index.md:79`).

Raw patches bypass the helpers and work for any group: `locale.de-de.with((strings: (document: (invoice: "RAW"))))` [verified].

### 3.4 How patches compose - actual behaviour [verified, `proto/api-philosophy/locale-custom.typ`]

| Form                                                                                                                             | Works?                             | Why                                                                                                                                                                                                        |
| :------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.with(custom.document(...), custom.line-items(...), custom.format(...))` (variadic)                                             | yes                                | each dict is its own positional arg; folded left to right                                                                                                                                                  |
| `.with(a).with(b)` (chained)                                                                                                     | yes, later wins per key            | positional args accumulate                                                                                                                                                                                 |
| `.with({ import locale.custom: *; document(...); format(...) })` (block, one `strings` + one `region` helper)                    | yes                                | the two dicts have different top-level keys, `+` keeps both                                                                                                                                                |
| `.with({ import locale.custom: *; document(...); line-items(...) })` (block, **two `strings` helpers - the documented example**) | **NO - first patch silently lost** | helpers return dicts (because of `return`), block joins dicts with shallow `+`, second `strings:` replaces the first. Result: `document.invoice` stays `"Invoice"`, `line-items.position` becomes `"Pos."` |
| raw dict `(strings: (...), region: (...))`                                                                                       | yes                                | same routing                                                                                                                                                                                               |
| string / number / anything else                                                                                                  | silently ignored                   | `.filter(p => type(p) == dictionary)`                                                                                                                                                                      |

`repr(locale.custom.document(invoice: "X"))` = `(strings: (document: (invoice: "X")))`, type `dictionary` [verified]. `locale.custom.document()` = `(strings: (document: (:)))` (harmless empty patch).

The documented block example is registered as untested: `docs/DOCUMENTATION.md:96` ("`locale-customize` ... ⚠️ Outdated version. Needs test"); no test in `tests/` uses `locale.custom` at all.

---

## 4. How a user customizes a locale end-to-end today

### 4.1 Mental model

```
base-language ──┐                      (master schema, English/neutral defaults)
lang.de ────────┤ fold(strict depth-2 merge)
user strings-patches ─┘──► final-lang ──► region.de(final-lang) ─┐
base-region ─────────────────────────────────────────────────────┤ fold
user region-patches ──────────────────────────────────────────────┘──► final-region
                                                                      │
     (strings, format, normalize, currency, tax, meta, resolve-plural) ◄┘  "Normalized" locale in ctx.locale
```

- **Cascading**: most specific wins, order = base -> shipped lang/region -> user patches in call order (`factory.typ:52-63`).
- **Lazy**: nothing is merged until `invoice` calls `locale(base-language, base-region)` (`invoice.typ:181`); `.with` only accumulates arguments.
- **Normalized**: the consumer (components, themes) only ever sees the flat evaluated dict via `ctx.locale.*` (`factory.typ:66-74`).
- Values may be functions (P12); patches can replace them with functions of the same signature.

### 4.2 Exact call syntax from the docs

Pick a preset (passed **uncalled**), `docs/.../locale/index.md:32-37`:

```typst
#show: invoice.with(
  locale: locale.en-de, // English language, German region
)
```

Tweak strings with the block DSL, `locale/index.md:51-63` (NB: broken for >1 strings helper, see 3.4):

```typst
#show: invoice.with(
  locale: locale.en-de.with({
    import locale.custom: *

    document(invoice: "Proforma Invoice")
    line-items(position: "Pos.", unit-price: "Price/Unit")
  }),
)
```

Tweak formatting with the variadic/qualified form, `locale/index.md:106-116`:

```typst
#show: invoice.with(
  locale: locale.de-de.with(
    locale.custom.format(
      currency: (val) => str(calc.round(val, digits: 2)) + " EUR",
      currency-fine: (val) => str(val) + " EUR"
    )
  ),
)
```

Author a whole locale (tier 2), `locale/custom.md:44-122`:

```typst
#let pl = (meta: (lang: "pl"), document: (invoice: "Faktura"), line-items: (position: "Lp.", ...))
#let region-pl = (lang) => (meta: (region: "pl"), format: (currency: (val) => ...), tax: (default-vat: data.tax.vat(23%)))
#let pl-pl = locale.build-locale(pl, region-pl)
// consumer:
#show: invoice.with(locale: pl-pl)
```

Inspect the schema: `docs/.../locale/base.md` documents every group/key/type of `base-language` and `base-region` as tables - the schema _is_ public API.

Scoped override inside the body (power user): `#apply(locale: ...)[...]` (`components.md:137-139`) - requires an _evaluated_ dict because it bypasses `invoice`'s evaluation.

---

## 5. Inconsistencies and defects the theming API should NOT copy

| #    | Finding                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Evidence                                                                                                         | Lesson                                                                                                                                                                   |
| :--- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I-1  | **Patch helpers return dicts, not one-element arrays** (`return` inside `( {...}, )`), so the documented block DSL silently drops patches.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `custom.typ:20-25`; [verified] section 3.4                                                                       | Build the array idiom _without_ `return`: `#let colors(..) = ((tokens: (colors: payload)),)`; add a docs test for the block form.                                        |
| I-2  | **Strict-merge panic is itself broken**: `str(base-sub-keys)` on an array -> users see `expected integer, float, decimal, version, bytes, label, type, or string, found array` at `factory.typ:27`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | [verified]                                                                                                       | Use `keys.join(", ")`/`repr`, and test the error path.                                                                                                                   |
| I-3  | **Strictness has holes**: unknown top-level groups and non-dict patches are silently ignored; merge is depth-2 only so nested dict values are replaced wholesale.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | `factory.typ:4,8-13,31,43`; [verified]                                                                           | Validate group names too; define merge depth deliberately (tokens like `margin: (left:, right:)` need depth-3 or per-key semantics).                                     |
| I-4  | **Three calling conventions for "the thing you pass"**: `locale.de-de` (uncalled, `.with` to customize), `themes.DIN-5008()` (must call; named args to customize), `themes.blank` (must not call; `.with` to customize). `tests/TESTING.md:228` even describes `themes.blank` as "a value, not a function" though it is a function.                                                                                                                                                                                                                                                                                                                                                                   | `invoice.typ:21,24`; `din-5008.typ:6`; `blank.typ:3`                                                             | One convention for every theme.                                                                                                                                          |
| I-5  | **Uncalled `themes.DIN-5008` fails silently**: passes `types.require(theme, "invoice::theme", function)`, `theme()` returns another function, loom `nest("theme", ..)` swaps the non-dict for `(:)`, document falls back to `(.., body) => body`, line items render the placeholder `[Line Items]`.                                                                                                                                                                                                                                                                                                                                                                                                   | `invoice.typ:106,180`; `root.typ:71`; `line-items.typ:131-133`; `mutator.typ:85-86`; [verified `uncalled-1.png`] | Validate the _evaluated_ theme (`types.require(eval-theme, "invoice::theme()", dictionary/record)`), or accept both conventions explicitly.                              |
| I-6  | **Hand-enumerated helpers drift from the schema** (missing `prepayment`, `amount-due`, `units`, `currency`; doc table lists 5/22 params).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | section 3.3                                                                                                      | Derive helpers/docs from the schema or add a coverage test (`helper params == base group keys`).                                                                         |
| I-7  | **`-nr` vs `-number`**: parameters and builders use `invoice-nr`, locale keys use `invoice-number`; `recipient-tax-nr` builder reads `reference.recipient-tax-number`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | `invoice.typ:53` vs `lang/base.typ:45`; `references.typ:157-160`                                                 | Pick one token vocabulary for theme keys and keep it identical across parameter names, schema keys and docs.                                                             |
| I-8  | **Docs reference non-existent API**: `tax.new` is documented (`tax.md:83-109`) but not exported (`public/tax/tax.typ:1-3`) [verified]; `themes.base` (`invoice/index.md:111`) does not exist [verified]; `locale.region.en` (`locale/base.md:256`) does not exist and a bare region function is passed where `build-locale` expects `(lang) => dict` [verified]; `import ...: locale, data` (`locale/custom.md:80`) - no `data` export; `country.gb` (`country.md:23`) not exported [verified]; `custom.typ:238` documents `payment.text` as `(sum, currency, deadline)` but the schema is `(sum, deadline)` (`lang/base.typ:145-148`); `lang/base.typ:144` comments 3 params for a 2-param function. | as cited                                                                                                         | Every theming doc snippet needs a `tests/docs/*` test (the project's own rule, `DOCUMENTATION.md:5-12`).                                                                 |
| I-9  | **References mixes called and uncalled builders**: arrays need `references.invoice-nr()`, dicts take `references.invoice-nr` uncalled; `root` distinguishes by _function identity against a hard-coded list_ (`root.typ:169-210`), so a user-defined builder or a `.with(label: ..)`-customized builder takes a different code path (`fn(eval-ctx)`), and `references.order-nr.with(label: "PO")` gets called with `ctx` as a positional arg -> `error: unexpected argument` at `root.typ:208` [verified, `e4.typ`]. So here `.with` - the package's universal customization verb - does _not_ work.                                                                                                  | `references.md:143-171`; `root.typ:200-210`                                                                      | Do not dispatch on function identity; use a tagged value or a single convention.                                                                                         |
| I-10 | **Duplicate implementations**: `to-string` exists in `coercion.typ:35-43`, `country.typ:143-151`, `DIN-5008/document.typ:7-18`; `resolve-plural` is copy-pasted in `lang/base.typ:1-17` and `lang/en.typ:2-18`; due-date/customer-nr fallback chains are duplicated between `references.typ` and `dynamic.typ:75-110`.                                                                                                                                                                                                                                                                                                                                                                                | as cited                                                                                                         | Centralize token resolution for themes in one place.                                                                                                                     |
| I-11 | **Latent forward-reference bug**: `to-tax` references `vat`, `exempt`, `zero` defined later in the file -> `unknown variable: zero` when `to-tax(none)` is hit [verified].                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `data/tax.typ:46-62`                                                                                             | Test every branch of polymorphic coercion.                                                                                                                               |
| I-12 | **`to-date` has a dead branch** (`value == auto` twice, second should be `none`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | `coercion.typ:51`                                                                                                | -                                                                                                                                                                        |
| I-13 | **Validation messages copy-pasted wrongly**: surcharge asserts with "discount::amount must be positive!" (`modifier.typ:215-218`); `modifier` passes the variable `description` itself as an allowed _pattern_ (`modifier.typ:36-43`); `payment-goal` says `locale::date` instead of `locale::format::date` (`payment-goal.typ:30`).                                                                                                                                                                                                                                                                                                                                                                  | as cited                                                                                                         | Generate the `scope::param` string mechanically where possible.                                                                                                          |
| I-14 | **Singular/plural namespace drift**: `themes` and `references` plural; `locale`, `tax`, `unit`, `country`, `info` singular. Parameter is `theme:`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `lib.typ:3-4,20-25`                                                                                              | Decide consciously (keeping `themes` is fine for back-compat, but new sub-namespaces should follow the singular majority, e.g. `themes.custom` mirrors `locale.custom`). |
| I-15 | **Style knobs are a flat list of ~55 named parameters** on one renderer and the DIN-5008 preset re-exposes only 2 of them (`color-row-odd/even`) by hand; defaults are duplicated in three places with _different values_ (`components/line-items/line-items.typ:13-14` odd=`e2e8f0`/even=`none` vs `base-theme/line-items.typ:9-10` odd=`none`/even=`e2e8f0`; `cell-inset` `(x: 0.4em)` vs `.4em`).                                                                                                                                                                                                                                                                                                  | `line-items.typ:6-66`; `base-theme/line-items.typ:5-38`; `din-5008.typ:13-14,32-35`                              | This is the core problem a schema+patch theming API solves: single source of defaults, no manual pass-through.                                                           |
| I-16 | `bank-details.qr-code: (:)` is an untyped free dict read with `.at(.., default:)` (`bank-details.typ:47,117-120`), `margin: (:)` likewise (`document.typ:52-57`) - unknown keys are silently ignored, unlike the locale philosophy.                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | as cited                                                                                                         | Apply the strict-key rule to nested option dicts.                                                                                                                        |
| I-17 | Doc-comment style is mixed (`/// - name (type): ...` in `custom.typ` vs inline `/// -> type` per param elsewhere); type spelled `string` in comments (`bank-details.typ:10`) but `str` in docs/validation.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `custom.typ:17-20` vs `bank-details.typ:9-11`                                                                    | Use the inline style + `str`.                                                                                                                                            |

---

## 6. INFERENCE - "if the theming API were designed by the same hand, it would..."

> Everything in this section is my extrapolation from sections 1-5, **not** existing code. A feasibility sketch of the mechanics compiles: `proto/api-philosophy/theme-analogy.typ` [verified].

**6.1 A theme would be a lazy function produced by a factory, passed uncalled.**
By analogy with `build-locale(lang, region) -> (..overrides, base-lang, base-region) => dict`:

```typst
// src/themes/themes.typ (inferred)
#let DIN-5008 = build-theme(din-5008-tokens, din-5008-slots)   // -> (..patches, base-theme) => dict
#let blank    = build-theme((:), (:))

// user
#show: invoice.with(theme: themes.DIN-5008)                     // like locale: locale.de-de
#show: invoice.with(theme: themes.DIN-5008.with(form: "B"))     // named options survive as named args
```

and `invoice` would evaluate `theme(base-theme)` exactly like `locale(base-language, base-region)` (`invoice.typ:180-181`), injecting the running version's master schema -> the same forward-compat promise the locale docs make (`custom.md:14`).

**Back-compat wrinkle:** README, template and all docs use the called form `themes.DIN-5008(form: "A")` (`README.md:44`, `template/invoice.typ:17`). The same hand kept deprecated `tax-nr` working (P19), so expect _both_ to be accepted: if the first evaluation returns a function, evaluate again; and validate that the final value is a dictionary to kill footgun I-5. (Open question Q1.)

**6.2 There would be a master schema `base-theme` dictionary, grouped by nouns, documented key by key like `locale/base.md`.**
Depth-2 groups in the style of `base-language`: design-token groups (`colors`, `fonts`/`text`, `sizes`, `strokes`, `spacing`/`insets`, `page`) + per-component groups named after the component they serve (`document`, `header`, `footer`, `line-items`, `totals`, `bank-details`, `payment-goal`, `signature`), plus `meta` (`name: "DIN-5008"`, maybe `version`). Existing flat knob names map naturally: `color-row-odd` -> `colors.row-odd` or `line-items.row-odd-fill`; `stroke-thin` -> `strokes.thin`; `size-total` -> `sizes.total`; `render-subtotal` -> `totals.render-subtotal` / slot. Values may be functions (P12) with `ctx` first: `(ctx, view) => content`, and cross-token derivations can be functions of the resolved theme the way `region(lang)` receives the final language.

**6.3 A `themes.custom` patch DSL mirroring `locale.custom`, one helper per group, all params `auto`.**

```typst
#show: invoice.with(
  theme: themes.DIN-5008.with(form: "B", {
    import themes.custom: *

    colors(primary: rgb("#0a3d62"), row-even: none)   // none = "off", auto = untouched
    fonts(body: "Inter", size: 9.5pt)
    line-items(column-order: ("quantity", "unit-price", "total-price"))
    footer[#info.sender.name · IBAN #info.iban]        // content slots evaluated with eval-content
    signature(render: (ctx, view) => [...])            // slot override, ctx-first
  }),
)
```

- Helpers return **one-element arrays** (no `return`) so the block form composes; factory does `.pos().flatten()` (already the locale factory's shape).
- Patches would be routed by a top-level discriminator the way `strings:`/`region:` are - e.g. `(tokens: (...))` vs `(slots: (...))` - only if there are genuinely two pipelines; otherwise a single pipeline is simpler.
- Variadic qualified form also valid: `themes.DIN-5008.with(themes.custom.colors(primary: blue))`.
- Chaining gives the "corporate design" story for free: `#let acme = themes.DIN-5008.with({...})` in a shared file/package, then `acme.with(themes.custom.colors(row-even: none))` per document [verified in sketch].
- Raw dict patches stay legal (transparent data, P8).

**6.4 Strict merge that actually works.** Unknown group _and_ unknown key panic with the house format, scoped like `theme::DIN-5008::form`: e.g. `theme::colors: unknown key 'primry'. Allowed keys: primary, muted, ...`. Per-value type checks via `types.require(v, "theme::colors::primary", color, gradient, none)` with new named unions in `types.typ` following the `-like`/`-type` suffix rule (`color-like`, `stroke-like`, `inset-like`, `slot-like = choice(none, content, function)`).

**6.5 Presets as bare names, options as named args, standards spelled verbatim.** `themes.DIN-5008`, `themes.blank`, plus further bare-name presets (the repo already hides four unexposed table styles: `render-line-items-elegant|vibrant|luxury|informational`, `src/themes/base-theme/line-items.typ:42,242,279,297`). Rare/advanced pieces go in a submodule like `tax.special` (e.g. `themes.components.*` / `themes.render.*` exposing `default-render-*` so users can wrap them as issue-41's test does).

**6.6 Two documented tiers.** Tier 1: `.with(themes.custom.*)`. Tier 2: `themes.build-theme(tokens, slots)` for agencies / Typst Universe packages, with the explicit note that heavy `.with` patching is discouraged for whole new themes (mirrors `custom.md:9-11`), and a worked "publish your own theme package" example mirroring "Europe East".

**6.7 Normalized consumption shape.** Components keep calling `(ctx.theme.<slot>)(ctx, view[, body])`; the factory maps the authoring schema to a flat consumer dict (as `build-locale` maps to `strings/format/...`), now also carrying resolved tokens (`ctx.theme.colors.primary`) so user content in header/footer and custom renderers can read the design tokens - and `info`-style accessors could expose them in body text.

**6.8 `auto`/`none` semantics carried over unchanged** (P11): helper param `auto` = untouched; token value `auto` = "engine decides / built-in renderer" (already true for `render-*: auto`); `none` = switched off (`hole-mark`-like booleans stay `bool`).

**6.9 Docs page would follow the house template:** purpose paragraph with the bold vocabulary (**Cascading**, **Normalized**), "Predefined Themes" table, "Customizing Themes" (`.with` + `themes.custom` block), "The `themes.custom` Module API" table (Function | Parameters | Description), separate pages `theme/custom.md` (authoring with `build-theme`) and `theme/base.md` (schema tables), every snippet registered in `DOCUMENTATION.md` with a `tests/docs/*` test.

---

## 7. Prototype / verification files

Directory: `<session>/proto/api-philosophy/`

| File                                         | What it proves                                                                                                                                      |
| :------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------- |
| `locale-custom.typ` -> `out-1.png`           | helper returns dict; documented block DSL loses first patch; variadic/chained/raw forms work; evaluated locale & theme keys                         |
| `errs.typ` -> `errs-1.png`                   | unknown group & non-dict patches silently ignored; depth-2 replacement; `themes.DIN-5008(...).with(signature: ..)` and `themes.blank.with(..)` work |
| `e1.typ` (loop)                              | real error texts of `types.require`, broken strict-merge panic, `unexpected argument`                                                               |
| `uncalled.typ` -> `uncalled-1.png`           | `theme: themes.DIN-5008` (no parens) compiles to an unstyled page with "Line Items" placeholder                                                     |
| `idiom.typ`                                  | one-element-array helpers without `return` join correctly in a code block                                                                           |
| `e2.typ`, `e3.typ`                           | `to-tax(none)` forward-reference error; `tax.new`, `themes.base`, `locale.region.en`, `country.gb` do not exist                                     |
| `theme-analogy.typ` -> `theme-analogy-1.png` | feasibility of `build-theme` + `themes.custom`-style block DSL + chaining + `none` as value + readable strict-merge errors                          |

---

## 8. Open questions for the designers / maintainer

1. Calling convention: may v0.5.0 break `themes.DIN-5008(form: "A")` in favour of the locale-style uncalled `themes.DIN-5008.with(form: "A")`, or must both be accepted?
2. Should the locale DSL bug (I-1) and the strict-merge panic bug (I-2) be fixed in the same release so that `locale.custom` and `themes.custom` share one merge/patch utility (e.g. a common `utils/patch.typ`)?
3. Merge depth for themes: locale's depth-2 is too shallow for values like `margin: (left:, right:)`, `inset: (x:, y:)`, stroke dicts. Deep-merge everything, or per-key "replace vs merge" semantics?
4. One pipeline or two (tokens vs slots), i.e. does the theme need the `strings:`/`region:`-style discriminator at all?
5. Should the theme factory receive the evaluated locale / ctx at evaluation time (as `region(lang)` does), e.g. for locale-dependent layout (DIN 5008 vs. Swiss/US window positions)?
6. Keep plural `themes` namespace (back-compat) - and is `themes.custom` the right name given `locale.custom`'s doc page for _authoring_ is confusingly also called "Custom Locales" (`locale/custom.md`) while the patch module is `locale.custom`?
