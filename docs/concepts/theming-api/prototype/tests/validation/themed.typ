// themed(..) findings follow the level: draft emits them (prefixed ids), strict panics.
#import "/tests/body.typ": *
#show: invoice.with(locale: test-locale, ..party, validation: sys.inputs.at(
  "lv",
  default: "draft",
))
#themed(theme.custom.checks(min-contrast: 4.5), theme.custom.colors(
  text-muted: rgb("#f472b6"),
))[#body()]
#context assert.eq(
  query(<ip-issue>).map(m => m.value.id).dedup().len(),
  if sys.inputs.at("lv", default: "draft") == "draft" { 2 } else { 0 },
)
