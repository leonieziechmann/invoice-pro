---
sidebar_position: 3
---

# Components API

This section details the standalone components you can use in your invoice, such as payment instructions, bank details, and signature blocks.

:::info
**Looking for items and modifiers?**
If you are looking for the core invoicing functions like `item`, `bundle`, `modifier`, `discount`, or `prepayment`, please check the [Line Items API Reference](./line-items).
:::

---

## `bank-details`

Defines and renders the bank account information for payments. It can optionally generate a payment QR code (like an EPC-QR code) so customers can pay quickly using their banking app.

:::tip
If you leave `payment-amount` set to `auto`, the component will automatically fetch the final amount to be paid (the gross total, or the remaining amount due if prepayments are present) and use it for the display and the QR code!
:::

:::note
The `bic` parameter is optional. If not provided or set to `none`, the BIC row will not be displayed in the bank details block, and the EPC-QR code will be generated without a BIC.
:::

:::info Payment reference
The payment reference is resolved in one order: the `reference` or `text` argument of `bank-details`, then the invoice's `payment-reference`, then the `invoice-nr`. The same value is printed, encoded in the EPC-QR code and written to the ZUGFeRD XML (BT-83), and it is also what `references.payment-reference` and `#info.payment-reference` show.

In the EPC-QR code, `reference` and the `invoice-nr` fill the structured reference field (max. 35 characters), while `text` and the invoice's `payment-reference` fill the unstructured remittance text field (max. 140 characters).
:::

