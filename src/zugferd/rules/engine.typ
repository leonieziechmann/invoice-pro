// The checks of the e-invoice validation: the business rules of EN 16931,
// the Factur-X profiles and XRechnung, and the rules of invoice-pro itself
// (IP-*: the official rules accept the XML, but the invoice would be wrong),
// which the data model must satisfy before its XML is written. The metadata
// of every rule is in tools/zugferd/registry.json.
//
// A check that fails records a finding `(key: .., field: .., ..values)`: the
// key of the rule's entry, the input field to name, `id` where the entry
// reports several ids, `level` where it has two, and the values its message
// needs. Checks of inputs most invoices do not give are in rare.typ, those
// of XRechnung in xrechnung.typ; the messages in messages.typ and
// xrechnung-messages.typ. All of them load only when an invoice needs them.
//
// A diagnostic is `(level: "error" | "warning", rule: .., field: ..,
// message: .., hint: .. | none)`, errors first, each level in the order of
// the checks.

#import "../code-lists.typ": lists
#import "../xml.typ": fmt-number, rate-digits
#import "../model.typ": profile-terms, vat-id-country, vat-id-prefix
#import "../../utils/iban.typ": iban-valid

#let _zero = decimal("0")

/// A value in quotes for a message, e.g. `"DE"`, or "(none)".
///
/// -> str
#let quoted(value) = if value == none { "(none)" } else {
  "\"" + str(value) + "\""
}

/// Whether `code` is in `list`, a code list of `lists`.
///
/// -> bool
#let in-list(list, code) = (
  type(code) == str
    and code != ""
    and not code.contains(" ")
    and (" " + code + " ") in list
)

// One binding per list, so that a check captures only the lists it names.
#let _countries = lists.country.every
#let _currencies = lists.currency.every
#let _factur-x-currencies = lists.currency.factur-x
#let _eas-codes = lists.eas.every
#let _icd-codes = lists.icd.every
#let _units = lists.unit.every
#let _vat-categories = lists.vat-category.every
#let _means-codes = lists.payment-means.every

#let _percent(rate) = (
  fmt-number(rate * 100, min-digits: 0, max-digits: rate-digits) + "%"
)

/// The input field of an invoice line, e.g. `item 2 (Consulting)`.
///
/// -> str
#let line-field(line) = {
  "item " + line.id + if line.name != none { " (" + line.name + ")" }
}

/// The input field of a VAT group, e.g. `tax S 19%`.
///
/// -> str
#let tax-field(tax) = {
  (
    "tax "
      + if tax.category != none { tax.category + " " }
      + if tax.rate == none { "(no rate)" } else { _percent(tax.rate) }
  )
}

/// IP-PROFILE-01: an input the profile cannot state (`lowest` can).
///
/// -> dictionary
#let not-carried(profile, field, term, lowest, inputs: none) = (
  key: "IP-PROFILE-01",
  field: field,
  profile: profile.name,
  term: term,
  lowest: lowest,
  inputs: inputs,
)

// --- Document ---

// ASCII only (a wider class is slow to compile); "’" is removed separately.
#let _amount-characters = regex("[0-9 .,'+\\-()]")

#let _document(model) = {
  let out = ()
  if model.invoice.number == none {
    out.push((key: "BR-02", field: "invoice-nr"))
  }
  let date = model.invoice.issue-date
  if type(date) != datetime or date.year() == none {
    out.push((key: "BR-03", field: "date"))
  }
  let currency-field = model.at("currency-field", default: "locale")
  let currency = model.currency
  if currency == none {
    out.push((key: "BR-05", field: "locale"))
  } else if not in-list(_currencies, currency) {
    import "rare.typ": currency-code
    out += currency-code(currency, currency-field, model.profile)
  }

  // IP-TAX-01: `tax: none` states no VAT category (BT-151).
  let implicit = 0
  for line in model.lines {
    if line.at("implicit", default: false) { implicit += 1 }
  }
  let implicit-group = false
  for tax in model.taxes {
    if tax.at("implicit", default: false) { implicit-group = true }
  }
  if implicit > 0 or implicit-group {
    out.push((key: "IP-TAX-01", field: "tax", count: implicit))
  }

  // IP-PRINT-02: unit prices may use a subunit (e.g. "ct").
  let printed = model.at("printed-currency", default: none)
  if (
    type(currency) == str
      and in-list(_factur-x-currencies, currency)
      and type(printed) == dictionary
  ) {
    for (kind, sample) in (
      ("amounts", printed.at("amount", default: none)),
      ("unit prices", printed.at("price", default: none)),
    ) {
      if sample == none { continue }
      let sign = sample.replace(_amount-characters, "").replace("’", "")
      if sign == "" { continue }
      let euro = sample.contains("€") and currency != "EUR"
      let states = (
        sample.contains(currency)
          or printed.symbol != none and sample.contains(printed.symbol)
      )
      if not euro and (states or kind == "unit prices") { continue }
      out.push((
        key: "IP-PRINT-02",
        field: "locale",
        kind: kind,
        sign: sign,
        sample: sample,
        currency: currency,
      ))
      break
    }
  }
  out
}

