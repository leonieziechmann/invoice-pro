---
sidebar_position: 5
---

# Document Details

The details of the document as a whole: what kind of document it is, the documents it refers to, the date or period of the supply, its notes and its currency.

## Document Type (BT-3)

`document-type` states what kind of document the invoice is. It is written as the document type code (BT-3, UNTDID 1001), and unless you set `subject`, it is the printed title:

| `document-type`       | BT-3  | Title (German / English)                 | Meaning                                                                                                 |
| :-------------------- | :---- | :--------------------------------------- | :------------------------------------------------------------------------------------------------------ |
| `auto` or `"invoice"` | `380` | Rechnung / Invoice                       | A commercial invoice: the buyer pays the seller.                                                        |
| `"credit-note"`       | `381` | Rechnungskorrektur / Credit Note         | Credits amounts to the buyer, e.g. for returned goods or a discount granted later.                      |
| `"corrected"`         | `384` | Korrigierte Rechnung / Corrected Invoice | Replaces the invoice `preceding-invoice-nr`.                                                            |
| `"prepayment"`        | `386` | Anzahlungsrechnung / Prepayment Invoice  | Asks for an advance payment, which the final invoice deducts. XRechnung does not allow it (`BR-DE-17`). |
| `"self-billed"`       | `389` | Gutschrift / Self-Billing Invoice        | Issued by the buyer for the seller, e.g. a commission statement (see below).                            |

Any other code of UNTDID 1001 for invoices and credit notes can be given as text, e.g. `"326"` for a partial invoice or `"875"` to `"877"` for construction invoices. It is printed with the title of its kind (an invoice or a credit note), so give it a `subject` of its own. XRechnung allows only `326`, `380`, `381`, `384`, `389`, `875`, `876` and `877` (`BR-DE-17`): the KoSIT validator only warns about other codes, but Mustang rejects them, so `invoice-pro` reports an error; with `zugferd: auto`, such an invoice is written as EN 16931.

### Credit Notes

EN 16931 states a credit note with **positive** amounts: the items are the credited amounts, entered with positive prices, and `document-type: "credit-note"` says that they are credited to the buyer. The amount due (BT-115) is the amount the buyer gets back.

