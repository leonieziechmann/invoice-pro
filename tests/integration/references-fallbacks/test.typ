// The reference signs and `info` fall back to the keys of the recipient, as
// the e-invoice does: the context of an invoice holds every parameter of
// `invoice`, most of them as `none`, so `ctx.at(key, default: ..)` never
// reached the recipient's `customer-nr`, `order-nr`, `contract-nr` or
// `delivery-note-nr`. An identifier of the `id` module is printed as its
// `id`, never as the dictionary of the typed identifier.

#import "/src/lib.typ": *
#import "/src/loom-wrapper.typ": motif
#import "/src/utils/text.typ": plain-text

// Records the text of its body as drawn (the `info` values are text by then).
#let drawn-text(body) = motif(
  scope: ctx => ctx,
  measure: (_, children) => (children, none),
  draw: (ctx, _, _, body) => [#metadata(plain-text(body))<fallback-text>#body],
  body,
)

// An invoice whose printed references (the context of its `title` part) and
// the text of its drawn body are handed to `check` after it. The invoices are
// bare fixtures, so validation is off.
#let check-invoice(check, ..args, body) = {
  invoice(
    theme: theme.plain.with(theme.custom.wrap("title", (ctx, view, inner) => {
      [#metadata(ctx.references)<fallback-references>]
      inner(ctx, view)
    })),
    locale: locale.en-de,
    validation: none,
    sender: (name: "Seller GmbH", address: "Street 1", city: "10115 Berlin"),
    invoice-nr: "RE-1",
    date: datetime(year: 2026, month: 9, day: 1),
    ..args,
  )[#drawn-text(body)]
  context {
    let refs = query(selector(<fallback-references>).before(here()))
    let text = query(selector(<fallback-text>).before(here()))
    // Introspection is empty in the first layout iteration.
    if refs.len() > 0 and text.len() > 0 {
      check(refs.last().value, text.last().value)
      [#metadata(none)<fallback-checked>]
    }
  }
}

#let recipient = (
  name: "Buyer AG",
  address: "Road 2",
  city: "80331 München",
  customer-nr: "KD-4711",
  order-nr: "PO-1",
  contract-nr: "CTR-7",
  delivery-note-nr: "LS-9",
  // An empty buyer reference of imported data counts as not given
  buyer-reference: "",
  leitweg-id: id.leitweg("04011000-1234512345-06"),
)

#let all-references = (
  references.customer-nr(),
  references.order-nr(),
  references.contract-nr(),
  references.delivery-note-nr(),
  references.buyer-reference(),
)

// --- 1. The keys of the recipient ---
#[
  #check-invoice(
    recipient: recipient,
    references: all-references,
    (refs, text) => {
      assert.eq(refs, (
        ("Customer No.", "KD-4711"),
        ("Order No.", "PO-1"),
        ("Contract No.", "CTR-7"),
        ("Delivery Note No.", "LS-9"),
        ("Buyer Reference", "04011000-1234512345-06"),
      ))
      assert.eq(
        text,
        "Customer: KD-4711 Order: PO-1 Contract: CTR-7 Delivery note: LS-9 Buyer reference: 04011000-1234512345-06",
      )
    },
  )[Customer: #info.customer-nr Order: #info.order-nr Contract: #info.contract-nr Delivery note: #info.delivery-note-nr Buyer reference: #info.buyer-reference]
]

// --- 2. The invoice's own values come first ---
#[
  #check-invoice(
    recipient: recipient,
    customer-nr: "KD-1",
    order-nr: "PO-2",
    contract-nr: "CTR-8",
    delivery-note-nr: "LS-10",
    references: all-references.slice(0, 4),
    (refs, text) => {
      assert.eq(refs.map(ref => ref.last()), ("KD-1", "PO-2", "CTR-8", "LS-10"))
      assert.eq(text, "KD-1 PO-2")
    },
  )[#info.customer-nr #info.order-nr]
]

// --- 3. The identifier of the recipient as customer number ---
#[
  #check-invoice(
    recipient: (
      name: "Buyer AG",
      address: "Road 2",
      city: "80331 München",
      id: id.gln("4000001123452"),
    ),
    references: (references.customer-nr(),),
    (refs, text) => {
      assert.eq(refs, (("Customer No.", "4000001123452"),))
      assert.eq(text, "4000001123452")
    },
  )[#info.customer-nr]
]

// Every scenario above must have run its check.
#context assert.eq(query(<fallback-checked>).len(), 3)
