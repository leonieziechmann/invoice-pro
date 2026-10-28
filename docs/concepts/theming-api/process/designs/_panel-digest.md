# TOTALS

{"structure-first":21.65,"tokens-first":20.45,"locale-symmetry":21.630000000000003,"user-first":19.92}

## JUDGE maintainer

ranking: structure-first > tokens-first > locale-symmetry > user-first

### structure-first total=7.3

scores={"any_format_flexibility":9,"simple_case_ergonomics":7,"customization_ladder_no_cliffs":8,"consistency_with_package_philosophy":8,"feasibility_typst_loom":7,"compliance_safety":7,"stability_freezability":7,"maintainer_effort":6,"third_party_ecosystem":9,"testability_docs":7}
FATAL: No fatal flaw. Serious gaps: nothing validates that a layout hosts `recipient` or `sender` (compliance-parts = notices, totals, bank-details only, validate.typ:5). A custom or third-party layout, or region("address", none), silently drops the legally required recipient address. | The frame view freezes `totals: ctx.global` (frame.typ frame-view), which contradicts its own rule that ctx.global becomes internal. | Plain-dict theme in ctx: +23% compile time at 150 items versus 0.4.2 in my cross-benchmark. Its '+~7%' claim holds only for small invoices. Fixable by sealing. | The named tokens:/options:/parts: shorthands on the lazy theme are replaced wholesale by a chained .with (the trap user-first verified). | Reserved-zone handling drops the footer on the last page (`pages: "not-last"`), so a § 35a footer can vanish on 1-page invoices. Marks were avoided (marks: none), not handled.
KEEP: Page master as data: open named regions with x|right, y|bottom, width/height, a page selector and hosted parts in reading order. 12 layouts compiled from one body, including an A5 sidebar receipt. | The right-edge anchor (`right:`) for Swiss/French windows. | A flat parts registry with uniform (ctx, view). Wrap receives `inner`, and wrappers compose across preset, brand, user and themed layers (verified). | Only first-page fixed regions sit in the flow (tagged, reading order). Everything else is page furniture. | A brand-immune `isolate` region plus a float reserve zone at the bottom of the last page (verified: same page when it fits, moves to page 2 otherwise). | `stationery: "pre-printed"` drops brand regions but keeps geometry. | A third-party package with no invoice-pro import (verified local package). | Typed DSL helpers (colors/fonts/sizes) with native `unexpected argument` errors, and a called form that is also valid via named base: auto. | A roadmap that lands the API behind a shim over the old DIN document before the one visual-reference pass.

### tokens-first total=6.88

scores={"any_format_flexibility":6,"simple_case_ergonomics":7,"customization_ladder_no_cliffs":7,"consistency_with_package_philosophy":8,"feasibility_typst_loom":8,"compliance_safety":9,"stability_freezability":6,"maintainer_effort":5,"third_party_ecosystem":9,"testability_docs":6}
FATAL: Structure is encoded as frozen enums (letterhead.arrangement, bank.layout, geometry.references) plus a fixed zone set (header/window/info/reserve). Every new layout request becomes a new frozen enum value or a frame override: 'a new composition needs a part or frame override'. | About 190 tokens plus a second expression language (alias strings and tint/shade/mix/on/legible/scale/times/stroke-of/pick/derive/replace descriptors with lazy recursive resolution and a cycle guard) that a solo maintainer must support forever. | `..named` DSL helpers give up autocomplete and per-parameter docs. | Sealing relies on undocumented lazy hashing of metadata content and was not checked on 0.14.0.
KEEP: The strict deep merge: full path plus allowed keys at every depth, sides folding for partial inset/margin dicts, templates for groups that are none, dotted keys, arrays replace, a replace() marker. | Sealing the resolved and unresolved trees in metadata. My cross-benchmark confirms +1.5% at 150 items versus +17-26% for the plain-dict designs. | core-notes appended by the component outside the part, so no theme can drop legal notes. EPC QR built by core with a min-size clamp. Mandatory parts. Logo requires alt text. | Contrast lints with a strict mode, and planned PDF/A guards for CMYK and PDF images. | A rename-alias mechanism for provisional token paths (the old path becomes an alias for one minor version). This is the key freeze-survival device. | resolve-theme(theme, env:) for unit tests and third-party CI. | from-data with a regex parser (no eval) and an assets dict. | Explicit stability tiers (stable / provisional / experimental).

### locale-symmetry total=6.49

scores={"any_format_flexibility":5,"simple_case_ergonomics":7,"customization_ladder_no_cliffs":6,"consistency_with_package_philosophy":9,"feasibility_typst_loom":7,"compliance_safety":8,"stability_freezability":5,"maintainer_effort":6,"third_party_ecosystem":6,"testability_docs":7}
FATAL: 'The core frame is not replaceable': sidebar or address-in-sidebar layouts are out. This contradicts maintainer decision 2 (support ANY layout). | The <style>-<layout> preset matrix (4 x 9 = 36 names) freezes a large, combinatorial naming surface. | Two parallel schema trees plus hand-enumerated helpers mean each key is written three times, and derivations may only reference earlier keys (a hidden ordering rule). | Layout as a function of the final style adds an API shape with no demonstrated use beyond mark colour. | Third-party packages import invoice-pro to call build-theme/wrap, which couples them to the stability of an internal marker format. | Plain-dict ctx: +26% at 150 items.
KEEP: A shared utils/patch.typ adopted by locale: fixes the verified locale bugs (I-1 array idiom, I-2 panic, depth-2 merge) and can ship first as 0.4.3. | Inject schema objects (defaults, types, hydrate) from the running version instead of importing them. This fixes the forward-compat trap they found, verified 0.5.0 package on 0.5.1. | A helper/schema coverage test instead of `..named` helpers. | A notes panic when a renderer returns nothing while notes exist (verified). | One convention for every preset. Named options such as form: are rejected with an educational message. | The clearest docs framing of 'data decides what, core decides where, the theme decides how'.

