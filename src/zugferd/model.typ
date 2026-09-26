// Normalizes the computed invoice into the e-invoice data model: amounts are
// read, never computed again (except BT-106 to BT-108 and gross-price nets).

#import "../utils/text.typ": plain-ascii, plain-text
#import "code-lists.typ": lists
#import "profile.typ": resolve-profile
#import "../utils/coercion.typ": to-decimal, to-ratio
#import "../data/tax.typ": to-tax-key
#import "../logic/payment-reference.typ": resolve-payment-reference
#import "../logic/document-type.typ": resolve-document-type
#import "../logic/service-period.typ": format-service-period, service-period-of
#import "../logic/payment-means.typ": (
  card-code, direct-debit-code, method-code, resolve as resolve-payment-means,
  transfer-code,
)
#import "../logic/references.typ": (
  service-period-label, service-period-text-label,
)
#import "../logic/printed.typ": shows-identifier, shows-text
#import "../logic/currency.typ": currency-code
#import "../utils/helper.typ": first-given
#import "xml.typ": fmt-number

#let _zero = decimal("0")
#let _one = decimal("1")

#let _in-list(list, code) = (
  type(code) == str
    and code != ""
    and not code.contains(" ")
    and (" " + code + " ") in list
)

// The same fallbacks as the printed invoice.
#let first-of = first-given

// Strings `plain-text` returns as they are.
#let _plain-ascii = plain-ascii

// The plain text of a value, or `none` if it has no visible text.
#let text-or-none(value) = {
  if type(value) == str and _plain-ascii in value { return value }
  if (
    type(value) == content
      and value.func() == text
      and _plain-ascii in value.text
  ) { return value.text }
  let result = plain-text(value)
  if result == "" { none } else { result }
}

/// The payment terms (BT-20) of a text with its line breaks, or `none`; a
/// Skonto line (BR-DE-18) needs a final line break.
///
/// -> str | none
#let payment-terms(value) = {
  let terms = plain-text(value, keep-newlines: true)
  if terms == "" { none } else if terms.ends-with("#") { terms + "\n" } else {
    terms
  }
}


// Compiled on first use (memoized).
#let _invisible-patterns() = (
  invisible: regex("\\p{Cf}"),
  spaces: regex(" {2,}"),
)

#let _visible(text) = {
  if text.len() == text.codepoints().len() { return text }
  let patterns = _invisible-patterns()
  text.replace(patterns.invisible, "").replace(patterns.spaces, " ").trim()
}

// An identifier without whitespace or invisible characters.
#let compact(value) = {
  if type(value) == str and _plain-ascii in value {
    return value.replace(" ", "")
  }
  let result = _visible(plain-text(value).replace(" ", ""))
  if result == "" { none } else { result }
}

// An identifier that may contain spaces ("HRB 12345").
#let _identifier(value) = {
  if type(value) == str and _plain-ascii in value { return value }
  let result = _visible(plain-text(value))
  if result == "" { none } else { result }
}

// `none` for the placeholder of a missing value ("#invoice-nr").
#let _unset(value, key) = if (
  type(value) == str
    and (
      value == "#" + key
        or (value.starts-with("#") and value.ends-with("." + key))
    )
) { none } else { value }

#let _country-code(country) = {
  let code = if type(country) == dictionary {
    country.at("code", default: none)
  } else { country }
  let code = if type(code) in (str, content) { compact(code) } else { none }
  if code == none { none } else { upper(code) }
}

#let country-code(party) = _country-code(party.at("country", default: none))

// The EAS of VAT IDs by prefix: only those of `lists.eas.every`.
#let vat-eas-codes = (
  AT: "9914",
  BE: "9925",
  BG: "9926",
  CH: "9927",
  CY: "9928",
  CZ: "9929",
  DE: "9930",
  EE: "9931",
  EL: "9933",
  ES: "9920",
  FI: "0213",
  FR: "9957",
  GB: "9932",
  GR: "9933",
  HR: "9934",
  HU: "9910",
  IE: "9935",
  IT: "0211",
  LT: "9937",
  LU: "9938",
  LV: "9939",
  MT: "9943",
  NL: "9944",
  PL: "9945",
  PT: "9946",
  RO: "9947",
  SI: "9949",
  SK: "9950",
)

/// The first two characters of a VAT ID in upper case, or `none`.
///
/// -> none | str
#let vat-id-prefix(vat-id) = {
  if vat-id == none { return none }
  let chars = vat-id.codepoints()
  if chars.len() < 2 { none } else { upper(chars.at(0) + chars.at(1)) }
}

/// The country that issued a VAT ID ("EL" is GR, "XI" GB), or `none`.
///
/// -> none | str
#let vat-id-country(vat-id) = {
  let prefix = vat-id-prefix(vat-id)
  let code = if prefix == "EL" { "GR" } else if prefix == "XI" { "GB" } else {
    prefix
  }
  if _in-list(lists.country.every, code) { code } else { none }
}

#let contact-model(party) = {
  let contact = party.at("contact", default: none)
  let nested = if type(contact) == dictionary { contact } else if (
    contact != none
  ) { (name: contact) } else { (:) }
  let name = first-of(
    nested.at("name", default: none),
    party.at("contact-name", default: none),
  )
  let phone = first-of(
    nested.at("phone", default: none),
    party.at("phone", default: none),
  )
  let email = first-of(
    nested.at("email", default: none),
    party.at("email", default: none),
  )
  let result = (
    name: if name != none { text-or-none(name) },
    phone: if phone != none { text-or-none(phone) },
    email: if email != none { compact(email) },
  )
  if result.name == none and result.phone == none and result.email == none {
    none
  } else { result }
}

