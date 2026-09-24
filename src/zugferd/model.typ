// Normalizes the computed invoice into the data model of the e-invoice.
//
// Everything the XML contains is derived here exactly once: plain texts,
// identifiers, net amounts and totals. The validator checks this model and the
// builder serializes it, so both always agree on what ends up in the XML.

#import "../utils/text.typ": plain-text
#import "codelists.typ"
#import "profile.typ": resolve-profile
#import "../utils/coercion.typ": to-decimal, to-ratio
#import "../data/tax.typ": default-grounds, to-tax-key
#import "../data/unit.typ": unit-db
#import "../locale/lang/lang.typ" as languages
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
#import "xml.typ": fmt-number

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

/// The payment terms (BT-20) of a text, or `none`. Unlike other texts, they
/// keep their line breaks: the XRechnung Skonto syntax (BR-DE-18) writes each
/// cash discount on a line of its own, e.g. "#SKONTO#TAGE=14#PROZENT=2.00#",
/// followed by a line break, which is added when the text ends with such a
/// line.
///
/// -> str | none
#let payment-terms(value) = {
  let terms = plain-text(value, keep-newlines: true)
  if terms == "" { none } else if terms.ends-with("#") { terms + "\n" } else {
    terms
  }
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
/// (`recipient`), the ship-to party (`delivery-address`), the seller's tax
/// representative (`sender.tax-representative`) and the payee (`payee`).
/// `true` marks the keys the e-invoice reads, `false` those only the printed
/// invoice uses.
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

// The keys of a party's `contact`, by role. The e-invoice writes the seller
// contact (BG-6) and the buyer contact (BG-9).
#let _contact-keys = (
  seller: (name: true, phone: true, email: true),
  buyer: (name: true, phone: true, email: true),
)

// The keys of an identifier given as a dictionary (`id`, `global-id`,
// `location-id`, `legal-id`, `electronic-address`), including those of a typed
// identifier of the `id` module (`kind`, `problems`).
#let _identifier-keys = (scheme: true, id: true, kind: true, problems: true)

// The keys of each role that take an identifier, possibly a typed one of the
// `id` module (`id.siret(..)`), whose problems the validator reports.
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

// Keys the normalization of a party adds (see `normalize-party`); they are
// not part of the input. A `post-code`, `city-name` or `state` of the input is
// replaced by the parts of its `city`.
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
  ustidnr: "vat-id",
  ust-id-nr: "vat-id",
  uid: "vat-id",
  uid-nr: "vat-id",
  tva: "vat-id",
  numero-tva: "vat-id",
  tva-intracom: "vat-id",
  iva: "vat-id",
  partita-iva: "vat-id",
  p-iva: "vat-id",
  piva: "vat-id",
  nif-iva: "vat-id",
  btw: "vat-id",
  btw-nr: "vat-id",
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
  tel-nr: "phone",
  tel-no: "phone",
  telnr: "phone",
  telephone: "phone",
  telefon: "phone",
  telefon-nr: "phone",
  phone-nr: "phone",
  phone-no: "phone",
  phone-number: "phone",
  endpoint: "electronic-address",
  endpoint-id: "electronic-address",
  peppol-id: "electronic-address",
  gln: (
    "global-id",
    "Pass the GLN as `global-id: id.gln(..)`.",
  ),
  // The legal registration identifier (BT-30, BT-47) and the constructors of
  // the `id` module for its schemes.
  siret: ("legal-id", "Pass the SIRET as `legal-id: id.siret(..)`."),
  siren: ("legal-id", "Pass the SIREN as `legal-id: id.siren(..)`."),
  handelsregister: (
    "legal-id",
    "Pass the register number as `legal-id: id.register(\"HRB ..\", court: \"Amtsgericht ..\")`.",
  ),
  hrb: (
    "legal-id",
    "Pass the register number as `legal-id: id.register(\"HRB ..\", court: \"Amtsgericht ..\")`.",
  ),
  register-number: "legal-id",
  registration-number: "legal-id",
  company-number: "legal-id",
  company-registration-number: "legal-id",
  trade-name: "trading-name",
  business-name: "trading-name",
  legal-information: "legal-info",
  fiscal-representative: "tax-representative",
  tax-rep: "tax-representative",
  vat-representative: "tax-representative",
  fiskalvertreter: "tax-representative",
  leitweg: "leitweg-id",
  order: "order-nr",
  po: "po-nr",
  contract: "contract-nr",
  delivery-note: "delivery-note-nr",
  strasse: "street",
  straße: "street",
  ort: "city",
  zip: ("city", _post-code-hint),
  zip-code: ("city", _post-code-hint),
  zipcode: ("city", _post-code-hint),
  postcode: ("city", _post-code-hint),
  postal-code: ("city", _post-code-hint),
  postalcode: ("city", _post-code-hint),
  plz: ("city", _post-code-hint),
  land: "country",
  country-code: "country",
  // A missing "r" of `country`, or the county of a British or Irish address.
  county: (
    "country",
    "Rename it to `country` if it states the country. The e-invoice has no field for a county; write it into `address` to print it.",
  ),
)

