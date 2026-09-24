// Printed = written, in detail: the findings of the invariants that the
// e-invoice states the amounts and quantities the invoice computed and
// prints (concept 4.2). They compare the data model of the e-invoice, whose
// XML the write guard compares with it once more (../guard/roundtrip.typ),
// with the computed invoice it is a projection of: the items, allowances,
// charges and VAT groups of the line items (`item-data`) and the totals the
// invoice prints (`ctx.global.total`). A failure is a bug of invoice-pro (or
// of a component that computes one value for the print and another one for
// the e-invoice), never a mistake in the invoice data, so every finding is an
// error.
//
// - IP-PRINT-01: an amount or quantity of the XML differs from the printed
//   one: of a line (quantity, price, base quantity, net amount, allowances
//   and charges), of a document level allowance or charge, of a VAT group
//   (category, rate, taxable amount, VAT amount) or a total (net, VAT,
//   gross, prepaid, due); or the lines, allowances and charges of the XML do
//   not add up to the printed total without VAT. With gross prices, a net
//   amount plus VAT must give the printed gross amount within the rounding
//   of logic/net-amounts.typ: less than a unit of the currency, plus the
//   rounding of the printed taxable amount of its VAT group.
// - IP-CALC-01: the parts of a document level allowance or charge per VAT
//   group add up to its printed amount. A part may have the other sign: a
//   discount on a VAT group whose lines add up to a credit is stated as a
//   charge of that group (IP-PRINT-01 compares each part).
// - IP-CALC-02: the printed amounts of a VAT group add up to its printed
//   taxable amount (with gross prices: to its gross total).
// - PEPPOL-EN16931-R120 (XRechnung): a line's net amount is its quantity
//   times its net price per base quantity plus its charges minus its
//   allowances, within 0.02 (0.5 for HUF), as the XRechnung Schematron
//   checks it on the XML.
//
// equivalence.typ loads this module only for an invoice that needs it: one
// whose values differ from the printed ones at first sight, one with gross
// prices or with allowances or charges, and an XRechnung with a line that
// PEPPOL-EN16931-R120 reports.

#import "engine.typ": line-field, tax-field
#import "../model.typ": text-or-none

#let _zero = decimal("0")
#let _one = decimal("1")

// The decimals the net price of a gross price keeps at least (see
// `price-digits` of logic/net-amounts.typ): its tolerance.
#let _price-tolerance = decimal("0.000001")

// A finding of IP-PRINT-01: the `term` of `field` is `stated` in the XML and
// `printed` on the invoice; with gross prices, `rate` is the VAT rate the net
// amount `stated` is compared with the gross amount `printed` by.
#let _differs(field, term, stated, printed, rate: none) = (
  key: "IP-PRINT-01",
  field: field,
  term: term,
  stated: stated,
  printed: printed,
  rate: rate,
)

// The field of a document level allowance or charge, e.g. `discount
// (Coupon)`.
#let _modifier-field(modifier) = {
  let name = text-or-none(modifier.at("name", default: none))
  let kind = if modifier.at("absolute", default: _zero) < _zero {
    "discount"
  } else { "surcharge" }
  if name == none { kind } else { kind + " (" + name + ")" }
}

// The findings of a line of the model against its item: its values, its
// allowances and charges (in the order the item prints them: its discounts,
// then its surcharges) and, with `slack`, PEPPOL-EN16931-R120. `limit` is
// the tolerance of its net amount with gross prices (`none`: net prices),
// `unit` the smallest amount of the currency. Called per line with the line
// and its item only (concept 6.4).
#let _line-findings(line, item, limit, unit, slack) = {
  let out = ()
  let divisor = _one + line.rate
  // A negative price is stated as it is printed, or as a positive price of
  // a negative quantity (BR-27).
  let (price, quantity) = if item.price < _zero and line.price >= _zero {
    (-item.price, -item.quantity)
  } else { (item.price, item.quantity) }
  let rate = if limit != none { line.rate }
  // Each value: its term, what the XML states, what the invoice prints, and
  // whether they differ.
  for (term, stated, printed, off) in (
    (
      "invoiced quantity (BT-129)",
      line.quantity,
      quantity,
      line.quantity != quantity,
    ),
    (
      "price base quantity (BT-149)",
      line.base-quantity,
      item.base-quantity,
      line.base-quantity != item.base-quantity,
    ),
    (
      "item net price (BT-146)",
      line.price,
      price,
      if limit == none { line.price != price } else {
        calc.abs(line.price - price / divisor) > _price-tolerance
      },
    ),
    (
      "line net amount (BT-131)",
      line.net,
      item.total,
      if limit == none { line.net != item.total } else {
        calc.abs(line.net - item.total / divisor) > limit
      },
    ),
  ) {
    if off {
      out.push(_differs(
        line-field(line),
        term,
        stated,
        printed,
        rate: if term != "invoiced quantity (BT-129)" { rate },
      ))
    }
  }
  let stated = line.allowances + line.charges
  let listed = ()
  for adjustment in item.discounts + item.surcharge {
    if adjustment.absolute != _zero { listed.push(adjustment) }
  }
  if listed.len() != stated.len() {
    out.push(_differs(
      line-field(line),
      "number of allowances and charges of the line (BG-27, BG-28)",
      stated.len(),
      listed.len(),
    ))
  } else {
    for (entry, adjustment) in stated.zip(listed) {
      let amount = calc.abs(adjustment.absolute)
      if (
        if limit == none { entry.amount != amount } else {
          calc.abs(entry.amount - amount / divisor) >= unit
        }
      ) {
        out.push(_differs(
          line-field(line),
          if adjustment.absolute < _zero {
            "line allowance amount (BT-136)"
          } else { "line charge amount (BT-141)" },
          entry.amount,
          amount,
          rate: rate,
        ))
      }
    }
  }
  if slack != none {
    let expected = line.quantity * line.price / line.base-quantity
    for entry in line.charges { expected += entry.amount }
    for entry in line.allowances { expected -= entry.amount }
    let off = line.net - expected
    if off > slack or off < -slack {
      out.push((
        key: "PEPPOL-EN16931-R120",
        field: line-field(line),
        net: line.net,
        quantity: line.quantity,
        price: line.price,
        base-quantity: line.base-quantity,
        expected: expected,
        slack: slack,
      ))
    }
  }
  out
}

