// The checks of XRechnung 3.0 (BR-DE-*) that only its profile runs.

#let _type-codes = ("326", "380", "381", "384", "389", "875", "876", "877")

/// BR-DE-17: the document type (BT-3).
///
/// -> array
#let document-type(code) = {
  if code in _type-codes { return () }
  ((key: "BR-DE-17", field: "document-type", code: code),)
}

// XR-TELEPHONE-REGEX and XR-EMAIL-REGEX, compiled on first use.
#let _patterns() = (
  digit: regex("[0-9]"),
  email: regex(
    "^[a-zA-Z0-9!#$%&\"*+/=?^_`{|}~-]+(\\.[a-zA-Z0-9!#$%&\"*+/=?^_`{|}~-]+)*@([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\\.)+[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$",
  ),
)

/// The seller contact (BG-6), addresses and buyer reference (BT-10).
///
/// -> array
#let parties(model) = {
  let out = ()
  let seller = model.seller
  let buyer = model.buyer
  let contact = seller.contact
  if contact == none {
    out.push((key: "BR-DE-2", field: "sender.contact"))
  } else {
    for (key, rule) in (
      ("name", "BR-DE-5"),
      ("phone", "BR-DE-6"),
      ("email", "BR-DE-7"),
    ) {
      if contact.at(key) == none {
        out.push((key: rule, field: "sender.contact." + key, input: key))
      }
    }
    // Errors: XRechnung only warns, but Mustang rejects the invoice.
    if (
      contact.phone != none
        and contact.phone.matches(_patterns().digit).len() < 3
    ) {
      out.push((
        key: "BR-DE-27",
        field: "sender.contact.phone",
        phone: contact.phone,
      ))
    }
    if (
      contact.email != none and contact.email.match(_patterns().email) == none
    ) {
      out.push((
        key: "BR-DE-28",
        field: "sender.contact.email",
        email: contact.email,
      ))
    }
  }

  for (party, field, city-rule, code-rule, term) in (
    (seller, "sender", "BR-DE-3", "BR-DE-4", "seller"),
    (buyer, "recipient", "BR-DE-8", "BR-DE-9", "buyer"),
    (model.ship-to, "delivery-address", "BR-DE-10", "BR-DE-11", "deliver-to"),
  ) {
    if party == none { continue }
    if party.address.city == none {
      out.push((
        key: city-rule,
        field: field + ".city",
        party: field,
        term: term,
      ))
    }
    if party.address.post-code == none {
      out.push((
        key: code-rule,
        field: field + ".city",
        party: field,
        term: term,
      ))
    }
  }

  if model.invoice.buyer-reference == none {
    // A buyer reached by its Leitweg-ID (EAS 0204) names it as reference.
    let address = buyer.at("electronic-address", default: none)
    out.push((
      key: "BR-DE-15",
      field: "recipient.buyer-reference",
      routing: if (
        type(address) == dictionary
          and address.at("scheme", default: none) == "0204"
      ) { address.at("id", default: none) },
    ))
  }
  out
}

// XR-SKONTO-REGEX (BR-DE-18).
#let _skonto-line() = regex(
  "#(SKONTO)#TAGE=([0-9]+#PROZENT=[0-9]+\\.[0-9]{2})(#BASISBETRAG=-?[0-9]+\\.[0-9]{2})?#$",
)
#let _xml-whitespace = regex("[ \\t\\r\\n]+")

// A "#" line that is no cash discount (`line`), text after "#...#" (`after`).
#let _skonto-problem(terms) = {
  let lines = terms.split("\n")
  let skonto = false
  for line in lines {
    let normalized = line.replace(_xml-whitespace, " ").trim(" ")
    if normalized.starts-with("#") {
      if normalized.match(_skonto-line()) == none {
        return (line: normalized)
      }
      skonto = true
    }
  }
  if not skonto { return none }
  // The last "#.+#": the last line with text between two "#" (no regex: slow).
  for i in range(lines.len() - 1, -1, step: -1) {
    let parts = lines.at(i).split("#")
    if parts.len() >= 3 and parts.slice(1, -1).join("#") != "" {
      if (
        i < lines.len() - 1 and parts.last().replace(_xml-whitespace, "") == ""
      ) {
        return none
      }
      return (after: lines.at(i).replace(_xml-whitespace, " ").trim(" "))
    }
  }
  none
}

/// BR-DE-18: the Skonto syntax of the payment terms and the discount bases.
///
/// -> array
#let payment-terms(payment, terms) = {
  let out = ()
  if terms != none {
    let problem = _skonto-problem(terms)
    if problem != none {
      let input = payment.at("terms-input", default: none)
      out.push((
        key: "BR-DE-18",
        field: if input == none { "payment-goal" } else { input },
        line: problem.at("line", default: none),
        after: problem.at("after", default: none),
      ))
    }
  }
  for discount in payment.at("discounts", default: ()) {
    let basis = discount.basis
    if basis != none and calc.round(basis, digits: 2) != basis {
      out.push((
        key: "BR-DE-18",
        field: "payment-goal.discount",
        basis: basis,
      ))
    }
  }
  out
}
