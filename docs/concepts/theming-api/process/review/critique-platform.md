# Critique of concept draft 1: platform risk (Typst 0.14.0, PDF standards, performance)

Critic key: `platform`. Working copy: `scratchpad/crit-platform/` (a copy of `proto-synthesis`; new experiments are in `crit-platform/exp/`, outputs in `crit-platform/exp/out/`).
Local compiler: typst 0.15.1 (9dfd3a08). I did not download any other binary, so every 0.14.0 statement below is backed by the official changelog or docs (SOURCE), not by a local run.

Evidence tags: **VERIFIED** means reproduced here. **SOURCE** means read in code or official docs. **REASONED** means argument only.

---

## TL;DR

| ID      | Sev         | Finding                                                                                                                                                                                                                                                                    |
| ------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PLAT-1  | **blocker** | `--pdf-standard a-3a,ua-1` (PDF/A plus PDF/UA together) only exists from **Typst 0.15.0**. The draft builds P5, P7, M2's test plan and §10 on it while saying "Nothing requires 0.15". On 0.14.0 you cannot have ZUGFeRD (PDF/A-3) and PDF/UA-1 in one file.               |
| PLAT-2  | **major**   | The legal footer silently runs off the paper. A running footer taller than `margin.bottom` is not measured, and lines past the page edge are lost. At 7 lines the text already touches the edge; at 10 lines, 3 lines are gone. No guard exists.                           |
| PLAT-3  | **major**   | A reserved zone relocates only `pages: "all" \| "last"` footers, and with `view.page = none`. So `page-number` disappears on the slip page, and `"rest"`/`"not-last"`/`"first"` footers are dropped. §5.3 says the footer is "relocated, not dropped".                     |
| PLAT-4  | major       | The M0 "0.14.0 CI job" is under-specified. The 0.15 layout change (retained baselines) plus PNG refs made on 0.15.1 means visual refs are compiler-specific. The CI matrix must say which compiler owns the refs.                                                          |
| PLAT-5  | minor       | Sealing overhead grows with item count and page count: +1 % at 1 item, +9 % at 150 items, **+19 % at 400 items**. About 9 ms per page comes from frame parts receiving the unsealed ctx in 4 `context` closures per page. The draft reports "+8 %" as if it were constant. |
| PLAT-6  | minor       | The logo alt-text guard fires for **every** user, with or without PDF/UA. It is also bypassed by any wrapper (`box(image(..))`). Typst's own `ua-1` check already catches every missing alt, with a better location.                                                       |
| PLAT-7  | minor       | The PDF-image guard is only a path-suffix check. Bytes, `format: "pdf"` and wrapped images slip past it. Typst's own error is better and also fires under `ua-1` alone, a case the guard's message leaves out.                                                             |
| PLAT-8  | minor       | The CMYK guard is now exercised (VERIFIED), but it only checks `tokens.colors`. Its wording ("PDF/A-3 rejects CMYK") is inaccurate: Typst lacks an output-intent profile.                                                                                                  |
| PLAT-9  | minor       | `page-number.from` compares the **total** page count, not the current page. "Page 1 of 4" prints on page 1, and on DIN `classic` the number appears twice (continuation header and footer).                                                                                |
| PLAT-10 | nit         | The ZUGFeRD XMP extension schema (`fx:` namespace) is missing. This is a platform limit (no custom XMP API in 0.14 or 0.15) that predates this draft, but §5.3 lists "ZUGFeRD keywords" as compliance output.                                                              |

What held up (VERIFIED):

- **112 of 112 compiles are clean:** 4 looks × 7 layouts × {`a-3b`, `ua-1`, `a-3a,ua-1`, `a-3a`}, with `zugferd: "basic"` and an SVG logo with alt text. `factur-x.xml` is attached with `/AFRelationship /Alternative`, and `pdfaid` / `pdfuaid` are correct.
- The third-party package, all 3 P2 stationery modes and all 5 walkthroughs compile clean under all three standard sets.
- SVG stationery works under `a-3b`, `ua-1` and `a-3a,ua-1`, and the PDF-stationery guard message fires as documented.
- Table headers repeat, the continuation header and "x of y" numbering work on 3–4 pages, and nothing overlapped when the last page is full (the reserved zone moves to a new page).
- `themed` has no measurable cost: 30 scoped groups at 150 items are not slower.
- Apart from PLAT-1, no 0.15-only language feature is used: no `dictionary.map/filter`, no `path`, no `within`, no `int(base:)`, no `counter.display(at:)` (grep, §A).

