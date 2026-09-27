---
sidebar_position: 3
---

# Taxes

Every item, and every allowance or charge, belongs to a VAT category of EN 16931, which the e-invoice states with its rate. This page describes how the `tax` module maps to these categories, the exemption reasons, the small business exemption and invoices with gross prices.

## Tax Category Codes

Every tax rate must be mapped to a valid **UNTDID 5305** category code. Use the standard functions from the `tax` module:

- Standard VAT/GST: `tax.vat(19%)` (maps to category **S**). Reduced rates are standard rated as well, e.g. `tax.vat(7%)`.
- Zero Rated: `tax.zero()` (maps to category **Z**).
- Tax Exempt: `tax.exempt(grounds: ..)` (maps to category **E**). The `grounds` are mandatory for exempt items (BR-E-10).
- Reverse Charge: `tax.reverse-charge()` (maps to category **AE**). Requires the VAT identifier of the buyer or, for a domestic reverse charge to a buyer without one (e.g. under § 13b UStG), its legal registration identifier (`legal-id` of the recipient). A cross-border reverse charge requires the VAT identifier (`IP-VAT-226`).
- Intra-community Supply: `tax.intra-community()` (maps to category **K**). Requires the VAT identifiers of both parties. Without a `delivery-address`, the buyer's country is stated as deliver-to country; a `delivery-address` without its own `country` is in the buyer's country as well. A deliver-to country that is the seller's own country, or for a seller without VAT identifier of its own the country of its tax representative, or a buyer VAT identifier not issued by an EU member state, is reported as a warning (`IP-VAT-138`, Art. 138 of the VAT Directive).
- Export: `tax.export()` (maps to category **G**). Requires the seller VAT identifier.
- Outside Scope: `tax.outside-scope()` (maps to category **O**). An invoice not subject to VAT carries no VAT identifiers, so the seller is identified by `tax-nr`, `id` or `legal-id`. Items of category `O` cannot be mixed with other categories on one invoice.
- Small Business: `tax-exempt-small-biz: true` uses the small business scheme of the locale's region, category **E** in Germany, Austria, France and Spain and **O** in Italy and Switzerland (see [Small Business Exemption](#small-business-exemption)).

EN 16931 only knows the categories `S`, `Z`, `E`, `AE`, `K`, `G`, `O`, `L` and `M`, and the split payment of Italy (`B`, `tax.special.transferred(..)`), which only `"xrechnung"` accepts: the code list of Factur-X lacks it (`FX-SCH-A-000179`), and it is for a domestic Italian invoice, all of whose addresses are in Italy (`BR-B-01`), without standard rated items (`BR-B-02`). The other special constructors in `tax.special` that map to other categories (e.g. `lower-rate` or the margin schemes) cannot be used for e-invoices. Items under a margin scheme are written as exempt with the note the law requires, e.g. `tax.exempt(grounds: "Margin scheme - second-hand goods")` (in Germany "Gebrauchtgegenstände/Sonderregelung"). `tax.special.ceuta-melilla(..)` (`M`) needs a rate above 0%, and items not subject to VAT (`O`) have none.

`tax: none` on the invoice is not a tax category: the items are printed with 0%, but an e-invoice must say why no VAT is charged, so it stops with the error `IP-TAX-01`. Choose one of the functions above instead.

Avoid using raw percentages (e.g., `19%`) directly on items if you need strict validation, as using the `tax` module functions guarantees the category codes are assigned correctly.

## Exemption Reasons

