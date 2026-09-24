// Printed = written (concept 4.2): whether the data model of the e-invoice
// states the amounts and quantities the invoice computed and prints
// (IP-PRINT-01, IP-CALC-01, IP-CALC-02 and, in XRechnung,
// PEPPOL-EN16931-R120, which equivalence-detail.typ describes and reports).
//
// The model takes these values over from the computed invoice (the line
// items' `item-data` and the totals it prints), so with net prices they are
// the same values. Every e-invoice compares them here in one pass; the
// detailed check loads only when a value differs, or for the invoices that
// need it anyway: with gross prices (the net amounts are derived from the
// printed gross ones), with allowances or charges (of a line, or of the
// document, split per VAT group), and an XRechnung in a currency without
// cents (whose lines PEPPOL-EN16931-R120 checks).

#let _zero = decimal("0")

/// The findings of the invariants for the data model `model` of the
/// computed invoice `item-data` (the line items' data), whose totals the
/// invoice prints as `printed` (`ctx.global.total`: net, gross, prepaid,
/// due), in the order of the checks (see equivalence-detail.typ).
///
/// -> array
#let findings(model, item-data, printed) = {
  let items = item-data.at("items", default: ())
  let taxes = item-data.at("taxes", default: (:))
  let lines = model.lines
  let digits = model.at("currency-decimals", default: 2)
  let same = (
    model.tax-mode != "inclusive"
      and item-data.at("discounts", default: ()) == ()
      and item-data.at("surcharges", default: ()) == ()
      and model.allowance-charges == ()
      and lines.len() == items.len()
      and model.taxes.len() == taxes.len()
      and not (
        model.profile.at("xrechnung", default: false)
          and type(digits) == int
          and digits < 2
      )
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
