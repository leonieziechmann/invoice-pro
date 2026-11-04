# Critique of the third draft: the maintainer's decisions (accuracy and consistency)

Reviewer role: critic (accuracy and consistency). Reviewed, as committed on the branch `feature-data-api` on 2026-11-04: [`../../README.md`](../../README.md) (the concept, third draft), [`../../prototype/README.md`](../../prototype/README.md), [`../../prototype/harness/README.md`](../../prototype/harness/README.md) and [`decisions.md`](decisions.md). Ground truth: two fresh work directories built by `prototype/run.sh` from the fifteen committed patches, one per compiler (Typst 0.15.1 and 0.14.2), the harness copied into each as its README says, and the prototype's branch `proto` in the exploration's scratch directory. `<work>` below is such a work directory and `<session>` the scratch directory; neither is in the repository. Like the other files in `process/`, this critique is a record of its time.

## Verdict

The decisions are applied consistently. Each of D1–D6 is described the same way in the status line, the executive summary, the decisions table, the workflow, the API, the CLI, the error model, the ledger, the plan, §14 and the appendices, and `decisions.md` agrees with them. No section still presents the old default `"draft"` for hydrated invoices, the name `invoice-data` or the constants `input-key` and `file-key` as current; every remaining mention is marked as history. Q1, Q2, Q4, Q7, Q19, Q35, Q36 and Q39 are decided everywhere, and each keeps its place in §14 with a pointer to §14.0.

The numbers hold. `run.sh` passes 15 of 15 on both compilers with the stated md5s, the per-commit trees of the fresh `git am` equal the branch `proto`, all 12 `typst` blocks compile on both compilers and are typstyle-clean, and the fail-safe semantics behave as §8.0 describes, including the levels matrix without data. The misuse checks, the fault corpus in all four modes, P6, P8, P10 and the integration run all pass. The template's instruction cost reproduces exactly. Lint is clean.

No finding is a blocker or a major one. The 13 minor findings are wording that promises more than the code does (the debug draft "without XML", `zugferd-errors: "report"`), a few stale or miscounted figures, one question filed under the wrong heading, and the reproducibility of the import counts that the proposed gate would rest on.

## What was checked