/// The electronic address (BT-34, BT-49): the explicit one with an id (BR-62,
/// BR-63), else of the VAT ID, else the email.
///
/// -> none | dictionary
#let get-electronic-address(party) = {
  let explicit = party.at("electronic-address", default: none)
  if type(explicit) == dictionary {
    let id = compact(explicit.at("id", default: none))
    if id != none {
      let scheme = compact(explicit.at("scheme", default: none))
      if scheme != none { scheme = upper(scheme) } else if id.contains("@") {
        scheme = "EM"
      }
      return (scheme: scheme, id: id)
    }
  } else if explicit != auto and explicit != none {
    let id = compact(explicit)
    if id != none {
      return (scheme: if id.contains("@") { "EM" }, id: id)
    }
  }

  // Only the scheme of the country that issued the VAT ID fits.
  let vat-id = compact(party.at("vat-id", default: none))
  let prefix = vat-id-prefix(vat-id)
  if prefix != none and vat-id.codepoints().len() > 2 {
    let scheme = vat-eas-codes.at(prefix, default: none)
    if scheme != none {
      return (scheme: scheme, id: upper(vat-id))
    }
  }

  let contact = contact-model(party)
  if contact != none and contact.email != none {
    return (scheme: "EM", id: contact.email)
  }
  none
}

// `(scheme: .., id: ..)`, without spaces if it has a scheme.
#let _scheme-id(value) = {
  if type(value) == dictionary {
    let scheme = compact(value.at("scheme", default: none))
    let id = value.at("id", default: none)
    id = if scheme == none { _identifier(id) } else { compact(id) }
    return if id == none { none } else { (scheme: scheme, id: id) }
  }
  let id = _identifier(value)
  if id == none { none } else { (scheme: none, id: id) }
}

// `ram:ID` (BT-29, BT-46, BT-71) without scheme, else `ram:GlobalID`.
#let _party-ids(party, keys) = {
  let ids = ()
  let id-keys = ()
  let global-ids = ()
  let global-id-keys = ()
  for key in keys {
    let value = party.at(key, default: none)
    if value == none { continue }
    value = _scheme-id(value)
    if value == none { continue }
    if value.scheme == none {
      if value.id not in ids {
        ids.push(value.id)
        id-keys.push(key)
      }
    } else if value not in global-ids {
      global-ids.push(value)
      global-id-keys.push(key)
    }
  }
  (
    id: ids.first(default: none),
    global-id: global-ids.first(default: none),
    id-keys: id-keys,
    global-id-keys: global-id-keys,
  )
}

// --- Party keys ---

// `true` for the keys the e-invoice reads, `false` for printed-only ones.
#let _address-keys = (
  name: true,
  address: true,
  street: true,
  city: true,
  country: true,
  region: true,
  extra: false,
)

/// The keys each party role knows (`seller` is `sender`, `buyer` `recipient`).
#let party-keys = (
  seller: _address-keys
    + (
      id: true,
      global-id: true,
      legal-id: true,
      trading-name: true,
      legal-info: true,
      vat-id: true,
      tax-nr: true,
      tax-representative: true,
      electronic-address: true,
      contact: true,
      contact-name: true,
      phone: true,
      email: true,
    ),
  buyer: _address-keys
    + (
      id: true,
      global-id: true,
      legal-id: true,
      trading-name: true,
      vat-id: true,
      electronic-address: true,
      contact: true,
      contact-name: true,
      phone: true,
      email: true,
      buyer-reference: true,
      leitweg-id: true,
      order-nr: true,
      po-nr: true,
      contract-nr: true,
      delivery-note-nr: true,
      delivery-address: true,
      tax-nr: false,
      customer-nr: false,
      customer-id: false,
      order-date: false,
      project: false,
      quote-nr: false,
    ),
  ship-to: _address-keys + (id: true, location-id: true, global-id: true),
  tax-representative: _address-keys + (vat-id: true),
  payee: (name: true, id: true, global-id: true, legal-id: true),
)

// The keys of `contact` (BG-6, BG-9).
#let _contact-keys = (
  seller: (name: true, phone: true, email: true),
  buyer: (name: true, phone: true, email: true),
)

#let _identifier-keys = (scheme: true, id: true, kind: true, problems: true)

#let _typed-id-keys = (
  seller: ("id", "global-id", "legal-id", "electronic-address"),
  buyer: (
    "id",
    "global-id",
    "legal-id",
    "electronic-address",
    "leitweg-id",
    "buyer-reference",
  ),
  ship-to: ("id", "location-id", "global-id"),
  payee: ("id", "global-id", "legal-id"),
)

// Keys `normalize-party` sets (replacing any input of the same name).
#let _derived-keys = (
  name-inline: true,
  address-inline: true,
  city-inline: true,
  address-lines: true,
  country-explicit: true,
  city-name: true,
  post-code: true,
  state: true,
)

// Loads keys.typ only for the first unknown key.
#let _unknown-key(key, known, path: none) = {
  import "keys.typ": unknown-key
  unknown-key(key, known, path: path)
}

#let _is-unset(value) = value in (none, auto, "", [], ())

