# Theming API - documented promises, maintainer intent, backwards-compat surface, user demand

Researcher focus: docs / tests / git history / GitHub issues. Repo state: `main` @ `a4d0586` (one commit after tag `v0.4.2`).
All `path:line` references are relative to `<repo>` unless stated otherwise.
Prototypes that back the "verified" claims live in `scratchpad/proto/docs-intent/` (t1..t7).

Web access status: GitHub issue pages and the GitHub REST API were reachable through WebFetch (content is summarised by a small model, so issue bodies below are paraphrases, not verbatim). `gh` CLI is not installed. The GitHub **Discussions** page is enabled but its list failed to load ("error while loading") - **no discussion content could be read; none is invented here**.

Correction to the task brief: `letter-pro` is **not** by the same author. `letter-pro/3.0.0/typst.toml` says `authors = ["Sematre"]`, repo `github.com/Sematre/typst-letter-pro`. It is a third-party dependency, which matters for section 5 (invoice-pro cannot change its behaviour).

---

## 0. TL;DR for designers

1. The _documented_ theme surface is tiny: `themes.DIN-5008(form, font, hole-mark, folding-marks, color-row-odd, color-row-even, margin)` and `themes.blank` passed un-called. Everything else (slots, `footer`, `render-*` hooks, `styles`) is undocumented.
2. The _tested_ surface is larger and is what really constrains a redesign: `themes.blank.with(document: (ctx, body) => ..)` (11 uses) and `themes.blank.with(line-items: (ctx, data, body) => ..)` (6 uses + 4 via `generic-render-line-items.with(render-*: ..)`), plus DIN-5008 `footer:` with `#info.*` motifs inside.
3. The docs explicitly reserve the right to break: "highly unstable ... finalized and locked in **v0.5.0**" (theme.md:10). The lock target already slipped once (v0.4 -> v0.5.0). v0.5.0 is therefore both the _permission_ to break and the _deadline_ after which breaking is no longer OK.
4. The public promise since v0.1.x is unchanged and still unfulfilled: "easy customization of accent colors and fonts to match corporate identities" (README.md:153). Docs additionally promise "multiple distinct visual designs out of the box" (intro.md:66) and "powerful and extendible" (intro.md:16).
5. The only open issue in the tracker is a theming issue: **#18 Footer** (every-page multi-column business footer). The maintainer tied it to the theming overhaul and shipped a self-described workaround (`footer:` on DIN-5008), which - verified - only renders on page 1.
6. Two latent bugs sit exactly where the new API must go: base-theme `header:`/`footer:` are dead parameters (verified), and `themes.DIN-5008` passed un-called compiles silently into an unstyled document (verified).
7. The maintainer already built, then hid, four style variants (`elegant`, `vibrant`, `luxury`, `informational`) on top of a ~50-parameter generic line-items renderer. They all still compile. This is the clearest signal of where she is steering: token/hook-driven generic components + named presets.

---

## 1. Every public promise about theming

### 1.1 Stability / versioning promises

| #   | Promise (short quote)                                                                                                                                                                                        | Where                                          |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| P1  | Theming API is "highly unstable"; "fully finalized and locked in **v0.5.0**"; "breaking changes to the rendering pipeline are expected"                                                                      | docs/docs/api-reference/theme.md:7-11          |
| P2  | README stability table: Theming = "**Under Construction** ... will most likely experience breaking changes in the next updates"                                                                              | README.md:103                                  |
| P3  | Same text is published on Typst Universe (README is the package page)                                                                                                                                        | https://typst.app/universe/package/invoice-pro |
| P4  | Invoice header args "Mostly Stable ... Future updates ... non-breaking ... adding new optional fields" - i.e. the `theme:` _argument of `invoice`_ is covered by a stronger promise than the theme internals | README.md:100                                  |
| P5  | Data model "Stable"                                                                                                                                                                                          | README.md:101                                  |

History of P1: versions 0.3.0-0.3.2 said "locked in **v0.4**" (docs/versioned_docs/version-0.3.2/api-reference/theme.md:10); from 0.4.0 on it says "v0.5.0" (changed in commit `ed7bd8a`, 2026-07-08). The theme page was otherwise byte-identical from 0.3.0 to 0.4.1 apart from the import version; 0.4.2 only added the two `color-row-*` rows + the info box (diff verified across all six snapshots).

### 1.2 Conceptual promises (the vocabulary designers must honour)

| #   | Promise                                                                                                                                                                                                          | Where                                |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| C1  | The theming engine "provides a **Cascading** approach to document styling"                                                                                                                                       | theme.md:13                          |
| C2  | Themes control "visual layout, typographic choices, and structural positioning of the underlying **Normalized** data objects"                                                                                    | theme.md:13                          |
| C3  | "Normalized Data & Theming": engine compiles inputs into "strictly **Normalized** data objects"; "the selected visual theme then consumes these standardized objects"                                            | api-reference/index.md:40-42         |
| C4  | Mutating internal state / the normalized pipeline directly is "unsupported"                                                                                                                                      | api-reference/index.md:44-46         |
| C5  | "Cascading Parameters": a value set higher up is inherited by descendants "unless explicitly overridden" - defined for `tax`/`input-gross`, but it is the package-wide meaning of the bold keyword **Cascading** | api-reference/index.md:32-34         |
| C6  | Architecture "completely decouples your data model from the visual representation"                                                                                                                               | intro.md:14                          |
| C7  | "the visual layout can be entirely swapped out without altering your business data"                                                                                                                              | intro.md:72                          |
| C8  | DIN 5008 "is merely a presentation layer. You can swap themes at any time"                                                                                                                                       | intro.md:75                          |
| C9  | Root settings "such as `theme`, `locale`, ..." are "aggressively **Normalized**"                                                                                                                                 | getting-started.md:90                |
| C10 | Themes module = "Visual layout configurations. Details how the theming engine receives and positions the final structured data on the page."                                                                     | api-reference/index.md:26            |
| C11 | Sender/recipient `extra` is "styled according to your theme"                                                                                                                                                     | api-reference/invoice/index.md:46    |
| C12 | Address lines: vertical layouts join with line breaks, horizontal layouts with commas (a data->theme contract: `address` vs `address-inline`)                                                                    | api-reference/invoice/index.md:57-60 |