// --- Document type ---

#let _document-type(model) = {
  let invoice = model.invoice
  let document = invoice.at("document", default: none)
  if type(document) != dictionary { return () }
  let out = ()
  let code = invoice.type-code

  // IP-DOC-01: a title such as "Gutschrift" names another kind of document.
  if document.input == auto and invoice.title != none {
    import "../document.typ": title-kind
    let named = title-kind(invoice.title)
    if named != none and named.kind != "invoice" {
      out.push((
        key: "IP-DOC-01",
        field: "subject",
        kind: named.kind,
        title: invoice.title,
        code: document.code,
      ))
    }
  }

  if model.profile.xrechnung {
    import "xrechnung.typ": document-type
    out += document-type(code)
  }

  // IP-DOC-05: BG-3 is written with its number (BT-25) only.
  if model.profile.document-references {
    let number = invoice.at("preceding-invoice-nr", default: none)
    if (
      number == none
        and invoice.at("preceding-invoice-date", default: none) != none
    ) {
      out.push((key: "IP-DOC-05", field: "preceding-invoice-nr"))
    } else if number == none and code == "384" {
      out.push((
        key: if model.profile.xrechnung { "BR-DE-26" } else { "IP-DOC-02" },
        field: "preceding-invoice-nr",
        code: code,
      ))
    }
  }

  // A negative credit note asks the buyer to pay (IP-DOC-03).
  let gross = model.totals.gross
  if gross < _zero {
    out.push((
      key: if document.credit { "IP-DOC-03" } else { "IP-DOC-04" },
      field: "line-items",
      code: code,
      gross: gross,
    ))
  }
  out
}

// --- Document data ---

#let _document-data(model) = {
  let out = ()
  let profile = model.profile

  let notes = model.invoice.at("notes", default: ())
  if notes.len() > 0 and not profile.notes {
    out.push(not-carried(profile, "notes", "invoice notes (BT-22)", "basic-wl"))
  }
  if (
    model.invoice.at("project", default: none) != none
      and not profile.procuring-project
  ) {
    out.push(not-carried(
      profile,
      "project",
      "the project reference (BT-11)",
      "en16931",
    ))
  }
  if (
    not profile.settlement
      and model.at("delivery", default: (:)).at("source", default: none)
        == "invoice"
  ) {
    out.push(not-carried(
      profile,
      "service-period",
      "the service period (BT-72, BG-14)",
      "basic-wl",
    ))
  }
  if not profile.document-references {
    let given = ()
    for key in ("preceding-invoice-nr", "preceding-invoice-date") {
      if model.invoice.at(key, default: none) != none { given.push(key) }
    }
    if given.len() > 0 {
      out.push(not-carried(
        profile,
        given.first(),
        "the preceding invoice reference (BG-3)",
        "basic-wl",
        inputs: if given.len() > 1 { given },
      ))
    }
  }
  if profile.notes {
    for note in notes {
      if note.subject-code != none {
        import "rare.typ": note-subject-code
        out += note-subject-code(note.subject-code, profile)
      }
    }
  }

  // IP-PERIOD-01: a text of its own is an error only for the invoice date.
  let delivery = model.at("delivery", default: (:))
  let printed = delivery.at("printed", default: none)
  let stated = delivery.at("text", default: none)
  let source = delivery.at("source", default: none)
  let term = if delivery.at("period", default: none) != none { "BG-14" } else {
    "BT-72"
  }
  let document = model.invoice.at("document", default: none)
  if profile.settlement and printed != none and printed != stated {
    let own = delivery.at("printed-own", default: true)
    let contradicts = not own or source == "invoice-date"
    out.push((
      key: "IP-PERIOD-01",
      level: if contradicts { "error" } else { "warning" },
      field: "references",
      printed: printed,
      stated: stated,
      source: source,
      term: term,
      contradicts: contradicts,
      document: document,
    ))
  }

  // BR-DE-TMP-32 (an XRechnung information): the date of the supply.
  if (
    profile.xrechnung
      and delivery.at("date", default: none) == none
      and delivery.at("period", default: none) == none
  ) {
    out.push((
      key: "BR-DE-TMP-32",
      field: "service-period",
      document: document,
    ))
  }

  if delivery.at("shown", default: none) == false {
    import "rare.typ": period-shown
    out += period-shown(model, stated, term, document)
  }
  out
}

// --- Parties ---

/// The country of a party: `rule` if missing, BR-CL-14 if not in the list.
///
/// -> array
#let country(code, rule, field, term, profile) = {
  if code == none { return ((key: rule, field: field, term: term),) }
  if in-list(_countries, code) { return () }
  import "rare.typ": country-code
  country-code(code, field, term, profile)
}