// The unknown keys of a party, its `contact` and its identifiers.
#let _input-keys(party, role) = {
  let known = party-keys.at(role)
  // A post code or country key loses nothing next to a stated one.
  let has-post-code = (
    text-or-none(_unset(party.at("post-code", default: none), "post-code"))
      != none
  )
  let has-country = party.at(
    "country-explicit",
    default: not _is-unset(party.at("country", default: none)),
  )
  let result = ()
  for (key, value) in party.pairs() {
    if key in known or key in _derived-keys or _is-unset(value) { continue }
    let entry = _unknown-key(key, known)
    if (
      (entry.like == "city" and has-post-code)
        or (entry.like == "country" and has-country == true)
    ) {
      entry.einvoice = false
    }
    result.push(entry)
  }
  let contact = party.at("contact", default: none)
  let contact-keys = _contact-keys.at(role, default: none)
  if contact-keys != none and type(contact) == dictionary {
    for (key, value) in contact.pairs() {
      if key in contact-keys or _is-unset(value) { continue }
      result.push(_unknown-key(key, contact-keys, path: "contact"))
    }
  }
  // An identifier without `id` is left out, and with it its other keys.
  for key in (
    "id",
    "global-id",
    "location-id",
    "legal-id",
    "electronic-address",
    "leitweg-id",
    "buyer-reference",
  ) {
    let value = party.at(key, default: none)
    if key not in known or type(value) != dictionary { continue }
    let lost = _is-unset(value.at("id", default: none))
    for (inner, inner-value) in value.pairs() {
      if inner in _identifier-keys or _is-unset(inner-value) { continue }
      let entry = _unknown-key(inner, _identifier-keys, path: key)
      result.push(entry + (einvoice: entry.einvoice or lost))
    }
  }
  result
}

// --- Parties ---

#let _key-text(value, key) = if value == none { none } else {
  text-or-none(_unset(value, key))
}

// BG-5, BG-8, BG-12, BG-15; three lines at most (BT-35, BT-36, BT-162).
#let _address-model(party) = {
  let raw-lines = party.at("address-lines", default: ())
  let lines = ()
  for line in if type(raw-lines) == array { raw-lines } else { (raw-lines,) } {
    let text = if line != none { text-or-none(line) }
    if text != none { lines.push(text) }
  }
  if lines.len() > 3 {
    lines = lines.slice(0, 2) + (lines.slice(2).join(", "),)
  }
  (
    lines: lines,
    city: _key-text(party.at("city-name", default: none), "city-name"),
    post-code: _key-text(party.at("post-code", default: none), "post-code"),
    state: _key-text(party.at("state", default: none), "state"),
    country: _country-code(party.at("country", default: none)),
    // Else the country is the locale's, or the buyer's for a delivery address.
    country-explicit: party.at("country-explicit", default: true) != false,
  )
}

// Lines joined by ", " as `info` prints them.
#let _lines-text(value) = {
  if value == none { return none }
  if type(value) == array {
    let lines = ()
    for line in value {
      let text = if line != none { text-or-none(line) }
      if text != none { lines.push(text) }
    }
    value = lines.join(", ")
  }
  text-or-none(value)
}

// BT-27, BT-44, BT-70
#let _party-name(party) = _lines-text(first-of(
  _unset(party.at("name-inline", default: none), "name-inline"),
  _unset(party.at("name", default: none), "name"),
))

#let _is-typed-id(value) = (
  type(value) == dictionary and "kind" in value and "problems" in value
)

// For the validator (IP-ID-01, IP-ID-03).
#let _typed-ids(party, role) = {
  let found = ()
  if role == none { return found }
  for key in _typed-id-keys.at(role, default: ()) {
    let value = party.at(key, default: none)
    if not _is-typed-id(value) { continue }
    found.push((
      key: key,
      scheme: value.at("scheme", default: none),
      id: value.at("id", default: none),
      kind: value.kind,
      problems: if type(value.problems) == array { value.problems } else {
        ()
      },
    ))
  }
  found
}

#let _id-text(value) = {
  if type(value) == dictionary { value.at("id", default: none) } else { value }
}

// BG-9: an email alone is where the invoice goes (BT-49), not a contact.
#let _states-contact(party) = (
  not _is-unset(party.at("contact", default: none))
    or not _is-unset(party.at("contact-name", default: none))
    or not _is-unset(party.at("phone", default: none))
)

/// A seller, buyer or ship-to party (`role`); `use-vat-id: false` keeps the
/// VAT ID out of the XML (BR-O-02), not out of the electronic address.
///
/// -> dictionary
#let party-model(party, role: none, use-vat-id: true) = {
  if type(party) != dictionary { party = (:) }
  let vat-id = party.at("vat-id", default: none)
  if vat-id != none { vat-id = compact(vat-id) }
  if vat-id != none { vat-id = upper(vat-id) }
  let id-keys = if role == "ship-to" {
    ("id", "location-id", "global-id")
  } else {
    ("id", "global-id")
  }
  let trading-name = party.at("trading-name", default: none)
  let legal-id = party.at("legal-id", default: none)
  let legal-info = party.at("legal-info", default: none)
  let tax-nr = party.at("tax-nr", default: none)
  (
    (
      name: _party-name(party),
      trading-name: if trading-name != none {
        _lines-text(_unset(trading-name, "trading-name"))
      },
      legal-id: if legal-id != none { _scheme-id(legal-id) },
      legal-info: if legal-info != none {
        _lines-text(_unset(legal-info, "legal-info"))
      },
      vat-id: if use-vat-id { vat-id } else { none },
      stated-vat-id: vat-id,
      tax-nr: if tax-nr != none { _identifier(tax-nr) },
      address: _address-model(party),
      electronic-address: get-electronic-address(party),
      contact: if role != "buyer" or _states-contact(party) {
        contact-model(party)
      },
      typed-ids: _typed-ids(party, role),
      input-keys: if role == none { () } else { _input-keys(party, role) },
    )
      + _party-ids(party, id-keys)
  )
}

