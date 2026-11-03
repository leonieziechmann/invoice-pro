# Critique of the data API concept (maintainer)

Reviewer role: the package maintainer who must decide on the concept and later implement it. Reviewed on 2026-11-03: [`../../README.md`](../../README.md) (the concept) and [`../../prototype/README.md`](../../prototype/README.md), against the theming concept ([`../../../theming-api/README.md`](../../../theming-api/README.md)), the house conventions ([`../research/conventions.md`](../research/conventions.md)), the deviations, the build and verification reports, and the prototype's diff (`git diff df934a7 proto`, 39 files). Scratch work is in `<session>/critique-maintainer/`. Every number below is either quoted from the reports or was measured during this review, and then says so.

## Verdict

The design is sound, and the evidence is unusually strong. The skeleton workflow, re-entry, the bulk motif and the data issues answer the request. P1 and P2 are byte-level proofs on both compilers, and I could reproduce the core of them.

The document is not yet ready for me to sign off as a plan. Five things block that:

1. The tools behind the planned CI gates are not in the repository (B1).
2. One ledger row has the wrong kind, and its justification does not hold (B2, reproduced).
3. The executive summary does not state the cost or the size of the change (M1).
4. Some open questions are not decidable as written (M4).
5. The plan ignores infrastructure the repository already has: Mustang and KoSIT in CI, golden XML, flake apps, the cachegrind support of `measure.py` (M5).

None of this changes the API, but all of it changes the effort. After these fixes I expect to be able to decide.

## Lint and reproduction

| Check                                                         | Result                                                                                                                                                                                                           |
| :------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| prettier 3.6.2 `--check`, both READMEs                        | pass                                                                                                                                                                                                             |
| typstyle 0.15.1 `--check`, the 7 `typst` blocks               | 7 of 7 clean                                                                                                                                                                                                     |
| compile the 7 blocks against the prototype                    | 7 of 7 on 0.15.1 and on 0.14.2 (with a `party` dictionary prepended, as the status paragraph says)                                                                                                               |
| local paths, versioned imports in `typst` blocks              | none                                                                                                                                                                                                             |
| §2.1 block vs `prototype/examples/skeleton.typ`               | identical except the import and a 4-line header comment (the text says "without its import line" only)                                                                                                           |
| `prototype/run.sh` from a clean clone                         | 12 of 12 PASS on 0.15.1 (`32b0b6d5d449`) and on 0.14.2 (`679ee994c66b`), re-run for this review                                                                                                                  |
| typstyle on the patched `.typ` files and `prototype/examples` | clean                                                                                                                                                                                                            |
| every file of the diff appears in the ledger                  | yes, all 39 (table below)                                                                                                                                                                                        |
| `scripts/check-version 0.6.0` at the next bump                | will list 31 lines of the concept and 6 of `prototype/README.md` that name 0.6.0 as the baseline (prose, no imports). The theming concept has 20 such lines for 0.5.0, so this is accepted practice; noted only. |

## Findings

### Blockers

**B1. The harness that the plan's CI gates depend on is not in the repository.** The plan asks for these gates:

- S1: "the fault corpus as a CI job", a CI job that compares python-jsonschema and ajv with `check`, a codegen job;
- S3: "the generated equivalence suite as a CI gate";
- S5: a perf gate and a CLI matrix.

The tools for them stayed in `<session>/exp/unified/proto/`, which §11.4 and Appendix C say is "not part of the repository": `gen/gen.py`, `eq/eq.sh`, `fuzz/fuzz.py` and its corpus, `schema/make_fixtures.py`, `schema/agree.py`, `schema/codegen.sh`, `bench/p9.py`, and the verifiers' corpora v3, v4 and r1. Without the generated outputs (`out/`), the scripts are about 288 KB.

There is a worse case. Patch 0002 commits `tests/data/conformance/fixtures.json`, a 23 550-line file generated by `make_fixtures.py`. `check-all.typ` says "the report CI compares with python-jsonschema", but no such comparator is in the patches. §12's MAINTENANCE item "regenerate or extend the conformance fixtures" therefore cannot be carried out from the repository.

