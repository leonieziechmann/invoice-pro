// Normalizes the computed invoice into the data model of the e-invoice.
//
// Everything the XML contains is derived here exactly once: plain texts,
// identifiers, net amounts and totals. The validator checks this model and the
// builder serializes it, so both always agree on what ends up in the XML.

#import "xml.typ": plain-text
#import "codelists.typ"
#import "profile.typ": resolve-profile
#import "../utils/coercion.typ": to-decimal, to-ratio
#import "../data/tax.typ": default-grounds, to-tax-key
#import "../data/unit.typ": unit-db
#import "../locale/lang/lang.typ" as languages
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

// The plain text of an identifier without any whitespace (VAT IDs, IBANs).
#let compact(value) = {
  let result = plain-text(value).replace(regex("\\s"), "")
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
// keyed by the VAT ID prefix (Greece uses "EL").
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
/// -> none | dictionary
#let get-electronic-address(party, is-outside-scope: false) = {
  let explicit = party.at("electronic-address", default: none)
  if explicit != none {
    if type(explicit) == dictionary {
      return (
        scheme: compact(explicit.at("scheme", default: none)),
        id: compact(explicit.at("id", default: none)),
      )
    }
    let id = compact(explicit)
    let scheme = if id != none and id.contains("@") { "EM" } else { none }
    return (scheme: scheme, id: id)
  }

  // An invoice not subject to VAT carries no VAT identifiers (BR-O-02).
  let vat-id = if is-outside-scope { none } else {
    compact(party.at("vat-id", default: none))
  }
  if vat-id != none and vat-id.len() > 2 {
    // The prefix names the country that issued the VAT ID, and only that
    // country's scheme fits: a Danish VAT ID of a German company is no German
    // VAT endpoint. Without a scheme for the prefix, the email is used.
    let scheme = vat-eas-codes.at(upper(vat-id.slice(0, 2)), default: none)
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

// An identifier with an optional scheme, e.g. a GLN `(scheme: "0088", id: ..)`.
#let _scheme-id(value) = {
  if value == none { return none }
  if type(value) == dictionary {
    let id = compact(value.at("id", default: none))
    if id == none { return none }
    return (scheme: compact(value.at("scheme", default: none)), id: id)
  }
  let id = text-or-none(value)
  if id == none { none } else { (scheme: none, id: id) }
}

#let _address-model(party) = {
  let raw-lines = party.at("address-lines", default: ())
  let lines = if type(raw-lines) == array { raw-lines } else { (raw-lines,) }
  (
    lines: lines.map(text-or-none).filter(line => line != none),
    city: text-or-none(_field(party, "city-name")),
    post-code: text-or-none(_field(party, "post-code")),
    state: text-or-none(_field(party, "state")),
    country: country-code(party),
  )
}

// Seller, buyer or ship-to party. `vat-id` is the VAT identifier the party
// states; `use-vat-id: false` keeps it out of the XML (BR-O-02).
#let party-model(party, use-vat-id: true) = {
  if type(party) != dictionary { party = (:) }
  let vat-id = compact(party.at("vat-id", default: none))
  if vat-id != none { vat-id = upper(vat-id) }
  let id = text-or-none(party.at("id", default: none))
  let global-id = _scheme-id(party.at("global-id", default: none))
  // A global identifier without scheme is an ordinary identifier.
  if global-id != none and global-id.scheme == none {
    if id == none { id = global-id.id }
    global-id = none
  }
  (
    name: text-or-none(first-of(
      _field(party, "name-inline"),
      _field(party, "name"),
    )),
    id: id,
    global-id: global-id,
    vat-id: if use-vat-id { vat-id } else { none },
    stated-vat-id: vat-id,
    tax-nr: text-or-none(party.at("tax-nr", default: none)),
    address: _address-model(party),
    electronic-address: get-electronic-address(
      party,
      is-outside-scope: not use-vat-id,
    ),
    contact: contact-model(party),
  )
}

// The seller (BG-4). Without an own identifier (BT-29) or a VAT identifier
// (BT-31) in the XML, the tax number identifies the seller (BR-CO-26).
#let seller-model(party, use-vat-id: true) = {
  let seller = party-model(party, use-vat-id: use-vat-id)
  if seller.id == none and seller.global-id == none and seller.vat-id == none {
    seller.id = seller.tax-nr
  }
  seller
}

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
/// it: `build-model` builds it once for all lines.
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

