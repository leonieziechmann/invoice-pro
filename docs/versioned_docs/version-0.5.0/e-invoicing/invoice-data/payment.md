---
sidebar_position: 4
---

# Payment

The payment details of an e-invoice come from the components that print them: the payment goal, the bank details, a direct debit, a card payment or a paid invoice. So the printed invoice and its XML always state the same payment.

## Payment Terms and Instructions

- **Due Date or Payment Terms (BT-9 / BT-20):** As long as an amount is due, the invoice must state when to pay (BR-CO-25). Add a [`payment-goal`](../../api-reference/components.md#payment-goal) (with `days` or a `date`) or set `due-date` on the invoice. A textual `date` or `due-date` (e.g. `[upon receipt]`) is written as payment terms, with its line breaks. An invoice that is [paid already](#paid-invoices) has nothing due and needs neither.
- **Payment Instructions (BG-16):** The components that say how the buyer pays are the payment means of the e-invoice (see below). IBAN and BIC are written without spaces and in upper case; they are the same values the bank details print and the EPC-QR code carries.

## Payment Means

Each payment means has a component that prints it and states it in the e-invoice, so the printed invoice and the XML always say the same. The payment goal prints the sentence of the payment means: it asks for a transfer only when the buyer pays by credit transfer.

| Component                                                        | Payment means code (BT-81)                                       | Written details                                                                                                  |
| :--------------------------------------------------------------- | :--------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| [`bank-details`](../../api-reference/components.md#bank-details) | `58` SEPA credit transfer (`30` in another currency than euro)   | IBAN (BT-84), account name (BT-85, only a `name` given to `bank-details`), BIC (BT-86)                           |
| [`direct-debit`](../../api-reference/components.md#direct-debit) | `59` SEPA direct debit (`49` in another currency than euro)      | Mandate reference (BT-89), creditor identifier (BT-90), debited account (BT-91)                                  |
| [`card-payment`](../../api-reference/components.md#card-payment) | `54` credit card, `55` debit card, `48` bank card (`kind: auto`) | Last digits of the card number (BT-87), card holder (BT-88)                                                      |
| [`paid`](../../api-reference/components.md#paid)                 | The code of its `method`, e.g. `10` for cash                     | Paid amount (BT-113) equal to the total, nothing due (BT-115), and the printed sentence as payment terms (BT-20) |

- **One payment means:** An invoice states one payment means (BT-81), so that the buyer knows how to pay and does not pay twice. A direct debit next to bank details is an error in XRechnung (`BR-DE-23-b`), as is a direct debit next to a payment card (`BR-DE-24-b`); the other combinations are errors of the newer EN 16931 Schematron of KoSIT in `"en16931"` and `"xrechnung"` (`CII-SR-467`, different payment means codes), and of `invoice-pro` in `"basic-wl"` and `"basic"` (`IP-PAY-03`), whose validation accepts them. To show your bank account for information only, print it as text. Several `bank-details` are several accounts of one credit transfer, and each of them is written.
- **EPC-QR code:** The QR code of the bank details asks the buyer to transfer the amount. It is therefore only shown by default when the invoice is paid by credit transfer: not next to a `direct-debit` or a `card-payment`, and not on a `paid` invoice. `qr-code: (display: true)` shows it anyway.
- **XRechnung:** An XRechnung requires payment instructions (`BR-DE-1`) and the details of its payment means: the IBAN of a credit transfer (`BR-DE-23-a`), the payment card of a card payment (`BR-DE-24-a`), and for a direct debit the mandate reference (`PEPPOL-EN16931-R061`), the creditor identifier (`BR-DE-30`) and the debited account (`BR-DE-31`). The IBANs must be valid (`BR-DE-19`, `BR-DE-20`); `invoice-pro` checks the check digits of the creditor identifier as well (`IP-PAY-02`). XRechnung only warns about an invalid IBAN and about a missing mandate reference, and the KoSIT validator accepts such an invoice, but other validators, such as Mustang, reject it, and the amount could not be paid or collected. `invoice-pro` therefore reports these rules as errors.
- **Profiles:** BASIC WL and BASIC state a direct debit, but neither the account name nor the payment card, and MINIMUM states no payment means at all, only the amount due. What a profile cannot state is still printed, and the report lists it as the warning `IP-PROFILE-01`.

## Direct Debit

A SEPA direct debit needs the mandate the buyer signed and your creditor identifier; XRechnung requires the IBAN of the debited account as well. The payment goal then announces the debit instead of asking for a transfer:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  locale: locale.en-de,
  zugferd: "xrechnung",
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@consultinggroup.de",
    ),
  ),
  recipient: (
    name: "Acme Corp",
    address: "Industrial Road 1",
    city: (name: "Stuttgart", post-code: "70173"),
    country: country.de,
    email: "invoices@acme.example",
    buyer-reference: "04011000-12345-67",
  ),
  invoice-nr: "INV-2026-104",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Maintenance contract, September], price: 250)
]

// "The total amount of 297,50 € will be collected from your account by
// direct debit within 14 days."
#payment-goal(days: 14)

