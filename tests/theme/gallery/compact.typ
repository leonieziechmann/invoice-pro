// Gallery: `compact` - an industrial wholesaler's collective invoice
// (Sammelrechnung) over three delivery notes, with seller item numbers, trade
// units and a volume discount. Default layout: layout auto (sender region de ->
// a4-dense). Item numbers are the seller's (item-id: (seller: ..)).
//   layout: <name>   lang: "en"   logo: "image" (an image logo with alt text)
//   check: true      n: <k> items in the last delivery note run up to index k
//   seed: <hex>      another brand colour
#import "/src/lib.typ": *

#let mark = box(
  height: 10mm,
  width: 10mm,
  fill: rgb("#1d3557"),
  radius: 1.2pt,
  align(center + horizon, text(fill: white, weight: "bold", size: 15pt, font: (
    "Inter",
    "Liberation Sans",
    "Libertinus Serif",
  ))[N]),
)

#let gallery(
  layout: none,
  seed: none,
  lang: "de",
  check: false,
  logo: "mark",
  n: 52,
  zugferd: false,
  validation: "draft",
  marker: none,
) = {
  let en = lang == "en"
  let logo = if logo == "image" {
    image("/tests/theme/assets/logo.svg", alt: "Nordwerk Industriebedarf GmbH")
  } else { mark }
  let stk = (display: if en { "pc" } else { "Stk." }, code: "H87")
  let pck = (display: if en { "pk" } else { "Pck." }, code: "PA")
  let mtr = (display: "m", code: "MTR")
  let rol = (display: if en { "roll" } else { "Rol." }, code: "RO")
  let krt = (display: if en { "box" } else { "Krt." }, code: "CT")
  let kg = (display: "kg", code: "KGM")
  // (item number, description, unit, price)
  let catalogue = (
    ("10-40816", [Sechskantschraube DIN 933 M8×16, 8.8 vz.], pck, 6.90),
    ("10-41025", [Sechskantschraube DIN 933 M10×25, 8.8 vz.], pck, 11.40),
    ("10-41240", [Sechskantschraube DIN 933 M12×40, 8.8 vz.], pck, 13.20),
    ("11-20008", [Sechskantmutter DIN 934 M8, St. 8 vz.], pck, 5.80),
    ("11-20010", [Sechskantmutter DIN 934 M10, St. 8 vz.], pck, 8.60),
    ("12-30084", [Unterlegscheibe DIN 125 A 8,4 vz.], pck, 7.10),
    ("12-30105", [Unterlegscheibe DIN 125 A 10,5 vz.], pck, 9.95),
    ("13-60045", [Spanplattenschraube 4,5×45 TX20, TG], krt, 18.90),
    ("13-60660", [Spanplattenschraube 6×60 TX30, TG], krt, 21.50),
    ("14-11008", [Schwerlastanker FAZ II 10/10 gvz], stk, 2.38),
    ("14-11210", [Schwerlastanker FAZ II 12/20 gvz], stk, 3.64),
    ("15-50012", [Gewindestange DIN 976 M12×1000, 4.8 vz.], stk, 3.15),
    ("20-00135", [Trennscheibe INOX 125×1,0 mm, gerade], stk, 1.29),
    ("20-00236", [Fächerschleifscheibe 125 mm, K60, Zirkonkorund], stk, 3.95),
    (
      "20-01020",
      [HSS-G Spiralbohrer DIN 338, 1–10 mm, 19-tlg. Kassette],
      unit.set-unit,
      24.80,
    ),
    ("21-44007", [Bit-Satz TX 10–40, 25 mm, 7-tlg.], unit.set-unit, 8.40),
    ("30-70120", [Kabelbinder 4,8×200 mm, schwarz, UV-beständig], pck, 3.10),
    ("30-72019", [Gewebeband 50 mm × 50 m, silber], rol, 6.75),
    ("31-10025", [Montageschaum B2, 750 ml, Pistolenschaum], stk, 7.45),
    ("31-22031", [Silikon neutral, transparent, 310 ml], stk, 4.20),
    ("40-90011", [Schutzhandschuh Nitril-beschichtet, Gr. 10], pck, 16.80),
    ("40-91209", [Gehörschutzstöpsel, SNR 37 dB], krt, 29.90),
    ("41-30044", [Absperrband rot/weiß 80 mm × 500 m], rol, 9.60),
    ("50-12050", [Stahlseil 5 mm, 7×19, vz.], mtr, 0.92),
    ("50-12080", [Rundstahlkette 8 mm, Güteklasse 8, geprüft], mtr, 11.30),
    ("60-80025", [Schweißdraht SG2 0,8 mm, Spule 15 kg], kg, 2.85),
  )
  let qty = (
    12,
    8,
    6,
    10,
    10,
    6,
    4,
    5,
    3,
    50,
    40,
    25,
    100,
    50,
    2,
    10,
    20,
    12,
    24,
    24,
    10,
    2,
    6,
    150,
    20,
    30,
  )
  let row(i) = {
    let (sku, name, u, p) = catalogue.at(calc.rem(i, catalogue.len()))
    item(
      name,
      item-id: (seller: sku),
      unit: u,
      price: p,
      quantity: qty.at(calc.rem(i, qty.len())),
    )
  }
  invoice(
    theme: theme.compact.with(
      theme.custom.logo(image: logo),
      if seed != none { theme.custom.brand(color: rgb("#" + seed)) },
      if check { theme.custom.checks(min-contrast: 4.5) },
      ..if layout != none { (layout: dictionary(theme.layout).at(layout)) },
    ),
    locale: if en { locale.en-de } else { locale.de-de },
    validation: validation,
    sender: (
      name: "Nordwerk Industriebedarf GmbH",
      address: "Am Güterbahnhof 7",
      city: "28197 Bremen",
      vat-id: "DE814562370",
      tax-nr: "60 145 20371",
      register: [Amtsgericht Bremen HRB 31877],
      management: [GF: Jens Hartwig, Aylin Demir],
      extra: (
        Telefon: "+49 421 69 330-0",
        "E-Mail": "rechnung@nordwerk-bremen.de",
        Web: "nordwerk-bremen.de",
      ),
    ),
    recipient: (
      name: "Metallbau Krüger GmbH & Co. KG",
      address: "Industriestraße 41",
      city: "27283 Verden (Aller)",
    ),
    invoice-nr: "RE-2026-10874",
    customer-nr: "D-40117",
    order-nr: "BE-7731",
    date: datetime(year: 2026, month: 9, day: 30),
    subject: if en { "Collective invoice September" } else {
      "Sammelrechnung September"
    },
    zugferd: if zugferd { "basic" },
    [
      #marker
      #if en [Dear Sir or Madam, for the deliveries in September we invoice the following items:] else [Sehr geehrte Damen und Herren, für die Lieferungen im September berechnen wir Ihnen:]

      #line-items[
        #group([Lieferschein LS-26-5512 vom 04.09.2026])[
          #for i in range(16) { row(i) }
        ]
        #group([Lieferschein LS-26-5598 vom 15.09.2026])[
          #for i in range(16, 34) { row(i) }
          #item(
            [Rundstahlkette 8 mm, Güteklasse 8 – Zuschnitt und Prüfbescheinigung],
            item-id: (seller: "99-00012"),
            unit: stk,
            price: 38.00,
            quantity: 2,
            description: [Zuschnitt 4 × 5,0 m inkl. Endglieder, Prüfbescheinigung nach DIN EN 818-2],
          )
        ]
        #group([Lieferschein LS-26-5671 vom 26.09.2026])[
          #for i in range(34, n) { row(i) }
        ]
        #discount([Mengenrabatt Rahmenvertrag RV-2024-03], amount: 3%)
      ]

      #payment-terms(days: 30)
      #bank-details(
        bank: "Sparkasse Bremen",
        iban: "DE72290501010012345678",
        bic: "SBREDE22XXX",
      )
    ],
  )
}