/// The findings of the invariants for the data model `model` of the
/// computed invoice `item-data` (the line items' data), whose totals the
/// invoice prints as `printed` (`ctx.global.total`: net, gross, prepaid,
/// due), in the order of the checks (see the top of this file).
/// PEPPOL-EN16931-R120 is checked if the profile is XRechnung.
///
/// -> array
#let detailed-findings(model, item-data, printed) = {
  let out = ()
  let items = item-data.at("items", default: ())
  let taxes = item-data.at("taxes", default: (:))
  let inclusive = model.tax-mode == "inclusive"
  let digits = model.at("currency-decimals", default: 2)
  let unit = calc.pow(
    decimal("10"),
    -(if type(digits) == int { digits } else { 2 }),
  )
  // The printed amounts of each VAT group: its lines and allowances and
  // charges (IP-CALC-02); with gross prices, how far a net amount may
  // differ from its gross amount divided by 1 + the rate (a unit, plus the
  // rounding of the printed taxable amount).
  let sums = (:)
  let tolerance = (:)
  for (key, tax) in taxes {
    sums.insert(key, _zero)
    if inclusive {
      let basis = tax.at("basis", default: _zero)
      let gross = basis + tax.at("absolute", default: _zero)
      let divisor = _one + tax.at("rate", default: _zero)
      tolerance.insert(key, unit + calc.abs(basis - gross / divisor))
    }
  }
  let slack = if model.profile.at("xrechnung", default: false) {
    if model.currency == "HUF" { decimal("0.5") } else { decimal("0.02") }
  }

  // --- Lines ------------------------------------------------------------------
  let lines = model.lines
  // Without a line per item, the lines cannot be compared, nor the sums of
  // the VAT groups (IP-CALC-02).
  let counted = lines.len() == items.len()
  if not counted {
    out.push(_differs(
      "line-items",
      "number of invoice lines (BG-25)",
      lines.len(),
      items.len(),
    ))
    lines = ()
  }
  // The printed amounts of the lines: per VAT group, or of all lines if
  // there is one group.
  let single = sums.len() == 1
  let total = _zero
  let limit = if inclusive and single { tolerance.values().first() }
  // PEPPOL-EN16931-R120 is checked on every line of an XRechnung: a line
  // total is its price times its quantity rounded with the `money` rounding
  // of the locale (logic/calc-item.typ), which can round more coarsely than
  // the slack allows, e.g. to whole yen or to 0.05.
  for (line, item) in lines.zip(items) {
    let net = item.total
    total += net
    if not single and line.key != none and line.key in sums {
      sums.at(line.key) += net
    }
    // The values of the line are those of the item (with gross prices, the
    // net ones within the rounding). A line that differs, has allowances or
    // charges, or a negative price (stated as a positive price of a
    // negative quantity, BR-27) is looked at in detail.
    let detailed = if inclusive {
      if not single {
        limit = if line.key != none {
          tolerance.at(line.key, default: unit)
        } else { unit }
      }
      let divisor = _one + line.rate
      let off = line.net - net / divisor
      let price = line.price - item.price / divisor
      (
        (
          line.quantity,
          line.base-quantity,
          line.allowances,
          line.charges,
          item.discounts,
          item.surcharge,
        )
          != (item.quantity, item.base-quantity, (), (), (), ())
          or off > limit
          or off < -limit
          or price > _price-tolerance
          or price < -_price-tolerance
      )
    } else {
      (
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
            net,
            item.base-quantity,
            item.price,
            item.quantity,
            (),
            (),
            (),
            (),
          )
      )
    }
    if not detailed and slack != none {
      let off = line.net - line.quantity * line.price / line.base-quantity
      detailed = off > slack or off < -slack
    }
    if detailed { out += _line-findings(line, item, limit, unit, slack) }
  }
  if single { sums.at(sums.keys().first()) += total }

  // --- Document level allowances and charges ---------------------------------
  let entries = model.allowance-charges
  let next = 0
  for modifier in (
    item-data.at("discounts", default: ())
      + item-data.at("surcharges", default: ())
  ) {
    let absolute = modifier.at("absolute", default: _zero)
    let parts = _zero
    for (key, part) in modifier.at("split", default: (:)) {
      let amount = part.at("absolute", default: _zero)
      parts += amount
      if key in sums { sums.at(key) += amount }
      if amount == _zero { continue }
      let entry = entries.at(next, default: none)
      next += 1
      let rate = part.at("tax", default: (:)).at("rate", default: _zero)
      if (
        entry == none
          or entry.key != key
          or entry.charge != (amount > _zero)
          or if inclusive {
            (
              calc.abs(entry.amount - calc.abs(amount) / (_one + rate))
                > tolerance.at(key, default: unit)
            )
          } else { entry.amount != calc.abs(amount) }
      ) {
        out.push(_differs(
          _modifier-field(modifier),
          if amount < _zero {
            "document level allowance amount (BT-92)"
          } else { "document level charge amount (BT-99)" },
          if entry != none { entry.amount },
          calc.abs(amount),
          rate: if inclusive { rate },
        ))
      }
    }
    if parts != absolute {
      out.push((
        key: "IP-CALC-01",
        field: _modifier-field(modifier),
        parts: parts,
        amount: absolute,
      ))
    }
  }
  if next != entries.len() {
    out.push(_differs(
      "line-items",
      "number of document level allowances and charges (BG-20, BG-21)",
      entries.len(),
      next,
    ))
  }

  // --- VAT breakdown ----------------------------------------------------------
  if model.taxes.len() != taxes.len() {
    out.push(_differs(
      "line-items",
      "number of VAT breakdowns (BG-23)",
      model.taxes.len(),
      taxes.len(),
    ))
  }
  for tax in model.taxes {
    let group = taxes.at(tax.key, default: none)
    if group == none {
      out.push(_differs(tax-field(tax), "VAT breakdown (BG-23)", tax.key, none))
      continue
    }
    let basis = group.at("basis", default: _zero)
    let amount = group.at("absolute", default: _zero)
    for (term, stated, value) in (
      ("VAT category taxable amount (BT-116)", tax.basis, basis),
      ("VAT category tax amount (BT-117)", tax.amount, amount),
      ("VAT category rate (BT-119)", tax.rate, group.at("rate", default: none)),
      (
        "VAT category code (BT-118)",
        tax.category,
        group.at(
          "category",
          default: none,
        ),
      ),
    ) {
      if stated != value {
        out.push(_differs(tax-field(tax), term, stated, value))
      }
    }
    // IP-CALC-02: the printed lines, allowances and charges of the group.
    let expected = if inclusive { basis + amount } else { basis }
    if counted and sums.at(tax.key) != expected {
      out.push((
        key: "IP-CALC-02",
        field: tax-field(tax),
        sum: sums.at(tax.key),
        expected: expected,
        gross: inclusive,
      ))
    }
  }

  // --- Totals -----------------------------------------------------------------
  let totals = model.totals
  let net = printed.at("net", default: _zero)
  let gross = printed.at("gross", default: _zero)
  let paid = model.payment.at("paid", default: false)
  for (term, stated, value) in (
    ("invoice total amount without VAT (BT-109)", totals.net, net),
    ("invoice total VAT amount (BT-110)", totals.tax, gross - net),
    ("invoice total amount with VAT (BT-112)", totals.gross, gross),
    (
      "paid amount (BT-113)",
      totals.prepaid,
      if paid { gross } else { printed.at("prepaid", default: _zero) },
    ),
    (
      "amount due for payment (BT-115)",
      totals.due,
      if paid { _zero } else { printed.at("due", default: _zero) },
    ),
    (
      "sum of the line net amounts (BT-106) minus the allowances (BT-107) plus the charges (BT-108)",
      totals.line - totals.allowance + totals.charge,
      net,
    ),
  ) {
    if stated != value { out.push(_differs("line-items", term, stated, value)) }
  }
  out
}
