---
sidebar_position: 1
---

# Country

The `country` of the `sender`, the `recipient` and a `delivery-address` sets the ISO 3166-1 alpha-2 country code of the party (written to the ZUGFeRD / Factur-X XML), the country line printed for foreign addresses, and how the `city` line is split into post code and city name.

---

## Stating the Country

The `country` key accepts:

- **A predefined country** of the `country` module, e.g. `country.fr` (see the table below).
- **An ISO 3166-1 alpha-2 code** as string or content, e.g. `"FR"` or `"fr"`. A code of a predefined country gives that country (`"UK"` is accepted for `"GB"`, here and in every other form of the code); any other code gives a country without printed name, e.g. `"NO"`.
- **A custom country** created with [`country.custom`](#countries-outside-the-module), e.g. `country.custom(code: "NO", name: "Norge")`.

Any other value, e.g. `"Germany"`, stops the compilation with an error instead of being replaced by another country.

Without `country` (or with `none` or an empty string, e.g. from an empty column of imported data), the sender and the recipient are in the country of the [locale](./index.md#locale) region (e.g. `DE` for `locale.de-de`), and a delivery address is in the recipient's country. For e-invoices, state the country of every party, above all for foreign parties.

**Example Usage:**

```typst
#import "@preview/invoice-pro:0.4.2": invoice, country

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
    country: "US", // The ISO code works as well
  ),
  // ...
)
```

---

## Predefined Countries

The predefined countries print the city line in the order of the country and recognize its post code format:

| Code        | Property             | Default Name       | City line (post code format)                  |
| :---------- | :------------------- | :----------------- | :-------------------------------------------- |
| **AT**      | `country.at`         | `"Österreich"`     | `1010 Wien` (4 digits)                        |
| **BE**      | `country.be`         | `"België"`         | `1000 Brussel` (4 digits)                     |
| **BG**      | `country.bg`         | `"Bulgaria"`       | `1000 Sofia` (4 digits)                       |
| **CH**      | `country.ch`         | `"Schweiz"`        | `8001 Zürich` (4 digits)                      |
| **CY**      | `country.cy`         | `"Cyprus"`         | `1010 Nicosia` (4 digits)                     |
| **CZ**      | `country.cz`         | `"Česko"`          | `110 00 Praha 1` (5 digits, `999 99`)         |
| **DE**      | `country.de`         | `"Deutschland"`    | `10115 Berlin` (5 digits)                     |
| **DK**      | `country.dk`         | `"Danmark"`        | `1050 København K` (4 digits)                 |
| **EE**      | `country.ee`         | `"Eesti"`          | `10111 Tallinn` (5 digits)                    |
| **ES**      | `country.es`         | `"España"`         | `28001 Madrid` (5 digits)                     |
| **FI**      | `country.fi`         | `"Suomi"`          | `00100 Helsinki` (5 digits)                   |
| **FR**      | `country.fr`         | `"France"`         | `75001 Paris` (5 digits)                      |
| **GB / UK** | `country.uk` / `.gb` | `"United Kingdom"` | `London \ SW1A 2AA` (postcode after the city) |
| **GR**      | `country.gr`         | `"Greece"`         | `105 57 Athina` (5 digits, `999 99`)          |
| **HR**      | `country.hr`         | `"Hrvatska"`       | `10000 Zagreb` (5 digits)                     |
| **HU**      | `country.hu`         | `"Magyarország"`   | `1051 Budapest` (4 digits)                    |
| **IE**      | `country.ie`         | `"Ireland"`        | `Dublin 2 \ D02 X285` (Eircode after)         |
| **IT**      | `country.it`         | `"Italia"`         | `00187 Roma` (5 digits)                       |
| **LT**      | `country.lt`         | `"Lietuva"`        | `LT-01100 Vilnius`                            |
| **LU**      | `country.lu`         | `"Luxembourg"`     | `L-1648 Luxembourg`                           |
| **LV**      | `country.lv`         | `"Latvija"`        | `LV-1050 Riga`                                |
| **MT**      | `country.mt`         | `"Malta"`          | `Valletta VLT 1117` (post code after)         |
| **NL**      | `country.nl`         | `"Nederland"`      | `1012 AB Amsterdam` (`9999 AA`)               |
| **PL**      | `country.pl`         | `"Polska"`         | `00-950 Warszawa` (`99-999`)                  |
| **PT**      | `country.pt`         | `"Portugal"`       | `1000-001 Lisboa` (`9999-999`)                |
| **RO**      | `country.ro`         | `"România"`        | `010011 București` (6 digits)                 |
| **SE**      | `country.se`         | `"Sverige"`        | `114 55 Stockholm` (5 digits, `999 99`)       |
| **SI**      | `country.si`         | `"Slovenija"`      | `1000 Ljubljana` (4 digits)                   |
| **SK**      | `country.sk`         | `"Slovensko"`      | `811 01 Bratislava` (5 digits, `999 99`)      |
| **US**      | `country.us`         | `"United States"`  | `New York, NY 10001` (state and ZIP code)     |

A post code may carry the country marker (e.g. `D-10115 Berlin`, `CH-8001 Zürich`); it is left out of the post code, except for Lithuania, Luxembourg and Latvia, where it is part of the official post code.

### Post Codes

A `city` given as string or content is split into post code and city name in the format of the country. A line whose post code does not match that format (e.g. `"1012 Amsterdam"` for the Netherlands, or `"8001 Zürich"` for a party in `country.de`) is not taken apart: the whole line is the city name and the post code stays empty. Check the country of the party, or give the parts explicitly:

```typst
city: (name: "Amsterdam", post-code: "1012 AB")
```

The post code must be a string (or content): `post-code: "01067"`, not `post-code: 01067`, which would lose the leading zero and is rejected.

---

## Customizing Predefined Countries

If you need to change the displayed name of a predefined country (e.g., if writing the invoice in another language), you can customize it using Typst's `.with()` feature:

```typst
// Displays "Allemagne" instead of "Deutschland", but retains the "DE" ZUGFeRD country code
#let french-germany = country.de.with(name: "Allemagne")
```

Set `show-always: true` to print the country line even for domestic addresses.

`.with()` keeps the city line format of the country: `country.de.with(code: "NO")` would still expect German post codes of 5 digits, so that `"0154 Oslo"` is not split into post code and city. For another country, use its ISO code (`"NO"`), its predefined country or [`country.custom`](#countries-outside-the-module).

---

## Countries Outside the Module

`country.custom` creates any other country:

| Parameter            | Type                                | Description                                                                                                                                                                                                        |
| :------------------- | :---------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `code`               | `str`                               | **Required.** The ISO 3166-1 alpha-2 code, e.g. `"NO"`.                                                                                                                                                            |
| `name`               | `none` \| `str` \| `content`        | The printed name of the country. Without, only the code is printed.                                                                                                                                                |
| `show-always`        | `bool`                              | Print the country line even for domestic addresses. Defaults to `false`.                                                                                                                                           |
| `post-code`          | `auto` \| `str` \| `array` of `str` | The format of the post code as a mask: `9` stands for a digit, `A` for a letter, a space for an optional space, anything else for itself (e.g. `"9999"`, `"A9A 9A9"`, `"999-9999"`). `auto` accepts 4 or 5 digits. |
| `post-code-position` | `"before"` \| `"after"`             | Whether the post code stands before the city name (`0154 Oslo`) or after it (`Toronto ON M5V 2T6`). Defaults to `"before"`.                                                                                        |

```typst
#let norway = country.custom(code: "NO", name: "Norge", post-code: "9999")
#let canada = country.custom(
  code: "CA",
  name: "Canada",
  post-code: "A9A 9A9",
  post-code-position: "after",
)

#show: invoice.with(
  // ...
  recipient: (
    name: "Eksempel AS",
    address: "Karl Johans gate 1",
    city: "0154 Oslo",
    country: norway,
  ),
)
```

The code must consist of two letters; the e-invoice additionally checks it against the ISO 3166-1 code list of EN 16931.

---

## Country Dictionary Schema

A country object is a structured dictionary with the following schema:

| Key              | Type       | Description                                                                  |
| :--------------- | :--------- | :--------------------------------------------------------------------------- |
| `name`           | `str`      | The human-readable name of the country.                                      |
| `code`           | `str`      | The ISO 3166-1 alpha-2 code of the country (e.g., `"DE"`, `"GB"`).           |
| `show-always`    | `bool`     | Print the country line even for domestic addresses.                          |
| `parse-city`     | `function` | Parses a raw address city line string to extract the `name` and `post-code`. |
| `format-address` | `function` | Formats the recipient/sender elements vertically into content block lines.   |
| `format-inline`  | `function` | Formats the recipient/sender elements horizontally into an inline string.    |

Only `code` is required when you pass a dictionary as `country`, e.g. `(code: "NO", name: "Norge")`: the missing keys are taken from the predefined country of that code, or from `country.custom`.

The older `region` key of a party (e.g. `region: "fr"`) is still accepted as an alias of `country`; `country` takes precedence.
