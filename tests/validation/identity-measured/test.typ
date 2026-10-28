// The identity check after layout (prototype tests/api-frame/identity.typ,
// --input mode=measured): a number that is only measured, never typeset, is still
// found. Strict panics after layout, where `catch` cannot see it: the draft issue
// carries the strict message.
#import "/tests/theme/identity.typ": identity-invoice, measured

#identity-invoice(measured)
#context {
  let issues = query(<ip-issue>).map(m => m.value)
  assert.eq(issues.map(x => x.id), ("theme/identity-number",))
  assert.eq(
    issues.first().message,
    "theme: the invoice number (2026-0142) does not appear in the first-page content; the area hosting `title` must render view.document.number (§ 14 UStG; EN 16931 BT-1)",
  )
}
