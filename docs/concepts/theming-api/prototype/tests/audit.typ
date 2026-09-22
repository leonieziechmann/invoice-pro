// Audit-stage regressions (every assertion runs on the real view inside a part wrap):
// plural unit names follow the item's quantity; dict item-ids reach the view;
// locale.custom.summary sets prepayment/amount-due; font chains end in an embedded
// family.  --input case=view (default)
#import "/src/lib.typ": *

#let has(c, s) = repr(c).contains(s)
#let check(ctx, view) = {
  let items = view.entries.filter(e => e.kind == "item")
  // plural units: 2,5 h -> "Stunden", 1 h -> "Stunde", 3 pieces -> "Stück" (invariant)
  assert(
    has(items.at(0).unit, "Stunden"),
    message: "2.5 hours: " + repr(items.at(0).unit),
  )
  assert(
    has(items.at(1).unit, "Stunde") and not has(items.at(1).unit, "Stunden"),
    message: "1 hour: " + repr(items.at(1).unit),
  )
  // item-id: a dict keeps its keys; a string is the standard id (GTIN, ..)
  assert.eq(items.at(0).item-id, (seller: "S-1", buyer: none, standard: none))
  assert.eq(items.at(1).item-id, (
    seller: none,
    buyer: none,
    standard: "4012345678901",
  ))
  assert.eq(items.at(2).item-id, (seller: "S-3", buyer: "B-3", standard: none))
  // locale.custom.summary(prepayment:, amount-due:)
  let s = ctx.locale.strings.summary
  assert.eq(s.prepayment, "Vorauszahlung")
  assert.eq(s.amount-due, "Restbetrag")
  theme.parts.items-table(ctx, view)
}

// font chains end in a family embedded in Typst (Libertinus Serif)
#let env = (kind: "invoice", lang: "de", region: "de", e-invoice: none)
#for p in ("classic", "plain", "corporate", "boxed") {
  let f = theme.resolve(dictionary(theme).at(p), env: env).tokens.fonts
  assert.eq(f.body.last(), "Libertinus Serif", message: p)
  assert.eq(f.regulated.last(), "Libertinus Serif", message: p)
}

#show: invoice.with(
  theme: theme.classic.with(theme.custom.part("items-table", check)),
  locale: locale.de-de.with(locale.custom.summary(
    prepayment: "Vorauszahlung",
    amount-due: "Restbetrag",
  )),
  sender: (
    name: "A GmbH",
    address: "Weg 1",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (name: "B AG", address: "Weg 2", city: "80331 München"),
  invoice-nr: "1",
  validation: "strict",
)
#line-items[
  #item([Beratung], price: 100, quantity: 2.5, unit: unit.hour, item-id: (
    seller: "S-1",
  ))
  #item(
    [Nacharbeit],
    price: 100,
    quantity: 1,
    unit: unit.hour,
    item-id: "4012345678901",
  )
  #item([Schrauben], price: 1, quantity: 3, item-id: (
    seller: "S-3",
    buyer: "B-3",
  ))
]
