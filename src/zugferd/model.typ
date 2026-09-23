// Normalizes the computed invoice into the data model of the e-invoice.
//
// Everything the XML contains is derived here exactly once: plain texts,
// identifiers, net amounts and totals. The validator checks this model and the
// builder serializes it, so both always agree on what ends up in the XML.

#import "../utils/text.typ": plain-text
#import "codelists.typ"
#import "profile.typ": resolve-profile
#import "../utils/coercion.typ": to-decimal, to-ratio
#import "../data/tax.typ": to-tax-key
#import "../logic/payment-reference.typ": resolve-payment-reference

#let _zero = decimal("0")

// The first value that is set, or `none`.
#let first-of(..values) = (
  values.pos().find(value => value not in (none, auto, "", []))
)

// The plain text of a value, or `none` if it has no visible text.
#let text-or-none(value) = {
  let result = plain-text(value)
  if result == "" { none } else { result }
}

// Invisible format characters (Unicode category Cf: zero width space, byte
// order mark, word joiner, soft hyphen, ...), which copied identifiers often
// carry. They are all outside ASCII, so the patterns are compiled (once, on
// first use) only for texts that are not plain ASCII.
#let _invisible-patterns() = (
  invisible: regex("\\p{Cf}"),
  spaces: regex(" {2,}"),
)

// A plain text without invisible characters. The spaces around a removed
// character are joined, as `plain-text` has collapsed the whitespace before.
#let _visible(text) = {
  if text.len() == text.codepoints().len() { return text }
  let patterns = _invisible-patterns()
  text.replace(patterns.invisible, "").replace(patterns.spaces, " ").trim()
}

// The plain text of an identifier without any whitespace or invisible
// characters (VAT IDs, IBANs, email addresses, codes). `plain-text` turns all
// whitespace into single spaces.
#let compact(value) = {
  let result = _visible(plain-text(value).replace(" ", ""))
  if result == "" { none } else { result }
}

// The plain text of an identifier that may contain spaces (e.g. the tax
// number "143/123/45678" or "HRB 12345"), without invisible characters.
#let _identifier(value) = {
  let result = _visible(plain-text(value))
  if result == "" { none } else { result }
}

#let _sum(values) = values.fold(_zero, (total, value) => total + value)

// The value of `key` in `dict`. The root context fills missing values with
// placeholders such as "#invoice-nr" or "#sender.city-name" for the visual
// invoice; those count as missing here.
#let _field(dict, key) = {
  let value = dict.at(key, default: none)
  if (
    type(value) == str
      and (
        value == "#" + key
          or (value.starts-with("#") and value.ends-with("." + key))
      )
  ) { none } else { value }
}

// ISO 3166-1 alpha-2 code of a party's country.
#let country-code(party) = {
  let country = party.at("country", default: none)
  let code = if type(country) == dictionary {
    country.at("code", default: none)
  } else { country }
  let code = if type(code) in (str, content) { compact(code) } else { none }
  if code == none { none } else { upper(code) }
}

// Electronic address schemes (EAS) for national VAT identification numbers,
// keyed by the VAT ID prefix (Greece uses "EL"). Only schemes of the EAS code
// list the validators accept (`codelists.eas`); Denmark and Sweden, for
// example, have none, so their parties fall back to the email address.
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

/// The prefix of a VAT identifier: its first two characters in upper case,
/// or `none` if it is shorter. Taken by characters, never by bytes, so that
/// a VAT ID starting with any character (e.g. "€") is safe to inspect.
///
/// -> none | str
#let vat-id-prefix(vat-id) = {
  if vat-id == none { return none }
  let chars = vat-id.codepoints()
  if chars.len() < 2 { none } else { upper(chars.at(0) + chars.at(1)) }
}

