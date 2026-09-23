// expect: AGREE_VALID
// finding: amounts-doctype-gutschrift-written-as-380
// facts: {"type_code": "389", "seller_name": "Kunde AG", "buyer_name": "Muster GmbH", "seller_vat": "DE987654328", "buyer_vat": "DE123456788"}
//
// A self-billed invoice (389, "Gutschrift"), issued by the buyer: the sender
// of the document is the buyer and its recipient the seller, so the XML
// states the recipient as seller (BG-4) and the sender as buyer (BG-7).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  document-type: "self-billed",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "GS-2026-3",
)

#line-items[
  #item([Provision August], price: 800, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank-details(bank: "Kundenbank", iban: "DE75512108001245126199")
