# Critique of concept draft 1: executability of the snippets

Critic key: `snippets`. Lens: every documentation snippet must compile, because the project rule is that every docs snippet is tested.
Prototype copy: `scratchpad/crit-snippets/` (forked from `proto-synthesis`, typst 0.15.1). All reproduction files are in `scratchpad/crit-snippets/sn/`.
Compile command: `cd crit-snippets && typst compile --root . sn/<f>.typ sn/<out>` (add `--package-path tests/pkgs` or `--package-path sn/pkgs` for the package snippets).

## 0. Headline

- **§8 error messages: 21 of 21 are byte-identical** to what `tests/errors/err.typ --input case=1..21` prints (after stripping `error: panicked with: `). `diff sn/draft-msgs.txt sn/actual-msgs.txt` finds no difference, and so does `cmp`. §8 is sound.
- **Snippets: 24 Typst blocks, 1 TOML block and 1 message block were extracted.** Only 3 compile exactly as written. With trivial context added (imports, `party`, a body), 13 more compile. **5 are broken because the doc is wrong**, 1 depends on names the prototype does not have, and 4 are signature listings, two of them inaccurate.
- **The lead reviewer's question about P3 line 752** has two answers:
  - `right: auto` does work, but only because region patches break §4.2's rule "`auto` = untouched". The region engine does a shallow `existing + rv`, so `auto` **resets** the field instead of leaving it alone.
  - The snippet as written **still panics**, for a different reason: the moved window overlaps the `info` region of `sn-010130-right`.

## 1. Classification of every block

Legend:

- **OK**: compiles as written.
- **OK+ctx**: compiles once trivial context is added (imports, `party`, `#body()`, assets).
- **DOC**: broken because the doc is wrong.
- **PROTO**: broken because the prototype lacks a name.
- **SIG**: not compilable by nature (a signature listing).

