// The invariants of the test oracle (printed = written): the data model of
// the e-invoice states the amounts and quantities the invoice computed and
// prints (IP-PRINT-01, IP-CALC-01, IP-CALC-02), and its sums hold (BR-CO-17
// and BR-*-08).
//
// The model takes these values over from the computed invoice (the line
// items' `item-data` and the totals it prints), so with net prices they are
// the same values and a finding is a bug in invoice-pro. `findings` compares
// them in one pass; the detailed check (equivalence-detail.typ) loads only
// when a value differs, or for the invoices that need it anyway: with gross
// prices (the net amounts are derived from the printed gross ones) and with
// allowances or charges (of a line, or of the document, split per VAT
// group).

#import "/src/zugferd/rules/engine.typ": tax-field
#import "/src/zugferd/xml.typ": rate-digits

#let _zero = decimal("0")
#let _one = decimal("1")

/// The findings of printed = written for the data model `model` of the
/// computed invoice `item-data` (the line items' data), whose totals the
/// invoice prints as `printed` (`ctx.global.total`: net, gross, prepaid,
/// due), in the order of the checks (see equivalence-detail.typ).
///
/// -> array
#let findings(model, item-data, printed) = {
  let items = item-data.at("items", default: ())
  let taxes = item-data.at("taxes", default: (:))
  let lines = model.lines
  let same = (
    model.tax-mode != "inclusive"
      and item-data.at("discounts", default: ()) == ()
      and item-data.at("surcharges", default: ()) == ()
      and model.allowance-charges == ()
      and lines.len() == items.len()
      and model.taxes.len() == taxes.len()
  )
  // Each line states its item, and the lines add up per VAT group (or all
  // of them, with one group).
  let sums = (:)
  for key in taxes.keys() { sums.insert(key, _zero) }
  let single = sums.len() == 1
  let total = _zero
  if same {
    for (line, item) in lines.zip(items) {
      if (
        (
          line.net,
          line.base-quantity,
          line.price,
          line.quantity,
          line.allowances,
          line.charges,
          item.discounts,
          item.surcharge,
        )
          != (
            item.total,
            item.base-quantity,
            item.price,
            item.quantity,
            (),
            (),
            (),
            (),
          )
      ) {
        same = false
        break
      }
      total += item.total
      if not single and line.key != none and line.key in sums {
        sums.at(line.key) += item.total
      }
    }
  }
  if single { sums.at(sums.keys().first()) += total }
  // Each VAT group states its printed amounts, which its lines add up to.
  if same {
    for tax in model.taxes {
      let group = taxes.at(tax.key, default: none)
      if (
        group == none
          or (tax.basis, tax.amount, tax.rate, tax.category, sums.at(tax.key))
            != (
              group.at("basis", default: _zero),
              group.at("absolute", default: _zero),
              group.at("rate", default: none),
              group.at("category", default: none),
              group.at("basis", default: _zero),
            )
      ) {
        same = false
        break
      }
    }
  }
  // The totals are those printed, and the lines add up to them.
  if same {
    let totals = model.totals
    let net = printed.at("net", default: _zero)
    let gross = printed.at("gross", default: _zero)
    let paid = model.payment.at("paid", default: false)
    same = (
      (
        totals.net,
        totals.tax,
        totals.gross,
        totals.prepaid,
        totals.due,
        totals.line - totals.allowance + totals.charge,
      )
        == (
          net,
          gross - net,
          gross,
          if paid { gross } else { printed.at("prepaid", default: _zero) },
          if paid { _zero } else { printed.at("due", default: _zero) },
          net,
        )
    )
  }
  if same { return () }
  import "equivalence-detail.typ": detailed-findings
  detailed-findings(model, item-data, printed)
}

// BR-x-08 (the taxable amount of a VAT group) by VAT category.
#let _basis-rules = (
  S: "BR-S-08",
  Z: "BR-Z-08",
  E: "BR-E-08",
  AE: "BR-AE-08",
  K: "BR-IC-08",
  G: "BR-G-08",
  O: "BR-O-08",
  L: "BR-AF-08",
  M: "BR-AG-08",
)

