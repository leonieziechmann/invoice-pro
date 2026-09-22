// Gallery: `technical` for a software house (English locale, B2B, groups,
// surcharge + discount, several units).
//   --input layout=<name>   another layout (default: the look's own, a4-digital)
//   --input extra=<n>       n extra timesheet lines (multi-page test)
//   --input zugferd=basic   embed Factur-X (compile with --pdf-standard a-3b)
//   --input checks=1        theme.custom.checks(min-contrast: 4.5)
#import "/src/lib.typ": *

#let lay = sys.inputs.at("layout", default: "default")
#let extra = int(sys.inputs.at("extra", default: "0"))

#show: invoice.with(
  theme: theme.technical.with(
    theme.custom.logo(
      image: image("by-logo.svg", alt: "Brückner & Yildiz Software"),
      height: 11mm,
    ),
    if sys.inputs.at("checks", default: "0") == "1" {
      theme.custom.checks(min-contrast: 4.5)
    },
    layout: if lay == "default" { auto } else {
      dictionary(theme.layout).at(lay)
    },
  ),
  locale: locale.en-de,
  sender: (
    name: "Brückner & Yildiz Software GmbH",
    address: "Schlesische Straße 26",
    city: "10997 Berlin",
    vat-id: "DE298765431",
    register: [Amtsgericht Charlottenburg HRB 214365 B],
    management: [Managing directors: Jana Brückner, Emre Yildiz],
    extra: (
      Phone: "+49 30 5557 1200",
      Email: "billing@by-software.de",
      Web: "by-software.de",
    ),
  ),
  recipient: (
    name: "Hansa Logistik AG",
    address: "Am Speicher XI 4",
    city: "28217 Bremen",
  ),
  date: datetime(year: 2026, month: 9, day: 30),
  invoice-nr: "BY-2026-0917",
  customer-nr: "C-0042",
  order-nr: "PO-4500193877",
  project: "DISPATCH-NG",
  due-date: datetime(year: 2026, month: 10, day: 30),
  references: (
    references.customer-nr(),
    references.order-nr(),
    references.project(),
    references.due-date(),
    references.vat-id(),
  ),
  subject: "Invoice — Sprint 14 and platform operations",
  zugferd: sys.inputs.at("zugferd", default: none),
)

Dear Ms Albers, as agreed in framework agreement FA-2024-07 we invoice the following services:

#line-items[
  #group(
    [Sprint 14 · 01.09.–14.09.2026],
    description: [Dispatcher platform, release 3.4],
  )[
    #item(
      [Backend development],
      description: [REST API v3: tour optimisation endpoints, OpenAPI spec, contract tests],
      price: 115,
      quantity: 38,
      unit: "h",
    )
    #item(
      [Frontend development],
      description: [Dispatcher dashboard: live map, drag-and-drop re-planning],
      price: 105,
      quantity: 26,
      unit: "h",
    )
    #item([Code review & QA automation], price: 105, quantity: 9.5, unit: "h")
  ]
  #group([Platform operations · September 2026])[
    #item(
      [Kubernetes cluster operations],
      description: [3 nodes, monitoring, patching, backups (SLA Gold)],
      price: 890,
      quantity: 1,
      unit: "month",
    )
    #item(
      [Incident response on-call],
      description: [INC-2291, Sat 19.09.2026, 02:10–08:05],
      price: 140,
      quantity: 6,
      unit: "h",
      modifier: surcharge([Weekend], amount: 25%),
    )
    #item(
      [Penetration test remediation],
      description: [Findings PT-07 to PT-12 (OWASP ASVS L2)],
      price: 1450,
      quantity: 1,
      unit: "lump sum",
      modifier: discount([Framework agreement], amount: 10%),
    )
    #item(
      [Cloud hosting (pass-through)],
      description: [AWS eu-central-1, invoice 612-0934-2026-09],
      price: 612.4,
      quantity: 1,
      unit: "month",
    )
    #for i in range(extra) {
      item(
        [Support ticket OPS-#(1400 + i)],
        description: [Remote analysis and fix, see timesheet],
        price: 105,
        quantity: 0.5 + calc.rem(i, 4) * 0.5,
        unit: "h",
      )
    }
  ]
]

#payment-terms(days: 30)
#bank-details(
  bank: "Commerzbank Berlin",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
#signature()
