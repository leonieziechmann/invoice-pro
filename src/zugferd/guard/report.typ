// Diagnostics of the XML write guard: turns what the serializer found (see
// write.typ) into diagnostics like the validator's, and merges them with
// the validator's (concept 4.4, "Richtlinie für Diagnosen"):
//
// - every finding of the guard is an error;
// - a finding the validator reports already (same rule or same input field)
//   is left out: the validator's diagnostic names the input and a hint;
// - when the validator reports errors, the remaining findings are one
//   diagnostic, "N further problems in the XML";
// - otherwise each finding is a diagnostic of its own, with a hint to report
//   it: the validator has no rule for it, which is a bug of invoice-pro.

// The guard's own rules, for findings no official rule names. The ids are
// listed in docs/docs/e-invoicing.md.
#let _rules = (
  unknown: "IP-GUARD-01",
  text: "IP-GUARD-01",
  order: "IP-GUARD-02",
  max: "IP-GUARD-03",
  variant-max: "IP-GUARD-03",
  aggregate: "IP-GUARD-03",
  exclusive: "IP-GUARD-03",
  xref-count: "IP-GUARD-03",
  min: "IP-GUARD-04",
  blank: "IP-GUARD-04",
  variant-min: "IP-GUARD-04",
  any-of: "IP-GUARD-04",
  empty: "IP-GUARD-04",
  not-used: "IP-GUARD-05",
  attribute-not-used: "IP-GUARD-05",
  xref-other: "IP-GUARD-05",
  attribute: "IP-GUARD-06",
  attribute-missing: "IP-GUARD-06",
  lexical: "IP-GUARD-07",
  fraction: "IP-GUARD-07",
  date: "IP-GUARD-08",
  code: "IP-GUARD-07",
  prefix: "IP-GUARD-07",
  category: "IP-GUARD-07",
  name: "IP-GUARD-09",
  namespace: "IP-GUARD-09",
  root: "IP-GUARD-09",
  well-formed: "IP-GUARD-09",
)

/// The rule of the diagnostic that summarizes further findings.
#let summary-rule = "IP-GUARD-00"

#let report-hint = "invoice-pro could not map this problem to an input; please report it at https://github.com/leonieziechmann/invoice-pro/issues."

// Input fields by the element of the XML they are written to: the parties
// and the parts of the invoice a user sets. The first element of a path
// that has an entry names the field; below a party, its details do.
#let _fields = (
  "ram:SellerTaxRepresentativeTradeParty": "sender.tax-representative",
  "ram:SellerTradeParty": "sender",
  "ram:BuyerTradeParty": "recipient",
  "ram:PayeeTradeParty": "payee",
  "ram:ShipToTradeParty": "delivery-address",
  "ram:BuyerReference": "recipient.buyer-reference",
  "ram:SpecifiedTradeSettlementHeaderMonetarySummation": "amounts",
  "ram:SpecifiedTradeSettlementPaymentMeans": "bank-details",
  "ram:SpecifiedTradePaymentTerms": "payment-goal",
  "ram:InvoiceCurrencyCode": "currency",
  "ram:IncludedNote": "notes",
  "ram:BillingSpecifiedPeriod": "service-period",
  "ram:InvoiceReferencedDocument": "references",
  "ram:ApplicableTradeTax": "tax",
)
#let _party-fields = (
  "ram:Name": "name",
  "ram:PostalTradeAddress": "address",
  "ram:SpecifiedTaxRegistration": "vat-id",
  "ram:URIUniversalCommunication": "electronic-address",
  "ram:DefinedTradeContact": "contact",
  "ram:SpecifiedLegalOrganization": "legal-id",
  "ram:ID": "id",
  "ram:GlobalID": "id",
)
#let _document-fields = (
  "ram:ID": "invoice-nr",
  "ram:TypeCode": "document-type",
  "ram:IssueDateTime": "date",
)
#let _line = "ram:IncludedSupplyChainTradeLineItem"

// The element name and the number of a path step such as `x[3]`.
#let _step(step) = {
  let parts = step.split("[")
  if parts.len() < 2 { return (step, none) }
  (parts.at(0), int(parts.at(1).trim("]")))
}

