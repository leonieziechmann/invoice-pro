// Source: docs/docs/api-reference/theme/parts.md — "Custom Parts and Areas (content cells)"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.classic.with(
    layout: theme.layout.us-letter-10,
    theme.custom.area("footer", arrange: (columns: (1fr, 1fr, 1fr)), parts: (
      [*Remit to:* #info.sender.name, PO Box 12, Austin TX],
      [billing\@acme.com],
      "registration",
    )),
  ),
  ..party,
)
#body()