/// IP-COUNTRY-01: a party without `country` and a VAT ID of another country.
///
/// -> array
#let country-of-vat-id(party, field, term, bt) = {
  let address = party.address
  if (
    address.at("country-explicit", default: true) or address.country == none
  ) { return () }
  let vat-id = party.at("stated-vat-id", default: party.vat-id)
  let issuer = vat-id-country(vat-id)
  if issuer == none or issuer == address.country { return () }
  (
    (
      key: "IP-COUNTRY-01",
      field: field + ".country",
      party: field,
      term: term,
      bt: bt,
      country: address.country,
      vat-id: vat-id,
      issuer: issuer,
    ),
  )
}

// Patterns of rare checks, compiled once on first use.
#let _post-code-digits() = regex("[0-9]{3,}")

/// IP-ADDR-01: a post code the country's parser leaves in the city name.
///
/// -> array
#let post-code(party, field, term, city-bt, code-bt) = {
  let address = party.address
  if (
    address.post-code != none
      or address.city == none
      or address.country == none
      or address.city.match(_post-code-digits()) == none
  ) { return () }
  (
    (
      key: "IP-ADDR-01",
      field: field + ".city",
      party: field,
      term: term,
      city: address.city,
      country: address.country,
      city-bt: city-bt,
      code-bt: code-bt,
    ),
  )
}

#let _electronic-address(
  party,
  required,
  rules,
  field,
  term,
  profile,
  represented: false,
  reference: none,
) = {
  let (missing-rule, scheme-rule) = rules
  let address = party.electronic-address
  if address == none or address.id == none {
    if required == none { return () }
    return (
      (
        key: missing-rule,
        level: required,
        field: field,
        term: term,
        vat-id: party.at("stated-vat-id", default: none),
        represented: represented,
        reference: reference,
      ),
    )
  }
  if address.scheme == none {
    return (
      (
        key: scheme-rule,
        field: field + ".electronic-address",
        term: term,
        address: address.id,
      ),
    )
  }
  if in-list(_eas-codes, address.scheme) { return () }
  import "rare.typ": address-scheme
  address-scheme(address.scheme, field, term, profile)
}

/// The input key a party identifier came from.
///
/// -> str
#let id-key(party, slot) = {
  party.at(slot + "-keys", default: ()).first(default: slot)
}

/// The scheme of a party's global identifier (`rule`: BR-CL-10 or BR-CL-26).
///
/// -> array
#let global-id(party, rule, field, profile) = {
  let global-id = party.at("global-id", default: none)
  if (
    global-id == none
      or global-id.scheme == none
      or in-list(_icd-codes, global-id.scheme)
  ) { return () }
  import "rare.typ": global-id-scheme
  let field = field + "." + id-key(party, "global-id")
  global-id-scheme(global-id.scheme, rule, field, profile)
}

/// IP-ID-02: two values for a party identifier that takes one.
///
/// -> array
#let identifiers(party, field, term) = {
  let out = ()
  let id-keys = party.at("id-keys", default: ())
  if id-keys.len() > 1 {
    let (first, second, ..) = id-keys
    out.push((
      key: "IP-ID-02",
      field: field + "." + second,
      kind: "id",
      first: first,
      second: second,
      term: term,
    ))
  }
  let global-id-keys = party.at("global-id-keys", default: ())
  if global-id-keys.len() > 1 {
    out.push((
      key: "IP-ID-02",
      field: field + "." + global-id-keys.at(1),
      kind: "global-id",
      first: global-id-keys.at(0),
      second: global-id-keys.at(1),
      term: term,
    ))
  }
  out
}

/// CII-SR-449, CII-SR-450, CII-SR-451: `ram:ID` or `ram:GlobalID`, not both.
///
/// -> array
#let single-identifier(party, rule, field, term) = {
  if (
    party.at("id", default: none) == none
      or party.at("global-id", default: none) == none
  ) { return () }
  (
    (
      key: rule,
      field: field,
      term: term,
      id-key: id-key(party, "id"),
      global-id-key: id-key(party, "global-id"),
    ),
  )
}

/// BR-CO-09: a VAT identifier starts with a country prefix.
///
/// -> array
#let vat-id-prefix-check(vat-id, field) = {
  if vat-id == none { return () }
  let prefix = vat-id-prefix(vat-id)
  if (
    prefix != none
      and (
        in-list(_countries, prefix) or prefix in ("EL", "1A", "AN")
      )
  ) {
    return ()
  }
  ((key: "BR-CO-09", field: field, vat-id: vat-id),)
}

/// BR-CL-11: the scheme of a legal registration identifier.
///
/// -> array
#let legal-id(party, field, term, bt, profile) = {
  let legal-id = party.at("legal-id", default: none)
  if (
    legal-id == none
      or legal-id.scheme == none
      or in-list(_icd-codes, legal-id.scheme)
  ) { return () }
  import "rare.typ": legal-id-scheme
  legal-id-scheme(legal-id.scheme, field, term, bt, profile)
}

