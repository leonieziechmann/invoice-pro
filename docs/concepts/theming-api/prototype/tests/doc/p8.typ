#import "prelude.typ": *
#import "corporate.typ": corporate // the same brand patch as in P2
#show: invoice.with(locale: locale.en-de, ..party, theme: theme.classic.with(
  corporate,
  layout: theme.layout.us-letter-10,
  theme.custom.area("footer", arrange: (columns: (1fr, 1fr, 1fr)), parts: (
    [*Remit to:* #info.sender.name, PO Box 12, Austin TX],
    [billing\@acme.com],
    "registration",
  )),
))
#body()