Observation: C1 ("Cascading") is promised but **not implemented** for themes today. A theme is a flat dict of 5 functions + 2 content values; there is no inheritance of style values between document -> table -> row. The only cascade that exists is loom's ctx (`apply(theme: ..)`, see P-A below). A v0.5.0 concept must give "Cascading" a real meaning or the word has to leave the docs.

### 1.3 Feature promises / roadmap

| #   | Promise                                                                                                                              | Where                              |
| --- | ------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------- |
| F1  | Roadmap: "[ ] (WIP) **Theming Engine:** Allow easy customization of accent colors and fonts to match corporate identities."          | README.md:153, contributing.md:89  |
| F2  | Feature list: "DIN 5008 Compliant: Supports both Form A and Form B layouts natively via the flexible Theming API."                   | README.md:12                       |
| F3  | "Highly Customizable: ... visual themes to match your corporate identity."                                                           | README.md:18                       |
| F4  | README links to docs for "theming instructions"                                                                                      | README.md:22                       |
| F5  | "For the future a powerful and extendible theming engine is also planned."                                                           | intro.md:16                        |
| F6  | "Theming API (Planned): A powerful and extendible theming engine designed to allow multiple distinct visual designs out of the box." | intro.md:66                        |
| F7  | "Currently, the package ships with a `blank` theme for fully custom layouts and a standard `DIN-5008` implementation."               | theme.md:15                        |
| F8  | "The theming engine is currently undergoing expansion."                                                                              | api-reference/invoice/index.md:108 |

F1 has been on the roadmap unchanged since v0.1.1 (git show v0.1.1:README.md line 260). "(WIP)" was added on 2026-05-05 (`81b214f`).

### 1.4 Promises about the two shipped themes

DIN-5008 (theme.md:17-60)

- "default implementation out-of-the-box" (theme.md:19) - matches `theme: themes.DIN-5008()` default at src/invoice.typ:21.
- "ensuring that recipient addresses align perfectly with standardized window envelopes" (theme.md:19) - a hard layout guarantee any restyling must not break.
- Form A default, Form B by parameter (theme.md:22, 29).
- Parameter table theme.md:27-35 (see 2.1).
- Row fill semantics (theme.md:37-39): fill is per **line item**, not per physical row; description/discount/subtotal rows share the item's fill; page breaks do not shift alternation; header and totals are not affected.
- Example comment: "We configure the theme function and pass it to the invoice" (theme.md:48).

blank (theme.md:64-90)

- "absolute barebones architectural primitive"; "applies zero visual formatting"; "maps directly to the internal base layout structure" (theme.md:66).
- "applies strictly no document-level theming", so native `#set page(..)` _before_ `#show: invoice.with(..)` works (theme.md:68-72, example 76-90).
- Example passes it un-called: `theme: themes.blank, // Bypasses internal layout styles` (theme.md:84).

Caveat on "zero visual formatting": blank still renders the full default line-items table incl. the `e2e8f0` stripe, bank details, payment goal and signature via the base renderers (src/themes/base-theme/base.typ:22-31). "blank" really means "no _document_ slot" (no letterhead, no address block, no subject, no date, no references, no PDF metadata), not "unstyled".

### 1.5 Semi-public "power user" promise

- P-A: `apply` can "override deeper internal functions - such as temporarily changing the `locale`, `theme`, or formatting logic for a specific scope. However, this requires knowledge of the internal data structure" (components.md:138). **Verified working** (proto t4): `#apply(theme: (themes.blank.with(signature: ..))())[ #signature() ]` re-skins only the wrapped component. Note the user must pass the _evaluated dict_, not the theme function, because `apply` just does `ctx + args.named()` (src/loom-wrapper.typ:18-22). This is the only real "cascade" in the theme system today and it replaces the whole `ctx.theme` wholesale (no deep merge).

### 1.6 Documentation defects (promises that are simply wrong today)

| Defect                                                                                                                                                                            | Evidence                                                                                                        |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `themes.base` is documented as the second available theme; it does not exist (exports are `blank`, `DIN-5008`)                                                                    | docs/docs/api-reference/invoice/index.md:111 vs src/themes/themes.typ:3-4. Wrong in every snapshot since 0.3.0. |
| TESTING.md says "`themes.blank` is a value, not a function" - it _is_ a function (`#let blank = base-theme`), which is exactly why it passes `types.require(theme, .., function)` | tests/TESTING.md:228 vs src/themes/blank/blank.typ:3, src/invoice.typ:106                                       |
| v0.4.2 GitHub release notes advertise a `color-header` option on DIN-5008; no such parameter exists anywhere in `src` (grep: 0 hits)                                              | https://github.com/leonieziechmann/invoice-pro/releases                                                         |
| `footer` parameter of DIN-5008 is shipped (0.4.0), announced in release notes and in issue #18, tested - but missing from the parameter table                                     | src/themes/DIN-5008/din-5008.typ:17 vs theme.md:27-35                                                           |
| invoice/index.md `references` type omits `auto`/`function` - not theming, but shows the docs lag the code; the repo rule is "take syntax from the test"                           | invoice/index.md:30 vs src/invoice.typ:49-50                                                                    |

---

## 2. Backwards-compatibility surface

Legend: **DOC** = in published docs, **TEST** = exercised by a tytanic test, **TPL** = in the Universe template / README (copied into every user project by `typst init`), **INT** = internal path but relied on by tests.

### 2.1 The `invoice(theme: ..)` contract

