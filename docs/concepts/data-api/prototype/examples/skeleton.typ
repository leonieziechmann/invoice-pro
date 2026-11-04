// The skeleton of the data API concept (§2.1; the synthesis' §4.7). It imports
// the prototype tree: compile with `--root <work>` in the layout of run.sh.
// Previewable alone; hydrated without edits by
// `--input invoice-pro-data-file=..` or `--input invoice-pro-data=<JSON>`.
// Hydrated, any problem stops the build; to see the problems in a draft,
// add `--input invoice-pro-validation=draft`.
#import "/repo/src/lib.typ": *

// The data the CLI hands over (inline JSON or a file read here, so its path
// resolves against this project); `none` without input: the samples render.
#let record = data.load(read: p => read(p, encoding: none))
#let values = data.values(record)

// Samples: what identifies one invoice. Hydrated, they are dropped.
#let sample = (
  invoice-nr: "MUSTER-0001",
  date: datetime(year: 2026, month: 1, day: 15),
  recipient: (
    name: "Erika Mustermann",
    address: "Musterweg 1",
    city: "10115 Berlin",
    country: "DE",
  ),
  custom: (tarif: "Grundversorgung"),
)
// The values this invoice shows: the data's, else the samples.
#let shown = if values == none { sample } else { values }

// A design rule (Typst, never data): the coat of arms by the recipient's post
// code; the custom field `wappen` may name one directly. It is chosen here, at
// document level, as a static logo patch: the built-in logo part stays, so the
// e-invoice checks of printed content stay active.
#let arms = (
  bayern: "wappen/bayern.svg",
  berlin: "wappen/berlin.svg",
  hamburg: "wappen/hamburg.svg",
  muenchen: "wappen/muenchen.svg",
)
#let arms-by-plz = ("8": "bayern", "1": "berlin", "2": "hamburg")
#let wappen = {
  let custom = shown.at("custom", default: none)
  let key = if type(custom) == dictionary { custom.at("wappen", default: none) }
  if type(key) != str or key not in arms {
    let who = data.party(shown.at("recipient", default: none))
    let plz = who.at("post-code", default: none)
    key = if type(plz) == str and plz != "" {
      arms-by-plz.at(plz.first(), default: none)
    }
  }
  let file = if type(key) == str and key in arms { arms.at(key) } else {
    "wappen/neutral.svg"
  }
  image(file, alt: "Wappen")
}

#show: invoice.with(
  data: record,
  // design: never data
  theme: theme.classic.with(theme.custom.logo(image: wappen, height: 18mm)),
  locale: locale.de-de,
  zugferd: "en16931",
  // issuer: kept unless the data gives `sender`
  sender: (
    name: "Entsorgung Süd GmbH",
    address: "Industriestraße 7",
    city: "80339 München",
    country: "DE",
    vat-id: "DE123456789",
    contact: (
      name: "Buchhaltung",
      phone: "+49 89 1234567",
      email: "rechnung@entsorgung-sued.example",
    ),
  ),
  ..sample,
)

Tarif: #info.get("custom", "tarif", default: "Standard")

#line-items[
  #item("Leerung Restmüll 120 l", quantity: 4, unit: unit.pcs, price: 12.5)
  #item("Sperrmüllabholung", price: 45)
]

#payment(
  terms: (days: 14),
  bank: (
    bank: "Musterbank",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  ),
  creditor-id: "DE98ZZZ09999999999",
)

#signature()
