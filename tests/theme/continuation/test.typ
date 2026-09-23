/// [ppi: 40]

// Continuation header (prototype tests/api-frame/continuation.typ, run under
// strict): sender · subject on one line (shortened with an ellipsis) and the
// number on the right, above a separator, on page 2; on page 1 the logo gets a
// light plate on the dark letterhead. US Letter #10.
#import "/tests/theme/body.typ": *

#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(logo: logo-img),
    theme.custom.area(
      "letterhead",
      fill: rgb("#0f766e"),
      text: (fill: white),
      inset: (x: 3mm, y: 2mm),
    ),
    layout: theme.layout.us-letter-10,
  ),
  locale: test-locale,
  validation: "strict",
  ..party,
  subject: "Sprint 14 and platform operations, including the migration of the reporting cluster and on-call support in September",
)
#body(n: 30)
