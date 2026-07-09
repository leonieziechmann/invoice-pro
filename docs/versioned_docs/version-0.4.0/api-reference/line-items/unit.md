---
sidebar_position: 2
---

# Unit

The `unit` module provides standard billing units mapped to their UNECE Recommendation 20 (ZUGFeRD) keys. These units automatically translate their names depending on the active document locale (German, English, Spanish, French, and Italian are supported).

---

## Dynamic Unit Resolution

All units are defined as builder functions that accept the document `locale`.

You can either pass the evaluated unit dictionary directly or pass the function (e.g., `unit.hour`) to an `item` or `bundle`. When a unit function is passed, the engine **automatically resolves** it using the document's global locale context, ensuring clean and dry document code.

**Example Usage:**

```typst
#import "@preview/invoice-pro:0.4.0": *

#show: invoice.with(
  locale: locale.de-de, // Sets document language to German
  // ...
)

#line-items[
  // Passing the builder function (resolved dynamically to "Stunde" with ZUGFeRD code "HUR")
  #item([IT Consulting], price: 120.00, quantity: 8, unit: unit.hour)

  // Or using shorthand aliases (resolved dynamically to "Meter" with ZUGFeRD code "MTR")
  #item([Network Cable], price: 1.50, quantity: 50, unit: unit.m)

  // Grouping items under a bundle (resolved dynamically to "Satz" with ZUGFeRD code "SET")
  #bundle([Server Rack Bundle], unit: unit.sets)[
    #item([Rack Case], price: 300.00, quantity: 1)
    #item([Power Distribution Unit], price: 80.00, quantity: 2)
  ]
]
```

---

## Predefined Units and Aliases

Below is a complete index of all predefined units, their ZUGFeRD XML codes, and their available shorter/longer aliases.

| Standard Function      | Code    | Shorthand / Alternative Aliases                                 |
| :--------------------- | :------ | :-------------------------------------------------------------- |
| `piece(locale)`        | **H87** | `pieces`, `stk`, `pc`, `pcs` (default unit for `item`/`bundle`) |
| `unit-set(locale)`     | **SET** | `set-unit`, `sets`                                              |
| `pair(locale)`         | **PR**  | `pairs`, `pr`                                                   |
| `lump-sum(locale)`     | **LS**  | `lumpsum`, `ls`, `pauschal`, `flat`                             |
| `hour(locale)`         | **HUR** | `hours`, `h`, `hr`, `hrs`                                       |
| `day(locale)`          | **DAY** | `days`, `d`                                                     |
| `month(locale)`        | **MON** | `months`, `mo`                                                  |
| `year(locale)`         | **ANN** | `years`, `y`, `yr`                                              |
| `kilogram(locale)`     | **KGM** | `kilograms`, `kg`                                               |
| `gram(locale)`         | **GRM** | `grams`, `g`                                                    |
| `tonne(locale)`        | **TNE** | `tonnes`, `t`                                                   |
| `metre(locale)`        | **MTR** | `metres`, `meter`, `meters`, `m`                                |
| `square-metre(locale)` | **MTK** | `square-metres`, `square-meter`, `square-meters`, `sqm`, `m2`   |
| `millimetre(locale)`   | **MMT** | `millimetres`, `millimeter`, `millimeters`, `mm`                |
| `centimetre(locale)`   | **CMT** | `centimetres`, `centimeter`, `centimeters`, `cm`                |
| `kilometre(locale)`    | **KMT** | `kilometres`, `kilometer`, `kilometers`, `km`                   |
| `litre(locale)`        | **LTR** | `litres`, `liter`, `liters`, `l`                                |
| `cubic-metre(locale)`  | **MTQ** | `cubic-metres`, `cubic-meter`, `cubic-meters`, `m3`             |

---

## Unit Dictionary Schema

Evaluating any unit builder function returns a dictionary with the following format:

```typst
(
  code: "HUR",          // UN/CEFACT Recommendation 20 XML code
  name: "Stunde",       // Localized unit name (used for calculations/logic)
  display: "Stunde",    // String/content rendered on the PDF layout
)
```