// Keys invoices often carry that `invoice-pro` does not read, but which look
// like misspellings of keys it knows ("fax-nr" and "tax-nr"). Like any
// unknown key, they are not written into the e-invoice, but they are never
// taken for a misspelling.
#let _other-keys = (
  fax-nr: true,
  fax-no: true,
  faxnr: true,
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
// not fit. A key ending in a number (e.g. "email2") and the keys of
// `_other-keys` are taken as deliberate.
#let _unknown-key(key, known, path: none) = {
  let normalized = _normalize-key(key)
  let like = none
  let hint = none
  if normalized in _key-aliases {
    let alias = _key-aliases.at(normalized)
    if type(alias) == str { like = alias } else { (like, hint) = alias }
  } else if normalized in known {
    like = normalized
  } else if (
    normalized not in _other-keys
      and normalized.match(_key-patterns().numbered) == none
  ) {
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
  // line whose post code was recognized, one standing for the country (e.g.
  // `county`) nothing next to a `country` the party states.
  let has-post-code = text-or-none(_field(party, "post-code")) != none
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
  // An identifier dictionary without `id` is left out, so any other key of it
  // loses the identifier.
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

// The text of a party detail that may be given as several lines, e.g.
// `legal-info: ("Sitz: München", "Amtsgericht München, HRB 98765")`: its
// lines joined by ", ", as `info` prints them.
#let _lines-text(value) = {
  if type(value) == array {
    value = value.map(text-or-none).filter(line => line != none).join(", ")
  }
  text-or-none(value)
}

// A typed identifier of the `id` module (e.g. `id.siret(..)`): a dictionary
// with the `kind` of the identifier and the `problems` found when it was made.
#let _is-typed-id(value) = (
  type(value) == dictionary and "kind" in value and "problems" in value
)

// The typed identifiers a party gives for the identifier keys of its role,
// with the key each was given for, for the validator (IP-ID-01, IP-ID-03).
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

// The text of an identifier that may be given as a dictionary, e.g. the
// Leitweg-ID `id.leitweg(..)` as buyer reference (BT-10), which states no
// scheme.
#let _id-text(value) = {
  if type(value) == dictionary { value.at("id", default: none) } else { value }
}

// Whether a buyer states a contact point (BG-9): a `contact`, or a contact
// name or phone number of its own. An email address alone is where the
// invoice goes (it can be the electronic address, BT-49), not a contact.
#let _states-contact(party) = (
  not _is-unset(party.at("contact", default: none))
    or not _is-unset(party.at("contact-name", default: none))
    or not _is-unset(party.at("phone", default: none))
)

