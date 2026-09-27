// expect: AGREE_VALID
// finding: parties-bt30-bt47-legal-registration-missing
// facts: {"seller_legal_id": ["", "Amtsgericht Berlin, HRB 4711"], "seller_trading_name": "Muster Design", "seller_legal_info": "Geschäftsführer: Max Muster", "buyer_trading_name": "Client Shop"}
//
// The register number (BT-30), the trading names (BT-28, BT-45) and the
// additional legal information of the seller (BT-33) had no input: a register
// number could only be given as seller identifier (BT-29) or printed.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de
    + (
      trading-name: "Muster Design",
      legal-id: id.register("HRB 4711", court: "Amtsgericht Berlin"),
      legal-info: "Geschäftsführer: Max Muster",
    ),
  recipient: buyer-fr + (trading-name: "Client Shop"),
  invoice-nr: "RG-TRADING-NAME",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
