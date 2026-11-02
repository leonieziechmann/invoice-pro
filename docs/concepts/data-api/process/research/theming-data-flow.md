# Research: How data reaches the theme

Phase-1 reader `theming-data-flow` of the data-API exploration (2026-11-02). Facts marked [v] were verified (read or run), [i] are inferences. `<repo>` is the repository root, `<session>` the scratch directory of the exploration (not part of the repository).

## Summary

The theme is resolved once in invoice(), before loom runs. At that point it only sees `env` (kind, lang, region, e-invoice; src/invoice.typ:409). Token and option derivations are `t => value` over tokens only, so tokens, options and layout cannot depend on invoice data. Data reaches design only at render time, through parts `(ctx, view) => content` or wrappers `(ctx, view, inner) => content`. Frame parts get the unsealed root ctx (34 keys) plus a frame view whose `sender`/`recipient` hold the full normalized party: `post-code`, `city-name`, `country`, and any unknown keys passed in. Body parts get a narrow view per component (signature: only `name`, `signature`) and no party data, unless they read `ctx.recipient`, which the contract calls internal. A coat of arms by postal code already works today, verified four ways and on both compilers: (1) a prefixed custom part reading `view.recipient.post-code`; (2) `wrap("logo")` that swaps `ctx.theme.options.logo.image` and calls the built-in renderer — portable, since every built-in layout hosts `logo` (checked on all 10 presets under strict validation); (3) a function cell in an area; (4) `info.get(..)` in the body. The variant table can even come from a brand file via `options.custom.<pkg>` and `theme.custom.from-data`. For custom fields there is no top-level hook: `invoice(custom: ..)` fails with "unexpected argument", and `item(x-acme: ..)` is rejected. Unknown party keys, though, pass silently into ctx and the views, even with ZUGFeRD and strict validation — the docs say unknown keys stop the build. A minimal additive extension, `invoice(data: none | dictionary)` sealed in metadata and unsealed by `unsealed()` and `dynamic._draw`, gives parts `ctx.data` and the body `info.get("data", ..)`. Prototyped in a copy: about 10 lines in 3 files. Sealing matters: a 2000-entry payload carried unsealed in `ctx.recipient` more than doubles compile time (3.3 s → 7.8–8.5 s for 200 items); sealed it costs the same as no payload. Constraints: layouts, areas, renderers and rules stay code, and from-data deliberately has no expression language. Packages cannot open user file paths (verified), so assets referenced by data need an `assets: p => image(p, ..)` resolver defined in the user's file. One side effect: any data-driven part, wrap or cell sets `prints-of(..).page-content` to true, which silences the e-invoice "is it printed" findings (checked to see whether the printed invoice shows what the XML states).

## Key facts