/// A seller, buyer or ship-to party (`role`: `"seller"`, `"buyer"` or
/// `"ship-to"`). `vat-id` is the VAT identifier the party states;
/// `use-vat-id: false` keeps it out of the XML (BR-O-02), but not out of the
/// electronic address. With a `role`, the keys of the party dictionary are
/// checked against those the role knows (`input-keys`).
///
/// `legal-id` is the legal registration identifier (BT-30, BT-47), a text or
/// an identifier with scheme (`id.siret(..)`), `trading-name` the name the
/// party trades under (BT-28, BT-45) and `legal-info` the additional legal
/// information of the seller (BT-33). The contact of the buyer (BG-9) is only
/// given when the buyer states a contact point (`contact`, `contact-name` or
/// `phone`).
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
      trading-name: _lines-text(_field(party, "trading-name")),
      legal-id: _scheme-id(party.at("legal-id", default: none)),
      legal-info: _lines-text(_field(party, "legal-info")),
      vat-id: if use-vat-id { vat-id } else { none },
      stated-vat-id: vat-id,
      tax-nr: _identifier(party.at("tax-nr", default: none)),
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

// The seller (BG-4). Without an own identifier (BT-29), a legal registration
// identifier (BT-30) or a VAT identifier (BT-31) in the XML, the tax number
// identifies the seller (BR-CO-26).
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

/// The seller tax representative (BG-11), from `sender.tax-representative`
/// normalized like a party (`normalize-party`): its name (BT-62), VAT
/// identifier (BT-63) and postal address (BG-12); `none` without one.
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

/// The payee (BG-10), from `payee` of the invoice: who receives the payment
/// instead of the seller, e.g. a factoring company. Its name (BT-59), its
/// identifier (BT-60, `id` or `global-id`) and its legal registration
/// identifier (BT-61); `none` without a payee.
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

// The UN/ECE Recommendation 20 codes of the units of the `unit` module, by
// their key in the language files.
#let _unit-codes = (
  piece: "H87",
  "set": "SET",
  pair: "PR",
  "lump-sum": "LS",
  hour: "HUR",
  day: "DAY",
  month: "MON",
  year: "ANN",
  kilogram: "KGM",
  gram: "GRM",
  tonne: "TNE",
  metre: "MTR",
  "square-metre": "MTK",
  millimetre: "MMT",
  centimetre: "CMT",
  kilometre: "KMT",
  litre: "LTR",
  "cubic-metre": "MTQ",
)

/// Unit texts and the UN/ECE Recommendation 20 codes they stand for, by the
/// text in lower case without a trailing ".": the symbols and names of the
/// unit database, the unit names of every language of invoice-pro and common
/// abbreviations. Only whole texts match, never a part of one.
///
/// It is built when called, so an invoice without e-invoice does not build
/// it: `build-model` builds it once for all lines (see `unit-resolver`).
///
/// -> dictionary
#let unit-aliases() = {
  let table = (:)
  for (code, texts) in (
    HUR: ("hr", "hrs", "std", "stunde", "stunden"),
    MIN: ("min", "mins", "minute", "minutes", "minuten"),
    SEC: ("s", "sec", "sek", "second", "seconds", "sekunde", "sekunden"),
    WEE: ("wk", "wks", "week", "weeks", "woche", "wochen"),
    MON: ("mon",),
    ANN: ("yr", "yrs"),
    KGM: ("kilo", "kilos"),
    TNE: ("to", "tonnen"),
    MTR: ("meter", "meters", "lfm"),
    MTK: ("m2", "qm", "sqm", "square meter", "square meters"),
    MTQ: ("m3", "cbm", "cubic meter", "cubic meters"),
    LTR: ("ltr", "liter", "liters"),
    MLT: ("ml",),
    KWH: ("kwh",),
    MWH: ("mwh",),
    H87: ("st", "stk", "stck", "pc", "pcs", "pce"),
    LS: ("psch", "pausch", "pauschal", "flat", "flat rate", "lumpsum"),
    IE: ("person", "persons", "pers", "personen"),
    ZP: ("page", "pages", "seite", "seiten"),
    P1: ("%", "percent", "prozent"),
  ).pairs() {
    for text in texts { table.insert(text, code) }
  }
  // Plurals that the languages list no own form for and that are no singular
  // with "s" (French, Italian and Spanish).
  for (code, texts) in (
    H87: ("pezzi", "unidades"),
    PR: ("paia", "pares"),
    HUR: ("ore",),
    DAY: ("giorni",),
    MON: ("mesi",),
    ANN: ("anni", "année", "années"),
    KGM: ("chilogrammi",),
    GRM: ("grammi",),
    TNE: ("tonnellate",),
    MTR: ("metri",),
    MTK: ("mètres carrés", "metri quadrati", "metros cuadrados"),
    MMT: ("millimetri",),
    CMT: ("centimetri",),
    KMT: ("chilometri",),
    LTR: ("litri",),
    MTQ: ("mètres cubes", "metri cubi", "metros cúbicos"),
  ).pairs() {
    for text in texts { table.insert(text, code) }
  }
  for unit in unit-db {
    if unit.symbol != none { table.insert(lower(unit.symbol), unit.code) }
    table.insert(lower(unit.name), unit.code)
  }
  for strings in (
    languages.de,
    languages.en,
    languages.fr,
    languages.it,
    languages.es,
  ) {
    for (key, names) in strings.units.pairs() {
      let code = _unit-codes.at(key, default: none)
      if code == none { continue }
      // A name, or its singular and plural.
      let names = if type(names) == dictionary { names.values() } else {
        (names,)
      }
      for name in names { table.insert(lower(name), code) }
    }
  }
  table
}

