#import "prelude.typ": *
// layout: auto (the default) follows the SENDER's country: AT -> din-5008-b
#let vienna = (address: "Kärntner Ring 5", city: "1010 Wien", country: "AT")
#show: invoice.with(
  locale: locale.de-at,
  ..party,
  sender: party.sender + vienna,
  theme: theme.classic, // pin one: theme.classic.with(layout: ..)
)
#body()
