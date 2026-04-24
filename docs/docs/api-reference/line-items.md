---
sidebar_position: 2
---

# Line Items API

This section details the functions used to build the core of your invoice: the line items. You can use these components to list services, group them into bundles, and apply modifiers like discounts or surcharges.

:::info
Many parameters (like `input-gross` and `tax`) are **cascading**. This means if you set them on the parent `line-items` container or a `bundle`, all child elements will automatically inherit those settings unless they are manually overridden at the item level.

**Resolution Order:** Item Level → Bundle Level → Line-Items Level → Document/Locale Default.
:::

---

## `line-items`

The root container that manages the context, column visibility, and overall calculations for all items, bundles, and modifiers inside it.

:::tip
By default, the `show-columns` parameter works automatically and tries to minimize the number of shown columns (e.g., hiding the tax column if all items share the exact same tax rate). You only need to provide a dictionary if you want to strictly override this behavior.
:::

| Key                | Type                                     | Description                                                                                                                                                                                                      |
| ------------------ | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `input-gross`      | `bool` \| `auto`                         | If `auto`, it matches the document's `tax-mode`. If manually set, it specifies if prices of items are entered as net or gross, triggering forward or backward tax calculations.                                  |
| `tax`              | `ratio` \| `dictionary` \| `auto`        | If `auto`, inherited from the locale default. If a `ratio` (e.g., `19%`), the tax-bracket/code is inferred by the locale system. If a `dictionary`, it should be set by the `tax` module (e.g., `tax.vat(19%)`). |
| `tax-mode`         | `"exclusive"` \| `"inclusive"` \| `auto` | Sets the tax mode. If `auto`, it matches the [document root's `tax-mode`](./invoice). _It is highly recommended not to change this value here unless absolutely necessary._                                      |
| `show-columns`     | `dictionary` \| `auto`                   | Overrides the default automatic column visibility. Used to manually toggle columns like `pos`, `quantity`, `unit-price`, etc.                                                                                    |
| `show-total`       | `bool` \| `auto`                         | Shows the total summary block of the line items. Defaults to `true`.                                                                                                                                             |
| `show-information` | `bool` \| `auto`                         | Shows annotations after the total about the content of the line-items (e.g., tax exemptions). Defaults to `true`.                                                                                                |
| `body`             | `content`                                | The main content block containing your `item`, `bundle`, or `modifier` calls.                                                                                                                                    |

### `show-columns` Dictionary

When overriding the automatic column visibility in `line-items`, you can pass a dictionary to the `show-columns` parameter. Each key toggles a specific column in the invoice table.

| Key           | Type             | Description                                                                 |
| ------------- | ---------------- | --------------------------------------------------------------------------- |
| `pos`         | `bool` \| `auto` | The position or index number of the item in the list.                       |
| `description` | `bool` \| `auto` | The detailed description text displayed below the item name.                |
| `quantity`    | `bool` \| `auto` | The amount being billed for the line item.                                  |
| `unit`        | `bool` \| `auto` | The unit of measurement (e.g., "h", "pcs").                                 |
| `unit-price`  | `bool` \| `auto` | The price per single unit of the item.                                      |
| `tax-rate`    | `bool` \| `auto` | The tax percentage applied to the specific item.                            |
| `total-price` | `bool` \| `auto` | The calculated total price for the line item (quantity &times; unit-price). |

---

## `item`

Represents a single billable product or service line within your invoice.

:::note
_Price vs. Total:_
You must provide either a `price` (unit price) **or** a `total` (fixed line total), but not both. The system will automatically perform forward/backward calculations based on your `input-gross` settings.
:::

| Key             | Type                                      | Description                                                                                                                                          |
| --------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`          | `str` \| `content`                        | The primary title of the item.                                                                                                                       |
| `description`   | `str` \| `content` \| `auto` \| `none`    | Detailed text appearing below the name.                                                                                                              |
| `quantity`      | `number` \| `auto`                        | The numeric amount being billed (defaults to 1).                                                                                                     |
| `base-quantity` | `number` \| `auto`                        | The reference quantity for the price (e.g., pricing per 100g).                                                                                       |
| `unit`          | `str` \| `content` \| `auto` \| `none`    | The unit of measurement (e.g., `"h"`, `"pcs"`).                                                                                                      |
| `date`          | `datetime` \| `array` \| `auto` \| `none` | When the service was provided. Use a single `datetime` or a range array `(datetime, datetime)`.                                                      |
| `price`         | `number` \| `auto`                        | The price per unit.                                                                                                                                  |
| `total`         | `number` \| `auto`                        | The fixed total price for the line item.                                                                                                             |
| `item-id`       | `str` \| `dictionary` \| `auto` \| `none` | If a `str`, it is treated as a standard item ID. Can also be a dictionary: `(seller: "id", buyer: "id", standard: "id")`. Not all keys are required. |
| `input-gross`   | `bool` \| `auto`                          | Overrides the parent `input-gross` setting specifically for this item.                                                                               |
| `tax`           | `ratio` \| `dictionary` \| `auto`         | Overrides the parent `tax` setting specifically for this item.                                                                                       |

:::warning
_Future ZUGFeRD Updates:_
The behavior of the `unit` parameter will undergo changes in future versions to ensure full compatibility with the ZUGFeRD e-invoicing standard.
:::

### The `tax` Parameter

While items generally inherit their tax settings from the parent `line-items` container or the document's locale, you can explicitly override the `tax` parameter on an individual `item` or `bundle`.

You can define the tax in two ways:

1. **Simple Ratio:** Provide a percentage directly (e.g., `tax: 19%`). The system will attempt to automatically infer the correct standard tax category based on your [locale](./locale).
2. **The `tax` Module:** For specialized scenarios—such as reverse charge, tax exemptions, or if your region has multiple tax categories with the same percentage—you must use functions from the `tax` module (e.g., `tax.vat(19%)`, `tax.reverse-charge()`).

:::info
Passing a simple ratio only works safely if the tax rate is **unambiguous** within your selected locale region. If the system cannot confidently guess the tax category, you will need to use the `tax` module.
:::

:::tip
For a complete list of standardized tax functions, margin schemes, and how to create custom tax categories, please read the [Tax Module API Reference](./tax).
:::

---

## `bundle`

Groups multiple items together as a virtual single item while automatically aggregating their totals and dates.

| Key             | Type                                      | Description                                                                                                        |
| --------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `name`          | `str` \| `content`                        | The name of the bundle.                                                                                            |
| `description`   | `str` \| `content` \| `auto` \| `none`    | If set to `auto`, it automatically generates a comma-separated list of all child item names.                       |
| `quantity`      | `number` \| `auto`                        | The quantity of the bundle itself.                                                                                 |
| `base-quantity` | `number` \| `auto`                        | The reference quantity for the price (e.g., pricing per 100g).                                                     |
| `unit`          | `str` \| `content` \| `auto` \| `none`    | The unit of measurement for the bundle.                                                                            |
| `date`          | `datetime` \| `array` \| `auto` \| `none` | If set to `auto`, calculates the date range based on the earliest and latest dates of the items inside the bundle. |
| `input-gross`   | `bool` \| `auto`                          | Overrides the parent `input-gross` setting specifically for children.                                              |
| `tax`           | `ratio` \| `dictionary` \| `auto`         | Overrides the parent `tax` setting specifically for children.                                                      |
| `body`          | `content`                                 | The nested items, modifiers, or sub-bundles belonging to this group.                                               |

### Mixed Tax Brackets

One of the most powerful features of the `bundle` component is its ability to handle mixed tax brackets automatically.

If you place items with varying tax rates (e.g., mixing 19% and 7% items) or different tax codes into a single bundle, the system will seamlessly manage the complexity. In the background, it splits and creates multiple instances of the bundle grouped by their respective tax brackets.

:::info
**Why this matters:**
This automatic splitting ensures that your invoice remains legally compliant. Total amounts, sub-totals, and any modifiers applied to the bundle (such as a 10% bundle-wide discount) are proportionally distributed and calculated correctly across the different tax rates without any manual intervention required from you.
:::

---

## Adjustments: `modifier`, `discount`, & `surcharge`

Modifiers allow you to apply relative or absolute adjustments to an item, a bundle, or the entire invoice.

:::info
Helper Functions `discount(..)` and `surcharge(..)` use the exact same parameters as `modifier(..)`. They are convenient semantic wrappers that automatically treat your `amount` as a negative reduction (`discount`) or a positive addition (`surcharge`).
:::

| Key           | Type                                   | Description                                                                                                                                        |
| ------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`        | `str` \| `content`                     | The label for the adjustment (e.g., "Student Discount", "Express Shipping").                                                                       |
| `amount`      | `ratio` \| `decimal-like` \| `auto`    | If a `ratio` (e.g., `-10%`), it acts as a relative percentage. If a `decimal-like` number (e.g., `15.00`), it acts as an absolute monetary amount. |
| `input-gross` | `bool` \| `auto`                       | For absolute monetary amounts, this defines if the entered value already includes tax. Follows standard cascading logic if set to `auto`.          |
| `description` | `str` \| `content` \| `auto` \| `none` | Extra context or conditions for the modifier.                                                                                                      |

### `input-gross`

For absolute monetary amounts (e.g., `10.00` instead of `10%`), the `input-gross` parameter is critical because it determines at which level the adjustment is "anchored."

| Value   | Behavior             | Result                                                                                              |
| :------ | :------------------- | :-------------------------------------------------------------------------------------------------- |
| `true`  | **Gross Adjustment** | The final **gross amount** (Total including tax) will be exactly the specified amount lower/higher. |
| `false` | **Net Adjustment**   | The **net amount** (Total excluding tax) will be exactly the specified amount lower/higher.         |
| `auto`  | **Inherited**        | Matches the parent container or the document's `tax-mode`.                                          |

#### Examples

- **Gross Discount:** `discount(input-gross: true, amount: 10)`
  The total amount the customer has to pay (Grand Total) will be exactly 10.00 units less.
- **Net Discount:** `discount(input-gross: false, amount: 10)`
  The subtotal before taxes will be exactly 10.00 units less. The final gross impact will depend on the tax rate.

:::warning
If your modifier's `input-gross` setting does **not** match the global `tax-mode` of the invoice (e.g., applying a gross discount on a net-based invoice), the system must perform forward or backward tax calculations.

Because the system balances these adjustments across all relevant tax brackets to remain legally compliant, you may occasionally see a **1-cent difference** in the final total due to rounding.
:::