#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE02 1203 0000 0000 2020 51",
)
```

## Paid Invoices

An invoice that is paid already, e.g. in cash or by card at the counter, uses [`paid`](../../api-reference/components.md#paid) instead of a payment goal: it prints that the amount was paid, and how, and that nothing is due. The e-invoice states the total as paid amount (BT-113), nothing due (BT-115) and the payment means it was paid with. `method` is one of `"cash"` (10), `"cheque"` (20), `"online"` (68), `"card"` (48, or the code of the `card-payment`), `"transfer"` (58, or 30 in another currency than euro) and `"direct-debit"` (59, or 49), or another code of UNTDID 4461 with its printed name, e.g. `(code: "97", name: [Clearing])`.

```typst
#paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
```

A card payment or a direct debit adds its details with its own component. XRechnung requires them: the payment card for `"card"` (`BR-DE-24-a`), the direct debit for `"direct-debit"` (`BR-DE-25-a`, in another currency than euro its mandate reference, `PEPPOL-EN16931-R061`) and the bank details for `"transfer"` (`BR-DE-23-a`). The other profiles with payment means ask for the bank details of `"transfer"` as well, as EN 16931 requires the account of a credit transfer: `"en16931"` as `CII-SR-470` (a rule of the newer EN 16931 Schematron of KoSIT), `"basic-wl"` and `"basic"` as `IP-PAY-04`, since the version of `BR-61` that their validation applies tests another account:

```typst
#paid(method: "card")
#card-payment(last4: "4242", holder: "Claire Martin", kind: "credit")
```

With prepayments, the printed sentence states the remaining amount that was paid; the e-invoice states the total as paid amount either way. An invoice that is paid has no payment goal and no payment terms: `paid` next to `payment-goal`, or next to a text as `due-date` of the invoice, which would be the payment terms (BT-20) instead of the sentence that it is paid, stops the compilation. A `datetime` as `due-date` is the due date (BT-9) the payment met.

A payment means code of its own must be the code of the component that details its kind, as the invoice states one (BT-81): `paid(method: (code: "54", name: [Visa]))` next to `card-payment(kind: "credit")` states 54 with the card details and prints its name, but next to `card-payment()` (48, a card of any kind) it stops the compilation, as one of the codes would be lost.

On a credit note or a self-billed invoice, the sender paid the amount to the recipient: the sentence says so (e.g. "Den Betrag in Höhe von 119,00 € haben wir Ihnen am 01.09.2026 ausgezahlt."), and the e-invoice states it as payment terms (BT-20).

## Cash Discount (Skonto)

A cash discount for a payment within fewer days is part of the payment goal. One entry is printed after the payment sentence and written into the payment terms (BT-20):

```typst
// "... within 30 days ... For payment within 14 days, a cash discount of 2%
// is granted."
#payment-goal(days: 30, discount: (days: 14, percent: 2%))
```

An array states several steps, and `basis` the amount a discount applies to, e.g. `discount: ((days: 7, percent: 3%), (days: 14, percent: 2%, basis: 1000))`. XRechnung states each step as a line in the syntax of the KoSIT (`BR-DE-18`), e.g. `#SKONTO#TAGE=14#PROZENT=2.00#`, with `#BASISBETRAG=` for the basis; the other profiles state the printed sentences. The percentage has at most two decimals, as the e-invoice states it. A cash discount changes no amount of the invoice: the buyer deducts it when paying in time. It is therefore no [`discount`](../../api-reference/line-items/index.md#adjustments-modifier-discount--surcharge), which reduces the amounts of the invoice no matter when the buyer pays.

If you write the payment terms yourself, as a textual `due-date`, state a cash discount in XRechnung as a line of its own in this syntax: `#SKONTO#TAGE=` with the days, `#PROZENT=` with the percent and two decimals, optionally `#BASISBETRAG=` with the amount it applies to, and a closing `#`. In the `"xrechnung"` profile, every line of the payment terms that starts with `#` must follow this syntax, and a line after the last cash discount that contains `#` more than once must end with its last `#` (BR-DE-18). `invoice-pro` adds the line break that XRechnung requires after a closing `#` at the end of the terms:

```typst
due-date: "Zahlbar innerhalb von 30 Tagen netto, innerhalb von 14 Tagen mit 2 % Skonto.\n#SKONTO#TAGE=14#PROZENT=2.00#",
```

The themes do not print a textual `due-date` on their own: print it where you state the payment terms (e.g. with [`#info.due-date`](../../api-reference/components.md#info-module)), so that the printed invoice states the cash discount as well.

## Payment Reference (BT-83)

The remittance information (`ram:PaymentReference`) always matches the payment reference printed in the [`bank-details`](../../api-reference/components.md#bank-details) block and encoded in its EPC-QR code. It is resolved in this order:

1. the `reference` or `text` argument of `bank-details`,
2. the `payment-reference` parameter of `invoice`,
3. the `invoice-nr`.

If `bank-details` explicitly sets `reference: none`, BT-83 is omitted as well.
