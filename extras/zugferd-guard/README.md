# ZUGFeRD guard (parked)

The runtime self-check of the e-invoice XML that invoice-pro ran on every compilation up to commit `9b4b850` (branch `feature-zugferd-validation`). It is parked here to become an optional companion package for invoices where nothing may go wrong. Nothing in this directory is wired up: the package does not load it, no test runs it, and it is not published.

## What it did

After the rules had checked the input (`src/zugferd/rules/`), every e-invoice went through these checks while its XML was written and read back:

- **G1, structure:** every element known to the profile's XSD at its position, in schema order and number, with the children and attributes it requires, and not marked as not used by the Factur-X Schematron.
- **G2, values:** the lexical form of decimals, indicators and dates, the decimals of `BR-DEC-*`, every code in the code lists of its position, and what the VAT category requires of each tax element.
- **G4, well-formed:** Typst's XML parser reads the attached bytes as one `CrossIndustryInvoice`.
- **G3, round trip:** the XML read back states exactly what the data model states (the header always, every line in the strict mode).
- **Strict mode** (`zugferd-strict: true`, or `--input zugferd-strict=true`): G3 for every line and the arithmetic of the written amounts (`BR-CO-10` to `BR-CO-17`, `BR-*-08`).
- **Invariants:** the model states what the invoice prints (`IP-PRINT-01`, `IP-CALC-01`, `IP-CALC-02`), and its sums hold (`BR-CO-17`, `BR-*-08`).

A finding became an error, with the official rule where there was one and else one of `IP-GUARD-00` to `IP-GUARD-13` (`registry.json`, `docs.md`), merged with the diagnostics of the rules. The XML itself never depended on the checks.

## Why it left the package

It made a gap in the rules visible: a compilation stopped with "please report" instead of attaching invalid XML. It cost 184 kB of code and tables (a sixth of the package) and about 40 % of the time of the e-invoice path at 5 lines, and in the conformance corpus (877 cases) and the audit invoices (588) it never found anything the rules had missed. The tests now carry the guarantee; this companion package would bring the runtime check back for those who want it.

## Where the code is

- **The checks** are maintained as the test oracle in `tools/zugferd/guard/`: `write.typ` and `rare.typ` (G1, G2), `roundtrip.typ` with `bindings.json` (G3), `strict.typ` (arithmetic), `equivalence.typ` and `equivalence-detail.typ` (invariants), `oracle.typ` (G4 and all of them together), `report.typ` (messages), and the tables that `tools/zugferd/gen_guard.py` generates from the pinned XSD and Schematron artefacts. The tests run them on every `model-test` invoice, so they stay in step with the builder and the model. Build the package from there rather than from a copy.
- **What only the runtime needed** is kept here, as of `9b4b850`:
  - `runtime/zugferd.typ`: `process-zugferd` with the guard's stages (G1 and G2 while writing, G4, G3, the strict mode) and the invariants;
  - `runtime/xml.typ`: `dict-to-xml`, which wrote the XML through the guard's writer;
  - `runtime/report.typ`: the guard's diagnostics and their merge with those of the rules (a finding the rules report already is left out; next to errors of the rules, the other findings are one summary, `IP-GUARD-00`; without them each finding is an error with the hint to report it);
  - `registry.json`: the registry entries `IP-GUARD-00` to `IP-GUARD-13`;
  - `docs.md`: the sections of `docs/docs/e-invoicing.md` that described the guard and the strict mode.
- **The removed API** (`src/invoice.typ` and `src/components/root.typ` at `9b4b850`):

  ```typst
  // invoice(..)
  zugferd-strict: false, // -> bool
  types.require(zugferd-strict, "invoice::zugferd-strict", bool)
  // into the context, also turned on by `--input zugferd-strict=true`
  zugferd-strict: if (
    zugferd != none
      and (
        zugferd-strict
          or sys.inputs.at("zugferd-strict", default: none) == "true"
      )
  ) { true },
  // root.typ: process-zugferd(.., strict: ctx.at("zugferd-strict", default: false) == true)
  ```

## Turning it into a package

A companion package cannot reach into invoice-pro, so invoice-pro needs a hook for it, for example a parameter `zugferd-check: none | function` that `process-zugferd` calls for every e-invoice with the model, the element tree and the XML, adding the findings it returns to the diagnostics before `zugferd-errors` decides. The companion package (e.g. `invoice-pro-guard`) would ship the oracle code and its tables and export that function:

```typst
#import "@preview/invoice-pro:x.y.z": *
#import "@preview/invoice-pro-guard:x.y.z": guard
#show: invoice.with(zugferd: "xrechnung", zugferd-check: guard.with(strict: true))
```

Open points: the tables follow the builder, so the companion package is tied to one version of invoice-pro (release both together, and let the guard refuse another version); the report and merge policy of `runtime/report.typ` would become the diagnostics of the hook; and the guard's findings need their ids back in the documentation of the companion package.
