# E-invoice conformance tools

These tools prove in CI that invoice-pro's e-invoices (ZUGFeRD / Factur-X / XRechnung) are valid and say what the invoice says. They are development tools: they are not part of the published package, and a user of the package never needs them.

How to run them, how to read their results and how to update golden files and known issues is described in [`tests/TESTING.md`](../../tests/TESTING.md#3-e-invoice-conformance-and-performance-ci).

| File                     | Purpose                                                                                                                                                   |
| :----------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `corpus/gen.py`          | Generates the corpus: legal invoices (all pairs of 11 dimensions and a random sample), mutations, metamorphic twins, adversarial inputs, random invoices. |
| `corpus/regression/`     | Committed regression cases, each with an `// expect:` header.                                                                                             |
| `harness.typ`            | Theme wrapper that attaches invoice-pro's diagnostics to the PDF as JSON, so that one compilation yields the XML and the verdict.                         |
| `run.py`                 | The runner: Typst, XSD, Mustang in one JVM, classification, oracles, known issues, gates.                                                                 |
| `oracles.py`             | Semantic checks of the XML against the input and against the printed PDF.                                                                                 |
| `known-issues.toml`      | Failure signatures of known bugs with their finding; the list can only shrink.                                                                            |
| `bt-disposition.toml`    | The disposition of every business term of EN 16931: the input that states it, what it is derived from, or why it is not supported.                        |
| `bt_disposition.py`      | Checks that every business term has a disposition; `scripts/zugferd-corpus` runs it before the corpus.                                                    |
| `minimize.py`            | Shrinks a failing generated case to a minimal reproduction.                                                                                               |
| `golden.py`              | Golden XML of the e-invoice test documents (`tests/zugferd/golden/`) and the reproducibility check.                                                       |
| `java/MustangBatch.java` | Validates many files with Mustang in a single JVM; compiled against the Mustang jar on first use.                                                         |
| `common.py`              | Shared helpers: Typst, PDF attachments and text, XSD, Mustang.                                                                                            |
| `test_*.py`              | Unit tests of the tools themselves (`python3 -m unittest discover -s tools/zugferd`); `scripts/zugferd-corpus` runs them first.                           |

Requirements: Python 3.11 or newer with `lxml` and `pypdf`, Typst, a JDK and the Mustang CLI jar 2.14.0. `nix run .#zugferd-corpus` and `nix run .#zugferd-golden` provide everything.
