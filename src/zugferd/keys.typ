// The known key an unknown party key most likely stands for (see
// `_input-keys` of model.typ), loaded only for the first unknown key.

#let _post-code-hint = "Write the post code into `city`, e.g. `city: \"10115 Berlin\"` or `city: (name: \"Berlin\", post-code: \"10115\")`."

// Other names of party keys (normalized): the key, or the key and a hint.
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
  // The legal registration identifier (BT-30, BT-47).
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

// Keys that look like misspellings ("fax-nr" of "tax-nr") but are none.
#let _other-keys = (
  fax-nr: true,
  fax-no: true,
  faxnr: true,
)

// Compiled on first use (memoized).
#let _key-patterns() = (
  camel-case: regex("([a-z0-9])([A-Z])"),
  separators: regex("[\\s_.-]+"),
  numbered: regex("[0-9]$"),
)

// A key in lower case with `-` between its words: "vat_id" is "vat-id".
#let _normalize-key(key) = {
  let patterns = _key-patterns()
  let key = key.replace(patterns.camel-case, m => (
    m.captures.at(0) + "-" + m.captures.at(1)
  ))
  lower(key).replace(patterns.separators, "-").trim("-")
}

// The optimal string alignment distance of `a` and `b`, at most `limit + 1`.
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

// The closest known key, preferring keys the e-invoice reads.
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

/// An input key a party does not know, with the known key it looks like
/// (`like`); a key ending in a number (e.g. "email2") is deliberate.
///
/// -> dictionary
#let unknown-key(key, known, path: none) = {
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
