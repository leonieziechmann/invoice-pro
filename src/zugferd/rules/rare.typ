// The checks of inputs most invoices do not give; engine.typ loads this
// module only when an invoice needs one of them.

#import "engine.typ": (
  country, country-of-vat-id, global-id, identifiers, in-list, legal-id,
  line-field, lists, not-carried, post-code, single-identifier,
  vat-id-prefix-check,
)
#import "../model.typ": vat-id-country, vat-id-prefix
#import "../../utils/iban.typ": iban-valid
#import "../../utils/creditor-id.typ": creditor-id-valid
#import "../../logic/service-period.typ": supply-dated

/// The rule a code of the list `name` breaks in the profile, or `none`: `cen`
/// where a CEN list lacks it, `fx` where only the Factur-X list does, and
/// IP-CODE-01 for a withdrawn code the validation still accepts.
///
/// -> none | str
#let _code-rule(name, code, profile, cen, fx) = {
  let entry = lists.at(name)
  if in-list(entry.every, code) { return none }
  let xrechnung = entry.at("xrechnung", default: entry.every)
  if profile.xrechnung {
    return if in-list(xrechnung, code) { none } else { cen }
  }
  let own = entry.at("factur-x", default: none)
  let withdrawn = entry.at("withdrawn", default: "")
  if not profile.en16931 {
    if own != none { return if in-list(own, code) { none } else { fx } }
    // `every` is the Factur-X list without the withdrawn codes.
    return if in-list(withdrawn, code) { "IP-CODE-01" } else { fx }
  }
  // Both CEN lists have it: only the Factur-X list lacks it.
  if in-list(xrechnung, code) { return fx }
  // Only CEN 1.3.16 lacks it, which KoSIT applies to EN 16931, not to BASIC;
  // a currency is allowed there with a warning.
  if in-list(withdrawn, code) {
    let factur-x = own == none or in-list(own, code)
    if factur-x and name == "currency" { return "IP-CODE-01" }
    if profile.id == "basic" { return if factur-x { "IP-CODE-01" } else { fx } }
  }
  cen
}

/// The finding of a code the profile's validation rejects (see `_code-rule`),
/// or `()`; `finding` holds the field and values of the message of `cen`.
///
/// -> array
#let code-finding(
  name,
  code,
  profile,
  cen,
  fx,
  finding,
  term,
  scheme: false,
) = {
  let rule = _code-rule(name, code, profile, cen, fx)
  if rule == none { return () }
  if rule == "IP-CODE-01" {
    return (
      (
        key: rule,
        level: if name == "currency" { "warning" } else { "error" },
        field: finding.field,
        code: code,
        term: term,
        scheme: scheme,
        list: name,
        profile: profile.name,
      ),
    )
  }
  let fx-only = (
    rule == fx and in-list(lists.at(name).at("xrechnung", default: ""), code)
  )
  (
    finding
      + (key: cen, id: rule, fx-only: fx-only, xrechnung: profile.xrechnung),
  )
}

/// BR-CL-04: the invoice currency (BT-5).
///
/// -> array
#let currency-code(code, field, profile) = code-finding(
  "currency",
  code,
  profile,
  "BR-CL-04",
  "FX-SCH-A-000040",
  (
    field: field,
    code: code,
    profile: if in-list(lists.currency.factur-x, code) { profile.name },
  ),
  "invoice currency code (BT-5)",
)

/// BR-CL-14: the country code of an address.
///
/// -> array
#let country-code(code, field, term, profile) = code-finding(
  "country",
  code,
  profile,
  "BR-CL-14",
  "FX-SCH-A-000036",
  (field: field, term: term, code: code),
  term,
)

/// BR-CL-25: the scheme of an electronic address.
///
/// -> array
#let address-scheme(scheme, field, term, profile) = code-finding(
  "eas",
  scheme,
  profile,
  "BR-CL-25",
  "FX-SCH-A-000031",
  (field: field + ".electronic-address", term: term, scheme: scheme),
  term,
  scheme: true,
)

