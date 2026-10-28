# loom 0.1.1 as enabler / limiter for an invoice-pro Theming API

Researcher focus: the loom engine. All loom paths are relative to
`%LOCALAPPDATA%/typst/packages/preview/loom/0.1.1/` (abbreviated `loom:`), all invoice-pro paths relative to
`<repo>/` (abbreviated `ip:`). Prototypes live in
`<session>/proto/loom-capabilities/`
(abbreviated `proto:`), compiled with typst 0.15.1. Every "VERIFIED" tag below refers to a prototype that actually compiled (or failed) as described.

Package facts: loom 0.1.1, entrypoint `src/lib.typ`, min compiler 0.14.0, ~2800 lines of pure Typst (`loom:typst.toml`). No state, no `context`, no introspection anywhere in the engine - it is a pure recursive function over content.

---

## 1. The loom model

### 1.1 Instance construction

`loom.construct-loom(<label>)` (`loom:src/lib.typ:43`, `loom:src/lib/factory.typ:36-57`) returns a dictionary

```
(weave: ...,
 motif: (plain, managed, compute, data, content),
 prebuild-motif: (debug, apply, static))
```

where every function is pre-bound with `key: <label>`. invoice-pro builds its instance in `ip:src/loom-wrapper.typ:1-22`:

- key is `<invoice-pro:0.4.2>` (`ip:src/loom-wrapper.typ:3`) and is intentionally bumped on every release (`ip:.agents/skills/bump-version/SKILL.md:20-23`).
- invoice-pro does NOT use loom's prebuilt `apply`; it ships its own (`ip:src/loom-wrapper.typ:18-22`): a `compute-motif` whose scope is `ctx => ctx + args.named()` (shallow) and whose measure passes children frames through.
- `eval-content(ctx, it)` (`ip:src/loom-wrapper.typ:24-34`) calls `loom.core.intertwine(ctx, content, key: loom-key, draw: true).at(0)` to weave arbitrary content (or the result of a function) at draw time with a given ctx.

A motif is nothing but `[#metadata((type: "component", scope:, measure:, draw:, body:))<key>]` (`loom:src/data/primitives.typ:32-52`). The engine recognises a component only if the node is `metadata`, carries exactly the instance label, and its value has `type: "component"` (`loom:src/core/engine.typ:31-50`).

VERIFIED (`proto:t10-foreign-key.typ`): a motif built with a different key (`<invoice-pro:0.5.0>`) inside a `<invoice-pro:0.4.2>` weave is silently ignored - it is left in the output as invisible metadata; no error. Consequence for a theme ecosystem: a third-party theme package that imports a _different_ invoice-pro version and emits motifs (e.g. `dynamic(...)` in a footer) would silently render nothing. Themes that are pure data + plain functions `(ctx, data) => content` have no such coupling.

### 1.2 `weave` (`loom:src/core/runtime.typ:30-128`)

Signature:

```
weave(key: <motif>,
      injector: (ctx, payload) => (global: payload),
      debug: false,
      inputs: (:),
      handle-nonconvergence: (ctx, iterations, last-payload, current-payload) => none,
      max-passes: 2,
      observer: none,
      director)            // the content tree
```

Flow:

1. `base-ctx = empty-context + inputs` where `empty-context = (sys: (path: (), debug: false, relative-id: 0))` (`runtime.typ:64`, `loom:src/core/context.typ:26-32`). Then `sys.debug`, `sys.key` are set (`runtime.typ:65`). Note: `inputs` is merged shallowly at top level - an input named `sys` would clobber the system namespace.
2. Measure loop: `measure-limit = max-passes - 1` (`runtime.typ:70`). For each measure pass: `sys.pass = "measure"`, `ctx += injector(ctx, current-payload)`, then `intertwine(ctx, director, draw: false)` yields the new payload (the normalized array of frames emitted by the top of the tree) (`runtime.typ:73-98`).
3. Convergence check `new-payload == current-payload` only runs for `i > 0` (`runtime.typ:86`); `handle-nonconvergence` only fires when `measure-limit > 1` (`runtime.typ:93-95`).
4. Final draw pass: `sys.pass = "draw"`, injector is applied with the last payload, `intertwine(..., draw: true)` (`runtime.typ:101-110`). IMPORTANT: the draw pass re-runs scope AND measure for every component, then draw (see 1.3).

With `max-passes: 2` (what invoice-pro uses, `ip:src/invoice.typ:323-330`): exactly ONE measure pass (payload `()` injected, so `global` is empty) plus ONE draw pass (payload of pass 1 injected). No convergence check ever happens. invoice-pro's injector is `ctx + (global: payload.first(default: (:)).at("signal", default: (:)))` (`ip:src/invoice.typ:326-328`), i.e. `ctx.global` = public signal of the `root` motif from the previous pass = `(total, formated-total, bank)` (`ip:src/components/root.typ:137-141`).