/// The input field a path of the XML is written from, or the path itself.
///
/// -> str
#let field-of(path, lines) = {
  let steps = path.map(_step)
  for (i, (tag, n)) in steps.enumerate() {
    if tag == _line and n != none {
      let line = lines.at(n - 1, default: none)
      if line == none { return "item " + str(n) }
      return (
        "item "
          + str(line.id)
          + if line.at("name", default: none) != none { " (" + line.name + ")" }
      )
    }
    if tag == "rsm:ExchangedDocument" and i + 1 < steps.len() {
      let field = _document-fields.at(steps.at(i + 1).at(0), default: none)
      if field != none { return field }
    }
    let field = _fields.at(tag, default: none)
    if field == none { continue }
    if field in ("sender", "recipient", "payee") and i + 1 < steps.len() {
      let detail = steps.at(i + 1).at(0)
      if detail == "ram:PostalTradeAddress" and i + 2 < steps.len() {
        if steps.at(i + 2).at(0) == "ram:CountryID" {
          return field + ".country"
        }
      }
      let sub = _party-fields.at(detail, default: none)
      if sub != none { return field + "." + sub }
    }
    return field
  }
  "/" + path.join("/")
}

#let _quoted(value) = if value == none { "(none)" } else {
  "\"" + str(value) + "\""
}

// What a finding says, in a sentence.
#let _message(f, profile) = {
  let path = f.path
  let tag = path.at(-1, default: "")
  let parent = if path.len() > 1 { path.at(path.len() - 2) } else { none }
  let where = if parent != none { " in " + _step(parent).at(0) } else { "" }
  let element = _step(tag).at(0)
  let kind = f.kind
  if kind == "unknown" {
    (
      "The XML contains "
        + element
        + where
        + ", which the "
        + profile
        + " schema does not allow there (or which invoice-pro never writes)."
    )
  } else if kind == "not-used" {
    (
      "The XML contains "
        + element
        + where
        + ", which the profile "
        + profile
        + " does not use there."
    )
  } else if kind == "order" {
    element + where + " is out of the order of the schema."
  } else if kind == "max" {
    (
      element
        + where
        + " occurs "
        + str(f.count)
        + " times; the profile allows "
        + str(f.limit)
        + "."
    )
  } else if kind == "min" {
    "The required element " + element + where + " is missing."
  } else if kind == "blank" {
    "The required element " + element + where + " has no text."
  } else if kind == "variant-min" {
    (
      "The element "
        + element
        + " with "
        + _quoted(f.variant)
        + where
        + " is missing."
    )
  } else if kind == "variant-max" {
    (
      element
        + " with "
        + _quoted(f.variant)
        + where
        + " occurs "
        + str(f.count)
        + " times; the profile allows "
        + str(f.limit)
        + "."
    )
  } else if kind == "any-of" {
    "One of " + f.tags.join(", ") + " is required in " + element + "."
  } else if kind == "exclusive" {
    element + " has both " + f.tags.join(" and ") + "; only one is allowed."
  } else if kind == "aggregate" {
    (
      element
        + " has "
        + str(f.count)
        + " "
        + f.steps.join("/")
        + "; allowed: "
        + str(f.low)
        + " to "
        + if f.high == none { "any number" } else { str(f.high) }
        + "."
    )
  } else if kind == "empty" {
    "The element " + element + " is empty."
  } else if kind == "text" {
    (
      "The element "
        + element
        + " has text where the schema expects elements, or elements where it expects text."
    )
  } else if kind == "attribute" {
    "The attribute " + f.name + " of " + element + " is not allowed."
  } else if kind == "attribute-not-used" {
    (
      "The attribute "
        + f.name
        + " of "
        + element
        + " is not used in the profile "
        + profile
        + "."
    )
  } else if kind == "attribute-missing" {
    "The attribute " + f.name + " of " + element + " is missing."
  } else if kind == "lexical" {
    element + " is " + _quoted(f.value) + ", which is not " + f.expected + "."
  } else if kind == "fraction" {
    (
      element
        + " "
        + _quoted(f.value)
        + " has more than "
        + str(f.limit)
        + " decimals."
    )
  } else if kind == "date" {
    (
      element
        + " "
        + _quoted(f.value)
        + " is no calendar date in the format YYYYMMDD."
    )
  } else if kind == "code" {
    (
      "The code "
        + _quoted(f.value)
        + if "name" in f { " of @" + f.name } else { "" }
        + " of "
        + element
        + " is not in the code list "
        + _quoted(f.list)
        + " of the profile "
        + profile
        + "."
    )
  } else if kind == "prefix" {
    (
      "The identifier of "
        + element
        + " starts with "
        + _quoted(f.value)
        + ", which is no country prefix of the code list."
    )
  } else if kind == "category" {
    let subject = "The VAT category " + f.category
    if f.check == "e" {
      if f.expected {
        (
          subject
            + " requires an exemption reason (ram:ExemptionReason or ram:ExemptionReasonCode)"
            + where
            + "."
        )
      } else {
        subject + " has no exemption reason, but one is stated" + where + "."
      }
    } else {
      let what = if f.check == "r" { "rate" } else { "VAT amount" }
      (
        subject
          + if f.expected == none { " has no " + what } else if (
            f.expected == 0
          ) { " requires the " + what + " 0" } else {
            " requires a " + what + " above 0"
          }
          + "; "
          + element
          + where
          + if f.value == none { " is missing" } else {
            " is " + _quoted(f.value)
          }
          + "."
      )
    }
  } else if kind == "xref-count" {
    (
      "The VAT total is stated "
        + str(f.count)
        + " times in the currency "
        + _quoted(f.value)
        + "."
    )
  } else if kind == "xref-other" {
    (
      "The VAT total is stated in the currency "
        + _quoted(f.value)
        + ", which is neither the invoice currency nor the VAT accounting currency."
    )
  } else if kind == "name" {
    (
      _quoted(f.value)
        + " is not a valid name of an element or attribute of the e-invoice."
    )
  } else if kind == "namespace" {
    (
      "The root element does not declare "
        + f.name
        + " as "
        + _quoted(f.value)
        + "."
    )
  } else if kind == "root" {
    if f.at("missing", default: false) {
      "The XML has no root element rsm:CrossIndustryInvoice."
    } else {
      (
        "The XML contains "
          + element
          + " beside its root element rsm:CrossIndustryInvoice."
      )
    }
  } else if kind == "well-formed" {
    "Typst's XML parser does not read the XML as one CrossIndustryInvoice document."
  } else { "The XML guard found a problem (" + kind + ")." }
}