/// The ISO 3166-1 code of the country that issued a VAT identifier: its
/// prefix, with "EL" for Greece and "XI" (Northern Ireland) for the United
/// Kingdom, or `none` if the prefix is not a country code.
///
/// -> none | str
#let vat-id-country(vat-id) = {
  let prefix = vat-id-prefix(vat-id)
  let code = if prefix == "EL" { "GR" } else if prefix == "XI" { "GB" } else {
    prefix
  }
  if code != none and code in codelists.countries { code } else { none }
}

// Contact details of a party, from `contact` or the flat `contact-name`,
// `phone` and `email` keys.
#let contact-model(party) = {
  let contact = party.at("contact", default: none)
  let nested = if type(contact) == dictionary { contact } else if (
    contact != none
  ) { (name: contact) } else { (:) }
  let result = (
    name: text-or-none(first-of(
      nested.at("name", default: none),
      party.at("contact-name", default: none),
    )),
    phone: text-or-none(first-of(
      nested.at("phone", default: none),
      party.at("phone", default: none),
    )),
    email: compact(first-of(
      nested.at("email", default: none),
      party.at("email", default: none),
    )),
  )
  if result.values().all(value => value == none) { none } else { result }
}

/// Retrieves the electronic address (BT-34, BT-49) of a party: the explicit
/// `electronic-address`, else one derived from the VAT ID, else the email.
///
/// An explicit address without an identifier (`""`, `auto`, `(scheme: "EM")`
/// or an empty field of imported data) counts as not given, so the address is
/// derived instead: the XML never gets an address without identifier (BR-62,
/// BR-63). An address without scheme is an email address (`EM`) if it contains
/// "@"; otherwise its scheme stays `none` for the validator to report.
///
/// The VAT ID is used even when the invoice is not subject to VAT: BR-O-02
/// leaves out the VAT identifiers (BT-31, BT-48), not the electronic address.
///
/// Returns `none` or `(scheme: none | str, id: str)`.
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
  } else if explicit != auto {
    let id = compact(explicit)
    if id != none {
      return (scheme: if id.contains("@") { "EM" }, id: id)
    }
  }

  // The prefix names the country that issued the VAT ID, and only that
  // country's scheme fits: a Danish VAT ID of a German company is no German VAT
  // endpoint. Without a scheme for the prefix, the email is used.
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

// An identifier with an optional scheme: a dictionary such as a GLN
// `(scheme: "0088", id: ..)`, or a text without scheme. Identifiers with a
// scheme are written without spaces; `none` if there is no identifier.
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

// The identifiers of a party, from the input `keys` in this order. An
// identifier without scheme is the party identifier written as `ram:ID`
// (BT-29, BT-46, BT-71), one with scheme the global identifier (`ram:GlobalID`):
// `id` may be given with a scheme, and a `global-id` without one is an
// ordinary identifier. The keys each value came from are kept (`id-keys`,
// `global-id-keys`), so that the validator reports two different values for
// one of them instead of dropping one.
#let _party-ids(party, keys) = {
  let ids = ()
  let id-keys = ()
  let global-ids = ()
  let global-id-keys = ()
  for key in keys {
    let value = _scheme-id(party.at(key, default: none))
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

// --- Keys of the party dictionaries ------------------------------------------

// The keys of `sender`, `recipient` and `delivery-address` besides the address:
// `true` if the e-invoice reads the key, `false` if only the printed invoice
// uses it.
#let _address-keys = (
  name: true,
  address: true,
  street: true,
  city: true,
  country: true,
  region: true,
  extra: false,
)

/// The keys each party knows, by role: the seller (`sender`), the buyer
/// (`recipient`) and the ship-to party (`delivery-address`). `true` marks the
/// keys the e-invoice reads, `false` those only the printed invoice uses.
#let party-keys = (
  seller: _address-keys
    + (
      id: true,
      global-id: true,
      vat-id: true,
      tax-nr: true,
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
      vat-id: true,
      electronic-address: true,
      contact: true,
      email: true,
      buyer-reference: true,
      leitweg-id: true,
      order-nr: true,
      po-nr: true,
      contract-nr: true,
      delivery-note-nr: true,
      delivery-address: true,
      tax-nr: false,
      contact-name: false,
      phone: false,
      customer-nr: false,
      customer-id: false,
      order-date: false,
      project: false,
      quote-nr: false,
    ),
  ship-to: _address-keys + (id: true, location-id: true, global-id: true),
)

