/// [ppi: 40]

// Print proof of `sn-010130-left` (prototype tests/proof.typ, concept §8.3): each
// declared envelope window in both extreme positions, the band that always shows,
// the fold and punch lines and the recipient box (green when >= 5 lines show in
// every envelope; US #10: 4 by design). One invoice per document: the overlay
// draws the windows on its first page.
#import "/tests/theme/body.typ": *

#show: invoice.with(
  theme: theme.classic.with(
    layout: theme.layout.sn-010130-left,
    theme.custom.proof(true),
  ),
  locale: test-locale,
  ..party,
)
#body(n: 4)