Synthesis L19 had the fault corpus, the codegen job and the equivalence generator as tooling. The concept's L19 dropped them without saying so.

_Fix:_ commit the harness sources, without outputs, under `prototype/harness/` now. Or move the parts the plan needs to `tools/contract/` in S1 and count the effort. Either way, state in §11.4 what survives the session.

**B2. L15 (`normalize.vat-rates`) has the wrong kind, and its justification does not hold.** The region dictionary is public API. `docs/docs/api-reference/locale/base.md` documents `normalize.infer-tax`, and `locale/index.md` lists `locale.custom.normalize(..)` with `money`, `money-fine`, `infer-tax`. So `vat-rates` is a new documented key, not "internal", and its docs belong in S6.

The justification says that a region without the list "behaves as `tax: 16%` does today". That holds for a region built from `base`. It does not hold for the common case, a patched `de`: the patch replaces `infer-tax` and inherits `vat-rates: (19%, 7%)`. The same skeleton then accepts `tax: 16%` written by hand and rejects `"16%"` from data. This contradicts §1, "the data's values pass the same type checks … as values written in Typst".

Reproduced on 0.15.1 and 0.14.2. The block below assumes the prototype's `lib.typ`. It panics with "`items[0].tax`: 16% is no VAT rate of region de (19%, 7%)". The same invoice written by hand with `#item("a", price: 10, tax: 16%)` and the same `loc` compiles.

```typst
// A skeleton whose region accepts 16 % (the documented locale override).
#let loc = locale.de-de.with((
  region: (normalize: (infer-tax: x => tax.vat(x))),
))
#show: invoice.with(
  data: (
    format: "invoice-pro/1",
    invoice-nr: "1",
    date: "2026-01-01",
    recipient: (name: "X", address: "A", city: "10115 Berlin", country: "DE"),
    items: ((name: "a", price: "10.00", tax: "16%"),),
  ),
  locale: loc,
  sender: (
    name: "A GmbH",
    address: "Weg 1",
    city: "10115 Berlin",
    country: "DE",
    vat-id: "DE123456789",
  ),
  validation: "strict",
)
#line-items[#item("x", price: 1)]
```

_Fix:_ do one of three things:

- reset `vat-rates` to `none` when a patch replaces `infer-tax` without giving the list;
- make the region pass trust a replaced `infer-tax`;
- document that a custom `infer-tax` must also set `vat-rates`.

Whichever you choose, mark L15 as a new public region key with docs, and add this case to the S2 tests.

### Major

**M1. The executive summary lacks what I need to decide whether to go on.** The theming concept's summary states its cost ("about 34–46 maintainer-days"). This summary does not state:

- **The effort.** §12 gives ≈ 21.5 d for S0–S6. The plan's own recommendations add more: S8 at 1.5 d (L29 and L30 are already in the patches), and S7a plus S7b at 2.5 d (Q15: "with 0.7.0 … the margin of the perf gate"). That makes at least 25.5 d, before the items that have no estimate (M5).
- **The size.** +4970 lines of Typst in `src/`, +15 % of today's 32 813, measured on the prototype tree. The published `src/` grows from 1 131 975 to 1 413 689 bytes (+25 %). 108 KB of that are the two JSON schemas, which no Typst code reads (only `invoice-data.schema()` generates them; I grepped `src/`, `tools/` and `tests/`).
- **The biggest maintenance cost.** Until S7c and S7d (6 d, not in 0.7.0) land, the rows engine is a second implementation of the cascade of the line-item components (§13 risk 1).
- **The non-extensions, by name.** At least these: near-miss keys panic (L7), `import *` binds two more names (L5), a party `custom` loses IP-KEY-01 (L13), the new region key (L15), and two shared-path bug fixes (L29, L30). The summary says only "the few changes … are listed in §9".

**M2. The ledger misses contract surfaces that the patches or the concept create.**