- [v] Part contract: renderer `(ctx, view) => content`, wrapper `(ctx, view, inner) => content`; only ctx.theme and ctx.locale are public ctx keys, every other key is internal; parts 'read only ctx.theme, ctx.locale and view'. (src/theming/custom.typ:273-279; src/utils/patch.typ:149; docs/docs/api-reference/theme/parts.md:11-19,51; docs/concepts/theming-api/README.md §5.1 (~line 598-625))
- [v] The theme is resolved before weave, once per invoice() call, and sees only env = (kind, lang, region = sender's country, e-invoice). Derivations are functions over resolved TOKENS (`t => value`), so tokens, options and layout cannot read invoice data. The only resolve-time 'data' hook is the layout resolver `env => layout`. (src/invoice.typ:409-418; src/theming/build.typ:245-258 (\_pick-layout), 155-243 (finalize); src/theming/schema.typ:6-9; src/theming/resolve.typ:1-20)
- [v] Frame parts receive the unsealed root draw ctx (render-frame calls unsealed(ctx)) and the frame view built by frame-view() plus `area`, and `page` in running areas. Dumped view keys: area, bank, currency, document, layout, marks, page, payment, recipient, references, sender, totals. ctx had 34 keys (bank, items, item-data, payment-terms, recipient, sender, global, theme, locale, validation, ...). (src/theming/frame.typ:106-170 (frame-view), 283-320 (render-area adds view.area), 880-888 (render-frame); experiment ex2-ctx-dump.typ output)
- [v] view.sender / view.recipient are the normalized party (`p + (name, name-inline, lines)`). normalize-party returns `party + (...)`, so post-code, city-name, state, country (a record), country-explicit AND every unknown input key (e.g. `x-acme`) reach view.recipient and ctx.recipient. post-code is parsed from `city: "80331 München"`, or taken from a structured `city: (post-code:, name:)` dict. (src/theming/frame.typ:50-69 (\_party); src/logic/country.typ:814-985 (normalize-party, 857 dict city, 958-984 build); ex2 dump: view.recipient keys include post-code and x-acme; ex6 with city dict renders '80331 München')
- [v] Body parts are called by call-part(ctx, name, view) with the unsealed component ctx (30 keys at the signature) and a narrow view per component: signature view = (name, signature) only. Body views carry no party/recipient data. (src/theming/parts/body.typ:1-35 (view doc), 64-109 (call-part); ex2 dump 'body part (signature) ... view keys: name, signature')
- [v] info.get / dynamic(..path | ctx => ..) traverses ANY ctx path in the body, e.g. info.get("recipient", "post-code") and info.get("recipient", "x-acme", "tarif"). Area content cells are woven, so info.\* also works inside areas. (src/components/dynamic.typ:25-230; src/theming/frame.typ:200-203 (eval-content); docs/docs/api-reference/components.md:330-345; ex1 body line 'Ihr Bezirk: Altstadt – PLZ 80331 – Tarif: Grundversorgung')
- [v] Coat of arms by postal code works TODAY with a prefixed custom part (`acme/wappen`) hosted in the letterhead and reading view.recipient.post-code. `--input plz=10115` switches München → Berlin. (exp/theming-data-flow/ex1-custom-part.typ; renders ex1-muc-1.png, ex1-ber-1.png)
- [v] wrap("logo", (ctx, view, inner) => { ctx.theme.options.logo.image = asset(path); inner(ctx, view) }) swaps the logo by post code and keeps the built-in renderer (height, on-dark plate). The post-code→path table came from brand.toml under options.custom.acme.arms via theme.custom.from-data. It works on all 10 presets under validation: "strict". (exp/theming-data-flow/ex3-wrap-logo.typ + brand.toml (ex3-strip.png: 80331 blue, 10115/20095 red, 50667 default grey); ex10-portable-wrap.typ (ex10-grid.png, 10/10 presets); every built-in layout hosts "logo": src/theming/layouts.typ:217,292,342,394,431,493,579,715,729,821)
- [v] options.custom is an open, uninterpreted namespace (field((:), dictionary)) in the merge rules' `open` list. from-data allows the `options` group, so a data file can ship lookup tables that parts read via ctx.theme.options.custom.<pkg>. (src/theming/schema.typ:156, 187, 325-331; src/theming/custom.typ:368-399; docs/docs/api-reference/theme/customization.md:184)
- [v] theme.custom.from-data(data, assets:) takes a PARSED dict (not a path). It coerces strings (#hex→rgb, 10pt/25mm→length, 66%→ratio, "none", "auto"→reset()), has no eval and no expression language, allows only tokens/options/checks and the scalar layout keys (paper, margin, body-top, body-gap, footer-clearance), and refuses areas/layouts/stationery ('are code'). Path strings go through a user-file `assets` callback because packages cannot open user paths. (src/theming/custom.typ:313-416; docs/docs/api-reference/theme/customization.md:253-309)
- [v] Precedent for a unified data file: walkthrough P4 puts [theme.*] (brand) and [sender] in one TOML and splits them as `from-data(e.theme, assets: ..)` and `sender: party.sender + e.sender`. (docs/concepts/theming-api/README.md:1052-1090)
- [v] A package cannot open a file path given by the user document: json(p) inside a package searches the package dir. Verified on 0.15.1 and 0.14.2. sys.inputs IS readable inside a package (precedent: invoice-pro-validation, ip-seal). (exp/theming-data-flow/ex7-package-paths.typ: 'file not found (searched at pkgs/local/probe/0.1.0/data-muc.json)'; src/theming/access.typ:5)
- [v] invoice() rejects unknown top-level args (`invoice(custom: ..)` → 'unexpected argument: custom'), and item() rejects unknown named args (`x-acme`). Unknown keys inside sender/recipient dicts are NOT rejected, even with zugferd: "en16931" + validation: "strict", although the docs say 'Misuse such as unknown keys always stops the compilation'. (ex4-unknown-arg.typ; ex9-item-custom.typ; ex5-zugferd-unknown-keys.typ (exit 0, PDF/A-3b written); docs/docs/api-reference/invoice/index.md:151; docs/docs/api-reference/invoice/validation.md:96)
- [v] themed(..) patches are static values; a scope cannot read ctx data. It rejects layout patches, frame parts and the frame options logo/title/page-number/continuation, so a coat of arms cannot be switched by themed. (src/theming/scope.typ:13-45; src/theming/build.typ:25, 64-84; ex10 with --input themed=1 → panic 'themed: `options::logo` belongs to the page frame')
- [v] Any data-driven decoration (a wrap of logo, a hosted custom part, a function cell) sets prints-of(theme).page-content = true. The e-invoice 'printed?' checks (IP-PRINT-03 seller tax ID, IP-PERIOD-03 supply date) then return none (unknown) instead of false and stop reporting. (src/theming/prints.typ:24-56; src/logic/printed.typ:54,137; ex11-prints.typ output: classic false, wrap logo true, custom part true, function cell true)
- [v] Theme validation of the logo (lint/logo-alt) runs once at resolve time on options.logo.image, so a logo swapped at render time by a wrap or part is never checked for alt text. (src/theming/validate.typ:550-566; src/theming/build.typ:239)
- [v] Sealing precedent: the resolved theme travels in ctx as opaque metadata, because loom hashes ctx per call. invoice() adds rarely used keys to ctx only when given ('each value it carries costs time on long invoices'). (src/theming/access.typ:1-24; src/invoice.typ:598-617; docs/concepts/theming-api/README.md §4.4)
- [v] Prototype of the minimal extension: `invoice(data: none|dictionary)` → inputs.data = metadata(data); unsealed() and dynamic.\_draw unseal it. Parts then read ctx.data (frame function cell, wrap of the body part signature) and the body reads info.get("data", ..). Payload passed via `--input payload=<json>` and json(bytes(..)). Works on 0.15.1 and 0.14.2. (exp/theming-data-flow/proto/src (diff in raw_notes); ex6-proto-ctx-data.typ → ex6-strip.png)
- [v] A single `--input` value is capped at about 128 KiB on Linux (MAX_ARG_STRLEN): 131000 chars OK, 140000 → 'Argument list too long'. (ex8-arglen.typ run)

## Implications

- Data-dependent APPEARANCE needs no new theming concept. The design side (a variant table: post-code prefix → image; tenant → colour) is Typst code in the skeleton, and the data only supplies the field value (post-code or a selector key like "arms": "muenchen"). The selection runs in a part or wrap at render time. This matches the maintainer's 'design stays in Typst, only data is exchanged'.
- The hydration API should accept a PARSED dictionary (like from-data), not a path: packages cannot open user files. Asset references in data (signature image, coat of arms, logo) need an `assets: path => image(path, alt: ..)` resolver defined in the user's file. Reuse from-data's naming and its coercion rules for strings → lengths/colours/none/auto if any such values appear in data.
- sys.inputs is readable inside the package, so a CLI channel such as `--input invoice-pro-data=<json>` can be consumed by invoice-pro itself. It is capped at about 128 KiB per argument, so large invoices need the skeleton to read a file inside --root and pass the parsed dict on. Both should feed the same hydrate entry point.
- Custom fields need a documented home. Recommended: an additive `invoice(data: none | dictionary)` carried SEALED (metadata) in ctx, exposed as `ctx.data` (a third contract key next to ctx.theme and ctx.locale) and as `info.get("data", ..)` in the body. Optionally also `view.data` in the frame view, and a later `item(data: ..)` for per-line fields (item() rejects unknown args today). This is pure extension; no existing signature changes.
- Sealing is required for speed: unsealed custom payloads are hashed per loom call (2000 entries: ~2.4× slower on 200 items); sealed they cost nothing measurable. Only insert the key when given (the existing invoice.typ:598 pattern).
- Data-dependent decisions add no loom passes: parts run in draw, and theme resolve is ~10 ms per distinct theme (identical themes are memoized). A document-level `if data.x { patch }` in the skeleton is cheap, but only works on RAW fields: the post-code is parsed by core from `city` unless the data supplies `city: (post-code:, name:)`, which normalize-party already accepts. Prefer structured city in the machine format (good for phase-2 bindings too).
- The data format should NOT carry a `theme` section if 'design is not programmatic' is taken literally. from-data stays the separate brand-file API. At most, a data file may carry selector values that pick among design variants defined in Typst. No rule or expression language in data (precedent: from-data refuses eval or expressions, src/theming/custom.typ:313-322).
- Body parts currently have no contract-conforming access to party data (body views lack it). A data-driven body part (e.g. a signature that varies by region) would read ctx.recipient, which is internal. ctx.data, or a frozen ctx.document view, closes this gap.
- Candidate small extension for the exact 'Wappen' use case: allow options.logo.image to be a callback `(ctx, view) => content` (add `function` to the field's types; schema rule: a field whose types include function holds a callback, not a derivation). It works on every layout without wrap/part, keeps the built-in renderer (so prints-of keeps logo 'builtin'), and is additive. It cannot come from data files (functions), which is correct.

## Risks

- Unknown party keys silently pass today, contrary to the docs ('unknown keys always stop the compilation'). If hydration files rely on that pass-through, a later strictness fix breaks them. If strictness is added for the data format, typos like `post_code` must be caught. Decide: a reserved prefix (`x-`/`pkg/`, analogous to the part prefix rule) or a dedicated `data` key.
- Data-driven parts, wraps and function cells set prints-of.page-content = true, which weakens the e-invoice printed-content checks (IP-PRINT-03 / IP-PERIOD-03 become 'unknown'). A coat-of-arms decoration that prints no invoice data should not do that; this may need a 'decorative' flag, or the logo-callback route that keeps `logo` built-in.
- Logos or assets swapped at render time bypass resolve-time lint (lint/logo-alt), so PDF/UA alt text is no longer guaranteed. The check would have to move to render time, or the data path must require alt.
- view.recipient.post-code, city-name and all party fields except name and lines are PROVISIONAL in the frame view (parts.md:107). A hydration contract that builds on them should freeze the ones it relies on.
- Carrying custom data unsealed (e.g. as party keys) is a performance trap: measured 2.4× slower with a 2000-entry payload on a 200-item invoice.
- Naming collisions: `extra` is already PRINTED (sender-details, contact, recipient notes) and counted by prints-of. `custom` is taken by theme.custom (patch DSL), options.custom and country.custom. `data` is the parameter name of from-data and of loom's data-motif (internal). `ctx.data` has no current collision (grep), but documentation must keep the 'brand data' (from-data) and 'invoice data' meanings apart.
- themed() cannot read data, and refuses frame options. Users wanting data-dependent body scopes must write the condition in Typst with the data variable in scope. If hydration hides the data from the skeleton author (package reads sys.inputs itself), ctx.data/info.get becomes the only route.
- Large payloads via --input hit the ~128 KiB argument limit on Linux. Files must sit inside --root.

## Open questions

- Name and placement of the custom-field slot: `invoice(data:)` → ctx.data (prototyped), or `custom`/`fields`, or per-party `recipient.data`? Should party-level custom fields be allowed via a prefix rule (e.g. `acme/tarif`) instead?
- Should `view.data` also be added to the frame view and to every body view (more contract-conforming, more plumbing), or is ctx.data as a third public ctx key enough?
- Per-line custom data: add `item(data: ..)` → view.items[i].data so a replaced items-table can render, say, a meter number per line?
- Should data-driven decorations keep the e-invoice printed checks (a 'decorative' part flag or a logo-callback option), or is the current conservative 'unknown' acceptable?
- Should the hydration format carry a `theme` section (delegated to from-data) at all, given 'design is not programmatic'? Or only selector values that pick among variants declared in the skeleton?
- Should invoice-pro read a reserved `--input invoice-pro-data=<json>` itself (zero-code CLI hydration, ≤128 KiB), or should the skeleton always read the data (file or input) and pass a dict?
- Freeze which normalized party fields (post-code, city-name, country.code, state) become part of the frame-view contract for data-driven parts?
- Allow options.logo.image as a `(ctx, view) => content` callback (additive schema change) as the blessed way to vary the logo per data?

## Measurements

- bench-ctx-payload.typ, `typst compile --root . --input mode=none|plain|sealed --input n=200 --input leaves=2000 bench-ctx-payload.typ out.pdf`: none 4.02/3.23/3.27 s; plain (2000-entry dict in recipient.x-acme) 7.72/8.46/7.79 s; sealed (metadata) 3.46/3.43/3.27 s
- Same with leaves=20: none 3.32/3.25/3.28, plain 3.55/4.16/3.61, sealed 3.76/3.90/3.62 s. leaves=200: none 3.94/3.71/3.43, plain 4.13/4.36/4.56, sealed 4.43/3.92/3.70 s (noise ~±0.4 s)
- Prototype bench-proto-data.typ (`--input mode=none|data|plain --input n=200 --input leaves=2000`): none 3.63/3.33/3.17 s; invoice(data:) sealed ctx.data 3.24/3.64/3.79 s; unsealed in recipient 8.10/8.23/8.13 s
- bench-resolve.typ (`--input n=K [--input same=1]`, theme.resolve(theme.corporate.with(colors(primary: rgb(i,0,0))))): n=0 0.13 s, n=1 0.21-0.26 s, n=21 distinct 0.41-0.43 s (~10 ms per distinct theme), n=21 identical 0.23-0.24 s (memoized)
- ex8-arglen.typ: `--input p=<131000 chars>` compiles; 140000 chars fails with 'Argument list too long' (Linux per-argument limit 128 KiB)
- ex10-portable-wrap.typ, `--input preset=<each of 10>`: data-driven wrap('logo') compiles under validation: "strict" on all 10 presets (10/10 PNGs)
- ex11-prints.typ: prints-of(..).page-content = false for plain classic; true for wrap logo, hosted custom part, function cell

## Notes

#### 1. How parts receive data

##### 1.1 Pipeline (where data and design meet)

```
invoice(..args)                                   src/invoice.typ
 ├─ normalize sender → env = (kind, lang, region, e-invoice)        :409
 ├─ eval-theme = theme(base: schema, env: env)  ← THEME RESOLVES HERE, no invoice data
 │     tokens: derivations t => value over TOKENS only               schema.typ:6-9, resolve.typ
 │     layout: dict or resolver env => layout                        build.typ:245-258
 ├─ normalize recipient / delivery / references
 ├─ inputs = (theme: seal(eval-theme), locale, sender, recipient, invoice-nr, ...)   :563
 │     rarely used keys inserted only if given ("each value costs time")             :598-617
 └─ weave(max-passes: 2, inputs, root(body))                                          :620
       root.scope  ensure() defaults for sender/recipient/...      components/root.typ:108-187
       root.measure collects totals, bank, payment terms
       root.draw    ctx += items, item-data, payment-terms, bank, global      :440-456
                    → render-frame(ctx, body) → unsealed(ctx) → frame parts   frame.typ:880-888
       components (line-items, bank-details, signature...) → call-part(ctx, name, view)  parts/body.typ:64
```

=> **Design decisions that depend on data can only happen at render time, inside parts.** The resolved theme never sees invoice data, only `env`.

##### 1.2 Signatures

| Thing              | Signature                                                                | Source                            |
| ------------------ | ------------------------------------------------------------------------ | --------------------------------- |
| part               | `(ctx, view) => content`                                                 | custom.typ:273-275                |
| wrap               | `(ctx, view, inner) => content`; stacks look → patches → themed          | custom.typ:276-279, patch.typ:149 |
| area cell          | part name \| content (woven, `info.*` works) \| `(ctx, view) => content` | frame.typ:172-204, schema.typ:214 |
| arrange fn         | `(ctx, cells, area) => content` (experimental)                           | frame.typ:210-214                 |
| page-number.format | `(ctx, current, total) => content`                                       | schema.typ:150-153                |
| zebra callback     | `(number) => fill`                                                       | schema.typ:123                    |

Contract: `ctx.theme` + `ctx.locale` public, the rest internal (parts.md:15-19, concept §5.1/§5.2 "Internal: every other ctx key").

##### 1.3 What ctx contains (dumped, ex2-ctx-dump.typ)

- **Frame function cell** (34 keys): bank, contract-nr, customer-nr, delivery-address, delivery-note-nr, due-date, format, global, invoice-date, invoice-nr, item-data, items, locale, order-date, order-nr, payee, payment-reference, payment-terms, preceding-invoice-nr, project, quote-nr, recipient, references, sender, subject, subject-text, sys, tax, tax-exempt-small-biz, tax-mode, theme, validation, zugferd, zugferd-errors.
- **Body part (signature wrap)** (30 keys): the same minus bank/items/item-data/payment-terms (they are added only in root.draw).
- **info.get(ctx => ..)** in the body: same 30 keys.

##### 1.4 Views

**Frame view** (frame.typ:106-170, + `area` from render-area:283-316, + `page` in running areas). Bold = frozen:
| field | content |
|---|---|
| **document**.{kind,title,subject,number,date(value,text)}, place | number and date tagged for the identity check; draft markers |
| **sender/recipient**.{name, lines} + all normalized party fields (provisional) | `_party(p)` = `p + (name, name-inline, lines)` |
| **currency**, references, bank, totals.{net,gross,due,prepaid}(value,text), payment.{days,due} | |
| **page**(current,total), **layout**(name,width,height), **area**(name,place,width,height,window,parts,fill,surface), marks | |

Dumped `view.recipient` keys: address, address-inline, address-lines, city, city-inline, city-name, country, country-explicit, extra, lines, name, name-inline, **post-code**, state, tax-nr, vat-id, **x-acme** (unknown input key passed through!).

**Body views** (parts/body.typ:1-35; parts.md:121-131): line-items/items-table/totals/notes (totals.rows, payable, items, entries, taxes, ...), bank-details (iban, qr, sender, ...), payment-terms (amount, deadline, ...), payment-means, signature (`name`, `signature` only), zugferd-report. **No party data in any body view.** Item view keys (ex9): base-quantity, date, description, discounts, has-\*, item-id, kind, level, name, note, origin, pos, price, quantity, reference, style, surcharge, tax, total, unit, unit-singular, unmodified-total.

##### 1.5 Post-code origin

normalize-party (country.typ:814-985): `city` string → `(resolved-country.parse-city)(city)` → `(name, post-code, state)`. A `city` dictionary is taken as already parsed (country.typ:855-857). Verified: `"city": {"post-code": "80331", "name": "München"}` prints "80331 München" (ex6). The result is `party + (name, address-lines, address, city, *-inline, country, country-explicit, city-name, post-code, state, tax-nr, vat-id)`, so **unknown keys survive**. root.scope `ensure("post-code", none)` (root.typ:121,140).

#### 2. Existing data-driven theming hooks

| Hook                                    | What it allows                                                                                         | Limits                                                                                                          | Source                                                                     |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `theme.custom.from-data(dict, assets:)` | a brand FILE (json/yaml/toml, parsed by the user) → patch: tokens, options, checks, scalar layout keys | no eval, no expressions, no areas/layout/stationery ("are code"); path strings only for logo.image via `assets` | custom.typ:313-416; customization.md:253-309 (experimental)                |
| `options.custom`                        | open, uninterpreted namespace for third-party parts; reachable from data files                         | values not interpreted; parts read `ctx.theme.options.custom.<pkg>`                                             | schema.typ:156,187, rules.open 325-331                                     |
| custom parts `pkg/name`                 | any renderer; must be prefixed AND hosted by an area                                                   | prefix rule panics; unhosted panics                                                                             | validate.typ:457-480; parts.md:57, 186-216                                 |
| function and content cells in areas     | anonymous renderer / woven content (`info.*` works)                                                    | counts as unreadable page content                                                                               | frame.typ:172-204                                                          |
| `wrap(name, fn)`                        | decorate or alter the input of the built-in renderer                                                   |                                                                                                                 | custom.typ:276-279                                                         |
| logo options                            | image, height, on-dark (auto = light plate on dark surface); `brand(logo:)`; lint/logo-alt             | frame option → not allowed in themed                                                                            | schema.typ:105-109; frame parts logo frame.typ:41-59; validate.typ:550-566 |
| `themed(..patches)[body]`               | scoped tokens/options/body parts                                                                       | static patches; rejects layout, frame parts, frame options                                                      | scope.typ; build.typ:25,64-84                                              |
| layout resolver `env => layout`         | layout by sender region                                                                                | env only (kind, lang, region, e-invoice)                                                                        | build.typ:245-258, presets.typ                                             |
| `info.*` / `dynamic` / `info.get`       | any ctx path or `ctx => content` in body and area content                                              | draw-only                                                                                                       | components/dynamic.typ                                                     |
| `apply(..named)[body]`                  | inject ctx keys for a subtree (documented 'power user')                                                | body subtree only, unsealed                                                                                     | loom-wrapper.typ:18-22; components.md:235-273                              |
| P4 walkthrough                          | one TOML with [theme.*] + [sender]                                                                     |                                                                                                                 | concept README:1052-1090                                                   |

#### 3. Coat of arms by PLZ, today (all compiled on 0.15.1 and 0.14.2)

Experiment dir: `<session>/exp/theming-data-flow/`

**(a) custom part** (ex1-custom-part.typ):

```typst
#let arms = ("8": image("arms/muenchen.svg", alt: "Wappen München"), "1": image("arms/berlin.svg", alt: ".."))
#let wappen(ctx, view) = {
  let plz = view.recipient.at("post-code", default: none)
  let a = if plz != none { arms.at(plz.first(), default: image("arms/default.svg", alt: "Wappen")) }
  if a != none { box(height: 14mm, a) }
}
theme.classic.with({ import theme.custom: *
  part("acme/wappen", wappen)
  area("letterhead", parts: ("sender", "acme/wappen"), arrange: (columns: (1fr, auto))) })
```

`--input plz=10115` → Berlin arms. Body: `#info.get(ctx => ctx.recipient.at("x-acme").district)` works.

**(b) wrap logo, table from brand file** (ex3-wrap-logo.typ + brand.toml, preset corporate, strict):

```toml
[theme.options.custom.acme.arms]
"8" = "arms/muenchen.svg"
"1" = "arms/berlin.svg"
```

```typst
theme.custom.wrap("logo", (ctx, view, inner) => {
  let plz = view.recipient.post-code
  let path = if plz != none { ctx.theme.options.custom.acme.arms.at(plz.first(), default: none) }
  if path == none { return inner(ctx, view) }
  let ctx = ctx; ctx.theme.options.logo.image = asset(path); inner(ctx, view) })
```

ex10: the same wrap on all 10 presets, strict → OK. Every built-in layout hosts `logo` (layouts.typ:217,292,342,394,431,493,579,715,729,821), so this is the most portable route.

**(c) function cell**: `area("letterhead", parts: ("sender", (ctx, view) => ..))`, no prefix or registration needed (ex2, ex6).

**(d) body**: `info.get("recipient", "post-code")`.

**(e) document-level Typst** `if d.recipient.city.post-code.starts-with("8") { theme.custom.logo(image: ..) }` works only if the data carries the post-code separately (structured city).

What does **not** work: `themed(theme.custom.logo(..))` → panic "options::logo belongs to the page frame"; `invoice(custom: ..)` → "unexpected argument: custom"; `item(.., x-acme: 5)` → "unexpected argument".

#### 4. Minimal extension for custom fields (prototyped)

Copy at `exp/theming-data-flow/proto/src`; diff vs repo:

```diff
 src/invoice.typ
+  /// custom data invoice-pro does not interpret → ctx.data, info.get("data", ..)
+  data: none,
+  types.require(data, "invoice::data", none, dictionary)
+  if data != none { inputs.insert("data", metadata(data)) }   // sealed, only if given
 src/theming/access.typ  (unsealed)
-  if type(t) == content { ctx + (theme: t.value) } else { ctx }
+  let ctx = if type(t) == content { ctx + (theme: t.value) } else { ctx }
+  let d = ctx.at("data", default: none)
+  if type(d) == content { ctx + (data: d.value) } else { ctx }
 src/components/dynamic.typ  (_draw)
+  let d = ctx.at("data", default: none)
+  let ctx = if type(d) == content { ctx + (data: d.value) } else { ctx }
```

Since frame parts (render-frame) and body parts (call-part) both pass through `unsealed`, `ctx.data` reaches **all parts** with no further plumbing. ex6 verified: frame function cell picks arms by `ctx.data.arms`, a signature wrap adds "★ Premiumkunde" if `ctx.data.vip`, and the body prints `info.get("data", "district")`. The payload also worked via `--input payload='{..json..}'` + `json(bytes(sys.inputs.payload))`. No grep hit for an existing `ctx.data` key.

Possible further steps (not prototyped): `view.data` in frame-view; `item(data:)` → view.items[i].data; a prefix rule for party custom keys; options.logo.image callback `(ctx, view) => content`; a 'decorative' flag so prints-of keeps the e-invoice checks.

#### 5. Constraints: Typst vs data

| Stays Typst (design/code)                                                    | Can be data                                                                        |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| layouts, areas, geometry, stationery (from-data refuses: custom.typ:379-397) | party fields incl. structured city, invoice fields, references, items, notes       |
| renderers/parts/wraps/arrange fns (functions cannot come from data)          | custom fields (ctx.data) and selector keys ("arms": "muenchen")                    |
| rules/conditions (no expression language, no eval: custom.typ:313-322)       | asset PATHS, resolved by a user-file `assets` callback                             |
| derivations `t => ..`                                                        | brand values via from-data (separate API, probably NOT in the invoice data format) |
| opening files (packages cannot: ex7)                                         | lookup tables in options.custom (data, read by code)                               |

#### 6. Measurements (wall time, `date +%s.%N` around `typst compile --root . ...`, typst 0.15.1)

- `bench-ctx-payload.typ --input n=200 --input leaves=2000 --input mode=…` (200 items; payload = 2000 entries × (a, b) in recipient.x-acme):
  - none: 4.02 / 3.23 / 3.27 s
  - plain (unsealed in recipient): 7.72 / 8.46 / 7.79 s
  - sealed (metadata in recipient): 3.46 / 3.43 / 3.27 s
  - leaves=20: none 3.32/3.25/3.28, plain 3.55/4.16/3.61, sealed 3.76/3.90/3.62 (noise ±0.4 s)
  - leaves=200: none 3.94/3.71/3.43, plain 4.13/4.36/4.56, sealed 4.43/3.92/3.70
- Prototype `bench-proto-data.typ` (leaves=2000, n=200): none 3.63/3.33/3.17; **ctx.data sealed 3.24/3.64/3.79**; plain-in-recipient 8.10/8.23/8.13.
- `bench-resolve.typ` (theme.resolve of corporate+colour patch): n=0 0.13 s; n=1 0.21-0.26; 21 distinct 0.41-0.43 (≈10 ms per distinct theme); 21 identical 0.23-0.24 (memoized).
- `--input p=<N chars>`: 131000 OK; 140000 → bash "Argument list too long" (Linux MAX_ARG_STRLEN 128 KiB).

#### 7. Side effects found

- prints-of (prints.typ:24-56): a wrap, custom part or function cell → `page-content: true` (ex11: classic false; wrap logo, custom part, function cell all true) → logic/printed.typ:137 returns `none` (unknown) instead of `false`, so IP-PRINT-03/IP-PERIOD-03 'not printed' findings are suppressed.
- lint/logo-alt only checks options.logo.image at resolve time (validate.typ:552-566); render-time swaps are not checked.
- Docs vs behaviour: unknown party keys are accepted (ex1/ex5, even ZUGFeRD + strict) despite "unknown keys always stop the compilation" (invoice/index.md:151, validation.md:96).

#### Files

exp dir: <session>/exp/theming-data-flow/

- ex1-custom-part.typ (+ data-muc.json, arms/\*.svg), ex2-ctx-dump.typ, ex3-wrap-logo.typ (+ brand.toml), ex4-unknown-arg.typ, ex5-zugferd-unknown-keys.typ, ex6-proto-ctx-data.typ (+ data-hydrate.json, proto/src), ex7-package-paths.typ (+ pkgs/local/probe), ex8-arglen.typ, ex9-item-custom.typ, ex10-portable-wrap.typ, ex11-prints.typ, bench-ctx-payload.typ, bench-proto-data.typ, bench-resolve.typ
- renders: ex1-muc-1.png, ex1-ber-1.png, ex3-strip.png, ex6-strip.png, ex10-grid.png