#let _parties(model) = {
  let profile = model.profile
  let seller = model.seller
  let buyer = model.buyer
  let ship-to = model.ship-to
  let out = ()

  if seller.name == none { out.push((key: "BR-06", field: "sender.name")) }
  if buyer.name == none { out.push((key: "BR-07", field: "recipient.name")) }

  for (party, field, term) in (
    (seller, "sender", "sender"),
    (buyer, "recipient", "recipient"),
    (ship-to, "delivery-address", "delivery address"),
  ) {
    if party != none and party.at("input-keys", default: ()) != () {
      import "rare.typ": input-keys
      out += input-keys(party, field, term)
    }
  }

  out += country(
    seller.address.country,
    "BR-09",
    "sender.country",
    "seller country code (BT-40)",
    profile,
  )
  out += country-of-vat-id(seller, "sender", "seller", "BT-40")
  if profile.addresses {
    out += country(
      buyer.address.country,
      "BR-11",
      "recipient.country",
      "buyer country code (BT-55)",
      profile,
    )
    out += country-of-vat-id(buyer, "recipient", "buyer", "BT-55")
    if ship-to != none {
      out += country(
        ship-to.address.country,
        "BR-57",
        "delivery-address.country",
        "deliver-to country code (BT-80)",
        profile,
      )
    }
    out += post-code(seller, "sender", "seller", "BT-37", "BT-38")
    out += post-code(buyer, "recipient", "buyer", "BT-52", "BT-53")
    // Without a delivery address of its own, the buyer's address is checked.
    if ship-to != none and not ship-to.at("from-buyer", default: false) {
      out += post-code(
        ship-to,
        "delivery-address",
        "deliver-to",
        "BT-77",
        "BT-78",
      )
    }
  }

  out += vat-id-prefix-check(seller.vat-id, "sender.vat-id")
  if profile.buyer-vat-id {
    out += vat-id-prefix-check(buyer.vat-id, "recipient.vat-id")
  }

  // BR-CO-26: a seller identifier; a tax representative's does not count.
  let seller-legal-id = seller.at("legal-id", default: none)
  let represented = model.at("tax-representative", default: none) != none
  if profile.id == "minimum" {
    // MINIMUM states neither `ram:ID` nor `ram:GlobalID` of the seller.
    if seller.vat-id == none and seller-legal-id == none {
      out.push((
        key: "BR-CO-26",
        field: "sender",
        minimum: true,
        represented: represented,
      ))
    }
  } else if (
    seller.id == none
      and seller.global-id == none
      and seller-legal-id == none
      and seller.vat-id == none
  ) {
    out.push((
      key: "BR-CO-26",
      field: "sender",
      minimum: false,
      represented: represented,
      outside-scope: model.outside-scope,
    ))
  }

  if seller.at("printed-tax-id", default: none) == false {
    out.push((
      key: "IP-PRINT-03",
      field: "references",
      vat-id: seller.vat-id,
      tax-nr: seller.tax-nr,
    ))
  }

  for (party, field, term) in (
    (seller, "sender", "seller"),
    (buyer, "recipient", "buyer"),
    (ship-to, "delivery-address", "deliver-to location"),
  ) {
    if party != none and party.at("typed-ids", default: ()) != () {
      import "rare.typ": typed-ids
      out += typed-ids(party, field, term)
    }
  }
  out += legal-id(seller, "sender", "seller", "BT-30", profile)
  out += legal-id(buyer, "recipient", "buyer", "BT-47", profile)
  for (party, key, field, term, carried, lowest) in (
    (
      seller,
      "trading-name",
      "sender.trading-name",
      "the seller trading name (BT-28)",
      profile.seller-trading-name,
      "basic-wl",
    ),
    (
      seller,
      "legal-info",
      "sender.legal-info",
      "the additional legal information of the seller (BT-33)",
      profile.seller-legal-info,
      "en16931",
    ),
    (
      buyer,
      "trading-name",
      "recipient.trading-name",
      "the buyer trading name (BT-45)",
      profile.buyer-trading-name,
      "en16931",
    ),
  ) {
    if not carried and party.at(key, default: none) != none {
      out.push(not-carried(profile, field, term, lowest))
    }
  }
  if (
    model.at("tax-representative", default: none) != none
      or model.at("payee", default: none) != none
  ) {
    import "rare.typ": payee, tax-representative
    out += tax-representative(model)
    out += payee(model)
  }

  if profile.party-ids {
    out += identifiers(seller, "sender", "seller")
    out += identifiers(buyer, "recipient", "buyer")
    out += global-id(seller, "BR-CL-10", "sender", profile)
    out += global-id(buyer, "BR-CL-10", "recipient", profile)
    if profile.en16931 {
      out += single-identifier(
        buyer,
        "CII-SR-450",
        "recipient",
        "buyer identifier (BT-46)",
      )
    }
  }
  if profile.addresses and ship-to != none {
    out += identifiers(ship-to, "delivery-address", "delivery address")
    out += global-id(ship-to, "BR-CL-26", "delivery-address", profile)
    if profile.en16931 {
      out += single-identifier(
        ship-to,
        "CII-SR-449",
        "delivery-address",
        "deliver-to location identifier (BT-71)",
      )
    }
  }

  if profile.addresses {
    // Required by XRechnung, a warning in EN 16931 (Peppol needs them).
    let (required, seller-rule, buyer-rule) = if profile.xrechnung {
      ("error", "PEPPOL-EN16931-R020", "PEPPOL-EN16931-R010")
    } else if profile.id == "en16931" {
      ("warning", "IP-EADDR-01", "IP-EADDR-01")
    } else { (none, none, none) }
    out += _electronic-address(
      seller,
      required,
      (seller-rule, "BR-62"),
      "sender",
      "seller electronic address (BT-34)",
      profile,
      represented: represented,
    )
    out += _electronic-address(
      buyer,
      required,
      (buyer-rule, "BR-63"),
      "recipient",
      "buyer electronic address (BT-49)",
      profile,
      reference: model.invoice.at("buyer-reference", default: none),
    )
  }

  if profile.xrechnung {
    import "xrechnung.typ": parties
    out += parties(model)
  }

  if profile.settlement {
    let intra-or-reverse = false
    for tax in model.taxes {
      if tax.category in ("K", "AE") {
        intra-or-reverse = true
        break
      }
    }
    if intra-or-reverse {
      import "rare.typ": buyer-vat-id, intra-community
      out += buyer-vat-id(model)
      out += intra-community(model)
    }
  }
  out
}