// BG-4; without BT-29, BT-30 and BT-31, the tax number is its ID (BR-CO-26).
#let seller-model(party, use-vat-id: true) = {
  let seller = party-model(party, role: "seller", use-vat-id: use-vat-id)
  if (
    seller.id == none
      and seller.global-id == none
      and seller.legal-id == none
      and seller.vat-id == none
  ) {
    seller.id = seller.tax-nr
  }
  seller
}

/// The seller tax representative (BG-11), or `none`.
///
/// -> none | dictionary
#let tax-representative-model(party) = {
  if type(party) != dictionary { return none }
  let vat-id = compact(party.at("vat-id", default: none))
  (
    name: _party-name(party),
    vat-id: if vat-id != none { upper(vat-id) },
    address: _address-model(party),
    input-keys: _input-keys(party, "tax-representative"),
  )
}

/// The payee (BG-10), or `none`.
///
/// -> none | dictionary
#let payee-model(payee) = {
  if type(payee) != dictionary { return none }
  (
    (
      name: _party-name(payee),
      legal-id: _scheme-id(payee.at("legal-id", default: none)),
      typed-ids: _typed-ids(payee, "payee"),
      input-keys: _input-keys(payee, "payee"),
    )
      + _party-ids(payee, ("id", "global-id"))
  )
}

// The buyer's address as ship-to party (BR-IC-12).
#let _ship-to-buyer(address) = (
  name: none,
  id: none,
  global-id: none,
  id-keys: (),
  global-id-keys: (),
  address: address,
  input-keys: (),
  from-buyer: true,
)

/// The code of a unit (BT-130, BT-150) as `(code: .., issue: ..)`.
///
/// -> dictionary
#let resolve-unit(unit) = {
  if type(unit) == dictionary {
    let code = compact(unit.at("code", default: none))
    if code != none { return (code: code, issue: none) }
    unit = unit.at("display", default: none)
  }
  let text = plain-text(unit)
  if text == "" { return (code: "C62", issue: none) }
  import "units.typ": resolve-text-unit
  resolve-text-unit(text)
}

/// The code of a unit, see `resolve-unit`.
///
/// -> str
#let map-unit-code(unit) = resolve-unit(unit).code

/// The delivery date (BT-72) or invoicing period (BG-14) of a service period.
///
/// -> dictionary
#let _delivery(period) = {
  if period == none {
    (date: none, period: none)
  } else if period.start == period.end {
    (date: period.start, period: none)
  } else {
    (date: none, period: (period.start, period.end))
  }
}

#let _service-period(ctx, items) = service-period-of(ctx, items)

#let determine-delivery-dates(ctx, items) = _delivery(_service-period(
  ctx,
  items,
))

// The service period printed as a reference; `own` if not dates.
#let _printed-service-period(ctx) = {
  let strings = ctx.at("locale", default: (:)).at("strings", default: (:))
  let labels = strings.at("reference", default: (:))
  let label = text-or-none(labels.at("service-time", default: none))
  let references = ctx.at("references", default: ())
  if type(references) != array { return none }
  for reference in references {
    if type(reference) != array or reference.len() != 2 { continue }
    let (title, value) = reference
    let mark = if type(value) == content { value.at("label", default: none) }
    if (
      mark in (service-period-label, service-period-text-label)
        or (
          label != none
            and type(title) in (str, content)
            and text-or-none(title) == label
        )
    ) {
      if type(value) not in (str, content) { return none }
      let text = text-or-none(value)
      if text == none { return none }
      return (text: text, own: mark != service-period-label)
    }
  }
  none
}

// Whether the invoice shows the date of the supply (IP-PERIOD-03), or `none`.
#let _period-shown(ctx, printed, printed-period, period-text, dates-printed) = {
  if type(printed) != dictionary or not printed.at("known", default: false) {
    return none
  }
  if printed-period != none or dates-printed { return true }
  let strings = ctx.at("locale", default: (:)).at("strings", default: (:))
  let invoice-date = strings
    .at("reference", default: (:))
    .at("invoice-date", default: none)
  let except = if invoice-date == none { () } else {
    (plain-text(invoice-date),)
  }
  shows-text(printed, period-text, except: except) == true
}

// BT-22, BT-21 (see `normalize-notes`).
#let _notes(notes) = {
  let result = ()
  for note in notes {
    if type(note) != dictionary { continue }
    let content = plain-text(
      note.at("text", default: none),
      keep-newlines: true,
    )
    if content == "" { continue }
    let code = compact(note.at("subject-code", default: none))
    result.push((
      content: content,
      subject-code: if code != none { upper(code) },
    ))
  }
  result
}

// No exemption reason (BR-S-10, BR-Z-10, BR-AF-10, BR-AG-10).
#let _taxed-categories = ("S", "Z", "L", "M")

