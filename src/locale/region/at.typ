#import "../../data/tax.typ"
#import "../../utils/format.typ" as m-format
#import "../../utils/coercion.typ"

/// Austrian regional configuration (AT).
#let at(lang) = {
  let numeric-format = (
    decimal-sign: ",",
    thousand-separators: ".",
    padding: false,
    accuracy: 4,
  )
  let currency-format = (currency: "€", location: end)

  return (
    meta: (
      region: "at",
    ),

    normalize: (
      money: x => calc.round(x, digits: 2),
      money-fine: x => calc.round(x, digits: 4),

      infer-tax: x => {
        let val = float(x)
        if val == 20% {
          tax.vat(20%) // Standard rate
        } else if val == 13% {
          tax.lower-rate(13%) // Reduced rate (e.g., cultural events, animal feed)
        } else if val == 10% {
          tax.lower-rate(10%) // Reduced rate (e.g., food, books, medicine)
        } else if val == 0% {
          panic(
            "Ambiguous 0% tax rate in region 'at'. Please explicitly use tax.zero(), tax.exempt(), tax.export(), or tax.outside-scope() from tax.typ instead of passing 0%.",
          )
        } else {
          panic(
            "Invalid or unknown tax rate for region 'at': "
              + repr(x)
              + ". Valid rates are 20%, 13%, and 10%. If you need a custom rate, pass a full tax object.",
          )
        }
      },
    ),

    format: (
      percent: x => {
        let p = float(x) * 100
        str(calc.round(p, digits: 1)).replace(".", ",") + "%"
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
      default-vat: tax.vat(20%),

      small-enterprise-special-scheme: tax.outside-scope(
        grounds: "Umsatzsteuerfrei aufgrund der Kleinunternehmerregelung gem. § 6 Abs. 1 Z 27 UStG",
      ),
    ),
  )
}