`observer:` is BROKEN in 0.1.1 - typo `engine.interwine` (`runtime.typ:117`). VERIFIED (`proto:t5b-observer.typ`): `error: module engine does not contain interwine`. Do not design around observers.

### 1.3 `intertwine` - the traversal (`loom:src/core/engine.typ:66-227`, public as `loom.core.intertwine`)

`intertwine(ctx, node, key:, draw: false) -> (content, array<frame>)`. Five cases:

| Case      | Condition                                                                       | Behaviour                                                                                                                                                      | Lines   |
| --------- | ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| Component | metadata + label == key + `type: "component"`                                   | lifecycle below                                                                                                                                                | 84-129  |
| Container | `node.has("children")` (sequence, grid, table, stack, list...)                  | each child visited with `sys.relative-id = index`; sequence -> joined; other containers rebuilt via `(node.func())(..fields-without-children, ..new-children)` | 132-169 |
| Wrapper   | `node.has("body")` (block, box, align, table.cell, strong...)                   | body visited, element rebuilt from `node.fields()`; `alignment/angle/dest/count` are moved to positional                                                       | 172-198 |
| Generic   | `node.has("child")` (notably `styled`, i.e. anything after a `set`/`show` rule) | child visited, rebuilt as `func(..args, child, styles)`                                                                                                        | 201-223 |
| Atomic    | everything else                                                                 | returned as-is when drawing                                                                                                                                    | 226     |

Component lifecycle (order matters for theming):

1. `child-ctx = (component.scope)(ctx)`; `relative-id` reset to 0 (`engine.typ:89-90`). Scope sees ONLY the inherited ctx - no children data.
2. Body is traversed with `child-ctx` - i.e. **children are fully measured AND DRAWN before the parent's measure/draw run** (`engine.typ:94-99`).
3. `(public, view) = (component.measure)(child-ctx, children-frames)` (`engine.typ:111`). Runs in every pass including the draw pass.
4. If `draw`: `content = (component.draw)(child-ctx, public, view, body-content)` (`engine.typ:122-126`).
5. Returns `(content, frame.normalize(public))` - public must be `none`, a frame, or (nested) arrays of frames, otherwise panic "Loom Data Contract Violation" (`loom:src/data/frame.typ:120-143`).

Data-flow summary:

- DOWN: only via `scope` -> ctx. A parent's `draw` cannot hand anything to its children (they are already drawn). `root`'s draw-time ctx extension (`ip:src/components/root.typ:282-296`: `references`, `items`, `item-data`, `payment-goal`, `bank`) is therefore visible only to `theme.document` and to header/footer woven through `eval-content`, never to body components.
- UP: only via `measure`'s `public` (frames/signals). Siblings cannot see each other in the same pass.
- ACROSS PASSES: only via `injector` (`global`).
- `draw` output is NOT re-traversed. Whatever a draw/theme function returns is final Typst content. (Motifs inside it must be woven manually with `eval-content`.)

### 1.4 Motif kinds (`loom:src/data/primitives.typ`)

| Kind    | Constructor                                          | scope                                         | measure signature -> return                                                                          | draw signature                                                               | Emits frame?                          | Lines   |
| ------- | ---------------------------------------------------- | --------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------- | ------- |
| plain   | `motif(scope:, measure:, draw:, body)`               | `ctx => ctx`                                  | `(ctx, children) => (public, view)` or `none`; validated by `_is-measure`                            | `(ctx, public, view, body) => content \| none`                               | only if `public` is a frame / frames  | 64-121  |
| managed | `managed-motif(name, scope:, measure:, draw:, body)` | auto `path.append(ctx, name)` then user scope | same, but `public` is auto-wrapped: `frame.new(kind: name, key: path.last(), path:, signal: public)` | same; `public` is the FRAME (use `public.signal`)                            | always                                | 132-198 |
| compute | `compute-motif(name: none, scope:, measure:, body)`  | user                                          | `(ctx, children) => public` (view = none); default passes children through                           | default (returns body)                                                       | passthrough / managed if `name` given | 206-242 |
| data    | `data-motif(name, scope:, measure:)`                 | user                                          | `ctx => public`; no body, leaf                                                                       | none                                                                         | always (managed)                      | 250-282 |
| content | `content-motif(scope:, draw:, ..body)`               | user                                          | auto: passes children frames through                                                                 | `(ctx, body) => content`; NOTE `draw: none` renders NOTHING (body swallowed) | passthrough                           | 290-328 |

Frames: `(type: "frame", kind:, key:, path:, signal:, sys: (:))` (`loom:src/data/frame.typ:27-53`). Paths are arrays of `(kind, relative-id)` (`loom:src/data/path.typ:37-52`); helpers `path.get/append/to-string/contains/parent/parent-kind/parent-is/depth/current/current-kind`.

invoice-pro usage pattern (all themable components are identical in shape):