// The keys of a party's `contact`.
#let _contact-keys = (name: true, phone: true, email: true)

// The keys of an identifier given as a dictionary (`id`, `global-id`,
// `location-id`, `electronic-address`).
#let _identifier-keys = (scheme: true, id: true)

// Keys the normalization of a party adds (see `normalize-party`); they are
// not part of the input.
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

#let _post-code-hint = "Write the post code into `city`, e.g. `city: \"10115 Berlin\"` or `city: (name: \"Berlin\", post-code: \"10115\")`."

// Other names of party keys, as normalized by `_normalize-key`: the key they
// stand for, or the key and a hint where renaming alone does not fit.
#let _key-aliases = (
  vat: "vat-id",
  vatid: "vat-id",
  vat-nr: "vat-id",
  vat-no: "vat-id",
  vat-number: "vat-id",
  ust-id: "vat-id",
  ustid: "vat-id",
  ust-idnr: "vat-id",
  ust-id-nr: "vat-id",
  tva: "vat-id",
  iva: "vat-id",
  btw: "vat-id",
  mwst: "vat-id",
  mwst-nr: "vat-id",
  taxnr: "tax-nr",
  tax-no: "tax-nr",
  tax-number: "tax-nr",
  tax-id: (
    "tax-nr",
    "Rename it to `tax-nr` for the national tax number, or to `vat-id` for the VAT identification number.",
  ),
  steuernummer: "tax-nr",
  steuer-nr: "tax-nr",
  st-nr: "tax-nr",
  stnr: "tax-nr",
  mail: "email",
  e-mail: "email",
  email-address: "email",
  tel: "phone",
  telephone: "phone",
  telefon: "phone",
  phone-number: "phone",
  endpoint: "electronic-address",
  endpoint-id: "electronic-address",
  peppol-id: "electronic-address",
  gln: (
    "global-id",
    "Pass the GLN as `global-id: (scheme: \"0088\", id: ..)`.",
  ),
  leitweg: "leitweg-id",
  strasse: "street",
  straße: "street",
  ort: "city",
  zip: ("city", _post-code-hint),
  zip-code: ("city", _post-code-hint),
  postcode: ("city", _post-code-hint),
  postal-code: ("city", _post-code-hint),
  post-code: ("city", _post-code-hint),
  plz: ("city", _post-code-hint),
  city-name: ("city", _post-code-hint),
  land: "country",
  country-code: "country",
)

// Patterns for unknown keys, compiled once on first use: unknown keys are rare.
#let _key-patterns() = (
  camel-case: regex("([a-z0-9])([A-Z])"),
  separators: regex("[\\s_.-]+"),
  numbered: regex("[0-9]$"),
)

// A key in lower case with `-` between its words: "vatId", "vat_id" and
// "VAT-ID" all become "vat-id".
#let _normalize-key(key) = {
  let patterns = _key-patterns()
  let key = key.replace(patterns.camel-case, m => (
    m.captures.at(0) + "-" + m.captures.at(1)
  ))
  lower(key).replace(patterns.separators, "-").trim("-")
}

