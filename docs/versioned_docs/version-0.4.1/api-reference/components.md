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

:::note
The `bic` parameter is optional. If not provided or set to `none`, the BIC row will not be displayed in the bank details block, and the EPC-QR code will be generated without a BIC.
:::

| Key                   | Type                         | Description                                                                                                                                     |
| --------------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                | `auto` \| `none` \| `str`    | The name of the account holder. If set to `auto`, it automatically defaults to the sender's name.                                               |
| `bank`                | `none` \| `str`              | The name of the banking institution.                                                                                                            |
| `iban`                | `none` \| `str`              | The International Bank Account Number (IBAN).                                                                                                   |
| `bic`                 | `none` \| `str`              | The Bank Identifier Code (BIC/SWIFT). If omitted or `none`, the BIC field is hidden in the bank details block and omitted from the EPC-QR code. |
| `reference`           | `auto` \| `none` \| `str`    | The payment reference to be used by the customer.                                                                                               |
| `payment-amount`      | `auto` \| `none` \| `number` | The specific amount to be paid. If `auto`, it uses the document's total gross amount.                                                           |
| `show-reference`      | `bool`                       | Whether to display the reference field in the output. Defaults to `true`.                                                                       |
| `account-holder-text` | `auto`                       | Optional custom text to label the account holder field.                                                                                         |
| `qr-code`             | `dictionary`                 | Configuration for a payment QR code (e.g., EPC-QR). Accepts keys like `display` (bool) and `size` (length, defaults to `5em`).                  |

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
#import "@preview/invoice-pro:0.4.1": item, apply, tax

// ...
#apply(tax: tax.vat(7%))[
  #item(
    [Textbook: "Modern Web Design"],
    price: 49.90,
    quantity: 2,
  )
  #item(
    [Textbook: "SEO for Beginners"],
    price: 29.90,
  )
]
// ...
```

:::warning
**Advanced Usage for Power Users:** Because `apply` interfaces directly with the internal state representation, power users can also use it to override deeper internal functions—such as temporarily changing the [`locale`](./locale), [`theme`](./theme), or formatting logic for a specific scope. However, this requires knowledge of the internal data structure and should be used with caution!
:::

---

## `info` Module

The `info` module provides a suite of draw-only motifs and pre-configured accessors to seamlessly embed dynamic invoice context values anywhere in your body text.

### Usage in Invoice Text

```typst
#import "@preview/invoice-pro:0.4.1": *

Thank you for your order #info.order-nr from #info.order-date.
Please settle the total of #info.total.gross by #info.due-date to IBAN #info.iban.

Our company #info.sender.name is registered under VAT ID #info.sender.vat-id.
Invoiced to #info.recipient.name in #info.recipient.city.
```

### Pre-bound Properties

| Field / Property                       | Description                         |
| :------------------------------------- | :---------------------------------- |
| `#info.invoice-nr`                     | Invoice number (`ctx.invoice-nr`)   |
| `#info.invoice-date` (or `#info.date`) | Formatted invoice issue date        |
| `#info.due-date`                       | Calculated payment deadline date    |
| `#info.customer-nr`                    | Customer / Client ID                |
| `#info.order-nr`                       | Purchase Order number               |
| `#info.order-date`                     | Purchase Order date                 |
| `#info.project`                        | Project name or code                |
| `#info.contract-nr`                    | Contract reference                  |
| `#info.quote-nr`                       | Quotation number                    |
| `#info.delivery-note-nr`               | Delivery note number                |
| `#info.preceding-invoice-nr`           | Preceding / original invoice number |
| `#info.payment-reference`              | Payment reference string            |
| `#info.buyer-reference`                | Buyer reference / Leitweg-ID        |
| `#info.subject`                        | Document subject line               |
| `#info.iban`                           | Payment IBAN                        |
| `#info.bic`                            | Bank Identifier Code (BIC)          |

### Nested Dictionaries

- **Sender Details (`#info.sender.*`)**:
  - `#info.sender.name`, `#info.sender.tax-nr`, `#info.sender.vat-id`
  - `#info.sender.address`, `#info.sender.city`, `#info.sender.country`
  - `#info.sender.email`, `#info.sender.phone`
- **Recipient Details (`#info.recipient.*`)**:
  - `#info.recipient.name`, `#info.recipient.tax-nr`, `#info.recipient.vat-id`
  - `#info.recipient.address`, `#info.recipient.city`, `#info.recipient.country`
  - `#info.recipient.buyer-reference`, `#info.recipient.customer-nr`
- **Totals (`#info.total.*`)**:
  - `#info.total.gross`: Formatted total gross amount (e.g. `1.190,00 €`)
  - `#info.total.net`: Formatted total net amount (e.g. `1.000,00 €`)

### Dynamic Path Queries (`#info.dynamic` / `#info.get`)

For any nested or custom path not covered by standard properties:

```typst
#info.dynamic("locale", "region", "code")
#info.dynamic("sender", "extra", default: "N/A")
#info.dynamic("invoice-date", format: d => [Year #d.year()])
#info.dynamic(ctx => [Issuer country code: #upper(ctx.sender.country.code)])
```

| Parameter | Type                           | Description                                                                                      |
| :-------- | :----------------------------- | :----------------------------------------------------------------------------------------------- |
| `..path`  | `str` \| `array` \| `function` | Path segments in `ctx` (e.g. `"locale", "region", "code"`), or a query closure `ctx => content`. |
| `default` | `none` \| `any`                | Fallback content if the path evaluates to `none`.                                                |
| `format`  | `auto` \| `function`           | Custom formatter `val => content`, or `auto` for context-aware formatting (e.g. dates).          |
