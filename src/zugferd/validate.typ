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
// likely not intended. Rules whose id starts with "IP-" are rules of
// invoice-pro itself: where the official rules accept the XML, but the invoice
// would still be wrong (e.g. required by law, or a value would be lost).

#import "codelists.typ"
#import "xml.typ": fmt-number
#import "model.typ": vat-eas-codes, vat-id-prefix

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

#let _percent(rate) = fmt-number(rate * 100, min-digits: 0) + "%"

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

// `rules`: the rule for a missing address and the rule for a missing scheme.
#let _check-electronic-address(party, required, rules, field, term) = {
  let (missing-rule, scheme-rule) = rules
  let address = party.electronic-address
  if address == none or address.id == none {
    if required == none { return () }
    let make = if required == "error" { error } else { warning }
    // Name only the inputs that can still provide the address.
    let vat-id = party.at("stated-vat-id", default: none)
    let hint = if vat-id == none {
      "Set `electronic-address`, `vat-id` or `email` on the " + field + "."
    } else {
      let prefix = vat-id-prefix(vat-id)
      let reason = if prefix != none and prefix not in vat-eas-codes {
        (
          " (there is no electronic address scheme for its prefix "
            + _quoted(prefix)
            + ")"
        )
      } else { "" }
      (
        "No electronic address can be derived from the VAT identifier "
          + _quoted(vat-id)
          + reason
          + ". Set `electronic-address` or `email` on the "
          + field
          + "."
      )
    }
    return (
      make(missing-rule, field, "The " + term + " is missing.", hint: hint),
    )
  }
  if address.scheme == none {
    return (
      error(
        scheme-rule,
        field + ".electronic-address",
        "The "
          + term
          + " "
          + _quoted(address.id)
          + " has no scheme identifier.",
        hint: "Give the address with its scheme, e.g. `electronic-address: (scheme: \"0088\", id: "
          + _quoted(address.id)
          + ")` for a GLN, or give an email address.",
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

// The input key a party identifier came from (see `id-keys` and
// `global-id-keys` of the model), for the field of a diagnostic.
#let _id-key(party, slot) = {
  party.at(slot + "-keys", default: ()).first(default: slot)
}

// `rule`: BR-CL-10 for the seller and buyer, BR-CL-26 for the ship-to party.
#let _check-global-id(party, rule, field) = {
  let global-id = party.at("global-id", default: none)
  if global-id == none or global-id.scheme == none { return () }
  if global-id.scheme not in codelists.icd {
    return (
      error(
        rule,
        field + "." + _id-key(party, "global-id"),
        "The scheme "
          + _quoted(global-id.scheme)
          + " of the global identifier is not an ISO/IEC 6523 code.",
        hint: "Use e.g. \"0088\" for a GLN or \"0060\" for a DUNS number.",
      ),
    )
  }
  ()
}

// Two different values for one identifier of a party, of which only one can
// be written: a `global-id` without scheme next to `id`, a `location-id` next
// to `id` of the delivery address, or two identifiers with scheme.
#let _check-identifiers(party, field, term) = {
  let out = ()
  let id-keys = party.at("id-keys", default: ())
  if id-keys.len() > 1 {
    let (first, second, ..) = id-keys
    out.push(error(
      "IP-ID-02",
      field + "." + second,
      if second == "global-id" {
        (
          "The global identifier of the "
            + term
            + " has no scheme, so it would be a second identifier next to `"
            + first
            + "`, and only one can be written."
        )
      } else {
        (
          "`"
            + first
            + "` and `"
            + second
            + "` give two different identifiers of the "
            + term
            + ", and only one can be written."
        )
      },
      hint: if second == "global-id" {
        "Give the ISO/IEC 6523 scheme of the global identifier, e.g. `global-id: (scheme: \"0088\", id: ..)` for a GLN."
      } else { "`location-id` is another name of `id`: keep one of them." },
    ))
  }
  let global-id-keys = party.at("global-id-keys", default: ())
  if global-id-keys.len() > 1 {
    out.push(error(
      "IP-ID-02",
      field + "." + global-id-keys.at(1),
      "`"
        + global-id-keys.at(0)
        + "` and `"
        + global-id-keys.at(1)
        + "` both give an identifier with scheme of the "
        + term
        + ", and only one can be written.",
      hint: "Keep one of them, or give `id` without scheme.",
    ))
  }
  out
}