// The optimal string alignment distance of `a` and `b` (edits and swaps of
// neighboring characters), or `limit + 1` as soon as it exceeds `limit`.
#let _edit-distance(a, b, limit) = {
  let a = a.clusters()
  let b = b.clusters()
  if calc.abs(a.len() - b.len()) > limit { return limit + 1 }
  let before = none
  let previous = range(b.len() + 1)
  for i in range(1, a.len() + 1) {
    let current = (i,)
    let lowest = i
    for j in range(1, b.len() + 1) {
      let cost = if a.at(i - 1) == b.at(j - 1) { 0 } else { 1 }
      let value = calc.min(
        previous.at(j) + 1,
        current.at(j - 1) + 1,
        previous.at(j - 1) + cost,
      )
      if (
        i > 1
          and j > 1
          and a.at(i - 1) == b.at(j - 2)
          and a.at(i - 2) == b.at(j - 1)
      ) {
        value = calc.min(value, before.at(j - 2) + 1)
      }
      current.push(value)
      lowest = calc.min(lowest, value)
    }
    if lowest > limit { return limit + 1 }
    before = previous
    previous = current
  }
  calc.min(previous.last(), limit + 1)
}

// The known key a misspelled `key` most likely stands for: within an edit
// distance of 1 for keys of up to 4 characters and of 2 for longer ones,
// preferring keys the e-invoice reads.
#let _closest-key(key, known) = {
  let best = none
  let best-distance = none
  for (candidate, einvoice) in known.pairs() {
    let limit = if candidate.len() <= 4 { 1 } else { 2 }
    let distance = _edit-distance(key, candidate, limit)
    if distance > limit { continue }
    if (
      best == none
        or distance < best-distance
        or (distance == best-distance and einvoice and not known.at(best))
    ) {
      best = candidate
      best-distance = distance
    }
  }
  best
}

// An input key a party does not know: the known key it looks like (`like`),
// whether the e-invoice reads that key, and a hint where renaming alone does
// not fit. A key ending in a number (e.g. "email2") is taken as deliberate.
#let _unknown-key(key, known, path: none) = {
  let normalized = _normalize-key(key)
  let like = none
  let hint = none
  if normalized in _key-aliases {
    let alias = _key-aliases.at(normalized)
    if type(alias) == str { like = alias } else { (like, hint) = alias }
  } else if normalized in known {
    like = normalized
  } else if normalized.match(_key-patterns().numbered) == none {
    like = _closest-key(normalized, known)
  }
  if like != none and like not in known {
    like = none
    hint = none
  }
  (
    key: key,
    path: if path == none { key } else { path + "." + key },
    within: path,
    like: like,
    einvoice: like != none and known.at(like),
    hint: hint,
  )
}

// Whether an input value states nothing: the keys of such values are ignored.
#let _is-unset(value) = value in (none, auto, "", [], ())

// The keys of a party dictionary, of its `contact` and of its identifiers that
// the role does not know (see `party-keys`), each described by `_unknown-key`.
#let _input-keys(party, role) = {
  let known = party-keys.at(role)
  // A key standing for the city or post code loses nothing next to a city
  // line whose post code was recognized.
  let has-post-code = text-or-none(_field(party, "post-code")) != none
  let result = ()
  for (key, value) in party.pairs() {
    if key in known or key in _derived-keys or _is-unset(value) { continue }
    let entry = _unknown-key(key, known)
    if entry.like == "city" and has-post-code { entry.einvoice = false }
    result.push(entry)
  }
  let contact = party.at("contact", default: none)
  if "contact" in known and type(contact) == dictionary {
    for (key, value) in contact.pairs() {
      if key in _contact-keys or _is-unset(value) { continue }
      result.push(_unknown-key(key, _contact-keys, path: "contact"))
    }
  }
  // An identifier dictionary without `id` is left out, so any other key of it
  // loses the identifier.
  for key in ("id", "global-id", "location-id", "electronic-address") {
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

// --- Parties -------------------------------------------------------------------

#let _address-model(party) = {
  let raw-lines = party.at("address-lines", default: ())
  let lines = if type(raw-lines) == array { raw-lines } else { (raw-lines,) }
  (
    lines: lines.map(text-or-none).filter(line => line != none),
    city: text-or-none(_field(party, "city-name")),
    post-code: text-or-none(_field(party, "post-code")),
    state: text-or-none(_field(party, "state")),
    country: country-code(party),
    // Whether the party states its country (`country` or `region`); otherwise
    // it is the country of the locale or, for a delivery address, the buyer's.
    country-explicit: party.at("country-explicit", default: true) != false,
  )
}

