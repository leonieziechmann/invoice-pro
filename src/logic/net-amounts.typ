// The net amounts the e-invoice states for an invoice with gross prices
// (`tax-mode: "inclusive"`), derived once from the printed gross amounts.

#import "../data/tax.typ": to-tax-key
#import "../utils/coercion.typ": to-ratio

#let _zero = decimal("0")
#let _one = decimal("1")

#let _integer-digits(value) = str(calc.floor(value)).len()

/// The decimals of the net price of a gross price (BT-146): at least 6 and
/// `fine`, more for large quantities (PEPPOL-EN16931-R120).
///
/// -> int
#let price-digits(quantity, base-quantity, fine: 4) = calc.max(
  6,
  fine,
  3 + _integer-digits(calc.abs(quantity / base-quantity)),
)

/// Rounds the decimals `exact` to `digits` decimals so that they add up to
/// `total` (largest remainder method). No amount changes its sign, and those
/// `nonzero` marks (`auto`: all) do not turn to 0.
///
/// -> array
#let allocate(exact, total, digits: 2, nonzero: auto) = {
  let rounded = ()
  let sum = _zero
  for value in exact {
    let r = calc.round(value, digits: digits)
    rounded.push(r)
    sum += r
  }
  let difference = total - sum
  if difference == _zero or exact == () { return rounded }
  let unit = calc.pow(decimal("10"), -digits)
  let step = if difference > _zero { unit } else { -unit }
  // Rounded furthest against the difference first (`sorted` is stable).
  let order = ()
  for i in range(exact.len()).sorted(key: i => (
    (rounded.at(i) - exact.at(i)) * step
  )) {
    let moved = (rounded.at(i) + step) * exact.at(i)
    if (
      moved > _zero
        or (
          moved == _zero
            and exact.at(i) != _zero
            and nonzero != auto
            and not nonzero.at(i)
        )
    ) { order.push(i) }
  }
  if order == () { order = range(exact.len()) }
  let count = calc.floor(calc.abs(difference) / unit)
  for k in range(count) {
    let i = order.at(calc.rem(k, order.len()))
    rounded.at(i) += step
  }
  // A total finer than the unit (custom rounding): the first takes the rest.
  let rest = difference - step * count
  if rest != _zero { rounded.at(order.first()) += rest }
  rounded
}

// The positive net amounts of a line's allowances and charges (BT-136,
// BT-141), with their signed sum closest to `target` (PEPPOL-EN16931-R120).
#let _modifier-nets(amounts, divisor, target, digits) = {
  let unit = calc.pow(decimal("10"), -digits)
  let exact = ()
  let nets = ()
  let sum = _zero
  for amount in amounts {
    let value = amount / divisor
    let net = calc.round(value, digits: digits)
    exact.push(value)
    nets.push(net)
    sum += net
  }
  let i = 0
  for value in exact {
    let miss = target - sum
    if calc.abs(miss) * 2 <= unit { break }
    let net = nets.at(i)
    let other = if value > net { net + unit } else if value < net {
      net - unit
    } else { net }
    if other != net and other != _zero and (other - net) * miss > _zero {
      nets.at(i) = other
      sum += other - net
    }
    i += 1
  }
  let out = ()
  for net in nets { out.push(calc.abs(net)) }
  out
}

/// The net amounts of the `items` and of the document level allowances and
/// charges (`modifiers`): per item `(net: .., price: .., adjustments: ..)`
/// (BT-131, BT-146, BT-136/BT-141), per modifier its net amounts by VAT group.
///
/// -> dictionary
#let net-amounts(items, taxes, modifiers, digits: 2, fine: 4) = {
  // The exact net amounts per VAT group, and where each goes (`slots`).
  let exact = (:)
  let slots = (:)
  let lines = ()
  let i = 0
  for item in items {
    let tax = item.tax
    let rate = tax.rate
    if type(rate) != decimal { rate = to-ratio(rate) }
    let divisor = _one + rate
    let key = to-tax-key(tax)
    if key not in exact {
      exact.insert(key, ())
      slots.insert(key, ())
    }
    exact.at(key).push(item.total / divisor)
    slots.at(key).push((i, none))
    let quantity = item.quantity
    let base-quantity = item.at("base-quantity", default: _one)
    let price = calc.round(
      calc.abs(item.price) / divisor,
      digits: price-digits(quantity, base-quantity, fine: fine),
    )
    // Quantity × net price; negative for a credited line (BR-27).
    let base = quantity * price / base-quantity
    if item.price < _zero { base = -base }
    lines.push((
      net: none,
      price: price,
      base: base,
      divisor: divisor,
      modifiers: item.at("discounts", default: ())
        + item.at("surcharge", default: ()),
    ))
    i += 1
  }
  let parts = ()
  for (m, modifier) in modifiers.enumerate() {
    let nets = (:)
    for (key, part) in modifier.at("split", default: (:)) {
      let amount = part.at("absolute", default: _zero)
      let rate = part.at("tax", default: (:)).at("rate", default: _zero)
      if type(rate) != decimal { rate = to-ratio(rate) }
      if key not in exact {
        exact.insert(key, ())
        slots.insert(key, ())
      }
      exact.at(key).push(amount / (_one + rate))
      slots.at(key).push((m, key))
      nets.insert(key, none)
    }
    parts.push(nets)
  }

  // Per VAT group, they add up to its printed taxable amount (BR-S-08 and
  // the like); a line may turn to 0, an allowance or charge may not.
  for (key, values) in exact {
    let basis = taxes.at(key, default: (:)).at("basis", default: none)
    let rounded = if basis == none {
      let out = ()
      for value in values { out.push(calc.round(value, digits: digits)) }
      out
    } else {
      let nonzero = ()
      for (_, part) in slots.at(key) { nonzero.push(part != none) }
      allocate(values, basis, digits: digits, nonzero: nonzero)
    }
    for ((index, part), net) in slots.at(key).zip(rounded) {
      if part == none { lines.at(index).net = net } else {
        parts.at(index).insert(part, net)
      }
    }
  }

  let out = ()
  for line in lines {
    let adjustments = ()
    if line.modifiers != () {
      let amounts = ()
      for modifier in line.modifiers { amounts.push(modifier.absolute) }
      adjustments = _modifier-nets(
        amounts,
        line.divisor,
        line.net - line.base,
        digits,
      )
    }
    out.push((net: line.net, price: line.price, adjustments: adjustments))
  }
  (lines: out, modifiers: parts)
}
