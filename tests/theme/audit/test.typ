/// [ppi: 12]

// Audit-stage regressions (prototype tests/audit.typ, tests/audit/*.typ,
// scripts/checks-audit.sh):
// - plural unit names follow the item's quantity, dict item-ids reach the view,
//   locale.custom.summary sets prepayment/amount-due, and the font chains end in
//   an embedded family (every assertion runs on the real view inside a part);
// - an invalid IBAN is a data issue, never a renderer panic: draft renders it
//   (six looks) and withholds the XML, none renders, strict stops with the data
//   message;
// - en16931 between two German parties is checked as XRechnung, and the
//   messages name both profiles.
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
  // item-id: a dict keeps its keys; a string is the seller's article number
  assert.eq(items.at(0).item-id, (seller: "S-1", buyer: none, standard: none))
  assert.eq(items.at(1).item-id, (
    seller: "ART-4711",
    buyer: none,
    standard: none,
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

#import "/tests/theme/body.typ": party
#import "/tests/theme/harness.typ": case, close-cases, in-case, issues-of
#import "/tests/test-locale.typ": test-locale

#case(
  "view",
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
  [
    #line-items[
      #item([Beratung], price: 100, quantity: 2.5, unit: unit.hour, item-id: (
        seller: "S-1",
      ))
      #item(
        [Nacharbeit],
        price: 100,
        quantity: 1,
        unit: unit.hour,
        item-id: "ART-4711",
      )
      #item([Schrauben], price: 1, quantity: 3, item-id: (
        seller: "S-3",
        buyer: "B-3",
      ))
    ]],
)

// an invalid IBAN: draft in six looks (the XML is withheld), none renders
#let bad-iban(look, validation: "draft", zugferd: none) = case(
  "iban/" + look + "/" + (if validation == none { "none" } else { validation }),
  theme: dictionary(theme).at(look),
  locale: test-locale,
  ..party,
  validation: validation,
  zugferd: zugferd,
  [
    #line-items[#item([X], price: 10)]
    #bank-details(
      iban: "DE00 1234 5678 9012 3456 78",
      bic: "COBADEFFXXX",
      bank: "Bank",
    )
  ],
)
#let looks = ("classic", "corporate", "elegant", "soft", "compact", "boxed")
#for look in looks { bad-iban(look, zugferd: if look == "classic" { "basic" }) }
#bad-iban("classic", validation: none)
#close-cases()
#context {
  for look in looks {
    let ids = issues-of("iban/" + look + "/draft").map(x => x.id)
    assert(ids == ("iban",), message: look + ": " + repr(ids))
  }
  assert.eq(issues-of("iban/classic/none"), ())
  // draft withholds the XML while the IBAN is invalid (a data issue)
  assert.eq(query(pdf.attach), ())
}
#assert.eq(
  catch(() => invoice(locale: test-locale, validation: "strict", ..party, [
    #line-items[#item([X], price: 10)]
    #bank-details(
      iban: "DE00 1234 5678 9012 3456 78",
      bic: "COBADEFFXXX",
      bank: "Bank",
    )
  ])),
  "panicked with: "
    + repr(
      "bank-details::iban `DE00 1234 5678 9012 3456 78` is not a valid IBAN (ISO 13616 check digits)",
    ),
)

// en16931 between German parties is applied as XRechnung
#assert.eq(
  catch(() => invoice(
    sender: (
      name: "A GmbH",
      address: "Weg 1",
      city: "20457 Hamburg",
      vat-id: "DE123456789",
      email: "a@b.de",
    ),
    recipient: (
      name: "B AG",
      address: "Weg 2",
      city: "80331 München",
      email: "c@d.de",
    ),
    invoice-nr: "1",
    zugferd: "en16931",
    validation: "strict",
    [#line-items[#item([X], price: 10)]],
  )),
  "panicked with: "
    + repr(
      "invoice-pro found 3 problems (validation: \"strict\"; preview them with validation: \"draft\" or --input invoice-pro-validation=draft):
  1. e-invoicing (profile 'en16931' applied as 'xrechnung') requires a buyer reference (BT-10). Set 'buyer-reference' or 'leitweg-id' on the recipient.
  2. e-invoicing (profile 'en16931' applied as 'xrechnung') requires a seller contact name (BT-41). Set 'contact.name' or 'contact-name' on the sender.
  3. e-invoicing (profile 'en16931' applied as 'xrechnung') requires a seller contact phone number (BT-42). Set 'contact.phone' or 'phone' on the sender.",
    ),
)
