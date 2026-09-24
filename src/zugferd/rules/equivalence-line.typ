// The detailed comparison of an invoice line of the data model with the
// item it is a projection of (IP-PRINT-01, PEPPOL-EN16931-R120, see
// equivalence.typ): for a line whose values differ at first sight, or that
// has allowances or charges of its own. equivalence.typ loads it only for
// such a line, as most invoices have none.

#import "engine.typ": line-field
#import "equivalence.typ": differs

#let _zero = decimal("0")
#let _one = decimal("1")

// The decimals the net price of a gross price keeps at least (see
// `price-digits` of logic/net-amounts.typ): its tolerance.
#let _price-tolerance = decimal("0.000001")

/// The findings of a line of the model against its item: its values, its
/// allowances and charges (in the order the item prints them: its
/// discounts, then its surcharges) and, with `slack`, PEPPOL-EN16931-R120.
/// `limit` is the tolerance of its net amount with gross prices (`none`:
/// net prices), `unit` the smallest amount of the currency.
///
/// -> array
#let line-findings(line, item, limit, unit, slack) = {
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
      out.push(differs(
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
    out.push(differs(
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
        out.push(differs(
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
