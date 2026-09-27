// expect: AGREE_VALID
// finding: amounts-custom-locale-currency-eur
// facts: {"currency": "USD", "iban": "DE89370400440532013000"}
//
// An invoice in US dollars (`currency: "USD"`) with the German locale: the
// XML states USD (BT-5), and the amounts are printed with "$" in the German
// number format. A credit transfer in another currency than the euro is no
// SEPA credit transfer (BT-81 = 30).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  currency: "USD",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "RG-USD",
)

#line-items[
  #item(
    [Maschinenteile],
    price: 1250,
    quantity: 4,
    tax: tax.export(
      grounds: "Steuerfreie Ausfuhrlieferung nach § 4 Nr. 1 Buchst. a UStG",
    ),
  )
]
#payment-goal(days: 30)
#bank
