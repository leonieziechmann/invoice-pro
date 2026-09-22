// Continuation header: sender · subject (one line, shortened with an ellipsis) and
// the number on the right; the logo gets a plate on a dark letterhead.
//   --input layout=<name>
#import "/tests/body.typ": *
#let lay = sys.inputs.at("layout", default: "us-letter-10")
#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(logo: logo-img),
    theme.custom.area(
      "letterhead",
      fill: rgb("#0f766e"),
      text: (fill: white),
      inset: (x: 3mm, y: 2mm),
    ),
    layout: dictionary(theme.layout).at(lay),
  ),
  locale: test-locale,
  ..party,
  subject: "Sprint 14 and platform operations, including the migration of the reporting cluster and on-call support in September",
)
#body(n: 30)