- `typst query skeleton.typ '<ip-issue>'` (§5.4) turns an internal label of `src/validation/render.typ` into a documented CLI contract. The issue record shape (`id`, `class`, `message`, `ref`, `fix`, `field`, `key`, `args`, `instance`) becomes one with it, and the label is not in the docs today. This needs a ledger row, and a naming decision: `<ip-issue>` next to `<invoice-pro-result>`.
- `invoice-data.party(..)` exports the output of the internal `normalize-party` of `src/logic/country.typ` (`post-code`, `city-name`, `*-inline`). `invoice-data.values(..)` exports the decoded internal values (unit functions, tax dictionaries, `id.*` values). Changes to these internals become API changes. Name them in L4 and give them a tier.
- L9 puts every `line-items` body in a motif, with or without data. An invoice without data gains one loom level and one traceback frame (verification round 0). That is small, but it is not "hydrated only". Say "also without data" in the row.
- L7: "These keys carry the reserved prefix". The prefix is not documented as reserved: `docs/docs` only shows `invoice-pro-validation`. Also, the near-miss rule is a prefix rule, so it reserves all of `invoice-pro-data*`. Reproduced on both compilers: a skeleton that reads its own `--input invoice-pro-data-dir=batch` now panics with "is not a key invoice-pro reads, so the invoice would show its samples". §5.1 says that other `invoice-pro-*` keys "stay free for skeletons". State the reserved prefix in L7, in §5.1 and in the docs.
- Under "Not an API change, but felt by every invoice", add the +25 % download size next to the +1.2–1.5 ms import cost.

**M3. The shipped template is not a hydratable skeleton for payment data.** `template/invoice.typ`, which `typst init` installs, uses `payment-terms(..)` and `bank-details(..)`. Hydrated with §3.11 under `strict`, it stops with the coverage issue "the data has a `payment` section, but the skeleton has no `payment(..)` block". I measured on the prototype tree whether switching the template to `payment(terms: (days: 14), bank: (..))` changes its output. It does not: the PDF md5 stays the same on 0.15.1 (`881821b7318c`, with `a-3b` `ba5d9a49b5de`) and on 0.14.2 (`8a1c8b464422`, `c7e98da669bc`), equal to 0.6.0.

So the template could become a ready skeleton without any visible change. The concept lists the template under "Not changed" and never asks this question. Decision 9 ("Every existing invoice hydrates without marks") and §2.5 ("any 0.7.0 invoice, no change → hydrates") are true for items only. Add a question with a recommendation; mine would be to switch the template in S6. Also correct the two claims.

**M4. Not every open question is decidable as written.** A decidable question names the alternative, its consequence, and what changes in the concept if I pick it: which sections, ledger rows, stages and days. Mostly the third part is missing. Per question:

| Question                | Problem                                                                                                                                                                                                                                                                                |
| :---------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Q19, Q25, Q27, Q28      | "Settled by the prototype": these are confirmations, not questions. Move them to a "please confirm" list, as theming A.1/A.2 did. Q28 is an action item of S6.                                                                                                                         |
| Q30, Q32, Q33           | a recommendation only, no alternative                                                                                                                                                                                                                                                  |
| Q17, Q18, Q26, Q29, Q31 | an alternative without its consequence. Q26: English first drops L16 and its ⚠ from 0.7.0. Q29: provisional throughout means a changelog entry for every change in 0.7.x. Q17: the size of the 0.7.0 surface and the days.                                                            |
| Q5, Q13                 | the recommendation is new work that no stage of §12 contains. Q5 (check digits, code lists and BR-Z-05 in the decoder) is not small, and it brings e-invoice rules into a third place. Say how it reuses `id.*` and `src/zugferd/` without copying rules, and assign a stage and days. |
| Q2, Q3                  | the plan has no gate that would enforce the restated budget: S5 gates the 300-row ratio only, with no root-import metric. Valgrind is not in the flake (`perf-gate` packages only Typst and Python), so an instruction gate needs flake work and CI minutes, which are not estimated.  |
| Q10                     | it decides O2, which is rated "high". Put it in the summary's list next to Q1–Q7.                                                                                                                                                                                                      |
| all                     | the process files use the synthesis' numbers, for example dev. 9 "per Q3" and dev. 12 "Q6 follow-up", which are concept Q7 and Q18. Add a mapping, or a sentence saying that `process/` uses the synthesis' numbers.                                                                   |
| missing                 | the template (M3); shipping the schemas in the package vs only on the docs site (M1); committing the harness (B1); the validation default for pipelines (m5); the names `bank.bank` and `custom` (m3)                                                                                  |

