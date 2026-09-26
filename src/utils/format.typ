#let number(
  number,
  decimal-sign: ",",
  thousand-separators: ".",
  negative-sign: "-",
  padding: false,
  accuracy: 2,
) = {
  let rounded = calc.round(number, digits: accuracy)
  let is-negative = rounded < 0
  let abs-val = calc.abs(rounded)

  let s = str(abs-val)
  let parts = s.split(".")
  let int-part = parts.at(0)
  let frac-part = if parts.len() > 1 { parts.at(1) } else { "" }

  if padding and accuracy > 0 {
    if frac-part.len() < accuracy {
      frac-part += "0" * (accuracy - frac-part.len())
    }
  }

  let formatted-int = int-part
    .clusters()
    .rev()
    .chunks(3)
    .map(c => c.join())
    .join(thousand-separators.rev())
    .clusters()
    .rev()
    .join()

  let result = formatted-int

  if frac-part.len() > 0 { result += decimal-sign + frac-part }
  if is-negative { result = negative-sign + result }

  return result
}

#let currency(
  value,
  currency: "€",
  location: end,
  number-format: (:),
) = {
  number-format += (padding: number-format.at("padding", default: true))

  let formated-string = number(value, ..number-format)
  if location == start {
    currency + sym.space.nobreak.narrow + formated-string
  } else if location == end {
    formated-string + sym.space.nobreak.narrow + currency
  } else { panic("Invalid Location!") }
}

/// Generates the standard number and currency formatters of a region.
#let make-formatters(numeric-format, currency-meta, currency-location: end) = {
  let currency-format = (
    currency: currency-meta.symbol,
    location: currency-location,
  )

  return (
    number: number.with(..numeric-format),

    currency: currency.with(
      ..currency-format,
      number-format: numeric-format
        + (accuracy: currency-meta.decimals, padding: true),
    ),

    currency-fine: x => {
      // A unit price is printed as calculated (BT-146): with the standard
      // decimals if it has no more, else `decimals-fine` or more (up to 6).
      let standard-rounded = calc.round(x, digits: currency-meta.decimals)
      let fine-rounded = calc.round(
        x,
        digits: calc.max(currency-meta.decimals-fine, 6),
      )
      let accuracy = if (standard-rounded == fine-rounded) {
        currency-meta.decimals
      } else {
        let fraction = str(calc.abs(fine-rounded)).split(".").at(1, default: "")
        calc.max(
          currency-meta.decimals-fine,
          fraction.trim("0", at: end, repeat: true).len(),
        )
      }

      currency(
        x,
        ..currency-format,
        number-format: numeric-format + (accuracy: accuracy, padding: true),
      )
    },

    currency-formatters: meta => make-formatters(
      numeric-format,
      meta,
      currency-location: currency-location,
    ),
  )
}
