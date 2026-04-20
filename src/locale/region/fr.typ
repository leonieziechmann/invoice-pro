#import "../../data/tax.typ"
#import "../../utils/format.typ" as m-format
#import "../../utils/coercion.typ"

/// French regional configuration (FR).
#let fr(lang) = {
  let numeric-format = (
    decimal-sign: ",",
    thousand-separators: " ",
    padding: false,
    accuracy: 4,
  )
  let currency-format = (currency: "€", location: end)

  return (
    meta: (
      region: "fr",
    ),

    normalize: (
      money: x => calc.round(x, digits: 2),
      money-fine: x => calc.round(x, digits: 4),

      infer-tax: x => {
        let val = float(x)
        if val == 20% {
          tax.vat(20%) // Standard rate
        } else if val == 10% {
          tax.lower-rate(10%) // Reduced rate (e.g., restaurants, transport, renovation)
        } else if val == 5.5% {
          tax.lower-rate(5.5%) // Reduced rate (e.g., food, books, basic necessities)
        } else if val == 2.1% {
          tax.lower-rate(2.1%) // Super-reduced rate (e.g., some medicines, press)
        } else if val == 0% {
          panic(
            "Ambiguous 0% tax rate in region 'fr'. Please explicitly use tax.zero(), tax.exempt(), tax.export(), or tax.outside-scope() from tax.typ instead of passing 0%.",
          )
        } else {
          panic(
            "Invalid or unknown tax rate for region 'fr': "
              + repr(x)
              + ". Valid rates are 20%, 10%, 5.5%, and 2.1%. If you need a custom rate, pass a full tax object.",
          )
        }
      },
    ),

    format: (
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
      default-vat: tax.vat(20%),

      small-enterprise-special-scheme: tax.outside-scope(
        grounds: "TVA non applicable, art. 293 B du CGI.",
      ),
    ),
  )
}
