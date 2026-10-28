---
sidebar_position: 5
---

# Invoice Data

For the generated XML payload to be valid, your input data must satisfy strict standard requirements. The validation names the input to fix for every problem (see [Validation and Error Reporting](../validation.md)). These pages explain the inputs, topic by topic, and what `invoice-pro` writes from them:

| Page                                    | Covers                                                                                                                                                                                                                      |
| :-------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Parties and Identifiers](./parties.md) | Names, addresses, countries and post codes, tax identifiers, party identifiers and legal registration identifiers, contacts, the buyer reference and Leitweg-ID, electronic addresses, the tax representative and the payee |
| [Line Items and Units](./line-items.md) | Unit codes, prices and quantities, item identifiers, and the notes, periods and country of origin of items                                                                                                                  |
| [Taxes](./taxes.md)                     | VAT categories, exemption reasons and their codes, the small business exemption and gross prices                                                                                                                            |
| [Payment](./payment.md)                 | Due date and payment terms, the payment means (credit transfer, direct debit, payment card, paid invoices), cash discounts and the payment reference                                                                        |
| [Document Details](./document.md)       | The document type (credit notes, corrected and self-billed invoices), document references, the service period, notes and the currency                                                                                       |
| [Business Terms](./business-terms.md)   | Every business term of EN 16931, with the input that states it or the reason why it is not supported                                                                                                                        |

## Dates

Every date input is a calendar date: a `datetime` of a time only, such as `datetime(hour: 9, minute: 0, second: 0)`, stops the compilation with an error that names the input (e.g. `` `service-period` is a time without a day ``), for the dates of the invoice (`date`, `service-period`, `order-date`, `preceding-invoice-date`, `due-date`), of the items (`item`, `bundle`, `group`), of `payment-terms`, `paid` and `prepayment`, and the `value` of the date references. Earlier versions failed in the date format of the locale with a message that named no input.

## Text

Names, addresses and references given as content are written as their plain text; formatting is dropped.

## What a Profile Cannot State

The profile decides what the XML can state (see [What Each Profile States](../index.md#what-each-profile-states)). An input the profile cannot state is still printed, but it is not written into the e-invoice, which the validation reports as a warning (`IP-PROFILE-01`): its hint names the lowest profile that states it.
