// ZUGFeRD item identifiers: a plain string maps to SellerAssignedID (BT-155);
// a dictionary maps `standard` to GlobalID (BT-157, GS1 GTIN), `seller` to
// SellerAssignedID (BT-155) and `buyer` to BuyerAssignedID (BT-156), emitted in
// TradeProduct XSD order before ram:Name. Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "München", post-code: "80339"),
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@seller.de",
    ),
  ),
  recipient: (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
    email: "accounting@buyer.de",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "2026-02",
)

#line-items[
  #item(
    [Consulting],
    price: 100,
    quantity: 1,
    tax: tax.vat(19%),
    item-id: "ART-4711",
  )
  #item(
    [Keyboard],
    price: 49.90,
    quantity: 2,
    tax: tax.vat(19%),
    item-id: (seller: "KB-001"),
  )
  #item(
    [Pen],
    price: 1.50,
    quantity: 10,
    tax: tax.vat(19%),
    item-id: (seller: "PEN-01", buyer: "B-778", standard: "4006381333931"),
  )
]
#payment-goal(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
