// Checks the e-invoice data model against the business rules of EN 16931,
// the Factur-X profiles and XRechnung before the XML is written.
//
// Every problem is collected as a diagnostic instead of stopping at the first
// one, so all of them can be reported at once:
//
//   (
//     level: "error" | "warning",
//     rule: "BR-CO-25",           // business rule or term the check is based on
//     field: "payment-goal",      // the invoice input to look at
//     message: "...",             // what is wrong
//     hint: "..." | none,         // how to fix it
//   )
//
// Errors make the XML invalid; warnings point out data that is valid but most
// likely not intended.

#import "codelists.typ"
#import "xml.typ": fmt-number, rate-digits
#import "../utils/iban.typ": iban-valid

#let _zero = decimal("0")

#let error(rule, field, message, hint: none) = (
  level: "error",
  rule: rule,
  field: field,
  message: message,
  hint: hint,
)

#let warning(rule, field, message, hint: none) = (
  level: "warning",
  rule: rule,
  field: field,
  message: message,
  hint: hint,
)

#let _quoted(value) = if value == none { "(none)" } else {
  "\"" + str(value) + "\""
}

#let _sum(values) = values.fold(_zero, (total, value) => total + value)

// A rate in percent as the XML states it, e.g. "19%" or "9.975%".
#let _percent(rate) = (
  fmt-number(rate * 100, min-digits: 0, max-digits: rate-digits) + "%"
)

// Human readable reference to an invoice line, e.g. `item 2 (Consulting)`.
#let _line-field(line) = {
  "item " + line.id + if line.name != none { " (" + line.name + ")" }
}

#let _tax-field(tax) = {
  "tax " + if tax.category != none { tax.category + " " } + _percent(tax.rate)
}

// --- Document -------------------------------------------------------------

// The characters of a printed amount besides its currency: digits,
// separators, signs and spaces. The samples are plain text, whose spaces and
// minus signs are ASCII; the typographic apostrophe (a thousands separator)
// is removed separately. (ASCII only: a class with other characters, or a
// Unicode class such as `\d` or `\s`, takes a fraction of a millisecond to
// compile on every compile.)
#let _amount-characters = regex("[0-9 .,'+\\-()]")

#let check-document(model) = {
  let out = ()
  if model.invoice.number == none {
    out.push(error(
      "BR-02",
      "invoice-nr",
      "The invoice number (BT-1) is missing.",
      hint: "Set `invoice-nr` on the invoice.",
    ))
  }
  let date = model.invoice.issue-date
  if type(date) != datetime or date.year() == none {
    out.push(error(
      "BR-03",
      "date",
      "The invoice date (BT-2) is missing or is not a calendar date.",
      hint: "Set `date` on the invoice, e.g. `datetime(year: 2026, month: 7, day: 1)`.",
    ))
  }
  if model.currency == none {
    out.push(error(
      "BR-05",
      "locale",
      "The invoice currency code (BT-5) is missing.",
      hint: "Use a locale that defines `currency.code`, e.g. `locale.de-de`.",
    ))
  } else if model.currency not in codelists.currencies {
    out.push(error(
      "BR-CL-04",
      "locale",
      "The invoice currency code (BT-5) "
        + _quoted(model.currency)
        + " is not an ISO 4217 code.",
      hint: "Use a currency code such as \"EUR\" or \"CHF\" in the locale.",
    ))
  } else if (
    model.profile.en16931
      and model.currency in codelists.cen-rejected-currencies
  ) {
    out.push(error(
      "BR-CL-04",
      "locale",
      "The invoice currency code (BT-5) "
        + _quoted(model.currency)
        + " is missing in the code list of the EN 16931 validation, so no e-invoice in the "
        + model.profile.name
        + " profile can use it.",
      hint: "Invoice in another currency, or use the \"minimum\" or \"basic-wl\" profile, whose validation knows the code.",
    ))
  }

  // IP-TAX-01: `tax: none` prints 0%, but does not say why no VAT is charged:
  // zero rated, exempt or not subject to VAT. An e-invoice must say it with
  // the VAT category of every item (BT-151).
  let implicit = 0
  for line in model.lines {
    if line.at("implicit", default: false) { implicit += 1 }
  }
  if (
    implicit > 0 or model.taxes.any(tax => tax.at("implicit", default: false))
  ) {
    out.push(error(
      "IP-TAX-01",
      "tax",
      "The invoice sets `tax: none`, so "
        + if implicit <= 1 { "an item has" } else {
          str(implicit) + " items have"
        }
        + " no VAT category (BT-151): printed with 0%, it would be declared as zero rated (Z).",
      hint: "Choose the VAT category with the `tax` module, e.g. `tax.exempt(grounds: ..)` for exempt items, `tax.outside-scope()` for supplies not subject to VAT or `tax.zero()` for zero rated goods, or set `tax-exempt-small-biz: true`.",
    ))
  }

  // IP-PRINT-02: the invoice prints its amounts in the currency the XML
  // states: with its code or the symbol of the locale, and not with "€" for
  // another currency. Unit prices may be printed in a subunit instead (e.g.
  // "ct" for energy tariffs), but not with "€" for another currency either.
  // A formatter that prints no currency says nothing else.
  let printed = model.at("printed-currency", default: none)
  if (
    type(model.currency) == str
      and model.currency in codelists.currencies
      and type(printed) == dictionary
  ) {
    for (kind, sample) in (
      ("amounts", printed.at("amount", default: none)),
      ("unit prices", printed.at("price", default: none)),
    ) {
      if sample == none { continue }
      let sign = sample.replace(_amount-characters, "").replace("’", "")
      if sign == "" { continue }
      let euro = sample.contains("€") and model.currency != "EUR"
      let states = (
        sample.contains(model.currency)
          or printed.symbol != none and sample.contains(printed.symbol)
      )
      if not euro and (states or kind == "unit prices") { continue }
      out.push(error(
        "IP-PRINT-02",
        "locale",
        "The invoice prints "
          + kind
          + " in "
          + _quoted(sign)
          + " (e.g. "
          + _quoted(sample)
          + "), but the e-invoice states the currency "
          + _quoted(model.currency)
          + " (BT-5).",
        hint: "Set the currency of the locale's region to the printed one, e.g. `currency: (code: \"PLN\", symbol: \"zł\")` in a region builder or `locale.de-de.with((region: (currency: (code: \"PLN\", symbol: \"zł\"))))`; the amounts are then printed with its symbol.",
      ))
      break
    }
  }
  out
}

