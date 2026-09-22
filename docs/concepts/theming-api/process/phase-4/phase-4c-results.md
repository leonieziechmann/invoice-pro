########## fix-layouts
workdir <session>/v2/fix-layouts commit e957665 (branch main of the fix-layouts clone)
TESTS: scripts/run-all.sh passes 742/742 with exit 0 on Typst 0.15.1 (Windows Git Bash, 15m09s, logs/run-all-fix-layouts-0151.txt) and 742/742 with exit 0 on Typst 0.14.2 (WSL, native copy in /tmp/ipfl, FONTCONFIG_FILE=/tmp/ip-fonts.conf, 9m35s, logs/run-all-fix-layouts-0142.txt). That is the previous 620 plus 122 new checks: dense header 20, swiss 22, one-page 80. The first 0.15.1 run gave 739/742. Two failures were the footer-fit lint message changing, so explicit margins now keep the full footer check. The third was the boxed 3-page budget, raised from n=40 to n=52. Envelope fit, proofs and the DIN/SN geometry checks pass unchanged. typstyle --check passes on src, tests and baseline-042. scripts/figures-build.sh built a local copy (out/figs, PPI 60): fig-layouts shows a4-dense and us-letter-dense clean and both SN layouts on 1 page. I also looked at renders: all 10 presets on a4-dense, the US sender contact sheet (all on 1 page), boxed on de/at/us, corporate and bold on sn-left, and the Swiss right/left/reserved renders.
SUMMARY: All three layout items are fixed and committed as e957665. The full suite passes 742/742 on both Typst 0.15.1 and 0.14.2. That is the previous 620 checks plus 122 new ones in scripts/checks-fix-layouts.sh, which run-all.sh calls with one line.

(1) Dense layouts (O8). a4-dense and us-letter-dense now arrange the header row with a function, `_dense-arrange`. A compact title, like compact's stacked one, keeps its natural width in the third column. A title that fills its line (a row with number and date, or a banner such as bold's) moves above the recipient | references row, the same way the digital layouts place it. A render of all 10 presets on a4-dense is clean, the rebuilt fig-layouts has no overlap, and the DEFECT notes are gone from tests/figures-sheets.typ.

(2) Swiss layouts (O1). sn-010130-right and sn-010130-left no longer reserve the QR-bill zone and print no placeholder. The zone is now an explicit opt-in: `theme.layout.reserve-qr-bill(layout)`, marked as a 0.5.x preview that prints a placeholder slip. I chose a helper over separate layout variants for four reasons:

- It says what it does (reserve a zone), so it reads as a deliberate step, not a different page master.
- It works with any A4 layout (right, left or a custom derived one) without doubling the catalogue with names like sn-\*-qr.
- The layout keeps its name, so the lint/qr-bill-paper message stays byte-identical.
- When the QR-bill component ships, the helper can switch the real slip on without renaming any layout.
  With layout: auto, a Swiss sender gets sn-010130-right on 1 page. All 10 presets fit 4 items on 1 page on both SN layouts.

(3) One page for small invoices. The new check renders every preset in every sender region (10 × 8, layout: auto, region locale, n=4) and requires exactly one page. At first 9 cases failed after the Swiss fix: boxed in de/at/fr/it/es/gb/us, elegant/us and bold/us. I measured how much each was short with a vertical-offset probe (boxed/us 30 mm, boxed/at 24 mm, boxed/fr and gb 12 mm, boxed/de 5 mm, bold/us 3 mm, elegant/us 2 mm) and made these fixes:

- **us-letter-10 footer:** it now carries only the contact block. The letterhead already shows the company name and address, and US invoices need no legal footer. This gives about 8 mm on every US window invoice; classic/us went from 2 mm to 10 mm of spare room.
- **us-letter-digital:** top margin is now the usual US 1/2 in instead of 18 mm, because Letter is 17.6 mm shorter than A4.
- **Frame:** a computed bottom margin on a one-page invoice is now sized for the page-1-of-1 footer only, without room for the "Page 1 of n" folio. It never makes the margin smaller as pages are added, so the page count settles. An explicit margin is still linted against every footer case, so the error messages stay byte-identical.
- **boxed (the main cause):** tight signature, 9.5 pt body, and smaller insets on rows, form cells, totals and the QR box.
- **corporate:** tight signature and tighter section spacing, so it also fits on sn-010130-left.
- **bold:** slightly smaller poster, totals-bar and block spacing.
  The envelope tests and the DIN/SN geometry are unchanged; no body-top or address/info values were touched.
  CHANGES:
