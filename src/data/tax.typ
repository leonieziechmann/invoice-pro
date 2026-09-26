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

// The rate may be a ratio or a number, as in a hand-built tax.
#let to-tax-key(tax) = {
  return str(coercion.to-ratio(tax.rate)) + "-" + tax.category
}

/// Creates a tax of any UNTDID 5305 category.
///
/// -> dictionary
#let new(
  /// The tax rate, e.g. `19%` or `0%`.
  /// -> ratio | int | float | decimal | str
  rate: 0%,
  /// The UNTDID 5305 tax category code, e.g. `"S"` or `"E"`.
  /// -> str
  category: "",
  /// A human-readable identifier of the tax type.
  /// -> str | content
  label: "",
  /// The legal reason of an exemption or a 0% rate.
  /// -> str | content | none
  grounds: none,
  /// The VATEX exemption reason code (BT-121), e.g. `"VATEX-EU-132-1A"`, of a
  /// tax that is exempt or not charged.
  /// -> none | str
  code: none,
) = {
  if code != none and type(code) != str {
    assert(
      false,
      message: "tax: `code` must be a VAT exemption reason code of the VATEX code list such as \"VATEX-EU-132-1A\", got "
        + repr(code)
        + ".",
    )
  }
  (
    rate: coercion.to-ratio(rate),
    category: category,
    label: label,
    grounds: grounds,
    // Only if given: keeps most taxes small.
    ..if code != none { (code: code) },
  )
}

// --- Constructors (UNTDID 5305) ---
#let mixed(rate, grounds: none) = new(
  rate: rate,
  category: "A",
  label: "mixed",
  grounds: grounds,
)

#let lower-rate(rate, grounds: none) = new(
  rate: rate,
  category: "AA",
  label: "lower-rate",
  grounds: grounds,
)

#let exempt-for-resale(grounds: none) = new(
  rate: 0%,
  category: "AB",
  label: "exempt-for-resale",
  grounds: grounds,
)

#let vat-not-due(rate, grounds: none) = new(
  rate: rate,
  category: "AC",
  label: "vat-not-due",
  grounds: grounds,
)

#let vat-previous(rate, grounds: none) = new(
  rate: rate,
  category: "AD",
  label: "vat-previous",
  grounds: grounds,
)

#let reverse-charge(grounds: "Reverse charge", code: none) = new(
  rate: 0%,
  category: "AE",
  label: "reverse-charge",
  grounds: grounds,
  code: code,
)

#let transferred(rate, grounds: none) = new(
  rate: rate,
  category: "B",
  label: "transferred",
  grounds: grounds,
)

#let duty-paid(rate, grounds: none) = new(
  rate: rate,
  category: "C",
  label: "duty-paid",
  grounds: grounds,
)

#let margin-travel(rate, grounds: none) = new(
  rate: rate,
  category: "D",
  label: "margin-travel",
  grounds: grounds,
)

#let exempt(grounds: none, code: none) = new(
  rate: 0%,
  category: "E",
  label: "exempt",
  grounds: grounds,
  code: code,
)

#let margin-second-hand(rate, grounds: none) = new(
  rate: rate,
  category: "F",
  label: "margin-second-hand",
  grounds: grounds,
)

#let export(grounds: none, code: none) = new(
  rate: 0%,
  category: "G",
  label: "export",
  grounds: grounds,
  code: code,
)

#let higher-rate(rate, grounds: none) = new(
  rate: rate,
  category: "H",
  label: "higher-rate",
  grounds: grounds,
)

#let margin-art(rate, grounds: none) = new(
  rate: rate,
  category: "I",
  label: "margin-art",
  grounds: grounds,
)

#let margin-antiques(rate, grounds: none) = new(
  rate: rate,
  category: "J",
  label: "margin-antiques",
  grounds: grounds,
)

#let intra-community(grounds: none, code: none) = new(
  rate: 0%,
  category: "K",
  label: "intra-community",
  grounds: grounds,
  code: code,
)

#let canary-islands(rate, grounds: none) = new(
  rate: rate,
  category: "L",
  label: "canary-islands",
  grounds: grounds,
)