/// BR-CL-10, BR-CL-26 (`rule`): the scheme of a global identifier.
///
/// -> array
#let global-id-scheme(scheme, rule, field, profile) = code-finding(
  "icd",
  scheme,
  profile,
  rule,
  "FX-SCH-A-000031",
  (field: field, scheme: scheme),
  "global identifier",
  scheme: true,
)

/// BR-CL-11: the scheme of a legal registration identifier.
///
/// -> array
#let legal-id-scheme(scheme, field, term, bt, profile) = code-finding(
  "icd",
  scheme,
  profile,
  "BR-CL-11",
  "FX-SCH-A-000031",
  (field: field + ".legal-id", term: term, bt: bt, scheme: scheme),
  term + " legal registration identifier (" + bt + ")",
  scheme: true,
)

/// BR-CL-18: a VAT category code.
///
/// -> array
#let category-code(category, field, profile) = code-finding(
  "vat-category",
  category,
  profile,
  "BR-CL-18",
  "FX-SCH-A-000179",
  (field: field, category: category),
  "VAT category code (BT-118)",
)

/// BR-CL-16: a payment means code.
///
/// -> array
#let means-code(code, profile) = code-finding(
  "payment-means",
  code,
  profile,
  "BR-CL-16",
  "FX-SCH-A-000023",
  (field: "paid.method", code: code),
  "payment means code (BT-81)",
)

/// IP-KEY-01, IP-KEY-02: unknown keys of a party dictionary.
///
/// -> array
#let input-keys(party, field, term) = {
  let out = ()
  for entry in party.at("input-keys", default: ()) {
    out.push((
      key: if entry.einvoice { "IP-KEY-02" } else { "IP-KEY-01" },
      field: field + "." + entry.path,
      entry: entry,
      term: term,
    ))
  }
  out
}

/// IP-ID-01, IP-ID-03: the identifiers of the `id` module a party gives.
///
/// -> array
#let typed-ids(party, field, term) = {
  let out = ()
  for entry in party.at("typed-ids", default: ()) {
    let path = field + "." + entry.key
    for problem in entry.problems {
      out.push((
        key: "IP-ID-01",
        field: path,
        problem: problem,
        kind: entry.kind,
        scheme: entry.scheme,
      ))
    }
    let misplaced = if (
      entry.kind == "routing"
        and entry.key in ("id", "global-id", "location-id", "legal-id")
    ) { "routing" } else if (
      entry.key == "leitweg-id" and entry.kind not in ("routing", "custom")
    ) { "leitweg-id" } else if (
      entry.key == "legal-id" and entry.kind == "party"
    ) {
      "party"
    } else if (
      entry.kind == "legal"
        and entry.scheme == none
        and entry.key in ("id", "global-id", "location-id")
    ) { "register" }
    if misplaced != none {
      out.push((
        key: "IP-ID-03",
        field: path,
        misplaced: misplaced,
        kind: entry.kind,
        input: entry.key,
        scheme: entry.scheme,
        term: term,
        party: field,
      ))
    }
  }
  out
}

// The rule of a VAT ID under O by where O occurs, or `none` (BASIC WL items).
#let _outside-scope-rule(model) = {
  let lines = model.profile.lines
  if lines {
    for line in model.lines {
      if line.category == "O" { return "BR-O-02" }
    }
  }
  let found = none
  for entry in model.allowance-charges {
    if entry.category != "O" { continue }
    if not entry.charge { return "BR-O-03" }
    found = "BR-O-04"
  }
  // A profile with lines states the items not subject to VAT on them.
  if found == none and lines { "BR-O-02" } else { found }
}