- `theme` must be a **function**: `types.require(theme, "invoice::theme", function)` (src/invoice.typ:106). Documented type: `function` (invoice/index.md:23; src/invoice.typ:19-21 docstring).
- It is called with **zero arguments**: `let eval-theme = theme()` (src/invoice.typ:180) and the result is put into loom inputs as `theme:` (src/invoice.typ:291).
- Contrast with locale, the sibling API: `locale(base-language, base-region)` (src/invoice.typ:181) - the locale function _receives the base to merge into_; the theme function receives nothing. (See 5.3.)
- Default: `themes.DIN-5008()` (src/invoice.typ:21). **TPL/DOC**: most docs examples omit `theme:` entirely and rely on this default (intro.md:27-41, index.md:61-65, getting-started) - so the default's _look_ is itself a compat surface guarded by ~20 visual refs.

Verified behaviours of wrong usage (proto t3a/t3b/t3c):

- `theme: themes.blank()` (called) -> clear assertion error "variable `invoice::theme`(...) must be of function". Good.
- `theme: themes.DIN-5008` (NOT called) -> **compiles without any error and renders an unstyled page**. `theme()` returns `base-theme.with(..)` (a function), root's `ensure("theme", "document", ..)` (src/components/root.typ:71) silently papers over it. This asymmetry ("blank must not be called, DIN-5008 must be called") is the number-one footgun of the current API and is never explained in the docs.
- A hand-written theme `() => (document: (ctx, body) => ..)` works; missing slots fall back: `line-items` -> literal text "Line Items" (src/components/line-items.typ:131-133), `bank-details`/`payment-goal`/`signature` -> panic "theme::X is not provided" (src/components/bank-details.typ:96-100, payment-goal.typ:34-38, signature.typ:30-32).

### 2.2 `themes.DIN-5008(..)` - named parameters

Source: src/themes/DIN-5008/din-5008.typ:6-18.

