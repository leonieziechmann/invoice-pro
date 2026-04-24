---
sidebar_position: 4
---

# Tax API

The `tax` module provides a standardized way to define tax rates, exemption reasons, and specific tax categories. This module is built around the **UNTDID 5305** (Tax Category Code) standard, which is crucial for international e-invoicing and frameworks like ZUGFeRD.

While simple ratios (e.g., `19%`) can often be used directly on [items](./line-items#item), using the `tax` module is mandatory for 0% tax rates, exemptions, reverse charges, or when your region has multiple tax categories sharing the same percentage.

---

## Core Tax Functions

These are the most common tax categories, available directly from the main `tax` module.

:::info
The `grounds` parameter:
All tax functions accept an optional `grounds` parameter (a string). This is used to provide the legal justification for the tax application. **Providing a `grounds` text is highly recommended (and often legally required) for any 0% tax rate or exemption.**
:::

| Function                          | Code   | Description                                                                                              |
| :-------------------------------- | :----- | :------------------------------------------------------------------------------------------------------- |
| `vat(rate, grounds: none)`        | **S**  | **Standard Rate**: The default VAT/GST rate for your region (e.g., `tax.vat(19%)`).                      |
| `lower-rate(rate, grounds: none)` | **AA** | **Lower Rate**: Used for reduced tax brackets like food or books.                                        |
| `exempt(grounds: none)`           | **E**  | **Exempt from Tax**: General tax exemption (always 0%).                                                  |
| `reverse-charge(grounds: none)`   | **AE** | **VAT Reverse Charge**: Tax liability is shifted to the recipient (always 0%).                           |
| `intra-community(grounds: none)`  | **K**  | **Intra-community Supply**: VAT exempt for EEA intra-community supply of goods and services (always 0%). |
| `export(grounds: none)`           | **G**  | **Free export item**: Tax not charged for exports outside the tax zone (always 0%).                      |
| `outside-scope(grounds: none)`    | **O**  | **Outside Scope**: Services that fall completely outside the scope of the tax system (always 0%).        |
| `zero(grounds: none)`             | **Z**  | **Zero Rated Goods**: Standard zero-rated items (always 0%).                                             |

**Example Usage:**

```typst
#import "@preview/invoice-pro:0.1.0": item, tax

item(
  name: "Consulting (B2B EU)",
  price: 1500.00,
  tax: tax.reverse-charge(grounds: "Tax liability of the recipient according to...")
)
```

---

## Special Tax Functions (`tax.special`)

For less common scenarios, industry-specific margin schemes, or specific regional taxes, the module provides a `special` submodule.

You can access these via `tax.special.<function-name>`.

### Margin Schemes

| Function                                  | Code  | Description                                           |
| :---------------------------------------- | :---- | :---------------------------------------------------- |
| `margin-travel(rate, grounds: none)`      | **D** | VAT margin scheme for travel agents.                  |
| `margin-second-hand(rate, grounds: none)` | **F** | VAT margin scheme for second-hand goods.              |
| `margin-art(rate, grounds: none)`         | **I** | VAT margin scheme for works of art.                   |
| `margin-antiques(rate, grounds: none)`    | **J** | VAT margin scheme for collector’s items and antiques. |

### Regional Taxes

| Function                              | Code  | Description                                                               |
| :------------------------------------ | :---- | :------------------------------------------------------------------------ |
| `canary-islands(rate, grounds: none)` | **L** | Canary Islands general indirect tax (IGIC).                               |
| `ceuta-melilla(rate, grounds: none)`  | **M** | Tax for production, services and importation in Ceuta and Melilla (IPSI). |

### Special Scenarios & Duties

| Function                                   | Code   | Description                              |
| :----------------------------------------- | :----- | :--------------------------------------- |
| `exempt-for-resale(grounds: none)`         | **AB** | Exempt for resale (always 0%).           |
| `vat-not-due(rate, grounds: none)`         | **AC** | Value Added Tax not now due for payment. |
| `mixed(rate, grounds: none)`               | **A**  | Mixed tax rate.                          |
| `transferred(rate, grounds: none)`         | **B**  | Transferred VAT.                         |
| `duty-paid(rate, grounds: none)`           | **C**  | Duty paid by supplier.                   |
| `higher-rate(rate, grounds: none)`         | **H**  | Higher tax rate.                         |
| `standard-additional(rate, grounds: none)` | **N**  | Standard rate additional VAT.            |

---

## Custom Tax Categories (`tax.new`)

If you encounter a specific requirement that is not covered by the standard library functions above, you can define a custom tax category using the internal `tax.new` function.

:::warning
Only use this if you know exactly which UNTDID 5305 tax category code your accounting software or e-invoicing standard expects.
:::

| Key        | Type            | Description                                                             |
| :--------- | :-------------- | :---------------------------------------------------------------------- |
| `rate`     | `ratio`         | The numeric tax rate (e.g., `19%` or `0%`).                             |
| `category` | `str`           | The official UN/CEFACT EDIFACT 5305 tax category code (e.g., "S", "Z"). |
| `label`    | `str`           | A human-readable identifier or label for the tax type.                  |
| `grounds`  | `str` \| `none` | The legal justification for this tax setting.                           |

**Example:**

```typst
#import "@preview/invoice-pro:0.1.0": tax

#let custom-tax = tax.new(
  rate: 0%,
  category: "E",
  label: "custom-exemption",
  grounds: "Exempt based on local regulation paragraph 42."
)
```
