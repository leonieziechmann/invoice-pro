// compat-014: PDF/UA-1 and PDF/A-3b per built-in look, image logo WITH alt text.
//   --input look=classic|corporate|boxed|plain|minimal  --input zugferd=basic|none
#import "/tests/doc/prelude.typ": *
#import "/tests/looks.typ": minimal
#let look = sys.inputs.at("look", default: "classic")
#let zf = sys.inputs.at("zugferd", default: "none")
#let preset = if look == "minimal" { minimal } else {
  dictionary(theme).at(look)
}
// XRechnung/EN 16931 needs BT-10 and seller contact (core checks, not theme checks).
#let party = if zf == "en16931" {
  (
    party
      + (
        recipient: party.recipient + (buyer-reference: "04011000-12345-34"),
        sender: party.sender
          + (contact-name: "Lina Berg", phone: "+49 40 1234567"),
      )
  )
} else { party }
#show: invoice.with(
  locale: locale.de-de,
  ..party,
  zugferd: if zf == "none" { none } else { zf },
  theme: preset.with(theme.custom.brand(
    color: rgb("#00843d"),
    logo: image("/tests/doc/sw.svg", alt: "Stadtwerke Musterstadt"),
  )),
)
#body()