// The buyer (BT-46) and the deliver-to location (BT-71) have one identifier:
// either `ram:ID` or `ram:GlobalID` (CII-SR-450, CII-SR-449).
#let _check-single-identifier(party, rule, field, term) = {
  if (
    party.at("id", default: none) == none
      or party.at("global-id", default: none) == none
  ) { return () }
  let id-key = _id-key(party, "id")
  let global-id-key = _id-key(party, "global-id")
  (
    error(
      rule,
      field,
      "The "
        + term
        + " can be stated only once, but `"
        + id-key
        + "` and `"
        + global-id-key
        + "` give one each.",
      hint: "Keep either `"
        + id-key
        + "` or `"
        + global-id-key
        + "` on the "
        + field
        + ".",
    ),
  )
}

#let _check-vat-id-prefix(vat-id, field) = {
  if vat-id == none { return () }
  let prefix = vat-id-prefix(vat-id)
  if (
    prefix != none
      and (prefix in codelists.countries or prefix in ("EL", "1A", "AN"))
  ) {
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
  let ship-to = model.ship-to
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

  // The seller country (BT-40) is written in every profile, the other
  // addresses from BASIC WL on.
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
    if ship-to != none {
      out += _check-country(
        ship-to.address.country,
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
      hint: if model.outside-scope {
        "An invoice not subject to VAT (O) states no VAT identifier (BR-O-02). Set `tax-nr` or `id` on the sender."
      } else { "Set `vat-id`, `tax-nr` or `id` on the sender." },
    ))
  }

  // Party identifiers (BT-29, BT-46) from BASIC WL on; the ship-to party
  // (BT-71) with the delivery information.
  if profile.party-ids {
    out += _check-identifiers(seller, "sender", "seller")
    out += _check-identifiers(buyer, "recipient", "buyer")
    out += _check-global-id(seller, "BR-CL-10", "sender")
    out += _check-global-id(buyer, "BR-CL-10", "recipient")
    if profile.en16931 {
      out += _check-single-identifier(
        buyer,
        "CII-SR-450",
        "recipient",
        "buyer identifier (BT-46)",
      )
    }
  }
  if profile.addresses and ship-to != none {
    out += _check-identifiers(ship-to, "delivery-address", "delivery address")
    out += _check-global-id(ship-to, "BR-CL-26", "delivery-address")
    if profile.en16931 {
      out += _check-single-identifier(
        ship-to,
        "CII-SR-449",
        "delivery-address",
        "deliver-to location identifier (BT-71)",
      )
    }
  }

  if profile.addresses {
    // Required by XRechnung, recommended for EN 16931 (Peppol).
    let required = if profile.xrechnung { "error" } else if (
      profile.id == "en16931"
    ) { "warning" } else { none }
    out += _check-electronic-address(
      seller,
      required,
      ("PEPPOL-EN16931-R020", "BR-62"),
      "sender",
      "seller electronic address (BT-34)",
    )
    out += _check-electronic-address(
      buyer,
      required,
      ("PEPPOL-EN16931-R010", "BR-63"),
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
      (ship-to, "delivery-address", "BR-DE-10", "BR-DE-11", "deliver-to"),
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

  for tax in model.taxes {
    let field = _tax-field(tax)
    let category = tax.category
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

#let check-payment(model) = {
  if not model.profile.settlement { return () }
  let out = ()
  let payment = model.payment

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

// The XML must state what the invoice prints and add up in itself. A failure
// here is a bug in invoice-pro, not in the invoice data.
#let check-consistency(model) = {
  let out = ()
  let bug-hint = "This is a bug in invoice-pro. Please report it at https://github.com/leonieziechmann/invoice-pro/issues."
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
