---
sidebar_position: 1
---

# Parties and Identifiers

The seller is the `sender` of the invoice and the buyer its `recipient`; on a self-billed invoice, which the buyer issues, it is the other way round (see [Self-Billed Invoices](./document.md#self-billed-invoices)). This page describes what the e-invoice needs from them and from the other parties: the seller's tax representative and the payee.

## Name and Address

Both the `sender` and the `recipient` need a name and an address with its city and country.

### Name

A `name` given as several lines is written as one name (BT-27, BT-44), its lines joined with `, ` as in the inline sender line: `("Kunde GmbH", "z. Hd. Frau Müller")` becomes `Kunde GmbH, z. Hd. Frau Müller`. Put a line that is not part of the name, such as an attention line, into `address` instead.

### Country

The `country` of a party is a country of the `country` module (e.g., `country.de`, `country.fr`, `country.us`), an ISO 3166-1 alpha-2 code (e.g., `"FR"`) or a country created with `country.custom(code: "NO", name: "Norge")`. Without `country`, the party is in the country of the locale region, and a `delivery-address` is in the recipient's country. If the VAT identifier of a party without `country` was issued by another country, the default is most likely wrong, and the e-invoice stops with `IP-COUNTRY-01`; an explicit `country` settles it, also for a foreign VAT registration. See the [Country API](../../api-reference/invoice/country.md) documentation for details.

### Address

ZUGFeRD supports up to three distinct address lines (`ram:LineOne`, `ram:LineTwo`, and `ram:LineThree`). You can specify the address in any of the following polymorphic forms, which are fully supported:

- **A single string or content:** Maps entirely to `ram:LineOne` (e.g., `"123 Main St"`).
- **An array of strings or content:** Maps sequentially to the three lines. If there are more than three elements in the array, the remaining elements are joined automatically into `ram:LineThree` using a comma separator (e.g., `("123 Main St", "Suite 100", "4th Floor", "Room 402")` maps to `"123 Main St"`, `"Suite 100"`, and `"4th Floor, Room 402"` respectively).

### City and Postal Code

The city and the postal code must be fully specified. To ensure correct splitting for XML generation, you can provide this in one of two ways:

- **As a String (Parsed Automatically):** Pass the city and postal code as a single string (e.g., `"10115 Berlin"`, `"1012 AB Amsterdam"`) or as content (e.g., `[#plz #ort]`). The post code is recognized in the format of the party's `country` (see [Predefined Countries](../../api-reference/invoice/country.md#predefined-countries)). A post code of another format is not taken apart, so check the `country` of the party: a city line with a number of three or more digits and no recognized post code stops the e-invoice (`IP-ADDR-01`), as the post code would be missing from the XML. District numbers such as `"Praha 1"` or `"Dublin 2"` are fine. For a country that is not predefined, `country.custom(code: .., post-code: ..)` sets the format of its post codes (e.g. `post-code: "999-9999"` for Japan).
- **As a Dictionary (Explicit Definition):** Alternatively, explicitly define the name and post-code using a dictionary to prevent any parsing ambiguity. The post code must be a string, so that leading zeros are kept:
  ```typst
  city: (name: "Berlin", post-code: "10115")
  ```

## Tax Identifiers

- The **sender** should include a `tax-nr` (national tax number) and/or `vat-id` (value-added tax identifier, written with its country prefix, e.g. `"DE123456789"`; spaces and invisible characters, such as the zero width spaces of copied text, are removed). The law requires one of them on the printed invoice (§ 14 Abs. 4 Satz 1 Nr. 2 UStG; Art. 226 No. 3 of the VAT Directive requires the VAT identifier): the default `references` and every [preset](../../api-reference/invoice/references.md#preset-packages) print the seller's tax number and VAT identifier and the buyer's VAT identifier, with net and gross prices alike. Earlier versions printed none of them for gross prices (`tax-mode: "inclusive"`).
- The **recipient** (buyer) should include a `vat-id` if applicable. Intra-community supplies (`K`) require it. Reverse charge (`AE`) requires it or, for a buyer without VAT identifier (e.g. a domestic reverse charge under § 13b UStG), the buyer's `legal-id` (BT-47, see below). A cross-border reverse charge needs the VAT identifier by law (Art. 226 No. 4 of the VAT Directive), which the legal registration identifier does not replace (`IP-VAT-226`). In `"basic-wl"`, which has no invoice lines, `invoice-pro` requires it for `K` and a cross-border `AE` by law (`IP-VAT-226`), but not for a domestic reverse charge.
- The `"minimum"` profile identifies the seller by its VAT identifier (BT-31) or its legal registration identifier (BT-30), so the **sender** needs a `vat-id` or a `legal-id` there, e.g. a French micro-entrepreneur without VAT identifier its SIRET (`legal-id: id.siret(..)`). Senders identified by a `tax-nr` or `id` only need `"basic-wl"` or higher.

## Identifiers

### Seller Identifier (BT-29)

The buyer must be able to identify the seller (BR-CO-26), by the VAT identifier, the legal registration identifier or a seller identifier. Without any of them, the `tax-nr` is used as seller identifier. To state a different identifier, e.g. your supplier number at the customer, set `id` on the sender; it does not assert a tax registration. A globally registered identifier (e.g. a GLN) can be given with its ISO/IEC 6523 scheme, most easily with the [`id` module](../../api-reference/invoice/identifiers.md):

```typst
sender: (
  ...
  id: "70025",
  global-id: id.gln("4000001123452"), // or: (scheme: "0088", id: "4000001123452")
)
```

`id` accepts a scheme as well (`id: (scheme: "0088", id: ..)` is the same as `global-id`), and a `global-id` without scheme is an ordinary identifier. Only one identifier without scheme and one with scheme can be written, so a `global-id` without scheme next to `id` stops the e-invoice (`IP-ID-02`) instead of being dropped.

The same keys on the `recipient` set the buyer identifier (BT-46), and on the `delivery-address` the deliver-to location identifier (BT-71, `id` or `location-id`). The buyer and the delivery address take only one of them, `id` or `global-id` (CII-SR-450, CII-SR-449, from the `"basic"` profile on).

### Legal Registration Identifier (BT-30, BT-47)

The number of a party in an official register, e.g. the SIREN or SIRET of a French company, the German Handelsregister number or the Swiss UID, is its `legal-id`, on the `sender` and on the `recipient`. Every profile states it, MINIMUM included. Give it as text, which is stated without a scheme, or with a constructor of the [`id` module](../../api-reference/invoice/identifiers.md), which states the ISO/IEC 6523 scheme and checks the check digit:

| Identifier                | Input                                                             | Stated as                                  |
| :------------------------ | :---------------------------------------------------------------- | :----------------------------------------- |
| SIREN (France)            | `legal-id: id.siren("123 456 782")`                               | `123456782`, scheme `0002`                 |
| SIRET (France)            | `legal-id: id.siret("123 456 782 00010")`                         | `12345678200010`, scheme `0009`            |
| UID (Switzerland)         | `legal-id: id.uid-ch("CHE-123.456.788")`                          | `CHE123456788`, scheme `0183`              |
| Handelsregister (Germany) | `legal-id: id.register("HRB 4711", court: "Amtsgericht München")` | `Amtsgericht München, HRB 4711`, no scheme |
| Another register          | `legal-id: id.custom("0208", "0123456749")`                       | `0123456749`, scheme `0208`                |
| GLN (a location, as `id`) | `global-id: id.gln("4000001123452")`                              | `4000001123452`, scheme `0088` (BT-29)     |

A wrong check digit stops the e-invoice (`IP-ID-01`); `id.custom` takes an identifier unchecked. An identifier given for a field it does not belong to, such as a GLN as `legal-id` or a register number as `id`, stops it as well (`IP-ID-03`). The scheme of a legal registration identifier must be an ISO/IEC 6523 code (`BR-CL-11`). An identifier that produces no text, such as `legal-id: id.siret` without calling the constructor or `legal-id: (scheme: "0002")` without `id`, stops the compilation with the field, also without e-invoice; earlier versions left it out without notice.

## Trading Name and Legal Information (BT-28, BT-45, BT-33)

`trading-name` on the `sender` or `recipient` is the name the party trades under, besides its legal `name`. `legal-info` on the `sender` is additional legal information about the seller, such as its managing directors, its registered office or its share capital (e.g. `"SAS au capital de 10 000 €, RCS Paris 123 456 782"`). The seller's trading name is stated from the `"basic-wl"` profile on, the buyer's trading name and the legal information in `"en16931"` and `"xrechnung"`; a profile that cannot state an input reports it as a warning (`IP-PROFILE-01`).

The built-in themes do not print these inputs: where the law requires them on the invoice, print them from the same value, e.g. as the `register` or `management` of the sender, which the legal footer of the themes prints, or in `extra` (see [Printing identifiers](../../api-reference/invoice/identifiers.md#printing-identifiers)).

## Contacts

### Seller Contact (BG-6)

Under German XRechnung rules, the seller must specify contact details. You can define this under the `contact` key of the `sender` dictionary (containing keys `name`, `phone`, `email`):

```typst
sender: (
  ...
  contact: (
    name: "Max Mustermann",
    phone: "+49 89 1234567",
    email: "max@consultinggroup.de",
  )
)
```

Alternatively, you can define them as direct fields on `sender` (using keys `contact-name`, `phone`, `email`). Missing fields of `contact` fall back to these keys.

### Buyer Contact (BG-9)

The `contact` of the `recipient` (or its keys `contact-name` and `phone`) is written as the buyer contact in `"en16931"` and `"xrechnung"`, with the same keys as the seller contact. An `email` of the recipient alone is not a contact point: it is where the invoice goes, the electronic address (see below). Earlier versions left the buyer contact out of the e-invoice. The built-in themes do not print it; to show it on the printed invoice, print it from the same value, e.g. in `extra` of the recipient, which the built-in themes print with the address (in the DIN 5008 layouts in the annotation zone of the address field).

## Buyer Reference / Leitweg-ID (BT-10)

A buyer reference (such as the customer's Leitweg-ID for public sectors) is mandatory under XRechnung. Define this under `buyer-reference` or `leitweg-id` in the `recipient` dictionary. A Leitweg-ID given with `id.leitweg(..)` is checked for its check digits (`IP-ID-01`), and can be the electronic address of the buyer as well (scheme `0204`), which the report suggests for a buyer with a Leitweg-ID but without electronic address (`PEPPOL-EN16931-R010`):

```typst
recipient: (
  ...
  buyer-reference: "DE123456789-12345-12"
  // or, for a public buyer reached by its Leitweg-ID:
  // leitweg-id: id.leitweg("04011000-1234512345-06"),
  // electronic-address: id.leitweg("04011000-1234512345-06"),
)
```

## Electronic Addresses (BT-34, BT-49)

For routing across networks (such as Peppol), both parties need an electronic address. XRechnung requires them (`PEPPOL-EN16931-R020`, `PEPPOL-EN16931-R010`). EN 16931 leaves them optional, and its validation checks neither: in `"en16931"` a missing address is a warning of `invoice-pro`'s own (`IP-EADDR-01`), and the other profiles do not report it.

- **Auto-derivation from VAT ID:** If `vat-id` is specified on the party, the system derives the endpoint from it. The Electronic Address Scheme (EAS) is chosen by the country prefix of the VAT ID:

  | VAT ID prefix | Scheme | VAT ID prefix | Scheme | VAT ID prefix | Scheme |
  | :------------ | :----- | :------------ | :----- | :------------ | :----- |
  | `AT`          | `9914` | `EL` / `GR`   | `9933` | `LU`          | `9938` |
  | `BE`          | `9925` | `ES`          | `9920` | `LV`          | `9939` |
  | `BG`          | `9926` | `FI`          | `0213` | `MT`          | `9943` |
  | `CH`          | `9927` | `FR`          | `9957` | `NL`          | `9944` |
  | `CY`          | `9928` | `GB`          | `9932` | `PL`          | `9945` |
  | `CZ`          | `9929` | `HR`          | `9934` | `PT`          | `9946` |
  | `DE`          | `9930` | `HU`          | `9910` | `RO`          | `9947` |
  | `EE`          | `9931` | `IE`          | `9935` | `SI`          | `9949` |
  |               |        | `IT`          | `0211` | `SK`          | `9950` |
  |               |        | `LT`          | `9937` |               |        |

  The endpoint is derived from the VAT ID on invoices not subject to VAT (category `O`) as well: they leave out the VAT identifiers themselves (BR-O-02), but the electronic address is no VAT identifier.

- **Email Fallback:** Without a VAT ID, or with a VAT ID whose prefix is not in the table (e.g. a Danish `DK` or Swedish `SE` VAT ID, for which the EAS code list has no scheme), the email address (`contact.email` or `email`) is used with the scheme `EM`. The scheme always follows the VAT ID prefix, never the country of the address.
- **Manual Override:** You can manually specify a custom electronic address on the party dictionary. A plain email address is accepted as well:
  ```typst
  sender: (
    ...
    electronic-address: (scheme: "0088", id: "4000001123452") // GLN Example
    // or: electronic-address: "invoices@example.com"
  )
  ```
  An address without identifier, such as `""` (e.g. an empty field of imported data), `auto` or a dictionary without `id`, counts as not given: the address is derived as described above. An address without scheme must be an email address; any other identifier needs its scheme, otherwise the e-invoice stops (BR-62 for the sender, BR-63 for the recipient). The scheme must be in the EAS code lists that the validation of the profile applies (BR-CL-25, and `FX-SCH-A-000031` for the list of Factur-X): XRechnung accepts the schemes `0219` and `0220`, which the Factur-X list lacks. A scheme the list has withdrawn, such as `9901`, stops the e-invoice in every profile (`IP-CODE-01` in `"basic-wl"` and `"basic"`, whose validation still accepts it), and so does one that only its newest version has, such as `0240`.

## Seller Tax Representative (BG-11)

A seller that is registered for VAT through a fiscal representative, e.g. a company from outside the EU, names it as `tax-representative` on the `sender`, with its name, address and VAT identifier:

```typst
sender: (
  name: "Alpen Maschinen AG",
  ...
  country: country.ch,
  legal-id: id.uid-ch("CHE-123.456.788"),
  tax-representative: (
    name: "Fiskalvertretung Muster GmbH",
    address: "Steuerweg 3",
    city: "60311 Frankfurt am Main",
    country: country.de,
    vat-id: "DE987654328",
  ),
)
```

The representative's VAT identifier (BT-63) satisfies the rules that ask for a seller VAT identifier, e.g. for standard rated items (`BR-S-02`) or an intra-community supply (`BR-IC-02`): never give it as the seller's own `vat-id`. It does not identify the seller, so the seller still needs its `id`, `legal-id` or `vat-id` (`BR-CO-26`). The representative needs a name (`BR-18`), a VAT identifier (`BR-56`) and an address, which the law requires on the invoice (`IP-VAT-226`, Art. 226 No. 15 of the VAT Directive). An invoice not subject to VAT (`O`) states no VAT identifiers, so it cannot name a tax representative with a VAT identifier (`BR-O-02` for its lines; in `"basic-wl"`, which states no lines, `BR-O-03` or `BR-O-04` for a document level allowance or charge, else `IP-TAX-05`). The profiles from `"basic-wl"` on state it; the built-in themes do not print it, so state it on the printed invoice as well, e.g. in its text.

## Payee (BG-10)

When someone other than the seller receives the payment, e.g. a factoring company, name it with `payee` on the invoice (from the `"basic-wl"` profile on):

```typst
#show: invoice.with(
  ...
  payee: (
    name: "Factoring Bank AG",
    global-id: id.gln("4000001543212"),                  // or `id`: BT-60
    legal-id: id.register("HRB 12345", court: "Amtsgericht Frankfurt am Main"), // BT-61
  ),
)
```

A payee needs its name, which is not the seller's (`BR-17`; in `"basic-wl"`, whose validation checks the name only, a payee that is the seller is `IP-PAY-05`), and at most one of `id` and `global-id` (`CII-SR-451`). Leave out `payee` when the seller receives the payment itself. The printed invoice names the payee as the e-invoice does: the default `references` and every preset print it ("Zahlungsempfänger", "Payee", `references.payee()`), and it is the default account holder of the [`bank-details`](../../api-reference/components.md#bank-details), whom the EPC-QR code names as the beneficiary, except on a credit note, which refunds the buyer. The account name of the e-invoice (BT-85) is only written for a `name` given to `bank-details`.

## Keys

A key of `sender`, `recipient` or `delivery-address` that `invoice-pro` does not know is not written into the e-invoice, which is reported as a warning (`IP-KEY-01`). A key that looks like a misspelling or another name of a key the e-invoice reads, such as `vatId`, `vat_id`, `ustid`, `uid`, `e-mail`, `legal_id`, `siret` or `handelsregister` (the last two stand for `legal-id`), stops the e-invoice (`IP-KEY-02`), as its value would be missing without notice. Give a SIRET or SIREN as `legal-id: id.siret(..)` or `legal-id: id.siren(..)`. So does a post code key such as `zip` or `plz` while the `city` line has no post code: the post code belongs in `city`. Keys that invoices often carry, such as `fax-nr`, are not taken for misspellings.
