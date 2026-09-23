// Several `locale.custom` overrides in one code block all apply, as the
// locale documentation shows. Each function returned a dictionary
// `(strings: ..)` or `(region: ..)`, and a code block merges dictionaries:
// the last override replaced the others without notice.

#import "/src/lib.typ": *
#import "/src/locale/lang/base.typ": base-language
#import "/src/locale/region/base.typ": base-region

#let build(locale) = locale(base-language, base-region)

// --- 1. The example of the documentation: two language overrides ---
#{
  let built = build(locale.en-de.with({
    import locale.custom: *

    document(invoice: "Proforma Invoice")
    line-items(position: "Pos.", unit-price: "Price/Unit")
  }))
  assert.eq(built.strings.document.invoice, "Proforma Invoice")
  assert.eq(built.strings.line-items.position, "Pos.")
  assert.eq(built.strings.line-items.unit-price, "Price/Unit")
  // Keys that are not overridden keep the text of the language
  assert.eq(built.strings.line-items.total, "Total")
}

// --- 2. Language and region overrides together ---
#{
  let built = build(locale.de-de.with({
    import locale.custom: *

    payment(deadline-soon: "umgehend")
    payment-means(cash: "Bar")
    format(currency: value => str(value) + " EUR")
  }))
  assert.eq(built.strings.payment.deadline-soon, "umgehend")
  assert.eq(built.strings.payment-means.cash, "Bar")
  assert.eq((built.format.currency)(2), "2 EUR")
  // Later overrides of the same group win, key by key
  let later = build(locale.de-de.with({
    import locale.custom: *

    payment(deadline-soon: "umgehend", deadline-days: days => "in " + str(days))
    payment(deadline-soon: "sofort")
  }))
  assert.eq(later.strings.payment.deadline-soon, "sofort")
  assert.eq((later.strings.payment.deadline-days)(3), "in 3")
}

// --- 3. Overrides as separate arguments, or a single one ---
#{
  let built = build(locale.en-de.with(
    locale.custom.document(invoice: "Proforma Invoice"),
    locale.custom.summary(total: "Grand Total"),
  ))
  assert.eq(built.strings.document.invoice, "Proforma Invoice")
  assert.eq(built.strings.summary.total, "Grand Total")
  let single = build(locale.en-de.with(
    locale.custom.legal(
      vat-exemption: "No VAT.",
    ),
  ))
  assert.eq(single.strings.legal.vat-exemption, "No VAT.")
}