| Id         | Draft lines | What                                                | Class                                   | Evidence (repro file → result)                                                                                                                                                                                                                                                                                                                                       |
| ---------- | ----------- | --------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S1.1       | 134–158     | cascade ASCII diagram                               | not code (untagged)                     | –                                                                                                                                                                                                                                                                                                                                                                    |
| S2.2-a     | 198–218     | lazy-theme signature                                | **SIG, inaccurate**                     | Declares `-> dictionary`, but the called form without `base` returns a _function_ (build.typ:238, `return self.with(..)`). `sn/s2-2.typ` passes `theme.classic()` to `invoice`, which accepts only functions, and it compiles. The listing should say `-> function \| dictionary`.                                                                                   |
| S2.2-b     | 221         | "verified message"                                  | OK                                      | Identical to err case 2.                                                                                                                                                                                                                                                                                                                                             |
| S2.3       | 226–233     | preset definitions                                  | OK+ctx                                  | `sn/s2-3.typ` needs internal imports (`build.typ`, `layouts.typ as layout`, `presets.typ: looks`). All 4 resolve, and `modern` on DIN B renders.                                                                                                                                                                                                                     |
| S2.4       | 243–261     | `build-theme` / `resolve-theme` / `adjust`          | **SIG, inaccurate**                     | The listing shows `layout: none` as a default, but `theme.build-theme(theme.custom.colors(primary: teal))` panics with ``assertion failed: variable `theme::build-theme::layout`(none) must be of dictionary`` (`sn/s2-4.typ`, `sn/exports.typ k=5`). The `resolve-theme` env default matches the listing (asserted).                                                |
| S2.6       | 308–311     | `themed` signature                                  | SIG                                     | Consistent with scope.typ:8.                                                                                                                                                                                                                                                                                                                                         |
| S2.7       | 321–324     | four ways to pass a theme                           | OK+ctx                                  | `sn/s2-7.typ k=1..4` all compile. Line 3 needs `acme-brand`. Line 4's `pkg.layout` is a placeholder: the package in (9) exports `sidebar-a5`. Using `pkg.layout` literally gives ``module `acme-theme` does not contain `layout` ``.                                                                                                                                 |
| S3.4       | 435–456     | `din-5008-a` in full + `derive` → B                 | OK+ctx                                  | `sn/s3-4.typ`: only needs `#let derive = theme.layout.derive`. `assert.eq` against `theme.layout.din-5008-a` / `-b` passes: the draft's data is identical to the prototype's.                                                                                                                                                                                        |
| S5.1-1     | 629         | `part("signature", ..)`                             | OK+ctx                                  | Fragment; needs `import theme.custom: *`. `sn/s5-1.typ k=1`.                                                                                                                                                                                                                                                                                                         |
| S5.1-2     | 630–631     | `wrap("bank-details", ..)`                          | OK+ctx                                  | `k=2`.                                                                                                                                                                                                                                                                                                                                                               |
| S5.1-3     | 632–633     | `wrap("totals", .. theme.adjust ..)`                | OK+ctx                                  | `k=3`.                                                                                                                                                                                                                                                                                                                                                               |
| S5.1-4     | 634         | eject `part("totals", (ctx, view) => { /* .. */ })` | OK+ctx, **but exposes a missing guard** | `k=4` compiles **without error**, and the invoice has **no net/VAT/gross totals** (`sn/out-s5-1-4.png`). See SNIP-5.                                                                                                                                                                                                                                                 |
| S7-P1      | 708–715     | freelancer                                          | **DOC (elision)** → OK+ctx              | Verbatim, the trailing `..` gives `error: expected expression` (`sn/p1-verbatim.typ:8:54`). With `..party` + `#body()`, `sn/p1.typ` compiles.                                                                                                                                                                                                                        |
| S7-P2      | 723–737     | GmbH, 3 output modes                                | **DOC (elision)** → OK+ctx              | `sender: (name: .., .., register: ..)` is a syntax error. With concrete sender fields, `sn/p2.typ --input output=print\|pdf\|einvoice` compiles. `einvoice` also compiles under `--pdf-standard a-3b`, but only after giving the recipient an `email`: otherwise core panics with `requires a buyer electronic address (BT-49)`. The docs test must carry that data. |
| S7-P3      | 748–751     | Swiss SME                                           | OK+ctx                                  | `sn/p3.typ k=main` compiles, with the page-2 slip and footer relocation visible (`sn/out-p3-main-*.png`).                                                                                                                                                                                                                                                            |
| S7-P3c     | 752         | left-window one-liner                               | **DOC**                                 | `sn/p3.typ k=left` gives ``theme::layout::regions::info overlaps the address window region `address` ``. See SNIP-1.                                                                                                                                                                                                                                                 |
| S7-P4t     | 761–772     | brand TOML                                          | OK                                      | `from-data` accepts it. The typo variant reproduces the §7 message exactly (`sn/p4typo.typ`).                                                                                                                                                                                                                                                                        |
| S7-P4c     | 775–778     | agency code                                         | **DOC**                                 | `e.sender.name` / `sender: e.sender` fail with `dictionary does not contain key "sender"` (`sn/p4.typ:5:75`): the TOML shown has no `[sender]` table. With the table added, `sn/p4b.typ` compiles.                                                                                                                                                                   |
| S7-P5      | 786–792     | SaaS pipeline                                       | **DOC**                                 | ``module `locale` does not contain `at` `` (`sn/p5.typ:8:52`). Also, `en-us` exists neither in the repo nor in the prototype (`src/locale/locale.typ`: regions at/ch/de/es/fr/it only). With a locale map + e-invoice data, both `us` and `eu` branches compile (`sn/o5-*.png`).                                                                                     |
| S7-P6      | 801–811     | design studio                                       | OK+ctx                                  | `sn/p6.typ` compiles (missing fonts are warnings only).                                                                                                                                                                                                                                                                                                              |
| S7-P7      | 816–819     | accessibility                                       | OK+ctx                                  | `sn/p7.typ` compiles, also with `--pdf-standard a-3a,ua-1`.                                                                                                                                                                                                                                                                                                          |
| S7-P8      | 829–834     | US subsidiary                                       | **DOC/PROTO**                           | ``module `locale` does not contain `en-us` `` (`sn/p8.typ:3:35`). `corporate.typ` also needs its own invoice-pro import. With `locale.en-de`, `sn/p8b.typ` compiles (`sn/o8b-1.png`).                                                                                                                                                                                |
| S7-9       | 839–857     | third-party package                                 | **DOC (elision)** → OK+ctx              | `block(.., ..)` in `rail` is a syntax error. With the elision removed, it is published as `sn/pkgs/local/acme-doc`. `sn/p9.typ` compiles, and so does the CI line `resolve-theme(theme.minimal.with(acme.patch, layout: acme.sidebar-a5))`.                                                                                                                          |
| S7-10      | 862–870     | scoped override                                     | **DOC (elision)** → OK+ctx              | `#bank-details(..)` is a syntax error. `[..]` inside `group` compiles as text. `sn/p10.typ` shows one yellow group and a red-derived `surface` behind bank details (`sn/o10-1.png`).                                                                                                                                                                                 |
| S8         | 888–910     | 21 messages                                         | OK                                      | 21/21 byte-identical (`sn/err-out.txt`, `sn/draft-msgs.txt`, `sn/actual-msgs.txt`).                                                                                                                                                                                                                                                                                  |
| S9         | 926–940     | internals sketch                                    | not code (untagged)                     | –                                                                                                                                                                                                                                                                                                                                                                    |
| §2.1 table | 189         | `theme.layout` exports                              | **PROTO**                               | `theme.layout.sn-010130-left`, `nf-z-11-001` and `uk-c5` give ``module `layout` does not contain ..`` (`sn/exports.typ k=1..3`). Only 7 layouts exist (`src/public/layout.typ:2`).                                                                                                                                                                                   |