// BT-121 of a category (BR-AE-10, BR-IC-10, BR-G-10, BR-O-10).
#let _category-codes = (
  AE: "VATEX-EU-AE",
  K: "VATEX-EU-IC",
  G: "VATEX-EU-G",
  O: "VATEX-EU-O",
)

/// The distinct exemption reason codes (BT-121) of the items of a VAT group.
///
/// -> array
#let exemption-codes(codes) = {
  let result = ()
  for code in codes {
    let text = compact(code)
    if text == none { continue }
    text = upper(text)
    if text not in result { result.push(text) }
  }
  result
}

/// The exemption reason code (BT-121) of a VAT category: the one its items
/// give, else the category's; `none` if taxed or the items differ.
///
/// -> none | str
#let exemption-code(category, codes) = {
  if category in _taxed-categories or codes.len() > 1 { return none }
  if codes.len() == 1 { codes.first() } else {
    _category-codes.at(category, default: none)
  }
}

/// The exemption reason (BT-120): the printed grounds, unless taxed.
///
/// -> str | none
#let exemption-reason(category, grounds) = {
  if category in _taxed-categories { return none }
  text-or-none(grounds)
}

// The key of a VAT group, as `group-by-tax` makes it.
#let _tax-key(tax) = {
  if type(tax) != dictionary or "rate" not in tax or "category" not in tax {
    return none
  }
  let rate = tax.rate
  if type(rate) == decimal and type(tax.category) == str {
    return str(rate) + "-" + tax.category
  }
  to-tax-key((rate: to-ratio(rate), category: tax.category))
}

// BG-26 as `(start, end)`, or `none`.
#let _line-period(date) = {
  if type(date) == datetime { return (date, date) }
  if (
    type(date) == array
      and date.len() == 2
      and type(date.first()) == datetime
      and type(date.last()) == datetime
  ) {
    return (date.first(), date.last())
  }
  none
}

// Computed numbers are decimals already.
#let _decimal(value) = if type(value) == decimal { value } else {
  to-decimal(value)
}

/// The invoice lines (BG-25) of the computed items (`nets`: net amounts of
/// gross prices). BR-27: a negative price negates the quantity instead.
///
/// -> array
#let line-models(items, nets: none) = {
  let lines = ()
  let index = 0
  for item in items {
    let tax = item.at("tax", default: (:))
    if type(tax) != dictionary { tax = (:) }
    let rate = tax.at("rate", default: _zero)
    if type(rate) != decimal { rate = to-ratio(rate) }
    let category = tax.at("category", default: none)
    if type(category) != str or _plain-ascii not in category {
      category = text-or-none(category)
    }

    let quantity = _decimal(item.at("quantity", default: _one))
    let base-quantity = _decimal(item.at("base-quantity", default: _one))
    let price = _decimal(item.at("price", default: _zero))
    let net = _decimal(item.at("total", default: _zero))
    // Discounts are negative, surcharges positive.
    let modifiers = (
      item.at("discounts", default: ()) + item.at("surcharge", default: ())
    )
    let adjustments = none
    if nets != none {
      let line = nets.at(index)
      net = line.net
      price = if price < _zero { -line.price } else { line.price }
      adjustments = line.adjustments
    }
    if price < _zero {
      price = -price
      quantity = -quantity
    }

    let allowances = ()
    let charges = ()
    let i = 0
    for modifier in modifiers {
      let amount = _decimal(modifier.at("absolute", default: _zero))
      let stated = if adjustments == none { calc.abs(amount) } else {
        adjustments.at(i)
      }
      i += 1
      if stated == _zero { continue }
      // BR-42, BR-44
      let reason = text-or-none(modifier.at("name", default: none))
      if amount < _zero {
        allowances.push((amount: stated, reason: first-of(reason, "Discount")))
      } else {
        charges.push((amount: stated, reason: first-of(reason, "Surcharge")))
      }
    }

    let item-id = item.at("item-id", default: none)
    if type(item-id) == str { item-id = (seller: item-id) }
    if type(item-id) != dictionary { item-id = (:) }
    let unit = resolve-unit(item.at("unit", default: none))

    let pos = item.at("pos", default: none)
    let id = if type(pos) == str and _plain-ascii in pos { pos } else if (
      pos != none
    ) { text-or-none(pos) }
    let description = item.at("description", default: none)
    let standard-id = item-id.at("standard", default: none)
    let seller-id = item-id.at("seller", default: none)
    let buyer-id = item-id.at("buyer", default: none)
    let note = item.at("note", default: none)
    if note != none { note = plain-text(note, keep-newlines: true) }
    let date = item.at("date", default: none)

    lines.push((
      index: index,
      id: if id != none { id } else { str(index + 1) },
      name: text-or-none(item.at("name", default: none)),
      description: if description != none { text-or-none(description) },
      standard-id: if standard-id != none { compact(standard-id) },
      seller-id: if seller-id != none { text-or-none(seller-id) },
      buyer-id: if buyer-id != none { text-or-none(buyer-id) },
      quantity: quantity,
      base-quantity: base-quantity,
      unit-code: unit.code,
      unit-issue: unit.issue,
      price: price,
      net: net,
      key: _tax-key(tax),
      category: category,
      rate: rate,
      // `tax: none`, see `tax.implicit-zero`.
      implicit: tax.at("implicit", default: false),
      allowances: allowances,
      charges: charges,
      // BT-127
      note: if note == "" { none } else { note },
      // BG-26
      period: if date != none { _line-period(date) },
      // BT-159
      origin: item.at("origin", default: none),
    ))
    index += 1
  }
  lines
}

