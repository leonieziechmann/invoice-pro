// Printed = written: whether the e-invoice states what the invoice prints;
// equivalence-detail.typ checks in detail where needed.

#let _zero = decimal("0")
#let _one = decimal("1")
#let _slack = decimal("0.02")
#let _slack-huf = decimal("0.5")

/// The findings for the model of the computed invoice `item-data`, whose
/// totals the invoice prints as `printed` (`ctx.global.total`).
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
  let slack = if model.profile.at("xrechnung", default: false) {
    if model.currency == "HUF" { _slack-huf } else { _slack }
  }
  // Each line states its item.
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
      if slack != none {
        // Without a division for the common base quantity 1.
        let off = line.net - line.quantity * line.price
        if line.base-quantity != _one {
          off = line.net - line.quantity * line.price / line.base-quantity
        }
        if off > slack or off < -slack {
          same = false
          break
        }
      }
      total += item.total
      if not single and line.key != none and line.key in sums {
        sums.at(line.key) += item.total
      }
    }
  }
  if single { sums.at(sums.keys().first()) += total }
  // Each VAT group states its printed amounts.
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
  // The totals are those printed.
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