- src/theming/layouts.typ: new `_dense-arrange`, used by a4-dense (and so us-letter-dense): recipient | references | title in one row, a wide title moves above the row (O8)
- src/theming/layouts.typ: removed the qr-bill area from sn-010130-right (and so -left); SN layouts are now documented as EXPERIMENTAL with no zone
- API: src/theming/layouts.typ + src/public/layout.typ: new `theme.layout.reserve-qr-bill(layout)`, a 0.5.x-preview opt-in that adds the 210 x 105 mm isolated QR-bill zone (placeholder slip) and keeps the layout name
- src/theming/layouts.typ: us-letter-10 footer now holds only the contact block (the letterhead already shows the company), about 8 mm more body room on US window invoices
- src/theming/layouts.typ: us-letter-digital top margin changed from 18 mm to 0.5 in (Letter is 17.6 mm shorter than A4)
- src/theming/frame.typ: a computed bottom margin on a one-page invoice uses only the page-1-of-1 footer; explicit margins are still linted against every footer case
- src/theming/looks/boxed.typ: tight signature, body 9.5pt, row-inset 0.3em, tighter form/title/totals/payment insets and QR box (boxed was the main cause of the one-page failures)
- src/theming/looks/corporate.typ: tight signature, tighter section heading and payment box spacing (fits sn-010130-left)
- src/theming/looks/bold.typ: poster insets 4.5/5 mm (was 5/6), 5 mm above the title word (was 6), totals bar y inset 3 mm, bank and payment spacing above 1em
- tests/dense-header.typ: new; each part reports its box, the test asserts no overlap and no squeezed cell (fails on the old layout for classic and bold)
- tests/swiss.typ: new; no qr-bill area on the SN layouts or on auto for a Swiss sender, no placeholder drawn, 1 page for 4 items; reserve-qr-bill draws the zone
- tests/one-page.typ: new; preset x sender region x layout (auto or explicit) must render on exactly 1 page; check=0 renders a failing case for inspection
- scripts/checks-fix-layouts.sh: new, 122 checks (dense 20, swiss 22, one-page 80); scripts/run-all.sh sources it with one line
- tests/errors/err.typ: case 32 now uses reserve-qr-bill(sn-010130-right) to trigger lint/qr-bill-paper; the expected text is unchanged
- scripts/checks-presets-business.sh: boxed 3-page test goes from n=40 to n=52 (boxed is denser now; 3 pages for n=44..70)
- tests/figures-sheets.typ: DEFECT notes and the DEFECT rendering in note() removed; SN captions now say 'experimental'
- logs/run-all-fix-layouts-0151.txt, logs/run-all-fix-layouts-0142.txt: full suite logs
  OPEN:
- Spare room (how much extra vertical space still fits on 1 page, measured on both compilers): bold/us 6 mm, elegant/de and elegant/at 6 mm, elegant/us 4 mm, boxed/at and boxed/us 4 mm. Explicit sn-010130-left: bold under 0.5 mm, corporate under 2 mm, soft at least 6 mm. The checks pass deterministically, but bold and corporate on sn-left have almost no reserve; sn-left's body-top of 97 mm (C5/6 DIN-position window edge at 93 mm plus 4 mm) is the limit.
- The one-page margin rule has hysteresis. If the first layout pass comes out on 2 pages (bold on sn-left was inflated in pass 1 by something unrelated to the margin), the page count stays at 2 even when the invoice would fit with the smaller margin. It is never worse than before and does not oscillate. A fully lower-fixpoint version would cost an extra layout pass on multi-page invoices (O11), so I did not do it.
- The bundle README (not in this branch) needs updating: O1 and P3 (SN layouts now reserve no zone; the new reserve-qr-bill helper), O8 (dense fixed; the page-count part is done), the §2.1 export table (reserve-qr-bill), the fig-layouts caption and the figures/ images (run sh scripts/figures-build.sh in the bundle), the §13.1 suite table (742), and the layout table row that says 'right / left + QR-bill zone'.
- Design changes to review: us-letter-10 has no company block in the footer (letterhead only); boxed and corporate close with a tight signature and no handwriting gap; boxed body is 9.5pt.
- Not addressed: prestige's sender name wrapping in the narrow SN letterhead box, soft's totals card possibly starting a page alone, and compact relying on the widow fallback (other O8 items).

