---
sidebar_position: 1
---

# Country

The `country` module provides a standardized way to define country-specific configurations for sender and recipient addresses. This module controls formatting of city and postal code layout positions and ensures compliance with ZUGFeRD/Factur-X standards by mapping to the correct ISO 3166-1 alpha-2 country codes.

---

## Predefined Countries

Predefined country configurations are available for most countries and can be referenced directly as properties:

| Country Code | Property            | Default Name       | City Format Style                         |
| :----------- | :------------------ | :----------------- | :---------------------------------------- |
| **AT**       | `country.at`        | `"Österreich"`     | European (e.g., `1234 Wien`)              |
| **BE**       | `country.be`        | `"België"`         | European (e.g., `1000 Brussel`)           |
| **CH**       | `country.ch`        | `"Schweiz"`        | European (e.g., `8000 Zürich`)            |
| **DE**       | `country.de`        | `"Deutschland"`    | European (e.g., `10115 Berlin`)           |
| **ES**       | `country.es`        | `"España"`         | European (e.g., `28001 Madrid`)           |
| **FR**       | `country.fr`        | `"France"`         | European (e.g., `75001 Paris`)            |
| **GB / UK**  | `country.uk` / `gb` | `"United Kingdom"` | UK Postcode (e.g., `London \n SW1A 2AA`)  |
| **IT**       | `country.it`        | `"Italia"`         | European (e.g., `00187 Roma`)             |
| **US**       | `country.us`        | `"United States"`  | US State/Zip (e.g., `New York, NY 10001`) |

Other EU member states are also predefined (e.g., `bg`, `cy`, `cz`, `dk`, `ee`, `gr`, `hr`, `hu`, `ie`, `lt`, `lu`, `lv`, `mt`, `nl`, `pl`, `pt`, `ro`, `se`, `si`, `sk`).

**Example Usage:**

```typst
#import "@preview/invoice-pro:0.4.0": invoice, country

#show: invoice.with(
  sender: (
    name: "My Company GmbH",
    address: "Stubenring 1",
    city: "1010 Wien",
    country: country.at, // Customizes address format and ZUGFeRD XML
  ),
  recipient: (
    name: "US Client Inc",
    address: "123 Main St",
    city: "New York, NY 10001",
    country: country.us,
  ),
  // ...
)
```

---

## Customizing Predefined Countries

If you need to change the displayed name of a predefined country (e.g., if writing the invoice in another language), you can customize it using Typst's `.with()` feature:

```typst
// Displays "Allemagne" instead of "Deutschland", but retains the "DE" ZUGFeRD country code
#let french-germany = country.de.with(name: "Allemagne")
```

---

## Country Dictionary Schema

A country object is a structured dictionary with the following schema:

| Key              | Type       | Description                                                                  |
| :--------------- | :--------- | :--------------------------------------------------------------------------- |
| `name`           | `str`      | The human-readable name of the country.                                      |
| `code`           | `str`      | The ISO 3166-1 alpha-2 code of the country (e.g., `"DE"`, `"GB"`).           |
| `parse-city`     | `function` | Parses a raw address city line string to extract the `name` and `post-code`. |
| `format-address` | `function` | Formats the recipient/sender elements vertically into content block lines.   |
| `format-inline`  | `function` | Formats the recipient/sender elements horizontally into an inline string.    |
