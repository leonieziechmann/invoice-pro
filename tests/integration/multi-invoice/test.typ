// Several invoices in one document are rendered one after another. Each one
// keeps its own page roles, page numbers and draft feedback: the second
// invoice starts with its letterhead (not the continuation header of the
// first), numbers its pages from 1, and each draft report lists only the
// issues of its own invoice.

#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

// Records the page role the frame hands to the page number and the
// continuation header, together with the physical page.
#let recording = theme.classic.with(
  theme.custom.fonts(body: "libertinus serif"),
  theme.custom.wrap("page-number", (ctx, view, inner) => {
    [#metadata((part: "page-number", ..view.page))<role>]
    inner(ctx, view)
  }),
  theme.custom.wrap("continuation", (ctx, view, inner) => {
    [#metadata((part: "continuation", ..view.page))<role>]
    inner(ctx, view)
  }),
)

#let sender = (
  name: "Test Sender GmbH",
  address: "Street 1",
  city: "12345 City",
  vat-id: "DE123456789",
)
#let recipient = (
  name: "Test Recipient",
  address: "Street 2",
  city: "54321 Town",
)

#let items(n) = line-items(
  range(n).map(i => item([Item #(i + 1)], price: 10)).join(),
)

// 1. a draft (no invoice number) over two pages
#invoice(
  theme: recording,
  locale: test-locale,
  sender: sender,
  recipient: recipient,
  items(40),
)
// 2. a complete invoice
#invoice(
  theme: recording,
  locale: test-locale,
  sender: sender,
  recipient: recipient,
  invoice-nr: "INV-2",
  items(3),
)
// 3. a draft without invoice number and recipient address
#invoice(
  theme: recording,
  locale: test-locale,
  sender: sender,
  recipient: (name: "Test Recipient"),
  items(3),
)

#context {
  // the first layout pass has no locations yet
  if query(<ip-invoice-start>).len() == 0 { return }
  let ends = query(<ip-invoice-end>).len()
  assert.eq(
    ends,
    3,
    message: "Invoice end markers: expected 3, got " + str(ends),
  )

  // one draft report per incomplete invoice, each with its own issues
  let reports = query(<ip-report>).map(m => m.value)
  assert.eq(
    reports,
    (1, 3),
    message: "Reports: expected (1, 3), got " + repr(reports),
  )
  let issues(k) = query(<ip-issue>)
    .map(m => m.value)
    .filter(x => x.instance == k)
    .map(x => x.id)
    .dedup()
    .sorted()
  assert.eq(
    issues(1),
    ("invoice-number",),
    message: "Invoice 1 issues: got " + repr(issues(1)),
  )
  assert.eq(issues(2), (), message: "Invoice 2 issues: got " + repr(issues(2)))
  assert.eq(
    issues(3),
    ("invoice-number", "recipient-address"),
    message: "Invoice 3 issues: got " + repr(issues(3)),
  )

  // page roles are relative to each invoice
  let starts = query(<ip-invoice-start>).map(m => m.location().page())
  let invoice-of(p) = starts.filter(s => s <= p).len()
  let roles = query(<role>).map(m => (
    invoice: invoice-of(m.location().page()),
    ..m.value,
  ))
  let numbers(k) = roles
    .filter(r => r.invoice == k and r.part == "page-number")
    .map(r => (r.current, r.total))
  assert.eq(
    numbers(1),
    ((1, 2), (2, 2)),
    message: "Invoice 1 page numbers: got " + repr(numbers(1)),
  )
  assert.eq(
    numbers(2),
    ((1, 1),),
    message: "Invoice 2 page numbers: got " + repr(numbers(2)),
  )
  assert.eq(
    numbers(3),
    ((1, 1),),
    message: "Invoice 3 page numbers: got " + repr(numbers(3)),
  )
  // the continuation header appears on following pages only
  let continued = roles.filter(r => r.part == "continuation")
  assert(
    continued.all(r => r.current > 1),
    message: "Continuation header on a first page: " + repr(continued),
  )
  assert.eq(
    continued.map(r => r.invoice),
    (1,),
    message: "Continuation header: expected only on invoice 1, got "
      + repr(continued),
  )
}
