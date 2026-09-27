<!-- The sections of docs/docs/e-invoicing.md that described the runtime write guard and the strict mode, as of 9b4b850. -->

### The XML Write Guard

The validator checks the invoice data; a second check, the write guard, checks the XML itself while it is written, against tables compiled from the official artefacts of the profile (the Factur-X 1.0.07 XSD and Schematron, the CEN Schematron of EN 16931 and, for `"xrechnung"`, the XRechnung 3.0 Schematron). For every e-invoice `invoice-pro` attaches without errors (with `zugferd-errors: "ignore"`, it attaches the XML whatever the checks find), it guarantees:

- **Structure (G1):** every element is known to the profile's schema at its position and not marked as not used there by the Factur-X Schematron; the elements are in schema order and number (`maxOccurs` and the counts of the Schematron); every element the schema or a rule of the Schematron without a condition on values requires is there with its text (an element without text counts as missing), e.g. for `"xrechnung"` the city and post code of the addresses, the contact of the seller, the buyer reference and the rate of each VAT breakdown; every required attribute is there, and no other attribute.
- **Values (G2):** decimals, indicators and dates have their lexical form, and dates in the format `102` name a day of the calendar; amounts have at most the decimals the `BR-DEC-*` rules allow; every code is in the code list of its position. Where several validators apply, the code must be in the list of each of them, e.g. a country code in the list of the Factur-X Schematron and in the one of EN 16931; only a currency that the newest EN 16931 list has withdrawn is allowed in `"basic"` and `"en16931"` where the Factur-X validation accepts it, with a warning (see [Currency](#13-currency-bt-5)). Every tax element (the VAT of a line, of an allowance or charge, and each VAT breakdown) has what its VAT category requires: a rate above 0 for `S`, `L` and `M`, the rate 0 for `Z`, `E`, `AE`, `K` and `G`, and none for `O` (`BR-S-05` and the like); a VAT breakdown has a rate unless its category is `O` (`BR-48`), the VAT amount 0 for `Z`, `E`, `AE`, `K`, `G` and `O`, an exemption reason for `E`, `AE`, `K`, `G` and `O`, and none for `S`, `Z`, `L` and `M` (`BR-E-09`, `BR-E-10` and the like).
- **Round trip (G3):** the XML as Typst's parser reads it back states exactly what the invoice data states, through a table of its own that maps every element to its business term (independent of the code that writes the XML): no value differs, none is left out that the profile can state, none is added, and every repeated group (notes, payment means, VAT breakdown, allowances and charges, lines) has as many entries as the invoice. Amounts, quantities and rates are compared as numbers (`19.00` is 19 %), dates in the format `102`. This covers the header of the document (the document, the parties, references, delivery, payment, VAT breakdown, allowances and charges, and the totals) and the number of lines; the [strict mode](#the-strict-mode) compares every line as well. The round trip runs when G1 and G2 found nothing, so that every element and value it reads has its form; a finding of G1 or G2 is an error in any case.
- **Well-formed (G4):** Typst's XML parser reads the bytes that are attached as one `CrossIndustryInvoice` document.

The guard does not change the XML: the file is the same with or without it. What it finds is added to the diagnostics, as errors, and `zugferd-errors` treats them like the validator's. A problem the validator reports already (the same rule or the same input) is not listed twice. Since the validator checks every input before, a finding of the guard is a bug of `invoice-pro`: if the guard finds something the validator does not, each finding is listed with the hint to report it; if the validator reports errors, the guard's other findings are one entry, as they may follow from those errors. A finding names the official rule of the check where there is one (e.g. `BR-CL-14` for a country code), and otherwise a rule of the guard:

[//]: # "Generated from src/zugferd/rules/registry.json by tools/zugferd/registry.py --write-docs; edit the registry instead."

| Rule          | Checks                                                                                                                  |
| :------------ | :---------------------------------------------------------------------------------------------------------------------- |
| `IP-GUARD-00` | Summarizes the guard's findings next to errors of the validator.                                                        |
| `IP-GUARD-01` | An element the profile's schema does not know at its position, or text where it expects elements.                       |
| `IP-GUARD-02` | An element out of the order of the schema.                                                                              |
| `IP-GUARD-03` | An element more often than the schema or the Schematron allows.                                                         |
| `IP-GUARD-04` | A required element that is missing or has no text.                                                                      |
| `IP-GUARD-05` | An element or attribute the Factur-X Schematron of the profile marks as not used.                                       |
| `IP-GUARD-06` | An attribute the schema does not allow, or a required one that is missing.                                              |
| `IP-GUARD-07` | A value outside its lexical form (e.g. `1,50` as a decimal) or a code outside its list, where no official rule says so. |
| `IP-GUARD-08` | A date in the format `102` that names no day of the calendar (e.g. `20260230`), where no official rule checks it.       |
| `IP-GUARD-09` | An invalid name, a missing namespace declaration, or not exactly one root element: the XML may not be well-formed.      |
| `IP-GUARD-10` | The XML read back states a business term with another value than the data model of the invoice.                         |
| `IP-GUARD-11` | The XML leaves out a business term the data model of the invoice has, although the profile can state it.                |
| `IP-GUARD-12` | The XML states a business term the data model of the invoice does not have.                                             |
| `IP-GUARD-13` | An element, or the entries of a repeated group (e.g. the lines), occur more or less often than the data model has.      |

The guard checks what the schema, the code lists and the rules of the VAT categories say about each element, not the business rules (sums, conditions between different parts of the invoice, and elements required only under such a condition, e.g. an identifier of the seller in `BR-CO-26`), which remain the validator's. It is stricter than the official validators in a few documented places: it rejects the elements the Factur-X Schematron marks as not used (Mustang ignores those reports), dates that name no day, a required element without text also where a rule only asks for the element, and any element `invoice-pro` never writes; and where a rule of the CEN Schematron may be taken over by a rule of higher priority only under a condition on values, it applies the rule anyway. Its tables follow the artefacts of the Mustang CLI 2.14.0, which `invoice-pro` pins: IPSI (`M`) at 0 % is rejected there (`BR-AG-05` tests a rate above 0), while the newer EN 16931 Schematron of KoSIT's XRechnung configuration accepts it.

### The Strict Mode

With `zugferd-strict: true` on the invoice, or `--input zugferd-strict=true` for every invoice of a compilation (`typst compile --input zugferd-strict=true invoice.typ`), the write guard checks more:

- the round trip (G3) of every invoice line: the name, identifiers, note, quantity, unit, price, VAT category and rate, period, allowances and charges and the net amount of each line in the XML are those of the invoice;
- the arithmetic of the amounts the XML states, computed from the XML alone, with the tolerances of the official rules: the sums of the lines, allowances and charges and the totals (`BR-CO-10` to `BR-CO-16`), the VAT amount of each VAT category from its taxable amount and rate, within 1 (`BR-CO-17`), and the taxable amount of each VAT category from its lines, allowances and charges (`BR-S-08` and the like: exactly for `S`, `O`, `L` and `M`, within 1 for `Z`, `E`, `AE`, `K` and `G`). A finding names the official rule the XML breaks.

The standard checks already cover the header, and the invoice data behind the lines is checked before the XML is written, so the strict mode is a second opinion on the written lines. It takes about 0.4 ms per line, about as much as writing the line, so it is off by default. The conformance corpus of `invoice-pro` compiles every e-invoice in the strict mode, and so does `scripts/validate-zugferd`, which validates the e-invoices of its tests; turn it on in your own CI as well.

```typst
#show: invoice.with(
  zugferd: "en16931",
  zugferd-strict: true, // compare every line of the XML, and check its sums
  // ...
)
```