// XRechnung 3.0 (XRechnung-CII-validation.xslt): BT-42 has at least three
// digits (XR-TELEPHONE-REGEX), and BT-43 matches XR-EMAIL-REGEX.
#let _digit = regex("[0-9]")
#let _xr-email = regex(
  "^[a-zA-Z0-9!#$%&\"*+/=?^_`{|}~-]+(\\.[a-zA-Z0-9!#$%&\"*+/=?^_`{|}~-]+)*@([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\\.)+[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$",
)

// --- Parties --------------------------------------------------------------

#let _check-country(code, rule, field, term) = {
  if code == none {
    return (
      error(
        rule,
        field,
        "The " + term + " is missing.",
        hint: "Set `country` on the "
          + field.split(".").first()
          + ", e.g. `country: country.de`.",
      ),
    )
  }
  if code not in codelists.countries {
    return (
      error(
        "BR-CL-14",
        field,
        "The " + term + " " + _quoted(code) + " is not an ISO 3166-1 code.",
        hint: if code == "UK" {
          "Use \"GB\" (`country.uk`) for the United Kingdom."
        } else {
          "Use a country from the `country` module, e.g. `country: country.de`."
        },
      ),
    )
  }
  ()
}

#let _check-electronic-address(address, required, rule, field, term) = {
  if address == none or address.id == none {
    if required == none { return () }
    let make = if required == "error" { error } else { warning }
    return (
      make(
        rule,
        field,
        "The " + term + " is missing.",
        hint: "Set `electronic-address`, `vat-id` or `email` on the "
          + field
          + ".",
      ),
    )
  }
  if address.scheme == none {
    return (
      error(
        "BR-CL-25",
        field + ".electronic-address",
        "The " + term + " has no scheme.",
        hint: "Pass a dictionary such as `(scheme: \"EM\", id: \"invoice@example.com\")`.",
      ),
    )
  }
  if address.scheme not in codelists.eas {
    return (
      error(
        "BR-CL-25",
        field + ".electronic-address",
        "The scheme "
          + _quoted(address.scheme)
          + " of the "
          + term
          + " is not in the CEF EAS code list.",
        hint: "Use e.g. \"EM\" for an email address or \"0088\" for a GLN.",
      ),
    )
  }
  ()
}

#let _check-global-id(party, field) = {
  let global-id = party.at("global-id", default: none)
  if global-id == none or global-id.scheme == none { return () }
  if global-id.scheme not in codelists.icd {
    return (
      error(
        "BR-CL-10",
        field + ".global-id",
        "The scheme "
          + _quoted(global-id.scheme)
          + " of the global identifier is not an ISO/IEC 6523 code.",
        hint: "Use e.g. \"0088\" for a GLN or \"0060\" for a DUNS number.",
      ),
    )
  }
  ()
}

#let _check-vat-id-prefix(vat-id, field) = {
  if vat-id == none { return () }
  let prefix = vat-id.slice(0, calc.min(2, vat-id.len()))
  if prefix in codelists.countries or prefix in ("EL", "1A", "AN") {
    return ()
  }
  (
    error(
      "BR-CO-09",
      field,
      "The VAT identifier "
        + _quoted(vat-id)
        + " does not start with a country prefix.",
      hint: "Write the VAT identifier with its country prefix, e.g. \"DE123456789\".",
    ),
  )
}