// Unit codes that are also common German abbreviations of other units, with
// what the code means and what the abbreviation stands for. Taken verbatim,
// they most likely do not mean what the code says.
#let _ambiguous-unit-codes = (
  STK: ("stick", "Stück"),
  PAL: ("pascal", "Palette"),
  FL: ("flake ton", "Flasche"),
  GL: ("gram per litre", "Glas"),
  KT: ("kit", "Karton"),
)

/// A function that returns the UN/ECE Recommendation 20 code of a unit
/// (BT-130, BT-150) as `(code: .., issue: ..)`. It builds the table of
/// `unit-aliases` once for all units it resolves, and keeps it to itself: a
/// function argument is hashed on every call.
///
/// A unit of the `unit` module or a dictionary carries its code. A text that
/// is exactly a code (e.g. "H87") is taken as it is, but a code that is also a
/// common abbreviation of another unit (e.g. "STK", the code of sticks) has
/// the issue `(kind: "ambiguous", ..)`. Any other text is looked up in the
/// unit names and abbreviations invoice-pro knows ("Std.", "m²", "qm",
/// "Stück", "pauschal", ...). A text it does not know has the issue
/// `(kind: "unknown", text: ..)` and the code C62 ("one") as placeholder:
/// invoice-pro does not guess what it means. Without a unit, the quantity
/// is a number of "one" (C62).
///
/// -> function
#let unit-resolver() = {
  let aliases = unit-aliases()
  unit => {
    if type(unit) == dictionary {
      let code = compact(unit.at("code", default: none))
      if code != none { return (code: code, issue: none) }
      unit = unit.at("display", default: none)
    }
    let text = plain-text(unit)
    if text == "" { return (code: "C62", issue: none) }
    // A unit written exactly as a code; case-sensitive, so that "min" is not
    // looked up as the code "MIN" but as an abbreviation (which gives the
    // same).
    if text in codelists.units {
      let ambiguous = _ambiguous-unit-codes.at(text, default: none)
      return (
        code: text,
        issue: if ambiguous != none {
          (
            kind: "ambiguous",
            text: text,
            meaning: ambiguous.first(),
            abbreviation: ambiguous.last(),
          )
        },
      )
    }
    let key = lower(text).trim(".", at: end)
    let code = aliases.at(key, default: none)
    // A plural with "s" ("heures", "kgs"), but not "ms" for "m".
    if code == none and key.ends-with("s") and key.clusters().len() > 2 {
      code = aliases.at(key.slice(0, -1), default: none)
    }
    if code != none { return (code: code, issue: none) }
    (code: "C62", issue: (kind: "unknown", text: text))
  }
}

