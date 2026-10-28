// themed(..) findings follow the level (prototype tests/validation/themed.typ):
// draft emits them (prefixed ids, the report lists them), strict stops with the
// scoped findings.
#import "/tests/theme/body.typ": *

#let scoped = themed.with(
  theme.custom.checks(min-contrast: 4.5),
  theme.custom.colors(text-muted: rgb("#f472b6")),
)
#show: invoice.with(locale: test-locale, ..party, validation: "draft")
#scoped[#body()]
#context {
  let ids = query(<ip-issue>).map(m => m.value.id).dedup()
  assert.eq(ids.len(), 2, message: repr(ids))
  assert(ids.all(i => i.starts-with("themed/")), message: repr(ids))
}
#assert.eq(
  catch(() => invoice(locale: test-locale, ..party, validation: "strict", [
    #scoped[#body()]
  ])),
  "panicked with: "
    + repr(
      "invoice-pro found 2 problems (validation: \"strict\"; preview them with validation: \"draft\" or --input invoice-pro-validation=draft):
  1. theme: colors::text-muted on colors::background has contrast 2.65:1, below checks.min-contrast 4.5:1
  2. theme: colors::text-muted on colors::tint has contrast 2.15:1, below checks.min-contrast 4.5:1",
    ),
)
