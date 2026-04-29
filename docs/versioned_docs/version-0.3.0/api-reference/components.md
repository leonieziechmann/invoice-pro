---
sidebar_position: 3
---

# Components API

This section details the standalone components you can use in your invoice, such as payment instructions, bank details, and signature blocks.

:::info
**Looking for items and modifiers?**
If you are looking for the core invoicing functions like `item`, `bundle`, `modifier`, or `discount`, please check the [Line Items API Reference](./line-items).
:::

---

## `bank-details`

Defines and renders the bank account information for payments. It can optionally generate a payment QR code (like an EPC-QR code) so customers can pay quickly using their banking app.

:::tip
If you leave `payment-amount` set to `auto`, the component will automatically fetch the final gross total of the invoice and use it for the display and the QR code!
:::

| Key                   | Type                         | Description                                                                                                                    |
| --------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `name`                | `auto` \| `none` \| `str`    | The name of the account holder. If set to `auto`, it automatically defaults to the sender's name.                              |
| `bank`                | `none` \| `str`              | The name of the banking institution.                                                                                           |
| `iban`                | `none` \| `str`              | The International Bank Account Number (IBAN).                                                                                  |
| `bic`                 | `none` \| `str`              | The Bank Identifier Code (BIC/SWIFT).                                                                                          |
| `reference`           | `auto` \| `none` \| `str`    | The payment reference to be used by the customer.                                                                              |
| `payment-amount`      | `auto` \| `none` \| `number` | The specific amount to be paid. If `auto`, it uses the document's total gross amount.                                          |
| `show-reference`      | `bool`                       | Whether to display the reference field in the output. Defaults to `true`.                                                      |
| `account-holder-text` | `auto`                       | Optional custom text to label the account holder field.                                                                        |
| `qr-code`             | `dictionary`                 | Configuration for a payment QR code (e.g., EPC-QR). Accepts keys like `display` (bool) and `size` (length, defaults to `5em`). |

---

## `payment-goal`

Displays the payment deadline and terms for the invoice. You can specify a strict deadline date or a relative number of days.

:::note
You can provide either `days` or a specific `date`. If you provide `days`, the system calculates the deadline relative to the main [invoice date](./invoice).
:::

| Key    | Type                                       | Description                                                               |
| ------ | ------------------------------------------ | ------------------------------------------------------------------------- |
| `days` | `none` \| `int`                            | The number of days allowed for payment, calculated from the invoice date. |
| `date` | `none` \| `datetime` \| `str` \| `content` | A specific fixed date for the payment deadline.                           |

### Examples

The visual output of the component changes based on the parameters provided. Below are the standard English translations for the output strings:

#### 1. Default (Prompt Payment)

If no parameters are provided, the system requests prompt payment.

```typst
#payment-goal()
```

> Please transfer the total amount of **123.45€** promptly without deduction to the account mentioned below.

#### 2. Relative Deadline

Using the `days` parameter to specify a timeframe.

```typst
#payment-goal(days: 14)
```

> Please transfer the total amount of **123.45€** within 14 days without deduction to the account mentioned below.

#### 3. Fixed Deadline

Using the `date` parameter to specify an absolute deadline.

```typst
#payment-goal(date: datetime(day: 1, month: 1, year: 2026))
```

> Please transfer the total amount of **123.45€** by 01.01.2026 at the latest without deduction to the account mentioned below.

---

## `signature`

Renders a signature block for the sender. This is typically placed at the very bottom of the document and can include a digital image of a handwritten signature.

| Key         | Type                         | Description                                                                                              |
| ----------- | ---------------------------- | -------------------------------------------------------------------------------------------------------- |
| `name`      | `auto` \| `str` \| `content` | The name to display under the signature line. If `auto`, it automatically defaults to the sender's name. |
| `signature` | `none` \| `content`          | The signature content (e.g., an image of a handwritten signature using Typst's `image()` function).      |

---

## `apply`

The `apply` function is a powerful scoping tool inherited from the underlying `loom` engine. It allows you to inject or override cascading parameters (like tax rates or gross/net settings) for a specific block of items without grouping them into a visible `bundle`.

:::info
While a `bundle` also passes parameters down to its children, it functionally aggregates those items into a single grouped line item on the invoice. `apply`, on the other hand, is invisible; it simply changes the context for the items inside it while letting them appear as normal, separate line items.
:::

| Key           | Type      | Description                                                                                                                                                                                   |
| :------------ | :-------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `..overrides` | `any`     | Any named arguments you provide will be injected into the context. For standard components, you simply use the same parameter name as you would in the function (e.g., `tax`, `input-gross`). |
| `body`        | `content` | The block of items or components that should inherit these overridden settings.                                                                                                               |

### Example: Bulk Tax Application

If you have multiple items that share a specific tax rate (e.g., books with a reduced 7% tax rate), you can wrap them in an `apply` block instead of setting the `tax` parameter on every single item.

```typst
#import "@preview/invoice-pro:0.1.0": item, apply, tax

// ...
#apply(tax: tax.lower-rate(7%))[
  #item(
    name: [Textbook: "Modern Web Design"],
    price: 49.90,
    quantity: 2,
  )
  #item(
    name: [Textbook: "SEO for Beginners"],
    price: 29.90,
  )
]
// ...
```

:::warning
**Advanced Usage for Power Users:** Because `apply` interfaces directly with the internal state representation, power users can also use it to override deeper internal functions—such as temporarily changing the [`locale`](./locale), [`theme`](./theme), or formatting logic for a specific scope. However, this requires knowledge of the internal data structure and should be used with caution!
:::