#let check-parties(model) = {
  let profile = model.profile
  let seller = model.seller
  let buyer = model.buyer
  let out = ()

  if seller.name == none {
    out.push(error(
      "BR-06",
      "sender.name",
      "The seller name (BT-27) is missing.",
      hint: "Set `name` on the sender.",
    ))
  }
  if buyer.name == none {
    out.push(error(
      "BR-07",
      "recipient.name",
      "The buyer name (BT-44) is missing.",
      hint: "Set `name` on the recipient.",
    ))
  }

  out += _check-country(
    seller.address.country,
    "BR-09",
    "sender.country",
    "seller country code (BT-40)",
  )
  if profile.addresses {
    out += _check-country(
      buyer.address.country,
      "BR-11",
      "recipient.country",
      "buyer country code (BT-55)",
    )
    if model.ship-to != none {
      out += _check-country(
        model.ship-to.address.country,
        "BR-57",
        "delivery-address.country",
        "deliver-to country code (BT-80)",
      )
    }
  }

  out += _check-vat-id-prefix(seller.vat-id, "sender.vat-id")
  if profile.buyer-vat-id {
    out += _check-vat-id-prefix(buyer.vat-id, "recipient.vat-id")
  }

  // BR-CO-26: the buyer must be able to identify the seller.
  if profile.id == "minimum" {
    if seller.vat-id == none {
      out.push(error(
        "BR-CO-26",
        "sender.vat-id",
        "The MINIMUM profile identifies the seller by the VAT identifier (BT-31), which is missing.",
        hint: "Set `vat-id` on the sender, or use the \"basic-wl\" profile or higher to identify the seller by `tax-nr` or `id`.",
      ))
    }
  } else if (
    seller.id == none and seller.global-id == none and seller.vat-id == none
  ) {
    out.push(error(
      "BR-CO-26",
      "sender",
      "The seller cannot be identified: neither a seller identifier (BT-29) nor a VAT identifier (BT-31) is given.",
      hint: if model.outside-scope and seller.stated-vat-id != none {
        "An invoice not subject to VAT leaves out the VAT identifier (BR-O-02). Set `tax-nr` or `id` on the sender."
      } else { "Set `vat-id`, `tax-nr` or `id` on the sender." },
    ))
  }

  if profile.party-ids {
    out += _check-global-id(seller, "sender")
    out += _check-global-id(buyer, "recipient")
    if model.ship-to != none {
      out += _check-global-id(model.ship-to, "delivery-address")
    }
  }

  if profile.addresses {
    // Required by XRechnung, recommended for EN 16931 (Peppol).
    let required = if profile.xrechnung { "error" } else if (
      profile.id == "en16931"
    ) { "warning" } else { none }
    out += _check-electronic-address(
      seller.electronic-address,
      required,
      "PEPPOL-EN16931-R020",
      "sender",
      "seller electronic address (BT-34)",
    )
    out += _check-electronic-address(
      buyer.electronic-address,
      required,
      "PEPPOL-EN16931-R010",
      "recipient",
      "buyer electronic address (BT-49)",
    )
  }

  if profile.xrechnung {
    let contact = seller.contact
    if contact == none {
      out.push(error(
        "BR-DE-2",
        "sender.contact",
        "XRechnung requires the seller contact (BG-6).",
        hint: "Set `contact: (name: .., phone: .., email: ..)` on the sender.",
      ))
    } else {
      for (key, rule, term) in (
        ("name", "BR-DE-5", "name (BT-41)"),
        ("phone", "BR-DE-6", "phone number (BT-42)"),
        ("email", "BR-DE-7", "email address (BT-43)"),
      ) {
        if contact.at(key) == none {
          out.push(error(
            rule,
            "sender.contact." + key,
            "XRechnung requires the seller contact " + term + ".",
            hint: "Set `contact."
              + key
              + "` (or `"
              + if key == "name" { "contact-name" } else { key }
              + "`) on the sender.",
          ))
        }
      }
      if (
        contact.phone != none and contact.phone.matches(_digit).len() < 3
      ) {
        // BR-DE-27 and BR-DE-28 are warnings for the KoSIT validator, but
        // Mustang rejects the invoice: invoice-pro treats them as errors.
        out.push(error(
          "BR-DE-27",
          "sender.contact.phone",
          "The seller contact phone number (BT-42) "
            + _quoted(contact.phone)
            + " has fewer than three digits.",
          hint: "Write the phone number with its digits, e.g. \"+49 89 1234567\".",
        ))
      }
      if contact.email != none and contact.email.match(_xr-email) == none {
        out.push(error(
          "BR-DE-28",
          "sender.contact.email",
          "The seller contact email address (BT-43) "
            + _quoted(contact.email)
            + " is not an email address XRechnung accepts.",
          hint: "Write one \"@\" between the name and a domain of ASCII letters, digits, hyphens and dots, and a domain with umlauts in punycode, e.g. \"info@xn--mller-bau-q9a.de\" for \"info@müller-bau.de\".",
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
        out.push(error(
          city-rule,
          field + ".city",
          "XRechnung requires the " + term + " city.",
          hint: "Set `city` on the "
            + field
            + ", e.g. \"10115 Berlin\" or `(name: \"Berlin\", post-code: \"10115\")`.",
        ))
      }
      if party.address.post-code == none {
        out.push(error(
          code-rule,
          field + ".city",
          "XRechnung requires the " + term + " post code.",
          hint: "Write the post code in `city` on the "
            + field
            + ", e.g. \"10115 Berlin\" or `(name: \"Berlin\", post-code: \"10115\")`.",
        ))
      }
    }

    if model.invoice.buyer-reference == none {
      out.push(error(
        "BR-DE-15",
        "recipient.buyer-reference",
        "XRechnung requires the buyer reference (BT-10), e.g. the Leitweg-ID.",
        hint: "Set `buyer-reference` (or `leitweg-id`) on the recipient.",
      ))
    }
  }

  out
}

// --- Lines ----------------------------------------------------------------

#let check-lines(model) = {
  if not model.profile.lines { return () }
  let out = ()
  if model.lines.len() == 0 {
    out.push(error(
      "BR-16",
      "line-items",
      "The invoice has no line items (BG-25).",
      hint: "Add at least one `item` to `line-items`.",
    ))
  }
  for line in model.lines {
    let field = _line-field(line)
    if line.name == none {
      out.push(error(
        "BR-25",
        field,
        "The item name (BT-153) has no text.",
        hint: "Give the item a name that contains text.",
      ))
    }
    let unit-issue = line.at("unit-issue", default: none)
    if line.unit-code not in codelists.units {
      out.push(error(
        "BR-CL-23",
        field,
        "The unit code (BT-130) "
          + _quoted(line.unit-code)
          + " is not a UN/ECE Recommendation 20 code.",
        hint: "Use a unit from the `unit` module, e.g. `unit.hour`, or a dictionary such as `(display: \"Std.\", code: \"HUR\")`.",
      ))
    } else if unit-issue != none and unit-issue.kind == "unknown" {
      // The unit is written as a code, and a text invoice-pro does not know
      // has none: writing "one" (C62) for it would be a guess.
      out.push(error(
        "BR-CL-23",
        field,
        "The unit "
          + _quoted(unit-issue.text)
          + " has no UN/ECE Recommendation 20 code (BT-130) invoice-pro knows.",
        hint: "Use a unit from the `unit` module, e.g. `unit.hour` or `unit.square-metre`, or give its code: `(display: "
          + _quoted(unit-issue.text)
          + ", code: \"..\")`, e.g. \"C62\" for a number of units.",
      ))
    } else if unit-issue != none and unit-issue.kind == "ambiguous" {
      out.push(warning(
        "IP-UNIT-01",
        field,
        "The unit "
          + _quoted(unit-issue.text)
          + " is written as the UN/ECE Recommendation 20 code for "
          + unit-issue.meaning
          + ", although it is also a common abbreviation of \""
          + unit-issue.abbreviation
          + "\".",
        hint: "Give the code explicitly, e.g. `(display: "
          + _quoted(unit-issue.text)
          + ", code: \"H87\")` for pieces, or `(display: .., code: "
          + _quoted(unit-issue.text)
          + ")` if you mean the code.",
      ))
    }
    if line.key == none or line.category == none {
      out.push(error(
        "BR-CO-04",
        field,
        "The item has no VAT category (BT-151).",
        hint: "Set `tax` on the item, e.g. `tax.vat(19%)`.",
      ))
    }
    // The price refers to a positive quantity; `item` and `bundle` stop on
    // any other already.
    if line.base-quantity <= _zero {
      out.push(error(
        "PEPPOL-EN16931-R121",
        field,
        "The price base quantity (BT-149) must be greater than 0.",
        hint: "Set `base-quantity` to the quantity the price refers to, e.g. 100 for a price per 100 pieces.",
      ))
    }
  }
  out
}