// The name of a party (BT-27, BT-44, BT-70). A name given as several lines is
// one name, its lines joined by ", " as in the inline sender line.
#let _party-name(party) = {
  let name = first-of(_field(party, "name-inline"), _field(party, "name"))
  if type(name) == array {
    name = name.map(text-or-none).filter(line => line != none).join(", ")
  }
  text-or-none(name)
}

/// A seller, buyer or ship-to party (`role`: `"seller"`, `"buyer"` or
/// `"ship-to"`). `vat-id` is the VAT identifier the party states;
/// `use-vat-id: false` keeps it out of the XML (BR-O-02), but not out of the
/// electronic address. With a `role`, the keys of the party dictionary are
/// checked against those the role knows (`input-keys`).
///
/// -> dictionary
#let party-model(party, role: none, use-vat-id: true) = {
  if type(party) != dictionary { party = (:) }
  let vat-id = compact(party.at("vat-id", default: none))
  if vat-id != none { vat-id = upper(vat-id) }
  let id-keys = if role == "ship-to" {
    ("id", "location-id", "global-id")
  } else {
    ("id", "global-id")
  }
  (
    (
      name: _party-name(party),
      vat-id: if use-vat-id { vat-id } else { none },
      stated-vat-id: vat-id,
      tax-nr: _identifier(party.at("tax-nr", default: none)),
      address: _address-model(party),
      electronic-address: get-electronic-address(party),
      contact: contact-model(party),
      input-keys: if role == none { () } else { _input-keys(party, role) },
    )
      + _party-ids(party, id-keys)
  )
}

// The seller (BG-4). Without an own identifier (BT-29) or a VAT identifier
// (BT-31) in the XML, the tax number identifies the seller (BR-CO-26).
#let seller-model(party, use-vat-id: true) = {
  let seller = party-model(party, role: "seller", use-vat-id: use-vat-id)
  if seller.id == none and seller.global-id == none and seller.vat-id == none {
    seller.id = seller.tax-nr
  }
  seller
}

// The ship-to party of an intra-community supply without delivery address: the
// buyer's address (BR-IC-12), without identifiers or input of its own.
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

// Map common invoice-pro unit strings to UN/ECE recommendation 20 unit codes.
#let map-unit-code(unit) = {
  if type(unit) == dictionary {
    let code = compact(unit.at("code", default: none))
    if code != none { return code }
    unit = unit.at("display", default: none)
  }
  let raw = plain-text(unit)
  // A unit written exactly as a code, e.g. "H87". Case-sensitive, so that "St"
  // (Stück) is not taken for "ST" (sheet).
  if raw in codelists.units { return raw }
  let u = lower(raw)
  if u in ("hrs", "hr", "h", "std.", "std", "stunde", "stunden") {
    "HUR"
  } else if u in ("day", "days", "tag", "tage") { "DAY" } else if (
    u in ("month", "months", "monat", "monate")
  ) { "MON" } else if u in ("year", "years", "jahr", "jahre") {
    "ANN"
  } else if u in ("kg",) { "KGM" } else if u in ("g", "gram") {
    "GRM"
  } else if u in ("m", "meter") { "MTR" } else if u in ("l", "liter") {
    "LTR"
  } else { "C62" }
}