Tally:

- 3 OK as written (S2.2-b, S7-P4t, S8).
- 13 OK+ctx.
- 5 DOC (P3c, P4c, P5, P8, plus the elision cluster P1/P2/9/10, counted as one defect class).
- 1 PROTO (§2.1).
- 4 SIG, 2 of them inaccurate.

## 2. Findings

### SNIP-1 (major, VERIFIED): the P3 left-window one-liner panics

- **Draft:** §7 P3, line 752: `theme.custom.region("address", right: auto, x: 22mm)`.
- **Repro:** `sn/p3.typ --input k=left` →
  ```
  error: panicked with: theme::layout::regions::info overlaps the address window region `address`; move it or shrink it (envelope windows must stay clear)
  ```
  In `layouts.typ:115`, `sn-010130-right` places `info` at `x: 22mm, y: 55mm, 80×35mm`, which is exactly where the window moves to.
- **Other variants:**
  - `region("address", x: 22mm)` alone → ``needs exactly one of `x` or `right` ``.
  - `right: none` → the same error.
    So `right: auto` is the only way to switch the anchor, and it depends on the §4.2 violation in SNIP-2.
- **Consistency:** §2.1 also lists a dedicated `sn-010130-left` layout, which does not exist (SNIP-6). The P3 comment and §2.1 therefore offer two different answers to the same need.
- **Fix (compiles as `sn/p3-fix.typ`, output `sn/out-p3-fix-1.png`):**
  ```typst
  // left-window envelopes: move the window left and the info block right
  theme.classic.with(layout: theme.layout.sn-010130-right, {
    import theme.custom: *
    region("address", right: auto, x: 22mm)
    region("info", x: auto, right: 18mm)
  })
  ```
  Better: after SNIP-2 is fixed, point to `layout: theme.layout.sn-010130-left` (shipped as data), or make the anchor pairs self-clearing so the one-liner becomes `region("address", x: 22mm)` + `region("info", right: 18mm)`.

### SNIP-2 (major, VERIFIED): region patches contradict §4.2 (`auto` resets, merge is shallow)

§4.2 says `auto` means "untouched, at every depth" and "dict onto dict: recurse, unlimited depth". Region patches do neither. `layout-ops.typ:166` does `regions.insert(name, existing + rv)` on the raw `args.named()` from `custom.typ:105` (no `clean-auto`, no `merge`). Evidence:

- `theme.classic.with(theme.custom.region("address", x: auto))` should be a no-op by §4.2. Instead it panics: ``theme::layout::regions::address needs exactly one of `x` or `right` `` (`sn/xauto.typ`).
- `region("address", inset: (top: 2mm))` on DIN A gives `inset == (top: 2mm)`, so DIN's `left: 5mm` is lost (`sn/p3-fix.typ`, assertion r3). The §10 visual caveat recommends exactly this patch.
- `theme.modern.with(brand(..), region("letterhead", text: (size: 9pt)))` drops the look's `text: (fill: t => t.colors.on-primary)`. The sender prints **near-black on the near-black band** (`sn/band-1.png`). This is a legibility/contrast regression, and `checks.min-contrast` does not see it.
- Contrast: in tokens and options, `colors(primary: auto)` really is untouched (assertion r4).

**Fix:**

1. Route region patches through `merge()` with `region::inset`/`region::text` handled as fold/recursive paths, so `auto` is untouched everywhere.
2. Add an explicit rule for exclusive anchor pairs: setting `x` clears `right` and vice versa (same for `y`/`bottom`).
3. Document in §3.4 and §4.2 that this is the only way anchors change.

P3 then needs no `auto` trick at all.

### SNIP-3 (major, VERIFIED): walkthroughs P5 and P8 use locale API that does not exist

- P5: `locale.at(d.locale)` → ``module `locale` does not contain `at` ``.
- P5 and P8: `locale.en-us` → ``module `locale` does not contain `en-us` ``. Neither the repository (`<repo>/src/locale/region/`: at, base, ch, de, es, fr, it) nor the prototype has a US region.

The US persona (P8) and the pipeline persona (P5) are therefore not testable. The appendix item 2 mapping "us → US #10" also refers to a region that does not exist.

**Fix:**

- Either add "en-us locale (USD, US date and number format)" to the roadmap as a prerequisite of P8, or rewrite P8 with an existing locale.
- For P5, use an explicit user map instead of reflection:
  ```typst
  #let locales = (de-de: locale.de-de, en-de: locale.en-de)   // extend as needed
  ... locale: locales.at(d.locale) ...
  ```
  `dictionary(locale).at(..)` also works on 0.15.1, but it was not checked on 0.14.0, so do not document it.

### SNIP-4 (major, VERIFIED): the P4 TOML and the P4 code disagree

The code reads `e.sender.name` and `sender: e.sender`, but the TOML block has no `[sender]` table. Error: `dictionary does not contain key "sender"` (`sn/p4.typ:5:75`).

**Fix:** append to the TOML block

```toml
[sender]
name = "Nordlicht Studio"
address = "Kai 1"
city = "24103 Kiel"
```

Then `sn/p4b.typ` compiles. Alternatively, drop `e.sender` from the code and take the alt text from the TOML (`[theme.options.logo] alt = ".."`). Note that `from-data` does not currently support `alt`.

### SNIP-5 (major, VERIFIED): required parts other than `notices` may return nothing; the eject snippet silently drops the tax totals

- **Draft claims:**
  - §3.6: `items-table`, `totals`, `line-items` and `bank-details` are "not `none`".
  - §8: "At render: required parts returning nothing" panics.
  - §5.3 treats the identity and legal-notes guards as the compliance story.
- **Code:** `call-part(.., required:)` is passed `required` **only for `notices`** (`src/components/line-items.typ:506`). Every other `call-part` call is unguarded (`line-items.typ:502`, `bank-details.typ:155`), and `validate-parts` only rejects the literal value `none`.
- **Repro:** the §5.1 eject line `part("totals", (ctx, view) => { /* .. */ })` compiles without error (`sn/s5-1.typ k=4`). The PNG `sn/out-s5-1-4.png` shows the item table followed directly by the tax note: **no net, VAT or gross totals**. Showing the tax amount is a § 14 (4) Nr. 8 UStG requirement.
- **Fix:**
  - Pass `required: true` for `line-items`, `items-table`, `totals` and `bank-details` (the latter when `qr` or IBAN data is present).
  - Say so in §3.6.
  - Add an §8 message, e.g. `theme::parts::totals returned no content, but it must render legally required output`.
  - Make the §5.1 eject example return something (`theme.parts.totals(ctx, view)` as the starting point) so the docs test does not model the hole.

### SNIP-6 (minor, VERIFIED): §2.1 lists layouts the prototype does not export

