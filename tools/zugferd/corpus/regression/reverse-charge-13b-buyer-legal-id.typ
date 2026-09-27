// expect: AGREE_VALID
// finding: tax-ae-buyer-legal-id-missing, fidelity-cat-ae-no-buyer-legal-id
// facts: {"buyer_legal_id": ["", "Amtsgericht Bremen, HRB 12345"], "breakdown": [["AE", "0"]]}
//
// A domestic reverse charge (§ 13b UStG) to a German company without VAT
// identifier. BR-AE-02 accepts its legal registration identifier (BT-47)
// instead, which there was no input for, so the invoice could not be written.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: (
    name: "Generalbau GmbH",
    address: "Am Hafen 3",
    city: (name: "Bremen", post-code: "28195"),
    country: country.de,
    legal-id: id.register("HRB 12345", court: "Amtsgericht Bremen"),
    email: "kreditoren@generalbau.example",
  ),
  invoice-nr: "RG-13B-LEGAL-ID",
)

#line-items[
  #item(
    [Estricharbeiten],
    price: 45,
    quantity: 120,
    unit: unit.square-metre,
    tax: tax.reverse-charge(
      grounds: "Steuerschuldnerschaft des Leistungsempfängers (§ 13b UStG)",
    ),
  )
]
#payment-goal(days: 30)
#bank