/// The invoice line (BG-25) of one computed item, see `line-models`.
///
/// -> dictionary
#let line-model(item, index) = {
  let line = line-models((item,)).first()
  line.index = index
  if item.at("pos", default: none) == none { line.id = str(index + 1) }
  line
}

/// The document level allowances (BG-20) and charges (BG-21), once per VAT
/// group (BR-53), without parts of 0; a reason is required (BR-33, BR-38).
///
/// -> array
#let document-allowance-charges(discounts, surcharges, nets: none) = {
  let entries = ()
  let m = 0
  for modifier in discounts + surcharges {
    let reason = text-or-none(modifier.at("name", default: none))
    let parts = if nets != none { nets.at(m) }
    m += 1
    for (key, part) in modifier.at("split", default: (:)).pairs() {
      let amount = _decimal(part.at("absolute", default: _zero))
      let net = if parts == none { calc.abs(amount) } else {
        calc.abs(parts.at(key))
      }
      if net == _zero { continue }
      let tax = part.at("tax", default: (:))
      let rate = tax.at("rate", default: _zero)
      let charge = amount > _zero
      entries.push((
        charge: charge,
        amount: net,
        reason: if reason != none { reason } else if charge {
          "Surcharge"
        } else {
          "Discount"
        },
        key: key,
        category: text-or-none(tax.at("category", default: none)),
        rate: if type(rate) == decimal { rate } else { to-ratio(rate) },
      ))
    }
  }
  entries
}

// --- Payment ---

#let _upper-id(value) = {
  let id = compact(value)
  if id == none { none } else { upper(id) }
}

// BG-16 with its code (BT-81).
#let _means(type-code, kind, field) = (
  type-code: type-code,
  kind: kind,
  field: field,
  iban: none,
  account-name: none,
  bic: none,
  card: none,
  debtor-iban: none,
)

/// The payment means (BG-16), and the method of `paid` if none details it.
///
/// -> array
#let payment-means-model(means, currency) = {
  let entries = ()
  for bank in means.transfers {
    let iban = _upper-id(bank.at("iban", default: none))
    entries.push(
      _means(transfer-code(currency), "transfer", "bank-details")
        + (
          iban: iban,
          // BT-85: only an explicit name.
          account-name: text-or-none(bank.at("account-name", default: none)),
          // BT-86, stated with the account.
          bic: if iban != none { _upper-id(bank.at("bic", default: none)) },
        ),
    )
  }
  let debit = means.direct-debit
  if debit != none {
    entries.push(
      _means(direct-debit-code(currency), "direct-debit", "direct-debit")
        + (debtor-iban: _upper-id(debit.at("debtor-iban", default: none))),
    )
  }
  let card = means.card
  if card != none {
    entries.push(
      _means(card-code(card.at("kind", default: auto)), "card", "card-payment")
        + (
          card: (
            id: card.last4,
            holder: text-or-none(card.at("holder", default: none)),
          ),
        ),
    )
  }
  let paid = means.paid
  let kind = if paid != none { paid.at("kind", default: none) }
  if kind != none {
    let detailed = (
      (kind == "transfer" and means.transfers.len() > 0)
        or (kind == "direct-debit" and debit != none)
        or (kind == "card" and card != none)
    )
    if not detailed {
      entries.push(_means(method-code(paid.method, currency), kind, "paid"))
    }
  }
  entries
}

/// A cash discount in the Skonto syntax of XRechnung (BR-DE-18).
///
/// -> str
#let skonto-line(discount) = (
  "#SKONTO#TAGE="
    + str(discount.days)
    + "#PROZENT="
    + fmt-number(discount.percent)
    + if discount.basis != none {
      "#BASISBETRAG=" + fmt-number(discount.basis)
    } else { "" }
    + "#"
)

#let _terms-lines(first, lines) = {
  let parts = if first == none { () } else { (first,) }
  payment-terms((parts + lines).join("\n"))
}

/// The payment terms (BT-20) of a profile: in XRechnung with Skonto lines.
///
/// -> none | str
#let profile-terms(payment, profile) = {
  let xrechnung = payment.at("terms-xrechnung", default: none)
  if profile.xrechnung and xrechnung != none { xrechnung } else {
    payment.terms
  }
}