`theme.layout.sn-010130-left`, `nf-z-11-001` and `uk-c5` → ``module `layout` does not contain ..`` (`sn/exports.typ k=1..3`, `src/public/layout.typ:2`). §10's "7 layouts" is correct, so the gap is §2.1 overclaiming.

**Fix:** mark these three as "planned (M4), not in prototype" in §2.1 and §3.4, or add them as data. `sn-010130-left` is trivial and also fixes SNIP-1.

### SNIP-7 (minor, VERIFIED): `..` elisions make 4 snippets uncompilable under the docs-test rule

P1 (`..`), P2 (`sender: (.., .., ..)`), (9) (`block(.., ..)`) and (10) (`bank-details(..)`) all fail with `expected expression`. Each needs only trivial context, but because every docs snippet is tested, the docs need a mechanical convention.

**Fix:** use a hidden per-page prelude that defines `party`, `body` and assets, plus `..party` / `// …` comments instead of bare `..`. Note in §12 M6 that tytanic snippet tests use that prelude. Also record that P2 `einvoice` needs a buyer electronic address (BT-49) in its test data, and P5 needs a buyer reference and seller contact.

### SNIP-8 (minor, VERIFIED): two signature listings contradict the implementation

- §2.2 declares `-> dictionary`, but without an injected `base` the result is a function (build.typ:238).
- §2.4 shows `layout: none` as the default of `build-theme`, but `none` panics (build.typ:222).

**Fix:**

- §2.2: `-> function | dictionary`, with "function when called without `base`".
- §2.4: make `layout` required (no default) or default it to `layout.plain`, and state which.

### SNIP-9 (minor, VERIFIED): the "patch #N" index in the non-dict error is off by one

`theme.classic.with(theme.custom.colors(primary: red), 42)` reports ``theme `classic`: patch #3 must be a dictionary produced by a `theme.custom` helper, found integer (42)`` (`sn/exports.typ k=4`). The user's second argument is reported as #3.

- **Cause:** `flatten-patches(look + args.pos(), ..)` in build.typ:240 counts the preset's look entry, and nested blocks restart the count (patch.typ:150).
- **Also:** the message says "dictionary produced by a helper", although helpers produce arrays.

**Fix:** number only the user's positional arguments, append the nested index (`patch #2[1]`), and say "a `theme.custom` result or a patch dictionary". The §4.2 example `patch #2 ...` stays valid.

### SNIP-10 (nit, VERIFIED visually): content blocks in a footer region ignore `sizes.fine`

In P8 (`sn/o8b-1.png`), `[*Remit to:* ..]` and `[billing\@acme.com]` print at body size, while the `register` part next to them prints at `fine` size in muted colour. Separately, the `bank-account` footer part prints an empty `BIC:` label when no BIC is given (`sn/o10-1.png`).

**Fix:** give footer regions a default `text: (size: t => t.sizes.fine, fill: t => t.colors.muted)` in the layouts, and let parts omit empty labels.

### SNIP-11 (nit, SOURCE): two §8 messages do not follow the house style §8 announces

§8 promises "a `theme::` path, the value, the allowed set and a did-you-mean hint". Two messages do not follow it:

- Message 14 (``variable `theme::tokens::colors::primary`("#ff0000") must be of color``) is the `types.require` style.
- Message 16 (``variable `invoice::theme` must be of function ..``) is also the `types.require` style.

**Fix:** either state that type errors intentionally use the `types.require` wording, or add the allowed set (`color or t => color`) to message 14.

## 3. What is solid

- §8 matches the prototype character for character, 21/21.
- The §3.4 layout data is byte-identical to the prototype's `layouts.typ` (`assert.eq`).
- These all compile with only trivial context:
  - the called form (`theme.modern(layout: .., {block})`);
  - wrap + `adjust` + part replacement (P6);
  - PDF/UA-1 (P7);
  - the zero-import package, including its CI `resolve-theme` line (9);
  - scoped re-derivation (10);
  - all three stationery modes of P2, including `a-3b`.
- Also verified:
  - margin fold (`page(margin: (bottom: 35mm))` keeps the other sides);
  - marks re-hydration on a digital layout (`marks(fold: (105mm,))` gives `x: 5mm` from the template);
  - a false `if` in a block is ignored.