Where EN 16931 requires an exemption reason (`AE`, `K`, `G`, `O`) and the items give no `grounds` of their own, the note of the invoice language (`tax-exemption` in the [language schema](../../api-reference/locale/base.md#tax-exemption), e.g. "Steuerfreie innergemeinschaftliche Lieferung" for `tax.intra-community()` in German) is printed below the line items and written as exemption reason, so the invoice and the XML state the same note. With `tax-exempt-small-biz: true`, the small business note of the invoice is the exemption reason. For the taxed categories (`S`, `Z`, `L`, `M`), `grounds` are printed on the invoice but left out of the XML, which does not allow them there. If the items of one category have different `grounds`, each of them is printed, and the XML joins them with `; ` into the one exemption reason (BT-120) of the category.

### Exemption Reason Code (BT-121)

Next to the text, the XML states the VAT exemption reason code of the CEF VATEX code list, from the `"basic-wl"` profile on: `VATEX-EU-AE` for a reverse charge, `VATEX-EU-IC` for an intra-community supply, `VATEX-EU-G` for an export, `VATEX-EU-O` for items not subject to VAT, and `VATEX-FR-FRANCHISE` for the small business scheme of France. The code of an exemption depends on its legal basis, so state it with `code`; without one, only the text is stated, which EN 16931 accepts (`BR-E-10`):

```typst
#item(
  [Physiotherapie],
  price: 80,
  tax: tax.exempt(
    grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
    code: "VATEX-EU-132-1C", // Art. 132 (1) (c) of the VAT Directive
  ),
)
```

The code must be one of the VATEX list the Factur-X and EN 16931 validators apply (`BR-CL-22`; the newer list of the KoSIT validator knows a few more, e.g. `VATEX-EU-144`, which Mustang rejects), in upper or lower case, and fit the category (`IP-TAX-02`): `VATEX-EU-AE`, `VATEX-EU-IC`, `VATEX-EU-G` and `VATEX-EU-O` belong to their categories, every other code to an exemption (`E`), and the taxed categories (`S`, `Z`, `L`, `M`) have none. An exemption with a code needs its `grounds` as well, which the printed invoice states (`IP-TAX-04`). EN 16931 states one code per VAT category and rate, so items of one group with different codes are stated with their grounds only (`IP-TAX-03`, a warning). Earlier versions stated no code at all.

## Document Level Allowances and Charges

Document level discounts and surcharges (BG-20, BG-21) belong to a VAT category as well. An absolute amount is split over the categories of the items (see [VAT categories of modifiers](../../api-reference/line-items/index.md#vat-categories-of-document-and-bundle-modifiers)); pin it to one with `tax`, e.g. `surcharge([Shipping], amount: 4.90, tax: tax.vat(19%))`.

## Small Business Exemption

With `tax-exempt-small-biz: true`, all items and pinned modifiers use the small business scheme of the locale's region. Its legal note is printed below the line items, and the XML states the same text as exemption reason (BT-120):

| Region | Category | Legal note (printed and BT-120)                                                                  |
| :----- | :------- | :----------------------------------------------------------------------------------------------- |
| DE     | `E`      | Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung gemäß § 19 Abs. 1 UStG.                   |
| AT     | `E`      | Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung gem. § 6 Abs. 1 Z 27 UStG.                |
| FR     | `E`      | TVA non applicable, art. 293 B du CGI.                                                           |
| ES     | `E`      | Exento de IVA según el régimen especial de franquicia para pequeñas empresas.                    |
| IT     | `O`      | Operazione in franchigia da IVA ai sensi dell'art. 1, commi da 54 a 89, della Legge n. 190/2014. |
| CH     | `O`      | Nicht MWST-pflichtig / Non soumis à la TVA / Non assoggettato all'IVA                            |

If the language of the invoice differs from the region (e.g. `locale.en-de`), a translated note comes first and the legal note follows in parentheses. The note is printed below the line items, as it is mandatory on the invoice (e.g. § 34a UStDV in Germany), also with `line-items(show-information: false)`, which hides only the information about the items (such as the tax rate or the unit they share).

- **Exempt (`E`), in Germany, Austria, France and Spain:** the scheme exempts the turnover of small businesses. In Germany, § 19 Abs. 1 UStG declares it tax exempt ("steuerfrei") since 2025 (Jahressteuergesetz 2024), and the invoice must note that the small business exemption applies (§ 34a UStDV). The Spanish note refers to the franchise of the EU small business scheme (Directive (EU) 2020/285) and cites no provision of Spanish law; where one applies, state it with an override (see below). An exempt invoice needs the seller's VAT identifier or tax number (BR-E-02): set `tax-nr` (e.g. the Steuernummer) or `vat-id` on the sender. Both are written to the XML, and the buyer's electronic address is derived from its VAT identifier as on any other invoice. A French micro-entrepreneur without an intra-community VAT number can state its SIREN as `tax-nr`, which is written as the seller's tax registration (BT-32).
- **Not subject to VAT (`O`), in Italy and Switzerland:** supplies under the Italian _regime forfettario_ are not subject to VAT, and Swiss businesses below the turnover threshold are not liable for VAT. As with `tax.outside-scope()`, the XML carries no VAT identifiers (BR-O-02), and the seller is identified by `tax-nr` or `id`.

:::warning Breaking change of the XML
Earlier versions wrote the small business exemption of every region as category `O` ("not subject to VAT") and left out the VAT identifiers. Invoices with `tax-exempt-small-biz: true` in the regions DE, AT, FR and ES are now written as category `E` and keep the VAT identifiers of seller and buyer, from which the electronic addresses (BT-34, BT-49) are derived, and the German note follows the wording of the amended § 19 UStG. A sender with neither `tax-nr` nor `vat-id` (only an `id`) is now reported as BR-E-02. German-language invoices of other regions (e.g. `locale.de-at`) no longer cite the German § 19 UStG in front of the region's note.
:::

To state another note or category, override the scheme of the region, e.g. `locale: locale.de-de.with(locale.custom.tax(small-enterprise-special-scheme: tax.exempt(grounds: "...")))`.

## Gross Prices

With `tax-mode: "inclusive"`, the invoice prints gross prices, while the XML states net amounts as EN 16931 requires. They are derived from what the invoice prints: the net amounts of the lines and of the allowances and charges of each VAT category are its printed gross amounts divided by 1 plus the rate, rounded to the currency so that they add up exactly to the taxable amount the invoice prints for the category (the cents the rounding lacks or exceeds go to the amounts that were rounded furthest the other way, so each differs from its exact net amount by less than a cent; a line of one cent may state 0.00 that way, an allowance or charge never does). The net unit price (BT-146) keeps at least 6 decimals, more for a large quantity (3 more than the integer digits of the quantity), so that the quantity times the price gives the net amount of the line within 0.02, as XRechnung requires (`PEPPOL-EN16931-R120`): for 1000 screws at 9.99 € including 19 % VAT, the XML states the net price 8.394958 and the net amount 8394.96.

In XRechnung, the same rule applies to net prices: a line total that is rounded more coarsely than its price can break it, e.g. 100.40 yen for a currency without decimals, or 1 × 0.325 € printed as 0.35 € with a `money` rounding of the locale to 0.05. `invoice-pro` checks every line and reports that as a warning, as KoSIT does.