/// The e-invoice data model of the root context and the computed items.
///
/// -> dictionary
#let build-model(
  ctx,
  item-data,
  payment-goal: none,
  bank: none,
  payment-means: none,
  nets: auto,
) = {
  let sender = ctx.at("sender", default: (:))
  let recipient = ctx.at("recipient", default: (:))
  // BT-3
  let document = ctx.at("document-type", default: none)
  if type(document) != dictionary { document = resolve-document-type(auto) }
  // Self-billed: the buyer sends; from here on `sender` is the seller.
  if document.self-billed {
    (sender, recipient) = (recipient, sender)
    // The delivery address `invoice` adds is the buyer's (BG-13).
    if type(sender) == dictionary {
      let _ = sender.remove("delivery-address", default: none)
    }
  }
  let profile = resolve-profile(
    ctx.at("zugferd", default: "en16931"),
    country-code(recipient),
  )

  let items = item-data.at("items", default: ())
  let taxes = item-data.at("taxes", default: (:))
  let tax-mode = item-data.at(
    "tax-mode",
    default: ctx.at("tax-mode", default: "exclusive"),
  )
  let inclusive = tax-mode == "inclusive"
  let locale = ctx.at("locale", default: (:))
  let currency-meta = locale.at("currency", default: (:))
  // Loaded only for gross prices.
  if inclusive and nets == auto {
    import "../logic/net-amounts.typ": net-amounts
    let discounts = item-data.at("discounts", default: ())
    let surcharges = item-data.at("surcharges", default: ())
    nets = net-amounts(
      items,
      taxes,
      discounts + surcharges,
      digits: currency-meta.at("decimals", default: 2),
      fine: currency-meta.at("decimals-fine", default: 4),
    )
  }
  if not inclusive or nets == auto { nets = none }

  // BR-O-02: no VAT IDs outside the scope of VAT, except in MINIMUM (BR-CO-26).
  let categories = ()
  for tax in taxes.values() {
    categories.push(tax.at("category", default: none))
  }
  let outside-scope = profile.id != "minimum" and "O" in categories

  let seller = seller-model(sender, use-vat-id: not outside-scope)
  // Whether the invoice shows the seller's VAT ID or tax number (BT-31, BT-32).
  let printed = ctx.at("printed", default: none)
  seller.insert("printed-tax-id", shows-identifier(printed, (
    seller.vat-id,
    seller.tax-nr,
  )))
  let buyer = party-model(
    recipient,
    role: "buyer",
    use-vat-id: not outside-scope,
  )
  // BG-11, BG-10
  let tax-representative = tax-representative-model(sender.at(
    "tax-representative",
    default: none,
  ))
  let payee = payee-model(ctx.at("payee", default: none))

  // BG-13; `location-id` is another name of its `id` (BT-71).
  let delivery-party = ctx.at("delivery-address", default: none)
  let ship-to = if type(delivery-party) == dictionary {
    party-model(delivery-party, role: "ship-to", use-vat-id: false)
  } else if "K" in categories and buyer.address.country != none {
    // BR-IC-12: without a delivery address, the goods go to the buyer.
    _ship-to-buyer(buyer.address)
  } else { none }

  let lines = line-models(
    items,
    nets: if nets != none { nets.lines },
  )
  let allowance-charges = document-allowance-charges(
    item-data.at("discounts", default: ()),
    item-data.at("surcharges", default: ()),
    nets: if nets != none { nets.modifiers },
  )

  let breakdown = taxes
    .pairs()
    .map(((key, tax)) => {
      let category = text-or-none(tax.at("category", default: none))
      let codes = exemption-codes(tax.at("codes", default: ()))
      (
        key: key,
        category: category,
        rate: to-ratio(tax.at("rate", default: 0)),
        basis: to-decimal(tax.at("basis", default: 0)),
        amount: to-decimal(tax.at("absolute", default: 0)),
        reason: exemption-reason(category, tax.at("grounds", default: none)),
        // BT-121; `codes` for the validator.
        code: exemption-code(category, codes),
        codes: codes,
        // An item has `tax: none`.
        implicit: tax.at("implicit", default: false),
      )
    })

  let line-total = _zero
  for line in lines { line-total += line.net }
  let allowance-total = _zero
  let charge-total = _zero
  for entry in allowance-charges {
    if entry.charge { charge-total += entry.amount } else {
      allowance-total += entry.amount
    }
  }
  // The printed totals (BT-109, BT-112); BT-110 adds up the printed VAT.
  let net-total = _decimal(item-data.at("net-total", default: _zero))
  let gross-total = _decimal(item-data.at("gross-total", default: _zero))
  let tax-total = _zero
  for tax in breakdown { tax-total += tax.amount }
  let means = if payment-means != none { payment-means } else {
    resolve-payment-means(
      if bank != none { (bank,) } else { () },
      none,
      none,
      none,
    )
  }
  // A `paid` invoice has the total as paid amount (BT-113): nothing is due.
  let prepaid-total = if means.paid != none { gross-total } else {
    _decimal(item-data.at("prepaid-total", default: _zero))
  }

  let currency = currency-code(locale)
  // To check the printed currency (BT-5).
  let printed-currency = (
    symbol: text-or-none(currency-meta.at("symbol", default: none)),
  )
  for (name, key) in (("amount", "currency"), ("price", "currency-fine")) {
    let formatter = locale.at("format", default: (:)).at(key, default: none)
    printed-currency.insert(name, if type(formatter) == function {
      plain-text(formatter(decimal("1")))
    })
  }

  let service-period = service-period-of(ctx, items)
  let format-date = locale.at("format", default: (:)).at("date", default: none)
  let period-text = if type(format-date) == function {
    text-or-none(format-service-period(service-period, format-date))
  }
  let printed-period = _printed-service-period(ctx)

  // BT-9, BT-20: `due-date` wins over the payment goal.
  let due-date = none
  let terms = none
  let terms-input = none
  let explicit-due-date = ctx.at("due-date", default: none)
  if type(explicit-due-date) == datetime {
    due-date = explicit-due-date
  } else {
    terms = payment-terms(explicit-due-date)
    if terms != none { terms-input = "due-date" }
  }
  if payment-goal != none {
    let goal-date = payment-goal.at("date", default: none)
    let days = payment-goal.at("days", default: none)
    let invoice-date = ctx.at("invoice-date", default: none)
    if due-date == none and type(goal-date) == datetime {
      due-date = goal-date
    } else if (
      due-date == none and type(days) == int and type(invoice-date) == datetime
    ) {
      due-date = invoice-date + duration(days: days)
    }
    if terms == none and type(goal-date) != datetime {
      terms = payment-terms(goal-date)
      if terms != none { terms-input = "payment-goal" }
    }
    // Without days or a date, the terms are what the goal prints (due at once).
    if terms == none and due-date == none and goal-date == none {
      let strings = (
        locale.at("strings", default: (:)).at("payment", default: (:))
      )
      let soon = strings.at("deadline-soon", default: none)
      if document.sender-pays {
        soon = strings.at("deadline-soon-credit", default: soon)
      }
      terms = payment-terms(soon)
      if terms != none { terms-input = "payment-goal" }
    }
  }
  // Cash discounts, a line each; for XRechnung in Skonto syntax (BR-DE-18).
  let discounts = if payment-goal != none {
    payment-goal.at("discounts", default: ())
  } else { () }
  let terms-xrechnung = none
  if discounts.len() > 0 {
    let notes = ()
    let lines = ()
    for discount in discounts {
      notes.push(plain-text(discount.note))
      lines.push(skonto-line(discount))
    }
    terms-xrechnung = _terms-lines(terms, lines)
    terms = _terms-lines(terms, notes)
    if terms-input == none { terms-input = "payment-goal" }
  }
  // A paid invoice states what it prints about the payment.
  if means.paid != none and terms == none {
    let lines = ()
    for line in means.paid.at("terms", default: ()) {
      lines.push(plain-text(line))
    }
    terms = _terms-lines(none, lines)
    if terms != none { terms-input = "paid" }
  }
  let debit = means.direct-debit

  (
    profile: profile,
    tax-mode: tax-mode,
    outside-scope: outside-scope,
    currency: currency,
    currency-field: if ctx.at("currency", default: auto) == auto {
      "locale"
    } else { "currency" },
    currency-decimals: currency-meta.at("decimals", default: 2),
    printed-currency: printed-currency,
    invoice: (
      number: _key-text(ctx.at("invoice-nr", default: none), "invoice-nr"),
      type-code: document.code,
      // Its title must not name another kind of document (IP-DOC-01).
      document: document,
      title: text-or-none(ctx.at("title", default: none)),
      issue-date: ctx.at("invoice-date", default: none),
      // A Leitweg-ID of the `id` module without its scheme.
      buyer-reference: text-or-none(_id-text(first-of(
        ctx.at("buyer-reference", default: none),
        recipient.at("buyer-reference", default: none),
        recipient.at("leitweg-id", default: none),
      ))),
      order-nr: text-or-none(first-of(
        ctx.at("order-nr", default: none),
        recipient.at("order-nr", default: none),
        ctx.at("po-nr", default: none),
        recipient.at("po-nr", default: none),
      )),
      contract-nr: text-or-none(first-of(
        ctx.at("contract-nr", default: none),
        recipient.at("contract-nr", default: none),
      )),
      despatch-nr: text-or-none(first-of(
        ctx.at("delivery-note-nr", default: none),
        recipient.at("delivery-note-nr", default: none),
      )),
      preceding-invoice-nr: text-or-none(first-of(
        ctx.at("preceding-invoice-nr", default: none),
        ctx.at("original-invoice-nr", default: none),
      )),
      // BT-26
      preceding-invoice-date: ctx.at("preceding-invoice-date", default: none),
      // BT-22, BT-21
      notes: _notes(ctx.at("notes", default: ())),
      // BT-11
      project: text-or-none(ctx.at("project", default: none)),
    ),
    seller: seller,
    buyer: buyer,
    ship-to: ship-to,
    tax-representative: tax-representative,
    payee: payee,
    // BT-72 or BG-14
    delivery: _delivery(service-period)
      + (
        source: if service-period != none { service-period.source },
        text: period-text,
        printed: if printed-period != none { printed-period.text },
        printed-own: printed-period != none and printed-period.own,
        shown: _period-shown(
          ctx,
          printed,
          printed-period,
          period-text,
          item-data.at("dates-printed", default: false),
        ),
      ),
    lines: lines,
    allowance-charges: allowance-charges,
    taxes: breakdown,
    // BT-106 to BT-108 add up the XML; the others are the printed totals.
    totals: (
      line: line-total,
      allowance: allowance-total,
      charge: charge-total,
      net: net-total,
      tax: tax-total,
      gross: gross-total,
      prepaid: prepaid-total,
      due: if means.paid != none { _zero } else {
        _decimal(item-data.at(
          "due-total",
          default: gross-total - prepaid-total,
        ))
      },
    ),
    payment: (
      reference: text-or-none(resolve-payment-reference(ctx, bank: bank)),
      // BG-16
      means: payment-means-model(means, currency),
      // BG-19: BT-89, BT-90
      mandate: if debit != none { _identifier(debit.mandate) },
      creditor-id: if debit != none { _upper-id(debit.creditor-id) },
      paid: means.paid != none,
      due-date: due-date,
      // BT-20 (see `profile-terms`)
      terms: terms,
      terms-xrechnung: terms-xrechnung,
      terms-input: terms-input,
      // `percent` in percent, `basis` or `none`.
      discounts: discounts.map(discount => (
        days: discount.days,
        percent: discount.percent,
        basis: discount.basis,
      )),
    ),
  )
}
