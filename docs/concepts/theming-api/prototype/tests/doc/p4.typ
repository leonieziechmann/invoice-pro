#import "prelude.typ": *
#let e = toml("nordlicht.toml")
#show: invoice.with(
  theme: theme.corporate.with(theme.custom.from-data(
    e.theme,
    assets: p => image(p, alt: e.sender.name),
  )),
  locale: locale.de-de,
  ..party,
  sender: party.sender + e.sender,
)
#body()
