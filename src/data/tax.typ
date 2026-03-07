#import "../utils/coercion.typ"

// UNTDID 5305
// https://vocabulary.uncefact.org/TaxCategoryCodeList
#let tax-category-db = (
  (code: "A", name: "Mixed tax rate"),
  (code: "AA", name: "Lower rate"),
  (code: "AB", name: "Exempt for resale"),
  (code: "AC", name: "Value Added Tax (VAT) not now due for payment"),
  (code: "AD", name: "Value Added Tax (VAT) due from a previous invoice"),
  (code: "AE", name: "VAT Reverse Charge"),
  (code: "B", name: "Transferred (VAT)"),
  (code: "C", name: "Duty paid by supplier"),
  (code: "D", name: "Value Added Tax (VAT) margin scheme - travel agents"),
  (code: "E", name: "Exempt from tax"),
  (code: "F", name: "Value Added Tax (VAT) margin scheme - second-hand goods"),
  (code: "G", name: "Free export item, tax not charged"),
  (code: "H", name: "Higher rate"),
  (
    code: "I",
    name: "Value Added Tax (VAT) margin scheme - works of art Margin scheme — Works of art",
  ),
  (
    code: "J",
    name: "Value Added Tax (VAT) margin scheme - collector’s items and antiques",
  ),
  (
    code: "K",
    name: "VAT exempt for EEA intra-community supply of goods and services",
  ),
  (code: "L", name: "Canary Islands general indirect tax"),
  (
    code: "M",
    name: "Tax for production, services and importation in Ceuta and Melilla",
  ),
  (code: "N", name: "standard rate additional VAT"),
  (code: "O", name: "Services outside scope of tax"),
  (code: "S", name: "Standard rate"),
  (code: "Z", name: "Zero rated goods"),
)

#let new(
  rate: 0%,
  category: "S",
  label: "vat",
  grounds: none,
) = (
  rate: coercion.to-ratio(rate),
  category: category,
  label: label,
  grounds: grounds,
)

#let to-tax-key(tax) = {
  return str(coercion.to-decimal(tax.rate)) + "-" + tax.category
}

#let zero(grounds: none) = new(
  rate: 0%,
  category: "Z",
  label: "exempt",
  grounds: grounds,
)

#let vat(rate, grounds: none) = new(
  rate: rate,
  category: "S",
  label: "vat",
  grounds: grounds,
)


#let to-tax(value) = {
  if type(value) == ratio { tax.vat(value) } else if type(value) == dictionary {
    value
  } else if value == auto { auto } else if value == none { tax.zero() } else {
    panic("Invalid Tax Type!")
  }
}
