// The identity check counts a value only where it is typeset as a whole: a
// title part that renders only the date 16.10.2026 does not render the invoice
// number 16, although the date begins with it.
#import "/tests/theme/identity.typ": date-only, identity-invoice

#identity-invoice(
  date-only,
  invoice-nr: "16",
  date: datetime(year: 2026, month: 10, day: 16),
)
#context {
  let issues = query(<ip-issue>).map(m => m.value)
  assert.eq(issues.map(x => x.id), ("theme/identity-number",))
}