/// The findings of the guard as diagnostics (level, rule, source, field,
/// message, hint, path).
///
/// -> array
#let guard-diagnostics(findings, lines, profile-name) = {
  let out = ()
  for f in findings {
    let rule = if f.rule != none { f.rule } else {
      _rules.at(f.kind, default: "IP-GUARD-01")
    }
    out.push((
      level: "error",
      rule: rule,
      source: "guard",
      field: field-of(f.path, lines),
      message: _message(f, profile-name),
      hint: report-hint,
      path: "/" + f.path.join("/"),
    ))
  }
  out
}

/// The validator's diagnostics with the guard's merged in (see the policy
/// at the top of this file).
///
/// -> array
#let merge(diagnostics, guard) = {
  if guard == () { return diagnostics }
  let rules = (:)
  let fields = (:)
  let errors = 0
  for d in diagnostics {
    if d.level == "error" {
      errors += 1
      rules.insert(d.rule, true)
      if type(d.field) == str { fields.insert(d.field, true) }
    }
  }
  let remaining = ()
  for g in guard {
    if g.rule not in rules and g.field not in fields { remaining.push(g) }
  }
  if remaining == () { return diagnostics }
  if errors == 0 { return diagnostics + remaining }
  let n = remaining.len()
  let first = remaining.first()
  (
    diagnostics
      + (
        (
          level: "error",
          rule: summary-rule,
          source: "guard",
          field: first.field,
          message: (
            str(n)
              + if n == 1 { " further problem" } else { " further problems" }
              + " in the XML, first: ["
              + first.rule
              + "] "
              + first.message
          ),
          hint: "It may follow from the errors above. If it remains once they are fixed, please report it at https://github.com/leonieziechmann/invoice-pro/issues.",
          path: first.path,
        ),
      )
  )
}
