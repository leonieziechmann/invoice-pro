// Print proof of every window layout: `--input layout=<name>` (default din-5008-b).
// The recipient box is green when it shows >= 5 lines in every declared envelope.
#import "/tests/body.typ": *
#let lay = sys.inputs.at("layout", default: "din-5008-b")
#let long = sys.inputs.at("long", default: "0") == "1"
#let party = (
  party
    + if long {
      (
        recipient: (
          name: [Muster Beteiligungsgesellschaft mbH \ z. Hd. Frau Dr. Erika Mustermann \ Abteilung Rechnungseingang],
          address: "Beispielweg 5",
          city: "80331 München",
        ),
      )
    } else { (:) }
)
#show: invoice.with(
  theme: theme.classic.with(
    layout: dictionary(theme.layout).at(lay),
    theme.custom.proof(true),
  ),
  locale: test-locale,
  ..party,
)
#body(n: 4)
