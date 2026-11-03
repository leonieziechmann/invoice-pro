# The data API prototype

This folder holds the consolidated prototype of the [data API concept](../README.md): the unified design of the exploration, built on invoice-pro 0.6.0 and checked by four independent verifiers in three rounds. It is a series of patches, not code in `src/`. Nothing here is loaded by the package.

| Path                            | What                                                                                                                                                                                                                |
| :------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`patches/`](patches/)          | ten `git format-patch` files on top of `df934a7` (main at 0.6.0)                                                                                                                                                    |
| [`examples/`](examples/)        | `skeleton.typ` (the skeleton of the concept, §2.1), `handwritten.typ` (the same invoice written by hand with 0.6.0), `skeleton-path.typ` (Typst 0.15 `path`), `wappen/*.svg` (five small placeholder coats of arms) |
| [`data/`](data/)                | `2026-0042.json` (the complete example, concept §3.11), the same as `2026-0042.toml`, the broken and the coat-of-arms cases (below)                                                                                 |
| [`run.sh`](run.sh)              | reproduces the core proofs from the patches                                                                                                                                                                         |
| [`harness/`](harness/README.md) | the sources of the builder's test harness behind the ten proofs (generators, the fault corpus, comparators, benchmark scripts), without outputs                                                                     |

## The patches

| Patch | Commit    | Content                                                                                                                                                                                                 |
| :---- | :-------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0001  | `3adb8e3` | contract core, `invoice(data:, custom:)` with re-entry, the rows engine behind the items slot and the `invoice-data.items` marker, `payment(..)`, region VAT rates, sealed `ctx.custom`, party `custom` |
| 0002  | `20bf27b` | crash-free decoder rules, item modifiers without `tax`, the committed JSON Schemas, the conformance fixtures                                                                                            |
| 0003  | `46b04c9` | contract unit test, signature-coverage test, `LAZY_MODULES`                                                                                                                                             |
| 0004  | `f414846` | decoder hot path                                                                                                                                                                                        |
| 0005  | `2963ca6` | coverage issues in the lazy contract module                                                                                                                                                             |
| 0006  | `6c6a1b1` | fixes after verification round 0                                                                                                                                                                        |
| 0007  | `f2700f2` | the payment implementation in `LAZY_MODULES`                                                                                                                                                            |
| 0008  | `cda7b07` | fixes after verification round 1                                                                                                                                                                        |
| 0009  | `97b0001` | a cash discount period of at most 36 500 days                                                                                                                                                           |
| 0010  | `29486ec` | the schemas' `$id` on the documentation site (no other change; after the last verification round)                                                                                                       |

The commit ids are those of the prototype's branch `proto` in the exploration's scratch directory; the patches carry the same changes. Together they touch 39 files, +33 177 / −11 lines. The subjects of 0006 and 0008 say "verifier round 1" and "verifier round 2", because the patches count the verification rounds from 1, while the verification report counts them from 0. Patch 0006 also holds the shared-path bug fix L29 and patch 0008 the bug fix L30; stage S8 of the plan splits them out.

### Files by area

| Area                      | Files (lines added / removed)                                                                                                                                                                                                                                                                                            |
| :------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| contract (new, lazy)      | `src/contract/schema.typ` (935, the descriptor), `types.typ` (305), `decode.typ` (1427), `export.typ` (330), `input.typ` (214), `hydrate.typ` (257), `rows.typ` (440, the bulk motif and the marker), `result.typ` (198), `result-schema.typ` (113), `api.typ` (73, the bodies of the facade)                            |
| committed schemas         | `src/contract/invoice.schema.json` (3572), `src/contract/result.schema.json` (541)                                                                                                                                                                                                                                       |
| public facades (new)      | `src/public/invoice-data.typ` (137), `src/public/payment.typ` (62); `src/lib.typ` (+2)                                                                                                                                                                                                                                   |
| payment block (new, lazy) | `src/components/payment.typ` (252)                                                                                                                                                                                                                                                                                       |
| integration points        | `src/invoice.typ` (+95), `src/components/line-items.typ` (+36 / −2, the items slot), `src/components/root.typ` (+26), `src/components/payment-terms.typ` (+13 / −3), `src/logic/modifier-applicator.typ` (+13), `src/components/dynamic.typ` (+4), `src/theming/access.typ` (+4 / −1), `src/zugferd/model.typ` (+3 / −1) |
| regions                   | `src/locale/region/base.typ` (+6), `de`, `at`, `ch`, `fr`, `it`, `es` (+3 each): the VAT rates                                                                                                                                                                                                                           |
| bug fixes (shared path)   | `src/theming/parts/frame.typ` (+7 / −2): the ellipsis of a header line, `sender.management` as lines                                                                                                                                                                                                                     |
| tests                     | `tests/data/contract/test.typ` (360), `tests/data/conformance/fixtures.json` (23 550, 135 cases), `tests/data/conformance/check-all.typ` (10), `tests/theme/exports/test.typ` (+17 / −2)                                                                                                                                 |
| tools and CI              | `tools/contract/signature.py` (135), `tools/perf/gate.py` (+15), `.github/workflows/tests.yaml` (+7)                                                                                                                                                                                                                     |