// Determine delivery date or period from items
#let determine-delivery-dates(ctx, items) = {
  let all-dates = ()
  for item in items {
    let item-date = item.at("date", default: none)
    if item-date == auto or item-date == none {
      all-dates.push(ctx.invoice-date)
    } else if type(item-date) == datetime {
      all-dates.push(item-date)
    } else if type(item-date) == array {
      for d in item-date {
        if type(d) == datetime {
          all-dates.push(d)
        }
      }
    }
  }

  let sorted-dates = all-dates.filter(d => type(d) == datetime).sorted().dedup()
  if sorted-dates.len() == 0 {
    (date: ctx.invoice-date, period: none)
  } else if sorted-dates.len() == 1 {
    (date: sorted-dates.first(), period: none)
  } else {
    (date: none, period: (sorted-dates.first(), sorted-dates.last()))
  }
}

// VAT exemption reason texts EN 16931 expects for a category (BR-AE-10,
// BR-IC-10, BR-G-10, BR-O-10) when the tax has no `grounds` of its own.
#let _default-exemption-reasons = (
  AE: "Reverse charge",
  K: "Intra-community supply",
  G: "Export outside the EU",
  O: "Not subject to VAT",
)

// Categories whose VAT breakdown must not carry an exemption reason
// (BR-S-10, BR-Z-10, BR-AF-10, BR-AG-10).
#let _taxed-categories = ("S", "Z", "L", "M")

#let exemption-reason(category, grounds) = {
  if category in _taxed-categories { return none }
  let reason = text-or-none(grounds)
  if reason != none { reason } else {
    _default-exemption-reasons.at(str(category), default: none)
  }
}

// The key of the VAT group a tax belongs to, as used by `group-by-tax`.
#let _tax-key(tax) = {
  if type(tax) != dictionary or "rate" not in tax or "category" not in tax {
    return none
  }
  to-tax-key((rate: to-ratio(tax.rate), category: tax.category))
}

// Net amount of a (possibly gross) amount, rounded to 2 decimals.
#let _net(amount, rate, inclusive) = {
  if inclusive { calc.round(amount / (1 + rate), digits: 2) } else { amount }
}

// An invoice line (BG-25) with net amounts.
#let line-model(item, index, inclusive: false, price-digits: 4) = {
  let tax = item.at("tax", default: (:))
  if type(tax) != dictionary { tax = (:) }
  let rate = to-ratio(tax.at("rate", default: 0))

  let quantity = to-decimal(item.at("quantity", default: 1))
  let base-quantity = to-decimal(item.at("base-quantity", default: 1))
  let price = to-decimal(item.at("price", default: 0))
  if inclusive {
    price = calc.round(price / (1 + rate), digits: price-digits)
  }
  // BR-27: the item net price must not be negative, the quantity carries the
  // sign of a credited line instead.
  if price < _zero {
    price = -price
    quantity = -quantity
  }

  let allowances = ()
  let charges = ()
  for modifier in (
    item.at("discounts", default: ()) + item.at("surcharge", default: ())
  ) {
    let amount = to-decimal(modifier.at("absolute", default: 0))
    let entry = (
      amount: _net(calc.abs(amount), rate, inclusive),
      reason: text-or-none(modifier.at("name", default: none)),
    )
    if entry.amount == _zero { continue }
    if amount < _zero { allowances.push(entry) } else { charges.push(entry) }
  }

  let item-id = item.at("item-id", default: none)
  if type(item-id) == str { item-id = (seller: item-id) }
  if type(item-id) != dictionary { item-id = (:) }

  (
    index: index,
    id: first-of(text-or-none(item.at("pos", default: none)), str(index + 1)),
    name: text-or-none(item.at("name", default: none)),
    description: text-or-none(item.at("description", default: none)),
    standard-id: compact(item-id.at("standard", default: none)),
    seller-id: text-or-none(item-id.at("seller", default: none)),
    buyer-id: text-or-none(item-id.at("buyer", default: none)),
    quantity: quantity,
    base-quantity: base-quantity,
    unit-code: map-unit-code(item.at("unit", default: none)),
    price: price,
    net: _net(to-decimal(item.at("total", default: 0)), rate, inclusive),
    key: _tax-key(tax),
    category: text-or-none(tax.at("category", default: none)),
    rate: rate,
    allowances: allowances,
    charges: charges,
  )
}

