---
sidebar_position: 3
---

# Testing and Conformance

`invoice-pro` checks the invoice data while it compiles (see [Validation and Error Reporting](./validation.md)). The XML it writes is checked by the tests of `invoice-pro`, on every change: against the official schemas and Schematron rules of each profile, and with the official validators. This page describes these tests, so that you can judge whether they meet your requirements. [`tests/TESTING.md`](https://github.com/leonieziechmann/invoice-pro/blob/main/tests/TESTING.md) describes them for maintainers, with every detail.

## Two Layers

| Layer                         | Runs                             | Checks                                                                                                                              |
| :---------------------------- | :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- |
| The validation of the package | on every compilation             | the invoice data and what the page shows, against the business rules of the profile and the rules of `invoice-pro`                  |
| The tests of `invoice-pro`    | on every change of `invoice-pro` | the XML of the test invoices, against the official schemas and Schematron rules, and some 900 invoices with the official validators |

The validation decides whether an invoice is valid. When it reports no error, the package writes the XML without checking it once more. The tests show that this XML is valid and states the invoice: for the invoices of the test suite, and for a corpus that covers the inputs of real invoices. Checking the XML while compiling would need the tables of the official schemas and Schematron files in the package and time on every compilation; in the tests, the package stays small and the preview fast.

## The Official Validators

| Artefact or validator                                        | Version                                          | Profiles                           |
| :----------------------------------------------------------- | :----------------------------------------------- | :--------------------------------- |
| Factur-X XSD and Schematron                                  | 1.09.2 (ZUGFeRD 2.5.2)                           | MINIMUM, BASIC WL, BASIC, EN 16931 |
| CEN Schematron of EN 16931 (CII)                             | 1.3.16 (KoSIT; Mustang for XRechnung)            | EN 16931, XRechnung                |
| XRechnung Schematron                                         | 2.4.0 in Mustang, 2.6.0 in KoSIT                 | XRechnung                          |
| [Mustang](https://www.mustangproject.org/) command line tool | 2.26.0                                           | every profile                      |
| [KoSIT validator](https://github.com/itplr-kosit/validator)  | 1.6.3, with the configuration of XRechnung 3.0.2 | EN 16931, XRechnung                |

An XML is officially valid only if all of them accept it: the XSD of its profile, Mustang and, for EN 16931 and XRechnung, KoSIT, the reference validator of XRechnung. Mustang checks MINIMUM to EN 16931 with the Factur-X Schematron alone, which states the business rules of EN 16931 itself; the rules the validators only warn about (a warning or information in the Schematron) do not make an invoice invalid. The versions are pinned with their checksums, and a weekly job reports new releases, so that the tests follow the validators that recipients use.

## The Test Oracle

The e-invoice tests of the Typst test suite (some 180 invoices) run the test oracle on every invoice whose validation reports no error. It checks the XML against tables compiled from the official artefacts of its profile (the Factur-X 1.09.2 XSD and Schematron, the CEN Schematron of EN 16931 for `"en16931"` and `"xrechnung"` and, for `"xrechnung"`, the XRechnung 3.0.2 Schematron; the rules the validators only warn about are left to them):

- **Structure:** every element is known to the schema at its position and in schema order and number, with the children and attributes it requires.
- **Values:** decimals, indicators and dates have their lexical form, and amounts the decimals the `BR-DEC-*` rules allow; every code is in the code lists of its position; every tax element has what its VAT category requires.
- **Well-formedness:** Typst's XML parser reads the XML as one document with one root element.
- **Round trip:** the XML is read back and compared with the invoice data, value by value and line by line: no value differs, none that the profile can state is left out, and none is added.
- **Arithmetic:** the amounts add up as the official rules require (`BR-CO-10` to `BR-CO-17`, `BR-S-08` and the like).
- **Printed = written:** the invoice data states what the invoice computed and prints.

The tables are compiled from the pinned artefacts by a generator that stops at any construct it does not understand instead of guessing, and the tests fail when the committed tables are not the generated ones. Many e-invoice documents of the other tests, e.g. of the integration tests, the template and examples of this documentation, are validated directly with Mustang and KoSIT.

### Testing the Oracle

A check is only worth as much as the errors it catches, so the oracle is tested itself: about 750 mutants of the XML of the golden test documents (elements deleted, duplicated, moved, renamed or emptied, codes and values changed, the rate, VAT amount or category of tax elements changed) are validated with the XSD and Mustang. The oracle must reject every mutant the XSD rejects, reject a changed code exactly when the official validator reports a code list rule for it, report exactly the rules of the VAT categories that Mustang reports, and accept the mutants the validators accept, except by its documented stricter checks.

## The Conformance Corpus

Every change of `invoice-pro` runs the conformance corpus as well: some 900 invoices, compiled and validated with the XSD of the profile, Mustang and KoSIT.

| Invoices          | What they cover                                                                                                                                                                                                                             | Expected                                                             |
| :---------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------- |
| Legal             | every allowed pair of values of 14 dimensions of real invoices (profile, countries, tax scenario, tax mode, modifiers, amounts, identifiers, payment, delivery, lines, theme, document type, extras, currency), plus a seeded random sample | valid for every validator, and no error of `invoice-pro`             |
| Mutations         | a legal invoice with one required input removed, or a detail the law requires on the printed invoice left out                                                                                                                               | rejected, and `invoice-pro` names the rule                           |
| Metamorphic twins | pairs of invoices that must agree: a bundle quantity doubled, lines reversed or split, another profile or currency                                                                                                                          | the amounts change as expected, the totals stay equal                |
| Adversarial       | unusual but valid input: content instead of text, invisible characters, a post code as a number, countries as text, XML special characters, long names                                                                                      | no crash, no lost or altered data                                    |
| Regressions       | minimal reproductions of the findings of audits and of reported issues                                                                                                                                                                      | as stated in each case                                               |
| Parity fixtures   | for every official rule that `invoice-pro` reports, the smallest invoice that breaks it, in each profile of the rule                                                                                                                        | the validators report the rule, and `invoice-pro` names the same one |

A nightly run adds random invoices outside the legal constraints: there, `invoice-pro` and the validators must agree, or `invoice-pro` applies a rule of its own or stops with a message about the input.

- **Hard gate:** a single legal invoice that is not valid for every validator, or that `invoice-pro` rejects, fails the tests: no silently invalid XML, no false alarm, no crash. Every other case must meet its expectation as well; a list of known issues could excuse a case while its bug is being fixed, but never the hard gate, and the list can only shrink.
- **Rule ids:** an error of `invoice-pro` that names a rule the validators of the profile do not have fails the tests, and so does a parity fixture that the validators do not reject with its rule.
- **Content:** beyond validity, the XML must carry the facts the generator put into each invoice, e.g. the invoice number, document type and currency, the names, identifiers and addresses of the parties, the VAT categories, rates and exemption reasons, allowances and charges, the invoicing period, the due date, the payment details, the units and the items, and the totals and amounts the PDF prints.
- **Messages:** every error of `invoice-pro` names its rule, the input field, the problem and a hint.

### Validator Differences

Mustang and KoSIT do not always agree: they bundle different versions of the CEN Schematron with different code lists, Mustang adds the Factur-X Schematron, and some XRechnung rules are warnings in KoSIT but errors in Mustang. Every disagreement the corpus shows is documented, with the reason and what `invoice-pro` does, and an undocumented one fails the tests. An e-invoice that `invoice-pro` accepts without errors must pass both validators. The one exception, a maintainer decision, is a currency that the newest EN 16931 code list has withdrawn: `invoice-pro` allows it with a warning in BASIC and EN 16931, as the Factur-X validation accepts it (see [Code Lists](./validation.md#code-lists)).

## Coverage of the Official Rules

The tests of `invoice-pro` account for every rule of the official validators, profile by profile: the rule ids of the Factur-X, EN 16931 and XRechnung Schematron files that the Mustang CLI 2.26.0 and KoSIT's XRechnung configuration apply to each profile. Each rule is either reported by `invoice-pro`, checked by the test oracle on the XML of every test invoice (rules on the structure, values and codes of the elements `invoice-pro` writes), excluded by construction (e.g. a negative price is written as a negative quantity), unable to occur because `invoice-pro` never writes the element it tests (e.g. a gross price), or only a warning of every validator, which accepts the invoice (most rules of the CII syntax, e.g. that an element should not be present). For every rule counted in the column "Reported by invoice-pro", a test invoice in that profile proves that the official validators of the profile reject it with the rule and that `invoice-pro` names the same one; where one mistake breaks several rules at once, `invoice-pro` may name another of them (e.g. `BR-S-02` for the XRechnung rule `BR-DE-16`). The coverage is not complete yet: the rules in the column "Open" are not handled, or `invoice-pro` reports them under another id.

[//]: # "rule-coverage table: generated by tools/zugferd/rule_coverage.py --update-docs"

| Profile   | Rule ids | Reported by invoice-pro | Checked by the tests | Excluded by construction | Cannot occur | Only warnings | Open |
| :-------- | -------: | ----------------------: | -------------------: | -----------------------: | -----------: | ------------: | ---: |
| MINIMUM   |       55 |                       9 |                   46 |                        0 |            0 |             0 |    0 |
| BASIC WL  |      278 |                      67 |                  185 |                       15 |           11 |             0 |    0 |
| BASIC     |      385 |                      63 |                  269 |                       36 |           16 |             1 |    0 |
| EN 16931  |     1025 |                      80 |                  418 |                       40 |           21 |           466 |    0 |
| XRechnung |      882 |                     106 |                  212 |                       49 |           42 |           473 |    0 |

Open: none.

[//]: # "end of the rule-coverage table"

## Business Terms

EN 16931 defines 196 business terms and groups, from the invoice number (BT-1) to the item attributes (BG-32). `invoice-pro` states each of them from an input, derives it, or documents why it does not support it, and a check of the tests fails when a term has no such decision. So no value ends up in another business term unnoticed. [Business Terms](./invoice-data/business-terms.md) lists every term with the input that states it.

## Golden XML and Reproducibility

The XML of every e-invoice test document is compared with a reviewed copy, so that every change of the XML shows in the review and is explained in its commit. Each of these documents is compiled twice with a fixed creation timestamp and must give a bit-identical PDF.

## Further Checks

- **Documentation:** every complete example of this documentation compiles.
- **Package bundle:** the files a release publishes compile the template and e-invoices on their own, offline, without the tests and tools of the repository.
- **Factur-X PDF:** the PDFs lack only the Factur-X XMP metadata, which Typst cannot write yet (see [Factur-X XMP Metadata](./limitations.md#factur-x-xmp-metadata)). This check is an expected failure: it fails when anything else about the PDF changes, and when Typst starts writing the metadata.
- **Performance:** the share of the e-invoice in the compile time stays within its budget (see [How It Works](./architecture.md#only-what-the-invoice-needs)).

## When the Tests Run

| When                                                                     | Tests                                                                                                                                                                                 |
| :----------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Every pull request and push to `main` that changes the code or the tests | Typst tests with the test oracle, conformance corpus, rule coverage, business terms, mutation test, golden XML and reproducibility, documentation examples, performance, Factur-X PDF |
| Every pull request that changes the published files                      | package bundle                                                                                                                                                                        |
| Nightly                                                                  | the corpus with random invoices, more mutants, also validated with KoSIT, and an invoice with 1000 lines                                                                              |
| Weekly                                                                   | new releases of Mustang, KoSIT, the XRechnung configuration and Typst                                                                                                                 |
| Every release                                                            | package bundle and Factur-X PDF                                                                                                                                                       |

## What the Tests Do Not Show

- **No certification.** The tests use the official validators, but `invoice-pro` is not certified by any authority or association. Check your e-invoices with the validator of your recipients before you use them in production.
- **Your data.** The rules check that the data is complete and consistent, not that it is right: the VAT rate, an exemption and the identifiers of your customers are your responsibility.
- **Rules beyond the profile.** Recipients and networks may apply rules of their own on top of the profile, e.g. those of Peppol or of a public portal. The XRechnung profile includes the Peppol rules of the XRechnung Schematron.
- **The PDF itself.** Validators that check the PDF reject it for the missing Factur-X XMP metadata (see [Scope and Limitations](./limitations.md)).

## Reporting a Problem

If a validator rejects an e-invoice that `invoice-pro` attached without errors, that is a bug of `invoice-pro`: please report it by [opening an issue](https://github.com/leonieziechmann/invoice-pro/issues), with the invoice and the report of the validator. (With `zugferd-errors: "ignore"`, the XML is attached whatever the validation finds, so such an e-invoice may be invalid.)