/// The sums of a model: its VAT breakdown adds up to the printed total
/// without VAT (IP-PRINT-01), the VAT amount of each VAT group is its
/// taxable amount times its rate within 1 (BR-CO-17), and the lines,
/// allowances and charges of a VAT group add up to its taxable amount
/// (BR-*-08).
///
/// The oracle checks only models without errors of the rules, so the amounts
/// have no more decimals than the XML states (IP-DEC-02): the amounts of the
/// model are exactly those of the XML and are compared as they are.
///
/// -> array
#let consistency-findings(model, printed) = {
  let out = ()
  if model.profile.settlement {
    // IP-PRINT-01: the VAT breakdown (BT-116) adds up to the printed total
    // without VAT.
    let basis = _zero
    for tax in model.taxes { basis += tax.basis }
    let net = printed.at("net", default: _zero)
    if basis != net {
      out.push((
        key: "IP-PRINT-01",
        field: "line-items",
        term: "sum of the VAT taxable amounts (BT-116)",
        stated: basis,
        printed: net,
        rate: none,
      ))
    }
    // BR-CO-17: the VAT amount is the taxable amount times the rate the XML
    // states, within the tolerance of 1 the validators allow (the amounts of
    // gross prices are rounded differently). Categories not subject to VAT
    // (O) and rates the XML cannot state (IP-DEC-01) are left out.
    for tax in model.taxes {
      if tax.category == "O" or tax.rate == none { continue }
      let percent = calc.round(tax.rate * 100, digits: rate-digits)
      if percent != tax.rate * 100 { continue }
      let expected = calc.round(tax.basis * percent / 100, digits: 2)
      if calc.abs(tax.amount - expected) > 1 {
        out.push((
          key: "BR-CO-17",
          field: tax-field(tax),
          amount: tax.amount,
          basis: tax.basis,
          expected: expected,
        ))
      }
    }
  }
  if model.profile.lines and model.taxes != () {
    // The net amounts of the lines and the allowances and charges of each
    // VAT group, in one pass over the lines.
    let sums = (:)
    for line in model.lines {
      if type(line.key) == str {
        sums.insert(line.key, sums.at(line.key, default: _zero) + line.net)
      }
    }
    for e in model.allowance-charges {
      if type(e.key) == str {
        let amount = if e.charge { e.amount } else { -e.amount }
        sums.insert(e.key, sums.at(e.key, default: _zero) + amount)
      }
    }
    // BR-x-08 of each VAT category that has one (not B).
    for tax in model.taxes {
      if type(tax.key) != str or type(tax.category) != str { continue }
      let rule = _basis-rules.at(tax.category, default: none)
      if rule == none { continue }
      let amount = sums.at(tax.key, default: _zero)
      if amount != tax.basis {
        out.push((
          key: "vat-basis",
          id: rule,
          field: tax-field(tax),
          amount: amount,
          basis: tax.basis,
        ))
      }
    }
  }
  out
}

/// The findings of all invariants for the model of the computed invoice
/// `item-data`, whose totals the invoice prints as `printed`.
///
/// -> array
#let invariant-findings(model, item-data, printed) = (
  findings(model, item-data, printed) + consistency-findings(model, printed)
)

// A rate in percent, e.g. "19%".
#let _percent(rate) = str(rate * 100) + "%"

/// The messages of the findings of the invariants, by key: `(message,)`.
#let messages = (
  "BR-CO-17": f => (
    "The VAT amount "
      + str(f.amount)
      + " is not the taxable amount "
      + str(f.basis)
      + " times the rate ("
      + str(f.expected)
      + ").",
  ),
  "vat-basis": f => (
    "The lines of this VAT category add up to "
      + str(f.amount)
      + " instead of the taxable amount "
      + str(f.basis)
      + ".",
  ),
  // The e-invoice states what the invoice prints (`findings`, and the total
  // of the VAT breakdown in `consistency-findings`).
  "IP-PRINT-01": f => {
    let shown(value) = if value == none { "(none)" } else { str(value) }
    let stated = shown(f.stated)
    if f.rate != none and type(f.stated) == decimal {
      let gross = calc.round(f.stated * (1 + f.rate), digits: 2)
      stated += (
        " net, which with " + _percent(f.rate) + " VAT is " + str(gross)
      )
    }
    (
      "The e-invoice states the "
        + f.term
        + " "
        + stated
        + ", but the invoice prints "
        + shown(f.printed)
        + ".",
    )
  },
  "IP-CALC-01": f => (
    "The parts of this allowance or charge per VAT category add up to "
      + str(f.parts)
      + ", but it amounts to "
      + str(f.amount)
      + ".",
  ),
  "IP-CALC-02": f => (
    "The lines, allowances and charges of this VAT category add up to "
      + str(f.sum)
      + ", but the invoice prints its "
      + if f.gross { "gross total " } else { "taxable amount " }
      + str(f.expected)
      + ".",
  ),
)