// The document level allowances (BG-20) and charges (BG-21): every global
// modifier is split into one entry per VAT category it applies to (BR-53).
#let document-allowance-charges(discounts, surcharges, inclusive: false) = {
  let entries = ()
  for modifier in discounts + surcharges {
    let reason = text-or-none(modifier.at("name", default: none))
    for (key, part) in modifier.at("split", default: (:)).pairs() {
      let amount = to-decimal(part.at("absolute", default: 0))
      let tax = part.at("tax", default: (:))
      let rate = to-ratio(tax.at("rate", default: 0))
      let net = _net(calc.abs(amount), rate, inclusive)
      if net == _zero { continue }
      entries.push((
        charge: amount > _zero,
        amount: net,
        reason: reason,
        key: key,
        category: text-or-none(tax.at("category", default: none)),
        rate: rate,
      ))
    }
  }
  entries
}

// With gross prices, every line and allowance is converted to net on its own.
// The rounding differences are moved onto the largest line of each VAT
// category, so the lines add up to the printed taxable amount (BR-S-08, ...).
#let _balance-lines(lines, allowance-charges, taxes) = {
  let lines = lines
  for (key, tax) in taxes.pairs() {
    let indices = lines
      .enumerate()
      .filter(((_, line)) => line.key == key)
      .map(((i, _)) => i)
    if indices.len() == 0 { continue }
    let entries = allowance-charges.filter(entry => entry.key == key)
    let expected = to-decimal(tax.at("basis", default: 0))
    let actual = (
      _sum(indices.map(i => lines.at(i).net))
        + _sum(entries.map(e => if e.charge { e.amount } else { -e.amount }))
    )
    let difference = expected - actual
    let tolerance = decimal("0.01") * (indices.len() + entries.len() + 1)
    if difference != _zero and calc.abs(difference) <= tolerance {
      let largest = indices.sorted(key: i => calc.abs(lines.at(i).net)).last()
      lines.at(largest).net += difference
    }
  }
  lines
}

