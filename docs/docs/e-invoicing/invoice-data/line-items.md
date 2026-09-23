---
sidebar_position: 2
---

# Line Items and Units

Each `item` and each `bundle` of the line items is an invoice line (BG-25) of the e-invoice, in the profiles with invoice lines (`"basic"`, `"en16931"` and `"xrechnung"`); a bundle whose items have several VAT groups is one line per group. `"minimum"` and `"basic-wl"` state the totals only.

## Unit Codes

ZUGFeRD requires line-item units to comply with the **UN/ECE Recommendation 20** unit code standard. To ensure a fully compliant configuration, the following approaches are supported (in order of preference):

- **Predefined Units (Recommended):** Use the predefined unit builder functions from the `unit` module (e.g., `unit.hour`, `unit.day`, `unit.piece`, etc.). These are automatically resolved using the document's global locale and map to compliant UN/ECE codes. See the [Unit API Reference](../../api-reference/line-items/unit.md) for details.
  ```typst
  unit: unit.hour
  ```
- **Custom / Dictionary Units:** If you have special or custom unit requirements, pass a dictionary containing both the display text and the official UN/ECE code:
  ```typst
  unit: (display: "Piece", code: "C62")
  ```
- **Automatic Mapping:** A string that is exactly a unit code (e.g. `"H87"`) is used as is. Other strings are mapped by the unit names of every language of `invoice-pro`, the symbols of the `unit` module and common abbreviations, e.g. `"Std."` or `"hrs"` for hours, `"Tage"` for days, `"m²"` or `"qm"` for square metres, `"km"`, `"t"`, `"kWh"`, `"Stk."` for pieces, `"Seiten"` for pages or `"pauschal"` for a lump sum. A string `invoice-pro` does not know is an error (`IP-UNIT-02`) rather than a guess: with the code `C62` (one), the XML would be valid, but it would state another unit than the invoice prints. Pass the unit as a dictionary with its code, e.g. `(display: "Nacht", code: "C62")` for a number of nights. A code that is also a common German abbreviation of another unit (`"STK"` is the code of sticks, `"PAL"` of pascal; also `"FL"`, `"GL"` and `"KT"`) is taken as a code, with a warning (`IP-UNIT-01`).

Unit codes are checked against the UN/ECE Recommendation 20 code list.

## Prices and Quantities

Unit prices are rounded to the fine precision of the locale (`normalize.money-fine`, 4 decimals by default) before the line totals are calculated, and the printed invoice and the XML use this rounded price. For prices with more decimals (e.g. energy tariffs), round them more finely, up to 6 decimals:

```typst
#show: invoice.with(
  locale: locale.de-de.with(
    locale.custom.normalize(money-fine: x => calc.round(x, digits: 6)),
  ),
  // ...
)
```

A `base-quantity` (e.g. a price per 100 pieces) is written as the price base quantity (BT-149); it must be greater than 0.

Quantities and base quantities are rounded to 4 decimals, the precision the built-in number formats print, before anything is calculated with them. A quantity of `1/3` is therefore printed and written as 0.3333, and with a price of 1000.00 the line total is 333.30, as a reader of the invoice would calculate it. If you print numbers with a custom `format.number`, keep at least 4 decimals so the printed quantity is the one the total is based on.

## Item Identifiers

Line items can carry article identifiers through the `item-id` parameter:

- **Seller's Item Identifier (BT-155):** A plain string such as `item-id: "ART-4711"`, or `(seller: "ART-4711")`, is your own article number.
- **Buyer's Item Identifier (BT-156):** `(buyer: "B-778")` is the buyer's article number.
- **Standard Identifier (BT-157):** `(standard: "4006381333931")` is always declared as a GS1 GTIN (scheme `0160`). Use it only for real EAN/UPC barcode numbers.

The `"basic"` profile only supports the standard identifier. See [The `item-id` Parameter](../../api-reference/line-items/index.md#the-item-id-parameter-and-zugferd) for details.

## Item Notes, Periods and Country of Origin

Besides its name and description, an [`item`](../../api-reference/line-items/index.md#item) can state a note, its date and the country its goods come from. They are printed with the item and written into its invoice line:

| `item` parameter                                                  | Printed                                                             | XML                                                                                  | Profiles                              |
| :---------------------------------------------------------------- | :------------------------------------------------------------------ | :----------------------------------------------------------------------------------- | :------------------------------------ |
| `note`, a text                                                    | below the description                                               | invoice line note (BT-127), with its line breaks                                     | `"basic"`, `"en16931"`, `"xrechnung"` |
| `date`, a `datetime` or a period `(start, end)`                   | as the date of the item                                             | invoice line period (BG-26, BT-134 and BT-135); a single date is a period of one day | `"basic"`, `"en16931"`, `"xrechnung"` |
| `origin`, a country (`country.it`) or an ISO 3166-1 code (`"IT"`) | below the note, e.g. "Ursprungsland: IT" or "Country of origin: IT" | item country of origin (BT-159)                                                      | `"en16931"`, `"xrechnung"`            |

`"minimum"` and `"basic-wl"` have no invoice lines. `"basic"` has no country of origin: `origin` is only printed there, which is reported as a warning (`IP-PROFILE-01`). A `bundle` is one line, printed with the names of its items, so an item inside it cannot have a `note` or an `origin` (an error); mention them in the `description` of the bundle. A country that is not in the ISO 3166-1 code list of EN 16931 (`BR-CL-15`) and a period that ends before it starts (`BR-30`) stop the e-invoice.

The dates of the items are the service period of the invoice, unless you set `service-period` (see [Service Period](./document.md#service-period-bt-72--bg-14)). Then the date of every item must lie within it: XRechnung requires this for an invoicing period (`PEPPOL-EN16931-R110` and `R111`, which the KoSIT validator reports as warnings and Mustang as errors, so `invoice-pro` reports an error); in the other profiles, and for a service period of a single day, a date outside it is a warning (`IP-PERIOD-02`).

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  zugferd: "en16931",
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@consultinggroup.de",
    ),
  ),
  recipient: (
    name: "Acme Corp",
    address: "Industrial Road 1",
    city: "70173 Stuttgart",
    country: country.de,
    vat-id: "DE987654321",
  ),
  invoice-nr: "INV-2026-118",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item(
    [Espresso machine],
    price: 1290.00,
    tax: tax.vat(19%),
    date: datetime(year: 2026, month: 8, day: 3),
    note: "Serial number 4711-0815",
    origin: country.it,
  )
  #item(
    [Barista training],
    quantity: 2,
    unit: unit.day,
    price: 450.00,
    tax: tax.vat(19%),
    date: (
      datetime(year: 2026, month: 8, day: 10),
      datetime(year: 2026, month: 8, day: 11),
    ),
  )
]

#payment-terms(days: 14)

#bank-details(
  bank: "Acme Bank",
  iban: "DE89370400440532013000",
)
```