// --- VAT ------------------------------------------------------------------

// Margin schemes have no category in EN 16931: they are written as exempt
// with the note the VAT Directive requires (art. 226 no. 13 and 14).
#let _margin-scheme-hint(scheme, german) = (
  "EN 16931 has no category for margin schemes: write the items as exempt with the note the law requires, e.g. `tax.exempt(grounds: \"Margin scheme - "
    + scheme
    + "\")` (in Germany \""
    + german
    + "\")."
)

// Categories EN 16931 knows, and how to express the others.
#let _category-hints = (
  AA: "Use `tax.vat(..)` with the reduced rate, e.g. `tax.vat(7%)`.",
  H: "Use `tax.vat(..)` with the higher rate.",
  N: "Use `tax.vat(..)` with the additional rate.",
  B: "Split payment (B) is not supported by Factur-X / ZUGFeRD.",
  D: _margin-scheme-hint("travel agents", "Sonderregelung für Reisebüros"),
  F: _margin-scheme-hint(
    "second-hand goods",
    "Gebrauchtgegenstände/Sonderregelung",
  ),
  I: _margin-scheme-hint("works of art", "Kunstgegenstände/Sonderregelung"),
  J: _margin-scheme-hint(
    "collector's items and antiques",
    "Sammlungsstücke und Antiquitäten/Sonderregelung",
  ),
)

// The rule families of the VAT categories: BR-S-*, BR-IC-*, ...
#let _category-rules = (
  S: "BR-S",
  Z: "BR-Z",
  E: "BR-E",
  AE: "BR-AE",
  K: "BR-IC",
  G: "BR-G",
  O: "BR-O",
  L: "BR-AF",
  M: "BR-AG",
)

// A rule of the family of a VAT category, e.g. `_category-rule("K", 2)` is
// BR-IC-02.
#let _category-rule(category, number) = (
  _category-rules.at(category)
    + "-"
    + (if number < 10 { "0" } else { "" })
    + str(number)
)

// The categories that need a seller VAT identifier or tax number (BR-x-02,
// -03, -04); K and G need the VAT identifier.
#let _taxed-categories = ("S", "Z", "E", "AE", "L", "M")

// The rules of the VAT categories come in threes: for invoice lines (e.g.
// BR-S-02, BR-S-05), document level allowances (BR-S-03, BR-S-06) and
// document level charges (BR-S-04, BR-S-07). The offset of the rule that
// applies to where a category occurs, or `none`: BASIC WL has no lines, so
// there only the rules of allowances and charges apply.
#let _rule-offset(occurrence, lines) = {
  if lines and occurrence.line { 0 } else if occurrence.allowance {
    1
  } else if occurrence.charge { 2 } else { none }
}

