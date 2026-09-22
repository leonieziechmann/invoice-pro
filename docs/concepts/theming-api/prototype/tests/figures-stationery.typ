// fig-stationery: tests/doc/p2.typ with figure-grade art (a real wordmark for the
// generated letterhead and designed letterhead sheets instead of the test fixtures).
// --input output=print|pdf|einvoice  --input n=<items>
#import "/tests/doc/prelude.typ": *
#let mode = sys.inputs.at("output", default: "pdf")
#let svg(s, alt: "ACME Maschinenbau GmbH") = image(
  bytes(s),
  format: "svg",
  alt: alt,
)
#let navy = "#003a70"
#let red = "#e2001a"
#let wordmark = (
  "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 120 30'>"
    + "<rect x='0' y='3' width='24' height='24' fill='"
    + navy
    + "'/>"
    + "<rect x='15' y='3' width='9' height='9' fill='"
    + red
    + "'/>"
    + "<text x='30' y='20' font-family='Liberation Sans, Arial' font-size='17' font-weight='bold' fill='"
    + navy
    + "'>ACME</text>"
    + "<text x='30' y='28' font-family='Liberation Sans, Arial' font-size='5.6' letter-spacing='0.6' fill='#4a5568'>MASCHINENBAU GMBH</text>"
    + "</svg>"
)
#let sheet(first) = (
  "<svg xmlns='http://www.w3.org/2000/svg' width='210mm' height='297mm' viewBox='0 0 210 297'>"
    + "<rect x='0' y='0' width='210' height='4' fill='"
    + navy
    + "'/>"
    + (
      if first {
        (
          "<g transform='translate(25,12) scale(0.42)'>"
            + wordmark.slice(wordmark.position(">") + 1, wordmark.len() - 6)
            + "</g>"
            + "<text x='190' y='17' text-anchor='end' font-family='Liberation Sans, Arial' font-size='3.4' fill='#4a5568'>Präzision seit 1924</text>"
            + "<rect x='0' y='288.5' width='210' height='8.5' fill='"
            + navy
            + "'/>"
            + "<text x='25' y='293.7' font-family='Liberation Sans, Arial' font-size='2.8' fill='white'>ACME Maschinenbau GmbH · Industriestraße 4 · 70565 Stuttgart · Amtsgericht Stuttgart HRB 7311 · USt-IdNr. DE987654321</text>"
        )
      } else {
        (
          "<g transform='translate(166,8) scale(0.2)'>"
            + wordmark.slice(wordmark.position(">") + 1, wordmark.len() - 6)
            + "</g>"
            + "<rect x='0' y='293' width='210' height='4' fill='"
            + navy
            + "'/>"
        )
      }
    )
    + "</svg>"
)
#let acme = theme.custom.brand(
  color: rgb(navy),
  accent: rgb(red),
  font: ("Liberation Sans", "Libertinus Serif"),
  logo: svg(wordmark),
)
#show: invoice.with(
  theme: theme.classic.with(
    acme,
    theme.custom.logo(image: svg(wordmark), height: 13mm),
    layout: theme.layout.din-5008-b,
    {
      import theme.custom: *
      if mode == "print" { stationery("pre-printed") }
      if mode == "pdf" {
        stationery((first: svg(sheet(true)), rest: svg(sheet(false))))
        area("continuation", none) // the rest-page art carries its own header
      }
      if mode != "print" { marks(none) }
    },
  ),
  locale: locale.de-de,
  ..party,
  sender: (
    name: "ACME Maschinenbau GmbH",
    address: "Industriestraße 4",
    city: "70565 Stuttgart",
    vat-id: "DE987654321",
    register: [Amtsgericht Stuttgart HRB 7311],
    management: [GF: Dr. Jan Keller],
    extra: (Telefon: "+49 711 4455 0"),
  ),
  zugferd: if mode == "einvoice" { "basic" },
)
#body(n: int(sys.inputs.at("n", default: "4")))