/// Builds the e-invoice data model from the root context and the computed
/// line item data.
///
/// -> dictionary
#let build-model(ctx, item-data, payment-goal: none, bank: none) = {
  let sender = ctx.at("sender", default: (:))
  let recipient = ctx.at("recipient", default: (:))
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
  let price-digits = (
    ctx
      .at("locale", default: (:))
      .at("currency", default: (:))
      .at("decimals-fine", default: 4)
  )

  // BR-O-02: an invoice not subject to VAT carries no VAT identifiers. MINIMUM
  // has no VAT breakdown; there the seller VAT ID is needed for BR-CO-26.
  let categories = taxes.values().map(tax => tax.at("category", default: none))
  let outside-scope = profile.id != "minimum" and "O" in categories

  let seller = seller-model(sender, use-vat-id: not outside-scope)
  let buyer = party-model(
    recipient,
    role: "buyer",
    use-vat-id: not outside-scope,
  )

  // `location-id` is another name of the deliver to location identifier
  // (BT-71), `id` of the delivery address.
  let delivery-party = ctx.at("delivery-address", default: none)
  let ship-to = if type(delivery-party) == dictionary {
    party-model(delivery-party, role: "ship-to", use-vat-id: false)
  } else if "K" in categories and buyer.address.country != none {
    // BR-IC-12: an intra-community supply names the deliver-to country;
    // without a delivery address, the goods go to the buyer.
    _ship-to-buyer(buyer.address)
  } else { none }

  let lines = items
    .enumerate()
    .map(((i, item)) => line-model(
      item,
      i,
      inclusive: inclusive,
      price-digits: price-digits,
    ))
  let allowance-charges = document-allowance-charges(
    item-data.at("discounts", default: ()),
    item-data.at("surcharges", default: ()),
    inclusive: inclusive,
  )
  if inclusive {
    lines = _balance-lines(lines, allowance-charges, taxes)
  }

  let breakdown = taxes
    .pairs()
    .map(((key, tax)) => {
      let category = text-or-none(tax.at("category", default: none))
      (
        key: key,
        category: category,
        rate: to-ratio(tax.at("rate", default: 0)),
        basis: to-decimal(tax.at("basis", default: 0)),
        amount: to-decimal(tax.at("absolute", default: 0)),
        reason: exemption-reason(category, tax.at("grounds", default: none)),
      )
    })

  let line-total = _sum(lines.map(line => line.net))
  let allowance-total = _sum(
    allowance-charges.filter(e => not e.charge).map(e => e.amount),
  )
  let charge-total = _sum(
    allowance-charges.filter(e => e.charge).map(e => e.amount),
  )
  let net-total = line-total - allowance-total + charge-total
  let tax-total = _sum(breakdown.map(tax => tax.amount))
  let gross-total = net-total + tax-total
  let prepaid-total = to-decimal(item-data.at("prepaid-total", default: 0))

  let locale = ctx.at("locale", default: (:))
  let currency = compact(
    locale.at("currency", default: (:)).at("code", default: none),
  )
  if currency != none { currency = upper(currency) }

  let iban = if bank != none { compact(bank.at("iban", default: none)) }
  let bic = if bank != none { compact(bank.at("bic", default: none)) }

  // BT-9 and BT-20: the invoice's own `due-date` wins over the payment goal.
  let due-date = none
  let terms = none
  let explicit-due-date = ctx.at("due-date", default: none)
  if type(explicit-due-date) == datetime {
    due-date = explicit-due-date
  } else {
    terms = text-or-none(explicit-due-date)
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
      terms = text-or-none(goal-date)
    }
    // Without days or a date, the payment goal prints that the amount is due
    // at once ("sofort nach Erhalt"), which are the payment terms.
    if terms == none and due-date == none and goal-date == none {
      terms = text-or-none(
        locale
          .at("strings", default: (:))
          .at("payment", default: (:))
          .at("deadline-soon", default: none),
      )
    }
  }

  (
    profile: profile,
    tax-mode: tax-mode,
    outside-scope: outside-scope,
    currency: currency,
    invoice: (
      number: text-or-none(_field(ctx, "invoice-nr")),
      type-code: "380",
      issue-date: ctx.at("invoice-date", default: none),
      buyer-reference: text-or-none(first-of(
        ctx.at("buyer-reference", default: none),
        recipient.at("buyer-reference", default: none),
        recipient.at("leitweg-id", default: none),
      )),
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
    ),
    seller: seller,
    buyer: buyer,
    ship-to: ship-to,
    delivery: determine-delivery-dates(ctx, items),
    lines: lines,
    allowance-charges: allowance-charges,
    taxes: breakdown,
    totals: (
      line: line-total,
      allowance: allowance-total,
      charge: charge-total,
      net: net-total,
      tax: tax-total,
      gross: gross-total,
      prepaid: prepaid-total,
      due: gross-total - prepaid-total,
    ),
    // The totals printed on the invoice, to verify the XML against them.
    printed-totals: (
      net: to-decimal(item-data.at("net-total", default: 0)),
      gross: to-decimal(item-data.at("gross-total", default: 0)),
    ),
    payment: (
      reference: text-or-none(resolve-payment-reference(ctx, bank: bank)),
      // BT-81: SEPA credit transfer, other credit transfers outside EUR.
      means: if iban != none {
        (
          type-code: if currency == "EUR" { "58" } else { "30" },
          iban: upper(iban),
          bic: if bic != none { upper(bic) },
        )
      },
      due-date: due-date,
      terms: terms,
    ),
  )
}