:::info IBAN and EPC-QR code
The IBAN is checked (structure and check digits) whether or not a QR code is shown. It is printed in groups of four, and written to the EPC-QR code and the ZUGFeRD XML without spaces and in upper case, so `"de89 3704 0044 0532 0130 00"` is fine. A missing or invalid IBAN stops the compilation with a message naming it. With an e-invoice and `zugferd-errors: "report"`, it is marked in the bank details instead, the EPC-QR code is replaced by a placeholder, and the report lists it as an error, so the XML is attached as a draft (see [Validation and Error Reporting](../e-invoicing.md#validation-and-error-reporting)).

The EPC-QR code is only generated when it is shown and the invoice currency is EUR. It carries the plain text of the account holder, so a styled or multi-line sender name works as well; with `name: auto`, the account holder is the sender name on one line, as in the ZUGFeRD XML. The QR code allows at most 70 bytes for the account holder name (non-ASCII characters such as umlauts count twice), 35 for a structured `reference` and 140 for `text`, and a BIC of 8 or 11 letters and digits. If a value does not fit, the compilation stops and says which one (with an e-invoice and `zugferd-errors: "report"`, the placeholder of the QR code names it instead): set a shorter account name with `name`, or hide the QR code with `qr-code: (display: false)`.

`bank-details` makes these checks itself, before the theme draws the bank details. A custom theme layout that draws no QR code therefore needs `qr-code: (display: false)` as well.

The EPC-QR code asks the buyer to transfer the amount. By default, it is therefore only shown when the invoice is paid by credit transfer: not next to a [`direct-debit`](#direct-debit) or a [`card-payment`](#card-payment), and not on a [`paid`](#paid) invoice. `qr-code: (display: true)` shows it anyway.
:::

| Key                   | Type                         | Description                                                                                                                                                                                                                                                                                                                                                                                                      |
| --------------------- | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                | `auto` \| `none` \| `str`    | The name of the account holder. If set to `auto`, it defaults to the name of the invoice's `payee` (e.g. a factoring company that receives the payment), else the sender's name (on one line), or the recipient's on a credit note or a self-billed invoice, which the sender pays. The EPC-QR code names the account holder as the beneficiary. A name given here is the account name of the e-invoice (BT-85). |
| `bank`                | `none` \| `str`              | The name of the banking institution.                                                                                                                                                                                                                                                                                                                                                                             |
| `iban`                | `none` \| `str`              | The International Bank Account Number (IBAN), with or without spaces. Required; it is checked for its structure and check digits.                                                                                                                                                                                                                                                                                |
| `bic`                 | `none` \| `str`              | The Bank Identifier Code (BIC/SWIFT). If omitted or `none`, the BIC field is hidden in the bank details block and omitted from the EPC-QR code.                                                                                                                                                                                                                                                                  |
| `reference`           | `auto` \| `none` \| `str`    | The structured payment reference to be used by the customer. If `auto`, it falls back to the invoice's `payment-reference`, then to the `invoice-nr`. `none` omits the reference.                                                                                                                                                                                                                                |
| `text`                | `none` \| `str`              | Unstructured payment reference text, as an alternative to `reference` (mutually exclusive).                                                                                                                                                                                                                                                                                                                      |
| `payment-amount`      | `auto` \| `none` \| `number` | The specific amount to be paid. If `auto`, it uses the remaining amount due (or full gross total if no prepayments are present).                                                                                                                                                                                                                                                                                 |
| `show-reference`      | `bool`                       | Whether to display the reference field in the output. Defaults to `true`.                                                                                                                                                                                                                                                                                                                                        |
| `account-holder-text` | `auto`                       | Optional custom text to label the account holder field.                                                                                                                                                                                                                                                                                                                                                          |
| `qr-code`             | `dictionary`                 | Configuration for a payment QR code (e.g., EPC-QR). Accepts `display` (bool, by default whether the buyer pays by credit transfer; `false` on a credit note or a self-billed invoice, which the sender pays) and `size` (length, defaults to `5em`).                                                                                                                                                             |

---

## `payment-goal`

Displays the payment deadline and terms for the invoice. You can specify a strict deadline date or a relative number of days, and cash discounts for an earlier payment.

On a credit note or a self-billed invoice (see [`document-type`](./invoice/index.md#document-type)), the sender pays the amount, so the sentence says that the sender transfers it (`payment.text-credit` of the [locale](./locale/base.md)), e.g. "Den Betrag in Höhe von … überweisen wir innerhalb von 14 Tagen auf das unten angegebene Konto." A cash discount (`discount`) is not supported on these documents and stops the compilation.

:::note
You can provide either `days` or a specific `date`. If you provide `days`, the system calculates the deadline relative to the main [invoice date](./invoice).
:::

:::info Payment means
The sentence follows the payment means of the invoice: it asks for a transfer to the account of the [`bank-details`](#bank-details), announces a [`direct-debit`](#direct-debit), or says that the amount is charged to the card of a [`card-payment`](#card-payment). An invoice that is [`paid`](#paid) has no payment goal.
:::

| Key        | Type                                       | Description                                                                                                                                                            |
| ---------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `days`     | `none` \| `int`                            | The number of days allowed for payment, calculated from the invoice date.                                                                                              |
| `date`     | `none` \| `datetime` \| `str` \| `content` | A specific fixed date for the payment deadline.                                                                                                                        |
| `discount` | `none` \| `dictionary` \| `array`          | A cash discount (Skonto) for a payment within fewer days: `(days: 14, percent: 2%)`, optionally with `basis`, the amount it applies to. An array states several steps. |

### Examples

The visual output of the component changes based on the parameters provided. Below are the standard English translations for the output strings:

#### 1. Default (Prompt Payment)

If no parameters are provided, the system requests prompt payment.

```typst
#payment-goal()
```

> Please transfer the total amount of **123.45€** upon receipt to the account listed below.

#### 2. Relative Deadline

Using the `days` parameter to specify a timeframe.

```typst
#payment-goal(days: 14)
```

> Please transfer the total amount of **123.45€** within 14 days to the account listed below.

#### 3. Fixed Deadline

Using the `date` parameter to specify an absolute deadline.

```typst
#payment-goal(date: datetime(day: 1, month: 1, year: 2026))
```

> Please transfer the total amount of **123.45€** no later than 01.01.2026 to the account listed below.

#### 4. Cash Discount (Skonto)

Using the `discount` parameter to grant a discount for an earlier payment. Each step is printed after the payment sentence:

```typst
#payment-goal(
  days: 30,
  discount: (
    (days: 7, percent: 3%),
    (days: 14, percent: 2%, basis: 100),
  ),
)
```

> Please transfer the total amount of **123.45€** within 30 days to the account listed below. For payment within 7 days, a cash discount of 3% is granted. For payment within 14 days, a cash discount of 2% on 100.00€ is granted.

`days` is a whole number of days, and `percent` a percentage between 0% and 100% with at most two decimals, as the e-invoice states it. A cash discount changes no amount of the invoice: the buyer deducts it when paying in time. In an e-invoice, the discounts are written into the payment terms (BT-20), in XRechnung in the syntax of the KoSIT (e.g. `#SKONTO#TAGE=7#PROZENT=3.00#`, see [Cash Discount](../e-invoicing.md#cash-discount-skonto)).

---

## `direct-debit`

Collects the amount of the invoice by SEPA direct debit from the account of the buyer. It prints the payment method, the mandate reference, your creditor identifier and the debited account, and the [`payment-goal`](#payment-goal) announces the direct debit instead of asking for a transfer. In an e-invoice, it is the payment means (BT-81 = 59, SEPA direct debit; 49 in another currency than euro) with the mandate reference (BT-89), the creditor identifier (BT-90) and the debited account (BT-91).

```typst
#payment-goal(days: 14)
#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE02 1203 0000 0000 2020 51",
)
```

> The total amount of **123.45€** will be collected from your account by direct debit within 14 days.
>
> Payment method: SEPA direct debit \
> Mandate reference: M-2026-017 \
> Creditor identifier: DE98ZZZ09999999999 \
> Your IBAN: DE02 1203 0000 0000 2020 51

| Key           | Type                         | Description                                                                                                                   |
| :------------ | :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------- |
| `mandate`     | `str` \| `content`           | The reference of the SEPA direct debit mandate the buyer signed. Required.                                                    |
| `creditor-id` | `str` \| `content`           | Your SEPA creditor identifier, with or without spaces. Required. For an invoice in euro, its check digits are checked.        |
| `debtor-iban` | `none` \| `str` \| `content` | The IBAN of the buyer's account that is debited, with or without spaces. XRechnung requires it. Its check digits are checked. |

An invalid creditor identifier or IBAN stops the compilation with a message naming it, like an invalid IBAN of [`bank-details`](#bank-details). An invoice has one payment means: `direct-debit` next to `bank-details` or `card-payment` is an error of the e-invoice (see [Payment Means](../e-invoicing.md#payment-means)), and the EPC-QR code of `bank-details` is hidden by default. On a credit note or a self-billed invoice, whose sender pays the amount, `direct-debit` stops the compilation.

---

## `card-payment`

States that the amount of the invoice is paid with, or charged to, a payment card. It prints the kind of card, the last digits of the card number and the card holder, and the [`payment-goal`](#payment-goal) says that the amount is charged to the card. In an e-invoice, it is the payment means (BT-81 = 54 for a credit card, 55 for a debit card, 48 for a card of either kind) with the last digits of the card number (BT-87) and the card holder (BT-88); the profiles below EN 16931 state only the payment means code.

```typst
#payment-goal()
#card-payment(last4: "4242", holder: "Claire Martin", kind: "credit")
```

> The total amount of **123.45€** will be charged to your card upon receipt.
>
> Payment method: Credit card \
> Card number: \*\*\*\* 4242 \
> Cardholder: Claire Martin

| Key      | Type                              | Description                                                                                                                          |
| :------- | :-------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------- |
| `last4`  | `str` \| `content`                | The last 4 digits of the card number (up to 6 are accepted). Required. Never give the full card number: an invoice must not show it. |
| `holder` | `none` \| `str` \| `content`      | The name of the card holder.                                                                                                         |
| `kind`   | `auto` \| `"credit"` \| `"debit"` | `"credit"` for a credit card, `"debit"` for a debit card, or `auto` (default) for a card of either kind.                             |

On a credit note or a self-billed invoice, whose sender pays the amount, `card-payment` stops the compilation.

---

## `paid`

States that the invoice is paid already, e.g. in cash or by card at the counter. It prints that the amount was paid, and how, and that nothing is due. An invoice that is paid has no [`payment-goal`](#payment-goal) and no payment terms: `paid` together with a `payment-goal` or with a text as `due-date` of the invoice (e.g. `due-date: "sofort"`) stops the compilation, while a `datetime` as `due-date` is the date the payment was due. In an e-invoice, the total is the paid amount (BT-113), nothing is due (BT-115), the payment means is the one it was paid with (BT-81), and the printed sentence is the payment terms (BT-20).

```typst
#paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
```

> The total amount of **123.45€** was paid on 01.09.2026. \
> Payment method: Cash \
> Amount Due: 0.00€

| Key      | Type                                       | Description                                                                                                                                                                                                                                                                                                                                    |
| :------- | :----------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `method` | `auto` \| `str` \| `dictionary`            | How the invoice was paid: `"cash"`, `"cheque"`, `"online"` (an online payment service), `"card"`, `"transfer"` or `"direct-debit"`, or another payment means code of UNTDID 4461 with its printed name, e.g. `(code: "97", name: [Clearing])`. `auto` (default) names no method: the payment means of the invoice is the one it was paid with. |
| `date`   | `none` \| `datetime` \| `str` \| `content` | The date of the payment.                                                                                                                                                                                                                                                                                                                       |

A payment by card, direct debit or transfer adds its details with [`card-payment`](#card-payment), [`direct-debit`](#direct-debit) or [`bank-details`](#bank-details), which XRechnung requires; the EPC-QR code of `bank-details` is hidden by default on a paid invoice:

```typst
#paid(method: "card")
#card-payment(last4: "4242", kind: "credit")
```

A payment means code of its own (`(code: .., name: ..)`) of a kind that one of these components states as well must be the code of the component, as an invoice states one payment means code (BT-81): `paid(method: (code: "54", name: [Visa]))` next to `card-payment(kind: "credit")` (54) prints its name next to the card details, while next to `card-payment()`, which states a card of any kind (48), it stops the compilation.

With prepayments, the sentence states the remaining amount that was paid ("The amount due of ... has been paid."). On a credit note or a self-billed invoice, the sender pays the amount to the recipient, so the sentence says so ("We paid the amount of ... to you on ...", `paid-credit` of the [language strings](./locale/base.md#payment-means)), and the e-invoice states it as payment terms (BT-20).

---

## `signature`

Renders a signature block for the sender. This is typically placed at the very bottom of the document and can include a digital image of a handwritten signature.

| Key         | Type                         | Description                                                                                              |
| ----------- | ---------------------------- | -------------------------------------------------------------------------------------------------------- |
| `name`      | `auto` \| `str` \| `content` | The name to display under the signature line. If `auto`, it automatically defaults to the sender's name. |
| `signature` | `none` \| `content`          | The signature content (e.g., an image of a handwritten signature using Typst's `image()` function).      |

---

## `apply`

The `apply` function is a powerful scoping tool inherited from the underlying `loom` engine. It allows you to inject or override cascading parameters (like tax rates or gross/net settings) for a specific block of items without grouping them into a visible `bundle` or `group`.

:::info
While a `bundle` aggregates items into a single grouped line item and a `group` organizes items under a visible section header with hierarchical numbering, `apply` is completely invisible; it simply changes the context for the items inside it while letting them appear as normal, separate line items.
:::

| Key           | Type      | Description                                                                                                                                                                                   |
| :------------ | :-------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `..overrides` | `any`     | Any named arguments you provide will be injected into the context. For standard components, you simply use the same parameter name as you would in the function (e.g., `tax`, `input-gross`). |
| `body`        | `content` | The block of items or components that should inherit these overridden settings.                                                                                                               |

### Example: Bulk Tax Application

If you have multiple items that share a specific tax rate (e.g., books with a reduced 7% tax rate), you can wrap them in an `apply` block instead of setting the `tax` parameter on every single item.

```typst
#import "@preview/invoice-pro:0.4.2": item, apply, tax

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
#import "@preview/invoice-pro:0.4.2": *

Thank you for your order #info.order-nr from #info.order-date.
Please settle the total of #info.total.gross by #info.due-date to IBAN #info.iban.

Our company #info.sender.name is registered under VAT ID #info.sender.vat-id.
Invoiced to #info.recipient.name in #info.recipient.city.
```

### Pre-bound Properties

| Field / Property                       | Description                                                                                                                                      |
| :------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- |
| `#info.invoice-nr`                     | Invoice number (`ctx.invoice-nr`)                                                                                                                |
| `#info.invoice-date` (or `#info.date`) | Formatted invoice issue date                                                                                                                     |
| `#info.due-date`                       | Calculated payment deadline date                                                                                                                 |
| `#info.customer-nr`                    | Customer / Client ID: the invoice's `customer-nr`, else the recipient's `customer-nr` or `id` (an identifier of the `id` module prints its `id`) |
| `#info.order-nr`                       | Purchase Order number: the invoice's `order-nr`, else the recipient's, as in the e-invoice (BT-13)                                               |
| `#info.order-date`                     | Purchase Order date                                                                                                                              |
| `#info.project`                        | Project name or code                                                                                                                             |
| `#info.contract-nr`                    | Contract reference: the invoice's `contract-nr`, else the recipient's, as in the e-invoice (BT-12)                                               |
| `#info.quote-nr`                       | Quotation number                                                                                                                                 |
| `#info.delivery-note-nr`               | Delivery note number: the invoice's `delivery-note-nr`, else the recipient's, as in the e-invoice (BT-16)                                        |
| `#info.preceding-invoice-nr`           | Preceding / original invoice number                                                                                                              |
| `#info.payment-reference`              | Payment reference (Verwendungszweck), resolved like [`bank-details`](#bank-details)                                                              |
| `#info.buyer-reference`                | Buyer reference / Leitweg-ID                                                                                                                     |
| `#info.subject`                        | Document subject line                                                                                                                            |
| `#info.iban`                           | Payment IBAN                                                                                                                                     |
| `#info.bic`                            | Bank Identifier Code (BIC)                                                                                                                       |

### Nested Dictionaries

- **Sender Details (`#info.sender.*`)**:
  - `#info.sender.name`, `#info.sender.tax-nr`, `#info.sender.vat-id`
  - `#info.sender.trading-name`, `#info.sender.legal-id`, `#info.sender.legal-info`
  - `#info.sender.address`, `#info.sender.city`, `#info.sender.country`
  - `#info.sender.email`, `#info.sender.phone`
- **Recipient Details (`#info.recipient.*`)**:
  - `#info.recipient.name`, `#info.recipient.tax-nr`, `#info.recipient.vat-id`
  - `#info.recipient.trading-name`, `#info.recipient.legal-id`
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
