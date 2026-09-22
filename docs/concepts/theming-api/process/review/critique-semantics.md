# Critique of concept draft 1: internal consistency and semantic precision

Critic key: `semantics`. Object: `scratchpad/concept/draft-1.md` (read in full).
Prototype copy: `scratchpad/crit-semantics/` (a copy of `proto-synthesis`). Probe files are in `crit-semantics/crit/`:
`sem.typ`, `sem2.typ`, `chain.typ` (run with `typst query --root . crit/<f>.typ "<o>" --field value --input case=<k>`), and
`pagesall.typ` (run with `typst compile --root . crit/pagesall.typ crit/pa-<k>-{p}.png --input case=<k>`). All runs used typst 0.15.1.

Evidence labels: **VERIFIED** means I reproduced it. **SOURCE** means I read it in the prototype code. **REASONED** means it is an argument only.

## Verdict in one paragraph

The architecture holds up, but the draft's semantic vocabulary is not yet precise enough to freeze. `auto` has at least four meanings. The region engine does not follow the merge rules that §4.2 declares, and one walkthrough (P3) depends on that deviation and still panics. Users have no documented way to reset a value to `auto`. The claims "order-free derivation" and "cycles are detected" are both false for realistic inputs. Region patches are not portable across layouts, which undercuts decision 1. The required-role rule accepts layouts that break the tagging and overlap guarantees, and it rejects legitimate recipient-less documents. None of this needs a redesign. It needs about six precise rules written into §2.5, §4.2 and §4.3, plus a handful of prototype fixes, before the 0.5.0 lock.

---

## Blockers

### SEM-1: `auto` means four different things, and the region helper contradicts the helper rule (VERIFIED)

Where: §2.5 rule 2 ("every parameter defaults to `auto` (untouched)"), §4.2 row 1 ("`auto`: untouched, at every depth"), §3.3/§3.4 (`body-top: auto`, `x/right/y/bottom/width/height: auto`, `reserve: auto`), §3.5 (`header-text: auto`, `page-number.format: auto`), §2.2 (`layout: auto`), §4.1 (component args "`auto` = inherit"), and P3 line 752.

The four meanings:

1. **Untouched** in patches (§4.2).
2. **Computed or absent** as a stored schema value (region anchors, `body-top`, `reserve`, `header-text`, `format`).
3. **Reset to the preset default layout** on the `layout:` argument. `.with(layout: us-letter-10).with(layout: auto)` resolves to `din-5008-a` (probe `sem.typ case=layout-auto-reset` returns `"din-5008-a"`). That is a reset, not "untouched".
4. **Inherit from the theme** for L5 component arguments (§4.1).

The prototype implements meaning 1 for every helper except `region()`:

- `custom.typ:180-185` passes `args.named()` without `clean-auto`.
- `layout-ops.typ:28` merges with shallow `existing + rv`.
- So `region("address", width: auto)` **overwrites** a DIN width of 85 mm with `auto` (full paper width). The overlap lint then fires: `sem2.typ case=width-auto` panics with "`info` overlaps the address window region `address`".
- `region("info", none), region("address", x: auto, right: 20mm)` returns `x: auto, right: 56.69pt` (`case=x-auto-no-overlap`). Here `auto` means "set to auto".

Walkthrough P3 (line 752) documents this "set" meaning (`region("address", right: auto, x: 22mm)`), which contradicts §2.5. On `sn-010130-right` the recipe **panics anyway**: the moved window overlaps the layout's own `info` region at x = 22 mm (`sem.typ case=p3-left`).

Why it blocks: the difference between switching an anchor and leaving it untouched is exactly what a user needs when adapting a window. Today the answer depends on which helper they call, and it is undocumented.

Fix:

- Declare one rule. **In patches, `auto` means untouched, everywhere, including `region()`.** Make `region()` use `clean-auto`.
- Add an explicit **`theme.custom.reset`** (or `unset`) marker that stores the schema default, which for these fields is `auto`. See SEM-2.
- Add an **anchor-switch rule**: setting `x` on a fixed region automatically clears `right`, and vice versa. The same applies to `y`/`bottom`, since the pairs are "exactly one of the two" anyway. Then `region("address", x: 22mm)` is enough to switch sides.
- Fix P3 to remove or move `info`: `region("info", x: 118mm)` together with `region("address", x: 22mm)`.
- Rename the `layout:` sentinel in the documentation to "preset default" and state that it is a reset.
- Give §4.1 its own sentence explaining that component-argument `auto` means inherit.

### SEM-2: No documented way to reset a value to `auto`; `replace(auto)` works only by accident and fails on regions (VERIFIED)

Where: §4.2 (`replace(v)`: "wholesale"), §3.3 `body-top`, §3.5 `header-text`.

- `page(body-top: 60mm), page(body-top: auto)` resolves to `170.08pt`, so it cannot be reset (`sem.typ case=reset-bodytop`).
- The same holds for `items-table(header-text: red)` followed by `header-text: auto` (`case=reset-headertext`).
- `replace(auto)` does reset both, because `merge` unwraps the marker before its `auto` check (`patch.typ:119-120`). The draft does not document this.
- On regions `replace(auto)` is stored **as the marker dict** (no `merge` runs), and validation then fails with "needs exactly one of `x` or `right`" (`case=region-replace`).
- `from-data` cannot express a reset at all (`data.typ:6`, "files cannot express `auto`").

This is a real use case: looks or brand packages set `header-text`, `body-top` or an anchor, and a user or a later layout needs the computed behaviour back.

Fix:

- Specify `theme.custom.reset()` as a first-class marker, honoured by `merge` **and** by region patching.
- Allow `"auto"` in data files as the reset spelling. The coercion table already treats `"none"` specially.
- Add a row to §4.2: "`reset` stores the schema default (often `auto`)".

### SEM-3: Region patches bypass the declared merge engine (shallow `+`); §4.2 is wrong for the most-used group (VERIFIED)

Where: §4.2 ("dict onto dict: recurse, unlimited depth", "region patch on an existing name: field-wise merge"), §3.4 (`text`, `inset`, `arrange` are dicts).

`layout-ops.typ:28` performs `existing + rv`. That is one level only, and markers are not interpreted.

- `theme.modern.with(region("letterhead", text: (size: 8pt)))` gives `text: (size: 8pt)`. The look's `fill: t => t.colors.on-primary` is **silently lost**, so the band text reverts to black on the primary colour (`sem.typ case=region-text-shallow`).
- `region("address", inset: (top: 2mm))` on DIN gives `(top: 5.67pt)`. The DIN `left: 5mm` inset is lost, and the recipient block shifts inside the window (`case=region-inset-shallow`).
- The draft's own visual caveat (§10) recommends exactly this patch: `region("address", inset: (top: ..))`.
- Region field _values_ are also never type-checked at patch time. Only `place`, `pages`, anchors and `parts` are validated (`validate.typ:61-78`). `fill: "red"` or `gap: 3` reach the renderer.

Fix:

- Route region fields through `merge` with rules: `inset` is a sides-fold path, `text` is a recursive open dict, `arrange` is replace.
- Add region field types to the schema (`field(default, ..types)`) so region patches get the same `::` type errors as tokens.
- State in §4.2 which region fields fold, which recurse and which replace.

### SEM-4: Region patches are not portable across layouts, contrary to decision 1 and §4.1 (VERIFIED)

Where: Exec summary decision 1 ("Every patch ... is re-applied on top of it ... any look works on any layout"), §4.1 ("region patches apply to whatever region results"), §3.4 ("`info`, `references` and reserved zones are optional").

The CI matrix only guards the **built-in looks**. A brand or company patch that touches an optional region panics when the layout is swapped:

- `theme.modern.with(region("info", fill: luma(240)))` fails with "has no region `info` in layout `a4-digital` ... To ADD a region, give it a `place`" (`sem.typ case=info-on-digital`).
- `region("info", none)` on a4-digital fails with "cannot remove a region the layout does not have" (`case=info-none-on-digital`). So the natural "hide the info block" brand tweak is not layout-neutral.
- Removal followed by a re-patch is incoherent: `region("info", none), region("info", y: 40mm)` fails with "has no region `info` ... **Did you mean `info`?**" (`case=remove-then-patch`). The removed name stays in the map as `none`, and did-you-mean suggests it.
- Geometry patches _do_ survive swaps silently. A DIN-tuned `region("address", x: 22mm)` is re-applied onto `us-letter-10` millimetres without a warning. "Layout is L1" therefore means "every user geometry patch is layout-blind" (REASONED).

P2's patch is reused in P8 on another layout. That works only because it does not touch optional regions, and the draft does not tell users about this constraint.

Fix. Specify one of the following:

- (a) Every standard **and** optional name exists in every built-in layout (possibly as `none`). Patching a `none` region is a no-op and `region(n, none)` is idempotent.
- (b) Add an explicit `region(name, .., if-present: true)` for portable patches.

Also:

- Define the removed state: after `region(n, none)`, a field patch on `n` is either ignored or treated as "add" with a clear message. It should never produce the self-referential hint.
- Document that geometry patches are layout-specific. Recommend `theme.layout.derive` for geometry and L2/L3 patches only for style fields, and consider linting geometry keys in patches that are applied after a `layout:` swap.

---

## Majors

### SEM-5: "Order-free" derivation is false: round-0 placeholders crash valid derivations, and a 6-round cap reports acyclic chains as cycles (VERIFIED)

Where: Exec summary decision 3, §4.3 steps 1-4 ("order-free", "cycles are detected"), `resolve.typ:8-13, 30-45`.

- **Placeholders crash.** Round 0 substitutes type-neutral zeros (`0pt`, `""`, `black`).
  - `sizes(large: t => t.sizes.base * 1.2, title: t => 1em * (t.sizes.base / t.sizes.large))` fails with **`cannot divide by zero`** (`sem2.typ case=div0`).
  - `fonts(body: t => t.fonts.heading.first(), heading: t => ("Inter", ..))` fails with **`string is empty`** (`case=fontstr`).
  - Both derivations are correct and acyclic, so whether they work depends on evaluation order, which is exactly what "order-free" promises to hide. Typst cannot catch panics, so the resolver cannot recover.
- **The cap misreports.** An acyclic 6-link chain (muted → subtle → label → rule → mark → negative → positive) panics with "derivations do not settle after 6 rounds (a derivation cycle ...)" (`chain.typ`). The message also does not list the unsettled paths, although the code comment promises it (`resolve.typ:28`).
- The acknowledged "self-consistent cycles are accepted" (§11) is a third non-obvious behaviour.

Fix:

- Seed round 0 with the **resolved default token tree**, computed once from the schema. It is known to be safe and stable, so placeholders never produce zero or empty values.
- Set the round cap to the number of derivation leaves + 1, which guarantees convergence for every acyclic graph, instead of 6.
- On failure, list the leaves that still change between the last two rounds.
- Rewrite §4.3 to state the real contract: "a derivation must be total over any well-typed token tree".

### SEM-6: The rule "a function is a derivation unless the types include `function`" is decidable only for schema leaves; open maps, region fields and markers fall through (VERIFIED)

Where: §3 intro, §4.3 last sentences.