// Who has the VAT category of a rule offset, for messages.
#let _holders = ("Items", "Document level allowances", "Document level charges")

// Where each VAT category and VAT group (by `key`) occurs: on lines, on
// document level allowances or charges.
#let _occurrences(model) = {
  let none-yet = (line: false, allowance: false, charge: false)
  let found = (:)
  for line in model.lines {
    for name in (line.category, line.key) {
      if name == none { continue }
      found.insert(name, found.at(name, default: none-yet) + (line: true))
    }
  }
  for entry in model.allowance-charges {
    let kind = if entry.charge { "charge" } else { "allowance" }
    for name in (entry.category, entry.key) {
      if name == none { continue }
      found.insert(name, found.at(name, default: none-yet) + ((kind): true))
    }
  }
  found
}

#let _basis-rules = (
  S: "BR-S-08",
  Z: "BR-Z-08",
  E: "BR-E-08",
  AE: "BR-AE-08",
  K: "BR-IC-08",
  G: "BR-G-08",
  O: "BR-O-08",
  L: "BR-AF-08",
  M: "BR-AG-08",
)

#let check-taxes(model) = {
  // MINIMUM carries no VAT details, only the totals.
  if not model.profile.settlement { return () }
  let out = ()
  let seller = model.seller
  let buyer = model.buyer
  let lines = model.profile.lines
  let categories = model
    .taxes
    .map(tax => tax.category)
    .filter(category => category != none)
    .dedup()
  let occurrences = _occurrences(model)
  let none-yet = (line: false, allowance: false, charge: false)
  // The rule offset of a VAT category or group (see `_rule-offset`).
  let offset(name) = _rule-offset(
    if name == none { none-yet } else {
      occurrences.at(name, default: none-yet)
    },
    lines,
  )

  // BR-CO-18: an invoice has a VAT breakdown. With lines, BR-16 (no lines)
  // says the same.
  if model.taxes.len() == 0 and not lines {
    out.push(error(
      "BR-CO-18",
      "line-items",
      "The invoice has no VAT breakdown (BG-23).",
      hint: "Add at least one `item` to `line-items`.",
    ))
  }

  // The number of VAT groups per category and rate as the XML states them
  // (`_tax-field` names both, also for a group without category).
  let stated-groups = (:)
  for tax in model.taxes {
    let group = _tax-field(tax)
    stated-groups.insert(group, stated-groups.at(group, default: 0) + 1)
  }

  for tax in model.taxes {
    let field = _tax-field(tax)
    let category = tax.category

    // IP-DEC-01: the XML states a rate with up to `rate-digits` decimals, so
    // a rate with more would be written as another rate, possibly as the
    // rate of another VAT group.
    let percent = tax.rate * 100
    if calc.round(percent, digits: rate-digits) != percent {
      out.push(error(
        "IP-DEC-01",
        field,
        "The VAT rate "
          + fmt-number(percent, min-digits: 0, max-digits: 28)
          + "% has more than "
          + str(rate-digits)
          + " decimals, so the e-invoice would state it as "
          + _percent(tax.rate)
          + if stated-groups.at(field) > 1 {
            (
              ", the rate of another VAT group"
                + if category != none { " of category " + category }
            )
          }
          + ".",
        hint: "Round the rate to at most "
          + str(rate-digits)
          + " decimals, e.g. `tax.vat(8.125%)`.",
      ))
    }

    if category == none or category not in codelists.vat-categories {
      let default-hint = "Use a constructor of the `tax` module such as `tax.vat(..)`, `tax.zero()` or `tax.exempt(..)`."
      out.push(error(
        "BR-CL-18",
        field,
        "The VAT category "
          + _quoted(category)
          + " is not allowed in EN 16931 (allowed: S, Z, E, AE, K, G, O, L, M).",
        hint: if category == none { default-hint } else {
          _category-hints.at(category, default: default-hint)
        },
      ))
      continue
    }

    // The rate of the lines (BR-x-05), allowances (BR-x-06) and charges
    // (BR-x-07) of the group. In BASIC WL, a group of lines only is left to
    // the rules of the VAT breakdown (BR-x-09).
    let rate-rule = offset(tax.key)
    if rate-rule != none { rate-rule = _category-rule(category, 5 + rate-rule) }
    if category in ("S", "L", "M") and tax.rate <= _zero and rate-rule != none {
      out.push(error(
        rate-rule,
        field,
        (
          S: "A standard rated VAT category (S)",
          L: "The IGIC category (L)",
          M: "The IPSI category (M)",
        ).at(category)
          + " needs a rate above 0%.",
        hint: "Use `tax.zero()` for zero rated or `tax.exempt(grounds: ..)` for exempt items.",
      ))
    }
    if category in ("Z", "E", "AE", "K", "G") and tax.rate != _zero {
      if rate-rule == none and tax.amount != _zero {
        rate-rule = _category-rule(category, 9)
      }
      if rate-rule != none {
        out.push(error(
          rate-rule,
          field,
          "The VAT category " + category + " requires a rate of 0%.",
          hint: "Use the matching constructor of the `tax` module, which sets the rate.",
        ))
      }
    }
    // BR-O-09: items not subject to VAT carry no VAT, so O has no rate.
    if category == "O" and tax.rate != _zero {
      out.push(error(
        "BR-O-09",
        field,
        "Items not subject to VAT (O) carry no VAT, so they have no rate.",
        hint: "Use `tax.outside-scope()`, which has none.",
      ))
    }
    if category == "E" and tax.reason == none {
      out.push(error(
        "BR-E-10",
        field,
        "Exempt items (E) need the VAT exemption reason (BT-120).",
        hint: "State the legal reason, e.g. `tax.exempt(grounds: \"Steuerfrei nach § 4 Nr. 21 UStG\")`.",
      ))
    }
  }

  // The identifiers of the parties each category requires where it occurs:
  // on lines (BR-x-02), allowances (BR-x-03) or charges (BR-x-04).
  let taxed = categories.filter(c => (
    c in _taxed-categories and offset(c) != none
  ))
  if taxed.len() > 0 and seller.vat-id == none and seller.tax-nr == none {
    let first = offset(taxed.first())
    out.push(error(
      _category-rule(taxed.first(), 2 + first),
      "sender",
      _holders.at(first)
        + " with the VAT category "
        + taxed.join(", ")
        + " require the seller VAT identifier (BT-31) or tax number (BT-32).",
      hint: "Set `vat-id` or `tax-nr` on the sender.",
    ))
  }
  for (category, term) in (
    ("K", "An intra-community supply (K)"),
    ("G", "An export outside the EU (G)"),
  ) {
    let at = offset(category)
    if category in categories and at != none and seller.vat-id == none {
      out.push(error(
        _category-rule(category, 2 + at),
        "sender.vat-id",
        term + " requires the seller VAT identifier (BT-31).",
        hint: "Set `vat-id` on the sender.",
      ))
    }
  }
  // An intra-community supply and a reverse charge to a buyer in another
  // country need the buyer VAT identifier by law (VAT Directive art. 226 no.
  // 4), also in BASIC WL, where the rules of lines do not apply (IP-VAT-226).
  // A domestic reverse charge (e.g. § 13b UStG) does not.
  let cross-border = seller.address.country != buyer.address.country
  let buyer-identified = (
    buyer.vat-id != none or buyer.at("legal-id", default: none) != none
  )
  let by-law = " by law (VAT Directive 2006/112/EC, art. 226 no. 4)"
  if "K" in categories and buyer.vat-id == none {
    let at = offset("K")
    out.push(error(
      if at == none { "IP-VAT-226" } else { _category-rule("K", 2 + at) },
      "recipient.vat-id",
      "An intra-community supply (K) requires the buyer VAT identifier (BT-48)"
        + if at == none { by-law }
        + ".",
      hint: "Set `vat-id` on the recipient.",
    ))
  }
  if "AE" in categories and not buyer-identified {
    let at = offset("AE")
    if at != none {
      out.push(error(
        _category-rule("AE", 2 + at),
        "recipient.vat-id",
        "Reverse charge (AE) requires the buyer VAT identifier (BT-48).",
        hint: "Set `vat-id` on the recipient.",
      ))
    } else if cross-border {
      out.push(error(
        "IP-VAT-226",
        "recipient.vat-id",
        "A reverse charge (AE) to a buyer in another country requires the buyer VAT identifier (BT-48)"
          + by-law
          + ".",
        hint: "Set `vat-id` on the recipient.",
      ))
    }
  }
  if "K" in categories and model.ship-to == none {
    out.push(error(
      "BR-IC-12",
      "delivery-address",
      "An intra-community supply (K) requires the deliver-to country (BT-80).",
      hint: "Set `country` on the recipient or pass a `delivery-address`.",
    ))
  }
  if "O" in categories and categories.len() > 1 {
    out.push(error(
      "BR-O-11",
      "tax",
      "Items not subject to VAT (O) cannot be combined with other VAT categories ("
        + categories.filter(c => c != "O").join(", ")
        + ") on one invoice.",
      hint: "Invoice the items outside the scope of VAT separately.",
    ))
  }
  out
}

