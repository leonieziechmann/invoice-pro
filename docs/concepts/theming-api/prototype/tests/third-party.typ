#import "/tests/body.typ": *
#import "@local/acme-theme:0.1.0" as acme
#show: invoice.with(
  theme: theme.classic.with(acme.patch, layout: acme.sidebar-a5),
  locale: test-locale,
  ..party,
)
#body(n: 4)