// --- Lines ---

#let _lines(model) = {
  if not model.profile.lines { return () }
  let out = ()
  if model.lines.len() == 0 {
    out.push((key: "BR-16", field: "line-items"))
  }
  // Unit codes checked so far: most lines share one.
  let units = (:)
  for line in model.lines {
    if line.name == none {
      out.push((key: "BR-25", field: line-field(line)))
    }
    let code = line.unit-code
    let known = if type(code) == str and code != "" {
      let seen = units.at(code, default: none)
      if seen == none {
        seen = in-list(_units, code)
        units.insert(code, seen)
      }
      seen
    } else { false }
    let unit-issue = line.at("unit-issue", default: none)
    if not known {
      out.push((key: "BR-CL-23", field: line-field(line), code: code))
    } else if unit-issue != none and unit-issue.kind == "unknown" {
      // IP-UNIT-02: an unknown unit text; "one" (C62) would be a guess.
      out.push((
        key: "IP-UNIT-02",
        field: line-field(line),
        text: unit-issue.text,
      ))
    } else if unit-issue != none and unit-issue.kind == "ambiguous" {
      out.push((key: "IP-UNIT-01", field: line-field(line), issue: unit-issue))
    }
    // BR-CO-04, a safety net: `tax: none` is zero rated (IP-TAX-01).
    if line.key == none or line.category == none {
      out.push((key: "BR-CO-04", field: line-field(line)))
    }
  }
  out
}

#let _line-data(model) = {
  if not model.profile.lines { return () }
  let given = ()
  for line in model.lines {
    if (
      line.at("period", default: none) != none
        or line.at("origin", default: none) != none
    ) { given.push(line) }
  }
  if given == () { return () }
  import "rare.typ": line-data
  line-data(model.profile, model.at("delivery", default: (:)), given)
}

// --- VAT ---

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

/// A rule of a VAT category's family, e.g. `category-rule("K", 2)`: BR-IC-02.
///
/// -> str
#let category-rule(category, number) = (
  _category-rules.at(category)
    + "-"
    + (if number < 10 { "0" } else { "" })
    + str(number)
)

// The categories that need a seller VAT ID or tax number (BR-x-02 to -04).
#let _taxed-categories = ("S", "Z", "E", "AE", "L", "M")

// Rules come in threes (lines, allowances, charges): the offset, or `none`.
#let _rule-offset(occurrence, lines) = {
  if lines and occurrence.line { 0 } else if occurrence.allowance {
    1
  } else if occurrence.charge { 2 } else { none }
}

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