// --- Payment --------------------------------------------------------------

// BR-DE-18, as the XRechnung 3.0 validation tests it: each line of the
// payment terms (BT-20) that starts with "#" matches XR-SKONTO-REGEX, and the
// text after the last "#...#" starts with a line break.
#let _skonto-line = regex(
  "#(SKONTO)#TAGE=([0-9]+#PROZENT=[0-9]+\\.[0-9]{2})(#BASISBETRAG=-?[0-9]+\\.[0-9]{2})?#$",
)
// Whitespace as XPath's normalize-space() collapses it, and `\s` of XPath
// regular expressions: a space, tab or line break.
#let _xml-whitespace = regex("[ \\t\\r\\n]+")

// What breaks the XRechnung Skonto syntax in the payment terms (BR-DE-18):
// `none` if nothing does, `(line: ..)` for a line that starts with "#" but is
// no cash discount, and `(after: ..)` for the line of the last "#...#" if no
// line break follows it.
#let _skonto-problem(terms) = {
  let lines = terms.split("\n")
  let skonto = false
  for line in lines {
    let normalized = line.replace(_xml-whitespace, " ").trim(" ")
    if normalized.starts-with("#") {
      if normalized.match(_skonto-line) == none { return (line: normalized) }
      skonto = true
    }
  }
  if not skonto { return none }
  // The validation splits the terms at `#.+#`, whose `.` is no line break:
  // the last "#...#" reaches from the first to the last "#" of the last line
  // with two "#" and text between them. (No regular expression: compiling
  // this one takes a third of a millisecond on every compile.)
  let i = lines.len() - 1
  while i >= 0 {
    let parts = lines.at(i).split("#")
    if parts.len() >= 3 and parts.slice(1, -1).join("#") != "" {
      if (
        i < lines.len() - 1 and parts.last().replace(_xml-whitespace, "") == ""
      ) {
        return none
      }
      return (after: lines.at(i).replace(_xml-whitespace, " ").trim(" "))
    }
    i -= 1
  }
  none
}

