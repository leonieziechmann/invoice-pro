// expect: AGREE_VALID
// finding: parties-bt30-bt47-legal-registration-missing, core-minimum-no-bt30
// facts: {"profile": "minimum", "seller_legal_id": ["0009", "12345678200010"]}
//
// A French micro-entrepreneur without VAT identifier in MINIMUM. The profile
// identifies the seller by its VAT identifier or its legal registration
// identifier (BR-CO-26); there was no input for the latter (BT-30), so the
// invoice could not be written.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  locale: locale.fr-fr,
  zugferd: "minimum",
  tax-exempt-small-biz: true,
  sender: (
    name: "Jean Dupont EI",
    address: "3 rue Victor Hugo",
    city: (name: "Bordeaux", post-code: "33000"),
    country: country.fr,
    legal-id: id.siret("123 456 782 00010"),
  ),
  recipient: buyer-fr,
  invoice-nr: "RG-MIN-SIRET",
)

#line-items[
  #item([Création du site web], price: 900, quantity: 1)
]
#payment-goal(days: 30)
