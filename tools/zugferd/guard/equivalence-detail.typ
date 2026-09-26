// The detailed check of equivalence.typ: IP-PRINT-01 (a value differs from
// the printed one), IP-CALC-01 and IP-CALC-02.

#import "/src/zugferd/rules/engine.typ": line-field, tax-field
#import "/src/zugferd/model.typ": text-or-none

#let _zero = decimal("0")
#let _one = decimal("1")

// A net price derived from a gross price keeps at least 6 decimals.
#let _price-tolerance = decimal("0.000001")

// A finding of IP-PRINT-01; `rate`: the VAT rate of a gross `printed`.
#let _differs(field, term, stated, printed, rate: none) = (
  key: "IP-PRINT-01",
  field: field,
  term: term,
  stated: stated,
  printed: printed,
  rate: rate,
)

// The field of a document level modifier, e.g. `discount (Coupon)`.
#let _modifier-field(modifier) = {
  let name = text-or-none(modifier.at("name", default: none))
  let kind = if modifier.at("absolute", default: _zero) < _zero {
    "discount"
  } else { "surcharge" }
  if name == none { kind } else { kind + " (" + name + ")" }
}

// A line against its item. `limit`: the tolerance of the net amount with
// gross prices, else `none`; `unit`: the smallest amount of the currency.
#let _line-findings(line, item, limit, unit) = {
  let out = ()
  let divisor = _one + line.rate
  // BR-27: a negative price may be stated positive, of a negative quantity.
  let (price, quantity) = if item.price < _zero and line.price >= _zero {
    (-item.price, -item.quantity)
  } else { (item.price, item.quantity) }
  let rate = if limit != none { line.rate }
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
  out
}

/// The findings of `findings` of equivalence.typ, checked in detail.
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
  // The printed amounts per VAT group (IP-CALC-02) and, with gross prices,
  // the tolerance of its net amounts: a unit plus the rounding of its basis.
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

  // --- Lines ---
  let lines = model.lines
  // Without a line per item, neither lines nor sums are compared.
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
  let single = sums.len() == 1
  let total = _zero
  let limit = if inclusive and single { tolerance.values().first() }
  for (line, item) in lines.zip(items) {
    let net = item.total
    total += net
    if not single and line.key != none and line.key in sums {
      sums.at(line.key) += net
    }
    // Lines that differ or have adjustments are looked at in detail.
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
    if detailed { out += _line-findings(line, item, limit, unit) }
  }
  if single { sums.at(sums.keys().first()) += total }

  // --- Allowances and charges ---
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

  // --- VAT breakdown ---
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

  // --- Totals ---
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
