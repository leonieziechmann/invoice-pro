// A French micro-entrepreneur without VAT identifier (franchise en base de
// TVA) in the Factur-X MINIMUM profile (validated by validate-all-zugferd).
// MINIMUM identifies the seller by its VAT identifier (BT-31) or its legal
// registration identifier (BT-30, BR-CO-26): here the SIRET of the `id`
// module, stated with its scheme 0009.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.fr-fr,
  zugferd: "minimum",
  tax-exempt-small-biz: true,
  sender: (
    name: "Jean Dupont EI",
    address: "3 rue Victor Hugo",
    city: "33000 Bordeaux",
    country: country.fr,
    legal-id: id.siret("123 456 782 00010"),
  ),
  recipient: (
    name: "Client SARL",
    address: "5 avenue Foch",
    city: "69006 Lyon",
    country: country.fr,
    legal-id: id.siren("987 654 324"),
  ),
  invoice-nr: "2026-014",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Création du site web], price: 900, quantity: 1, unit: unit.piece)
]
#payment-goal(days: 30)
