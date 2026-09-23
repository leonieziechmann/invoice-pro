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

// ISO 7064 MOD 97-10 check of an IBAN (without whitespace).
#let _iban-valid(iban) = {
  if iban.match(regex("^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$")) == none {
    return false
  }
  let remainder = 0
  for char in (iban.slice(4) + iban.slice(0, 4)).clusters() {
    if char.match(regex("^[0-9]$")) != none {
      remainder = calc.rem(remainder * 10 + int(char), 97)
    } else {
      remainder = calc.rem(remainder * 100 + str.to-unicode(char) - 55, 97)
    }
  }
  remainder == 1
}

// --- Document -------------------------------------------------------------

// The characters of a printed amount besides its currency: digits,
// separators, signs and spaces.
#let _amount-characters = regex("[\\d\\s.,'’+\\-()]")

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

  // IP-PRINT-02: the invoice prints its amounts in the currency the XML
  // states: with its code or the symbol of the locale, and not with "€" for
  // another currency. A formatter that prints no currency says nothing else.
  let printed = model.at("printed-currency", default: none)
  if (
    type(model.currency) == str
      and model.currency in codelists.currencies
      and printed != none
  ) {
    for sample in printed.samples {
      let sign = sample.replace(_amount-characters, "")
      if (
        sign == ""
          or not (sample.contains("€") and model.currency != "EUR")
            and (
              sample.contains(model.currency)
                or printed.symbol != none and sample.contains(printed.symbol)
            )
      ) { continue }
      out.push(error(
        "IP-PRINT-02",
        "locale",
        "The invoice prints amounts in "
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
        contact.phone != none
          and contact.phone.matches(regex("[0-9]")).len() < 3
      ) {
        out.push(warning(
          "BR-DE-27",
          "sender.contact.phone",
          "The seller contact phone number (BT-42) should contain at least three digits.",
        ))
      }
      if (
        contact.email != none
          and contact.email.match(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"))
            == none
      ) {
        out.push(warning(
          "BR-DE-28",
          "sender.contact.email",
          "The seller contact email address (BT-43) "
            + _quoted(contact.email)
            + " does not look like an email address.",
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
    if line.unit-code not in codelists.units {
      out.push(error(
        "BR-CL-23",
        field,
        "The unit code (BT-130) "
          + _quoted(line.unit-code)
          + " is not a UN/ECE Recommendation 20 code.",
        hint: "Use a unit from the `unit` module, e.g. `unit.hour`, or a dictionary such as `(display: \"Std.\", code: \"HUR\")`.",
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
  }
  out
}

// --- VAT ------------------------------------------------------------------

// Categories EN 16931 knows, and how to express the others.
#let _category-hints = (
  AA: "Use `tax.vat(..)` with the reduced rate, e.g. `tax.vat(7%)`.",
  H: "Use `tax.vat(..)` with the higher rate.",
  N: "Use `tax.vat(..)` with the additional rate.",
  B: "Split payment (B) is not supported by Factur-X / ZUGFeRD.",
)

// The rules requiring a seller VAT identifier or tax number per category.
#let _seller-id-rules = (
  S: "BR-S-02",
  Z: "BR-Z-02",
  E: "BR-E-02",
  AE: "BR-AE-02",
  L: "BR-AF-02",
  M: "BR-AG-02",
)

#let _zero-rate-rules = (
  Z: "BR-Z-05",
  E: "BR-E-05",
  AE: "BR-AE-05",
  K: "BR-IC-05",
  G: "BR-G-05",
)

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
  let categories = model
    .taxes
    .map(tax => tax.category)
    .filter(category => category != none)
    .dedup()

  // The number of VAT groups per category and rate as the XML states them.
  let stated-groups = (:)
  for tax in model.taxes {
    let group = str(tax.category) + " " + _percent(tax.rate)
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
      let group = str(category) + " " + _percent(tax.rate)
      out.push(error(
        "IP-DEC-01",
        field,
        "The VAT rate "
          + fmt-number(percent, min-digits: 0, max-digits: 28)
          + "% has more than "
          + str(rate-digits)
          + " decimals, so the e-invoice would state it as "
          + _percent(tax.rate)
          + if stated-groups.at(group) > 1 {
            ", the rate of another VAT group of category " + str(category)
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
    if category == "S" and tax.rate <= _zero {
      out.push(error(
        "BR-S-05",
        field,
        "A standard rated VAT category (S) needs a rate above 0%.",
        hint: "Use `tax.zero()` for zero rated or `tax.exempt(grounds: ..)` for exempt items.",
      ))
    }
    if category == "L" and tax.rate <= _zero {
      out.push(error(
        "BR-AF-05",
        field,
        "The IGIC category (L) needs a rate above 0%.",
      ))
    }
    if category in _zero-rate-rules and tax.rate != _zero {
      out.push(error(
        _zero-rate-rules.at(category),
        field,
        "The VAT category " + category + " requires a rate of 0%.",
        hint: "Use the matching constructor of the `tax` module, which sets the rate.",
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

  let taxed = categories.filter(c => c in _seller-id-rules)
  if taxed.len() > 0 and seller.vat-id == none and seller.tax-nr == none {
    out.push(error(
      _seller-id-rules.at(taxed.first()),
      "sender",
      "Items with the VAT category "
        + taxed.join(", ")
        + " require the seller VAT identifier (BT-31) or tax number (BT-32).",
      hint: "Set `vat-id` or `tax-nr` on the sender.",
    ))
  }
  for (category, rule, term) in (
    ("K", "BR-IC-02", "An intra-community supply (K)"),
    ("G", "BR-G-02", "An export outside the EU (G)"),
  ) {
    if category in categories and seller.vat-id == none {
      out.push(error(
        rule,
        "sender.vat-id",
        term + " requires the seller VAT identifier (BT-31).",
        hint: "Set `vat-id` on the sender.",
      ))
    }
  }
  if "K" in categories and buyer.vat-id == none {
    out.push(error(
      "BR-IC-02",
      "recipient.vat-id",
      "An intra-community supply (K) requires the buyer VAT identifier (BT-48).",
      hint: "Set `vat-id` on the recipient.",
    ))
  }
  if "AE" in categories and buyer.vat-id == none {
    out.push(error(
      "BR-AE-02",
      "recipient.vat-id",
      "Reverse charge (AE) requires the buyer VAT identifier (BT-48).",
      hint: "Set `vat-id` on the recipient.",
    ))
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
#let _line-break = regex("\\r?\\n")
#let _hash-block = regex("#.+#")
#let _leading-line-break = regex("^\\s*\\n")
// Whitespace as XPath's normalize-space() collapses it.
#let _xml-whitespace = regex("[ \\t\\r\\n]+")

// The line of the payment terms that breaks the XRechnung Skonto syntax
// (BR-DE-18): `none` if there is none, "" if only the line break after the
// last Skonto line is missing.
#let _skonto-problem(terms) = {
  let skonto = false
  for line in terms.split(_line-break) {
    let normalized = line.replace(_xml-whitespace, " ").trim(" ")
    if normalized.starts-with("#") {
      if normalized.match(_skonto-line) == none { return normalized }
      skonto = true
    }
  }
  if (
    skonto
      and terms.split(_hash-block).last().match(_leading-line-break) == none
  ) { return "" }
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
      out.push(error(
        "BR-DE-18",
        if input == none { "payment-goal" } else { input },
        "In the payment terms (BT-20), every line that starts with \"#\" must be a cash discount in the XRechnung syntax, e.g. \"#SKONTO#TAGE=14#PROZENT=2.00#\", followed by a line break"
          + if problem == "" { "." } else {
            ", but " + _quoted(problem) + " is not."
          },
        hint: "Write each cash discount on a line of its own: `#SKONTO#TAGE=` with the days, `#PROZENT=` with the percent and two decimals, optionally `#BASISBETRAG=` with the amount it applies to, and a closing `#`, e.g. \"Zahlbar innerhalb von 30 Tagen.\\n#SKONTO#TAGE=14#PROZENT=2.00#\". Do not start other lines with \"#\".",
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
  } else if not _iban-valid(payment.means.iban) {
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