/// The UN/ECE Recommendation 20 code of a unit (BT-130, BT-150):
/// `(code: .., issue: ..)`.
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
/// - aliases (auto, dictionary): The table of `unit-aliases`, built when
///   `auto`; pass it when resolving many units.
/// -> dictionary
#let resolve-unit(unit, aliases: auto) = {
  if type(unit) == dictionary {
    let code = compact(unit.at("code", default: none))
    if code != none { return (code: code, issue: none) }
    unit = unit.at("display", default: none)
  }
  let text = plain-text(unit)
  if text == "" { return (code: "C62", issue: none) }
  // A unit written exactly as a code; case-sensitive, so that "min" is not
  // looked up as the code "MIN" but as an abbreviation (which gives the same).
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
  if aliases == auto { aliases = unit-aliases() }
  let key = lower(text).trim(".", at: end)
  let code = aliases.at(key, default: none)
  // A plural with "s" ("heures", "kgs"), but not "ms" for "m".
  if code == none and key.ends-with("s") and key.clusters().len() > 2 {
    code = aliases.at(key.slice(0, -1), default: none)
  }
  if code != none { return (code: code, issue: none) }
  (code: "C62", issue: (kind: "unknown", text: text))
}

/// The UN/ECE Recommendation 20 code of a unit, see `resolve-unit`.
///
/// -> str
#let map-unit-code(unit, aliases: auto) = (
  resolve-unit(unit, aliases: aliases).code
)

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

// Categories whose VAT breakdown must not carry an exemption reason
// (BR-S-10, BR-Z-10, BR-AF-10, BR-AG-10).
#let _taxed-categories = ("S", "Z", "L", "M")

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

// An invoice line (BG-25) with net amounts.
// With gross prices, `round-price` rounds the net price as the invoice
// rounds unit prices (the `money-fine` rounding of the locale). `unit-aliases`
// is the table of the function `unit-aliases`, built when `auto`.
#let line-model(
  item,
  index,
  inclusive: false,
  round-price: price => calc.round(price, digits: 4),
  unit-aliases: auto,
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

  let unit = resolve-unit(
    item.at("unit", default: none),
    aliases: unit-aliases,
  )

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
    // something else (see `resolve-unit`).
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
  let buyer = party-model(recipient, use-vat-id: not outside-scope)

  let delivery-party = ctx.at("delivery-address", default: none)
  let ship-to = if type(delivery-party) == dictionary {
    let party = party-model(delivery-party, use-vat-id: false)
    // `location-id` is an alias of the deliver to location identifier (BT-71).
    party.id = first-of(
      party.id,
      text-or-none(delivery-party.at("location-id", default: none)),
    )
    party
  } else if "K" in categories and buyer.address.country != none {
    // BR-IC-12: an intra-community supply names the deliver-to country;
    // without a delivery address, the goods go to the buyer.
    (name: none, id: none, global-id: none, address: buyer.address)
  } else { none }

  let aliases = unit-aliases()
  let lines = items
    .enumerate()
    .map(((i, item)) => line-model(
      item,
      i,
      inclusive: inclusive,
      round-price: round-price,
      unit-aliases: aliases,
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
        reason: exemption-reason(
          category,
          tax.at("grounds", default: none),
          strings: ctx.at("locale", default: (:)).at("strings", default: (:)),
        ),
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
  let prepaid-total = to-decimal(item-data.at("prepaid-total", default: 0))

  let locale = ctx.at("locale", default: (:))
  let currency-meta = locale.at("currency", default: (:))
  let currency = compact(currency-meta.at("code", default: none))
  if currency != none { currency = upper(currency) }
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

  let iban = if bank != none { compact(bank.at("iban", default: none)) }
  let bic = if bank != none { compact(bank.at("bic", default: none)) }

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
    // at once ("sofort nach Erhalt"), which are the payment terms.
    if terms == none and due-date == none and goal-date == none {
      terms = payment-terms(
        locale
          .at("strings", default: (:))
          .at("payment", default: (:))
          .at("deadline-soon", default: none),
      )
      if terms != none { terms-input = "payment-goal" }
    }
  }

  (
    profile: profile,
    tax-mode: tax-mode,
    outside-scope: outside-scope,
    currency: currency,
    printed-currency: printed-currency,
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
      terms-input: terms-input,
    ),
  )
}