**M5. The plan leaves out work that the repository's own rules require.**

- **E-invoice validation.** The repository already runs Mustang and KoSIT in CI (`zugferd-validation.yaml`, `validate-all-zugferd`, `zugferd-corpus`, `zugferd-golden`). S4's "one Mustang and KoSIT run (O12)" undersells this. New hydrated e-invoice test documents belong in the "Validated Test Suites" list of `tests/TESTING.md` and in the golden XML. Consider a hydrated population in `zugferd-corpus` too, which would make P1 a permanent CI property.
- **Flake and CI.** The CI step that patch 0003 adds runs `python3` inside `nix develop`, but `devShells.default` lists no Python. It only works if a `python3` comes from elsewhere on the PATH, such as the runner's system Python, while every other tool is a flake app with `toolsPython` (`perf-gate`, `check-docs-examples`). The plan does not count any of this work:
  - packaging `signature.py`, the conformance comparator, the fault corpus and the CLI matrix as flake apps;
  - adding valgrind;
  - pinning python-jsonschema, ajv, datamodel-codegen, json-schema-to-typescript and cargo-typify in Nix (the last needs a Rust toolchain).

  Codegen could reasonably be nightly only.

- **Tests that tytanic cannot run.** tytanic cannot pass `--input`. Root reads `invoice-pro-result` from `sys.inputs` directly (dev. 12), which breaks the house rule of an injectable `inputs:` (conventions §1.5). `invoice()`'s key scan is not injectable either. So the S2 tests "the R7 panics" and the S5 tests "no record without data, PDF bytes unchanged by the input" and "the CLI matrix" need a script and a CI job, like `run.sh`. Say where they live. Better still, make the result request injectable, or say why not.
- **Package bundle.** `check-package-bundle` (`package.yaml`, `release.yaml`) should compile one hydrated invoice offline from the published files. That proves the contract modules, the `../../typst.toml` read of the result (dev. 12) and the lazy imports work in the bundle.
- **Registries and docs that §12 does not list:**
  - `tests/TESTING.md`: the directory structure (a new `tests/data/` category, which sits next to the `tests/data-test.typ` utility and is easy to confuse with it), the validated suites, and the CI table;
  - `docs/docs/api-reference/locale/{base,custom,index}.md` (B2);
  - `theme/parts.md` (`ctx.custom`, `view.items[i].custom`);
  - `invoice/index.md` (the parameter table);
  - the `info` page (`info.get("custom", ..)`);
  - the hydrated variants on the `payment-terms` and `bank-details` pages.
- **A second BT registry.** The descriptor's `x-en16931` annotations (112) are a second map from business terms to inputs, next to `tools/zugferd/bt-disposition.toml`. Add a consistency check between the two, or list them as a risk.
- **Estimates as ranges.** The theming concept gave ranges, and this plan gives points. S1 went from 6 d in the synthesis to 5 d here, although it gained five fixes (O1, O3, O4, O7, O8) and still has the synthesis' five gates (conformance, fault corpus, drift, codegen, decoder budget). S6 has 3 d for two reference pages, a guide, a data-format reference generated from the descriptor (a new generator with a drift check), doc tests, registries and the schema hosting, against 4–5 d for theming's docs stage. Give ranges, and state the 0.7.0 total with the recommended S7a, S7b and S8 included.