- **`options.custom`** (the third-party option namespace) is typed `dictionary`, so its inner leaves are never visited. `options: (custom: (acme: (fill: t => t.colors.primary)))` reaches the part as a **function** (`sem.typ case=custom-derivation`). Third-party parts would each have to resolve derivations themselves, inconsistently.
- **Region fields.** `resolve-region` hard-codes `fill`, `stroke` and the values of `text` (`resolve.typ:51-63`). It does not look at the types, even though `parts` and `arrange` legitimately hold functions. §3 says "marked layout fields" but the schema marks nothing. `marks.stroke` is special-cased separately (`build.typ:55-57`).
- **Callback fields escape type-checking entirely.** `check-types` skips any leaf whose types include `function` (`resolve.typ:85`), so `page-number(format: "Seite")` is accepted (`case=fn-unchecked`) and only fails when rendered. Array leaves are not element-checked either: `items-table(zebra: ("red", 12))` passes (`case=zebra-unchecked`). So the claim "literal leaves are type-checked before derivations" is only partly true.
- **Markers are interpreted at any path.** A wrap marker under `options::title::fill` is composed into `(ctx, view) => ..` and then called as a derivation, which fails with "missing argument: view" (`case=wrap-in-options`).
- **Options cannot derive from options** ("derive once from the resolved tokens"). That is why `header-text` needs a render-time `auto`. The asymmetry is not stated.

Fix:

- Make the derivation marker **schema-declared**: `field(default, color, derivable: true)`, also for region fields. Resolve derivations recursively in open maps (`options.custom`).
- Type-check callbacks as `function` with an arity note, and check array elements with an `array<T>` type.
- Accept wrap and replace markers only under `parts` (wrap) and at dict-valued paths (replace). Panic elsewhere with a path.
- State in §3.5 that options see tokens only.

### SEM-7: `themed` and `adjust` scope semantics are underspecified: frame parts are silently unaffected, `adjust` accepts ineffective patches, and cost claims omit `adjust` (VERIFIED / SOURCE)

Where: §2.6, §4.1 L4 ("tokens/options/parts/checks"), §4.4 ("`themed` re-resolves once per scope per loom pass"), §2.4/§5.1 `adjust`.

- **Frame parts are unaffected, silently.** `themed(wrap("title", ..))[#body()]` renders with no effect and no error (`pagesall.typ case=themed-title`: the "SCOPED" marker is absent in `pa-themed-title-1.png`). The frame draws from root's document ctx (`frame.typ:107`). The same applies to `themed(title(..))`, `themed(logo(..))` and `themed(page-number(..))`. The draft rejects layout patches in `themed`, but frame parts and options are just as unreachable.
- **`adjust` accepts part patches it cannot honour.** `theme.adjust(ctx, part("totals", ..))` is accepted (`sem.typ case=adjust-parts`), but `inner` is already bound, so the patch does nothing. Wraps inside `adjust` have the same problem.
- **Cost.** `scope-theme` re-runs the **whole** `finalize` (`build.typ:118-122`): layout validation, required roles, the overlap lint, asset checks and contrast. `adjust` does this **on every invocation of the wrapper**, so a wrap on a running-region part re-resolves the theme once per page, and wraps on `totals` once per render. §4.4 accounts only for `themed`. Re-checking layout roles inside a scope that cannot change the layout is wasted work.
- **Re-derivation scope.** §2.6 says "derived tokens re-derive". The code also re-derives options and region fills (`finalize` runs everything). This is harmless but should be stated, because an option set as a derivation at document level changes inside a scope and a literal one does not.
- **Wrap stacking.** The prototype's order is L2 look < L3 in call order < L4 innermost-last, and `part()` at any layer discards every earlier wrap. This is correct but written nowhere except "wraps stack across L2-L4". A zero-import package cannot contribute an L2 look; `pkg.patch` is always L3, interleaved with user patches by position (REASONED).

Fix:

- Reject, in `themed` and `adjust`, patches to frame-called parts and to their options, with a message such as "frame parts are document-level". Alternatively, specify that the frame is re-rendered per scope. It cannot be, so rejection is the right choice.
- Restrict `adjust` to `tokens`, `options` and `checks`.
- Give `scope-theme` a light finalize (tokens, options, types) without layout validation.
- Add a §4.1 table for wrap order and for "`part` resets the wrap stack".
- Optionally let `build-theme` accept a package look without importing, as a documented plain-dict convention.