#let ceuta-melilla(rate, grounds: none) = new(
  rate: rate,
  category: "M",
  label: "ceuta-melilla",
  grounds: grounds,
)

#let standard-additional(rate, grounds: none) = new(
  rate: rate,
  category: "N",
  label: "standard-additional",
  grounds: grounds,
)

#let outside-scope(grounds: none, code: none) = new(
  rate: 0%,
  category: "O",
  label: "outside-scope",
  grounds: grounds,
  code: code,
)

#let vat(rate, grounds: none) = new(
  rate: rate,
  category: "S",
  label: "vat",
  grounds: grounds,
)

#let zero(grounds: none) = new(
  rate: 0%,
  category: "Z",
  label: "zero",
  grounds: grounds,
)

// The tax of an item without any tax (`tax: none`): printed as zero rated, but
// `implicit`, as it does not say which 0% category applies.
#let implicit-zero() = (..zero(), label: "implicit-zero", implicit: true)

// A tax for messages, e.g. "19% S".
#let describe(tax) = (
  str(calc.round(float(coercion.to-ratio(tax.rate)) * 100, digits: 2))
    + "% "
    + tax.category
)

#let is-implicit(tax) = (
  type(tax) == dictionary and tax.at("implicit", default: false) == true
)

// A hand-built tax with the defaults of `new`; other keys are kept.
#let normalize(value) = (
  value
    + new(
      rate: value.at("rate", default: 0%),
      category: value.at("category", default: ""),
      label: value.at("label", default: ""),
      grounds: value.at("grounds", default: none),
      code: value.at("code", default: none),
    )
)

#let to-tax(value) = {
  if type(value) == ratio {
    vat(value)
  } else if type(value) == dictionary {
    normalize(value)
  } else if value == "exempt" {
    exempt()
  } else if value == "reverse-charge" {
    reverse-charge()
  } else if value == auto {
    auto
  } else if value == none {
    implicit-zero()
  } else {
    panic("Invalid Tax Type!")
  }
}

#let resolve(ctx, value, name) = {
  if type(value) == ratio {
    let infer-tax = (
      ctx
        .at("locale", default: (:))
        .at("normalize", default: (:))
        .at("infer-tax", default: (..) => panic(
          name + "::tax can not be of type `ratio`.",
        ))
    )
    infer-tax(value)
  } else {
    to-tax(value)
  }
}

// --- Exemption grounds ---

#let has-grounds(grounds) = grounds not in (none, "", [], [ ])

// Grounds are compared by text: a string and equal content are listed once.
#let grounds-key(grounds) = {
  let text = coercion.to-string(grounds)
  if type(text) == str { text.trim() } else { repr(grounds) }
}

// The virtual item of a bundle can carry several grounds (`grounds-list`).
#let grounds-of(tax) = {
  let list = tax.at("grounds-list", default: none)
  if type(list) == array { return list }
  let grounds = tax.at("grounds", default: none)
  if has-grounds(grounds) { (grounds,) } else { () }
}

#let merge-grounds(list, more) = {
  let keys = list.map(grounds-key)
  for grounds in more {
    let key = grounds-key(grounds)
    if key not in keys {
      list.push(grounds)
      keys.push(key)
    }
  }
  list
}

// The default exemption note of a category that needs a reason (BR-AE-10,
// BR-IC-10, BR-G-10, BR-O-10), else `none`.
#let default-grounds(category, strings) = {
  if type(category) != str { return none }
  let key = (
    AE: "reverse-charge",
    K: "intra-community",
    G: "export",
    O: "outside-scope",
  ).at(category, default: none)
  if key == none { return none }
  strings.at("tax-exemption", default: (:)).at(key, default: none)
}

// The exemption reason codes (BT-121) of a tax.
#let codes-of(tax) = {
  let list = tax.at("codes", default: none)
  if type(list) == array { return list }
  let code = tax.at("code", default: none)
  if code == none { () } else { (code,) }
}

#let merge-codes(list, more) = {
  for code in more {
    if code not in list { list.push(code) }
  }
  list
}

// EN 16931 allows one exemption reason (BT-120) per VAT category.
#let join-grounds(list) = {
  if list.len() == 0 { none } else if list.len() == 1 { list.first() } else {
    list.join("; ")
  }
}
