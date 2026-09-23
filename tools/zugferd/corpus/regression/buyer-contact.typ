// expect: AGREE_VALID
// finding: parties-identifier-inputs-dropped, robustness-printed-refs-missing-in-xml
// facts: {"buyer_contact": {"name": "Mme Dupont", "phone": "+33 1 23456789", "email": "dupont@client.example"}}
//
// The contact of the recipient was dropped from the XML, although EN 16931
// has a business term for it (BG-9).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr
    + (
      contact: (
        name: "Mme Dupont",
        phone: "+33 1 23456789",
        email: "dupont@client.example",
      ),
    ),
  invoice-nr: "RG-BUYER-CONTACT",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
