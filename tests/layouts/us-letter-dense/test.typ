/// [ppi: 60]

// The `us-letter-dense` layout with the classic look: the shared body (4 items),
// brand colour and logo, identical on every layout (prototype tests/matrix.typ).
#import "/tests/theme/body.typ": *

#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(color: rgb("#0f766e"), logo: logo-img),
    layout: theme.layout.us-letter-dense,
  ),
  locale: test-locale,
  ..party,
)
#body(n: 4)
