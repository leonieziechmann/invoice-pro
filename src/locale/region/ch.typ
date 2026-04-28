#import "../../data/tax.typ"
#import "../../utils/format.typ" as m-format
#import "../../utils/coercion.typ"

/// Swiss regional configuration (CH).
#let ch(lang) = {
  let numeric-format = (
    decimal-sign: ".",
    thousand-separators: "'",
    padding: false,
    accuracy: 4,
  )
  let currency-format = (currency: "CHF ", location: start)

  return (
    meta: (
      region: "ch",
    ),

    normalize: (
      money: x => calc.round(x, digits: 2),
      money-fine: x => calc.round(x, digits: 4),

      infer-tax: x => {
        let val = float(x)
        if val == 8.1% {
          tax.vat(8.1%) // Standard rate
        } else if val == 2.6% {
          tax.lower-rate(2.6%) // Reduced rate (e.g., food, books, medicine)
        } else if val == 2.5% {
          tax.lower-rate(2.5%) // Special rate for accommodation/lodging
        } else if val == 0% {
          panic(
            "Ambiguous 0% tax rate in region 'ch'. Please explicitly use tax.zero(), tax.exempt(), tax.export(), or tax.outside-scope() from tax.typ instead of passing 0%.",
          )
        } else {
          panic(
            "Invalid or unknown tax rate for region 'ch': "
              + repr(x)
              + ". Valid rates are 8.1%, 2.6%, and 2.5%. If you need a custom rate, pass a full tax object.",
          )
        }
      },
    ),

    format: (
      percent: x => {
        let p = float(x) * 100
        str(calc.round(p, digits: 1)) + "%"
      },

      number: m-format.number.with(..numeric-format),

      currency: m-format.currency.with(
        ..currency-format,
        number-format: numeric-format + (accuracy: 2, padding: true),
      ),
      currency-fine: x => {
        let accuracy = if (
          calc.round(x, digits: 2) == calc.round(x, digits: 4)
        ) { 2 } else { 4 }
        m-format.currency(
          x,
          ..currency-format,
          number-format: numeric-format + (accuracy: accuracy, padding: true),
        )
      },
    ),

    tax: (
      default-vat: tax.vat(8.1%),

      small-enterprise-special-scheme: tax.outside-scope(
        grounds: "Nicht MWST-pflichtig / Non soumis à la TVA / Non assoggettato all'IVA",
      ),
    ),
  )
}