/// The UN/ECE Recommendation 20 code of a unit as `(code: .., issue: ..)`,
/// see `unit-resolver`.
///
/// -> dictionary
#let resolve-unit(unit) = unit-resolver()(unit)

/// The UN/ECE Recommendation 20 code of a unit, see `unit-resolver`.
///
/// -> str
#let map-unit-code(unit) = resolve-unit(unit).code

/// The delivery date (BT-72) or the invoicing period (BG-14) of the
/// e-invoice: the service period the invoice prints (see
/// `resolve-service-period`), as `(date: .., period: ..)`. A single date is
/// the delivery date, a period its first and last date.
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

// The service period the invoice prints as a reference, or `none`:
// `(text: .., own: ..)`, its text and whether it is a text of its own rather
// than dates in the date format of the locale. That is the one of
// `references.service-time`, which marks it whatever its title, or a
// reference of its own with the title of the service period, e.g.
// `("Leistungszeitraum", "Juni 2026")`.
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
    let titled = (
      label != none
        and type(title) in (str, content)
        and text-or-none(title) == label
    )
    if mark in (service-period-label, service-period-text-label) or titled {
      if type(value) not in (str, content) { return none }
      let text = text-or-none(value)
      if text == none { return none }
      return (text: text, own: mark != service-period-label)
    }
  }
  none
}

// Whether the printed invoice shows the date of the supply (IP-PERIOD-03):
// `none` if that cannot be known, as the theme does not say that it prints
// the reference signs (see `logic/printed.typ`); `true` if it prints a
// service period as a reference (`printed-period`) or the dates of the items,
// or shows the text of the service period the e-invoice states
// (`period-text`) elsewhere, e.g. in a reference of another title or the
// text of the invoice, but not as the invoice date; else `false`.
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

// The notes of the invoice (BT-22 and BT-21, see `normalize-notes`): the
// plain text of each note with its line breaks, and its subject code in upper
// case. A note without text is left out.
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

// Categories whose VAT breakdown must not carry an exemption reason
// (BR-S-10, BR-Z-10, BR-AF-10, BR-AG-10).
#let _taxed-categories = ("S", "Z", "L", "M")

// The VAT exemption reason code (BT-121) of the categories that have one
// meaning (BR-AE-10, BR-IC-10, BR-G-10, BR-O-10).
#let _category-codes = (
  AE: "VATEX-EU-AE",
  K: "VATEX-EU-IC",
  G: "VATEX-EU-G",
  O: "VATEX-EU-O",
)

/// The VAT exemption reason codes (BT-121) the items of a VAT group give
/// (`code` of the constructors of the `tax` module): distinct, without
/// whitespace and in upper case, as the validator checks them.
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

/// The VAT exemption reason code (BT-121) of a VAT category: the one code its
/// items give, else the code of the category for AE, K, G and O (e.g.
/// "VATEX-EU-IC" for an intra-community supply). A taxed category (S, Z, L,
/// M) has none, and neither has a group whose items give different codes:
/// EN 16931 states one per VAT category and rate, so the reasons are stated
/// as text (BT-120) only; the validator reports both.
///
/// -> none | str
#let exemption-code(category, codes) = {
  if category in _taxed-categories or codes.len() > 1 { return none }
  if codes.len() == 1 { codes.first() } else {
    _category-codes.at(category, default: none)
  }
}

