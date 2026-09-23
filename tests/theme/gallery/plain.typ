// Gallery: `plain` - a freelance translator under the small-business rule (de-DE,
// § 19 UStG, no logo, no furniture). Ported from the theming prototype's
// tests/figures-gallery.typ.
#import "/src/lib.typ": *

#let gallery(validation: "draft", marker: none) = invoice(
  theme: theme.plain,
  locale: locale.de-de,
  validation: validation,
  tax-exempt-small-biz: true,
  sender: (
    name: "Clara Weiß · Fachübersetzungen",
    address: "Kolberger Straße 4",
    city: "24105 Kiel",
    tax-nr: "20/123/45678",
    email: "post@clara-weiss.de",
  ),
  recipient: (
    name: "Nordwind Reisen GmbH",
    address: "Holstenstraße 21",
    city: "24103 Kiel",
  ),
  invoice-nr: "CW-2026-038",
  date: datetime(year: 2026, month: 9, day: 15),
  [
    #marker
    Guten Tag Frau Petersen,

    vielen Dank für Ihren Auftrag. Für die Übersetzungen im September berechne ich:

    #line-items[
      #item(
        [Übersetzung Katalog „Skandinavien 2027“],
        description: [Deutsch → Englisch, Normzeilen à 55 Anschläge],
        unit: "Zeilen",
        price: 1.45,
        quantity: 2140,
      )
      #item(
        [Übersetzung AGB, DE → EN (Fachgebiet Recht)],
        price: 1.8,
        quantity: 410,
        unit: "Zeilen",
      )
      #item(
        [Korrektorat Newsletter Oktober],
        price: 55,
        quantity: 2,
        unit: unit.hour,
      )
      #item([Eilzuschlag Katalog (Lieferung in 5 Werktagen)], price: 310)
    ]

    #payment-terms(days: 14)
    #bank-details(
      bank: "Förde Sparkasse",
      iban: "DE68210501700012345678",
      bic: "NOLADE21KIE",
    )
    #signature(name: "Clara Weiß")
  ],
)