/// The seller tax representative (BG-11).
///
/// -> array
#let tax-representative(model) = {
  let representative = model.at("tax-representative", default: none)
  if representative == none { return () }
  let profile = model.profile
  let field = "sender.tax-representative"
  let out = input-keys(representative, field, "tax representative")
  if not profile.tax-representative {
    out.push(not-carried(
      profile,
      field,
      "the seller tax representative (BG-11)",
      "basic-wl",
    ))
    return out
  }
  if model.outside-scope and representative.vat-id != none {
    let rule = _outside-scope-rule(model)
    out.push(if rule == none { (key: "IP-TAX-05", field: field) } else {
      (key: "vat-outside-scope", id: rule, field: field)
    })
  }
  if representative.name == none {
    out.push((key: "BR-18", field: field + ".name"))
  }
  if representative.vat-id == none {
    out.push((
      key: "BR-56",
      field: field + ".vat-id",
      outside-scope: model.outside-scope,
    ))
  } else {
    out += vat-id-prefix-check(representative.vat-id, field + ".vat-id")
  }
  out += country(
    representative.address.country,
    "BR-20",
    field + ".country",
    "tax representative country code (BT-69)",
    profile,
  )
  out += country-of-vat-id(representative, field, "tax representative", "BT-69")
  if (
    representative.address.lines == () and representative.address.city == none
  ) {
    out.push((key: "IP-VAT-226", field: field + ".address", kind: "address"))
  }
  out += post-code(
    representative,
    field,
    "tax representative",
    "BT-66",
    "BT-67",
  )
  out
}

/// The payee (BG-10); IP-PAY-05: BASIC WL checks only its name.
///
/// -> array
#let payee(model) = {
  let payee = model.at("payee", default: none)
  if payee == none { return () }
  let profile = model.profile
  let field = "payee"
  let out = input-keys(payee, field, "payee")
  out += typed-ids(payee, field, "payee")
  if not profile.payee {
    out.push(not-carried(profile, field, "the payee (BG-10)", "basic-wl"))
    return out
  }
  let seller = model.seller
  let seller-legal-id = seller.at("legal-id", default: none)
  if payee.name == none {
    out.push((key: "BR-17", field: field + ".name", kind: "name"))
  } else if (
    payee.name == seller.name
      or (payee.id != none and payee.id == seller.id)
      or (
        payee.legal-id != none
          and seller-legal-id != none
          and payee.legal-id.id == seller-legal-id.id
      )
  ) {
    out.push((
      key: if profile.id == "basic-wl" { "IP-PAY-05" } else { "BR-17" },
      field: field,
      kind: "seller",
    ))
  }
  out += identifiers(payee, field, "payee")
  out += global-id(payee, "BR-CL-10", field, profile)
  out += legal-id(payee, field, "payee", "BT-61", profile)
  if profile.en16931 {
    out += single-identifier(
      payee,
      "CII-SR-451",
      field,
      "payee identifier (BT-60)",
    )
  }
  out
}

/// The period and the country of origin of lines (BG-26, BT-159).
///
/// -> array
#let line-data(profile, delivery, lines) = {
  let out = ()
  let invoicing-period = delivery.at("period", default: none)
  let date = delivery.at("date", default: none)
  let service-period = if invoicing-period != none {
    invoicing-period
  } else if (
    date != none
  ) { (date, date) }
  // PEPPOL-EN16931-R110 and R111 of XRechnung compare the lines with BG-14.
  let peppol = profile.xrechnung and invoicing-period != none

  let origins = 0
  for line in lines {
    let period = line.at("period", default: none)
    let origin = line.at("origin", default: none)
    if period != none and period.last() < period.first() {
      out.push((key: "BR-30", field: line-field(line), period: period))
    } else if period != none and service-period != none {
      let rules = ()
      if period.first() < service-period.first() {
        rules.push(if peppol { "PEPPOL-EN16931-R110" } else { "IP-PERIOD-02" })
      }
      if period.last() > service-period.last() {
        rules.push(if peppol { "PEPPOL-EN16931-R111" } else { "IP-PERIOD-02" })
      }
      for rule in rules.dedup() {
        out.push((
          key: rule,
          field: line-field(line),
          period: period,
          service-period: service-period,
        ))
      }
    }

    if origin == none { continue }
    origins += 1
    if profile.item-origin {
      out += code-finding(
        "country",
        origin,
        profile,
        "BR-CL-15",
        "FX-SCH-A-000026",
        (field: line-field(line), code: origin),
        "country of origin (BT-159)",
      )
    }
  }
  if origins > 0 and not profile.item-origin {
    out.push(not-carried(
      profile,
      "item.origin",
      "the country of origin of an item (BT-159)",
      "en16931",
    ))
  }
  out
}

