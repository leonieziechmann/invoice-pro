# The prototype's harness

The builder's test harness of the [data API prototype](../README.md): the generators, comparators, corpora and scripts behind the proofs P1–P10 ([concept §11.2](../../README.md#112-the-ten-proofs)). Only the sources are here. Outputs, logs and the generated invoices (`eq/data/`, `eq/hand/`) are left out, and so are the verifiers' own scripts and corpora (below).

This folder is a record, not a test suite of the package. No CI job runs it. Stages S1, S3 and S5 of the [implementation plan](../../README.md#12-implementation-plan) port the parts that become CI gates into `tools/` and `tests/`. Until then, this is the only copy that survives the exploration's scratch directory.

## Layout and use

The scripts address the Typst root `<work>` of [`run.sh`](../run.sh): `<work>/repo` (0.6.0 + the patches), `<work>/pristine` (0.6.0) and `<work>/proto/{examples,data}`. Copy this folder into `<work>/proto/` after `run.sh` has built the work directory:

```sh
docs/concepts/data-api/prototype/run.sh ../data-api-proof
cp -r docs/concepts/data-api/prototype/harness/* ../data-api-proof/proto/
cd ../data-api-proof/proto
python3 -I gen/gen.py 5,50,300 b,r,t           # writes eq/data/*.json and eq/hand/*.typ
eq/eq.sh typst "b r t" "5 50 300" "none auto"  # P1: pristine == hand-written == hydrated
```

The files of `examples/` here join those of `prototype/examples/` (the extra skeletons that P6, P7 and P8 compile).

## What is here

| Path                             | Proof  | What it does                                                                                                                                                                    |
| :------------------------------- | :----- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `gen/gen.py`                     | P1, P9 | design C's generator: for kind b, r, t and n rows, the invoice as `invoice-pro/1` data and the same invoice written by hand                                                     |
| `eq/eq.sh`, `eq/skeleton*.typ`   | P1     | md5 (PDF and embedded XML) of the hand-written invoice on 0.6.0 and on the prototype, and of the hydrated skeleton                                                              |
| `edge/`                          | P1     | the edge fixtures (nested and dated bundles, `apply` around the marker, static rows, nulls)                                                                                     |
| `regress/integration.sh`         | P2     | every `tests/integration/**/test.typ` on both trees, byte comparison                                                                                                            |
| `regress/pages.sh`               | P2     | design C's regression: every `tests/**/test.typ`, rendered pages and error texts compared                                                                                       |
| `misuse/`                        | P3     | sample leaks, the R7 panics with their fixes, skeleton misuse                                                                                                                   |
| `fuzz/fuzz.py`, `fuzz/corpus/`   | P4     | the fault corpus: the engine judge's 38 single-fault documents, adapted, plus 31 later faults (69); a hard abort is any failed compile except the deliberate format-major panic |
| `schema/make_fixtures.py`        | P5     | generates `tests/data/conformance/fixtures.json` from `data/2026-0042.json` and the committed schema                                                                            |
| `schema/compare.py`              | P5     | python-jsonschema against `invoice-data.check` on the 135 fixtures, by their expectation labels (valid, invalid, lenient, decoder-only)                                         |
| `schema/agree.py`, `check-d.typ` | P5     | the same, label-free, on design D's 51 fixtures (`d-fixtures.json`)                                                                                                             |
| `schema/codegen.sh`              | P5     | pydantic (datamodel-codegen), TypeScript (json-schema-to-typescript) and Rust (cargo-typify) types from both schemas; needs `CODEGEN_TOOLS`                                     |
| `payment/`                       | P6     | the payment matrix with and without data                                                                                                                                        |
| `wappen/`                        | P7     | the sources (inline, file, stdin, TOML, 0.15 `path`) and the coat-of-arms cases                                                                                                 |
| `result/p8.sh`                   | P8     | the result record against its schema; `typst query` (0.14) against `typst eval` (0.15)                                                                                          |
| `bench/`                         | P9     | the ratio gate (`p9.py`), the S7a side branch (`p9-s7a.py`, needs a worktree `repo-s7a`), the import cost (`imptrace.py`)                                                       |
| `signature/p10.sh`               | P10    | `tools/contract/signature.py` on the prototype and on mutated copies                                                                                                            |
| `selfcheck.sh`                   | all    | the builder's self-check of P1–P10 on both compilers; reads `TYPST_BIN`, `TYPST14_BIN`, `TYPSTYLE_BIN`                                                                          |

Changes against the exploration's copy: `schema/codegen.sh` reads the directory of the code generators from `CODEGEN_TOOLS`, `selfcheck.sh` takes the compilers from the environment and the layout from its own location, and the header comment of `examples/skeleton-no-bank.typ` names the concept instead of the synthesis. Nothing else changed.

## Re-run from this folder

Checked on 2026-11-03 in the layout above, against the prototype tree, Typst 0.15.1 unless stated:

| Command                                                                  | Result                                                                                                                                                                                    |
| :----------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `gen/gen.py 5,50 b,r,t` and `gen/gen.py 300 b`                           | the same files as the exploration's run (`b-5`, `b-300` compared byte for byte)                                                                                                           |
| `eq/eq.sh typst "b r t" "5 50" "none auto"`                              | 12 of 12 identical (pristine == hand-written == hydrated)                                                                                                                                 |
| `schema/make_fixtures.py data/2026-0042.json <schema> out.json`          | the committed `fixtures.json` byte for byte when `schema/out/model.py` from `codegen.sh` exists; without it 134 cases, all equal to the committed ones, and no `pydantic-model-dump` case |
| `check-all.typ` through `typst eval` (0.15.1) and `typst query` (0.14.2) | byte-identical reports                                                                                                                                                                    |
| `schema/compare.py` on the 135 fixtures; `schema/agree.py` on D's 51     | 135 of 135 and 51 of 51 agree (python-jsonschema 4.26.0)                                                                                                                                  |
| `fuzz/fuzz.py typst none`                                                | 69 faults, 0 hard aborts                                                                                                                                                                  |
| `misuse/p3.sh typst`                                                     | 31 checks, 0 failures                                                                                                                                                                     |

The other scripts were not re-run from this folder; their results are in [`../../process/review/verification.md`](../../process/review/verification.md) and [`../../process/prototype/build.md`](../../process/prototype/build.md).

## What is not here

- Outputs and logs (`out/`), the generated invoices (`eq/data/`, `eq/hand/`: run `gen/gen.py`) and the generated types (`schema/out/`: run `codegen.sh`).
- The verifiers' scripts and corpora: the robustness corpora r1, v3 and v4, the 3154 schema-walk mutations, the 2201-document compile sweep, the 171 targeted probes and the P10 mutations. They stay in `<session>/exp/unified/verify-*/` with several hundred MB of outputs. [`verification.md`](../../process/review/verification.md) records their commands, case lists and results; S1 rebuilds the corpus that becomes a CI gate from the fault corpus here and those case lists.
- Requirements: bash 4 or later, GNU coreutils (`md5sum`), Python 3 with `jsonschema` (P5), `pdfdetach` (poppler; P1, P3, P6), `valgrind` (instruction counts) and, for `codegen.sh`, the three code generators.