#let _taxes(model) = {
  // MINIMUM carries no VAT details, only the totals.
  if not model.profile.settlement { return () }
  let out = ()
  let seller = model.seller
  let lines = model.profile.lines
  let categories = ()
  for tax in model.taxes {
    if tax.category != none and tax.category not in categories {
      categories.push(tax.category)
    }
  }
  let occurrences = _occurrences(model)
  let none-yet = (line: false, allowance: false, charge: false)
  let offset(name) = _rule-offset(
    if name == none { none-yet } else {
      occurrences.at(name, default: none-yet)
    },
    lines,
  )

  // BR-CO-18: with lines, BR-16 (no lines) says the same.
  if model.taxes.len() == 0 and not lines {
    out.push((key: "BR-CO-18", field: "line-items"))
  }

  let stated-groups = (:)
  for tax in model.taxes {
    let group = tax-field(tax)
    stated-groups.insert(group, stated-groups.at(group, default: 0) + 1)
  }

  for tax in model.taxes {
    let field = tax-field(tax)
    let category = tax.category

    if tax.rate == none {
      if category != "O" {
        out.push((key: "BR-48", field: field, category: category))
      }
    } else {
      // IP-DEC-01: the XML states a rate with up to `rate-digits` decimals.
      let percent = tax.rate * 100
      if calc.round(percent, digits: rate-digits) != percent {
        out.push((
          key: "IP-DEC-01",
          field: field,
          percent: percent,
          rate: tax.rate,
          shared: stated-groups.at(field) > 1,
          category: category,
        ))
      }
    }

    // BR-CL-18: the category; XRechnung also accepts B (split payment).
    if not in-list(_vat-categories, category) {
      import "rare.typ": category-code
      let found = category-code(category, field, model.profile)
      if found != () {
        out += found
        continue
      }
    }
    if tax.rate == none { continue }

    // The rate: BR-x-05 to -07 by where the group occurs (BR-x-09 in BASIC WL).
    let rate-rule = offset(tax.key)
    if rate-rule != none {
      rate-rule = if category in _category-rules {
        category-rule(category, 5 + rate-rule)
      }
    }
    if category in ("S", "L", "M") and tax.rate <= _zero and rate-rule != none {
      out.push((
        key: "vat-rate-positive",
        id: rate-rule,
        field: field,
        category: category,
      ))
    }
    if category in ("Z", "E", "AE", "K", "G") and tax.rate != _zero {
      if rate-rule == none and tax.amount != _zero {
        rate-rule = category-rule(category, 9)
      }
      if rate-rule != none {
        out.push((
          key: "vat-rate-zero",
          id: rate-rule,
          field: field,
          category: category,
        ))
      }
    }
    if category == "O" and tax.rate != _zero {
      out.push((key: "BR-O-09", field: field))
    }
    if (
      category == "E"
        and tax.reason == none
        and tax.at("code", default: none) == none
    ) {
      out.push((key: "BR-E-10", field: field))
    }
    if tax.at("codes", default: ()) != () {
      import "rare.typ": exemption-codes
      out += exemption-codes(tax, field, model.profile)
    }
  }

  // BR-x-02 to -04: a seller identifier, or the tax representative's (BT-63).
  let representative = model.at("tax-representative", default: none)
  let represented = (
    representative != none
      and model.profile.tax-representative
      and representative.vat-id != none
  )
  let taxed = ()
  for category in categories {
    if category in _taxed-categories and offset(category) != none {
      taxed.push(category)
    }
  }
  if (
    taxed.len() > 0
      and seller.vat-id == none
      and seller.tax-nr == none
      and not represented
  ) {
    let first = offset(taxed.first())
    out.push((
      key: "vat-seller-id",
      id: category-rule(taxed.first(), 2 + first),
      field: "sender",
      holder: first,
      categories: taxed,
    ))
  }
  for category in ("K", "G") {
    let at = offset(category)
    if (
      category in categories
        and at != none
        and seller.vat-id == none
        and not represented
    ) {
      out.push((
        key: "vat-seller-vat-id",
        id: category-rule(category, 2 + at),
        field: "sender.vat-id",
        category: category,
      ))
    }
  }
  // BR-IC-12, a safety net: the model states a deliver-to country for K.
  if "K" in categories and model.ship-to == none {
    out.push((key: "BR-IC-12", field: "delivery-address"))
  }
  let delivery = model.at("delivery", default: (:))
  if (
    "K" in categories
      and delivery.at("date", default: none) == none
      and delivery.at("period", default: none) == none
  ) {
    out.push((
      key: "BR-IC-11",
      field: "service-period",
      document: model.invoice.at("document", default: none),
    ))
  }
  if "O" in categories and categories.len() > 1 {
    let others = ()
    for category in categories {
      if category != "O" { others.push(category) }
    }
    out.push((key: "BR-O-11", field: "tax", others: others))
  }
  // The split payment of Italy (B): BASIC and EN 16931 check its rules too.
  if "B" in categories and model.profile.en16931 {
    import "rare.typ": split-payment
    out += split-payment(model, categories)
  }
  out
}

// --- Payment ---