#let _code-categories = (
  "VATEX-EU-AE": "AE",
  "VATEX-EU-IC": "K",
  "VATEX-EU-G": "G",
  "VATEX-EU-O": "O",
)

/// The exemption reason codes (BT-121) of a VAT group.
///
/// -> array
#let exemption-codes(tax, field, profile) = {
  let out = ()
  let category = tax.category
  let codes = tax.at("codes", default: ())
  for code in codes {
    let found = code-finding(
      "vatex",
      code,
      profile,
      "BR-CL-22",
      "FX-SCH-A-000181",
      (field: field, code: code),
      "VAT exemption reason code (BT-121)",
    )
    if found != () {
      out += found
      continue
    }
    let fits = _code-categories.at(code, default: "E")
    if category in ("S", "Z", "L", "M") or fits != category {
      out.push((
        key: "IP-TAX-02",
        field: field,
        code: code,
        category: category,
        fits: fits,
      ))
    }
  }
  if codes.len() > 1 {
    out.push((
      key: "IP-TAX-03",
      field: field,
      category: category,
      codes: codes,
    ))
  }
  if (
    category == "E"
      and tax.reason == none
      and tax.at("code", default: none) != none
  ) {
    out.push((key: "IP-TAX-04", field: field, code: tax.code))
  }
  out
}

/// The details of a direct debit (BG-19) or a payment card (BG-18).
///
/// -> array
#let payment-means-details(entry, payment, profile) = {
  let out = ()
  let xrechnung = profile.xrechnung
  if entry.kind == "direct-debit" {
    if entry.field == "paid" {
      // `paid(method: "direct-debit")` without the direct debit.
      if xrechnung {
        let sepa = entry.type-code == "59"
        out.push((
          key: if sepa { "BR-DE-25-a" } else { "PEPPOL-EN16931-R061" },
          field: "paid.method",
          type-code: entry.type-code,
          paid: true,
        ))
      }
    } else if xrechnung {
      // Safety nets: `direct-debit` requires `mandate` and `creditor-id`.
      if payment.at("mandate", default: none) == none {
        out.push((
          key: "PEPPOL-EN16931-R061",
          field: "direct-debit.mandate",
          paid: false,
        ))
      }
      if payment.at("creditor-id", default: none) == none {
        out.push((key: "BR-DE-30", field: "direct-debit.creditor-id"))
      }
      if entry.debtor-iban == none {
        out.push((key: "BR-DE-31", field: "direct-debit.debtor-iban"))
      }
    }
    if entry.debtor-iban != none and not iban-valid(entry.debtor-iban) {
      out.push((
        key: if xrechnung and entry.type-code == "59" { "BR-DE-20" } else {
          "IP-PAY-01"
        },
        field: "direct-debit.debtor-iban",
        iban: entry.debtor-iban,
        debtor: true,
      ))
    }
  } else if entry.kind == "card" {
    if entry.card == none {
      if xrechnung {
        out.push((
          key: "BR-DE-24-a",
          field: "paid.method",
          type-code: entry.type-code,
        ))
      }
    } else if not profile.payment-card {
      out.push(not-carried(
        profile,
        "card-payment",
        "the payment card (BG-18)",
        "en16931",
      ))
    }
  }
  out
}

/// IP-PAY-02: the check digits of a SEPA creditor identifier (BT-90).
///
/// -> array
#let creditor-id(creditor-id) = {
  if creditor-id-valid(creditor-id) { return () }
  (
    (
      key: "IP-PAY-02",
      field: "direct-debit.creditor-id",
      creditor-id: creditor-id,
    ),
  )
}

