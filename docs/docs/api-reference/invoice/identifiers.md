---
sidebar_position: 3
---

# Identifiers

The `id` module creates **typed identifiers** of parties: a registration or location number together with the scheme that says what it is. Give them wherever a party identifier is accepted, and the e-invoice (ZUGFeRD / Factur-X / XRechnung) states the identifier with its scheme and checks its format and check digit.

```typst
sender: (
  ...
  legal-id: id.siret("123 456 782 00010"),  // BT-30, scheme 0009
)
```

Identifiers are optional: an invoice without them needs none of this. Plain text is accepted as well (e.g. `legal-id: "HRB 4711"`), and identifiers of the `id` module are only checked for an e-invoice. They are not printed by the built-in themes; see [Printing identifiers](#printing-identifiers).

---

## Constructors

| Constructor                       | Identifier                                                         | Scheme       | Checked                                                                                | Example                                                       |
| :-------------------------------- | :----------------------------------------------------------------- | :----------- | :------------------------------------------------------------------------------------- | :------------------------------------------------------------ |
| `id.gln(value)`                   | Global Location Number of GS1 (a company or a location)            | `0088`       | 13 digits, GS1 check digit                                                             | `id.gln("4000001123452")`                                     |
| `id.duns(value)`                  | D-U-N-S number of Dun & Bradstreet                                 | `0060`       | 9 digits                                                                               | `id.duns("15-048-3782")`                                      |
| `id.siren(value)`                 | SIREN of a French company                                          | `0002`       | 9 digits, Luhn check digit                                                             | `id.siren("123 456 782")`                                     |
| `id.siret(value)`                 | SIRET of a French establishment                                    | `0009`       | 14 digits, Luhn check digit (La Poste: its own check)                                  | `id.siret("123 456 782 00010")`                               |
| `id.uid-ch(value)`                | Swiss enterprise identification number (UID)                       | `0183`       | "CHE" and 9 digits, check digit modulo 11                                              | `id.uid-ch("CHE-123.456.788")`                                |
| `id.register(value, court: none)` | number in a commercial register without a scheme (e.g. German HRB) | none         | not empty                                                                              | `id.register("HRB 4711", court: "Amtsgericht München")`       |
| `id.leitweg(value)`               | Leitweg-ID of a German public buyer                                | `0204` (EAS) | up to 12 digits, part of up to 30 capital letters and digits, check digits (MOD 97-10) | `id.leitweg("04011000-1234512345-06")`                        |
| `id.custom(scheme, id)`           | any other identifier with the code of its scheme                   | as given     | nothing: the escape hatch                                                              | `id.custom("0208", "0123456749")` (Belgian enterprise number) |

- Spaces, dots and hyphens that numbers are often grouped with are removed (`"123 456 782 00010"` is `"12345678200010"`); the hyphens of a Leitweg-ID are part of it.
- `id.uid-ch` also takes the UID with the suffix of a Swiss VAT number ("MWST", "TVA" or "IVA") or of the commercial register ("HR" or "RC"): the suffix is dropped, as the UID is the same.
- `id.register` writes the court in front of the number, e.g. "Amtsgericht München, HRB 4711": a register number is unique only within its register, and EN 16931 has no field of its own for the court.
- The scheme codes are those of ISO/IEC 6523 (ICD), the Leitweg-ID's of the electronic address schemes (EAS). The e-invoice checks the scheme of `id.custom` against the code list of the field it is given for (`BR-CL-10`, `BR-CL-11`, `BR-CL-25`).

## Where Identifiers Go

| Input                                                   | Business term                                          | Takes                                                                 |
| :------------------------------------------------------ | :----------------------------------------------------- | :-------------------------------------------------------------------- |
| `sender.legal-id`, `recipient.legal-id`                 | legal registration identifier (BT-30, BT-47)           | `id.siren`, `id.siret`, `id.uid-ch`, `id.register`, `id.custom`, text |
| `sender.id` / `global-id`, `recipient.id` / `global-id` | seller and buyer identifier (BT-29, BT-46)             | `id.gln`, `id.duns`, `id.siret`, `id.custom`, text                    |
| `delivery-address.id` / `global-id`                     | deliver-to location identifier (BT-71)                 | `id.gln`, `id.custom`, text                                           |
| `payee.id` / `global-id`, `payee.legal-id`              | payee identifier and legal registration (BT-60, BT-61) | as for the seller and buyer                                           |
| `recipient.leitweg-id` or `recipient.buyer-reference`   | buyer reference (BT-10)                                | `id.leitweg`, text                                                    |
| `electronic-address` of `sender` and `recipient`        | electronic address (BT-34, BT-49)                      | `id.leitweg`, `id.gln`, `id.siret`, `id.custom`, text                 |

An identifier with a scheme given as `id` is the global identifier (`ram:GlobalID`), the same as `global-id`. The legal registration identifier is part of every profile, MINIMUM included, where it is the seller's identifier besides its VAT identifier (`BR-CO-26`).

An identifier that produces no text stops the compilation with the input it was given for, with and without e-invoice, as it would be missing from the printed invoice and the XML without notice: a constructor given without calling it (`legal-id: id.siret` instead of `legal-id: id.siret("..")`), or a dictionary whose `id` is missing or empty (`legal-id: (scheme: "0002")`). An empty value such as `""` or `none` (e.g. an empty field of imported data) counts as not given, and an electronic address without `id` is derived from the VAT identifier or the email address instead.

## Problems

A constructor never stops the compilation. What is wrong with an identifier is kept as its problems, and an e-invoice reports them as errors with the input they were given for:

```text
1. [IP-ID-01] sender.legal-id: The check digit of the SIRET "123 456 782 00011" is wrong.
   Hint: Check the identifier for typos. If it is right as it is, give it with `id.custom("0009", ..)`, which does not check it.
```

| Rule       | Checks                                                                                                                                                                                                                             |
| :--------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `IP-ID-01` | The format and check digit of an identifier of the `id` module.                                                                                                                                                                    |
| `IP-ID-03` | An identifier given for a field it does not belong to: a Leitweg-ID as party identifier or legal registration identifier, another identifier as `leitweg-id`, a GLN or D-U-N-S number as `legal-id`, or a register number as `id`. |

`id.custom(scheme, id)` takes any identifier unchecked: use it for schemes without a constructor, and for an identifier you know to be right although its check digit is rejected.

## Printing Identifiers

The built-in themes do not print the legal registration identifier, the trading name or the legal information of a party. Where the law requires them on the invoice (e.g. the register and register court of a German GmbH, the SIREN or SIRET of a French company), print them from the same value, so that the printed invoice and the e-invoice cannot differ:

```typst
#import "@preview/invoice-pro:0.4.2": *

#let register = id.register("HRB 98765", court: "Amtsgericht München")

#show: invoice.with(
  zugferd: "en16931",
  sender: (
    name: "Tech Solutions GmbH",
    address: "Software Allee 10",
    city: "80331 München",
    country: country.de,
    vat-id: "DE123456788",
    legal-id: register,
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 123456",
      email: "rechnung@techsol.example",
    ),
    // Printed by the DIN 5008 theme next to the sender address
    extra: (("Handelsregister", register.id),),
  ),
  recipient: (
    name: "Kunde GmbH",
    address: "Domstraße 5",
    city: "50667 Köln",
    country: country.de,
    vat-id: "DE987654321",
    legal-id: id.register("HRB 12345", court: "Amtsgericht Köln"),
  ),
  invoice-nr: "RE-2026-0101",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Consulting], quantity: 8, unit: unit.hour, price: 120)
]
#payment-goal(days: 14)
#bank-details(iban: "DE89370400440532013000", bic: "COBADEFFXXX")
```

In the text of the invoice, [`#info.sender.legal-id`](../components.md#info-module) prints the identifier of the sender.
