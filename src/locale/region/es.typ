#import "../../data/tax.typ"

/// Spanish regional configuration (ES).
#let es(lang) = {
  let infer-tax-es(rate) = {
    if rate == 21% {
      return tax.vat(21%) // Standard rate
    } else if rate == 10% {
      return tax.vat(10%) // Reduced rate
    } else if rate == 4% {
      return tax.vat(4%) // Super-reduced rate
    } else if rate == 0% {
      panic(
        "Ambiguous 0% tax rate in region 'es'. Please explicitly use tax.zero(), tax.exempt(), tax.export(), or tax.outside-scope() from tax.typ instead of passing 0%.",
      )
    } else {
      panic(
        "Invalid or unknown tax rate for region 'es': "
          + repr(rate)
          + ". Valid rates are 21%, 10%, and 4%. If you need a custom rate, pass a full tax object.",
      )
    }
  }

  return (
    meta: (
      region: "es",
    ),

    normalize: (
      infer-tax: infer-tax-es,
    ),

    tax: (
      default-vat: tax.vat(21%),

      // Franquicia del IVA: exempt (category E). The note cites no article;
      // `locale.custom.tax(..)` can state one.
      small-enterprise-special-scheme: tax.exempt(
        grounds: "Exento de IVA según el régimen especial de franquicia para pequeñas empresas.",
      ),
    ),
  )
}