/// BR-B-01, BR-B-02: the split payment of Italy (B).
///
/// -> array
#let split-payment(model, categories) = {
  let out = ()
  for (party, field, term) in (
    (model.seller, "sender", "seller country code (BT-40)"),
    (model.buyer, "recipient", "buyer country code (BT-55)"),
    (
      model.at("tax-representative", default: none),
      "sender.tax-representative",
      "tax representative country code (BT-69)",
    ),
    (model.ship-to, "delivery-address", "deliver-to country code (BT-80)"),
  ) {
    if party == none { continue }
    let country = party.address.country
    if country != none and country != "IT" {
      out.push((
        key: "BR-B-01",
        field: field + ".country",
        term: term,
        country: country,
      ))
      break
    }
  }
  if "S" in categories {
    out.push((key: "BR-B-02", field: "tax"))
  }
  out
}

/// BR-CL-08: the subject code of a note (BT-21) is in UNTDID 4451.
///
/// -> array
#let note-subject-code(code, profile) = {
  import "../document.typ": note-subject-code-valid
  if note-subject-code-valid(code) { return () }
  (
    (
      key: "BR-CL-08",
      id: if profile.en16931 { "BR-CL-08" } else { "FX-SCH-A-000162" },
      field: "notes",
      code: code,
    ),
  )
}

// The highest total of a small-amount invoice in euros (§ 33 UStDV).
#let _small-amount = decimal("250")

/// IP-PERIOD-03: the invoice prints the date of the supply: an error for a
/// German seller (except on a small-amount invoice), else a warning.
///
/// -> array
#let period-shown(model, stated, term, document) = {
  if not supply-dated(document) { return () }
  let out = ()
  let profile = model.profile
  let delivery = model.at("delivery", default: (:))
  let issue-date = model.invoice.at("issue-date", default: none)
  let differs = (
    delivery.at("period", default: none) != none
      or delivery.at("date", default: none) != issue-date
  )
  let german = model.seller.address.country == "DE"
  let totals = model.at("totals", default: (:))
  let small-amount = (
    german
      and model.at("currency", default: none) == "EUR"
      and totals.at("gross", default: none) != none
      and totals.gross <= _small-amount
      and model
        .at("taxes", default: ())
        .all(tax => tax.at("category", default: none) not in ("K", "AE"))
  )
  if german and not small-amount {
    out.push((
      key: "IP-PERIOD-03",
      level: "error",
      field: "references",
      stated: if profile.settlement { stated },
      term: term,
    ))
  } else if profile.settlement and stated != none and differs {
    out.push((
      key: "IP-PERIOD-03",
      level: "warning",
      field: "references",
      stated: stated,
      term: term,
      small-amount: small-amount,
    ))
  }
  out
}

#let _buyer-vat-id-rules = (
  K: (line: "BR-IC-02", allowance: "BR-IC-03", charge: "BR-IC-04"),
  AE: (line: "BR-AE-02", allowance: "BR-AE-03", charge: "BR-AE-04"),
)