- A credit note with a negative total would ask the buyer to pay, so it stops the e-invoice (`IP-DOC-03`). An invoice with a negative total is valid, but a credit note is the document for it (`IP-DOC-04`, a warning).
- As long as an amount is due, the credit note says when or how the buyer gets it (`BR-CO-25`): [`payment-terms`](../../api-reference/components.md#payment-terms) prints that the amount is transferred within the given days (and states that date, BT-9), a textual `due-date` (e.g. `due-date: "Der Betrag wird mit Ihrer nächsten Rechnung verrechnet."`) states the terms (BT-20).
- [`bank-details`](../../api-reference/components.md#bank-details) on a credit note are the account the amount is paid to, usually the buyer's: the account holder defaults to the recipient's name, and no EPC-QR code is printed. Do not reuse the bank details of your invoices on a credit note: your own account would be printed with the buyer as its holder and stated as the account the credit is paid into. XRechnung requires payment instructions (BG-16) on credit notes as well (`BR-DE-1`): the recipient's account you transfer the amount to, `paid` if it is paid already, or for a set-off against an invoice `paid(method: (code: "97", name: [Verrechnung]))`.
- The sender of a credit note or a self-billed invoice pays the amount, so it cannot collect it from the recipient: [`direct-debit`](../../api-reference/components.md#direct-debit), [`card-payment`](../../api-reference/components.md#card-payment) and a cash discount of `payment-terms` (`discount`) stop the compilation on these documents. [`paid`](../../api-reference/components.md#paid) states that the amount has been paid already.
- A document that amends an invoice must refer to it (Art. 219 VAT Directive): set `preceding-invoice-nr` (and `preceding-invoice-date`) to the invoice the credit note refers to. The default `references` print them.
- The date of the supply of a credit note is the one of the supply it credits: set `service-period` to it, or give the items their `date`. The date of the credit note is not the date of the supply, so without them the credit note states none (see [Service Period](#service-period-bt-72--bg-14)).
- In German, a credit note is titled "Rechnungskorrektur": the German VAT law reserves "Gutschrift" for self-billed invoices (§ 14 Abs. 2 Satz 2 UStG). A commercial credit note titled "Gutschrift" is permitted as well; set `subject: "Gutschrift"` together with `document-type: "credit-note"` if you prefer it.

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  zugferd: auto,
  document-type: "credit-note",
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
    city: "70173 Stuttgart",
    country: country.de,
    vat-id: "DE987654321",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "CN-2026-007",
  date: datetime(year: 2026, month: 7, day: 20),
  preceding-invoice-nr: "INV-2026-102",
)

#line-items[
  #item(
    [Workshop cancelled by us],
    quantity: 1,
    price: 1500.00,
    tax: tax.vat(19%),
  )
]

#payment-terms(days: 14)

#bank-details(
  bank: "Acme Bank",
  iban: "DE89370400440532013000",
)
```

### Self-Billed Invoices

The buyer issues a self-billed invoice for the seller, e.g. a publisher for the royalties of an author or a principal for the commissions of an agent. `sender` is then the buyer, who issues the document, and `recipient` the seller:

- The XML states the recipient as seller (BG-4) and the sender as buyer (BG-7). The messages of the e-invoice name the inputs, e.g. `recipient.vat-id` for the seller VAT identifier.
- The default references and every preset state the tax number and VAT ID of the seller (the recipient), which the law requires on the invoice, and the VAT ID of the buyer (the sender); `references.seller-tax-nr()`, `references.seller-vat-id()` and `references.buyer-vat-id()` print them in references of your own.
- `payment-terms` says that the sender transfers the amount, and the [`bank-details`](../../api-reference/components.md#bank-details) are the seller's account, without EPC-QR code.
- The title is the mention the law requires on a self-billed invoice (Art. 226 No. 10a VAT Directive): "Gutschrift" in German (§ 14 Abs. 4 Satz 1 Nr. 10 UStG), "Self-Billing Invoice" in English, "Autofacturation" in French, "Autofatturazione" in Italian and "Facturación por el destinatario" in Spanish. Keep it in a `subject` of your own.

### Titles That Name Another Document

Without `document-type`, the e-invoice states a commercial invoice (`380`), which asks the buyer to pay. If the subject names another kind of document, the e-invoice stops with `IP-DOC-01`: a credit note ("Gutschrift", "Rechnungskorrektur", "Stornorechnung", "Credit note", "Avoir", "Nota di credito", ...), a corrected or a self-billed invoice, or a document that is no invoice at all, such as a quote ("Angebot", "Kostenvoranschlag", "Quote", "Offer", "Devis", "Preventivo", "Presupuesto"), a delivery note ("Lieferschein"), an order confirmation, a pro forma invoice or a payment reminder. Set the matching `document-type`, or `document-type: "invoice"` if it is an invoice. The first word of the subject that names a kind of document decides, so "Rechnung zum Angebot 2026-5" is an invoice. An e-invoice is only written for invoices and credit notes: do not set `zugferd` for quotes and other documents that are no invoice.

## Document References

`order-nr` (BT-13), `contract-nr` (BT-12), `delivery-note-nr` (BT-16) and `preceding-invoice-nr` (BT-25, e.g. for corrections) are written to the XML where the profile supports them. `project` is written as the project reference (BT-11), which public buyers often require, in the `"en16931"` and `"xrechnung"` profiles; the other profiles have none, which is reported as a warning (`IP-PROFILE-01`).

`preceding-invoice-date` (a `datetime`) is the date of the preceding invoice (BT-26), written next to its number from the `"basic-wl"` profile on (`"minimum"` has no preceding invoice reference, which is reported as a warning, `IP-PROFILE-01`); `references.preceding-invoice-date()` prints it. The default `references` print the number and the date of the preceding invoice if you give them. A date without `preceding-invoice-nr` cannot be written and stops the e-invoice (`IP-DOC-05`: the e-invoice states a preceding invoice by its number, `BR-55`, so the date would be lost). A corrected invoice (`document-type: "corrected"`) replaces the preceding invoice, so it must name it: `BR-DE-26` in XRechnung (which KoSIT only warns about, but Mustang rejects), `IP-DOC-02` in the other profiles, as the VAT Directive (Art. 219) requires a document that amends an invoice to refer to it.

## Service Period (BT-72 / BG-14)

The date or period of the supply is mandatory invoice content in many countries (e.g. § 14 Abs. 4 Nr. 6 UStG). `invoice-pro` resolves it once, for the printed invoice ([`references.service-time()`](../../api-reference/invoice/references.md)) and the XML alike:

1. the `service-period` of the invoice, a `datetime` or a period `(start, end)`, if you set it;
2. else from the earliest to the latest `date` of the items (of `item`, `bundle` and `group`, a date or a period). Items without a date do not count when others have one;
3. else the invoice date, if no item has a date. Not so on a credit note (`document-type: "credit-note"`, 381), which amends an invoice, and on a prepayment invoice (`"prepayment"`, 386), which asks for an advance payment before the supply: their own date is not the date of the supply, so without a `service-period` or dates of the items, neither the printed document nor its XML states one. XRechnung recommends one (`BR-DE-TMP-32`, a warning), and an intra-community supply (K) requires one (`BR-IC-11`, an error): set `service-period` to the date or period of the supply the credit note refers to.

A single date is written as the actual delivery date (BT-72), a period as the invoicing period (BG-14, BT-73 and BT-74), both from the `"basic-wl"` profile on (`"minimum"` has neither: a `service-period` is then reported as a warning, `IP-PROFILE-01`). The default `references` print a `service-period` you set and, for a seller in Germany, the date of the supply in any case: German law requires it on the invoice also when it is the date of the invoice (§ 14 Abs. 4 Satz 1 Nr. 6 UStG), and without dates on the items, the XML states the invoice date. Every preset prints it as well; with references of your own, add `references.service-time()`:

```typst
#show: invoice.with(
  service-period: (
    datetime(year: 2026, month: 6, day: 1),
    datetime(year: 2026, month: 6, day: 30),
  ),
  references: (references.invoice-nr(), references.service-time()),
  // ...
)
```

The printed service period must be the one the XML states (`IP-PERIOD-01`). `references.service-time(value: ..)` prints a date or a period `(start, end)` given as `value` in the date format of the locale, and another date than the one the XML states is an error. A text of its own, e.g. `references.service-time(value: "Juni 2026")` or a reference `("Leistungszeitraum", "Juni 2026")`, cannot reach the XML: without dates on the items or a `service-period`, the XML states the invoice date, which the text contradicts, so it is an error; besides them, the text may name the same period in other words, so it is a warning. Set `service-period` instead, and print it with `references.service-time()`. The same holds for a credit note or a prepayment invoice without dates, whose XML states no date of the supply: a date printed with `value` is an error, a text of its own a warning. A printed invoice without the date of the supply is reported as well (`IP-PERIOD-03`, see [Printed Details](../validation.md#printed-details)).

## Notes (BT-22)

`notes` on the invoice are texts about the invoice as a whole, e.g. terms of delivery or legal notices. They are printed below the line items, with the exemption notes, and written into the XML as invoice notes (BT-22) with their line breaks, from the `"basic-wl"` profile on (`"minimum"` has none, which is reported as a warning, `IP-PROFILE-01`). Like the exemption notes, they are printed also with `line-items(show-information: false)`, so the printed invoice states what the XML states. A note can carry a subject code of UNTDID 4451 (BT-21, `BR-CL-08`), e.g. `"AAI"` for general information or `"REG"` for regulatory information:

```typst
#show: invoice.with(
  notes: (
    "Lieferung frei Haus.",
    (
      text: "Es gelten unsere Allgemeinen Geschäftsbedingungen.",
      subject-code: "AAI",
    ),
  ),
  // ...
)
```

## Currency (BT-5)

The invoice currency (BT-5) is the currency of the locale (`EUR`, or `CHF` for the Swiss locales), unless you set `currency` on the invoice to an ISO 4217 code. The amounts are then printed in that currency in the number format of the locale: with its symbol for `EUR` (€), `USD` ($), `GBP` (£), `JPY` (¥), `PLN` (zł), `CZK` (Kč) and `HUF` (Ft), otherwise with its code (e.g. "1.234,50 CHF" or "1.234,50 SEK"), and rounded to its decimals (e.g. none for `JPY`).

```typst
#show: invoice.with(
  locale: locale.de-de,
  currency: "USD", // prints "1.234,50 $" and states USD in the e-invoice
  // ...
)
```

The EPC-QR code of the [bank details](../../api-reference/components.md#bank-details) transfers euros only, so it is shown for invoices in euro only, and a credit transfer in another currency is written as a credit transfer (BT-81 `30`) instead of a SEPA credit transfer (`58`). An e-invoice whose printed amounts show another currency than the one it states stops with `IP-PRINT-02`, e.g. with a currency formatter of a custom locale that prints "zł" while the locale states `EUR`. The profiles based on EN 16931 accept only the currencies of its code list (`BR-CL-04`). The printed invoice reads the currency code as the e-invoice states it, in upper case and without spaces: a custom locale with the code `"eur"` invoices in euro, so its bank details show the EPC-QR code, and a direct debit is a SEPA direct debit whose creditor identifier is checked. A currency with more than 2 decimals, such as `KWD`, rounds its amounts to them, which the XML cannot state (`IP-DEC-02`, reported for `currency`): create such an invoice without e-invoice, or with a locale of your own whose currency has 2 decimals, e.g. `locale.en-de.with((region: (currency: (code: "KWD", symbol: "KWD", decimals: 2))))`.

In the profiles based on EN 16931, the currency must be in the code lists of both official validators (`BR-CL-04`): a currency that is newer than the list of one of them (e.g. `VES`) stops the e-invoice. One that the current list has withdrawn (e.g. `BGN` and `HRK`, replaced by the euro) stops an XRechnung, while `"basic"` and `"en16931"`, whose Factur-X validation accepts it, allow it with a warning (`IP-CODE-01`): a receiver that validates with the current list, as KoSIT does, rejects such an e-invoice. `"basic"` and `"en16931"` also apply the list of Factur-X (`FX-SCH-A-000040`), which lacks e.g. the São Tomé dobra of before 2018 (`STD`), which `"xrechnung"` accepts.

### VAT in the National Currency (BT-6, BT-111)

Within the EU, an invoice in another currency must also state the VAT amount in the national currency of the member state where the supply is taxed (Art. 230 VAT Directive), e.g. in euro for a supply taxed in Germany. `invoice-pro` does not support the VAT accounting currency (BT-6) and the VAT total in it (BT-111) yet: state the VAT amount in the national currency and the exchange rate in a note (`notes`), which is printed and written into the e-invoice (BT-22).