### user-first total=6.41

scores={"any_format_flexibility":6,"simple_case_ergonomics":9,"customization_ladder_no_cliffs":8,"consistency_with_package_philosophy":5,"feasibility_typst_loom":7,"compliance_safety":6,"stability_freezability":5,"maintainer_effort":6,"third_party_ecosystem":8,"testability_docs":7}
FATAL: It rejects the locale-style patch DSL ('a second vocabulary') and replaces ctx-first (ctx, view) with a single-argument `it =>` signature. Both contradict decision 3 and the house convention (P12). | 29 named knobs in every preset signature: each new part becomes a new named parameter of every preset, and it.tokens/it.brand/it.geometry/it.locale/it.opts are all frozen. | Compliance is unproven: legal notes, zero-tax suppression and the EPC payload still live in renderers (M4 unbuilt), as does the empty-notes check. | Dict-valued knobs (table:, tokens:) still hit the chained .with wholesale-replace trap. There are two ways to load a brand file, and `kinds` is frozen before document kinds exist. | Plain-dict ctx: +17% at 150 items.
KEEP: The verified finding that .with replaces dict-valued named args wholesale. It argues for positional patch arrays and only one named swap (layout:). | The assets: p => image(p) loader closure, verified across a package boundary: a 0.14-compatible answer to logo paths in brand files. | medium/pre-printed as a mode that wins over styling (found by testing). | 'Did you mean' hints in validation errors. | it.default(..overrides) re-parameterisation as a middle rung (can become inner.with(..) in wraps). | The shortest five-minute path: logo, color, font.

RECOMMENDATION:
BACKBONE: structure-first. It covers the page master as data (open named regions with geometry, page selector and hosted parts in reading order), the core-owned frame, the flat parts registry with (ctx, view) plus wrap-with-inner composing across layers, and a small semantic token layer. Its freeze profile is the best: new formats arrive as data or additive tokens, not as frozen enum values or preset names.