/// The exemption reason (BT-120) of a VAT category: the plain text of its
/// grounds. The VAT groups of the line items state the note of the language
/// for the categories that need a reason (AE, K, G, O) when their items give
/// no grounds, and print it (see `calculate-taxes`); without any, it is taken
/// from `strings` the same way.
///
/// -> str | none
#let exemption-reason(category, grounds, strings: (:)) = {
  if category in _taxed-categories { return none }
  let reason = text-or-none(grounds)
  if reason != none { reason } else {
    text-or-none(default-grounds(category, strings))
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

// The invoice line period (BG-26) of an item: its date as a period of one
// day, or its period, as `(start, end)`; `none` without a date.
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

// An invoice line (BG-25) with net amounts.
// With gross prices, `round-price` rounds the net price as the invoice
// rounds unit prices (the `money-fine` rounding of the locale). `unit` is the
// unit of the item as `unit-resolver` resolves it, resolved here when `auto`.
#let line-model(
  item,
  index,
  inclusive: false,
  round-price: price => calc.round(price, digits: 4),
  unit: auto,
) = {
  let tax = item.at("tax", default: (:))
  if type(tax) != dictionary { tax = (:) }
  let rate = to-ratio(tax.at("rate", default: 0))

  let quantity = to-decimal(item.at("quantity", default: 1))
  let base-quantity = to-decimal(item.at("base-quantity", default: 1))
  let price = to-decimal(item.at("price", default: 0))
  if inclusive {
    price = round-price(price / (1 + rate))
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

  if unit == auto { unit = resolve-unit(item.at("unit", default: none)) }

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
    unit-code: unit.code,
    // A unit text without a known code, or a code that most likely means
    // something else (see `unit-resolver`).
    unit-issue: unit.issue,
    price: price,
    net: _net(to-decimal(item.at("total", default: 0)), rate, inclusive),
    key: _tax-key(tax),
    category: text-or-none(tax.at("category", default: none)),
    rate: rate,
    // No tax was set for the item (`tax: none`), see `tax.implicit-zero`.
    implicit: tax.at("implicit", default: false),
    allowances: allowances,
    charges: charges,
    // BT-127: the note of the item, with its line breaks.
    note: {
      let note = item.at("note", default: none)
      if note != none { note = plain-text(note, keep-newlines: true) }
      if note == "" { none } else { note }
    },
    // BG-26: the date or period of the item as `(start, end)`.
    period: _line-period(item.at("date", default: none)),
    // BT-159: the country of origin, an ISO 3166-1 code.
    origin: item.at("origin", default: none),
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

// --- Payment -------------------------------------------------------------------

// An identifier in upper case (IBAN, BIC, creditor identifier), or `none`.
#let _upper-id(value) = {
  let id = compact(value)
  if id == none { none } else { upper(id) }
}

// A payment means (BG-16) with its payment means code (BT-81), its kind (see
// `code-kind`) and the input it comes from, for messages. The details of a
// credit transfer (BG-17: `iban`, `account-name`, `bic`), a payment card
// (BG-18: `card`) and a direct debit (the debited account of BG-19,
// `debtor-iban`) are set by `payment-means-model`.
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

/// The payment means (BG-16) of the invoice, in the order of the XML: one for
/// each account of a credit transfer (`bank-details`, BG-17), the direct
/// debit, the payment card (BG-18), and the method of `paid` if none of them
/// details it (e.g. cash). An invoice has one kind of payment means; the
/// validator reports conflicting ones.
///
/// -> array
#let payment-means-model(means, currency) = {
  let entries = ()
  for bank in means.transfers {
    entries.push(
      _means(transfer-code(currency), "transfer", "bank-details")
        + (
          iban: _upper-id(bank.at("iban", default: none)),
          // Only an explicit name of `bank-details` (BT-85).
          account-name: text-or-none(bank.at("account-name", default: none)),
          bic: _upper-id(bank.at("bic", default: none)),
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

/// A cash discount in the Skonto syntax of XRechnung (BR-DE-18): the days,
/// the percentage with two decimals and the amount it applies to, if given,
/// e.g. "#SKONTO#TAGE=14#PROZENT=2.00#".
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

// Payment terms of several parts, each on a line of its own.
#let _terms-lines(first, lines) = {
  let parts = if first == none { () } else { (first,) }
  payment-terms((parts + lines).join("\n"))
}

/// The payment terms (BT-20) a profile states: XRechnung states cash
/// discounts in its Skonto syntax (`terms-xrechnung`, `none` if the terms
/// have none), the other profiles as the invoice prints them.
///
/// -> none | str
#let profile-terms(payment, profile) = {
  let xrechnung = payment.at("terms-xrechnung", default: none)
  if profile.xrechnung and xrechnung != none { xrechnung } else {
    payment.terms
  }
}

/// Builds the e-invoice data model from the root context and the computed
/// line item data.
///
/// `payment-means` are the payment means of the invoice as the root context
/// resolves them (see `logic/payment-means.typ`); without them, the bank
/// details `bank` are its only payment means.
///
/// -> dictionary
#let build-model(
  ctx,
  item-data,
  payment-goal: none,
  bank: none,
  payment-means: none,
) = {
  let sender = ctx.at("sender", default: (:))
  let recipient = ctx.at("recipient", default: (:))
  // The document type (BT-3), see `resolve-document-type`.
  let document = ctx.at("document-type", default: none)
  if type(document) != dictionary { document = resolve-document-type(auto) }
  // The buyer issues a self-billed invoice: the sender of the document is
  // the buyer and its recipient the seller. From here on, `sender` is the
  // seller and `recipient` the buyer.
  if document.self-billed { (sender, recipient) = (recipient, sender) }
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
  // Net prices of gross prices are rounded like every unit price of the
  // invoice: with the fine money rounding of the locale, so a locale that
  // keeps 6 decimals keeps them in the XML as well.
  let round-price = (
    ctx
      .at("locale", default: (:))
      .at("normalize", default: (:))
      .at("money-fine", default: none)
  )
  if type(round-price) != function {
    let digits = (
      ctx
        .at("locale", default: (:))
        .at("currency", default: (:))
        .at("decimals-fine", default: 4)
    )
    round-price = price => calc.round(price, digits: digits)
  }

  // BR-O-02: an invoice not subject to VAT carries no VAT identifiers. MINIMUM
  // has no VAT breakdown; there the seller VAT ID is needed for BR-CO-26.
  let categories = taxes.values().map(tax => tax.at("category", default: none))
  let outside-scope = profile.id != "minimum" and "O" in categories

  let seller = seller-model(sender, use-vat-id: not outside-scope)
  // What the printed invoice shows besides the components (see
  // `logic/printed.typ`): whether it shows the seller's VAT ID or tax number
  // the XML states (BT-31, BT-32), which the law requires on the invoice;
  // `none` if that cannot be known, e.g. with the blank theme.
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
  // BG-11 and BG-10: the parties besides seller and buyer, if any.
  let tax-representative = tax-representative-model(sender.at(
    "tax-representative",
    default: none,
  ))
  let payee = payee-model(ctx.at("payee", default: none))

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

  let resolve = unit-resolver()
  let lines = ()
  for (i, item) in items.enumerate() {
    lines.push(line-model(
      item,
      i,
      inclusive: inclusive,
      round-price: round-price,
      unit: resolve(item.at("unit", default: none)),
    ))
  }
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
      let codes = exemption-codes(tax.at("codes", default: ()))
      (
        key: key,
        category: category,
        rate: to-ratio(tax.at("rate", default: 0)),
        basis: to-decimal(tax.at("basis", default: 0)),
        amount: to-decimal(tax.at("absolute", default: 0)),
        reason: exemption-reason(
          category,
          tax.at("grounds", default: none),
          strings: ctx.at("locale", default: (:)).at("strings", default: (:)),
        ),
        // BT-121, and the codes the items give (for the validator).
        code: exemption-code(category, codes),
        codes: codes,
        // Some item of the group has no tax (`tax: none`).
        implicit: tax.at("implicit", default: false),
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
  let means = if payment-means != none { payment-means } else {
    resolve-payment-means(
      if bank != none { (bank,) } else { () },
      none,
      none,
      none,
    )
  }
  // An invoice that is paid already (`paid`) has the total as paid amount
  // (BT-113), prepayments included, so nothing is due (BT-115).
  let prepaid-total = if means.paid != none { gross-total } else {
    to-decimal(item-data.at("prepaid-total", default: 0))
  }

  let locale = ctx.at("locale", default: (:))
  let currency-meta = locale.at("currency", default: (:))
  let currency = currency-code(locale)
  // How the invoice prints an amount (`format.currency`) and a unit price
  // (`format.currency-fine`), to check that it prints the currency the XML
  // states (BT-5).
  let printed-currency = (
    symbol: text-or-none(currency-meta.at("symbol", default: none)),
  )
  for (name, key) in (("amount", "currency"), ("price", "currency-fine")) {
    let formatter = locale.at("format", default: (:)).at(key, default: none)
    printed-currency.insert(name, if type(formatter) == function {
      plain-text(formatter(decimal("1")))
    })
  }

  // The service period and the date format the invoice prints it with.
  let service-period = _service-period(ctx, items)
  let format-date = locale.at("format", default: (:)).at("date", default: none)
  let period-text = if type(format-date) == function {
    text-or-none(format-service-period(service-period, format-date))
  }
  let printed-period = _printed-service-period(ctx)

  // BT-9 and BT-20: the invoice's own `due-date` wins over the payment goal.
  // `terms-input` is the input the payment terms come from.
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
    // Without days or a date, the payment goal prints that the amount is due
    // at once ("sofort nach Erhalt"), which are the payment terms. On a
    // document whose sender pays (a credit note or a self-billed invoice),
    // it prints that the sender pays at once ("umgehend") instead.
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
  // The cash discounts of the payment goal follow the terms, each on a line
  // of its own: as the invoice prints them, and in XRechnung in its Skonto
  // syntax (BR-DE-18).
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
    // The input the currency comes from: the invoice's `currency`, or the
    // locale.
    currency-field: if ctx.at("currency", default: auto) == auto {
      "locale"
    } else { "currency" },
    // The decimals the amounts of the currency are rounded to.
    currency-decimals: currency-meta.at("decimals", default: 2),
    printed-currency: printed-currency,
    invoice: (
      number: text-or-none(_field(ctx, "invoice-nr")),
      type-code: document.code,
      // The resolved `document-type`, and the title printed on the document
      // (the subject without the invoice number), which must not name
      // another kind of document (IP-DOC-01).
      document: document,
      title: text-or-none(ctx.at("title", default: none)),
      issue-date: ctx.at("invoice-date", default: none),
      // A Leitweg-ID of the `id` module is stated without its scheme.
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
      // BT-26, a `datetime` or `none`.
      preceding-invoice-date: ctx.at("preceding-invoice-date", default: none),
      // BT-22 and BT-21: `(content: .., subject-code: ..)` each.
      notes: _notes(ctx.at("notes", default: ())),
      // BT-11: the project reference.
      project: text-or-none(ctx.at("project", default: none)),
    ),
    seller: seller,
    buyer: buyer,
    ship-to: ship-to,
    tax-representative: tax-representative,
    payee: payee,
    // The service period (BT-72 or BG-14), see `resolve-service-period` for
    // its `source`. `text` is how `references.service-time` prints it,
    // `printed` the text of the service period the invoice prints as a
    // reference, if any, `printed-own` whether that is a text of its own
    // rather than dates, and `shown` whether the printed invoice shows the
    // date of the supply at all (see `_period-shown`).
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
      // BG-16: the payment means and their details.
      means: payment-means-model(means, currency),
      // BG-19: the mandate reference (BT-89) and the creditor identifier
      // (BT-90) of a direct debit.
      mandate: if debit != none { _identifier(debit.mandate) },
      creditor-id: if debit != none { _upper-id(debit.creditor-id) },
      // The invoice is paid already (`paid`).
      paid: means.paid != none,
      due-date: due-date,
      // BT-20, and in XRechnung, if they differ, the terms with the cash
      // discounts in its Skonto syntax (see `profile-terms`).
      terms: terms,
      terms-xrechnung: terms-xrechnung,
      terms-input: terms-input,
      // The cash discounts of the payment goal: `days`, `percent` (in
      // percent) and `basis` (`none` if not given).
      discounts: discounts.map(discount => (
        days: discount.days,
        percent: discount.percent,
        basis: discount.basis,
      )),
    ),
  )
}
