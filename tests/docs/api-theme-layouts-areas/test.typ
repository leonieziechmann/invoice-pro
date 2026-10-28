// Source: docs/docs/api-reference/theme/layouts.md — "Patching Areas"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    brand(logo: image("logo.svg", alt: "Atelier Nord"))
    area("letterhead", parts: ("sender", "logo")) // the logo moves to the right
    area("references", none) // no reference row above the title ..
    area("info", parts: ("sender-details", "reference-list")) // .. the references go next to the address
    area("continuation", none) // no header on following pages
    area("footer", text: (size: 6.5pt))
  }),
  ..party,
)
#body()