**M6. The signature test covers `invoice()` only, but the format mirrors twelve components.** The rows engine and `payment(..)` replay `item`, `group`, `bundle`, `discount`, `surcharge`, `modifier`, `prepayment`, `payment-terms`, `bank-details`, `direct-debit`, `card-payment` and `paid` (§3.6 has a "Feeds `item(..)`" column). A new parameter of one of them has no data key, and nothing fails. A changed cascade breaks equivalence, and only the equivalence suite would catch it, which is not in the repository (B1). This is risk 1 of §13, and §12's MAINTENANCE items have no rule for it.

_Fix:_

- extend `signature.py` (or a second table) to these components: each parameter is a data key or explicitly Typst-only;
- add a MAINTENANCE item: "a change to a line-item or payment component is mirrored in `src/contract/rows.typ` or `src/components/payment.typ`, and the equivalence suite passes".

**M7. The cost for invoices without data is only half reported.** §7.3 and Q2 give the parse delta: +3.84 M / +3.88 M instructions, ≈ 1.2–1.5 ms. They do not give the absolute import time (≈ 150 ms in dev. 49), which is what makes 1.2 ms readable. They also leave out the runtime of the new hooks that run on every invoice: the key scan, the slot motif, and root's `payment` signal collection. The verifiers did time hand-written invoices on the prototype against 0.6.0, at 0.962–1.043× in round 0 and 0.84–1.17× in round 1, both noise. Put those numbers into §7.3, and add an instruction count of the hand-written 5- and 300-row invoices on both trees, which `tools/perf/measure.py --instructions` already does.

The live preview (`measure.py --watch`) is the metric the maintainer accepted for small invoices (tools/perf README). It was not measured for a skeleton with the `load` line and the marker; note that `invoice-data.items` imports `src/contract/rows.typ` in every preview. Nor was it measured for `typst watch` with a data file. Either measure it or list it as not measured.

### Minor

- **m1.** §11.2 calls P8 "pass (one fail)". Verification round 2 has 6 passes and 1 fail, so write "partial". P10 has `P10.mutations-r3` as a fail; "partial" is generous, so say "partial (one fail)".
- **m2.** §6.4 and the MAINTENANCE items say "the drift check fails until …", as if it ran in CI. The patches add no drift step to `tests.yaml`. Mark it _proposed_ (S1).
- **m3.** Names to decide now, while they are cheap:
  - `payment(bank: (bank: "Musterbank", ..))` and the data's `payment.bank.bank` read badly, and the parameter's own doc calls it "the account to pay to". Consider `account`.
  - `custom` is a third meaning next to `theme.custom` and `locale.custom` (customisation namespaces); the §2.1 skeleton uses `theme.custom.logo` and `info.get("custom", ..)` a few lines apart.
  - The issue ids `schema/<pointer>` belong to class `data`, while theme issues use the prefix of their class (`theme/…`).
  - Decision 14 says `invoice-data` is "named after the parameter". It is an exception to that rule, named after `invoice(data:)`, so say so.
- **m4.** Readability:
  - Show the zero-change path first, an ordinary invoice plus `--input invoice-pro-data=…`, in five lines. Then show the 87-line skeleton with the coat-of-arms rule.
  - Move the format reference (§3.2–§3.7, about 160 lines) to an appendix, because S6 will generate it into the docs anyway.
  - Several table cells exceed 500 characters (L7, the `tax` row of §3.2).
  - The `sample` / `shown` / `..sample` ceremony of the skeleton could shrink with `values(record, default: sample)`, if you want one more name.
- **m5.** Under the default `validation: "draft"`, a hydrated invoice with problems exits 0 and writes a PDF. A pipeline that forgets `strict` ships drafts. The watermark is there and the XML is withheld, but the exit code is 0. Ask whether a data input should imply `strict`, or at least make `strict` the documented pipeline default in the guide.
- **m6.** The shared-path bug fixes are mixed into feature patches: L29 into 0006 and L30 into 0008. S8 ("may land first, separate PRs") must split them out. Say so in §11.1 or §12.
- **m7.** `tests/data/contract/` has no `.gitignore`, which TESTING.md requires. S1 ports the test to tytanic anyway; list it.
- **m8.** The header of `prototype/examples/skeleton.typ` names "SYNTHESIS.md §4.7" and `--root <unified>`. In the repository these are `process/designs/synthesis.md` and the `<work>` layout of `run.sh`.
- **m9.** The status line of `process/designs/synthesis.md` reads "`<session>` = `<session>`", a leftover of the path replacement.
- **m10.** The doc comment of `invoice(data:)` lists `auto | none | dictionary | bytes | str | content` but accepts a 0.15 `path` too.
- **m11.** 35 questions are a lot for one sitting. After the split of M4 (four confirmations, one process question), about 30 decisions remain. Group them by stage, so that I can answer S1's questions before S1 starts.