#let check-payment(model) = {
  if not model.profile.settlement { return () }
  let out = ()
  let payment = model.payment

  if model.profile.xrechnung and payment.terms != none {
    let problem = _skonto-problem(payment.terms)
    if problem != none {
      let input = payment.at("terms-input", default: none)
      let syntax = "every line that starts with \"#\" must be a cash discount in the XRechnung syntax, e.g. \"#SKONTO#TAGE=14#PROZENT=2.00#\", followed by a line break"
      let line = problem.at("line", default: none)
      let after = problem.at("after", default: none)
      out.push(error(
        "BR-DE-18",
        if input == none { "payment-goal" } else { input },
        "In the payment terms (BT-20), "
          + if line != none {
            syntax + ", but " + _quoted(line) + " is not."
          } else if after.starts-with("#") {
            syntax + "."
          } else {
            (
              "XRechnung reads the text between the first and the last \"#\" of a line as a cash discount, which a line break must follow, but "
                + _quoted(after)
                + " goes on after its last \"#\"."
            )
          },
        hint: "Write each cash discount on a line of its own: `#SKONTO#TAGE=` with the days, `#PROZENT=` with the percent and two decimals, optionally `#BASISBETRAG=` with the amount it applies to, and a closing `#`, e.g. \"Zahlbar innerhalb von 30 Tagen.\\n#SKONTO#TAGE=14#PROZENT=2.00#\". Do not start other lines with \"#\", and do not write text after the last \"#\" of a line that contains two.",
      ))
    }
  }

  if (
    model.totals.due > _zero
      and payment.due-date == none
      and payment.terms == none
  ) {
    out.push(error(
      "BR-CO-25",
      "payment-goal",
      "An amount is due, but neither the payment due date (BT-9) nor the payment terms (BT-20) are given.",
      hint: "Add `#payment-goal(days: 14)` or set `due-date` on the invoice.",
    ))
  }

  if payment.means == none {
    if model.profile.xrechnung {
      out.push(error(
        "BR-DE-1",
        "bank-details",
        "XRechnung requires payment instructions (BG-16).",
        hint: "Add `#bank-details(iban: ..)` with the account to pay to.",
      ))
    }
  } else if not iban-valid(payment.means.iban) {
    out.push(warning(
      "BR-DE-19",
      "bank-details.iban",
      "The IBAN (BT-84) " + _quoted(payment.means.iban) + " is not valid.",
      hint: "Check the IBAN for typos.",
    ))
  }

  if model.totals.prepaid > model.totals.gross and model.totals.gross >= _zero {
    out.push(warning(
      "BR-CO-16",
      "prepayment",
      "The prepaid amount (BT-113) exceeds the invoice total, so the amount due (BT-115) is negative.",
    ))
  }
  out
}

// --- Consistency ----------------------------------------------------------

// Whether an amount has more than the 2 decimals the XML states (BR-DEC-*).
#let _cents-exceeded(amount) = calc.round(amount, digits: 2) != amount

// The first amount the XML cannot state because it has more than 2 decimals,
// in the order of the XML, and how many there are: (count: .., rule: ..,
// term: .., place: .., value: ..). Only the amounts the profile writes count.
#let _excess-decimals(model) = {
  let found = (count: 0)
  let note(found, rule, term, place, value) = {
    if found.count == 0 {
      found += (rule: rule, term: term, place: place, value: value)
    }
    found.count += 1
    found
  }
  let profile = model.profile
  if profile.lines {
    for line in model.lines {
      if _cents-exceeded(line.net) {
        found = note(
          found,
          "BR-DEC-23",
          "line net amount (BT-131)",
          _line-field(line),
          line.net,
        )
      }
      for entry in line.allowances {
        if _cents-exceeded(entry.amount) {
          found = note(
            found,
            "BR-DEC-24",
            "line allowance (BT-136)",
            _line-field(line),
            entry.amount,
          )
        }
      }
      for entry in line.charges {
        if _cents-exceeded(entry.amount) {
          found = note(
            found,
            "BR-DEC-27",
            "line charge (BT-141)",
            _line-field(line),
            entry.amount,
          )
        }
      }
    }
  }
  let totals = model.totals
  let amounts = ()
  if profile.settlement {
    for entry in model.allowance-charges {
      amounts.push(if entry.charge {
        ("BR-DEC-05", "document level charge (BT-99)", entry.amount)
      } else {
        ("BR-DEC-01", "document level allowance (BT-92)", entry.amount)
      })
    }
    for tax in model.taxes {
      amounts.push(("BR-DEC-19", "VAT taxable amount (BT-116)", tax.basis))
      amounts.push(("BR-DEC-20", "VAT amount (BT-117)", tax.amount))
    }
    amounts += (
      ("BR-DEC-09", "sum of the line net amounts (BT-106)", totals.line),
      ("BR-DEC-10", "sum of the allowances (BT-107)", totals.allowance),
      ("BR-DEC-11", "sum of the charges (BT-108)", totals.charge),
      ("BR-DEC-16", "prepaid amount (BT-113)", totals.prepaid),
    )
  }
  amounts += (
    ("BR-DEC-12", "total without VAT (BT-109)", totals.net),
    ("BR-DEC-13", "total VAT amount (BT-110)", totals.tax),
    ("BR-DEC-14", "total with VAT (BT-112)", totals.gross),
    ("BR-DEC-18", "amount due (BT-115)", totals.due),
  )
  for (rule, term, value) in amounts {
    if _cents-exceeded(value) {
      found = note(found, rule, term, none, value)
    }
  }
  found
}

