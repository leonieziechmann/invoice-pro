// Gallery: `corporate` - a drive-technology manufacturer invoicing conveyor drives,
// retrofit work and spare parts to a logistics holding (purchase order, delivery
// note, framework contract, volume rebate). English locale, German sender:
// layout: auto picks a4-sidebar; --input layout=<name> swaps the page master,
// --input zugferd=1 adds the e-invoice (compile with --pdf-standard a-3b).
#import "/src/lib.typ": *
#let lay = sys.inputs.at("layout", default: "")
#let layout = if lay == "" { auto } else { dictionary(theme.layout).at(lay) }

#show: invoice.with(
  theme: theme.corporate.with(
    theme.custom.logo(
      image: image("vossberg.svg", alt: "Vossberg Antriebstechnik AG"),
      height: 10mm,
    ),
    layout: layout,
  ),
  locale: locale.en-de,
  sender: (
    name: "Vossberg Antriebstechnik AG",
    address: "Am Stadtholz 44",
    city: "33609 Bielefeld",
    vat-id: "DE124578903",
    register: [Amtsgericht Bielefeld, HRB 38127],
    management: [Executive board: Dr. K. Vossberg (CEO), A. Nwosu-Lange (CFO)],
    extra: (
      Phone: "+49 521 9860 0",
      Email: "receivables@vossberg-drives.de",
      Web: "vossberg-drives.de",
    ),
  ),
  recipient: (
    name: "Nordhafen Logistik Holding GmbH",
    address: "Accounts Payable · Kattwykdamm 12",
    city: "21129 Hamburg",
  ),
  invoice-nr: "VA-2026-004817",
  customer-nr: "D-10442",
  order-nr: "PO 7300051962",
  delivery-note-nr: "LS 26-09-3318",
  contract-nr: "FWA-2024-09",
  date: datetime(year: 2026, month: 9, day: 29),
  references: (
    references.customer-nr(),
    references.order-nr(),
    references.delivery-note-nr(),
    references.contract-nr(),
    references.due-date(),
  ),
  zugferd: if sys.inputs.at("zugferd", default: "") != "" { "basic" },
)

Dear Mr Albers,

under framework agreement FWA-2024-09 we invoice the drives delivered to your Hamburg-Altenwerder hub and the retrofit of sorter line S3.

#line-items[
  #group([Conveyor drives (delivery LS 26-09-3318)])[
    #item(
      [Helical gear motor VG 90, 2.2 kW],
      description: [IE3, i = 18.4, hollow shaft 40 mm, with brake],
      quantity: 12,
      unit: unit.piece,
      price: 1284,
    )
    #item(
      [Frequency inverter VF 400, 3 kW],
      description: [PROFINET, STO, parameterised for line S3],
      quantity: 12,
      unit: unit.piece,
      price: 896,
    )
    #item(
      [Spare parts kit S3 (bearings, seals, brake pads)],
      quantity: 2,
      unit: unit.set-unit,
      price: 740,
    )
  ]
  #group([Retrofit sorter line S3])[
    #item(
      [Mechanical installation],
      description: [Two technicians, 25–26 September 2026],
      quantity: 32,
      unit: unit.hour,
      price: 94,
    )
    #item(
      [Commissioning and acceptance test],
      quantity: 1,
      unit: unit.lump-sum,
      price: 2350,
    )
  ]
  #item(
    [Freight and packaging, Bielefeld to Hamburg],
    quantity: 1,
    unit: unit.lump-sum,
    price: 485,
  )
  #discount([Framework volume rebate], amount: 3%)
]

#payment-terms(days: 30)
#bank-details(
  bank: "Deutsche Bank AG",
  iban: "DE89370400440532013000",
  bic: "DEUTDEDBBIE",
)
#signature(name: "Accounts Receivable · Vossberg Antriebstechnik AG")