---

## A. Static audit: Typst features against 0.14.0

Method: I grepped `src/theming/**`, `src/utils/patch.typ`, `src/components/root.typ`, `src/components/line-items.typ`, `src/invoice.typ` and `src/public/{theme,layout}.typ`. I checked each hit against the official changelogs (0.14.0, 0.15.0), the 0.14.0 docs source (`raw.githubusercontent.com/typst/typst/v0.14.0/docs/reference/export/pdf.md`), issue typst#7183 and PR typst#8294.

| Feature                                                                         | First Typst version                                                                                                    | Used where                                                                      | Risk on 0.14.0                                                                                                                                                                       |
| ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **PDF/A plus PDF/UA in one export (`a-3a,ua-1`)**                               | **0.15.0** (PR #8294, merged 2026-05-29; 0.15 changelog: "can now target multiple (compatible) PDF standards at once") | draft l.792 (P5), l.819 (P7), l.1009 (§10), l.1080 (M2 tests)                   | **BLOCKER**: the 0.14.0 docs say "You currently cannot choose both PDF/A and PDF/UA at the same time"; rc2 error text: "Typst currently only supports one PDF substandard at a time" |
| `pdf.attach`                                                                    | 0.14.0 (renamed from `pdf.embed`; `embed` removed in 0.15)                                                             | `components/root.typ:301`                                                       | OK, but exactly at the floor, so the floor can never go below 0.14                                                                                                                   |
| `array.first(default:)`                                                         | 0.14.0                                                                                                                 | `root.typ:102,110`, loom-wrapper                                                | OK, at the floor                                                                                                                                                                     |
| PDF files as `image`                                                            | 0.14.0 (hayro)                                                                                                         | guard `theming/validate.typ:128-151`                                            | OK. Whether PDF/A rejects them on 0.14 is not verified (on 0.15.1 Typst rejects them itself, see PLAT-7)                                                                             |
| PDF/UA-1 alone, `pdf.artifact`, header/footer/background auto-artifacts         | 0.14.0                                                                                                                 | frame layers, `ua-1` claims                                                     | OK                                                                                                                                                                                   |
| `set document(description:, keywords:)`                                         | ≤0.14 (0.4.2 already ships it with `compiler = "0.14.0"`)                                                              | `root.typ:317`                                                                  | OK                                                                                                                                                                                   |
| `oklch()`, `.components()`                                                      | ≤0.11                                                                                                                  | `theming/color.typ:271-272`                                                     | low                                                                                                                                                                                  |
| `color.linear-rgb(c).components(alpha: false)`                                  | ≤0.11                                                                                                                  | `color.typ:237`                                                                 | low                                                                                                                                                                                  |
| `color.space() == cmyk`                                                         | old                                                                                                                    | `validate.typ:139`                                                              | low                                                                                                                                                                                  |
| `image.source` field (str)                                                      | 0.13 (renamed from `path`)                                                                                             | `validate.typ:129`                                                              | low. In 0.15 a `path` value may appear there and bypass the guard (Typst still errors)                                                                                               |
| `image` `alt` via `.at("alt")`                                                  | old                                                                                                                    | `validate.typ:134`                                                              | low                                                                                                                                                                                  |
| `metadata(any)` + `.value` as the sealed ctx value                              | 0.8                                                                                                                    | `theming/access.typ`                                                            | functionally low. The **performance** property (content hash computed once and cached) is an implementation detail; the draft correctly asks for a 0.14 benchmark                    |
| `counter(page).final()` without a location                                      | 0.11                                                                                                                   | `theming/frame.typ:137,149`                                                     | low                                                                                                                                                                                  |
| `here().page()`, `query(<ip-reserve>)` inside `context` in page header/footer   | 0.11                                                                                                                   | `frame.typ:136-140`                                                             | low; no convergence warnings seen                                                                                                                                                    |
| `context` in `set page(header/footer/background/foreground)`                    | 0.11                                                                                                                   | `frame.typ:171-180`                                                             | low                                                                                                                                                                                  |
| `array.to-dict()`                                                               | ≤0.8                                                                                                                   | `build.typ:54`                                                                  | low                                                                                                                                                                                  |
| `dictionary.map/filter`                                                         | **0.15**                                                                                                               | **not used** (every `.map/.filter` receiver is an array or `.pairs()`, grep §A) | none                                                                                                                                                                                 |
| `path` type, `within` selector, `int(base:)`, `counter.display(at:)`, `divider` | 0.15                                                                                                                   | not used                                                                        | none                                                                                                                                                                                 |
| `place(float: true, clearance:)`, `place(dx, dy)`                               | old                                                                                                                    | `frame.typ:156,187,208`                                                         | low                                                                                                                                                                                  |
| `regex`, `str.match`, `str.clusters`, `"\d"` in string literals                 | old                                                                                                                    | `theming/data.typ:191-192`, `utils/patch.typ:320`                               | low (the unknown `\d` escape passes through; verified on 0.15.1, and lexer behaviour is unchanged)                                                                                   |
| `decimal`                                                                       | 0.12                                                                                                                   | root, line-items                                                                | low                                                                                                                                                                                  |
| `set image(fit: "stretch")`, `box(clip:)`                                       | old                                                                                                                    | `frame.typ:164`                                                                 | low                                                                                                                                                                                  |
| `sys.inputs` (`ip-seal`)                                                        | 0.9                                                                                                                    | `access.typ`                                                                    | nit: leaks an internal knob to every user                                                                                                                                            |
| loom 0.1.1                                                                      | `compiler = "0.14.0"`                                                                                                  | everywhere                                                                      | floor stays 0.14                                                                                                                                                                     |
| **0.15 breaking change "baseline retention" in `box`/`block`/list layout**      | 0.15.0                                                                                                                 | every region `arrange` grid, `align: left + bottom` rows in `address`           | visual refs differ between 0.14 and 0.15 (PLAT-4)                                                                                                                                    |

Draft l.979-983 lists "0.14-era features". The list is correct as far as it goes, but it misses the one thing that actually needs 0.15: the combined standard flag used on the command line.

---

## B. PDF standards

### B1. Preset × layout matrix (VERIFIED)

`exp/std.typ` takes these inputs: `look`, `layout`, `zugferd` (default `basic`), `logo` (default an SVG with alt) and `n`.

```
for std in a-3b ua-1 "a-3a,ua-1" a-3a; for look in classic modern minimal plain;
  for lay in din-5008-a din-5008-b us-letter-10 a4-digital letter-digital sn-010130-right plain:
  typst compile --root . --pdf-standard $std --input look=$look --input layout=$lay exp/std.typ ...
```

**Result: 112/112 compile with no errors and no warnings.**

`exp/out/std-a-3b-classic-din-5008-a.pdf` contains `/F(factur-x.xml) /UF(factur-x.xml) /AFRelationship/Alternative pdfaid:part 3 conformance B`. `std-a-3a_ua-1-plain-plain.pdf` also carries `pdfuaid:part 1`.

Also clean under all three standard sets:

- `tests/third-party.typ` (with `--package-path tests/pkgs`);
- `tests/p2-stationery.typ` in all 3 `output` modes;
- `tests/walk.typ` `p1|p4|p6|p8|scope`.

This confirms draft §10 l.1009 on 0.15.1, but see PLAT-1 for 0.14.0.

**Caveat (a test gap in the draft's evidence):** the matrix and the `ua-1` runs in `proto-synthesis` use `logo-img`, which is a `box` of text (`tests/body.typ:5`), not an `image`. So the §10 `ua-1` claim never covered an image logo. My matrix used a real SVG image with alt.

### B2. Alt text (VERIFIED)

`exp/std.typ --input logo=<variant> --input zugferd=none`:

| Logo                      | no standard                   | `--pdf-standard ua-1`                     |
| ------------------------- | ----------------------------- | ----------------------------------------- |
| `image(svg)`, no alt      | **panic** (theme guard)       | panic (theme guard)                       |
| `image(bytes)`, no alt    | **panic** (theme guard)       | panic (theme guard)                       |
| `box(image(svg))`, no alt | **compiles** (guard bypassed) | Typst: `PDF/UA-1 error: missing alt text` |
| `box[..text..]`           | compiles                      | compiles                                  |

So the draft's claim (P7 l.822, §8 l.896) that "the logo without alt text panics" is only half true. It panics even when nobody asked for PDF/UA. A wrapped image bypasses it, and Typst's own UA check is the real safety net anyway. It also covers images inside custom parts and region content, which the theme guard never sees. → PLAT-6.

### B3. Stationery: SVG vs PDF (VERIFIED)

`exp/stat.typ --input src=<variant>` on DIN B, with `exp/lh.pdf` as a real 1-page PDF made by Typst:

| Source                            | `a-3b` + zugferd                             | `a-3b`, no zugferd                                                     | `ua-1` + zugferd |
| --------------------------------- | -------------------------------------------- | ---------------------------------------------------------------------- | ---------------- |
| `image("lh1.svg")`                | OK                                           | OK                                                                     | OK               |
| `image("lh.pdf")`                 | **theme panic** (the draft's message, l.905) | Typst: `embedding PDFs is currently not supported in this export mode` | theme panic      |
| `image(read(.., encoding: none))` | Typst error (guard bypassed)                 | Typst error                                                            | Typst error      |
| `box(image("lh.pdf"))`            | Typst error (guard bypassed)                 | Typst error                                                            | Typst error      |
| `image("lh-pdf", format: "pdf")`  | Typst error (guard bypassed)                 | Typst error                                                            | Typst error      |

Typst's native error points at the user's `image(...)` line and adds `hint: try converting the PDF to an SVG`. The theme panic points at `src/theming/validate.typ:147`. The platform also rejects PDF images under **`ua-1` alone** (row 4, `ua-1` without zugferd, VERIFIED), which the guard's "PDF/A-3 (ZUGFeRD)" wording leaves out. So the stationery SVG path works as claimed, and the PDF path is rejected as claimed, but by Typst more reliably than by the guard. → PLAT-7.

### B4. CMYK (VERIFIED; the draft l.914 says "not exercised")

`exp/cmyk.typ` with `brand(color: cmyk(..))`:

- with zugferd, the theme panics with and without `--pdf-standard`;
- with `a-3b` and no zugferd, Typst reports `PDF/A-3b error: the PDF is missing a CMYK profile`.

The guard covers only `tokens.colors` (`validate.typ:138-142`). A CMYK `items-table.header-fill` or region `fill` is not checked; Typst still catches it under `a-3b`. → PLAT-8.

---

## C. Performance (VERIFIED, 5 runs each, wall clock including process start, typst 0.15.1)

The baseline is built from the repo's `src` (copied to `exp/base/src`, repo untouched) with `themes.DIN-5008()`. The benchmark bodies are identical to `tests/bench-150.typ` apart from the item count (`exp/bench-{1,150,400}.typ`, `exp/base/bench-*.typ`).

| Items (pages)  | 0.4.2 baseline | Synthesis, sealed          | Synthesis, `ip-seal=0` |
| -------------- | -------------- | -------------------------- | ---------------------- |
| 1              | 391–474 ms     | 394–490 ms (**≈ +2 %**)    | 426–577 ms (+10 %)     |
| 150            | 1137–1187 ms   | 1251–1415 ms (**≈ +9 %**)  | 1938–2115 ms (+72 %)   |
| 400 (20–21 p.) | 2414–2736 ms   | 2890–3168 ms (**≈ +19 %**) | 4691–6353 ms (+93 %)   |

This reproduces the draft's 150-item numbers (l.76-78). **But the overhead is not constant:** sealed, each item costs about 6.8 ms against 5.2 ms in the baseline.

Isolation at 400 items (3 runs each):

| Variant                                                               | Time                      | What it isolates                                    |
| --------------------------------------------------------------------- | ------------------------- | --------------------------------------------------- |
| `classic` without footer, page-number, continuation and marks regions | 2497–2556 ms (≈ baseline) | the engine and sealing cost nothing extra           |
| `theme.plain`                                                         | 2597–2606 ms              |                                                     |
| Same furniture as **static content** in the regions                   | 2674–2706 ms              | real typesetting of about 20 footers                |
| Furniture rendered **by parts** (default)                             | 2836–2930 ms              | **≈ +170 ms ≈ 9 ms per page of part-call overhead** |

Cause (SOURCE): `render-frame` unseals once (`frame.typ:107`). Then every page runs 4 `context` closures (`running("header")`, `running("footer")`, `layer("background")`, `layer("foreground")`), and each calls `render-region` → `render-cell` → `fn(ctx, view)` with the full unsealed ctx (theme, locale, globals) plus a fresh `view` dict carrying `page`. User closures are memoised on their arguments, so every part call hashes the whole theme again. This is exactly the cost sealing was meant to remove, now paid per page. → PLAT-5.

`themed` scaling (`exp/bench-themed.typ`, 30 groups × 5 items, k groups wrapped in `themed(row(fill:))`): k=0 took 1281–1289 ms and k=30 took 930–1020 ms. There is no overhead (it is faster, likely because the zebra fills are dropped). The output was checked visually: `exp/out/th-compare.png`, identical totals.

---

## D. Multi-page behaviour (VERIFIED, PNGs in `crit-platform/exp/out/`)

1. **DIN A `classic`, 75 items, 4 pages** (`exp/mp2.typ --input n=75 --input big=1`, `din75-{1..4}.png`):
   - table header repeats;
   - continuation header on pages 2–4;
   - footer on every page, and the fold and punch marks on every page;
   - no overlap.
   - Defects: "Page 1 of 4" prints on page 1, although `page-number.from` defaults to 2, and pages 2–4 show "Page x of y" twice (header and footer). → PLAT-9.
2. **Tall legal footer** (`--input big=1` with 10 contact lines, `n=20`, `dinbig-2.png`, crop `dinbig-footer-crop.png` at 150 ppi): the contact column is cut at the paper edge. The lines "B: 2", "C: 3" and "D: 4" are not on the page at all, and "A: 1" sits under 1 mm from the edge. With the 7-line variant (`din75-4.png`) the last line already touches the edge, inside any printer's unprintable margin. There is no error and no warning. → PLAT-2.
3. **SN 010130 with a reserved QR zone, last page full** (`exp/std.typ --input layout=sn-010130-right --input n=60`, `mp60-{1..4}.png`): the body ends near the bottom of page 3, and the slip plus the relocated footer float onto a new page 4. There is no overlap and no lost body content, and the slip sits at the bottom 105 mm as specified. **But:**
   - the footer's "Page 4 of 4" is missing on page 4. The same happens with n=55 on page 3 (`mp55-3.png`). The header's continuation still shows it, but on a layout without a continuation header the page number is simply gone.
   - Code: `frame.typ:140` suppresses all running footers on the reserve page. `frame.typ:206` relocates only `pages in ("all","last")` regions, and `frame.typ:207` passes `page: none`, so `page-number` returns `none` (`parts/frame.typ` `page-number`: `if p == none ... return none`). Footer regions with `pages: "rest"`, `"not-last"` or `"first"` vanish on that page. → PLAT-3.
   - A tagging side note: the relocated footer is in-flow, so it is tagged. On every other page the footer is an artifact (Typst auto-artifacts headers and footers, per the accessibility guide). Screen readers therefore meet the § 35a GmbHG block once, at the end, and only on the slip page.

---

## Findings in detail

### PLAT-1 (blocker): `a-3a,ua-1` requires Typst 0.15; ZUGFeRD plus PDF/UA is impossible on 0.14.0

- **Where:** exec summary l.69 ("Nothing requires 0.15"); §7 P5 l.792; P7 l.819; §9 l.979-988; §10 l.1009; §12 M2 l.1080 ("`a-3b` and `a-3a,ua-1` for built-in presets"); appendix (no open question on it).
- **Evidence (SOURCE):**
  - The 0.14.0 docs (`typst v0.14.0 docs/reference/export/pdf.md`) say: "You currently cannot choose both PDF/A and PDF/UA at the same time."
  - The 0.15.0 changelog says: "Typst can now target multiple (compatible) PDF standards at once, e.g. PDF/UA-1 and PDF/A-2a".
  - The change landed in PR typst#8294, merged 2026-05-29, which closed issue #7183 ("Typst currently only supports one PDF substandard at a time").
  - Verified on 0.15.1 only: the combined flag works there, 112/112.
- **Impact:**
  - The P7 persona (accessibility-bound public-sector supplier) and the P5 SaaS pipeline cannot be served on the declared minimum compiler.
  - The combination that matters for e-invoicing (ZUGFeRD needs PDF/A-3, and public buyers often require PDF/UA) cannot be produced below 0.15.
  - The M2/M0 CI plan as written would fail on the 0.14.0 job.
- **Fix:**
  1. State in §9 and the exec summary: "0.14.0: one standard per export (`a-3b` for ZUGFeRD **or** `ua-1`); `a-3a,ua-1` needs ≥ 0.15.0."
  2. Put P5 and P7 on the same footing: P7 on 0.14 uses `ua-1` without ZUGFeRD, or requires 0.15.
  3. Split the CI matrix into 0.14.0 {`a-3b`+zugferd, `ua-1`, `a-3a`} and 0.15.x {`a-3a,ua-1`}.
  4. Add an appendix question: "Bump min compiler to 0.15 for combined PDF/A + UA?" This is a real trade-off. Nothing in the _theme API_ needs 0.15, but a stated business requirement does.

### PLAT-2 (major): running footers are not measured; legal footer lines are lost off-page

- **Where:** §6 table "legal footer (R15, #18) … every page"; §11 l.1051 ("a tall first-page footer forces `margin.bottom`"); §8 has no such check; `frame.typ:135-145,171-180`.
- **Evidence:** VERIFIED in `exp/mp2.typ --input big=1 --input n=20` → `exp/out/dinbig-2.png` and `dinbig-footer-crop.png`. With 10 lines of sender extras, 3 footer lines are outside the page. With 7 lines, the last line lies under 1 mm from the edge.
- **Impact:** § 35a GmbHG / § 14 UStG footer data (register, management, VAT ID) is silently cut. The draft's own promise is "footers are legal content", but only the reserve page relocates them. GmbH footers with 5–7 lines per column are normal.
- **Fix:** in `render-frame`, `measure` the tallest footer stack (and header) at `text-w` before `set page`, inside one `context`. Then either:
  - (a) raise `margin.bottom` to `max(margin.bottom, footer-h / (1 - footer-descent) + safe-zone)`, which is allowed because it is a single unconditional `set page`; or
  - (b) panic: `theme::layout::regions::footer is 41mm tall but margin.bottom leaves 26mm; raise layout.margin.bottom or reduce the footer`.

  Option (b) matches the house "strict" style. Add it to §8 and to the M2 tests (`footer-overflow` compile-fail). The same check covers header overflow into the body.

### PLAT-3 (major): the reserved-zone page drops the page number and non-"all"/"last" footer regions

- **Where:** §5.3 last row ("legal footer on a reserved page | relocated into the flow above the zone, not dropped (built)"); §6 "regulated zones"; `frame.typ:140,206-211`.
- **Evidence:**
  - VERIFIED: `exp/out/mp60-4.png` and `mp55-3.png` have no footer page number on the slip page.
  - SOURCE: `frame.typ:206` filters `fr.pages in ("all","last")`, and `:207` sets `page: none`.
- **Impact:** a layout with a page number only in the footer (US, digital A4 with no continuation) loses it on the last page. A footer region scoped to `"rest"` or `"not-last"` (common for "continued on next page") silently disappears on that page. The draft's guarantee is false.
- **Fix:** relocate _every_ footer region whose `pages` matches that page (compute `cur`/`total` inside a `context` in the float, since `here().page()` works there). Pass `page: (current, total)` instead of `none`. Add the 3-page SN case with `page-number` and a `"rest"` footer to the M4 tests.

### PLAT-4 (major): the 0.14.0 CI job must pin which compiler owns the visual refs

- **Where:** §9 l.985-988; §12 M0/M2 ("the one visual-ref pass, ~20 refs"); §10 (all PNG evidence on 0.15.1).
- **Evidence (SOURCE):** the 0.15.0 changelog lists a breaking change: the layout engine now retains baselines in `box`/`block`/list alignment. The frame relies on grids with `align: (left + bottom, left + top)` rows (`layouts.typ` `address`) and `box`-based arrangements. Also, `typst query` is deprecated in 0.15, which matters if CI uses it.
- **Impact:** refs made on the developer's 0.15.x will fail on the 0.14.0 job, or the other way round. Either CI goes red, or someone "fixes" it by regenerating refs on the wrong compiler and hides a real regression.
- **Fix:** specify "refs generated and compared on 0.14.0 only; the 0.15.x job runs compile, the PDF standards and the benchmark, with no pixel compare". Or keep two ref sets. Add this to M0.

### PLAT-5 (minor): sealing overhead is page-proportional; the frame re-pays unsealed hashing per page

- **Where:** exec summary l.72-81; §4.4 l.611-615; `frame.typ:107,135-158`.
- **Evidence:** VERIFIED, table §C: +2 % at 1 item, +9 % at 150 items, +19 % at 400 items. About 170 ms of the 400-item overhead comes from part-rendered furniture compared with static furniture.
- **Fix:**
  - Render page-invariant region content (letterhead, legal footer blocks, marks) **once** outside `context` and reuse it.
  - Only `page-number` and `continuation` need the page. Pass them a small view, not the full ctx, or call parts through a memoisation boundary that takes the sealed theme.
  - Report the benchmark as a curve (1/150/400 items), not a single "+8 %".
  - Add the 400-item case to the M0 benchmark with a budget, for example ≤ +12 %.

### PLAT-6 (minor): the logo alt guard is unconditional and bypassable

- **Where:** §4.4 validation list; §8 l.896; P7 l.822; `validate.typ:133-136`.
- **Evidence:** VERIFIED, table B2.
- **Fix:** keep the guard only as a courtesy for the `logo` option, and document that it applies to everyone (a user without an a11y need will hit it). Or drop it and rely on Typst's `ua-1` check, which covers all images and wrappers. At minimum, reword it so it does not claim to enforce PDF/UA. The document cannot detect `--pdf-standard`, so the only honest trigger is "always".

### PLAT-7 (minor): the PDF-image guard is a suffix check; Typst's own error is stronger and also covers `ua-1`

- **Where:** §8 l.905; P2 l.742; `validate.typ:128-130,143-151`.
- **Evidence:** VERIFIED, table B3. Bytes, `format: "pdf"` and `box(...)` bypass the guard, while Typst rejects all of them under `a-3b` and under `ua-1`. The guard fires with zugferd set even when no PDF standard is requested. That is defensible, since ZUGFeRD implies PDF/A-3, but should be documented.
- **Fix:** keep the guard as an early hint for the common `image("x.pdf")` case. Extend the message to "PDF/A and PDF/UA exports cannot embed PDF images (Typst limitation); convert to SVG". Note in §5.3 that the enforcement is Typst's. PDF-in-PDF/A on 0.14.0 has not been verified locally.

### PLAT-8 (minor): the CMYK guard's scope and wording

- **Where:** §8 "Specified, not yet built" l.914; `validate.typ:137-142`.
- **Evidence:** VERIFIED in `exp/cmyk.typ`. The theme panic fires with zugferd. Without zugferd, `a-3b` gives Typst's `the PDF is missing a CMYK profile`.
- **Fix:**
  - Change "not exercised" to "exercised".
  - Also check option and region colours, or leave CMYK to Typst.
  - Reword to "Typst cannot embed a CMYK output profile, so PDF/A exports reject CMYK".

### PLAT-9 (minor): `page-number.from` semantics and duplicate numbering

- **Where:** §3.5 `page-number.from: 2`; `parts/frame.typ` `page-number` (`p.total < o.from`).
- **Evidence:** VERIFIED: `exp/out/din75-1.png` shows "Page 1 of 4" on page 1, and `din75-4.png` shows the number in both the header and the footer.
- **Fix:** define `from` as the first _current_ page that shows a number. Drop `page-number` from DIN `classic` when `continuation` already shows it, or remove the number from `continuation`.

### PLAT-10 (nit): the ZUGFeRD XMP extension schema is absent

- **Where:** §5.3 row 1 ("keywords incl. ZUGFeRD").
- **Evidence:** VERIFIED: the XMP in `exp/out/std-a-3b-classic-din-5008-a.pdf` has no `urn:factur-x` / `fx:ConformanceLevel` / `fx:DocumentType` entries, only `pdf:Keywords`. Typst 0.14 and 0.15 expose no custom XMP API.
- **Fix:** state it as a known platform limit (it predates 0.4.2). Strict ZUGFeRD validators (Mustang) may flag it. Keywords are not a substitute.

---

## Reproduction index (all under `scratchpad/crit-platform/`)

- `exp/std.typ`: look × layout × standard × logo variants; outputs `exp/out/std-*.pdf`.
- `exp/stat.typ` + `exp/lh.typ` / `exp/lh.pdf`: stationery SVG vs PDF.
- `exp/cmyk.typ`: CMYK guard.
- `exp/bench-{1,150,400}.typ`, `exp/bench-400-{nofurn,plain,static}.typ`, `exp/bench-themed.typ`, `exp/base/` (0.4.2 baseline, a copy of the repo's `src`).
- `exp/mp2.typ`: DIN multi-page and footer overflow; PNGs `exp/out/din75-*.png`, `dinbig-*.png`, `dinbig-footer-crop.png`.
- SN reserved zone: `exp/out/mp55-*.png`, `mp60-*.png`.