```
managed-motif("signature",
  scope: ctx => loom.mutator.batch(ctx, { ...; nest("theme", { ensure("signature", (..) => panic(...)) }) }),
  measure: (ctx, _) => (none, view-data),
  draw: (ctx, _, view, ..) => (ctx.theme.signature)(ctx, view),
  none)
```

(`ip:src/components/signature.typ:19-44`; same in `bank-details.typ:96-100,143`, `payment-goal.typ:34,55`, `line-items.typ:131-133,500`; root: `ip:src/components/root.typ:71,312`.) So today `ctx.theme` is a flat dict of render FUNCTIONS (`document, header, footer, line-items, bank-details, payment-goal, signature` - VERIFIED in `proto:t7-invoice.typ`), produced by calling `theme()` before weave (`ip:src/invoice.typ:180,291`), and the slot contract is `(ctx, view[, body]) => content`.

### 1.5 Prebuilt motifs (`loom:src/lib/motifs.typ`)

- `apply(..named, body)` (83-109): scope = `context.scope(ctx, k: (v, v))` for every non-`auto` arg => shallow top-level replace. invoice-pro's own `apply` is equally shallow.
- `debug(display: auto, body)` (35-67): prints children frames.
- `static(body)` (121-130): draws `body` without traversing it.
- `loom.core.scope(ctx, key: (value, fallback) | (value:, default:))` (`loom:src/core/context.typ:49-74`): `value != auto` -> set; `auto` + key present -> inherit; `auto` + missing -> fallback. Top-level keys only.

### 1.6 `loom.mutator` (`loom:src/lib/mutator.typ`) - immutable dict transactions