/// The buyer VAT identifier (BT-48) of an intra-community supply or AE.
///
/// -> array
#let buyer-vat-id(model) = {
  let profile = model.profile
  let buyer = model.buyer
  if not profile.settlement or buyer.vat-id != none { return () }
  let categories = ()
  for tax in model.taxes {
    let category = tax.category
    if (
      category != none
        and category in _buyer-vat-id-rules
        and category not in categories
    ) {
      categories.push(category)
    }
  }

  let out = ()
  let cross-border = model.seller.address.country != buyer.address.country
  for category in categories {
    // AE may name the buyer's legal-id (BT-47), unless across borders.
    if category == "AE" and buyer.at("legal-id", default: none) != none {
      if cross-border {
        out.push((
          key: "IP-VAT-226",
          field: "recipient.vat-id",
          kind: "legal-id",
        ))
      }
      continue
    }
    let rules = _buyer-vat-id-rules.at(category)
    let on-line = false
    if profile.lines {
      for line in model.lines {
        if line.category == category {
          on-line = true
          break
        }
      }
    }
    let on-allowance = false
    let on-charge = false
    for entry in model.allowance-charges {
      if entry.category == category {
        if entry.charge { on-charge = true } else { on-allowance = true }
      }
    }
    if on-line or (profile.lines and not on-allowance and not on-charge) {
      out.push((
        key: "vat-buyer-id",
        id: rules.line,
        field: "recipient.vat-id",
        category: category,
        holder: "line",
      ))
    } else if on-allowance or on-charge {
      let holder = if on-allowance { "allowance" } else { "charge" }
      out.push((
        key: "vat-buyer-id",
        id: rules.at(holder),
        field: "recipient.vat-id",
        category: category,
        holder: holder,
      ))
    } else if category == "K" or cross-border {
      out.push((
        key: "IP-VAT-226",
        field: "recipient.vat-id",
        kind: "no-lines",
        category: category,
      ))
    }
  }
  out
}

// The VAT identifier prefixes of the EU member states and Northern Ireland.
#let _eu-vat-prefixes = (
  "AT BE BG CY CZ DE DK EE EL ES FI FR GR HR HU IE IT LT LU LV MT NL PL PT"
    + " RO SE SI SK XI"
).split(" ")

/// IP-VAT-138 (warnings): a supply of K goes to another member state.
///
/// -> array
#let intra-community(model) = {
  if not model.profile.settlement { return () }
  let intra-community = false
  for tax in model.taxes {
    if tax.category == "K" {
      intra-community = true
      break
    }
  }
  if not intra-community { return () }

  let out = ()
  let seller = model.seller
  let home = vat-id-country(seller.at("stated-vat-id", default: seller.vat-id))
  // A seller without VAT ID ships from its tax representative's state (BT-63).
  let representative = model.at("tax-representative", default: none)
  let whose = "seller"
  if home == none and representative != none {
    home = vat-id-country(representative.vat-id)
    whose = "representative"
  }
  if home == none {
    home = seller.address.country
    whose = "seller"
  }
  if (
    model.ship-to != none
      and home != none
      and model.ship-to.address.country == home
  ) {
    out.push((
      key: "IP-VAT-138",
      field: "delivery-address.country",
      kind: "deliver-to",
      home: home,
      whose: whose,
    ))
  }
  let buyer-vat-id = model.buyer.vat-id
  let prefix = vat-id-prefix(buyer-vat-id)
  if prefix != none and prefix not in _eu-vat-prefixes {
    out.push((
      key: "IP-VAT-138",
      field: "recipient.vat-id",
      kind: "buyer-vat-id",
      vat-id: buyer-vat-id,
    ))
  }
  out
}

/// The payment details MINIMUM cannot state.
///
/// -> array
#let minimum-payment(model) = {
  let out = ()
  let profile = model.profile
  let payment = model.payment
  for entry in payment.means {
    // BASIC WL states a payment card only by its payment means code.
    if entry.field == "direct-debit" {
      out.push(not-carried(
        profile,
        entry.field,
        "the direct debit (BG-19)",
        "basic-wl",
      ))
    } else if entry.field == "card-payment" {
      out.push(not-carried(
        profile,
        entry.field,
        "the payment card (BG-18)",
        "en16931",
      ))
    } else if entry.field == "paid" {
      // `paid(method: "cash")` and the other methods without details.
      out.push(not-carried(
        profile,
        "paid.method",
        "the payment means (BT-81)",
        "basic-wl",
      ))
    }
  }
  if payment.at("discounts", default: ()).len() > 0 {
    out.push(not-carried(
      profile,
      "payment-goal.discount",
      "a cash discount (BT-20)",
      "basic-wl",
    ))
  }
  out
}