// The XML must state what the invoice prints and add up in itself. A failure
// here is a bug in invoice-pro, not in the invoice data.
#let check-consistency(model) = {
  let out = ()
  let bug-hint = "This is a bug in invoice-pro. Please report it at https://github.com/leonieziechmann/invoice-pro/issues."

  // BR-DEC-*: the XML states amounts with 2 decimals. Rounded there, amounts
  // with more (from a locale that rounds money more finely) would no longer
  // add up (BR-CO-10, BR-S-08, ...), so they cannot be written at all.
  let excess = _excess-decimals(model)
  if excess.count > 0 {
    out.push(error(
      excess.rule,
      "locale",
      "An e-invoice states amounts with 2 decimals, but "
        + if excess.count == 1 { "the " } else {
          str(excess.count) + " amounts have more, e.g. the "
        }
        + excess.term
        + if excess.place != none { " of " + excess.place }
        + " is "
        + str(excess.value)
        + ".",
      hint: "Round money to 2 decimals in the locale, e.g. `locale.custom.normalize(money: x => calc.round(x, digits: 2))`.",
    ))
    // The sums below would only repeat that the rounded amounts do not add
    // up. Without excess decimals, the amounts of the model are exactly the
    // amounts the XML states, so they are compared as they are.
    return out
  }

  let totals = model.totals
  let printed = model.printed-totals
  if totals.net != printed.net or totals.gross != printed.gross {
    out.push(error(
      "BR-CO-15",
      "line-items",
      "The totals of the XML ("
        + str(totals.net)
        + " net, "
        + str(totals.gross)
        + " gross) differ from the printed totals ("
        + str(printed.net)
        + " net, "
        + str(printed.gross)
        + " gross).",
      hint: bug-hint,
    ))
  }
  if model.profile.settlement {
    let basis = _sum(model.taxes.map(tax => tax.basis))
    if basis != totals.net {
      out.push(error(
        "BR-CO-13",
        "line-items",
        "The VAT breakdown ("
          + str(basis)
          + ") does not add up to the total without VAT ("
          + str(totals.net)
          + ").",
        hint: bug-hint,
      ))
    }
    // BR-CO-17: the VAT amount is the taxable amount times the rate the XML
    // states, within the tolerance of 1 the validators allow (the amounts of
    // gross prices are rounded differently). Categories not subject to VAT
    // (O) and rates the XML cannot state (IP-DEC-01) are checked elsewhere.
    for tax in model.taxes {
      let percent = calc.round(tax.rate * 100, digits: rate-digits)
      if tax.category == "O" or percent != tax.rate * 100 { continue }
      let expected = calc.round(tax.basis * percent / 100, digits: 2)
      if calc.abs(tax.amount - expected) > 1 {
        out.push(error(
          "BR-CO-17",
          _tax-field(tax),
          "The VAT amount "
            + str(tax.amount)
            + " is not the taxable amount "
            + str(tax.basis)
            + " times the rate ("
            + str(expected)
            + ").",
          hint: bug-hint,
        ))
      }
    }
  }
  if model.profile.lines {
    for tax in model.taxes {
      let lines = model.lines.filter(line => line.key == tax.key)
      let entries = model.allowance-charges.filter(e => e.key == tax.key)
      let amount = (
        _sum(lines.map(line => line.net))
          + _sum(entries.map(e => if e.charge { e.amount } else { -e.amount }))
      )
      if amount != tax.basis {
        out.push(error(
          if tax.category == none { "BR-CO-13" } else {
            _basis-rules.at(tax.category, default: "BR-CO-13")
          },
          _tax-field(tax),
          "The lines of this VAT category add up to "
            + str(amount)
            + " instead of the taxable amount "
            + str(tax.basis)
            + ".",
          hint: bug-hint,
        ))
      }
    }
  }
  out
}

/// Validates an e-invoice data model and returns all diagnostics, errors first.
///
/// -> array
#let validate(model) = {
  let diagnostics = (
    check-document(model)
      + check-parties(model)
      + check-lines(model)
      + check-taxes(model)
      + check-payment(model)
      + check-consistency(model)
  )
  (
    diagnostics.filter(d => d.level == "error")
      + diagnostics.filter(d => d.level != "error")
  )
}