| Check                                                                                                                                                                                                               | Result                                                                                                                                                                                                                                                           |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TYPST_BIN=<typst> prototype/run.sh <work>`, both compilers, fresh work directories                                                                                                                                 | 15 of 15 PASS; `32b0b6d5d449` (0.15.1), `679ee994c66b` (0.14.2); template `881821b7318c` / `ba5d9a49b5de` and `8a1c8b464422` / `c7e98da669bc`                                                                                                                    |
| the tree of each of the 15 commits that `git am` makes against the same commit of `proto`                                                                                                                           | identical tree ids (final tree `fac53eb7`); the commit ids of the prototype README are those of `proto`                                                                                                                                                          |
| `git diff --numstat df934a7` of the patched tree against the prototype README's file table and totals                                                                                                               | 46 files, +33 364 / −102; every per-file count of the README matches                                                                                                                                                                                             |
| §11.1 and the executive summary: Typst lines and bytes of `src/`                                                                                                                                                    | +5002 net Typst lines on 32 813; 1 131 975 → 1 415 660 bytes; schemas 108 015 bytes: all match                                                                                                                                                                   |
| the 12 `typst` blocks of the concept: typstyle 0.15.1 `--check`, compiled against `<work>/repo` alone and hydrated with inline data, both compilers                                                                 | 12 of 12 clean and compiling alone; hydrated, 9 compile, and the 3 others stop as they should (§5.1 and §5.3 pass `data:` themselves, so inline data is a second source, R7; the §6.2 wrap fragment has no `line-items`); no versioned import                    |
| §2.1 block against `prototype/examples/skeleton.typ`; §4.1, §4.3, §4.4 against `src/invoice.typ`, `src/public/data.typ`, `src/public/payment.typ`; the §2.0 diff and header against `template/invoice.typ`          | identical (bodies elided as stated)                                                                                                                                                                                                                              |
| `misuse/p3.sh`, both compilers                                                                                                                                                                                      | 47 of 47 PASS                                                                                                                                                                                                                                                    |
| `fuzz/fuzz.py <typst> none\|auto default\|draft`: 8 runs                                                                                                                                                            | 69 faults each, 0 hard aborts, 0 wrong outcomes; default: 59 stops with the hint, 9 (none) or 7 (auto) clean PDFs, the format-major panic, with `auto` 2 IP-ID-01 rule stops; draft: 59 drafts without an embedded file                                          |
| `payment/p6.sh` (both), `result/p8.sh` (0.15.1 and 0.14.2), `signature/p10.sh` (0.15.1)                                                                                                                             | 0 failures; 0 failures; the prototype passes and 7 of 7 mutations fail                                                                                                                                                                                           |
| `regress/integration.sh`, both compilers                                                                                                                                                                            | 66 tests: 59 identical PDFs and 7 identical errors on each                                                                                                                                                                                                       |
| invoices without data, pristine 0.6.0 against the prototype: `handwritten.typ` under no flag and the flags `draft`, `strict`, `none`, with and without a-3b; an incomplete invoice under the four levels × the same | 16 of 16 and 64 of 64 identical (the same PDF bytes, or the same exit code and the same first error line)                                                                                                                                                        |
| the stop texts of `bad.json` and of the four `broken-*.json`; badge, `check()` and result counts                                                                                                                    | as quoted in §2.2 and §8.0; `bad.json`: stop 6, badge 6, `check(.., region: "de")` 6, draft result 7; no result without the draft flag; `broken-no-recipient.json`: stop 3, badge 2 (O25)                                                                        |
| the template hydrated with §3.11's data alone, and with that data without its `payment` section, both compilers                                                                                                     | stops with "`payment.creditor-id` is required"; final, 1 embedded file, IBAN `DE07100202005821158846`, BT-81 58                                                                                                                                                  |
| the template without data, cachegrind, `--jobs 1`, both trees under names of equal length                                                                                                                           | +27.1 M (+1.17 %) on 0.15.1, +25.7 M (+1.13 %) on 0.14.2, PDFs identical: matches §7.3                                                                                                                                                                           |
| the root import, `bench/impcount.py 21 <0.15> <0.14> --names 4`                                                                                                                                                     | +3.237 M (+0.63 %; 4 name sets identical) on 0.15.1 at 4.65 M/ms, so 0.70 ms; +3.370 M (+0.70 %; +3.362 to +3.379) on 0.14.2 at 3.77 M/ms, so 0.89 ms; +12 069 B parsed (+5 823 B code); no `src/contract/*` and no `components/payment.typ` in the import trace |
| the new and changed tests of the prototype (`tests/data/contract`, `tests/theme/exports`, `tests/validation/api`, `tests/data/conformance/check-all.typ`), both compilers                                           | compile, assertions hold                                                                                                                                                                                                                                         |
| prettier 3.6.2 `--check` on every Markdown file under `docs/concepts/data-api/`; typstyle on every `.typ` file there and on the 40 changed `.typ` files of the patched tree                                         | clean                                                                                                                                                                                                                                                            |
| local paths in `docs/concepts/data-api/`                                                                                                                                                                            | none (a naive pattern matches only the verifiers' placeholder paths in `verification.md` and an example path in a research note); `process/` other than `decisions.md` is unchanged by the third draft                                                           |
| leftovers: `invoice-data`, `input-key`, `file-key`, a draft default for hydrated invoices, a decided question presented as open                                                                                     | none outside history and the internal constants of `src/contract/input.typ`                                                                                                                                                                                      |

## Findings

Every finding is minor. Locations are those of the committed files.

### 1. The debug draft is not always "without XML", and the draft flag does not cover e-invoice rule errors

The template's header says the draft flag gives "a draft that marks every problem, without XML". The executive summary says it "attaches no e-invoice", and step 2 of §2.2 says "No XML is attached, and the build exits 0". The draft-flag row of §5.6 says `withheld`, and decisions.md D1 says "and no XML". The status description of the result schema says the same ("rendered as a draft and the e-invoice withheld"). In the prototype, as in 0.6.0, only a class-`data` issue withholds the XML.

- `misuse/layout.typ` hydrated with the complete `2026-0042.json` and the draft flag gives "ENTWURF · 6 Probleme" with `factur-x.xml` attached (0.15.1). The stop's own hint is right: it leaves out ", and it attaches no e-invoice" when no data problem is among the issues.
- When the only problem is a data-only e-invoice rule (Q5: a GLN `"abc"` in the recipient's `global-id`), the default stops with the e-invoice assertion, which has its own hint (`zugferd-errors: "report"`) and not the debug hint. With the draft flag it stops the same way. The draft flag gives no draft.

§5.9 already explains the second case. Fix: write "without XML when a data problem is among them" or leave the XML out of the template line, and add one sentence on e-invoice rule errors to the debug loop of §2.2 (and its row in §5.6). The result schema's description is pre-existing (patches 0001–0010); S5 can correct it.

### 2. `zugferd-errors: "report"` on a hydrated invoice is called "a draft", but it exits 0 with a final-looking PDF

§8.5 says that with `zugferd-errors: "report"` "the invoice is a draft with `e-invoice.status: "draft"`", and §5.9 says such a skeleton "gets a draft". Measured on both compilers, with §3.11's data plus a bad GLN in the skeleton of §2.1 with `zugferd-errors: "report"` and no flag: exit 0, no badge, a report page, `invoice-draft.xml` attached, and a result with `status: "ok"`, `validation: "strict"`, `e-invoice.status: "draft"`. Only the e-invoice is a draft. §5.6 has it right (`ok` / `draft`).

Fix: correct the two sentences, and add `zugferd-errors: "report"` next to `none` in §8.0 as the second explicit way to let a hydrated invoice with e-invoice errors leave with exit 0. That is consistent with "explicit values keep their meaning", but under fail safe it should be visible where the levels are explained.

### 3. §11.3 counts the decisions' round as 12 pass and 3 partial

The verification table of decisions.md has 14 checks: 11 pass, 2 partial and 1 no verdict (the timing methods). The text under §11.3 counts the no-verdict check as partial, which gives 11 pass and 3 partial. Fix: "D | decisions | 11 | 3 | 0 | 0", or a footnote for "no verdict".

### 4. Stale per-file line counts in §4.6 and the ledger

These figures are carried over from the second draft unchanged. Patch 0014 shortened the comments, and the prototype README has the final numbers:

| Location | The concept says                             | The patched tree (`git diff --numstat df934a7`) |
| :------- | :------------------------------------------- | :---------------------------------------------- |
| L9       | `src/components/line-items.typ` (+36, −2)    | +27 / −2                                        |
| L27      | `src/components/payment-terms.typ` (+13, −3) | +12 / −3                                        |
| L28      | `src/logic/modifier-applicator.typ` (+13)    | +11                                             |
| §4.6     | `src/components/dynamic.typ` +4              | +3                                              |
| L13      | `src/zugferd/model.typ` (+3)                 | +3 / −1                                         |

### 5. The executive summary gives the cost as 30–41 days, §12 as 30.5–41

The summary's own parts add up to 30.5 d at the low end (26.5 + 1.5 + 2.5), and so does §12 ("about 30.5–41 d"). Fix: "About 30.5–41 maintainer-days".

### 6. The issue-id prefix is filed under "Please confirm", but its recommendation changes the prototype

§14.1 defines its items as "settled by the prototype or by a draft". The first Q19 follow-up (`bank` or `account`) fits that: the recommendation keeps what the prototype does. The second does not: the prototype writes `schema/<pointer>`, and the recommendation is `data/<pointer>` (S2, +0.25 d). That id appears in the draft report and in the result record's `issues[].id`, which pipelines read. "Please confirm the two name follow-ups" (executive summary) is therefore ambiguous: a "confirmed" could mean either prefix. Fix: move the prefix to §14.3 as an open decision with its recommendation and alternative, or say in §14.1 that confirming it means changing the prototype's ids. decisions.md ("Not applied") is accurate either way.

### 7. The import counts move between runs by more than the stated A/A floor

The concept and decisions.md give one verifier's counts, +3.369 M and +3.450 M, with an "A/A floor ±0.02 M", and propose to gate on these counts (Q3, S5). That floor is the spread within one run. The committed instrument, `bench/impcount.py`, re-run in a fresh work directory, gives +3.237 M on 0.15.1 (4 name sets, all equal) and +3.370 M on 0.14.2. The implementer reported +3.40 M and +3.32 M with the same script. The verifier's own tool (`<session>/verify-decisions/r2/icount.py`, which also copies `typst.toml` and uses another tree path) is not in the repository. A different length of the work directory's path moved the 0.15.1 count by a further 0.04 M (+3.229 to +3.265 M). Across the three measurements the delta is +3.24 to +3.40 M on 0.15.1 and +3.32 to +3.45 M on 0.14.2. That spread of up to 0.16 M (about 5 %) is eight times the stated floor.

The verdict does not change. This run gives 0.70 ms (0.15.1, 4.65 M/ms) and 0.89 ms (0.14.2, 3.77 M/ms), and all three measurements stay under 0.8 % of the import. Fix:

- give the range across the measurements in §7.3, §7.5, §13 and decisions.md, and call ±0.02 M the floor within one run;
- note that the committed `impcount.py` gives the lower 0.15.1 figure;
- let the S5 gate count pristine and candidate in the same run, with the tree path fixed and a stated tolerance.

### 8. The facade does not carry a one-line doc for every parameter

§4.3 says that the package import parses "a one-line doc comment per function and parameter". Five parameters of `src/public/data.typ` have only their `/// -> type` line: `check(data, region:)`, `values(record)`, `items(sample)` and `schema(kind:)`. Fix: "per function and for most parameters", or add the five lines (a few hundred instructions each). decisions.md's wording ("a one-line doc comment and every `/// -> type` line") is accurate.

### 9. The milliseconds for `handwritten.typ` do not follow the stated rate

§7.3 and decisions.md give +11.24 M as "about 2.7 ms" on 0.15.1 and +10.26 M as "about 2.55 ms" on 0.14.2. At the import's untraced rate stated a few lines earlier (4.28–4.54 and 3.76–3.84 M per ms) they are 2.5–2.6 ms and 2.7 ms: the two values read as swapped. They were probably converted at the whole invoice's own rate. Fix: name the rate, or convert at the import's rate as for the budget.

### 10. The S2 docs list misses three places that state the old default

L26 lists `tests/TESTING.md` and `tests/docs/**` in general, but the S2 column names pages one by one and leaves out:

- `tests/TESTING.md` line 412: "`invoice(validation: ..)` defaults to `"draft"`";
- the doc test `tests/docs/api-invoice-validation-draft/test.typ`, whose comment "draft (the default)" mirrors `validation.md`;
- `docs/docs/getting-started.md` line 83, which describes the draft as what happens when a field is missing. That is still true without data, but should name the hydrated case. S6 lists "both READMEs, the intro", and not this page.

### 11. The template's E-INVOICE section now reads against its DATA section

The unchanged E-INVOICE section of `template/invoice.typ` says: "While required data is missing, the invoice is a draft with markers and a report page, and no XML is attached. `validation: "strict"` stops the compilation instead". The new DATA section a few lines below says that a hydrated invoice stops on any problem. Both are true, one without data and one with it, but the first does not say so. Fix: start the sentence with "Without data," (a comment, so the PDF and the golden files do not change), in patch 0013 or when S6 ports it.

### 12. `selfcheck.sh` skips one of the four fault-corpus modes on 0.14.2

The harness README's table after the decisions says `fuzz.py <typst> none|auto default|draft` ran 4 times "for both" compilers, and so did the verifier. The P4 step of `selfcheck.sh` runs `$T none`, `$T14 none` and `$T auto` per mode, so a self-check never runs 0.14.2 with an e-invoice. All 8 runs pass (above). Fix: add `python3 -I fuzz.py $T14 auto $m`.

### 13. decisions.md numbers the `run.sh` check by the script's sections

"`run.sh` check 3 became two checks" uses the section numbers of the script's header. The prototype README numbers the checks 1–15, where these are checks 6 and 7. Fix: "section 3 of `run.sh` (checks 6 and 7)".

## Consistent across the documents

- **D1, fail safe.** The same rule everywhere: `validation: auto` means `"strict"` when hydrated and `"draft"` otherwise. The other parts agree in every section too: explicit values unchanged, the flag wins and `=auto` is no override, `=draft` as the debug view, `=none` as "off means off", data problems still class-`data` issues, one deferred stop that lists every problem with the hint, misuse and R7 panics unchanged, `zugferd-errors` still `"panic"`. Exit codes, the absence of a result when the build stops, the pipeline of §5.9 and the preview caveat (§2.2, risk 26) all follow from it. The §8.0 table matches the code of `resolve-level` and of the stop.
- **D2 and D3.** Recorded as decided in decision 5, §3.4, §3.8, §6.1 and R2 (D2), and in decision 9, §2.4, §4.5 and §14.4 (D3). The behaviour is unchanged from the verified prototype.
- **D4, the import budget.** The same figures everywhere: summary, decision 23, §7.3, §7.5, L38, §9, §13, Q2, Q3, Q8 (the 0.08–0.26 ms left over is consistent) and O11. The conversions 0.74–0.79 and 0.90–0.92 ms and the break-even imports of 153 and 139 ms follow from the stated rates.
- **D5, the template.** The diff, the header and the md5s agree between §2.0, L33, §7.3, the prototype README and decisions.md and the tree. The figures reproduce: +1.17 %, the creditor-ID stop, and the data without a payment section.
- **D6, the names.** `data` with 8 names everywhere, the house rule stated (§4.3, decision 14, L4) and the shadowing caveat placed where the second draft argued against the name (§4.3, L4, L5, risk 19, Appendix B 18). `record` and `raw` are used in the blocks. The `--input` keys and the label are kept, and so are the keys that mirror the existing API.
- **The branch.** `feature-data-api` in the status line, §12 and §14.0, with the old remote branch named as still to be deleted on GitHub.