| Param            | Default                                                                        | Status                                                                                                       | Used in                                                                                                                                                     |
| ---------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `form`           | `"A"`                                                                          | DOC TEST TPL; the only validated param (`types.require`, din-5008.typ:19)                                    | README.md:44, template/invoice.typ:17, theme.md:50, tests/integration/features-complex, group, docs/readme-getting-started, docs/api-theme-din5008          |
| `font`           | `"Liberation Sans"`                                                            | DOC TEST                                                                                                     | 13+ tests pass `font: "libertinus serif"` (CI determinism convention, tests/TESTING.md:198; commit `34ce3e4` "fixed font warning"); also e-invoicing.md:178 |
| `hole-mark`      | `true`                                                                         | DOC TEST                                                                                                     | theme.md:52, tests/docs/api-theme-din5008                                                                                                                   |
| `folding-marks`  | `true`                                                                         | DOC                                                                                                          | theme.md:32                                                                                                                                                 |
| `color-row-odd`  | `none`                                                                         | DOC TEST (since 0.4.2, external PR #36)                                                                      | tests/integration/row-colors-custom                                                                                                                         |
| `color-row-even` | `rgb("e2e8f0")`                                                                | DOC TEST                                                                                                     | theme.md:53, tests/integration/row-colors-custom, row-colors-none                                                                                           |
| `margin`         | `(:)` (left 25mm, right 20mm, top/bottom 20mm filled in at document.typ:52-57) | DOC                                                                                                          | theme.md:35                                                                                                                                                 |
| `footer`         | `none`                                                                         | **undocumented**, TEST, announced in release notes v0.4.0/v0.4.1 and in issue #18 as the official workaround | tests/integration/footer-dynamic/test.typ:6-20                                                                                                              |

Contract details behind `footer` that a migration must keep or consciously replace:

- accepts content containing loom motifs (`#info.sender.name`, `#info.iban`, `#info.total.gross`, `#info.due-date` ...) which are woven against the root ctx via `eval-content` (src/loom-wrapper.typ:24-34; src/themes/DIN-5008/document.typ:157-159; commit `23788cb`). The v0.4.1 release notes sell this as "dynamic values ... resolve directly in custom footers".
- **verified (proto t2): the footer renders on page 1 only** - letter-pro does `if current-page == 1 { footer }` (letter-pro/3.0.0/src/lib.typ, inside `letter-generic`'s `set page(footer: ..)`). Page >= 2 only gets "Seite x von y". Issue #18 explicitly asks for "every invoice page".

Return value: `base-theme.with(document: .., line-items: ..)` (din-5008.typ:21-36), i.e. a partially applied function. **Verified (proto t3d)**: users can already chain `themes.DIN-5008(..).with(signature: (ctx, view) => ..)` to replace single slots of a configured theme. Undocumented, untested, but it works today and is the natural thing a power user would try.

### 2.3 `themes.blank` / base-theme slots

`themes.blank` **is** `base-theme` (src/themes/blank/blank.typ:3). Slots (src/themes/base-theme/base.typ:8-32):

| Slot           | Signature (from docstrings)                | Status                                                                                                                                                             |
| -------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `document`     | `(ctx, body) => content`                   | **TEST x11** - tests/integration/references-defaults (5), references-presets (6) use it as an assertion hook on `ctx.references`                                   |
| `line-items`   | `(ctx, data, body) => content`             | **TEST x6** direct (tests/integration/tax-exemption-grounds asserts on `data.taxes[].category/.marker/.grounds`) + x4 via generic renderer (issue-39 x3, issue-41) |
| `bank-details` | `(ctx, view) => content`                   | unit test calls `render-bank-details(ctx, view)` directly with a hand-made ctx containing only `locale` (tests/unit/test.typ:714-758) **INT**                      |
| `payment-goal` | `(ctx, view) => content`                   | untested directly                                                                                                                                                  |
| `signature`    | `(ctx, view) => content`                   | untested directly (verified working, proto t3d/t4)                                                                                                                 |
| `header`       | content, "Can include motifs/active items" | **dead - verified (proto t1)**: not rendered                                                                                                                       |
| `footer`       | content                                    | **dead - verified (proto t1)**: not rendered                                                                                                                       |

Why header/footer are dead: base.typ:35-40 puts `set page(header: ..)` inside `if .. { }` blocks; a Typst `set` rule is scoped to its enclosing block, so it never reaches `document(ctx, body)` on line 41. Introduced in `23788cb` (2026-08-14); before that the two values were merely stored in the dict and never consumed. They have **never worked in any release**, so there is no compat obligation - but the docstring (base.typ:12-19) records the maintainer's intent: header/footer are _content evaluated by the weave loop that may contain motifs_.

Usage count of blank in tests: `themes.blank` un-called x19, `themes.blank.with(` x16 (grep over tests/\*_/_.typ). It is the mandated theme for every data/unit/issue test (tests/TESTING.md:163, 228, 281, 298; .agents/skills/create-unit-test/SKILL.md:39-52). Breaking `theme: themes.blank` would touch ~25 test files and the docs example theme.md:84 / tests/docs/api-theme-blank.

### 2.4 Internal paths that tests import (INT)

- `/src/themes/components/line-items/line-items.typ` : `render-line-items` (generic) with hooks `render-totals-body: (ctx, data, styles, elements) => ..`, `render-subtotal` / `render-total-net: (ctx, value, styles) => (label, value)` - tests/issues/issue-39/test.typ:12-31, tests/issues/issue-41/test.typ:11-36.
- `/src/themes/components/line-items/totals.typ` : `default-render-subtotal`, `default-render-total-net` - tests/issues/issue-41/test.typ:14, 28, 32 (the "call the default, then decorate" pattern; the hidden `elegant` variant uses the same pattern, src/themes/base-theme/line-items.typ:67-78).
- `/src/themes/base-theme/bank-details.typ` : `render-bank-details` - tests/unit/test.typ:714.

None of these are exported from `src/lib.typ` (lib.typ:1-25 only exports the `themes` module = `blank` + `DIN-5008`). So a _package user_ cannot reach the generic renderer or its ~50 knobs at all today (`@preview/...` imports cannot address internal files in a supported way). Issue #33 confirms the pain: the reporter's only workaround for disabling stripes was a "modified copy of `render-line-items`" fed through base-theme's `line-items` slot.

The generic renderer's parameter list (src/themes/components/line-items/line-items.typ:6-67) is effectively a draft token/hook vocabulary: 7 colours, 3 sizes, 1 weight, 3 strokes, 4 insets, 4 totals-layout values, `column-order`, `description-colspan`, header bg/colour/repeat/strokes, `tax-suffix-style`, `align-header/body`, and 15 `render-*` hooks. Naming convention already in place: `color-*`, `size-*`, `weight-*`, `stroke-*`, `*-inset`, `totals-*`, `render-*`, `align-*`.
Inconsistency to fix: generic defaults are `color-row-odd: e2e8f0, color-row-even: none` (line-items.typ:13-14) while the base-theme wrapper and DIN-5008 publish the inverse (`odd: none, even: e2e8f0`, base-theme/line-items.typ:9-10, din-5008.typ:13-14). The _documented_ one (theme.md:33-34) is the inverse.

### 2.5 Things the DIN-5008 document slot does that are not "style"

A redesign that lets users swap the document layout must decide where these go (src/themes/DIN-5008/document.typ):

- `set document(title, author, date, description, keywords)` incl. the "ZUGFeRD"/"Factur-X" keywords (document.typ:66-78; added by `bbd8f46` "embed standard PDF metadata"). With `themes.blank` **no PDF metadata is written at all**. This is data-derived and arguably compliance-relevant, yet lives in the presentation layer - conflicts with C6/C7.
- Rendering of subject heading, place + date line (document.typ:164-181), reference signs, sender block with `extra` grid (document.typ:82-125), address window (127-146), annotations from `recipient.extra` (41-50). With `blank` none of this is rendered and the docs never tell a custom-layout user how to get at it (the only documented route is the `info.*` motifs in body text, components.md:143-209).
- `set text(hyphenate: true)`, `set par(justify: true)` (document.typ:183-184), `set text(font: font)` (80).
- No logo / letterhead slot exists. The header is a fixed 2-column grid (subject left, sender block right, fixed 5.5cm height).

### 2.6 Visual references as compat surface

Every DIN-5008 visual test has committed `ref/*.png` (tests/docs/_, tests/integration/_). Any change to default spacing, stripe colour, fonts, totals block etc. flips ~20 references. The project rule (`.agents/skills/fix-tests/SKILL.md:35-38`): "NEVER run blanket `tt update`"; each ref must be inspected and updated individually. A concept that keeps the _default DIN-5008 output pixel-identical_ is dramatically cheaper to land than one that does not.

### 2.7 Precedent for deliberate migration

The package already has a house style for deprecation: top-level `tax-nr` was kept as "(deprecated)" (src/invoice.typ:37-39), still works, and panics with a precise message when combined with the new location or with `zugferd` (src/invoice.typ:185-197). Expect the maintainer to want the same for theme changes: old spelling keeps working, conflicts panic with a helpful message, docs mark it deprecated.

---

## 3. What real users asked for (GitHub)

Tracker totals at time of research: 41 numbers used; 1 open issue (#18), 1 open PR (#40). Bodies paraphrased from API/HTML via WebFetch.

### 3.1 Footer / letterhead / business identity

- **#18 "[Feature Request]: Footer"** - OPEN, enhancement, MrToWy, 2026-05-08. https://github.com/leonieziechmann/invoice-pro/issues/18
  Wants a footer on **every page** with tax number, managing director, bank data - the classic German "Geschaeftsbrief-Pflichtangaben" footer; mock-up shows 3 muted small-text columns (company / management+tax / bank). Proposed API: a `footer-blocks:` argument on `invoice` taking an array mixing **predefined blocks** (`footer-sender-details`, `footer-bank-details`) and free content. Explicitly modelled on `references` ("I like how references work, give me the same for the footer").
  Maintainer 2026-05-08: theming is already planned, test infrastructure first. Maintainer 2026-07-09: full theming delayed (limited OSS time while finishing her bachelor's); `footer` parameter added to DIN-5008 as a **workaround** that accepts a custom grid. Issue deliberately left open as the tracking issue for the theming overhaul (she refers to it as such in #33).
  Gap today: page-1-only (2.2), no predefined blocks, no every-page option, undocumented.
- **#2 "Header misalignment"** - closed, MLNW, 2025-12. https://github.com/leonieziechmann/invoice-pro/issues/2 Sender header alignment vs. DIN 5008; a commenter pointed out the standard. Maintainer (2026-02-17): wants a **customizable override** so users can deviate from the standard while the default stays compliant. -> principle: _compliant by default, escape hatch available_.
- PR #4 "Improve header" (MLNW, merged 2026-01-03) - first external layout contribution.

### 3.2 Colours / corporate identity / print

- **#33 "Configurable row fill (striping)"** - closed, joelsa (systemscape.de - a business user), 2026-08-12. https://github.com/leonieziechmann/invoice-pro/issues/33
  Use cases named: black-and-white printing, corporate-identity accent colours, minimalist look. Proposed `row-fill:` on `themes.DIN-5008()` mirroring Typst `table.fill` semantics (`auto | none | color | array | function(index)`). Workaround noted: copying `render-line-items` into base-theme's `line-items` slot - "lacks ergonomics".
  Maintainer 2026-08-15: a proper theming overhaul (refers to #18, "pending since May") will take a while; accept a PR as temporary unblock but keep scope "dead simple": basic odd/even config now, "advanced logic for later".
  Result: **PR #36** (joelsa, merged 2026-08-19) -> `color-row-odd` / `color-row-even`. https://github.com/leonieziechmann/invoice-pro/pull/36
  Takeaways: (a) users reach for Typst-native semantics (`fill` with none/color/array/function); (b) the maintainer regards `color-row-*` as a stop-gap, so a v0.5.0 concept may supersede it if it keeps the two names working; (c) businesses will contribute if the extension point is obvious.

### 3.3 Totals block presentation

- **#41 "Always show (bold) 'Gesamt netto'"** - closed, JuliDi, 2026-09-18. https://github.com/leonieziechmann/invoice-pro/issues/41 B2B readers care about net. Solved by changing the default for everyone (`a4d0586`).
- **#39 "How to remove tax item completely?"** - closed, FabianBartl, 2026-09-04. https://github.com/leonieziechmann/invoice-pro/issues/39 Kleinunternehmer invoices must not show "0 %". Solved by changing the default (`386bbeb`).
  Pattern: both were _presentation_ wishes that had no user-side knob, so the maintainer had to patch defaults and cut a release. Both regression tests had to reach into INT paths to observe the totals (2.4). A public totals hook/option would have let users self-serve.
- **#37 modifier labels vs. partial payments** - closed, marcschn. https://github.com/leonieziechmann/invoice-pro/issues/37 Label customisation was only possible by wrapping the whole locale; solved with per-modifier `label` + `prepayment` component (PR #38). Shows the label/locale vs. layout/theme boundary users bump into.

### 3.4 Address block / sender block layout

- **#21 "More lines for sender and recipient addresses"** - closed, Leandros. https://github.com/leonieziechmann/invoice-pro/issues/21 Country line, c/o lines, company + project. Users noted newline hacks work for recipient but break the DIN one-line return address. Maintainer designed polymorphic `address` + `country` module; arrays render vertically in blocks and are flattened with commas in the sender line -> the data layer already hands themes two forms (`address` / `address-inline`, `name-inline`, `city-inline`; src/components/root.typ:18-31).
- **#14 "sender.extra not rendered anymore"** (dbongartz) and **#19 "Item-Discount and Extras not printed"** (MrToWy) - closed. https://github.com/leonieziechmann/invoice-pro/issues/14 , /issues/19 The 0.2.0 refactor silently dropped rendering of `extra`; re-added, then alignment fixed in 0.3.2. Lesson: layout regressions in the letterhead are noticed immediately; users rely on `extra` for phone/e-mail/web/register number.
- **#26 "tax number not displayed when references given"** (Proxycon), **#34 "Mandatory tax IDs are not visible"** (HarHarLinks) - closed. Legally required identifiers competing for the reference-sign row. A theme that relocates identifiers (e.g. into a footer, as #18 wants) must still guarantee they appear _somewhere_.

### 3.5 Other document types / reuse of the layout

- **#10 "Add option to set document title and labels"** - closed, lucaschoeneberg, 2026-01-19. https://github.com/leonieziechmann/invoice-pro/issues/10 Wants Angebot / Rechnung / Gutschrift from the same DIN layout (`title`/`doc-type` + `labels`).
  Maintainer 2026-04-21: use `subject` + `references` for now; **roadmap**: (1) multiple document types (invoice, offer, delivery note) via one parameter, (2) full locale override system, (3) custom locale configurations **packaged as standalone Typst packages** for reuse across projects.
  Implication: themes must not hard-code "invoice"; and "ship my company theme as its own package / file and reuse it across documents" is a stated maintainer goal for locale that transfers 1:1 to themes.
- #11 RFC comment (jbosse3): wants to combine invoice features with plain letter functionality.

### 3.6 Non-DIN / international layouts

- **PR #40 "feat: MVP UK invoice support"** - OPEN, JadedBlueEyes, 2026-09-08, 19 files, +405/-12. https://github.com/leonieziechmann/invoice-pro/pull/40 Body is minimal ("just enough for my needs"); layout impact unknown (not inspected in detail). Signals demand beyond DE/AT/CH; note contributing.md:72 restricts _tax_ scope to EU-compatible systems - it says nothing restricting _layout_.
- Locales exist for fr/it/es (+ regions at/ch/fr/it/es) but the only real layout is German DIN 5008. **Verified (proto t5/t6)**: a 2-page `locale.fr-fr` or `locale.en-de` invoice prints "Seite 2 von 2". Cause: the built locale dict has no top-level `lang` key (src/locale/factory.typ:66-74) so root falls back to `ensure("lang", "de")` (src/components/root.typ:61-62, 158), and letter-pro's auto page numbering only knows de/en anyway. Page numbering is owned by neither the locale nor the theme API today.

### 3.7 What nobody asked for (yet) in the tracker

No issue requests a **logo**, accent colour for headings, custom fonts per element, dark header bars, or alternative column sets. These are the maintainer's own roadmap items (F1, F6) and the obvious business needs, but there is no user-written spec to copy. #18 and #33 are the only user-authored API sketches - both favour **small declarative knobs on the theme call / invoice call plus predefined building blocks**, not callback programming.

---

## 4. Conventions a concept must respect

### 4.1 Tests (tytanic) - tests/TESTING.md

- Runner `tt` (tytanic v0.3.3 pinned in flake.nix:13). One dir per case with `test.typ` + mandatory `.gitignore` (`/diff/`, `/out/`) (TESTING.md:5-59).
- Categories: `docs/`, `integration/`, `issues/`, `line-items/`, `unit/` (TESTING.md:40-46; create-unit-test SKILL.md:20-24).
- Visual test needs a manually created empty `ref/1.png`, otherwise tytanic treats it as compile-only (TESTING.md:189); then `tt update <path>`.
- Import source, not package: `#import "/src/lib.typ": *` (TESTING.md:195, 251).
- `test-locale` for anything asserting text/values; `data-test` motif for value assertions; `themes.blank` for data tests "to narrow the test scope" (TESTING.md:69-91, 97-167, 228).
- Visual DIN tests pass `font: "libertinus serif"` (TESTING.md:198) - the default "Liberation Sans" is not available in the Nix sandbox. A new theme API must keep the font overridable in one place or tests become noisy. (A theme whose _default_ font is not bundled with Typst is itself a smell: every fresh user gets a font-fallback warning.)
- Valid IBAN `DE75512108001245126199` / BIC `SOLADEST600` in tests and docs (TESTING.md:166).
- Assertion message pattern `"Field: expected <v>, got " + repr(actual)` (TESTING.md:165).
- Never blanket `tt update`; inspect `out/` vs `ref/` vs `diff/` per case (.agents/skills/fix-tests/SKILL.md:35-60).
- Every reproducible GitHub bug -> `tests/issues/issue-<n>/` + row in the Issue Test Registry (TESTING.md:266-283, 446-456).
- Expect new theming features to arrive as `tests/integration/<feature>/` visual tests (precedent: row-colors-custom, row-colors-none, footer-dynamic) and one `tests/docs/api-theme-*/` per docs example.

### 4.2 Docs registry - docs/DOCUMENTATION.md

- Every non-trivial code block in `docs/docs/**` is registered with Code ID, description, version, test dir (DOCUMENTATION.md:7-10). theme.md currently has two: `din5008-example` -> `docs/api-theme-din5008/`, `blank-example` -> `docs/api-theme-blank/` (DOCUMENTATION.md:79-84) and the mirror table in TESTING.md:434-435.
- Discrepancy rule: "Take syntax from the test, take structure from the docs" (TESTING.md:258; DOCUMENTATION.md:10).
- Docs are Docusaurus; style conventions visible in every API page: parameter tables `Key | Type | Description`, admonitions (`:::info`, `:::tip`, `:::warning`, `:::danger`), bold house terms (**Cascading**, **Normalized**, **Grounds**, **Forward/Backward Calculation**). Large APIs are split into sub-pages (`locale/index.md`, `locale/custom.md`, `locale/base.md`; `invoice/country.md`, `invoice/references.md`; `line-items/unit.md`) - a finished theming API will likely become `api-reference/theme/{index,custom,base,...}.md` by the same pattern (locale's trio is: _use a preset_ / _customise with builders_ / _base schema reference_).
- `docs/versioned_docs/**` are frozen snapshots - never edit (MAINTENANCE.md:29, bump-version SKILL.md:49).

### 4.3 Versioning & release

- Version string lives in: typst.toml, `src/loom-wrapper.typ` loom-key label `<invoice-pro:X.Y.Z>`, README (3x), template/invoice.typ, all current docs, DOCUMENTATION.md registry (MAINTENANCE.md:13-29; bump-version SKILL.md). `check-version <old>` verifies.
- Release flow (.agents/skills/create-release/SKILL.md): `check-pr` -> bump -> regenerate `thumbnail.png` from `template/invoice.typ` page 1 -> `docusaurus docs:version` snapshot -> `nix build .#release` -> commit `chore(release): prepare vX.Y.Z` -> annotated tag -> CI opens the Typst Universe PR -> release notes with emoji sections incl. `## Breaking Changes`.
- Universe packages are immutable per version: users on `@preview/invoice-pro:0.4.2` are never broken by 0.5.0; breakage only hits on upgrade. Combined with P1 this gives real freedom for one clean break in 0.5.0 - and none afterwards.
- `compiler = "0.14.0"` (typst.toml:12) - the concept may not rely on >0.14 features even though the dev CLI is 0.15.x (workspace-setup SKILL.md:42).
- The template (`template/invoice.typ:16-18`) is what `typst init @preview/invoice-pro` copies into user projects; its `theme: themes.DIN-5008(form: "A")` line is the most widely deployed theme call in the wild, and the thumbnail is the package's shop window.

### 4.4 Formatting / CI / contribution policy

- Pre-commit: `typstyle -i` on `*.typ`, `prettier` on markdown, `nixpkgs-fmt` (flake.nix:155-160; pull-request-precheck SKILL.md:26-31). `scripts/check-pr` = lint -> `tt run` -> docs build -> ZUGFeRD validation (scripts/check-pr).
- Conventional commits with scopes: `feat(theme):`, `feat(themes):`, `fix(tax):`, `docs(theme):`, `test:`, `chore(release):` (git log).
- "must create an issue first ... evaluate the proposed API, and assess its impact on overall usability and **rendering speed**" (contributing.md:67). Performance is an explicit acceptance criterion; note `weave(max-passes: 2, ..)` at src/invoice.typ:323-324.
- "minimal dependencies" policy; utilities are to be copied in, not imported (contributing.md:76-79). A theming concept should not add packages. letter-pro is an _existing_ dependency "for the DIN layout" (README.md:162).
- Feature-request template demands: use case, **hypothetical Typst snippet of the proposed API**, expected output/mock-up, current workaround (.github/ISSUE_TEMPLATE/feature_request.md). A concept document in that shape will feel native to the maintainer.
- Source docstring convention: `/// description` + `/// -> type` per parameter (src/invoice.typ:19-104; base.typ:9-31). Validation via `types.require(value, "path::name", ..allowed)` with `::`-paths such as `"theme::DIN-5008::form"` (din-5008.typ:19). Today only `form` is validated in the whole theme layer.
- Naming: kebab-case everywhere; presets are module members (`locale.de-de`, `tax.vat`, `unit.h`, `country.de`, `references.preset-b2b`, `themes.DIN-5008`). `DIN-5008` with capitals is an established public identifier.

---

## 5. Timeline and where the maintainer is steering

### 5.1 Timeline

| Date             | Version / commit                                                                                                                                                                                                                                     | Event                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2025-12          | v0.1.0/0.1.1                                                                                                                                                                                                                                         | No theme concept. Layout knobs are direct `invoice()` args, passed straight to letter-pro: `format`, `header: auto\|content`, `footer`, `folding-marks`, `hole-mark`, `annotations`, `information-box`, `page-numbering`, `margin`, `font` (git show v0.1.1:src/lib.typ:26-110). Roadmap already lists "Theming Engine ... accent colors and fonts ... corporate identities".                                                                                                                                            |
| 2025-12..2026-02 | #2, PR #4                                                                                                                                                                                                                                            | First layout complaints (header alignment). Maintainer: default stays DIN, add override.                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| 2026-03-07       | #11 RFC                                                                                                                                                                                                                                              | "Input Once, Minimize Human Error"; loom; theming named as something the loom foundation will enable.                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 2026-04-18       | `6ce4ff7` -> v0.2.0                                                                                                                                                                                                                                  | **Theme system born**: `src/themes/{themes,base,blank,DIN-5008,base-theme}`. `theme: themes.DIN-5008(..)`, zero-arg theme function returning a dict of 4 component renderers + `document` + (inert) `header`/`footer`. README gains "### Theming" and the "Under Construction" stability line. **Regression in customisability**: `header`, `footer`, `information-box`, `page-numbering`, `annotations` args disappear. `extra` rendering lost (#14).                                                                   |
| 2026-04-24..29   | `4933ac3`, v0.3.0                                                                                                                                                                                                                                    | Docs site; theme.md written with "locked in **v0.4**", **Cascading**/**Normalized** vocabulary. Locale system lands (`2c8471e`) with the function-with-overrides pattern.                                                                                                                                                                                                                                                                                                                                                |
| 2026-05-05       | `81b214f`                                                                                                                                                                                                                                            | Roadmap item marked "(WIP)".                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| 2026-05-08       | #18                                                                                                                                                                                                                                                  | Footer request; maintainer: planned, tests first.                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 2026-05-13..21   | `a91eaa0` "Separated Line Items", `a981b21` "Advanced heading", `137717e` "total element structure", `454b657` "elegant line-items", `1d1c7ac` "recreating old base style", `1c1c996`, `c8a819a`, `1ec62a0`, `64e4454` (branch `generic-components`) | The monolithic line-items renderer is split into `src/themes/components/line-items/{table,totals,global-info,columns,line-items}.typ` - a generic, parameter- and hook-driven component. Style variants `elegant`, `vibrant`, `luxury`, `informational` are written as _thin presets over the generic component_. "recreating old base style" = the old look is re-expressed as just another preset (proof that the generic component is expressive enough; and evidence she cares about not changing the default look). |
| 2026-07-08/09    | `ed7bd8a`, v0.4.0                                                                                                                                                                                                                                    | Lock target moved to **v0.5.0**. `ce41753`: default `line-items` slot switched from `render-line-items-vibrant` (her dev default!) back to `render-line-items`. `233283d`: `footer` on DIN-5008 as "workaround" for #18. Release notes: "Generic Components & Layout Engine ... extensible, customizable components system". `bbd8f46`: PDF metadata put into the DIN document slot.                                                                                                                                     |
| 2026-08-14/15    | `23788cb`, v0.4.1                                                                                                                                                                                                                                    | `eval-content`: header/footer content is woven with loom ctx so `#info.*` works inside; base-theme gets the (non-working) `set page` wiring.                                                                                                                                                                                                                                                                                                                                                                             |
| 2026-08-12..19   | #33 / PR #36                                                                                                                                                                                                                                         | External business contributor adds `color-row-odd/even`; maintainer: keep it dead simple, "advanced logic for later".                                                                                                                                                                                                                                                                                                                                                                                                    |
| 2026-09-04       | v0.4.2                                                                                                                                                                                                                                               | Row colours documented; `group` component adds group header/subtotal rows to the table renderer. Release notes mention a non-existent `color-header`.                                                                                                                                                                                                                                                                                                                                                                    |
| 2026-09-19       | `a4d0586`                                                                                                                                                                                                                                            | Totals presentation default changed for #41.                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |

### 5.2 What this says about intent

1. **Generic components + presets is the chosen architecture.** She invested a full week (May 13-21) in making line-items a generic component with style values and `render-*` hooks, then wrote four looks as presets and rebuilt the legacy look as a fifth. What is missing is (a) the same treatment for `document`/letterhead, `bank-details`, `payment-goal`, `signature`; (b) a public, ergonomic way to reach those knobs; (c) a shared token layer so an accent colour set once reaches table, totals, headings and footer ("**Cascading**").
2. **Defaults are sacred.** "recreating old base style", reverting the default from `vibrant`, the fix-tests skill, and the DIN "window envelope" promise all say: the out-of-the-box DIN-5008 invoice must stay compliant and visually stable; creativity is opt-in.
3. **Compliant by default, overridable on purpose** (#2 comment) - mirrors how tax/locale work (`auto` everywhere, explicit override possible).
4. **Small declarative knobs first, callbacks as escape hatch.** Her guidance on #33, the shape of `references` (dict | array | function | presets, src/invoice.typ:120-133) and of locale (`locale.en-de.with({ import locale.custom: *; document(invoice: ..) })`) all favour named, validated, data-like configuration with builder helpers, with raw functions accepted as the power-user form.
5. **Context-aware content is a feature she wants in themes.** The header/footer docstrings ("Can include motifs/active items") and `eval-content` show header/footer are meant to be loom-evaluated content with `#info.*` access, not static strings. #18's "predefined footer blocks" map naturally onto motifs (`info.sender...`, a future `footer.bank-details`).
6. **Reusable/packagable configuration.** Stated for locale in #10 (ship custom locales as standalone Typst packages). A company theme defined once in `brand.typ` or an own package and passed as `theme:` is the obvious analogue - and the current "theme = plain function value" representation already permits it.
7. **More document types are coming** (#10: invoice/offer/delivery note via one parameter). Theme slots and tokens should be named for roles ("document title", "party block", "table", "totals", "payment"), not for "invoice".
8. **Time is the bottleneck** (#18 comment: bachelor's degree, limited OSS time; contributing.md:65 prefers issues over PRs because reviewing is expensive). A concept that can be landed incrementally - e.g. token layer + DIN-5008 knobs first, document-slot decomposition later - with pixel-identical defaults has a far higher chance of being adopted than a big-bang rewrite.

### 5.3 Parallels with sibling APIs that the docs themselves draw

- locale: preset is a function; use un-called (`locale.de-de`) or customise with `.with({ builders })`; `invoice` calls it with the base to deep-merge into (`locale(base-language, base-region)`, src/invoice.typ:181); docs: "Only the fields you explicitly define will be changed; the rest will fall back" (locale/index.md tip) and "leverage the cascading merge by specifying only the nested keys you wish to alter" (locale/base.md:241). There is a documented **base schema page** listing every key.
- theme today: preset is _sometimes_ a function-returning-function (`DIN-5008(..)`) and _sometimes_ a bare function (`blank`); `invoice` calls it with nothing; override = replace a whole slot; no schema page; no deep merge.
- The smallest conceptual move that aligns them: a theme is `(..overrides, base) => dict` exactly like a locale, presets are usable un-called, `.with(..)`/call-with-options customises, and there is a `themes.custom`/builder namespace + a documented base schema. Whether to take that route is a design decision - this report only notes that the docs' own vocabulary ("Cascading", "Normalized", "fall back to the default") already describes it.

---

## 6. Verified experiments (scratchpad/proto/docs-intent)

| File                                          | Question                                                                  | Result                                                                                     |
| --------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| t1-blank-footer.typ                           | Does `themes.blank.with(header:, footer:)` render?                        | **No** - neither mark appears. Dead params (base.typ:35-40 scoping bug).                   |
| t2-din-footer-multipage.typ                   | DIN-5008 `footer:` on a 2-page invoice                                    | Footer on page 1 only; page 2 shows only "Seite 2 von 2".                                  |
| t3a.typ                                       | `theme: themes.DIN-5008` (un-called)                                      | Compiles silently, unstyled output - no error.                                             |
| t3b.typ                                       | `theme: themes.blank()`                                                   | Clear `types.require` assertion: "must be of function".                                    |
| t3c.typ                                       | Hand-written `() => (document: ..)` partial theme                         | Works; line-items slot falls back to literal "Line Items".                                 |
| t3d.typ                                       | `themes.DIN-5008(..).with(signature: ..)`                                 | Works - slot override on a configured theme is already possible.                           |
| t4-apply-theme.typ                            | `#apply(theme: <evaluated dict>)[..]` scoped override (components.md:138) | Works; needs the _evaluated_ dict.                                                         |
| t5/t6                                         | Page-number language for fr-fr / en-de                                    | Always German "Seite x von y" (locale dict lacks top-level `lang`; root defaults to "de"). |
| t7-{elegant,vibrant,luxury,informational}.typ | Do the hidden presets still compile against today's generic renderer?     | All four compile and render.                                                               |

---

## 7. Open questions this research could not settle

1. GitHub Discussions could not be loaded - are there theming threads there?
2. Does the maintainer consider `themes.blank` un-called a hard requirement (25 test files) or is a mechanical migration acceptable under the "unstable until 0.5.0" banner?
3. Is staying on letter-pro a constraint? Every-page footers, localized page numbering, logo/letterhead and information-box all run into `letter-generic`'s fixed behaviour; the minimal-dependency policy would even favour inlining the ~150 relevant lines.
4. Should PDF metadata (`set document`) stay in a theme slot or move to root so every theme (incl. blank/custom) gets it?
5. Are the INT import paths used by issue-39/issue-41 meant to become public API (`themes.components.*`?), or should tests be rewritten against whatever public hook replaces them?
6. How far should "multiple document types" (#10) shape slot/token naming now?
7. PR #40 (UK) was not inspected file-by-file; it may contain layout changes that collide with a theme refactor.