########## fix-polish
workdir <session>/v2/fix-polish commit a596e5d
TESTS: scripts/run-all.sh: 630/630 ok, 0 FAIL, exit 0 on Typst 0.15.1 (Windows Git Bash, 27m33s) and on Typst 0.14.2 (WSL nix, native copy /tmp/ipfp, FONTCONFIG_FILE=/tmp/ip-fonts.conf, 18m10s). The 10 new checks: the serif letterhead unit test; 64 stress compiles (prestige and elegant x 16 layouts x wide/tall logo, counted as 1 check); the export lists; the draft report in de, en, fr, it and es (5 checks); the issue keys in src match the localised keys (16); the doc logos are logo assets. tests/polish/exports.typ and tests/polish/arrange.typ were confirmed to fail on the old tree. The strict panic texts are unchanged: errors 41 cases and validation 10 cases, byte-identical. typstyle 0.14.1 --check is clean for src, tests and baseline-042 (generated tests/doc and tests/pkgs excluded). Visual checks at --ppi 110: all 17 prestige layout settings, elegant and prestige on a4-dense and us-letter-dense, the letterhead stress cases, the prestige gallery on sn-010130-right, the German draft report, and the p2 (print, pdf, einvoice), p1 and p7 doc renders. pdf-standards.sh was not re-run.
SUMMARY: All four items are done on branch main of the fix-polish clone, commit a596e5d. The full suite passes 630/630 with exit 0 on both compilers: 620 earlier checks plus 10 new ones in scripts/checks-fix-polish.sh, which run-all.sh calls with one line. On Typst 0.15.1 (Windows) it took 27m33s; on 0.14.2 (WSL, native copy /tmp/ipfp, FONTCONFIG_FILE=/tmp/ip-fonts.conf) it took 18m10s. The logs are in logs/run-all-fix-polish-0151.txt and -0142.txt. typstyle --check is clean for src, tests and baseline-042 (the generated tests/doc and tests/pkgs are excluded, as in earlier stages).