### SEM-8: The required-role rule is both too weak (it lets untagged and overlapping recipients through) and too strong (no recipient-less documents) (VERIFIED)

Where: §3.6 ("`recipient` hosted exactly once on page 1 or in the flow"), §5.3 ("tagged, reading order"), `validate.typ:57-59, 88-98`, `frame.typ:153, 185`.

**Too weak.**

- `is-page1-content` counts a fixed region with `pages: "all"` as page-1 content. The frame, however, renders only `pages == "first"` fixed regions in the flow. Fixed regions with `"all"` go to the **foreground as artifacts** on every page, page 1 included.
- `theme.classic.with(region("address", pages: "all"))` therefore passes the guard. The recipient is untagged on page 1, and on page 2 it **overprints the line-items table** (`pa-all-2.png`: "Muster AG / Beispielweg 5" printed over rows 22-25).
- `body-top` auto-reserve also ignores fixed regions with `"all"` (`frame.typ:124`).
- "Exactly once" counts **regions**, not pages or occurrences.

**Too strong.**

- A layout with no recipient always panics (`pagesall.typ case=norecip`: "must host part `recipient` in exactly one first-page or flow region (found 0)"). There is no escape hatch.
- A Kleinbetragsrechnung (§ 33 UStDV, ≤ EUR 250) legally needs no recipient, and receipts and POS slips are a stated R-class of "any format".
- The sidebar receipt in walkthrough 9 only passes because it hosts the recipient.
- A layout where the address legitimately repeats on every page (a statement or remittance style) is either rejected ("exactly one") or, via `pages: "all"`, falls into the "too weak" case above.

Fix:

- Make the role's requirement a **core decision in measure**, like `notices.required`: `required = env.kind == "invoice" and not small-amount and recipient != none`.
- Define "hosted" precisely: at least one tagged occurrence on page 1 (a flow region, or a fixed region with `pages: "first"`). Additional occurrences in artifact regions are allowed. Fixed regions with `pages: "all"` or `"not-last"` that host a required role should render in the flow on page 1 and as artifacts afterwards, and should reserve `body-top`.
- Document the receipt path explicitly: `plain` or `receipt` layout + small-amount ⇒ recipient optional.

### SEM-9: The frame-view contract in §3.8 differs from what the prototype passes, and built-in parts already depend on the difference (SOURCE)

Where: §3.8 ("`layout`, `region`: `(name, width, height)`", "Parts must not read `ctx.global`").

- `frame.typ:43` passes `layout: layout`, the **full resolved layout dict**.
- The built-in `marks` part reads `view.layout.marks` (`parts/frame.typ:142`). That field is not in the contract, so the only documented way to get mark geometry is non-contract.
- "Must not read `ctx.global`" is unenforced. Parts receive the full ctx, including `global`, `item-data` and so on (`body.typ:15-24`, `frame.typ:52-53`).
- The frame view's `totals` are derived from `ctx.global.total` in root (`frame.typ:21-41`). Core may read internals, but §3.8 says the view is built "no `ctx.global`". The sentence should say "parts receive no `ctx.global`".

Fix:

- Either freeze `view.layout` as the resolved layout (then it is part of the contract) or add `view.marks` and keep `layout` as `(name, width, height)`.
- Strip internal keys from the ctx that is handed to parts (a whitelist: `theme`, `locale`, `...`), or state that reading them is unsupported and will break.
- Reword §3.8 as above.

### SEM-10: "Reserved zones relocate the footer instead of dropping it" holds only for footers on `"all"` or `"last"`, and the page number is always dropped (VERIFIED)

Where: Exec summary grafts (maintainer judge), §3.4 `float`, §5.3 last row, §6 regulated zones, P3 ("legal footer moves above it").

