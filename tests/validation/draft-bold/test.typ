// validation: "draft" inside the `bold` look (prototype tests/presets-display.typ
// --input broken=1, scripts/checks-presets-display.sh): no invoice number and no
// seller tax ID; the markers render sensibly inside the look, and the report
// follows. One draft invoice per document: its markers link to its report.
#import "/tests/theme/display.typ": display-invoice

#display-invoice("bold", broken: true)
#context {
  let ids = query(<ip-issue>).map(m => m.value.id).dedup()
  assert.eq(ids, ("invoice-number", "sender-tax-id"))
  assert(query(<ip-report>).len() == 1, message: "no draft report")
}