#let _payment-means(model) = {
  let out = ()
  let profile = model.profile
  let xrechnung = profile.xrechnung
  let payment = model.payment
  let means = payment.means

  if means.len() == 0 {
    if xrechnung {
      let document = model.invoice.at("document", default: none)
      let paid = payment.at("paid", default: false)
      out.push((
        key: "BR-DE-1",
        field: if paid { "paid.method" } else { "bank-details" },
        paid: paid,
        sender-pays: (
          type(document) == dictionary
            and document.at("sender-pays", default: false)
        ),
      ))
    }
    return out
  }

  // One payment means code (BT-81); IP-PAY-03 where the validation allows more.
  let kinds = ()
  let conflicting = ()
  let debit-details = (
    payment.at("mandate", default: none) != none
      or payment.at("creditor-id", default: none) != none
  )
  for entry in means {
    if entry.kind not in kinds {
      kinds.push(entry.kind)
      conflicting.push(entry)
    }
    if entry.debtor-iban != none { debit-details = true }
  }
  if kinds.len() > 1 {
    let fields = ()
    for entry in conflicting { fields.push(entry.field) }
    out.push((
      key: if xrechnung and debit-details and "transfer" in kinds {
        "BR-DE-23-b"
      } else if xrechnung and debit-details and "card" in kinds {
        "BR-DE-24-b"
      } else if xrechnung or profile.id == "en16931" { "CII-SR-467" } else {
        "IP-PAY-03"
      },
      field: fields.join(", "),
      means: conflicting,
      paid: "paid" in fields,
    ))
  }

  for entry in means {
    if entry.kind == "transfer" {
      if entry.iban == none {
        // No account (BG-17). IP-PAY-04: BR-61 of BASIC WL and BASIC misses it.
        let paid = entry.field == "paid"
        out.push((
          key: if xrechnung { "BR-DE-23-a" } else if profile.id == "en16931" {
            "CII-SR-470"
          } else { "IP-PAY-04" },
          field: if paid { "paid.method" } else { "bank-details.iban" },
          type-code: entry.type-code,
          paid: paid,
        ))
      } else if not iban-valid(entry.iban) {
        out.push((
          key: if xrechnung and entry.type-code == "58" { "BR-DE-19" } else {
            "IP-PAY-01"
          },
          field: "bank-details.iban",
          iban: entry.iban,
          debtor: false,
        ))
      }
      if entry.account-name != none and not profile.account-name {
        out.push(not-carried(
          profile,
          "bank-details.name",
          "the account name (BT-85)",
          "en16931",
        ))
      }
    } else if entry.kind in ("direct-debit", "card") {
      import "rare.typ": payment-means-details
      out += payment-means-details(entry, payment, profile)
    }
    if not in-list(_means-codes, entry.type-code) {
      import "rare.typ": means-code
      out += means-code(entry.type-code, profile)
    }
  }

  let sepa-debit = false
  for entry in means {
    if entry.kind == "direct-debit" and entry.type-code == "59" {
      sepa-debit = true
    }
  }
  if sepa-debit and payment.at("creditor-id", default: none) != none {
    import "rare.typ": creditor-id
    out += creditor-id(payment.creditor-id)
  }
  out
}

#let _payment(model) = {
  if not model.profile.settlement {
    import "rare.typ": minimum-payment
    return minimum-payment(model)
  }
  let out = ()
  let payment = model.payment
  let terms = profile-terms(payment, model.profile)

  if model.profile.xrechnung {
    import "xrechnung.typ": payment-terms
    out += payment-terms(payment, terms)
  }

  if model.totals.due > _zero and payment.due-date == none and terms == none {
    out.push((key: "BR-CO-25", field: "payment-goal"))
  }

  out += _payment-means(model)

  // IP-PREPAID-01: prepayments above the total leave a negative amount due.
  if model.totals.prepaid > model.totals.gross and model.totals.gross >= _zero {
    out.push((key: "IP-PREPAID-01", field: "prepayment"))
  }
  out
}

// --- Consistency ---

#let _cents-exceeded(amount) = calc.round(amount, digits: 2) != amount