- `frame.typ:140` suppresses **every** footer on the page that carries the reserved zone.
- `frame.typ:206` relocates only footers with `pages in ("all", "last")`. A footer on `"rest"`, `"not-last"` or `"first"` is dropped: with `sn-010130-right` + `region("footer", pages: "rest")` + 30 items, page 3 of 3 has neither footer nor page number (`pa-footer-rest-3.png`).
- Relocated regions get `view.page: none` (`frame.typ:207`), so the `page-number` part returns `none` (`parts/frame.typ:123`). The QR-bill page therefore never shows "Page n of n".

Fix:

- Define relocation as "every footer region whose `pages` matches the current page is relocated".
- Pass the real `(current, total)` into the relocated view. This can be computed in `context` inside the floated block.
- Add both to the "specified, not yet built" list.

---

## Minors

### SEM-11: Some of the "35 frozen tokens" have no consumer, and one is contradicted by a layout field (VERIFIED / SOURCE)

- `colors(mark: red)` leaves the marks black. `layout.marks.stroke` is a literal `0.25pt + black` in every layout and in the template (`layouts.typ:22,58`, `schema.typ:330`), and `colors.mark` is read nowhere (`sem.typ case=marks-token`; grep finds no reader).
- No built-in renderer reads `on-accent`, `fonts.numeric`, `fonts.figures` (R4 "tabular"), `weights.regular`, `spacing.xs`, `spacing.lg` or `strokes.hairline` (grep over `src/`, excluding `schema.typ` and `custom.typ`).
- Freezing tokens that nothing honours creates silent no-ops.

Fix: set the marks default to `stroke: t => t.strokes.hairline + t.colors.mark`. Either wire every token into at least one built-in part before M6, or move the unused ones to provisional.

### SEM-12: `none` has five meanings, and the draft lists only two (REASONED / SOURCE)

The five meanings:

1. **Off** (leaf values).
2. **Remove** (a region).
3. **Hide** (`part(name, none)` on optional parts).
4. **Template-able empty group** (`layout.marks`).
5. **Ignored** (a `none` entry in a patch list).

Two specific pitfalls:

- `marks(none)` disables the marks, but the `marks` region stays. `region("marks", none)` removes the region but leaves `layout.marks` set.
- `surface: none` means "no zebra" at token level, while `zebra: (none, ..)` means the same at option level.

Fix: add a four-row "`none` means ..." table to §4.2. Say explicitly that templates exist only for `layout::marks`, and that re-hydration (patching a group that is currently `none`) is keyed by path, not by value.

### SEM-13: The region `pages` default of `"first"` applies to running and background places too (SOURCE)

`region-defaults.pages = "first"` (`schema.typ:314`). So a new `region("legal", place: "footer", parts: (..))` appears on page 1 only. Most users would expect a footer on every page, as the built-in footers declare explicitly.

Fix: make the default place-dependent (`header`/`footer`/`background`/`foreground` ⇒ `"all"`, `fixed` ⇒ `"first"`), or require `pages` for new running regions.

### SEM-14: "Looks never patch geometry" is undefined (SOURCE)

The `modern` look patches the letterhead `inset`, and `minimal` patches the footer `arrange` (`presets.typ:227,235`). Whether `inset`, `arrange`, `gap`, `height` or `align` count as geometry decides what third-party looks may do, and it determines what the CI matrix guarantees.

Fix: list the look-safe region fields explicitly (for example `fill`, `stroke`, `text`, `inset`, `arrange`, `gap`, `align`) and forbid the rest (`place`, `pages`, anchors, `width`, `height`) in a look lint.

---

## What the draft gets right (checked, no finding)

- The idempotent called form and the chained later-wins behaviour work (coverage test).
- The shared `merge` engine is strict at every depth for tokens and options, and its did-you-mean hints work.
- `notices` is refused when `none` and outside the replaceable composite (source).
- Stationery visibility is applied before the role check (`validate.typ:86`).