`batch(target, ops)` (37-62): `ops` is an ARRAY of closures `(state, read) => state` with `state = (base:, patch:)`; result is `base + patch`. Every op constructor returns a one-element array, so a Typst code block `{ put(..); if c { ensure(..) }; nest(..) }` joins them into one array (VERIFIED `proto:t3-mutator.typ` #8). All leaf ops accept an optional leading key path (`..path, key, value`) that is auto-wrapped in `nest` ops (95-102).

| Op                                          | Semantics                                                                                                     | Lines                                          |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `put(..path, key, value)`                   | overwrite                                                                                                     | 110-128                                        |
| `ensure(..path, key, default)`              | set only if current value `== none` (missing OR explicitly `none`)                                            | 134-157                                        |
| `derive(..path, key, value, default: none)` | `value == auto` -> `ensure(key, default)`, else `put(key, value)`; THE "auto = inherit" primitive             | 166-190                                        |
| `update(..path, key, fn)`                   | `fn(current)`; quirk: skipped if key exists only in the patch (216)                                           | 202-222                                        |
| `remove(..path, key)`                       | delete                                                                                                        | 227-247                                        |
| `merge(..path, dict)`                       | shallow merge                                                                                                 | 254-269                                        |
| `merge-deep(..path, dict)`                  | per key `collection.merge-deep(current, val)`: dicts recurse, everything else (incl. arrays, `none`) replaces | 277-299, `loom:src/lib/collection.typ:110-132` |
| `ensure-deep(..path, defaults)`             | recursive "fill missing"; existing non-dict values win; `none` counts as missing (335)                        | 321-356                                        |
| `nest(key, ops)`                            | run sub-batch on `target.at(key)`; a non-dict current value is REPLACED by `(:)` (86)                         | 76-104                                         |

VERIFIED gotchas (`proto:t3-mutator.typ`, all asserts pass):

1. `ensure`/`ensure-deep` cannot distinguish "missing" from an explicit `none`. A user token `stripe: none` ("turn striping off") is overwritten by the default when defaults are applied with `ensure-deep`. `merge-deep(defaults <- user)` preserves the `none`. => For a token tree: start from defaults and `merge-deep` the user values on top; do NOT `ensure-deep` defaults under user values (or reserve another sentinel than `none` for "off").
2. `merge-deep` deep-merges dict-valued tokens (e.g. `inset: (x:, y:)`, stroke dicts, margin dicts). There is no "replace this dict wholesale" escape hatch. A non-dict value replaces a dict and vice versa.
3. `nest("theme", ...)` wipes a non-dictionary `theme` value (e.g. a string preset name or a function) - `ctx.theme` must be a dictionary by the time components run.
4. `derive(k, none, ...)` stores `none` (a real value); only `auto` means inherit.
5. Function values are legal everywhere (patch values, ctx values).

Also available: `loom.collection.{get, map, merge-deep, omit, pick, compact}` (`loom:src/lib/collection.typ`) - `get(root, ..path, req-type:, default:)` is a safe nested getter (treats `none` as missing).

### 1.7 `loom.matcher` - see section 5 for the full reference.

### 1.8 `loom.guards` (`loom:src/lib/guards.typ`)

`assert-inside / assert-not-inside / assert-direct-parent(ctx, ..kinds)`, `assert-root(ctx)`, `assert-max-depth(ctx, n)`, `assert-has-key(ctx, key, msg:)`, `assert-value(ctx, key, ..allowed)`. They `panic` (or return `false` when `ctx.sys.test == true`, 23-29).

VERIFIED (`proto:t11*.typ`): `assert-value` message: ``Context key `variant` has invalid value `"fancy"`. Expected one of: "compact", "regular"``. `assert-root` is buggy - it ALWAYS fails, even at the root, because `path.parent` defaults to `(none, none)`, never `none` (`guards.typ:126`, `path.typ:103-110`).

### 1.9 `loom.query` (`loom:src/lib/query.typ`)

Operate on the `children` frame array inside `measure`: `select/select-signals(children, kind)`, `where/where-signals(children, pred)`, `find/find-signal(children, kind, default:)`, `collect/collect-signals(children, kind:, depth: 10)` (recursive through frames nested in signals), `pluck`, `sum-signals`, `group-by/group-signals`, `fold`.

---

## 2. What a theming system can build on

### 2.1 ctx inheritance = scoped theme overrides (CSS-like cascade) - VERIFIED

`proto:t1-scoped-override.typ` (output `proto:t1-out-1.png`, values extracted with `typst eval query(<probe>)`):

| Probe position                                                                        | accent | font-size | table.radius |
| ------------------------------------------------------------------------------------- | ------ | --------- | ------------ |
| root (`inputs: (tokens: (accent: blue, font-size: 10pt, table: (radius: 2pt, ...)))`) | blue   | 10pt      | 2pt          |
| inside shipped `apply(tokens: (accent: red))`                                         | red    | MISSING   | MISSING      |
| inside custom deep scope `token-scope(accent: green, table: (radius: 9pt))`           | green  | 10pt      | 9pt          |
| nested `token-scope(accent: purple)`                                                  | purple | 10pt      | 9pt          |
| sibling after the nested scope                                                        | green  | 10pt      | 9pt          |
| after everything                                                                      | blue   | 10pt      | 2pt          |

Conclusions:

- Subtree-scoped overrides work and are properly isolated from siblings - loom gives a real cascade for free.
- The shipped `apply()` (both loom's and invoice-pro's) is SHALLOW: `apply(theme: (...))` replaces the entire `theme` dict. VERIFIED on a real invoice (`proto:t7-invoice.typ`): inside `apply(theme: (signature: f))` the ctx theme keys collapse to `["signature"]`; a `line-items` in that subtree would fall back to the `[Line Items]` placeholder ensured at `ip:src/components/line-items.typ:131-133`.
- A deep-merging scope wrapper is 5 lines of public loom API:
  ```
  #let themed(..overrides, body) = compute-motif(
    scope: ctx => loom.mutator.batch(ctx, loom.mutator.merge-deep("theme", overrides.named())),
    measure: (_, children) => children,
    body)
  ```
  VERIFIED in the real invoice (`proto:t7-invoice.typ`): `themed(signature: custom-fn)[#signature()]` swaps one render slot for one subtree, all other slots intact, the next `#signature()` outside is back to default.

### 2.2 Two cascades can be driven by one wrapper - VERIFIED (`proto:t12-dual-cascade.typ`, `proto:t12-out-1.png`)

A plain `motif` can merge tokens in `scope` (ctx cascade, read by components) AND wrap the already drawn body with Typst `set`/`show` rules in `draw` (Typst style cascade, affects everything rendered below, including output of child components, because child content is nested inside the parent's draw output). This is how `theme.document` already styles the whole invoice (`set text(font: font)` at `ip:src/themes/DIN-5008/document.typ:80`). Typography/spacing tokens can therefore be applied ONCE via set rules instead of being read in every component.

Function-valued tokens work: `accent-soft: t => t.accent.lighten(75%)` resolved at read time follows a scoped override of `accent` automatically (lazy derived tokens). Verified in the same prototype.

### 2.3 Mutators for defaults / inheritance

- `derive(key, value, default:)` is exactly the package's existing "`auto` = inherit from parent/ctx" idiom (`ip:src/components/line-items.typ:94-108`, `bank-details.typ:85-93`). A component argument like `item(..., style: auto)` or `line-items(stripe: auto)` maps 1:1 onto it.
- `ensure(..path, key, default)` is what components use today to guarantee their render slot exists (`nest("theme", { ensure("signature", ...) })`).
- `merge-deep("theme", overrides)` = partial override; `ensure-deep("theme", defaults)` = fill-in (mind the `none` gotcha, 1.6).

### 2.4 Matchers for schema validation

Already the package-wide validation idiom: `types.require(value, "scope::name", ..patterns)` (`ip:src/utils/types.typ:5-24`) = `assert(match(value, choice(..patterns)), message: "variable `name`(repr) must be of <display(pattern)>")`, with reusable named patterns in the same file (`decimal-like`, `text-like`, `tax-type`, `party-type`...). A token schema can be written "by example" as a nested dict of types/choices (section 5). `matcher.switch/case` is a natural shorthand normaliser (e.g. `length | color | stroke | none` -> stroke) - VERIFIED `proto:t2-matcher.typ` #6.

### 2.5 Data flowing UP that a theme may need - VERIFIED

`proto:t7-invoice.typ` (DIN-5008, custom `footer:` content): a page FOOTER containing `#dynamic("global", "formated-total", "due")` prints `242,00 EUR`, and a probe inside it reports `ctx.global.total.due == decimal("242.00")`, `ctx.sys.pass == "draw"`. So in the draw pass every component, every theme slot and header/footer content (woven with `eval-content`, `ip:src/themes/DIN-5008/document.typ:157-158`) can read aggregated totals through `ctx.global`, although they are laid out "before" the items. What is available is exactly what `root` publishes (`ip:src/components/root.typ:137-141`: `total`, `formated-total`, `bank`). Anything else a theme might want document-wide (item count, has-discounts, has-bank-details, tax breakdown, payment-goal, currency) must be added to root's public signal to become visible to body components; `theme.document` + header/footer additionally get `items`, `item-data`, `payment-goal`, `bank`, normalized `references` (`root.typ:282-296`).

`ctx.sys.pass` ("measure"/"draw") lets code distinguish the provisional pass.

### 2.6 Content motifs for themable user content

- `content-motif(draw: (ctx, body) => ...)` is a draw-only, ctx-aware leaf/wrapper: `dynamic` (`ip:src/components/dynamic.typ:40-41`) is one. A public `themed-block`, `token("color.accent")`, `dynamic(ctx => ...)`-style helper that lets USER content read theme tokens is trivial to build.
- `eval-content(ctx, content-or-function)` makes any user-supplied slot content (header, footer, notes, custom blocks) "live": motifs inside are woven with the ctx at that point, including theme tokens and `global`.
- VERIFIED (`proto:t9-labels-context.typ`): `intertwine`/`eval-content` is a pure function and can be called INSIDE `context { }` / `layout(size => ...)`. So a layout-aware theme slot can still host live motifs.
- VERIFIED (same file): labels placed on DRAW OUTPUT work normally - `show <probe-box>: ...` restyles content produced by motifs. A theme could expose stable labels (e.g. `<invoice-total>`) as styling hooks for power users.

### 2.7 Function values in ctx are fine

Already used: `ctx.theme.*` render functions, `ctx.locale.format.*` formatters (`ip:src/components/line-items.typ:113-127`). Closures compare/hash structurally in Typst, so they do not break the payload equality check either.

---

## 3. Hard limits

### 3.1 No layout information inside loom's data flow

loom never uses `context`. VERIFIED (`proto:t4-limits.typ` a): a value produced with `context here().page()` inside `measure` has type `content` - opaque, cannot be compared or put into arithmetic. Hence: page number, page count, remaining space, measured sizes can NOT influence signals, ctx, totals or which slot is chosen by loom. They CAN influence drawing: a draw/theme function may return `context { ... }`/`layout(...)` content (VERIFIED `t4` g). Features such as per-page carry-over/subtotals ("Uebertrag"), "continued on next page", different first-page header are only implementable with Typst introspection inside the render function (state/counter/query/`table.header(repeat)`), never from loom data.

### 3.2 Motifs inside opaque constructs are silently dropped - VERIFIED (`proto:t4-limits.typ`, `proto:t4-out-1.png`)

Visited: plain sequence, `grid`/`table` children, `table.cell`, `block/box/align` wrappers, list/enum items, content after a `set` rule and after a `show: fn` rule (styled -> case 4).
NOT visited (no error, the motif just vanishes): inside `context [...]`, inside `layout(size => ...)`, inside named content fields such as `figure(caption: ...)`, `page(header:/footer:/background:)`, `table(header: ...)`-like named args. Theme code that places user content into such positions must weave it explicitly with `eval-content` (as base-theme/DIN-5008 do for header/footer). Signals emitted inside eval-content'ed content are lost (`.at(0)` drops the frames) - header/footer content can read data but not contribute to it.

### 3.3 Labelled containers crash the engine - VERIFIED (`proto:t9b-label-crash.typ`)

`#block[... #motif ...] <my-label>` (or any labelled element that has `body`/`children`/`child`, including `#text(fill: ..)[..] <l>` which is a `styled`) inside the woven body fails with `error: unexpected argument: label` at `loom:src/core/engine.typ:193` / `:218`, because `node.fields()` contains `label` and is splatted back into the constructor. Labelled atomic text is fine. A theming concept must not ask users to label containers in the invoice body as styling hooks (labels on draw output are fine, see 2.6) unless loom is patched.

### 3.4 Order of evaluation: parent draw comes last

Children are drawn before the parent's measure/draw (`engine.typ:94-126`). A theme slot (called from a parent's draw) receives finished `body` content; it can wrap/style it (set/show rules, containers) but cannot re-parameterise children. Everything children need must be in ctx at scope time. Scope functions do not see children data.

### 3.5 Passes / convergence with `max-passes: 2` - VERIFIED (`proto:t8-passes.typ`)

- Pass 1 sees an empty `global`; the draw pass sees pass-1 data. Scope and measure run twice per node, draw once.
- Second-order dependencies are stale: with a component whose signal depends on `global.total`, the root's draw-pass view is 13 while a header reading `ctx.global.total` still shows 10; with `max-passes: 3` both show 13. invoice-pro already has one first-order dependency of this kind (`bank-details.payment-amount` / `payment-goal.total` read `ctx.global.total.due`, `ip:src/components/bank-details.typ:126`, `payment-goal.typ:50`).
- Rule for the theme design: theme tokens/slots must never change DATA signals based on aggregated data; presentation-only reactions to `ctx.global` in the draw pass are safe. Raising max-passes costs one full tree evaluation per pass.

### 3.6 Performance: cost is proportional to ctx size x closure calls - VERIFIED

- `proto:t6d-closure-hash.typ`: 5000 calls of a trivial closure: 255 ms with a small arg, 2290 ms when one argument is a 20 000-entry dict (~20 ns per dict entry per call; Typst hashes closure arguments for memoization). `content` (312 ms) and `bytes` (298 ms) values of the same size are cheap because they are lazily hashed.
- `proto:t6-perf.typ` (800 leaf motifs, injector reduced to a count): baseline 0.77 s; +2000 tokens in ctx: 1.4-1.6 s; +20 000 tokens: 8.9 s (nested under one key) / 13.9 s (20 000 top-level keys). Nesting under ONE `theme` key is cheaper than flattening into top-level ctx keys (the engine clones the top-level dict per sequence child to set `sys.relative-id`, `engine.typ:138-139`).
- `proto:t6c-perf-weave.typ`: loom's DEFAULT injector `(global: payload)` puts every frame into ctx and makes weave quadratic (1600 leaves: 9.2 s vs 0.9 s with a small injector). invoice-pro's injector only injects the root signal - keep it that way; never inject large collections (e.g. all items) into ctx for body components.
- Real numbers today (`proto:t7-invoice.typ`): ctx has 30 top-level keys / 275 leaf values (109 of them locale). A theme of a few hundred tokens adds single-digit milliseconds. Per-node re-application of a big default tree (`ensure-deep` of 2000 tokens in every scope) doubled total time in the synthetic test - resolve defaults ONCE (before weave or in root scope), let components only `ensure` their own slot.
- Logos/images as `content` or `bytes` inside the theme are fine; big plain arrays/dicts/strings are not.

### 3.7 Call-depth budget - VERIFIED

Typst's call-depth limit is hit by nesting, each motif level inside a markup body costs 3 frames (component -> sequence -> map closure). `proto:t5-depth.typ`: 24 nested `apply[...]` levels OK, 25 fail (`maximum function call depth exceeded`); without sequences 70 OK/75 fail. Inside a real invoice (`proto:t5c-depth-invoice.typ`): `root > line-items > apply x N > item` works up to N = 19, fails at 20. A theming design that adds ONE wrapper motif per scope is fine; designs that wrap every component in several helper motifs, or deep recursive token resolution inside scope/measure, eat this budget.

### 3.8 Matcher limits (details in section 5)

Boolean only (no path to the failing leaf), all record keys required (no optional), no ranges/predicates, functions only checkable as `function`, `display` not exported by loom 0.1.1.

### 3.9 Misc

- ctx is ONE flat namespace shared by inputs and component-internal keys (`tax`, `text`, `reference`, `show-column`, `input-gross`, ... e.g. `ip:src/components/bank-details.typ:87-93`). `sys` is reserved. Theme data should live under a single namespaced key (`theme`), optionally with sub-dicts (`theme.tokens`, `theme.slots`...).
- `theme()` is evaluated BEFORE weave with no arguments (`ip:src/invoice.typ:180`); it cannot see locale/sender/ctx. Anything ctx-dependent must happen lazily in slot functions or in root's scope.
- `set page(...)` from a scoped override cannot change page geometry mid-document without a page break (Typst semantics); page-level tokens are effectively document-global.
- Side finding (VERIFIED with the first version of `proto:t7-invoice.typ`, `themes.blank.with(header: [...])` rendered no header): in `ip:src/themes/base-theme/base.typ:35-40` the `set page(header: ...)`/`set page(footer: ...)` rules sit inside `if { }` blocks, so they are scoped to that block and have no effect. Only DIN-5008's own footer path (`document.typ:157-158`) works. Header/footer slots of the base theme are currently dead code.
- loom README limits (`loom:README.md`, "Limitations"): vertical-only flow, ~50 levels recursion, opaque named fields, show rules run after loom and cannot create motifs.

---

## 4. Prototype index (all under `proto:`)

| File                                           | Claim verified                                                                                                                                                 | Result                                                                                            |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `t1-scoped-override.typ` (+`t1-out-1.png`)     | nested scope overrides a ctx key for a subtree; draw reads it; shipped `apply` is shallow; `merge-deep` scope is deep                                          | pass, table in 2.1                                                                                |
| `t2-matcher.typ`                               | 17 matcher semantics asserts on a nested token schema (strict, partial, type quirks, switch) + display strings                                                 | compiles, all asserts pass                                                                        |
| `t2b-matcher-error.typ`                        | error message of `types.require` for a nested dict                                                                                                             | fails as intended, message in 5.4                                                                 |
| `t2c-matcher-error-leaf.typ`                   | 12-line custom walker gives per-leaf path, allows partial dicts, rejects unknown keys                                                                          | fails as intended, message in 5.4                                                                 |
| `t3-mutator.typ`                               | ensure/ensure-deep `none` gotcha, merge-deep semantics, derive, nest wipe, update quirk, op arrays                                                             | all asserts pass                                                                                  |
| `t4-limits.typ` (+`t4-out-1.png`)              | `context` in measure is opaque; motifs in `context`/`layout`/`figure(caption:)` are dropped; grid/table.cell/wrappers/set/show/list OK; draw may use `context` | visited probes: plain, grid-a, grid-b, cell, wrapped, after-set, after-show, list-item, enum-item |
| `t5-depth.typ`, `t5c-depth-invoice.typ`        | nesting budget                                                                                                                                                 | 24 / 19 levels                                                                                    |
| `t5b-observer.typ`                             | `weave(observer:)` broken                                                                                                                                      | error `interwine`                                                                                 |
| `t6-perf.typ`, `t6b`, `t6c`, `t6d`             | ctx-size cost model                                                                                                                                            | numbers in 3.6                                                                                    |
| `t7-invoice.typ` (+`t7-small-1.png`)           | real invoice: footer reads total due (data up), scoped render-slot override via deep scope, shallow apply wipes slots, ctx size                                | pass                                                                                              |
| `t8-passes.typ`                                | measure re-runs in draw pass; one-generation staleness with max-passes 2                                                                                       | pass                                                                                              |
| `t9-labels-context.typ`, `t9b-label-crash.typ` | eval-content inside `layout`, show rules on draw-output labels; labelled container crash                                                                       | pass / crash                                                                                      |
| `t10-foreign-key.typ`                          | motif with another loom key is silently ignored                                                                                                                | pass                                                                                              |
| `t11-guards.typ`, `t11b-guards.typ`            | guard messages; `assert-root` always fails                                                                                                                     | as described                                                                                      |
| `t12-dual-cascade.typ` (+`t12-out-1.png`)      | one wrapper motif driving ctx cascade + Typst set-rule cascade + lazy derived token                                                                            | pass                                                                                              |

Run any of them with: `cd <proto> && typst compile --root . loom-capabilities/<file>.typ loom-capabilities/out-{p}.png`.

---

## 5. Matcher API reference (`loom:src/lib/matcher.typ`, public via `loom.matcher`)

Public exports (`loom:src/public/matcher.typ:1-3`): `any, case, choice, dict, exact, instance, many, match, switch`. NOT exported: `display` (exists at `matcher.typ:286-335`); invoice-pro carries a verbatim copy in `ip:src/utils/display-matcher.typ` ("Can be import in later versions when display is published", l.1-2).

### 5.1 Entry points

| Function               | Signature                                                                          | Returns                                                                            | Lines   |
| ---------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------- |
| `match`                | `match(value, expected, strict: false)`                                            | `bool` only                                                                        | 154-230 |
| `switch`               | `switch(target, cases)` - `cases` is an array built by joining `case(...)` results | result of first matching case's transform, or `none` when nothing matches (silent) | 260-275 |
| `case`                 | `case(pattern, transform, strict: false)` - `transform: value => result`           | one-element array                                                                  | 235-246 |
| `display` (not public) | `display(pattern)`                                                                 | `str`                                                                              | 286-335 |

### 5.2 Patterns "by example" (evaluated in this order after descriptors)

| Pattern                                                                                        | Matches                                                                                                                                                                        | Lines   |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- |
| a `type` (`int`, `str`, `color`, `length`, `stroke`, `function`, `content`, `dictionary`, ...) | `type(value) == T`, and also the type object `T` itself                                                                                                                        | 199-203 |
| an array `(p1, p2)`                                                                            | array of EXACTLY that length, element-wise (tuple). `()` matches only the empty array                                                                                          | 206-213 |
| a dictionary `(k: p, ...)` (record)                                                            | value is a dict, EVERY pattern key must be present and match; extra keys allowed unless `strict: true` (strict propagates into nested records/choices). `(:)` matches any dict | 216-226 |
| any other literal (`"bold"`, `1`, `auto`, `none`, `true`)                                      | `value == literal`                                                                                                                                                             | 229     |

### 5.3 Descriptors (dicts tagged with `__loom_matcher_sig__`, `matcher.typ:19-20`)

| Constructor         | Meaning                                                          | display()         | Lines   |
| ------------------- | ---------------------------------------------------------------- | ----------------- | ------- |
| `any()`             | wildcard                                                         | `*`               | 32-35   |
| `choice(..options)` | OR over patterns                                                 | `a \| b \| c`     | 46-54   |
| `many(schema)`      | array of any length, every item matches                          | `array<(schema)>` | 66-74   |
| `dict(schema)`      | dictionary of any size, every VALUE matches (keys unconstrained) | `dict<(schema)>`  | 86-94   |
| `exact(value)`      | strict equality (use to match a type object itself)              | display of value  | 108-116 |
| `instance(type)`    | strict `type(value) == type` (does not accept the type object)   | `<type>`          | 129-137 |

### 5.4 What errors look like

loom's matcher never produces a message; invoice-pro's `types.require` does. VERIFIED output of `proto:t2b-matcher-error.typ` (nested theme dict with `font.size: "10pt"`):

```
error: assertion failed: variable `theme::tokens`((
  color: (accent: rgb("#0074d9"), text: luma(0%)),
  font: (family: "Inter", size: "10pt"),
)) must be of (color: (accent: color | gradient | tiling, text: color | gradient | tiling), font: (family: str | array<(str)>, size: length))
   +- src/utils/types.typ:20:2
  while calling `require` at ...t2b-matcher-error.typ:14:1
```

i.e. whole value `repr` + whole schema, no hint WHICH leaf failed - unusable for a token tree of realistic size. For single leaves the same helper is good, e.g. from `proto:t2c-matcher-error-leaf.typ` (a 12-line recursive walker that calls `match` per leaf and tracks the path):

```
error: assertion failed: token `theme.font.size` ("10pt") must be of length
```

The walker also (a) accepts partial dicts, (b) rejects unknown keys with a "known: ..." list - both impossible with plain `match`.

### 5.5 Limits and quirks relevant for a token schema (all VERIFIED in `proto:t2-matcher.typ`)

1. No optional keys: `match((color: (accent: red)), schema)` is `false` when the schema has more keys. Validate AFTER merging with defaults, or validate per leaf with a custom walker.
2. Unknown keys pass silently unless `strict: true` (typos like `colour:` go unnoticed by default). `strict` is all-or-nothing for the whole nested pattern.
3. Boolean result only; no path, no reason.
4. Typst type granularity: `1pt` is `length`, not `stroke`; `1em + 10%` is `relative`, not `length`; paints are three types (`color | gradient | tiling`). Token schemas need `choice(...)` unions and usually a normalisation step (`switch/case`).
5. `switch` returns `none` when no case matches - add a final `case(any(), v => panic(...))`.
6. Functions are only checkable as `function` - no arity/signature validation for render slots; wrong arity surfaces as a Typst call error inside the component's draw.
7. No numeric ranges, regex or custom predicates (would need a new descriptor type; `match` ignores unknown descriptor types and falls through to record matching).
8. A user dict can never be confused with a descriptor unless it contains the key `__loom_matcher_sig__`.
9. `dict(schema)` constrains values only - good for open maps such as `columns: dict(choice(auto, bool))` or `slots: dict(function)`.

---

## 6. Implications for the theming concept (condensed)

1. Keep ALL theme data under one ctx key (`theme`), as a plain nested dictionary (tokens + slot functions); cheap to pass, compatible with `nest/ensure/merge-deep`, and with the existing `nest("theme", { ensure(slot, ...) })` idiom in every component.
2. Scoped overrides need a new deep-merging wrapper motif (`themed(...)[...]`/a fixed `apply`), because the shipped `apply` replaces the whole dict. One wrapper can also emit Typst set rules for the subtree.
3. Resolve defaults once (before weave or in root scope) via "defaults <- preset <- user" `merge-deep`; avoid `ensure-deep` for tokens where `none` is meaningful.
4. Derived tokens: either eager resolve after each merge, or lazy function-valued tokens `(tokens) => value`; both work in ctx.
5. Validate tokens with matcher patterns per leaf through a small path-tracking walker (reuse `types.require`'s message style and `display`), not with one big `match`.
6. Slots stay `(ctx, view[, body]) => content`; they may use `context`/`layout` and `eval-content` for live user content, but must not expect layout data in ctx, must not place user content with motifs into named fields/context blocks without `eval-content`, and must not feed presentation decisions back into signals.
7. Expose more document-level facts in root's public signal if themes should react to them in body components (only `total`, `formated-total`, `bank` today).
8. Third-party themes should be data + functions, not motif-emitting code bound to a specific invoice-pro version (loom key is versioned).
9. Known loom 0.1.1 bugs to route around or fix upstream (same author): observer typo, labelled-container crash, `assert-root`, `update` on patch-only keys, `display` not exported.