// The first amount with more than 2 decimals, in XML order, and the count.
#let _excess-decimals(model) = {
  let found = (count: 0)
  let note(found, term, place, value) = {
    if found.count == 0 {
      found += (term: term, place: place, value: value)
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
          "line net amount (BT-131)",
          line-field(line),
          line.net,
        )
      }
      for entry in line.allowances {
        if _cents-exceeded(entry.amount) {
          found = note(
            found,
            "line allowance (BT-136)",
            line-field(line),
            entry.amount,
          )
        }
      }
      for entry in line.charges {
        if _cents-exceeded(entry.amount) {
          found = note(
            found,
            "line charge (BT-141)",
            line-field(line),
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
        ("document level charge (BT-99)", entry.amount)
      } else {
        ("document level allowance (BT-92)", entry.amount)
      })
    }
    for tax in model.taxes {
      amounts.push(("VAT taxable amount (BT-116)", tax.basis))
      amounts.push(("VAT amount (BT-117)", tax.amount))
    }
    amounts += (
      ("sum of the line net amounts (BT-106)", totals.line),
      ("sum of the allowances (BT-107)", totals.allowance),
      ("sum of the charges (BT-108)", totals.charge),
      ("prepaid amount (BT-113)", totals.prepaid),
    )
  }
  amounts += (
    ("total without VAT (BT-109)", totals.net),
    ("total VAT amount (BT-110)", totals.tax),
    ("total with VAT (BT-112)", totals.gross),
    ("amount due (BT-115)", totals.due),
  )
  for (term, value) in amounts {
    if _cents-exceeded(value) {
      found = note(found, term, none, value)
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

// A failure here is a bug in invoice-pro, except IP-DEC-02.
#let _consistency(model) = {
  let out = ()

  // IP-DEC-02: the XML states amounts with 2 decimals (BR-DEC-*).
  let excess = _excess-decimals(model)
  if excess.count > 0 {
    let decimals = model.at("currency-decimals", default: 2)
    let by-currency = type(decimals) == int and decimals > 2
    out.push((
      key: "IP-DEC-02",
      field: if by-currency {
        model.at("currency-field", default: "locale")
      } else { "locale" },
      excess: excess,
      by-currency: by-currency,
      currency: model.at("currency", default: none),
      decimals: decimals,
    ))
    // The sums below would repeat it; without it, amounts compare exactly.
    return out
  }

  let totals = model.totals
  let printed = model.printed-totals
  for (term, stated, shown) in (
    ("total without VAT (BT-109)", totals.net, printed.net),
    ("total with VAT (BT-112)", totals.gross, printed.gross),
  ) {
    if stated != shown {
      out.push((
        key: "IP-PRINT-01",
        field: "line-items",
        term: term,
        stated: stated,
        printed: shown,
        rate: none,
      ))
    }
  }
  if model.profile.settlement {
    let basis = _zero
    for tax in model.taxes { basis += tax.basis }
    if basis != printed.net {
      out.push((
        key: "IP-PRINT-01",
        field: "line-items",
        term: "sum of the VAT taxable amounts (BT-116)",
        stated: basis,
        printed: printed.net,
        rate: none,
      ))
    }
    // BR-CO-17: VAT amount = basis times rate, within the validators' tolerance
    // of 1 (gross prices round differently); O and IP-DEC-01 rates are skipped.
    for tax in model.taxes {
      if tax.category == "O" or tax.rate == none { continue }
      let percent = calc.round(tax.rate * 100, digits: rate-digits)
      if percent != tax.rate * 100 { continue }
      let expected = calc.round(tax.basis * percent / 100, digits: 2)
      if calc.abs(tax.amount - expected) > 1 {
        out.push((
          key: "BR-CO-17",
          field: tax-field(tax),
          amount: tax.amount,
          basis: tax.basis,
          expected: expected,
        ))
      }
    }
  }
  if model.profile.lines and model.taxes != () {
    let sums = (:)
    for line in model.lines {
      if type(line.key) == str {
        sums.insert(line.key, sums.at(line.key, default: _zero) + line.net)
      }
    }
    for e in model.allowance-charges {
      if type(e.key) == str {
        let amount = if e.charge { e.amount } else { -e.amount }
        sums.insert(e.key, sums.at(e.key, default: _zero) + amount)
      }
    }
    // BR-x-08 of each VAT category that has one (not B).
    for tax in model.taxes {
      if type(tax.key) != str or type(tax.category) != str { continue }
      let rule = _basis-rules.at(tax.category, default: none)
      if rule == none { continue }
      let amount = sums.at(tax.key, default: _zero)
      if amount != tax.basis {
        out.push((
          key: "vat-basis",
          id: rule,
          field: tax-field(tax),
          amount: amount,
          basis: tax.basis,
        ))
      }
    }
  }
  out
}

/// The findings of the rules for an e-invoice data model.
///
/// -> array
#let findings(model) = (
  _document(model)
    + _document-type(model)
    + _document-data(model)
    + _parties(model)
    + _lines(model)
    + _line-data(model)
    + _taxes(model)
    + _payment(model)
    + _consistency(model)
)

// --- Diagnostics ---

// The rules whose usual level is "warning" (the first `level` in the registry).
#let _warnings = (
  "BR-DE-TMP-32",
  "IP-DOC-04",
  "IP-EADDR-01",
  "IP-KEY-01",
  "IP-PERIOD-02",
  "IP-PREPAID-01",
  "IP-PROFILE-01",
  "IP-TAX-03",
  "IP-UNIT-01",
  "IP-VAT-138",
  "PEPPOL-EN16931-R120",
)

/// A diagnostic, e.g. for a report hook or a test.
///
/// -> dictionary
#let diagnostic(level, rule, field, message, hint: none) = (
  level: level,
  rule: rule,
  field: field,
  message: message,
  hint: hint,
)

/// Turns the findings into diagnostics, errors first.
///
/// -> array
#let diagnostics(findings) = {
  let errors = ()
  let warnings = ()
  for f in findings {
    let build = none
    if f.key.starts-with("BR-DE-") {
      import "xrechnung-messages.typ": messages as xrechnung-messages
      build = xrechnung-messages.at(f.key, default: none)
    }
    if build == none {
      import "messages.typ": messages
      build = messages.at(f.key, default: none)
    }
    if build == none { panic("invoice-pro: no message for the rule " + f.key) }
    let level = f.at("level", default: if f.key in _warnings {
      "warning"
    } else {
      "error"
    })
    let (message, hint) = build(f)
    let d = diagnostic(
      level,
      f.at("id", default: f.key),
      f.field,
      message,
      hint: hint,
    )
    if level == "error" { errors.push(d) } else { warnings.push(d) }
  }
  errors + warnings
}

/// Checks an e-invoice data model and returns its diagnostics, errors first.
///
/// -> array
#let run-rules(model) = {
  let found = findings(model)
  if found == () { return () }
  diagnostics(found)
}
