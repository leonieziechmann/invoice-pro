#import "../../data/tax.typ"

/// Italian regional configuration (IT).
#let it(lang) = {
  let infer-tax-it(rate) = {
    if rate == 22% {
      return tax.vat(22%) // Standard rate
    } else if rate == 10% {
      return tax.vat(10%) // Reduced rate
    } else if rate == 5% {
      return tax.vat(5%) // Super-reduced rate
    } else if rate == 4% {
      return tax.vat(4%) // Super-reduced rate
    } else if rate == 0% {
      panic(
        lang.errors.ambiguous-tax
          + "\n"
          + "Ambiguous 0% tax rate in region 'it'. Please explicitly use one of the constructors:\n"
          + "`tax.reverse-charge()` -> Reverse Charge (Inversione contabile)\n"
          + "`tax.intra-community()` -> Cessione intracomunitaria\n"
          + "`tax.exempt()` -> Esente IVA (Art. 10 DPR 633/72)\n"
          + "`tax-exempt-small-biz: true` -> Regime forfettario (Art. 1 c. 54-89 L. 190/2014)\n"
          + "`tax.outside-scope()` -> Operazione fuori campo IVA.",
      )
    } else {
      panic(
        lang.errors.invalid-tax
          + "\n"
          + "Invalid tax rate: "
          + repr(rate)
          + ". Expected 22%, 10%, 5%, 4%, or a specific tax constructor.",
      )
    }
  }

  return (
    meta: (
      region: "it",
    ),

    normalize: (
      infer-tax: infer-tax-it,
    ),

    tax: (
      default-vat: tax.vat(22%),

      // Regime forfettario: not subject to VAT (FatturaPA N2.2): category O.
      small-enterprise-special-scheme: tax.outside-scope(
        grounds: "Operazione in franchigia da IVA ai sensi dell'art. 1, commi da 54 a 89, della Legge n. 190/2014.",
      ),
    ),
  )
}