GRAFT FROM TOKENS-FIRST:
(1) The strict merge semantics: full path plus allowed keys at every depth, sides folding for inset/margin, templates for none-groups, dotted keys, arrays replace, replace() marker.
(2) Sealing the resolved and unresolved trees in metadata (internal). My benchmark: +1.5% versus +17-26% at 150 items for the plain-dict designs. Gate it with a 0.14.0 CI benchmark.
(3) core-notes appended by the component outside the part as the primary legal-notes guarantee (keep structure-first's emptiness check as a secondary guard), the core-built EPC QR with a size clamp, mandatory parts, and logo alt text.
(4) A trimmed tiered token idea: a frozen semantic tier of about 40 leaves with seed derivation (on-primary, legible accent-text, OKLab surface tint); per-part `options` as the provisional component tier, protected by the rename-alias mechanism; no ref tier in 0.5.0.
(5) Contrast lint/strict mode and the PDF/A guards (CMYK, .pdf image sources when zugferd is set).
(6) resolve-theme for tests and third-party CI.
(7) from-data with a regex parser. Alias strings only inside data files, converted to lazy functions. The $op descriptor language is not frozen.

GRAFT FROM LOCALE-SYMMETRY:
(1) utils/patch.typ shared with locale, shipped first as 0.4.3 (fixes the locale DSL bugs).
(2) Inject schema objects (defaults and types) from the running version, never import them.
(3) A helper/schema coverage test, keeping typed named DSL helpers instead of ..named.
(4) Its 'data decides what, core decides where, theme decides how' docs framing.

GRAFT FROM USER-FIRST:
(1) The assets: p => image(p) loader, which keeps the 0.14 minimum and avoids path().
(2) The 'mode wins over styling' rule for pre-printed.
(3) Did-you-mean hints.
(4) The .with wholesale-replace constraint: drop structure-first's named tokens:/options:/parts: shorthands and keep only layout: as a named swap.

DROP:

- locale-symmetry's <style>-<layout> preset matrix and layout-as-function-of-style.
- tokens-first's arrangement enums (they become layouts/regions), ..named helpers and Typst-side alias strings.
- user-first's 29 flat knobs, `it =>` signature, kinds and singular namespace.
- structure-first's frame-view `totals: ctx.global` (replace with an explicit record built by root).

CONFLICTS:
(a) Region-inferred layout: none in 0.5.0. The default is din-5008-a, because the CH/FR/UK millimetre values are unverified and silent defaulting is a compliance risk. Add layouts.for-region later.
(b) Called vs uncalled: accept both via named base: auto, validate the evaluated dict, uncalled is canonical.
(c) Part signature: (ctx, view), wrap (ctx, view, inner).
(d) Token richness: a middle ground, frozen semantic tier plus provisional per-part options with rename aliases, grown additively.
(e) Layout engine: freeze the region schema, but mark arrange-function/float/isolate/reserve and the non-DIN frame parts experimental.

MUST ADD (gaps in all four):

- Required-parts validation: the layout must host recipient and sender.
- Reserved zones must suppress marks and stationery and move the legal footer into the flow above the zone rather than drop it; panic if it does not fit.
- The QR-bill as a frame part fed from root's fresh ctx, not a body component.

Stay on compiler 0.14.0 with an M1 CI job.

Roadmap:

- M0: patch.typ plus locale fixes, lang fix, metadata into root.
- M1: engine behind a shim over the old DIN document (no visual churn).
- M2: own frame plus DIN layouts, #18 footer, drop letter-pro (the one visual-reference pass).
- M3: view v2 plus core notes/EPC plus a token-driven table (kills the 50 parameters and the crash bugs).
- M4: further layouts as data with one reference test each, non-DIN marked experimental.
- M5: themed, from-data, guards, docs, lock.

## JUDGE business-user

ranking: locale-symmetry > structure-first > tokens-first > user-first

### locale-symmetry total=7.48

scores={"any_format_flexibility":6,"simple_case_ergonomics":8,"customization_ladder_no_cliffs":7,"consistency_with_package_philosophy":9,"feasibility_typst_loom":8,"compliance_safety":9,"stability_freezability":6,"maintainer_effort":6,"third_party_ecosystem":8,"testability_docs":8}
FATAL: The core frame is fixed to 'absolute page-1 zones (head/window/info) plus furniture' and cannot be replaced. The proposal itself says a sidebar-address design is 'hard to express'. This contradicts maintainer decision 2 ('ANY format'). | The <style>-<layout> preset naming ('about 4 x 9 = 36 names') would freeze dozens of public names in v0.5.0. | Derivations are resolved in positional schema order ('may only reference keys defined earlier'), which is a trap for brand authors. | Each key is written three times (defaults, types, helper). Removing the window needs a raw patch (layout: (window: none)). Called and dict themes are rejected, so theme: toml(..) does not work directly.
KEEP: One shared utils/patch.typ (strict deep merge, sides folding, wrap marker, re-hydration, one-element-array helpers without return, '::' path errors) that locale adopts too, shipped as a locale bugfix in M0 | Injected master schema objects (defaults, types, hydrate); forward compatibility verified across two package versions | themes.custom has one helper per group and a brand() macro. Rich style tokens incl. letterhead fill band, logo.position left/right, footer.blocks builders | One stationery switch: mode generated|background|pre-printed | Core composes table->totals->notes and panics if notes renders nothing. Core view.qr closure clamped to >= 20 mm. A theme cannot move the address out of the window | A layout may be a function of the final style (region(lang) analogue)

### structure-first total=7.36

scores={"any_format_flexibility":9,"simple_case_ergonomics":7,"customization_ladder_no_cliffs":6,"consistency_with_package_philosophy":7,"feasibility_typst_loom":8,"compliance_safety":8,"stability_freezability":6,"maintainer_effort":6,"third_party_ecosystem":9,"testability_docs":7}
FATAL: Region edits can silently drop legally required identity fields. themes.modern.with(custom.region("masthead", none)) compiled to an invoice with no number, date or title (reproduced: out/sdate.png). | body-top: auto ignores background regions such as a full-bleed band, so flow content collides with the band. No lint catches it. | The token/option layer is thin (3 frozen table options), so business users jump from colours straight to region geometry. | Dict-valued named .with shorthands (tokens:, options:, parts:) are replaced wholesale when chained, and the proposal never acknowledges it. | The frozen surface is broad: region schema, the whole frame view and about 25 part names. Region inference (R11) is refused.
KEEP: Layout = data made of named regions (place, pages first|rest|last|not-last|all, x|right, y|bottom, parts in reading order, arrange, brand, isolate, float, reserve). DIN is one 20-line dict; the A5 sidebar comes from a zero-import package | Flat part registry (ctx, view) => content with a wrap marker composing across layers (brand, user, scope) | notices as a separate compliance part: none rejected, empty-while-required panics at render time. view.qr and filtered taxes are decided in measure | A QR-bill reserve zone via place: after, float: true, isolate: true (prototyped) | Stationery 'pre-printed' | (first, rest) suppresses brand: true regions automatically | Regions accept part names, content and functions (the #18 footer composition) | Called and uncalled forms both valid; themed as an unnamed compute motif; 7% measured overhead

### tokens-first total=7.05

scores={"any_format_flexibility":7,"simple_case_ergonomics":7,"customization_ladder_no_cliffs":7,"consistency_with_package_philosophy":7,"feasibility_typst_loom":6,"compliance_safety":8,"stability_freezability":7,"maintainer_effort":5,"third_party_ecosystem":9,"testability_docs":7}
FATAL: Performance relies on an undocumented engine property: sealing trees in metadata(); without it about +300 ms per invoice, which is risky for batch users | About 190 tokens with string aliases ('{color.primary}') that get no IDE help. The ..named DSL helpers lose autocomplete and per-parameter docs | Arrangements stop at enums. Logo right in a band required a full letterhead part override. parts.frame reintroduces a whole-document escape hatch | The footer is either auto (4 fixed columns) or literal content; there are no reusable blocks to mix, which is what #18 asks for
KEEP: Order-free lazy derivation with a cycle guard. Descriptors (tint, on, legible, mix, scale) are plain dicts, usable in data files and zero-import packages | from-data regex parser (no eval), absence = inherit, 'none' -> none | Contrast tooling: on-color, legible repair, lints, a11y strict, specimen; built-in presets must have zero lints in CI | resolve-theme for unit-testing token outcomes outside an invoice | Semantic roles incl. font.numeric, font.figures tabular, font.regulated for brand-immune zones | Sides folding for inset/margin; stability tiers with rename aliases for one minor version; planned PDF/A guards (CMYK, PDF image source)

### user-first total=7.02

scores={"any_format_flexibility":6,"simple_case_ergonomics":9,"customization_ladder_no_cliffs":7,"consistency_with_package_philosophy":5,"feasibility_typst_loom":8,"compliance_safety":7,"stability_freezability":6,"maintainer_effort":7,"third_party_ecosystem":7,"testability_docs":7}
FATAL: Rejects the house ns.custom patch-DSL idiom instead of fixing it, renames themes -> theme, and freezes a 29-parameter flat signature: the same flat-params shape the research criticised | Single-argument it => parts break the ctx-first convention, and it.ctx is exposed as an unstable escape hatch | The layout geometry can silently drop required identity data: layout info: none with modern's info position block removed date and references (reproduced in stress test a) | Dict-valued knobs keep the .with wholesale trap. Stationery needs medium + stationery + letterhead none + footer none, and footer: none also kills the page number | Legal notes and the EPC payload are still in renderers in the prototype; there are no custom regions (fixed zone names only)
KEEP: theme: accepts a dict / toml(..) directly; the idempotent called form removes the footgun | Did-you-mean unknown-key errors (verified), hex-string colour coercion, an assets: loader closure resolving user paths across the package boundary (verified) | kinds: per-document-kind patches (reminder red accent verified) | Footer block catalogue (sender, contact, register, tax-ids, bank, page-number, continuation) reading sender.register/management/capital | Rule: an output mode wins over styling (a user renderer must not re-show the letterhead on pre-printed paper) | Stationery stretched to the sheet; layout: auto from region with CH kept on DIN until SN geometry is verified | 'Re-parameterize the default' rung via it.default(opts)

RECOMMENDATION:
Use two backbones. The public API shell and merge engine come from LOCALE-SYMMETRY. The layout axis and part registry come from STRUCTURE-FIRST.

(1) API shell from locale-symmetry. Take utils/patch.typ shared with locale (strict deep merge, sides folding, wrap marker, re-hydration, one-element-array helpers without return, '::' path errors) and ship it in M0 as a locale bugfix together with the lang fix and core set document. Take build-theme, the themes.custom helper-per-group DSL plus the brand() macro, and injected master schema objects (defaults, types, hydrate) for verified forward compatibility.

(2) Layout engine from structure-first. Layouts become data made of named regions (place, pages selector, x|right, y|bottom, parts in reading order, arrange, brand, isolate, float, reserve), replacing locale-symmetry's fixed head/window/info zones. DIN, SN, NF, UK, US and digital layouts are region dicts, and a layout may still be (style) => dict. Parts form a flat registry (ctx, view) => content, with wrap((ctx, view, inner) => ..) composing across layers. notices is a separate compliance part with the emptiness check. themed is an unnamed compute motif. The frame is NOT replaceable: regions supply the freedom, core keeps metadata, lang and the window guarantee.

Graft from tokens-first:

- order-free lazy derivation with a cycle guard (not locale-symmetry's positional order), with descriptors as plain dicts so data files and zero-import packages can derive;
- from-data (regex parser), resolve-theme for unit tests, specimen, contrast lints and a11y strict, PDF/A guards (CMYK, PDF image source);
- semantic roles incl. font.numeric, tabular figures and font.regulated, trimmed to about 60 frozen semantic tokens plus small per-part option groups. No ref.\* tier and no string aliases as the primary authoring form.

Graft from user-first:

- theme: accepts a dict/array/toml and the idempotent called form;
- did-you-mean errors, hex-string coercion, the assets: loader closure, kinds:;
- the footer block catalogue reading new sender.register/management/capital keys;
- stationery stretched to the sheet, and the rule that an output mode wins over part overrides;
- layout: auto from the locale region, with CH mapped to DIN until SN is verified. Explicit layout: always wins, which answers the structure-first/locale-symmetry objection.

Also keep from locale-symmetry the rich letterhead/table/totals/bank tokens (logo.position, band fill), so logo-right and band never force a renderer. That was the cliff in tokens-first and user-first.

ADD, based on my stress tests:
(a) An IDENTITY GUARD. Invoice number, invoice date, title and recipient become required outputs, like notices. Validate that some region hosts a part providing them; otherwise panic with a § 14 UStG / EN 16931 message, or fall back to core output. structure-first region removal and user-first info: none both produced invoices without a date.
(b) body-top: auto must reserve space for every first-page region overlapping the text area, including background bands, plus a lint for fixed regions overlapping the address window.
(c) Stationery is ONE mode value: generated | pre-printed | (first:, rest:). It suppresses brand: true regions; page number and continuation are configurable.
(d) The #18 footer is a footer region hosting block names + content + functions.

DROP:

- locale-symmetry's <style>-<layout> preset explosion (use two axes: presets classic/modern/minimal/plain x layouts.\*), positional derivation and triple key writing;
- structure-first's dict-valued named .with shorthands tokens:/options:/parts:, which are lost silently when chained (keep only layout:, where swap is intended);
- user-first's 29-knob builder, the theme rename, it => parts, it.ctx, and the medium/stationery/part-null juggling;
- tokens-first's 190-token frozen surface, metadata sealing as a contract (internal optimisation only, and ask loom for an official opaque value), parts.frame, and from-dtcg in 0.5.0.

CONFLICT RULINGS:

- part signature: (ctx, view) with wrap/inner, plus a helper to call the default with other options;
- views: adopt the shared v2 contract ((value, text) records, plurals, decisions in measure, no ctx.global); freeze only the bold fields and keep line-items provisional;
- compiler: stay on 0.14.0 with a CI job in M1.

Suggested order: M0 patch+locale+lang+metadata; M1 engine + classic on region DIN + own frame + #18; M2 stationery switch, identity guard and reserve lint; M3 view v2, notices and core QR; M4 US/UK/digital layouts + layout: auto (SN/NF after mask verification); M5 modern/minimal, from-data, assets, kinds, contrast, specimen, themed; M6 docs and lock.

## JUDGE api-consistency

ranking: locale-symmetry > structure-first > tokens-first > user-first

### tokens-first total=6.52

scores={"any_format_flexibility":7,"simple_case_ergonomics":7,"customization_ladder_no_cliffs":8,"consistency_with_package_philosophy":6,"feasibility_typst_loom":6,"compliance_safety":8,"stability_freezability":6,"maintainer_effort":4,"third_party_ecosystem":6,"testability_docs":7}
FATAL: Unknown named arguments are silently dropped. build-theme only reads user.pos(), so `themes.classic.with(form: "B")` or `.with(color: red)` compiles and does nothing. This repeats locale's I-3 at the entry point. | The DSL helpers are generic `(..keys) => ((name): keys.named())`, so they have no named params, no auto defaults, no per-param docs and no native arity errors. Helper names also differ from group names (`palette` writes `color`, `typography` writes `size`), which breaks P6. | The ecosystem story contradicts itself. build-theme is presented as the tier-2 publish factory, yet packages are told not to import it. A package that does call its own copy validates and resolves with that version's leaf-types and $op resolver, so injecting the base schema does not deliver forward compatibility for descriptors added later. | Parts can reach tokens only via themes.tokens-of(ctx), because the sealed layout is internal. A zero-import package part that needs a token must either import invoice-pro or read the internal ctx.theme.sealed.value.tokens. | `theme:` accepts a dict meaning a patch onto classic, while resolve-locale accepts a dict meaning an evaluated locale. The same argument shape means opposite things in sibling APIs.
KEEP: Named base injection `(..patches, base: none, env: none)` with a 'pass the preset UNCALLED' panic | Rename aliases for provisional token paths for one minor version (stability mechanism) | `resolve-theme(theme, env:)` for third-party CI and unit tests; `specimen`; a CI rule of zero contrast lints for built-in presets | Order-free lazy resolution with a cycle guard instead of tier or schema order | Regex-based `from-data` (no eval); alias strings only as a data-file affordance | Mandatory-parts refusal plus core-notes appended after the line-items part, which any replaced part cannot drop | restyle accepts the same patch forms (positional and named dotted) as document level

### structure-first total=6.99

scores={"any_format_flexibility":10,"simple_case_ergonomics":7,"customization_ladder_no_cliffs":7,"consistency_with_package_philosophy":6,"feasibility_typst_loom":8,"compliance_safety":6,"stability_freezability":6,"maintainer_effort":5,"third_party_ecosystem":8,"testability_docs":7}
FATAL: VERIFIED (judge probe sf/tests/judge.typ): `themes.din-5008.with(form: "B")` is silently ignored. build only reads layout/tokens/options/parts from patches.named() (I-3). | VERIFIED: the named shorthands reintroduce Typst .with wholesale replacement. `.with(tokens: (color: (primary: red))).with(tokens: (size: ..))` loses the primary colour. | VERIFIED: precedence is inverted. Named shorthands are applied before positional patches regardless of call order, so `din.with(brand).with(options: (totals: (width: 30%)))` yields the brand's 50%. This contradicts its own 'positional patches in call order' and the house 'later wins'. | VERIFIED: compliance hole. compliance-parts = (notices, totals, bank-details), so part('recipient', none) and part('items-table', none) validate, and a layout may omit the recipient region entirely. | Naming: the default preset `themes.din-5008` is reused on US Letter, which keeps DIN at the centre of the naming against decision 2. A new plural top-level `layouts` namespace feeds a `layout:` param (I-14). The DSL mixes typed helpers with stringly `options(name,..)` and `region(name,..)`. `themed` drops named args while `.with` accepts them.
KEEP: The region-based page master (place kinds, pages selector first/rest/last/not-last/all, x|right, y|bottom, parts in reading order, arrange, brand, isolate, float, reserve) as the content of the layout pipeline | Layout swap = replace regions wholesale (never merge regions across standards) | Open parts registry; wrap markers that compose across preset, brand, user and scope layers | Parts read public ctx.theme.tokens, so zero-import third-party packages (verified A5 sidebar package) | themed explicitly rejects layout patches with a clear message | notices as a separate compliance part with an empty-output panic; options.row capture so a scope reaches data motifs | Path-style validation messages including region semantics (exactly one of x/right)

### locale-symmetry total=7.66

scores={"any_format_flexibility":6,"simple_case_ergonomics":7,"customization_ladder_no_cliffs":7,"consistency_with_package_philosophy":9,"feasibility_typst_loom":8,"compliance_safety":9,"stability_freezability":7,"maintainer_effort":6,"third_party_ecosystem":7,"testability_docs":9}
FATAL: The frame is not replaceable and the layout schema only knows page-1 zones plus furniture. A sidebar layout with the address in the sidebar cannot be expressed, and table->totals->notes order is fixed. This falls short of decision 2 unless the layout schema is replaced by a region model. | Positional base injection `(..overrides, base-style, base-layout)` copies a latent locale footgun. Calling a preset with two patches binds them as the bases and fails with a cryptic missing-key error. | Preset explosion (36 `<style>-<layout>` names) and no layout-swap patch. A third-party look cannot be moved onto another layout via .with unless the package exports the raw style. | Derivations resolve in positional schema order. A user derivation referencing a later key produces a confusing type error.
KEEP: The whole API shell: build-theme(style, layout) mirroring build-locale; lazy uncalled presets; .with as the only verb | Shared utils/patch.typ that also fixes locale I-1/I-2/I-3 and ships first as a locale bugfix | style:/layout: pipelines mirroring strings:/region:, unknown pipelines and non-dict patches panic | Typed themes.custom helpers with helper name == group name, one-element arrays via emit, and a coverage test against schema drift | Named arguments rejected with an educational message | Injected master schema OBJECTS (defaults, types, hydrate) so older package closures validate against newer types (verified across 0.5.0->0.5.1) | themed(..patches) with the same helpers, layout patches rejected, re-derivation from the unresolved source | Strongest compliance core: non-replaceable frame placement of the address, notes panic when a renderer drops them, zero-tax and EPC decided in core | Docs trio mirroring locale (index/custom/base) with base tables generated from types

### user-first total=6.49

scores={"any_format_flexibility":7,"simple_case_ergonomics":9,"customization_ladder_no_cliffs":6,"consistency_with_package_philosophy":4,"feasibility_typst_loom":7,"compliance_safety":8,"stability_freezability":6,"maintainer_effort":6,"third_party_ecosystem":8,"testability_docs":7}
FATAL: VERIFIED (judge probe uf/tests/judge.typ): precedence inversion. Named knobs are always applied after positional patches, so `theme.classic.with(color: blue).with((color: red))` stays blue and a later brand file loses to an earlier company knob. | VERIFIED: dict-valued named knobs replace wholesale across chained .with (`.with(table: (row-fill: green)).with(table: (header: "filled"))` loses row-fill). The proposal admits it is 'the one rule users must learn'. | VERIFIED: overlapping knobs (`stripes` vs `table: (row-fill:)`) write the same path and dict order silently decides. 29 knobs plus 4 model groups are effectively two vocabularies. | Drops the house `custom` DSL (P6/P7) and replaces the ctx-first `(ctx, view)` part convention (P12) with `it => content`, making raw ctx `it.ctx` unstable. A locale-savvy user cannot guess it. | restyle reads knobs.named() only, so positional patch dicts, the documented layering tool, are silently dropped in a scope. restyle(layout:) and restyle(medium:) are accepted without effect. Layout presets are strings and are inferred from the region by default (hidden coupling).
KEEP: Singular `theme` namespace matching the parameter name (P1, fixes I-14) | A called preset is idempotent (returns self.with(..)), so the called/uncalled footgun disappears structurally | medium-as-mode: what pre-printed hides stays hidden even if a part is overridden | kinds: per-document-kind patches (the only concrete R27 answer) | `default` renderer re-parameterization (super with option overrides) | Did-you-mean suggestions in unknown-key errors, including data files | Parts receive tokens in the view, enabling zero-import packages | theme.blocks footer blocks with one `(it, ..options)`-style convention customized with .with (fixes references I-9)

RECOMMENDATION:
BACKBONE: locale-symmetry's API shell. Put structure-first's region page master inside the layout pipeline.

KEEP (locale-symmetry):

- the shared utils/patch.typ, shipped first as the locale bugfix (emit one-element arrays, strict deep merge with :: paths, sides fold, re-hydration, markers)
- the style:/layout: pipelines and typed theme.custom helpers (helper name == group name, auto defaults, coverage test)
- injected schema objects (defaults, types, hydrate); rejection of named args on presets AND on themed
- themed(..patches) with the same helpers and layout patches rejected
- the compliance core (metadata, lang, XML, notes decided in measure with an empty-output panic, zero-tax filtering, EPC view.qr); the locale-style docs trio

GRAFT from structure-first:

- the region layout schema (place fixed|before|after|header|footer|background|foreground, pages first|rest|last|not-last|all, x|right, y|bottom, parts in reading order, arrange, brand, isolate, float, reserve) replaces locale-symmetry's fixed head/window/info/furniture groups; this removes the fixed-frame cliff without making the frame a replaceable part
- the open parts registry; wrap markers composing across layers (one signature, ctx-first: wrap((ctx, view, super) => ..); document the marker as a plain tagged dict so zero-import packages can build it)
- a layout SWAP patch custom.layout(theme.layouts.X) that replaces regions; this removes the 36-name preset explosion, so ship style presets only (theme.classic/modern/minimal/plain) on a default layout, with layouts as values in theme.layouts.\*
- options.row / theme-scope capture, kept inside the single theme ctx key

GRAFT from tokens-first:

- NAMED base injection (..patches, base: none, env: none) with a 'pass it UNCALLED' panic, replacing positional (base-style, base-layout), which lets stray positionals bind as bases; fix locale identically in patch.typ
- order-free lazy derivation with a cycle guard (derivations stay Typst functions t => value); alias strings only inside from-data
- rename aliases for provisional keys for one minor version; resolve-theme for package CI; specimen; the regex from-data parser; zero contrast lints for built-in presets in CI
- mandatory parts (recipient/address, items-table, totals, notices, bank-details cannot be none), plus a layout-validator rule that recipient is hosted by exactly one first-page region or the flow; this closes structure-first's verified hole

GRAFT from user-first:

- the singular `theme` namespace (theme: theme.classic), since backwards compatibility is not required
- the mode-wins-over-styling rule as the semantics of layout.stationery (generated|background|pre-printed)
- kinds (per document kind) reserved as experimental for R27
- did-you-mean hints in strict-merge errors; super(ctx, view, ..option-overrides) re-parameterization
- a brand(color:, accent:, font:, logo:) macro in theme.custom for the five-minute path

DROP:

- every named dict shorthand on presets (structure-first tokens:/options:/parts:, user-first table: etc.); my probes verified wholesale loss and call-order inversion
- silent acceptance of unknown named args
- theme: accepting a dict (accept only a function, with a message pointing to theme.classic.with(theme.custom.from-data(..)))
- region-inferred layout by default (offer an explicit theme.layouts.for-region helper plus a docs table)
- $op descriptors, sealed metadata as a contract (at most an internal optimisation), the 36 <style>-<layout> names, the it => part signature

CONFLICTS:

- scope verb: themed (tokens-first's token reader becomes theme.tokens(ctx))
- part signature: (ctx, view), per P12
- theme = style x layout vs swap: both, build-theme for authors and custom.layout swap for users
- DSL vs knobs: DSL plus the brand macro
- layout may be a function of the final style, but dicts with lazy region values are the norm
- compiler: stay on 0.14.0 with a 0.14.0 CI job in M0

## SYNTHESIS

path: <session>/concept/draft-1.md
backbone: structure-first: layouts as region data, the parts registry with wrap composing across layers, and the core-owned page frame (letter-pro dropped). Around it sits locale-symmetry's API shell: the shared patch.typ, typed custom.\* helpers, the injected schema object, a coverage test and rejection of named arguments.

SUMMARY:
A theme works like a locale: a lazy value, passed uncalled, written `theme.classic.with(..patches, layout: ..)`. It combines three things:

- a page master written as data: a layout of named regions, each with geometry (x|right, y|bottom), a page selector and a list of parts in reading order;
- a flat registry of part renderers `(ctx, view) => content` that can be wrapped `(ctx, view, inner)` or replaced;
- a frozen tier of 35 semantic tokens (colors/fonts/sizes/weights/strokes/spacing) derived from one seed colour, plus provisional per-part options.

**Merge engine.** Everything folds through one strict engine, `utils/patch.typ`, which locale also uses. It ships first as the 0.4.3 locale fix.

- An unknown key panics at any depth, printing the `::` path, a did-you-mean hint and the allowed keys.
- Margins fold, arrays replace, and a group that is `none` is rebuilt from a template before a patch lands on it.
- Wrap and replace markers are plain tagged dicts, so packages need no import to build them.
- A patch that names a region the layout does not have must say where it goes (`place`); otherwise it is treated as a typo.

**Three synthesis rules resolve the judges' conflicts:**

1. The layout is always the bottom layer. Looks patch only the standard region names (letterhead, address, title, footer, ...) and never geometry, so any look works on any layout. This removes the 36-name preset matrix and the idea of layouts as functions of style.
2. The only named argument is `layout:`. It means "swap", which is exactly what Typst's wholesale `.with` replacement does. Any other named argument panics with a hint. The idempotent called form means `theme.classic(p)` equals `theme.classic.with(p)`.
3. Derivations are plain `t => value` functions, resolved by iterating until nothing changes (up to 6 rounds). Order does not matter and cycles are detected. Alias strings exist only in data files, where `from-data` converts them.

**Compliance output lives in core, not in parts.**

- PDF metadata, the document language and the ZUGFeRD XML attachment.
- Legal notes: the component decides whether they are required and calls the `notices` part outside the replaceable `line-items` part. `none` is refused, and empty output panics.
- The EPC QR code is built in measure as `view.qr(size)`: black on white, at least 20 mm.
- Identity guard: every layout must place `recipient` exactly once and `title` at least once on page 1 or in the flow, and empty output panics.
- An overlap check keeps the address window clear.
- Reserved zones (Swiss QR-bill) are filled white, so marks and letterhead art do not show through. The page footer moves above the zone instead of disappearing.

**Stationery** is one layout value: generated, pre-printed, or first/rest artwork. It drops every region flagged as brand furniture regardless of renderer (a mode wins over styling), and the artwork is stretched to the sheet.

**API surface.**

- Namespace `theme` with presets classic, modern, minimal and plain.
- `theme.layout` with din-5008-a, din-5008-b, us-letter-10, a4-digital, letter-digital, plain, experimental sn-010130-right, and `derive`.
- `theme.custom`: typed helpers (one per group), `brand`, `from-data(data, assets:)`, `region`, `part`, `wrap`, `checks`.
- `build-theme`, `resolve-theme`, `adjust`, and `themed` for scoped overrides.
- Sealing the theme inside a `metadata` value in the loom context is an internal optimisation. Parts always receive an unsealed context.

**Prototype.** It was forked from structure-first and its engine rewritten (1,767 lines). Verified on typst 0.15.1:

- all 28 look × layout combinations compile from one invoice body;
- the three stationery modes work, and the e-invoice mode passes PDF/A-3b with the factur-x.xml attached;
- walkthroughs P1, P4 (TOML brand), P6, P8 and the scoped overrides render;
- a third-party package with zero invoice-pro imports renders a new A5 layout;
- the coverage assertions pass, including that the default seed reproduces the old zebra colour #e2e8f0 exactly;
- all 21 error messages appear as written in the concept;
- PDF/UA-1 exports compile cleanly.

**Benchmark (150 items, 5 runs):**

| Variant                   | Time         |
| ------------------------- | ------------ |
| 0.4.2 baseline            | 1129–1156 ms |
| Synthesis, theme sealed   | 1226–1364 ms |
| Synthesis, theme unsealed | 1894–1922 ms |

Nothing was run on typst 0.14.0. The concept keeps the 0.14.0 minimum and adds a 0.14.0 CI job in M0.

GRAFTS:

- locale-symmetry: shared utils/patch.typ shipped first as the locale bugfix (M0); typed helper-per-group DSL returning one-element arrays; injected schema object; helper/schema coverage test; rejection of named arguments; the 'data decides what, core decides where, theme decides how' framing
- tokens-first: strict merge at every depth with templates for none-groups and a replace marker; sealing the theme in metadata (internal only; measured +8% vs +67% unsealed); order-free derivation with cycle detection; legal notes called outside the replaceable part; EPC payload built by core; resolve-theme; from-data with a regex parser and aliases converted to functions; PDF/A and contrast guards; logo alt-text check; rename aliases for provisional keys
- user-first: idempotent called form; did-you-mean hints; assets: loader for logo paths in brand files; mode wins over styling for stationery; artwork stretched to the sheet; option to re-parameterise the default renderer (exposed as theme.adjust)
- business judge: identity guard (title and recipient as required roles); body-top reserving space for background bands; overlap check against the address window; footer as a region hosting blocks, content and functions (#18) with a block catalogue as parts
- maintainer judge: reserved zones cover marks and stationery and move the footer above the zone (built); QR-bill as a frame part fed by root; required-parts validation; no region inference in 0.5.0; drop the frame view's totals = ctx.global
- api-consistency judge: singular theme namespace with theme.layout and theme.custom sub-namespaces; functions only for invoice(theme:); wrap marker documented as a plain dict; layout patches rejected inside themed

DECISIONS:

- The layout is always the bottom layer and looks patch only standard region names: any look works on any layout (28/28 verified), with no preset matrix
- Only one named argument, layout:, since swap is exactly what Typst's .with replacement does; all others panic, which kills the verified .with traps and precedence inversion
- invoice(theme:) accepts only lazy themes; calling a theme is idempotent (called == .with); a dict panics with a pointer to from-data
- Presets classic/modern/minimal/plain on default layouts; DIN is just theme.layout.din-5008-a/b
- The schema is written once with field(default, ..types); defaults and types trees are derived, which removes locale-symmetry's triple writing
- 35 frozen semantic tokens; options provisional with rename aliases; no ref tier, enums, descriptors or dotted keys
- The default zebra is derived as OKLCH(92.88%, 0.4264\*C, h) of the seed and reproduces #e2e8f0 exactly, so a brand colour re-derives the palette while the default look is kept
- Part signature (ctx, view); wrap (ctx, view, inner) composes across preset, brand, user and themed layers; theme.adjust re-parameterises inner
- The frame is core-owned and not replaceable; regions give the freedom; compliance output (metadata, lang, XML, notes decision, EPC, identity and recipient roles) is outside parts
- Stationery is one switch that drops brand regions whatever renders them; reserved zones cover marks and move the footer above them
- Sealing is an internal optimisation, gated by a 0.14.0 CI benchmark; parts see an unsealed ctx.theme dict, so zero-import packages can read tokens
- Stay on Typst 0.14.0; the assets loader replaces path(); no region inference until the Swiss and French masks are verified

UNRESOLVED:

- Nothing was run on typst 0.14.0; lazy hashing of metadata (the basis of sealing), query() in page furniture and image field access need the M0 CI job
- SN 010130, NF Z 11-001 and UK millimetre values are unverified against postal masks and remain experimental; the maintainer must decide whether to obtain the standards
- View v2 (value/text records, notes decided in measure) and the table rewrite are specified but not built; the prototype still adapts the v1 line-items view and the old table defects (spacer-column gap, '(net)' colour)
- Panic when the reserved zone plus relocated footer fits on no page, the sizes.fine >= 6pt check and the rename-alias hint are specified but not built
- The fixpoint resolver silently accepts self-consistent cycles (for example darkening black); decide whether to also forbid cycles structurally
- Maintainer calls listed in the appendix: singular theme namespace, for-region timing, new sender legal keys, locale page-label key, deleting the hidden elegant/vibrant/luxury/informational variants, view v2 freeze scope, a loom opaque-value release, the adjust name, default-look drift from the footer and continuation header

PROTOS: <session>/proto-synthesis/src/utils/patch.typ, <session>/proto-synthesis/src/theming/, <session>/proto-synthesis/tests/matrix.typ, <session>/proto-synthesis/tests/p2-stationery.typ, <session>/proto-synthesis/tests/walk.typ, <session>/proto-synthesis/tests/third-party.typ, <session>/proto-synthesis/tests/coverage.typ, <session>/proto-synthesis/tests/errors/err.typ, <session>/proto-synthesis/tests/bench-150.typ, <session>/proto-synthesis/out/