1. prestige on sn-010130-right. The cause of the white bars: when the logo sat beside the name, the serif letterhead put it in a grid with two auto columns. In the narrow 80 x 30 mm box Typst shrank the logo column, so the white plate came out narrower than the logo and showed as bars above and below it. The layout is now picked in this order: logo above the name if it fits; beside it if the name keeps its one-line width there (the logo column has the logo's own width); above with the logo scaled to the height left (at least 45 %); beside with the logo scaled to at most 40 % of the width. The sender name now stays on one line: narrow tracking first, then a smaller size down to 72 %. Only very long names still wrap: a 35-character name wraps to 2 lines with the wide logo and 3 with a tall square one in the SN box.
   While checking the whole prestige matrix at --ppi 110 (17 layout settings) I found that a4-dense and us-letter-dense were also broken for prestige and elegant. The recipient, references and title overlapped, the same defect O8 describes for classic. I fixed it for the serif family only: when the title shares a row with other parts, it now renders compact and right-aligned instead of taking the whole row. After that all 17 prestige renders look clean. I also checked stress cases: a long name, a wide logo, a tall logo and an on-dark text logo, on sn-010130-right/left, din-5008-a, us-letter-10 and a4-dense, plus the prestige gallery on SN.

2. API hygiene. theme.custom now comes from a new facade file, src/public/custom.typ, which re-exports only the 29 documented helpers. emit, clean-auto, _tokens, \_options and \_wrap-marker no longer leak. The other public modules (theme, theme.layout, theme.parts, the package root) already matched the documented lists. There is no public validation module or helper: validation is only the invoice(validation:) and theme.resolve(validation:) parameters plus the --input override. The new test tests/polish/exports.typ compares each module's exported names with the documented list. It also asserts that no public module (including locale, tax, unit, country, references and info) exports a `_` name or a known internal. It fails on the old tree.

3. Report language (O5). Every theme and lint issue, and the invalid-IBAN issue, now carries a key and its values. Texts for the 16 keys, and for the four required roles, are in all five languages (de, en, fr, it, es). Paths and code stay as code spans, and numbers use a decimal comma outside English. If a locale has no text for a key, the report falls back to the English developer message. The strict-mode panic texts are unchanged; tests/errors/expected.txt and tests/validation/expected.txt still match byte for byte. The new test tests/polish/report-lang.typ checks every text in every language with sample values, the fallback, the number format and the localised role text. It also renders a real draft with an invalid IBAN, a logo without alt text, a fine size under 6 pt and a failed contrast pair, in each of the five languages. I looked at the German report render: all five rows are in German.

4. Doc logos. The doc fixtures used the full-page letterhead copy not only for p2's acme.svg but also for logo.svg and sw.svg, so I replaced all three. The new sources are tests/logo-acme.svg (the ACME wordmark), tests/logo-mark.svg and tests/logo-sw.svg. make-doc-tests.py now copies these, so the snippet text in the document is unchanged. I checked the p2 renders (print, pdf, einvoice) and p1, p6, p7 and presets.
   CHANGES:

- src/theming/looks/serif.typ: letterhead-arrange picks, in order, logo above / beside / above scaled / beside scaled, and the logo column always has the logo's width (fixes the white bars on sn-010130-right); sender name stays on one line (narrow tracking, then down to 72 % size); a title that shares a row (a4-dense, us-letter-dense) renders compact and right-aligned
- API: src/public/custom.typ (new): theme.custom now re-exports only the documented helpers; emit, clean-auto, \_tokens, \_options and \_wrap-marker are no longer exported
- src/public/theme.typ: imports custom from the new facade
- API: src/validation/issue.typ: issue() takes optional key and args; issue records gain key and args fields
- src/validation/render.typ: localized() gives the report text in the document's language, falling back to the English message
- src/theming/validate.typ, src/theming/frame.typ, src/theming/parts/body.typ, src/components/root.typ: every theme/lint issue and the IBAN issue passes a key and args (role, overprint, window, qr-bill-paper, envelope, part-none, part-empty, fine-size, logo-alt, cmyk, pdf-image-\*, contrast, footer-fit, identity, iban)
- src/theming/proof.typ: an envelope that does not fit also returns its numbers (misfit-args) for the localised text
- API: src/locale/lang/{base,en,de,fr,it,es}.typ: new strings.validation.issues (16 texts) and strings.validation.roles (4 texts)
- tests/coverage.typ: drops emit/clean-auto from the list of non-group helpers (no longer exported)
- tests/polish/exports.typ (new): exported names of the public modules == the documented lists; no internal names anywhere
- tests/polish/report-lang.typ (new): texts for every key in every language, fallback, number format, and a real draft report rendered per language
- tests/polish/arrange.typ (new): unit test that the serif letterhead fits its box and never squeezes the logo column (fails on the old code)
- tests/polish/letterhead.typ (new): stress fixture with a long name and wide/tall/light logos on any layout
- tests/logo-acme.svg, tests/logo-mark.svg, tests/logo-sw.svg (new), and tests/doc/{acme,logo,sw}.svg: logo-sized marks replace the full-page letterhead copies
- scripts/make-doc-tests.py: copies the new logo sources
- scripts/checks-fix-polish.sh (new, 10 checks) plus one line in scripts/run-all.sh
- logs/run-all-fix-polish-0151.txt and logs/run-all-fix-polish-0142.txt: 630/630 on each compiler
  OPEN:
- O8 is fixed only for the serif family. On a4-dense and us-letter-dense, classic and the other non-serif looks still overlap in the header row. The DEFECT notes in tests/figures-sheets.typ, and fig-layouts/fig-matrix in the bundle, still need a rebuild with scripts/figures-build.sh once the core fix lands. The bundle README's O8 text about the prestige wrap is now outdated.
- O1 is unchanged: sn-010130-right still prints the placeholder QR-bill slip on page 2.
- In the SN box, a very long sender name (about 35 characters) still wraps: 2 lines with a wide logo, 3 with a tall square logo. This is inherent to an 80 x 30 mm box.
- Locale merges go only two levels deep. A user override of strings.validation.issues replaces the whole dictionary, and the missing keys then fall back to the English developer message. The planned locale.custom.validation helper (depth-3 merge) is still open; O5 in the bundle README should be updated to say the report is now localised.
- The bundle's §2.1/§7 text could mention the new strings.validation.issues/roles groups and the issue key/args fields. bundle/prototype is a copy of the old FINAL and has none of these changes; it needs refreshing after the merge.
- The test for the logo column in tests/polish/arrange.typ inspects the grid that letterhead-arrange returns, so it is tied to how the arrangement is built.
- scripts/pdf-standards.sh was not re-run on this branch.

########## merge
workdir <session>/v2/final commit 8a2e546
TESTS: scripts/run-all.sh on Typst 0.15.1 (Windows Git Bash): 752 ok, 0 FAIL, exit 0, 14m50s. On Typst 0.14.2 (WSL nix, native copy /tmp/ippm, FONTCONFIG_FILE=/tmp/ip-fonts.conf): 752 ok, 0 FAIL, exit 0, 10m15s. Both passed on the first run after the two fixes above. scripts/pdf-standards.sh: 13/13 ok, exit 0, on both. That covers ua-1, a-3b+zugferd basic and a-3b+zugferd en16931 for classic, corporate, plain and minimal (12 checks), plus the combined a-3a,ua-1: accepted on 0.15.1 and rejected on 0.14.2, as expected. typstyle 0.14.1 --check on src, tests and baseline-042: rc=0. All files in the commit use LF line endings. Visual checks at 60-70 ppi: prestige and elegant on a4-dense (compact title in the third column, no overlap), and prestige with a tall logo on sn-010130-right (one page, no QR zone, logo plate intact).
SUMMARY: Both fix branches are merged into final on main. The fix-layouts pull (e957665) fast-forwarded. The fix-polish pull (a596e5d) had one text conflict, in scripts/run-all.sh, and one semantic conflict, in tests/polish/exports.typ. The merge commit is 8a2e546 "polish merge". scripts/run-all.sh passes 752/752 with 0 FAIL and exit 0 on both Typst 0.15.1 and 0.14.2. That is 620 base checks, 122 from fix-layouts and 10 from fix-polish. scripts/pdf-standards.sh passes 13/13 on both compilers. typstyle 0.14.1 --check on src and tests (including tests/doc and tests/pkgs) and on baseline-042 is clean, so no reformat and no suite re-run were needed. frame.typ auto-merged cleanly: the one-page footer-margin rule from fix-layouts and the key/args issue fields from fix-polish touch different hunks. The two serif and dense-header fixes also work together. The serif look renders its title compact when the title shares a row, and \_dense-arrange keeps a narrow title in the third column. I checked renders: prestige and elegant on a4-dense show recipient | references | title with no overlap. prestige with a tall logo on sn-010130-right fits on one page, with no QR zone and no white bars.
CHANGES:

- scripts/run-all.sh: resolved the conflict; it now sources both scripts/checks-fix-layouts.sh and scripts/checks-fix-polish.sh
- tests/polish/exports.typ: the documented theme.layout export list now includes reserve-qr-bill. fix-layouts added this 0.5.x-preview helper to src/public/layout.typ, and fix-polish's export test did not know about it yet
- API: the merged tree now has theme.layout.reserve-qr-bill (from fix-layouts). theme.custom comes from the facade src/public/custom.typ, and issue key/args fields plus strings.validation.issues/roles are added (from fix-polish)
- logs/run-all-polish-merge-0151.txt, logs/run-all-polish-merge-0142.txt, logs/pdf-standards-polish-merge-0151.txt, logs/pdf-standards-polish-merge-0142.txt: new logs
  OPEN:
- The bundle is out of date. Its README needs updates to O1, P3, O5 and O8, the §2.1 export table (reserve-qr-bill, strings.validation.issues/roles, issue key/args), the §13.1 suite count (now 752) and the layout table row about the 'QR-bill zone'. figures/ also needs a rebuild with sh scripts/figures-build.sh, and bundle/prototype needs refreshing from the new FINAL (8a2e546).
- O8 leftovers still not addressed: soft's totals card may start a page alone, and compact relies on the widow fallback. Also, a sender name of about 35 characters still wraps in the 80 x 30 mm SN letterhead box.
- Some layouts have little spare vertical room: bold on explicit sn-010130-left under 0.5 mm, corporate under 2 mm. The one-page margin rule also has hysteresis (see the fix-layouts report).
- Design changes for the maintainer to review: the us-letter-10 footer drops the company block, boxed and corporate use a tight signature, and boxed body text is 9.5pt.
- Locale override of strings.validation.issues replaces the whole dictionary (depth-2 merge); the locale.custom.validation helper is still open.
- In the Windows 0.15.1 environment the preset fonts (EB Garamond, Playfair Display, Bodoni Moda) are missing and fall back, so those renders use substitute fonts. Earlier stages had the same limitation.

########## republish
workdir <session>/v2/bundle commit fa19238
TESTS: - **scripts/run-all.sh on Typst 0.15.1** (Windows Git Bash, final @ 73a4696): 752 ok, 0 FAIL, rc=0, 18m17s.

- **scripts/run-all.sh on Typst 0.14.2** (WSL, git clone in /tmp/iprep, FONTCONFIG_FILE=/tmp/ip-fonts.conf, nix typst on PATH): 752 ok, 0 FAIL, rc=0, 12m53s.
- **Doc snippets:** 19 generated from the README. I compiled them plus the documented variants: p2 print/pdf/einvoice, p2 einvoice under a-3b, p2 n=12, p3 window=left, qr-bill=1, and both combined, p7 under ua-1, proof=1, and presets for all 10 presets. Result: 39/39 on 0.15.1 and 39/39 on 0.14.2.
- **Strict panic text:** the validation snippet's panic matches §7.3 byte for byte on 0.15.1. On 0.14.2 it prints the quoted form, as §13.2 says.
- **p3 page counts:** 1 page by default and 1 with window=left. With qr-bill=1 it is 2 pages, and I looked at the render: the placeholder zone sits on its own page with the footer above it.
- **Checks:** prettier 3.6.2 --check on README.md passes. typstyle --check on src, tests and baseline-042 passes (rc=0).
- **Extra sweep:** tests/one-page.typ on 10 presets × 7 explicit window layouts: 61 of 70 fit on one page, 9 need two (listed in O8).
- **Figures:** all under 600 KB. I inspected the changed sheets and page renders, zooming in on the SN tiles and on prestige on sn-010130-right.
- **pdf-standards.sh:** not re-run. No src/ change since the merge's 13/13 on both compilers.
  SUMMARY: I republished the bundle from the merged FINAL (8a2e546 plus two small commits: 73a4696 and fa19238).

**Figures.** I rebuilt all 18 figures with `sh scripts/figures-build.sh`. Twelve changed: fig-layouts, fig-matrix, fig-presets, fig-presets-industry, fig-proof, fig-validation, and preset-bold, -boxed, -classic, -corporate, -prestige and -soft. The other six came out byte-identical. I looked at every changed figure. No DEFECT mark is left. The dense layouts render cleanly: classic's row title moves above the header row. The SN tiles show no QR-bill zone and no "Page 1 of 2". prestige on sn-010130-right has the sender name on one line and an intact logo plate. At 180 ppi the fig-layouts sheet lost the first letter of every SN body line ("nvoice", "ccount Holder"). The old figure had the same fault. The script now builds that sheet at 190 ppi, and the result is clean. Every figure is under 600 KB; the largest is fig-presets-industry at 533,230 bytes, and fig-layouts is 509,318.

**README.**

- Swiss layouts: no QR-bill zone by default. The zone is the 0.5.x opt-in `theme.layout.reserve-qr-bill`. The P3 snippet now shows it with `--input qr-bill=1`.
- New §8.1 notes explain the Swiss layouts and the dense arrange rule, and Figure 4's caption no longer mentions DEFECT marks.
- The one-page margin rule is described in §6, and the 80 one-page checks in the summary, §2.3 and §9.
- §2.1 export table: `reserve-qr-bill`, the `theme.custom` facade, `strings.validation.issues`/`roles`, and a note on the export test.
- §7.2 and §7.3: issue `key`/`args` and the fully localised report.
- Also updated: §3.6, the §5.2 tiers, the §12 line counts (9,097 total), §13.1 (752, with new rows for layout fixes 122 and polish 10), §14, §15, Appendix B (R10, R18), eight Fix rows in Appendix C, and Appendix D (a step 6 for the fix stages, new paths).
- Open items: O1 is marked resolved pending the maintainer's confirmation; the only open part is shipping the QR-bill component. O5 is resolved for the report; the `locale.custom.validation` helper stays open because a locale override of `issues` replaces the whole dictionary. O8 is rewritten with what was fixed and what is still open.
- prettier 3.6.2 --check passes.

**New finding.** The one-page guarantee holds only for `layout: auto`. I ran `tests/one-page.typ` on all 70 preset × explicit window layout pairs, and 9 need two pages:

- corporate on din-5008-b, a4-window-right and us-letter-10
- bold on din-5008-b, a4-window-right, a4-window-left and us-letter-10
- technical on din-5008-b
- soft on us-letter-10

In fig-matrix, corporate on us-letter-10 continues on page 2 (only its signature moves there). The O8 text and the Figure 2 caption say so.

**Doc tests.** I regenerated them with `scripts/make-doc-tests.py` (19 snippets). All compile on both compilers: 39/39 cases each on 0.15.1 and 0.14.2, counting the documented variants. Running the generator from bundle/prototype produces no diff.

**Prototype.** bundle/prototype is a clean `git archive` of FINAL without logs/: no .git, out/ or generated PNG/PDF files, but tests/fake.pdf and the SVG assets are kept. Its file list matches FINAL's tracked files minus logs/, and every file is byte-identical.
CHANGES:

- bundle/figures/\*.png: rebuilt all 18; 12 changed (fig-layouts, fig-matrix, fig-presets, fig-presets-industry, fig-proof, fig-validation, preset-bold/-boxed/-classic/-corporate/-prestige/-soft), 6 byte-identical; all under 600 KB; no DEFECT marks
- bundle/README.md: status and summary (752 checks, the Swiss opt-in, O1 now asks for confirmation); §2.1 exports (reserve-qr-bill, theme.custom facade, strings.validation.issues/roles, export test); §2.3 visual guards; §3.6 qr-bill part; §5.2 tiers; §6 one-page margin rule and R18 row; Figure 2 caption; §7.2 issue record with key/args; §7.3 localised report; §8.1 SN row, new Swiss and dense notes, Figure 4 caption; §9 one-page checks and the prestige font fallback; P3 text and snippet with the reserve-qr-bill opt-in; §12 line counts; §13.1 suite table 752; §14; §15; A.3 O1, O5, O8 rewritten; App. B R10, R18; App. C eight Fix rows and the 0.14.2 count; App. D step 6 and paths; prettier clean
- API (doc only): the P3 snippet now documents theme.layout.reserve-qr-bill(layout) as the opt-in for the Swiss QR-bill zone
- final/scripts/figures-build.sh: fig-layouts sheet at 190 ppi, because at 180 ppi the downsampling dropped the first letter of the SN body lines (commit 73a4696)
- final/tests/doc/p3.typ, tests/doc/snippets.md.txt: regenerated from bundle/README.md by make-doc-tests.py (commit 73a4696)
- final/logs/run-all-republish-0151.txt, run-all-republish-0142.txt: suite logs (commit fa19238)
- bundle/prototype/: rebuilt as a git archive of FINAL HEAD without logs/; the file list matches the tracked files minus logs and every file is byte-identical; fake.pdf and SVG assets kept; LF only
  OPEN:
- The one-page guarantee covers layout: auto only. On explicit window layouts, 9 of 70 preset × layout pairs need two pages with the tests/one-page.typ data: corporate on din-5008-b, a4-window-right and us-letter-10; bold on din-5008-b, a4-window-right, a4-window-left and us-letter-10; technical on din-5008-b; soft on us-letter-10. No test covers this; it is recorded in O8.
- O8 leftovers, carried over: soft's totals card can start a page alone (n=20-22 on a4-digital); compact relies on the widow fallback; a sender name of about 35 characters wraps in the 80 × 30 mm SN letterhead box; little spare room for bold on explicit sn-010130-left (under 0.5 mm) and corporate (under 2 mm); the one-page margin rule has hysteresis near the boundary; corporate's descriptions wrap in the 124 mm column.
- Design changes for the maintainer to review (listed in O8): the us-letter-10 footer drops the company block; boxed and corporate use a tight signature; boxed body text is 9.5 pt with tighter insets; bold's poster block is lower; us-letter-digital has a 1/2 in top margin.
- O1 needs maintainer confirmation, plus a decision on whether the QR-bill component ships in 0.5.0 or 0.5.x.
- O5 remainder: a locale override of strings.validation.issues replaces the whole dictionary (depth-2 merge), and the locale.custom.validation helper does not exist yet. The fr/it/es report texts need a native-speaker review.
- fig-validation shows only data and e-invoice issues, so the new theme/lint localisation is not visible in any figure. It is checked by the 5 report-lang renders in the suite.
- Figures were rendered on Windows without EB Garamond, Playfair Display and Bodoni Moda; the prestige, elegant and soft headings use the Libertinus fallback. The §9 prestige paragraph now says so.
- The README Appendix D still refers to a process/ folder that is not in the bundle. It was already there before and I left it unchanged.