The test files are plain Typst files whose assertions panic on failure (tytanic was not available to the prototype); compile them with `--root` at the patched tree.

### Examples and data

- `examples/skeleton.typ` (the skeleton of the concept, §2.1) imports `/repo/src/lib.typ`, `examples/handwritten.typ` imports `/` + `--input lib` (default `repo`, or `pristine`) + `/src/lib.typ`, so both compile with `--root <work>` against a tree layout `<work>/repo` (0.6.0 + patches), `<work>/pristine` (0.6.0) and `<work>/proto/{examples,data}`, the layout `run.sh` builds.
- `data/2026-0042.json` and `.toml`: the complete example; hydrated, the skeleton equals `handwritten.typ` on 0.6.0 byte for byte.
- `data/broken-no-{invoice-nr,date,recipient,items}.json`: one required value missing each (a draft without an e-invoice; `strict` stops).
- `data/bad.json`: six data problems in one file (an alias key `plz`, a price `"38,90"`, a VAT rate 16 %, a unit name `"kWh"`, a missing mandate, a currency `"EURO"`).
- `data/w-{80331,20095,10115,50667}.json`, `w-city-string.json`, `w-override.json`, `w-unknown-name.json`: the coat-of-arms cases (post code rule, a city string, the `custom.wappen` override, an unknown override that falls back to the rule).

## Apply the patches

The patches apply to `df934a7`, which does not contain this folder. Apply them in a separate worktree:

```sh
git worktree add ../invoice-pro-proto df934a7
cd ../invoice-pro-proto
git am "$OLDPWD"/docs/concepts/data-api/prototype/patches/*.patch
```

## Run the proofs

```sh
# from the root of this repository; Typst 0.14 or 0.15, git, bash 4 or later, GNU md5sum,
# python3; pdfdetach (poppler) optional
TYPST_BIN=typst docs/concepts/data-api/prototype/run.sh ../data-api-proof
```

`run.sh` clones this repository twice into the work directory, checks out `df934a7` in both, applies the patches with `git am` to one of them, copies `examples/` and `data/` next to them and links `<work>/dev/stdin` to `/dev/stdin`. It then checks:

| #    | Check                                                                                                                                                       |
| :--- | :---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | the skeleton compiles alone, with its samples (the Berlin arms, an embedded `factur-x.xml`)                                                                 |
| 2–5  | hydrated from a file, from inline JSON, from stdin and from TOML, it is md5-identical to `handwritten.typ` compiled with 0.6.0 (PDF/A-3b, the XML included) |
| 6    | data without an invoice number gives a draft with no embedded file                                                                                          |
| 7    | the same under `--input invoice-pro-validation=strict` stops the build with the missing-number message                                                      |
| 8–12 | the post codes 80331, 20095, 10115 and 50667 pick Bavaria, Hamburg, Berlin and the neutral arms; `custom.wappen` overrides with München                     |

Expected output: `failures: 0`, with the md5 `32b0b6d5d449` on Typst 0.15.1 and `679ee994c66b` on 0.14.2 (12 of 12 PASS on both, re-run on 2026-11-03). `run.sh` uses `declare -A` and `md5sum`, so macOS needs a newer bash and GNU coreutils.

`run.sh` reproduces the core of proofs P1, P3 and P7 only. The ten proofs are: P1 equivalence over generated matrices, P2 no regression over 1105 documents, P3 no sample leaks and the misuse panics, P4 crash-freedom over fault corpora, P5 schema agreement and code generation, P6 the payment matrix, P7 the sources and the coat of arms, P8 the result contract, P9 performance and P10 signature coverage. The sources of their harness are in [`harness/`](harness/README.md), which also says how to run them in the work directory of `run.sh`; every number is in [`../process/review/verification.md`](../process/review/verification.md); the builder's self-check is [`../process/prototype/build.md`](../process/prototype/build.md), and the 49 decisions where the prototype differs from the synthesis are [`../process/prototype/deviations.md`](../process/prototype/deviations.md). What is still open is listed in the concept, §11.5.