## Ledger audit (patch files → rows)

| Files of the diff                                                              | Row(s)     | Comment                                                                  |
| :----------------------------------------------------------------------------- | :--------- | :----------------------------------------------------------------------- |
| `src/invoice.typ`                                                              | L1, L2, L3 | ok                                                                       |
| `src/lib.typ`, `src/public/*.typ`, `src/contract/api.typ`                      | L4, L5     | ok; add the `party`/`values` shapes (M2)                                 |
| `src/components/payment.typ`                                                   | L5         | ok                                                                       |
| `src/contract/input.typ`                                                       | L7         | the prefix rule (M2)                                                     |
| `src/contract/result.typ`, `result-schema.typ`, `result.schema.json`           | L8         | ok; the non-injectable input (M5)                                        |
| `src/components/line-items.typ`                                                | L9, L28    | the effect without data (M2)                                             |
| `src/contract/rows.typ`                                                        | L10, L14   | ok                                                                       |
| `src/components/root.typ`                                                      | L8, L11    | ok                                                                       |
| `src/theming/access.typ`, `src/components/dynamic.typ`                         | L12        | ok                                                                       |
| `src/zugferd/model.typ`                                                        | L13        | ok; `_address-keys` also covers the tax representative                   |
| `src/locale/region/{base,de,at,ch,fr,it,es}.typ`                               | L15        | wrong kind, inherited list (B2)                                          |
| `src/contract/{schema,types,decode,export,hydrate}.typ`, `invoice.schema.json` | L17        | ok; the size (M1)                                                        |
| `tools/perf/gate.py`                                                           | L18        | ok                                                                       |
| `tools/contract/signature.py`, `tests/data/**`, `.github/workflows/tests.yaml` | L19        | Python not in the dev shell; the fixtures' generator is missing (B1, M5) |
| `tests/theme/exports/test.typ`                                                 | L6         | ok                                                                       |
| `src/components/payment-terms.typ`                                             | L27        | ok                                                                       |
| `src/logic/modifier-applicator.typ`                                            | L28        | ok                                                                       |
| `src/theming/parts/frame.typ`                                                  | L29, L30   | ok; split out of 0006 and 0008 (m6)                                      |
| (documentation only)                                                           | –          | `<ip-issue>` as a CLI contract (M2)                                      |

## What I checked, reproducibly

```sh
# lint (CI versions)
prettier --check docs/concepts/data-api/README.md docs/concepts/data-api/prototype/README.md
# extract the typst blocks, typstyle --check each, compile each with a `party`
# dictionary and `#import "/repo/src/lib.typ": *` against <session>/runcheck
typst compile --root <session>/runcheck <block>.typ out.pdf   # 0.15.1 and 0.14.2
# the core proofs from a clean clone
TYPST_BIN=typst docs/concepts/data-api/prototype/run.sh <work>          # 12/12
TYPST_BIN=typst-0.14.2 docs/concepts/data-api/prototype/run.sh <work14>  # 12/12
# B2: the block above, and the same invoice written by hand (compiles)
# M2: a skeleton reading sys.inputs.at("invoice-pro-data-dir")
typst compile --root <session>/runcheck nm.typ o.pdf --input invoice-pro-data-dir=batch
# M3: template/invoice.typ with payment(terms: .., bank: ..), md5 with and without
#     --pdf-standard a-3b on both compilers; the unchanged template hydrated with
#     prototype/data/2026-0042.json under strict
```
