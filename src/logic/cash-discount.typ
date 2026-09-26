// Cash discounts (Skonto) of the payment goal, printed and as payment terms
// (BT-20, BR-DE-18); they change no amount of the invoice.

#import "../utils/types.typ"
#import "../utils/coercion.typ": to-decimal, to-ratio

#let _keys = ("days", "percent", "basis")

/// Checks the `discount` of the payment goal, `none`, `(days: .., percent: ..,
/// basis: ..)` or an array of them; returns an array, `percent` as `2.5`.
///
/// -> array
#let normalize(discount) = {
  if discount == none { return () }
  let steps = if type(discount) == dictionary { (discount,) } else {
    discount
  }
  let out = ()
  for (i, step) in steps.enumerate() {
    let name = (
      "payment-goal::discount"
        + if type(discount) == array {
          ".at(" + str(i) + ")"
        } else { "" }
    )
    assert(
      type(step) == dictionary,
      message: "`"
        + name
        + "` must be a dictionary such as `(days: 14, percent: 2%)`, got "
        + repr(step),
    )
    for key in step.keys() {
      assert(
        key in _keys,
        message: "`"
          + name
          + "` has the unknown key `"
          + key
          + "`. A cash discount has `days`, `percent` and optionally `basis`.",
      )
    }
    let days = step.at("days", default: none)
    assert(
      type(days) == int and days > 0,
      message: "`"
        + name
        + ".days` must be the number of days within which the discount applies (an integer greater than 0), got "
        + repr(days),
    )
    let percent = step.at("percent", default: none)
    assert(
      type(percent) == ratio,
      message: "`"
        + name
        + ".percent` must be a percentage such as `2%`, got "
        + repr(percent),
    )
    let percent = to-ratio(percent) * 100
    assert(
      percent > 0 and percent < 100,
      message: "`"
        + name
        + ".percent` must be more than 0% and less than 100%, got "
        + str(percent)
        + "%",
    )
    assert(
      calc.round(percent, digits: 2) == percent,
      message: "`"
        + name
        + ".percent` can have at most 2 decimals (the e-invoice states it with 2 decimals), got "
        + str(percent)
        + "%",
    )
    let basis = step.at("basis", default: none)
    types.require(basis, name + ".basis", none, types.decimal-like)
    out.push((
      days: days,
      percent: percent,
      basis: if basis != none { to-decimal(basis) },
    ))
  }
  out
}

/// The cash discounts with the `note` the invoice prints for each, from the
/// `cash-discount` sentence of the language.
///
/// -> array
#let with-notes(discounts, locale) = {
  let payment = locale.strings.payment
  let format = locale.format
  let out = ()
  for step in discounts {
    // Rounded like every amount of the invoice.
    let basis = if step.basis != none {
      (locale.normalize.money)(step.basis)
    }
    out.push(
      step
        + (
          basis: basis,
          note: (payment.cash-discount)(
            (format.number)(float(step.percent)) + "%",
            (payment.deadline-days)(step.days),
            if basis != none { (format.currency)(basis) },
          ),
        ),
    )
  }
  out
}
