// The identity check after layout (prototype tests/errors/err.typ case 25 and
// tests/api-frame/identity.typ --input mode=date): a title part that renders
// neither the invoice number nor the date. Strict panics after layout (with the
// number, the first finding), where `catch` cannot see it: the draft issues
// carry the strict messages.
#import "/tests/theme/identity.typ": identity-invoice

#identity-invoice((ctx, view) => [Dear customer])
#context {
  let issues = query(<ip-issue>).map(m => m.value)
  assert.eq(
    issues.map(x => x.id),
    ("theme/identity-number", "theme/identity-date"),
  )
  assert.eq(
    issues.first().message,
    "theme: the invoice number (2026-0142) does not appear in the first-page content; the area hosting `title` must render view.document.number (§ 14 UStG; EN 16931 BT-1)",
  )
  assert(
    issues.last().message.starts-with("theme: the invoice date ("),
    message: issues.last().message,
  )
}
