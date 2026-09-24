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
#import "xml.typ": fmt-number, rate-digits
#import "model.typ": profile-terms, vat-eas-codes, vat-id-country, vat-id-prefix
#import "document.typ": note-subject-code-valid, title-kind
#import "../utils/iban.typ": format-iban, iban-valid
#import "../utils/creditor-id.typ": creditor-id-valid

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
// The highest total of a small-amount invoice in euros, which needs fewer
// details (§ 33 UStDV).
#let _small-amount = decimal("250")

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
  // The invoice's `currency`, or the locale.
  let currency-field = model.at("currency-field", default: "locale")
  if model.currency == none {
    out.push(error(
      "BR-05",
      "locale",
      "The invoice currency code (BT-5) is missing.",
      hint: "Set `currency` on the invoice, e.g. `currency: \"EUR\"`, or use a locale that defines `currency.code`, e.g. `locale.de-de`.",
    ))
  } else if model.currency not in codelists.currencies {
    out.push(error(
      "BR-CL-04",
      currency-field,
      "The invoice currency code (BT-5) "
        + _quoted(model.currency)
        + " is not an ISO 4217 code.",
      hint: if currency-field == "currency" {
        "Set `currency` to an ISO 4217 code such as \"EUR\" or \"USD\"."
      } else {
        "Use a currency code such as \"EUR\" or \"CHF\" in the locale, or set `currency` on the invoice."
      },
    ))
  } else if (
    model.profile.en16931
      and model.currency in codelists.cen-rejected-currencies
  ) {
    out.push(error(
      "BR-CL-04",
      currency-field,
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
        hint: "Set `currency` on the invoice to the printed currency, e.g. `currency: \"PLN\"`, or the currency of the locale's region, e.g. `currency: (code: \"PLN\", symbol: \"zł\")` in a region builder; the amounts are then printed with its symbol.",
      ))
      break
    }
  }
  out
}

// --- Document type --------------------------------------------------------

// What a title names that is no invoice at all, for IP-DOC-01.
#let _no-invoice = (
  quote: "a quote",
  delivery-note: "a delivery note",
  order: "an order",
  pro-forma: "a pro forma invoice",
  reminder: "a payment reminder",
)

// The document types XRechnung allows (BR-DE-17).
#let _xrechnung-type-codes = (
  "326": true,
  "380": true,
  "381": true,
  "384": true,
  "389": true,
  "875": true,
  "876": true,
  "877": true,
)

// IP-DOC-01: the title of a document without `document-type` names another
// kind of document than the invoice (BT-3 = 380) the e-invoice states, e.g.
// "Gutschrift": the e-invoice would ask the buyer to pay a credit note.
#let _check-title(invoice) = {
  let document = invoice.document
  if document.input != auto { return () }
  let named = title-kind(invoice.title)
  if named == none or named.kind == "invoice" { return () }
  let title = _quoted(invoice.title)
  let as-invoice = "or `document-type: \"invoice\"` if it is an invoice."
  let (message, hint) = if named.kind in _no-invoice {
    (
      "The subject "
        + title
        + " names "
        + _no-invoice.at(named.kind)
        + ", which is no invoice, but the e-invoice states a commercial invoice (BT-3 = "
        + document.code
        + ").",
      "Do not set `zugferd` for quotes, delivery notes, orders, pro forma invoices or payment reminders: an e-invoice is only written for invoices and credit notes. Set `document-type: \"invoice\"` if it is an invoice.",
    )
  } else if named.kind == "corrected" {
    (
      "The subject "
        + title
        + " names a corrected invoice, but the e-invoice states a new commercial invoice (BT-3 = "
        + document.code
        + "), which the buyer would book and pay a second time.",
      "Set `document-type: \"corrected\"` (384) and `preceding-invoice-nr` to the invoice it replaces, `document-type: \"credit-note\"` (381) for a credit note, "
        + as-invoice,
    )
  } else if named.kind == "self-billed" {
    (
      "The subject "
        + title
        + " names a self-billed invoice, but the e-invoice states a commercial invoice of the sender (BT-3 = "
        + document.code
        + ").",
      "Set `document-type: \"self-billed\"` (389): the sender is then the buyer, who issues the invoice, and the recipient the seller. Set `document-type: \"invoice\"` if it is an invoice.",
    )
  } else {
    (
      "The subject "
        + title
        + " names a credit note"
        + if named.kind == "credit-note-or-self-billed" {
          " or a self-billed invoice"
        }
        + ", but the e-invoice states a commercial invoice (BT-3 = "
        + document.code
        + "), which asks the buyer to pay.",
      "Set `document-type: \"credit-note\"` (381) for a credit note and enter the credited items with positive prices, "
        + if named.kind == "credit-note-or-self-billed" {
          "`document-type: \"self-billed\"` (389) for a self-billed invoice (which German VAT law calls \"Gutschrift\"), "
        } else {
          // "Rechnungskorrektur" and the like also name a corrected invoice.
          "`document-type: \"corrected\"` (384) for an invoice that replaces the preceding one, "
        }
        + as-invoice,
    )
  }
  (error("IP-DOC-01", "subject", message, hint: hint),)
}

/// Checks the document type (BT-3): that the title of the document does not
/// name another kind of document (IP-DOC-01), that the profile allows the
/// type (BR-DE-17), and that the amounts have the sign of the type.
///
/// -> array
#let check-document-type(model) = {
  let invoice = model.invoice
  let document = invoice.at("document", default: none)
  if type(document) != dictionary { return () }
  let out = _check-title(invoice)
  let code = invoice.type-code

  // XRechnung only warns about BR-DE-17, but validators such as Mustang
  // reject the invoice, so invoice-pro reports an error.
  if model.profile.xrechnung and code not in _xrechnung-type-codes {
    out.push(error(
      "BR-DE-17",
      "document-type",
      "XRechnung does not allow the document type "
        + _quoted(code)
        + " (BT-3), only 326, 380, 381, 384, 389, 875, 876 and 877.",
      hint: if code == "386" {
        "XRechnung has no prepayment invoice: state the advance payment as an invoice (`document-type: \"invoice\"`) or a partial invoice (`document-type: \"326\"`), or use the \"en16931\" profile (as `zugferd: auto` does)."
      } else {
        "Use one of these document types, or the \"en16931\" profile (as `zugferd: auto` does)."
      },
    ))
  }

  // The preceding invoice reference (BG-3), from BASIC WL on: its number
  // (BT-25) is required (BR-55), and a corrected invoice replaces the
  // invoice it names. A document that amends an invoice must refer to it
  // (Art. 219 of the VAT Directive), which XRechnung checks as BR-DE-26.
  // XRechnung only warns about BR-DE-26, but validators such as Mustang
  // reject the invoice.
  if model.profile.document-references {
    let number = invoice.at("preceding-invoice-nr", default: none)
    if (
      number == none
        and invoice.at("preceding-invoice-date", default: none) != none
    ) {
      out.push(error(
        "BR-55",
        "preceding-invoice-nr",
        "The date of the preceding invoice (BT-26) is given, but not its number (BT-25), which a preceding invoice reference must have.",
        hint: "Set `preceding-invoice-nr` on the invoice.",
      ))
    } else if number == none and code == "384" {
      out.push(error(
        if model.profile.xrechnung { "BR-DE-26" } else { "IP-DOC-02" },
        "preceding-invoice-nr",
        "A corrected invoice (BT-3 = "
          + code
          + ") replaces a preceding invoice, but it names none (BG-3).",
        hint: "Set `preceding-invoice-nr` (and `preceding-invoice-date`) to the invoice it corrects.",
      ))
    }
  }

  // A credit note states the credited amounts as positive amounts: a
  // negative credit note asks the buyer to pay (IP-DOC-03). An invoice with
  // a negative total is valid, but a credit note is the document for it.
  let gross = model.totals.gross
  if document.credit and gross < _zero {
    out.push(error(
      "IP-DOC-03",
      "line-items",
      "A credit note (BT-3 = "
        + code
        + ") states the credited amounts as positive amounts, but its total is "
        + fmt-number(gross)
        + ", which would ask the buyer to pay "
        + fmt-number(-gross)
        + ".",
      hint: "Enter the credited items with positive prices: the document type already says that the amounts are credited to the buyer.",
    ))
  } else if not document.credit and gross < _zero {
    out.push(warning(
      "IP-DOC-04",
      "line-items",
      "The total is negative ("
        + fmt-number(gross)
        + "), but the document type "
        + _quoted(code)
        + " (BT-3) is no credit note: the e-invoice asks the buyer to pay a negative amount.",
      hint: "For a credit, set `document-type: \"credit-note\"` and enter the credited items with positive prices.",
    ))
  }
  out
}

// --- Document data --------------------------------------------------------

/// Checks the data of the document besides its type: the notes (BT-21,
/// BT-22), the project reference (BT-11), and that the service period the
/// invoice prints is the one the XML states (IP-PERIOD-01).
///
/// -> array
#let check-document-data(model) = {
  let out = ()
  let profile = model.profile

  // The notes are printed in any case, but only BASIC WL and the richer
  // profiles can state them.
  let notes = model.invoice.at("notes", default: ())
  if notes.len() > 0 and not profile.notes {
    out.push(warning(
      "IP-PROFILE-01",
      "notes",
      "The "
        + profile.name
        + " profile has no invoice notes (BT-22), so `notes` are printed, but not written into the e-invoice.",
      hint: "Use the \"basic-wl\" profile or a richer one to state them.",
    ))
  }
  // The project reference (BT-11) exists in EN 16931 and XRechnung only.
  if (
    model.invoice.at("project", default: none) != none
      and not profile.procuring-project
  ) {
    out.push(warning(
      "IP-PROFILE-01",
      "project",
      "The "
        + profile.name
        + " profile has no project reference (BT-11), so `project` is not written into the e-invoice.",
      hint: "Use the \"en16931\" or \"xrechnung\" profile to state it.",
    ))
  }
  // MINIMUM states neither the service period (BT-72, BG-14) nor the
  // preceding invoice (BG-3), which exist from BASIC WL on.
  if (
    not profile.settlement
      and model.at("delivery", default: (:)).at("source", default: none)
        == "invoice"
  ) {
    out.push(warning(
      "IP-PROFILE-01",
      "service-period",
      "The "
        + profile.name
        + " profile has no service period (BT-72, BG-14), so `service-period` is not written into the e-invoice.",
      hint: "Use the \"basic-wl\" profile or a richer one to state it.",
    ))
  }
  if not profile.document-references {
    let given = ()
    for key in ("preceding-invoice-nr", "preceding-invoice-date") {
      if model.invoice.at(key, default: none) != none { given.push(key) }
    }
    if given.len() > 0 {
      out.push(warning(
        "IP-PROFILE-01",
        given.first(),
        "The "
          + profile.name
          + " profile has no preceding invoice reference (BG-3), so "
          + given.map(key => "`" + key + "`").join(" and ")
          + if given.len() == 1 { " is" } else { " are" }
          + " not written into the e-invoice.",
        hint: "Use the \"basic-wl\" profile or a richer one to state it.",
      ))
    }
  }
  if profile.notes {
    for note in notes {
      let code = note.subject-code
      if code != none and not note-subject-code-valid(code) {
        out.push(error(
          "BR-CL-08",
          "notes",
          "The subject code "
            + _quoted(code)
            + " of a note (BT-21) is not a code of UNTDID 4451.",
          hint: "Use a code such as \"AAI\" (general information), \"REG\" (regulatory information), \"TXD\" (tax declaration) or \"SUR\" (supplier remarks), or leave out `subject-code`.",
        ))
      }
    }
  }

  // IP-PERIOD-01: the service period the invoice prints is the one the XML
  // states (BT-72 or BG-14). Another date or period (e.g.
  // `references.service-time(value: datetime(..))`) contradicts it, and so
  // does a text of its own (e.g. `references.service-time(value: "Juni
  // 2026")`) when the XML states the invoice date for want of any date. A
  // text of its own besides dates of the items or the invoice's
  // `service-period` may name the same period in other words: a warning.
  // The delivery information exists from BASIC WL on.
  let delivery = model.at("delivery", default: (:))
  let printed = delivery.at("printed", default: none)
  let stated = delivery.at("text", default: none)
  let source = delivery.at("source", default: none)
  let term = if delivery.at("period", default: none) != none { "BG-14" } else {
    "BT-72"
  }
  if (
    profile.settlement
      and printed != none
      and stated != none
      and printed != stated
  ) {
    let own = delivery.at("printed-own", default: true)
    let contradicts = not own or source == "invoice-date"
    let report = if contradicts { error } else { warning }
    out.push(report(
      "IP-PERIOD-01",
      "references",
      "The invoice prints the service period "
        + _quoted(printed)
        + if contradicts { "" } else { " as a text of its own" }
        + ", but the e-invoice states "
        + _quoted(stated)
        + " ("
        + term
        + ")"
        + if source == "invoice-date" {
          ", the invoice date, as no item has a date"
        } else if source == "items" { ", from the dates of the items" }
        + if contradicts { "." } else {
          ". Make sure that both name the same period."
        },
      hint: "Set `service-period` on the invoice, e.g. `service-period: (datetime(year: 2026, month: 6, day: 1), datetime(year: 2026, month: 6, day: 30))`, and print it with `references.service-time()` without `value`, which prints the service period of the e-invoice.",
    ))
  }

  // IP-PERIOD-03: the invoice prints the date of the supply: by its
  // references, with the dates of the items or in its text (see
  // `_period-shown` of the model). German law requires it on
  // every invoice, also when it is the date of the invoice (§ 14 Abs. 4
  // Satz 1 Nr. 6 UStG, UStAE 14.5 Abs. 16), except on a small-amount invoice
  // of at most 250 euros that is no intra-community supply or reverse charge
  // (§ 33 UStDV); the VAT Directive where it differs from the date of the
  // invoice (Art. 226 No. 7). A credit note amends an invoice that states
  // it. Only known for a theme that prints the references (e.g. DIN 5008),
  // not for the blank theme.
  let document = model.invoice.at("document", default: none)
  let credit = (
    type(document) == dictionary and document.at("credit", default: false)
  )
  if delivery.at("shown", default: none) == false and not credit {
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
      out.push(error(
        "IP-PERIOD-03",
        "references",
        "The printed invoice does not show the date of the supply"
          + if profile.settlement and stated != none {
            " (" + _quoted(stated) + " in the e-invoice, " + term + ")"
          }
          + ", which German law requires on the invoice, also when it is the date of the invoice (§ 14 Abs. 4 Satz 1 Nr. 6 UStG).",
        hint: "Print it with `references.service-time()`, which the default `references` and every preset include, and set `service-period` if the supply was not on the date of the invoice.",
      ))
    } else if profile.settlement and stated != none and differs {
      out.push(warning(
        "IP-PERIOD-03",
        "references",
        "The e-invoice states the date of the supply "
          + _quoted(stated)
          + " ("
          + term
          + "), which is not the date of the invoice, but the printed invoice does not show it"
          + if small-amount {
            " (a small-amount invoice of at most 250 euros need not show it, § 33 UStDV)."
          } else { " (Art. 226 No. 7 of the VAT Directive)." },
        hint: "Print it with `references.service-time()`, which every preset includes.",
      ))
    }
  }
  out
}

// --- Parties --------------------------------------------------------------

// Hints for country codes that are missing from the code list of EN 16931.
#let _country-hints = (
  EL: "Use \"GR\" (`country.gr`) for Greece; \"EL\" is only the prefix of Greek VAT identifiers.",
  SS: "South Sudan (SS) is missing from the code list the EN 16931 validators apply, so only the \"minimum\" and \"basic-wl\" profiles can state it.",
  UK: "Use \"GB\" (`country.uk`) for the United Kingdom.",
)

// `en16931`: whether the profile is checked with the rules of EN 16931. Its
// code list lacks South Sudan ("SS"), which the Factur-X profiles MINIMUM and
// BASIC WL accept.
#let _check-country(code, rule, field, term, en16931) = {
  if code == none {
    return (
      error(
        rule,
        field,
        "The " + term + " is missing.",
        hint: "Set `country` on the "
          + field.split(".").first()
          + ", e.g. `country: country.de` or `country: \"DE\"`.",
      ),
    )
  }
  if code not in codelists.countries and (code != "SS" or en16931) {
    return (
      error(
        "BR-CL-14",
        field,
        "The "
          + term
          + " "
          + _quoted(code)
          + " is not in the ISO 3166-1 code list of EN 16931.",
        hint: _country-hints.at(
          code,
          default: "Use a country of the `country` module (e.g. `country.de`), an ISO code (e.g. \"DE\") or `country.custom(code: ..)`.",
        ),
      ),
    )
  }
  ()
}

// A party without `country` is in the country of the locale. If the VAT ID it
// states was issued by another country, that default is most likely wrong. An
// explicit `country` always settles it, e.g. for a foreign VAT registration.
#let _check-country-of-vat-id(party, field, term, bt) = {
  let address = party.address
  if (
    address.at("country-explicit", default: true) or address.country == none
  ) { return () }
  let vat-id = party.at("stated-vat-id", default: party.vat-id)
  let issuer = vat-id-country(vat-id)
  if issuer == none or issuer == address.country { return () }
  (
    error(
      "IP-COUNTRY-01",
      field + ".country",
      "The "
        + term
        + " country ("
        + bt
        + ") is not stated and defaults to "
        + _quoted(address.country)
        + ", the country of the locale, but the "
        + term
        + " VAT identifier "
        + _quoted(vat-id)
        + " was issued by "
        + _quoted(issuer)
        + ".",
      hint: "Set `country` on the "
        + field
        + ", e.g. `country: "
        + _quoted(issuer)
        + "`.",
    ),
  )
}

// Patterns of rare checks, compiled once on first use.
#let _post-code-digits() = regex("[0-9]{3,}")
// XR-TELEPHONE-REGEX (three digits, BR-DE-27) and XR-EMAIL-REGEX (BR-DE-28)
// of the XRechnung 3.0 Schematron.
#let _xr-patterns() = (
  digit: regex("[0-9]"),
  email: regex(
    "^[a-zA-Z0-9!#$%&\"*+/=?^_`{|}~-]+(\\.[a-zA-Z0-9!#$%&\"*+/=?^_`{|}~-]+)*@([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\\.)+[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$",
  ),
)

// A city line whose post code the parser of the party's country does not
// recognize stays whole: the post code is missing, and the number is written
// into the city name.
#let _check-post-code(party, field, term, city-bt, code-bt) = {
  let address = party.address
  if (
    address.post-code != none
      or address.city == none
      or address.country == none
      or address.city.match(_post-code-digits()) == none
  ) { return () }
  (
    error(
      "IP-ADDR-01",
      field + ".city",
      "The "
        + term
        + " city "
        + _quoted(address.city)
        + " contains a number, but no post code in the format of "
        + _quoted(address.country)
        + ": the post code ("
        + code-bt
        + ") would be missing, and the number would be written into the city name ("
        + city-bt
        + ").",
      hint: "Write the post code as the country expects it (e.g. \"1012 AB Amsterdam\"; `country.custom(code: .., post-code: \"999-9999\")` sets the format of other countries), check `country` on the "
        + field
        + ", or pass the parts, e.g. `city: (name: \"Amsterdam\", post-code: \"1012 AB\")`.",
    ),
  )
}

// `rules`: the rule for a missing address and the rule for a missing scheme.
// `represented`: the party is a seller with a tax representative, whose VAT
// identifier is not the seller's `vat-id` (nor its address).
#let _check-electronic-address(
  party,
  required,
  rules,
  field,
  term,
  represented: false,
) = {
  let (missing-rule, scheme-rule) = rules
  let address = party.electronic-address
  if address == none or address.id == none {
    if required == none { return () }
    let make = if required == "error" { error } else { warning }
    // Name only the inputs that can still provide the address.
    let vat-id = party.at("stated-vat-id", default: none)
    let hint = if vat-id == none and represented {
      (
        "Set `electronic-address`, `vat-id` (the seller's own VAT identifier, not the one of its tax representative) or `email` on the "
          + field
          + "."
      )
    } else if vat-id == none {
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
    // A Peppol participant identifier such as "0088:4000001123452" (also
    // with the prefix "iso6523-actorid-upis::") carries its scheme in front
    // of the identifier.
    let (scheme, id) = ("0088", address.id)
    let parts = address.id.split(":")
    if (
      parts.len() >= 2 and parts.at(-2) in codelists.eas and parts.last() != ""
    ) {
      (scheme, id) = (parts.at(-2), parts.last())
    }
    return (
      error(
        scheme-rule,
        field + ".electronic-address",
        "The "
          + term
          + " "
          + _quoted(address.id)
          + " has no scheme identifier.",
        hint: "Give the address with its scheme, e.g. `electronic-address: (scheme: "
          + _quoted(scheme)
          + ", id: "
          + _quoted(id)
          + ")`"
          + if scheme == "0088" and id == address.id { " for a GLN" }
          + ", or give an email address.",
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

// Keys of a party dictionary that the party does not know (see `input-keys`
// of the model). A misspelled key the e-invoice reads is an error, as its value
// would be missing without notice; any other unknown key is a warning, as its
// value is not written into the e-invoice.
#let _check-input-keys(party, field, term) = {
  let out = ()
  for entry in party.at("input-keys", default: ()) {
    let owner = if entry.within == none { "the " + term } else {
      "`" + entry.within + "`"
    }
    if entry.einvoice and entry.like == none {
      // A key of an identifier dictionary that has no `id`.
      out.push(error(
        "IP-KEY-02",
        field + "." + entry.path,
        "`"
          + entry.key
          + "` is not a key of "
          + owner
          + ", which has no `id`, so the identifier is missing from the e-invoice.",
        hint: "Give the identifier as `(scheme: .., id: ..)`.",
      ))
    } else if entry.einvoice {
      out.push(error(
        "IP-KEY-02",
        field + "." + entry.path,
        "`"
          + entry.key
          + "` is not a key of "
          + owner
          + ". It looks like `"
          + entry.like
          + "`, so its value is missing from the e-invoice.",
        hint: if entry.hint != none { entry.hint } else {
          "Rename it to `" + entry.like + "`."
        },
      ))
    } else {
      out.push(warning(
        "IP-KEY-01",
        field + "." + entry.path,
        "`"
          + entry.key
          + "` is not a key of "
          + owner
          + ", so its value is not written into the e-invoice.",
        hint: if entry.hint != none { entry.hint } else if entry.like != none {
          "Did you mean `" + entry.like + "`?"
        } else {
          "Check the spelling of the key, or keep it if only the printed invoice uses it (e.g. through `info.dynamic`)."
        },
      ))
    }
  }
  out
}

// What an identifier of each kind of the `id` module identifies, for messages.
#let _id-kinds = (
  party: "a party identifier",
  legal: "a legal registration identifier",
  routing: "a Leitweg-ID",
  custom: "an identifier",
)

// The typed identifiers of the `id` module a party gives (`typed-ids` of the
// model): their problems (IP-ID-01, e.g. a wrong check digit), and an
// identifier given for a business term it does not belong to (IP-ID-03): a
// Leitweg-ID as party identifier, another identifier as Leitweg-ID, a GLN or
// D-U-N-S number as legal registration identifier, or a register number as
// party identifier.
#let _check-typed-ids(party, field, term) = {
  let out = ()
  for entry in party.at("typed-ids", default: ()) {
    let path = field + "." + entry.key
    let scheme = entry.scheme
    for problem in entry.problems {
      out.push(error(
        "IP-ID-01",
        path,
        if type(problem) == str { problem } else { repr(problem) },
        hint: if entry.kind == "custom" {
          "Give the code of the scheme and the identifier, e.g. `id.custom(\"0208\", \"0123456749\")`."
        } else if scheme == none {
          "Give the register number, e.g. `id.register(\"HRB 4711\", court: \"Amtsgericht München\")`."
        } else {
          (
            "Check the identifier for typos. If it is right as it is, give it with `id.custom("
              + _quoted(scheme)
              + ", ..)`, which does not check it."
          )
        },
      ))
    }
    if (
      entry.kind == "routing"
        and entry.key in ("id", "global-id", "location-id", "legal-id")
    ) {
      out.push(error(
        "IP-ID-03",
        path,
        "A Leitweg-ID says where a public buyer receives its invoices; it does not identify the "
          + term
          + ", which `"
          + entry.key
          + "` stands for.",
        hint: "Give the Leitweg-ID as `leitweg-id` of the recipient (the buyer reference, BT-10) and, if the buyer is reached by it, as its `electronic-address`.",
      ))
    } else if (
      entry.key == "leitweg-id" and entry.kind not in ("routing", "custom")
    ) {
      out.push(error(
        "IP-ID-03",
        path,
        "`leitweg-id` takes the Leitweg-ID of the buyer, but it is given "
          + _id-kinds.at(entry.kind, default: "another identifier")
          + ".",
        hint: "Give the Leitweg-ID with `id.leitweg(..)`, and the identifier of the buyer as `id`, `global-id` or `legal-id`.",
      ))
    } else if entry.key == "legal-id" and entry.kind == "party" {
      out.push(error(
        "IP-ID-03",
        path,
        "The identifier of the scheme "
          + _quoted(scheme)
          + " identifies a company or a location, but no official registrar issues it, so it is no legal registration identifier of the "
          + term
          + ".",
        hint: "Give it as `global-id` (the "
          + term
          + " identifier), or with `id.custom("
          + _quoted(scheme)
          + ", ..)` if it is the registration the "
          + term
          + " is known by.",
      ))
    } else if (
      entry.kind == "legal"
        and scheme == none
        and entry.key in ("id", "global-id", "location-id")
    ) {
      out.push(error(
        "IP-ID-03",
        path,
        "A register number is the legal registration identifier of the "
          + term
          + ", not its identifier, which `"
          + entry.key
          + "` stands for.",
        hint: if field == "delivery-address" {
          "The deliver-to location has no legal registration identifier: give its location identifier, e.g. `id.gln(..)`."
        } else { "Give it as `legal-id`." },
      ))
    }
  }
  out
}

// BR-CL-11: the scheme of a legal registration identifier (BT-30, BT-47,
// BT-61) is an ISO/IEC 6523 ICD code. Without a scheme it is stated as it is.
#let _check-legal-id(party, field, term, bt) = {
  let legal-id = party.at("legal-id", default: none)
  if (
    legal-id == none
      or legal-id.scheme == none
      or legal-id.scheme in codelists.icd
  ) { return () }
  (
    error(
      "BR-CL-11",
      field + ".legal-id",
      "The scheme "
        + _quoted(legal-id.scheme)
        + " of the "
        + term
        + " legal registration identifier ("
        + bt
        + ") is not an ISO/IEC 6523 code.",
      hint: "Use the constructor of the `id` module for the register, e.g. `id.siret(..)`, `id.register(..)` for a register without a scheme, or `id.custom(..)` with the ICD code of the register, e.g. \"0208\" for a Belgian enterprise number.",
    ),
  )
}

// An input the profile has no business term for is not written into the
// e-invoice: `lowest` is the lowest profile that states it.
#let _not-carried(profile, field, term, lowest) = warning(
  "IP-PROFILE-01",
  field,
  "The "
    + profile.name
    + " profile cannot state "
    + term
    + ", so `"
    + field
    + "` is not written into the e-invoice.",
  hint: "Use the " + _quoted(lowest) + " profile or higher to state it.",
)

// The seller tax representative (BG-11): its name (BR-18), country (BR-20)
// and VAT identifier (BR-56, BR-CO-09), and the address the VAT Directive
// requires on the invoice (Art. 226 No. 15). An invoice not subject to VAT
// states no VAT identifiers, so it cannot name a tax representative (BR-O-02).
#let _check-tax-representative(model) = {
  let representative = model.at("tax-representative", default: none)
  if representative == none { return () }
  let profile = model.profile
  let field = "sender.tax-representative"
  let out = _check-input-keys(representative, field, "tax representative")
  if not profile.tax-representative {
    out.push(_not-carried(
      profile,
      field,
      "the seller tax representative (BG-11)",
      "basic-wl",
    ))
    return out
  }
  if model.outside-scope {
    out.push(error(
      "BR-O-02",
      field,
      "An invoice not subject to VAT (O) states no VAT identifiers, so it cannot name the seller tax representative (BG-11), whose VAT identifier (BT-63) it would have to state (BR-56).",
      hint: "Leave out `tax-representative` on invoices of items not subject to VAT.",
    ))
  }
  if representative.name == none {
    out.push(error(
      "BR-18",
      field + ".name",
      "The name of the seller tax representative (BT-62) is missing.",
      hint: "Set `name` on the tax representative.",
    ))
  }
  if representative.vat-id == none {
    out.push(error(
      "BR-56",
      field + ".vat-id",
      "The VAT identifier of the seller tax representative (BT-63) is missing.",
      hint: "Set `vat-id` on the tax representative, the VAT identifier it holds for the seller, e.g. `vat-id: \"DE123456789\"`.",
    ))
  } else {
    out += _check-vat-id-prefix(representative.vat-id, field + ".vat-id")
  }
  out += _check-country(
    representative.address.country,
    "BR-20",
    field + ".country",
    "tax representative country code (BT-69)",
    profile.en16931,
  )
  out += _check-country-of-vat-id(
    representative,
    field,
    "tax representative",
    "BT-69",
  )
  if (
    representative.address.lines == () and representative.address.city == none
  ) {
    out.push(error(
      "IP-VAT-226",
      field + ".address",
      "The postal address of the seller tax representative (BG-12) is missing, which the invoice must state by law (Art. 226 No. 15 of the VAT Directive 2006/112/EC).",
      hint: "Set `address` and `city` on the tax representative.",
    ))
  }
  out += _check-post-code(
    representative,
    field,
    "tax representative",
    "BT-66",
    "BT-67",
  )
  out
}

// The payee (BG-10): it is named only when it is not the seller (BR-17), with
// one identifier (CII-SR-451) of a known scheme (BR-CL-10, BR-CL-11).
#let _check-payee(model) = {
  let payee = model.at("payee", default: none)
  if payee == none { return () }
  let profile = model.profile
  let field = "payee"
  let out = _check-input-keys(payee, field, "payee")
  out += _check-typed-ids(payee, field, "payee")
  if not profile.payee {
    out.push(_not-carried(profile, field, "the payee (BG-10)", "basic-wl"))
    return out
  }
  let seller = model.seller
  let seller-legal-id = seller.at("legal-id", default: none)
  if payee.name == none {
    out.push(error(
      "BR-17",
      field + ".name",
      "The name of the payee (BT-59) is missing.",
      hint: "Set `name` on the payee, e.g. the name of the factoring company that receives the payment.",
    ))
  } else if (
    payee.name == seller.name
      or (payee.id != none and payee.id == seller.id)
      or (
        payee.legal-id != none
          and seller-legal-id != none
          and payee.legal-id.id == seller-legal-id.id
      )
  ) {
    out.push(error(
      "BR-17",
      field,
      "The payee (BG-10) is stated when someone other than the seller receives the payment, but its name, identifier or legal registration identifier is the seller's.",
      hint: "Leave out `payee` when the seller receives the payment itself.",
    ))
  }
  out += _check-identifiers(payee, field, "payee")
  out += _check-global-id(payee, "BR-CL-10", field)
  out += _check-legal-id(payee, field, "payee", "BT-61")
  if profile.en16931 {
    out += _check-single-identifier(
      payee,
      "CII-SR-451",
      field,
      "payee identifier (BT-60)",
    )
  }
  out
}

// The VAT categories that require the buyer VAT identifier (BT-48), with the
// rules for an invoice line, a document level allowance and charge, and what
// identifies the buyer for them (a reverse charge may take the legal
// registration identifier instead).
#let _buyer-vat-id-rules = (
  K: (
    line: "BR-IC-02",
    allowance: "BR-IC-03",
    charge: "BR-IC-04",
    term: "An intra-community supply (K)",
    required: "the buyer VAT identifier (BT-48)",
  ),
  AE: (
    line: "BR-AE-02",
    allowance: "BR-AE-03",
    charge: "BR-AE-04",
    term: "Reverse charge (AE)",
    required: "the buyer VAT identifier (BT-48) or legal registration identifier (BT-47)",
  ),
)

// The buyer VAT identifier (BT-48) of an intra-community supply (K) or a
// reverse charge (AE). The official rules check invoice lines (BR-IC-02,
// BR-AE-02) and document level allowances and charges (-03, -04). BASIC WL
// writes no lines, yet the VAT Directive (Art. 226 No. 4) still requires the
// buyer VAT ID for K and for a cross-border reverse charge; invoice-pro checks
// that as IP-VAT-226. A domestic reverse charge (e.g. § 13b UStG) can do
// without it.
#let _check-buyer-vat-id(model) = {
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
    // A reverse charge may identify the buyer by its legal registration
    // identifier (BT-47) instead (BR-AE-02 to BR-AE-04), e.g. a domestic
    // reverse charge under § 13b UStG. Across borders, the law still requires
    // the buyer VAT identifier, which the profiles do not check then.
    if category == "AE" and buyer.at("legal-id", default: none) != none {
      if cross-border {
        out.push(error(
          "IP-VAT-226",
          "recipient.vat-id",
          "A cross-border reverse charge (AE) must state the buyer VAT identifier (BT-48) by law (Art. 226 No. 4 of the VAT Directive 2006/112/EC); the legal registration identifier (BT-47) does not replace it.",
          hint: "Set `vat-id` on the recipient.",
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

    let (rule, message) = if (
      on-line or (profile.lines and not on-allowance and not on-charge)
    ) {
      (rules.line, rules.term + " requires " + rules.required + ".")
    } else if on-allowance or on-charge {
      let (rule, kind) = if on-allowance {
        (rules.allowance, "allowance (BG-20)")
      } else { (rules.charge, "charge (BG-21)") }
      (
        rule,
        "A document level "
          + kind
          + " of the VAT category "
          + category
          + " requires "
          + rules.required
          + ".",
      )
    } else if category == "K" or cross-border {
      let subject = if category == "K" { rules.term } else {
        "A cross-border reverse charge (AE)"
      }
      (
        "IP-VAT-226",
        subject
          + " must state the buyer VAT identifier (BT-48) by law (Art. 226 No. 4 of the VAT Directive 2006/112/EC).",
      )
    } else { (none, none) }
    if rule == none { continue }
    out.push(error(
      rule,
      "recipient.vat-id",
      message,
      hint: if rule == "IP-VAT-226" {
        "Set `vat-id` on the recipient. The BASIC WL profile has no invoice lines, so its validators do not check this."
      } else if category == "AE" {
        "Set `vat-id` on the recipient or, if the buyer has no VAT identifier (e.g. a domestic reverse charge), its `legal-id`, e.g. `legal-id: id.register(\"HRB 4711\", court: \"Amtsgericht München\")`."
      } else { "Set `vat-id` on the recipient." },
    ))
  }
  out
}

// VAT identifier prefixes of the EU member states (Greece: "EL") and of
// Northern Ireland ("XI"), the buyers of an intra-community supply.
#let _eu-vat-prefixes = (
  AT: true,
  BE: true,
  BG: true,
  CY: true,
  CZ: true,
  DE: true,
  DK: true,
  EE: true,
  EL: true,
  ES: true,
  FI: true,
  FR: true,
  GR: true,
  HR: true,
  HU: true,
  IE: true,
  IT: true,
  LT: true,
  LU: true,
  LV: true,
  MT: true,
  NL: true,
  PL: true,
  PT: true,
  RO: true,
  SE: true,
  SI: true,
  SK: true,
  XI: true,
)

// Whether an intra-community supply (K) goes to another member state: the
// deliver-to country (BR-IC-12) and the buyer VAT identifier. Picking up the
// goods is legal, so both are warnings.
#let _check-intra-community(model) = {
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
  // A seller without VAT identifier of its own that is registered for VAT
  // through a tax representative dispatches the goods from the member state
  // of the representative's VAT identifier (BT-63).
  let representative = model.at("tax-representative", default: none)
  let whose = "the seller's own country "
  if home == none and representative != none {
    home = vat-id-country(representative.vat-id)
    whose = "the country of the seller's tax representative "
  }
  if home == none {
    home = seller.address.country
    whose = "the seller's own country "
  }
  if (
    model.ship-to != none
      and home != none
      and model.ship-to.address.country == home
  ) {
    out.push(warning(
      "BR-IC-12",
      "delivery-address.country",
      "The intra-community supply (K) states "
        + whose
        + _quoted(home)
        + " as the deliver-to country (BT-80), but the goods must be dispatched to another member state.",
      hint: "Set `country` on the delivery address or the recipient to the member state the goods are delivered to.",
    ))
  }
  let buyer-vat-id = model.buyer.vat-id
  let prefix = vat-id-prefix(buyer-vat-id)
  if prefix != none and prefix not in _eu-vat-prefixes {
    out.push(warning(
      "IP-VAT-138",
      "recipient.vat-id",
      "The buyer VAT identifier "
        + _quoted(buyer-vat-id)
        + " was not issued by an EU member state, so the supply is not an intra-community supply (K).",
      hint: "Use `tax.export()` for supplies to countries outside the EU. Goods for Northern Ireland are intra-community supplies to an \"XI\" VAT identifier.",
    ))
  }
  out
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

  out += _check-input-keys(seller, "sender", "sender")
  out += _check-input-keys(buyer, "recipient", "recipient")
  if ship-to != none {
    out += _check-input-keys(ship-to, "delivery-address", "delivery address")
  }

  // The seller country (BT-40) is written in every profile, the other
  // addresses from BASIC WL on.
  out += _check-country(
    seller.address.country,
    "BR-09",
    "sender.country",
    "seller country code (BT-40)",
    profile.en16931,
  )
  out += _check-country-of-vat-id(seller, "sender", "seller", "BT-40")
  if profile.addresses {
    out += _check-country(
      buyer.address.country,
      "BR-11",
      "recipient.country",
      "buyer country code (BT-55)",
      profile.en16931,
    )
    out += _check-country-of-vat-id(buyer, "recipient", "buyer", "BT-55")
    if ship-to != none {
      out += _check-country(
        ship-to.address.country,
        "BR-57",
        "delivery-address.country",
        "deliver-to country code (BT-80)",
        profile.en16931,
      )
    }
    out += _check-post-code(seller, "sender", "seller", "BT-37", "BT-38")
    out += _check-post-code(buyer, "recipient", "buyer", "BT-52", "BT-53")
    // Without a delivery address of its own, the buyer's address is checked.
    if ship-to != none and not ship-to.at("from-buyer", default: false) {
      out += _check-post-code(
        ship-to,
        "delivery-address",
        "deliver-to",
        "BT-77",
        "BT-78",
      )
    }
  }

  out += _check-vat-id-prefix(seller.vat-id, "sender.vat-id")
  if profile.buyer-vat-id {
    out += _check-vat-id-prefix(buyer.vat-id, "recipient.vat-id")
  }

  // BR-CO-26: the buyer must be able to identify the seller. The VAT
  // identifier of a tax representative (BT-63) does not identify the seller.
  let seller-legal-id = seller.at("legal-id", default: none)
  let represented = model.at("tax-representative", default: none) != none
  if profile.id == "minimum" {
    // MINIMUM states neither `ram:ID` nor `ram:GlobalID` of the seller.
    if seller.vat-id == none and seller-legal-id == none {
      out.push(error(
        "BR-CO-26",
        "sender",
        "The MINIMUM profile identifies the seller by its VAT identifier (BT-31) or its legal registration identifier (BT-30), and both are missing.",
        hint: if represented {
          "The VAT identifier of the tax representative does not identify the seller. Set `legal-id` on the sender, e.g. the seller's registration number in its own country. A seller identified by `id` needs the \"basic-wl\" profile or higher."
        } else {
          "Set `vat-id` or `legal-id` on the sender, e.g. `legal-id: id.siret(\"..\")` or `legal-id: id.register(\"HRB ..\", court: \"Amtsgericht ..\")`. A seller identified by `tax-nr` or `id` needs the \"basic-wl\" profile or higher."
        },
      ))
    }
  } else if (
    seller.id == none
      and seller.global-id == none
      and seller-legal-id == none
      and seller.vat-id == none
  ) {
    out.push(error(
      "BR-CO-26",
      "sender",
      "The seller cannot be identified: neither a seller identifier (BT-29), a legal registration identifier (BT-30) nor a VAT identifier (BT-31) is given.",
      hint: if represented {
        "The VAT identifier of the tax representative does not identify the seller. Set `id` or `legal-id` on the sender, e.g. the seller's registration number in its own country."
      } else if model.outside-scope {
        "An invoice not subject to VAT (O) states no VAT identifier (BR-O-02). Set `tax-nr`, `id` or `legal-id` on the sender."
      } else { "Set `vat-id`, `tax-nr`, `id` or `legal-id` on the sender." },
    ))
  }

  // IP-PRINT-03: the printed invoice shows the seller's VAT ID or tax number
  // the XML states (BT-31, BT-32), one of which the law requires on the
  // invoice (§ 14 Abs. 4 Satz 1 Nr. 2 UStG; Art. 226 No. 3 of the VAT
  // Directive). Only known for a theme that prints the references and no
  // content of its own on every page, see `logic/printed.typ`.
  if seller.at("printed-tax-id", default: none) == false {
    let stated = ()
    if seller.vat-id != none {
      stated.push("VAT identifier " + _quoted(seller.vat-id) + " (BT-31)")
    }
    if seller.tax-nr != none {
      stated.push("tax number " + _quoted(seller.tax-nr) + " (BT-32)")
    }
    out.push(error(
      "IP-PRINT-03",
      "references",
      "The e-invoice states the seller's "
        + stated.join(" and ")
        + ", but the printed invoice shows "
        + if stated.len() > 1 { "neither" } else { "it nowhere" }
        + ". The printed invoice and the e-invoice must state the same details, and the law requires the seller's tax number or VAT identifier on every invoice but a small-amount invoice (§ 14 Abs. 4 Satz 1 Nr. 2 UStG, § 33 UStDV; Art. 226 No. 3 of the VAT Directive).",
      hint: "Print it with the reference signs: keep `references: auto`, use a preset such as `references.preset-b2b()`, or add `references.seller-vat-id()` or `references.seller-tax-nr()` to your references. The `extra` details of the sender and the text of the invoice work as well.",
    ))
  }

  // Identifiers of the `id` module, legal registration identifiers
  // (BT-30, BT-47) and the details only some profiles state.
  out += _check-typed-ids(seller, "sender", "seller")
  out += _check-typed-ids(buyer, "recipient", "buyer")
  if ship-to != none {
    out += _check-typed-ids(ship-to, "delivery-address", "deliver-to location")
  }
  out += _check-legal-id(seller, "sender", "seller", "BT-30")
  out += _check-legal-id(buyer, "recipient", "buyer", "BT-47")
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
      out.push(_not-carried(profile, field, term, lowest))
    }
  }
  out += _check-tax-representative(model)
  out += _check-payee(model)

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
      represented: represented,
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
      // XRechnung only warns about BR-DE-27 and BR-DE-28, but validators such
      // as Mustang reject the invoice, so invoice-pro reports errors.
      if (
        contact.phone != none
          and contact.phone.matches(_xr-patterns().digit).len() < 3
      ) {
        out.push(error(
          "BR-DE-27",
          "sender.contact.phone",
          "The seller contact phone number (BT-42) "
            + _quoted(contact.phone)
            + " must contain at least three digits.",
          hint: "Write the phone number with its digits, e.g. \"+49 89 1234567\".",
        ))
      }
      if (
        contact.email != none
          and contact.email.match(_xr-patterns().email) == none
      ) {
        out.push(error(
          "BR-DE-28",
          "sender.contact.email",
          "The seller contact email address (BT-43) "
            + _quoted(contact.email)
            + " does not have the format XRechnung requires.",
          hint: "Write one \"@\" between the name and a domain of ASCII letters, digits, hyphens and dots, and a domain with umlauts in punycode, e.g. \"info@xn--mller-bau-q9a.de\" for \"info@müller-bau.de\".",
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
          hint: "Write the post code in the format of the country of the "
            + field
            + " (e.g. \"10115 Berlin\") or pass `city: (name: .., post-code: ..)`.",
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

  out += _check-buyer-vat-id(model)
  out += _check-intra-community(model)
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

/// Checks the period and the country of origin of the lines (BG-26,
/// BT-159): the order of the dates of a period (BR-30), a date outside the
/// service period of the invoice (PEPPOL-EN16931-R110 and R111 in XRechnung,
/// else IP-PERIOD-02) and the country code (BR-CL-15).
///
/// -> array
#let check-line-data(model) = {
  let profile = model.profile
  if not profile.lines { return () }
  let out = ()

  // The service period of the invoice: the delivery date (BT-72) or the
  // invoicing period (BG-14). The dates of the items can only leave it if
  // the invoice sets `service-period`.
  let delivery = model.at("delivery", default: (:))
  let invoicing-period = delivery.at("period", default: none)
  let date = delivery.at("date", default: none)
  let service-period = if invoicing-period != none {
    invoicing-period
  } else if (
    date != none
  ) { (date, date) }
  // PEPPOL-EN16931-R110 and R111 of XRechnung compare the lines with BG-14.
  let peppol = profile.xrechnung and invoicing-period != none
  let span(period) = {
    let start = period.first().display("[year]-[month]-[day]")
    let end = period.last().display("[year]-[month]-[day]")
    if start == end { start } else { start + " to " + end }
  }

  let origins = 0
  for line in model.lines {
    let period = line.at("period", default: none)
    let origin = line.at("origin", default: none)
    // Most lines have neither.
    if period == none and origin == none { continue }
    let field = _line-field(line)
    if period != none and period.last() < period.first() {
      out.push(error(
        "BR-30",
        field,
        "The period of the item (BG-26) ends before it starts: "
          + span(period)
          + ".",
        hint: "Give the `date` of the item as `(start, end)`, the earlier date first.",
      ))
    } else if period != none and service-period != none {
      let rules = ()
      if period.first() < service-period.first() {
        rules.push(if peppol { "PEPPOL-EN16931-R110" } else { "IP-PERIOD-02" })
      }
      if period.last() > service-period.last() {
        rules.push(if peppol { "PEPPOL-EN16931-R111" } else { "IP-PERIOD-02" })
      }
      for rule in rules.dedup() {
        out.push((if peppol { error } else { warning })(
          rule,
          field,
          "The date of the item ("
            + span(period)
            + ") is outside the service period of the invoice ("
            + span(service-period)
            + ").",
          hint: "Set `service-period` on the invoice to a period that includes the dates of all items, or leave it out: the dates of the items are the service period then.",
        ))
      }
    }

    if origin == none { continue }
    origins += 1
    if profile.item-origin and origin not in codelists.countries {
      out.push(error(
        "BR-CL-15",
        field,
        "The country of origin (BT-159) "
          + _quoted(origin)
          + " is not in the ISO 3166-1 code list of EN 16931.",
        hint: if origin == "EL" { _country-hints.EL } else {
          "Give `origin` as a country of the `country` module (e.g. `country.de`) or an ISO 3166-1 code such as \"DE\"."
        },
      ))
    }
  }
  if origins > 0 and not profile.item-origin {
    out.push(warning(
      "IP-PROFILE-01",
      "item.origin",
      "The "
        + profile.name
        + " profile has no country of origin of an item (BT-159), so `origin` is printed, but not written into the e-invoice.",
      hint: "Use the \"en16931\" or \"xrechnung\" profile to state it.",
    ))
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

// The VAT category of the VAT exemption reason codes (BT-121) that have one
// of their own; every other code of the VATEX list is an exemption (E).
#let _code-categories = (
  "VATEX-EU-AE": "AE",
  "VATEX-EU-IC": "K",
  "VATEX-EU-G": "G",
  "VATEX-EU-O": "O",
)

// The exemption reason codes (BT-121) of a VAT group: BR-CL-22 (a code of
// the VATEX list), IP-TAX-02 (a code of another VAT category, or of a taxed
// one), IP-TAX-03 (several codes, which EN 16931 cannot state for one VAT
// category and rate) and IP-TAX-04 (an exemption with a code but no text,
// which the printed invoice needs).
#let _check-exemption-codes(tax, field) = {
  let out = ()
  let category = tax.category
  let codes = tax.at("codes", default: ())
  for code in codes {
    if code not in codelists.vatex {
      out.push(error(
        "BR-CL-22",
        field,
        "The VAT exemption reason code (BT-121) "
          + _quoted(code)
          + " is not a code of the VATEX code list.",
        hint: "Use a code of the CEF VATEX list, e.g. \"VATEX-EU-132-1A\" for an exemption of Art. 132 (1) (a) of the VAT Directive, or leave out `code`: the grounds are stated as text (BT-120).",
      ))
      continue
    }
    let fits = _code-categories.at(code, default: "E")
    if category in ("S", "Z", "L", "M") or fits != category {
      out.push(error(
        "IP-TAX-02",
        field,
        "The VAT exemption reason code (BT-121) "
          + _quoted(code)
          + if category in ("S", "Z", "L", "M") {
            (
              " cannot be stated for the VAT category "
                + category
                + ", which is not exempt: it has no exemption reason."
            )
          } else {
            (
              " is a code of the VAT category "
                + fits
                + ", not of "
                + category
                + ", so the e-invoice would state another reason than its category."
            )
          },
        hint: if category in ("S", "Z", "L", "M") {
          "Leave out `code`."
        } else {
          "Use the constructor of the `tax` module that fits the code, e.g. `tax.intra-community()` for \"VATEX-EU-IC\" or `tax.exempt(code: ..)` for an exemption, or leave out `code`."
        },
      ))
    }
  }
  if codes.len() > 1 {
    out.push(warning(
      "IP-TAX-03",
      field,
      "The items of the VAT category "
        + category
        + " give the VAT exemption reason codes "
        + codes.map(_quoted).join(", ")
        + ", but the e-invoice states one code (BT-121) per VAT category and rate, so it states the reasons as text only (BT-120).",
      hint: "Give the items of one VAT category and rate the same `code`, or invoice them separately.",
    ))
  }
  if (
    category == "E"
      and tax.reason == none
      and tax.at("code", default: none) != none
  ) {
    out.push(error(
      "IP-TAX-04",
      field,
      "Exempt items (E) with the VAT exemption reason code "
        + _quoted(tax.code)
        + " (BT-121) need the exemption reason as text as well: the printed invoice states why no VAT is charged (§ 14 Abs. 4 Satz 1 Nr. 8 UStG, Art. 226 No. 11 of the VAT Directive).",
      hint: "State the legal reason next to the code, e.g. `tax.exempt(grounds: \"Steuerfrei nach § 4 Nr. 14 UStG\", code: \"VATEX-EU-132-1C\")`.",
    ))
  }
  out
}

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
    if (
      category == "E"
        and tax.reason == none
        and tax.at("code", default: none) == none
    ) {
      out.push(error(
        "BR-E-10",
        field,
        "Exempt items (E) need the VAT exemption reason (BT-120).",
        hint: "State the legal reason, e.g. `tax.exempt(grounds: \"Steuerfrei nach § 4 Nr. 21 UStG\")`, and its VATEX code if you know it, e.g. `code: \"VATEX-EU-132-1G\"`.",
      ))
    }
    out += _check-exemption-codes(tax, field)
  }

  // The identifiers of the parties each category requires where it occurs:
  // on lines (BR-x-02), allowances (BR-x-03) or charges (BR-x-04). The VAT
  // identifier of the seller tax representative (BT-63) stands in for the
  // seller's own.
  let representative = model.at("tax-representative", default: none)
  let represented = (
    representative != none
      and model.profile.tax-representative
      and representative.vat-id != none
  )
  let representative-hint = " A seller registered for VAT through a fiscal representative names it with `tax-representative: (name: .., address: .., city: .., country: .., vat-id: ..)` on the sender instead: the representative's VAT identifier is not the seller's `vat-id`."
  let taxed = categories.filter(c => (
    c in _taxed-categories and offset(c) != none
  ))
  if (
    taxed.len() > 0
      and seller.vat-id == none
      and seller.tax-nr == none
      and not represented
  ) {
    let first = offset(taxed.first())
    out.push(error(
      _category-rule(taxed.first(), 2 + first),
      "sender",
      _holders.at(first)
        + " with the VAT category "
        + taxed.join(", ")
        + " require the seller VAT identifier (BT-31), its tax number (BT-32) or the VAT identifier of its tax representative (BT-63).",
      hint: "Set `vat-id` or `tax-nr` on the sender." + representative-hint,
    ))
  }
  for (category, term) in (
    ("K", "An intra-community supply (K)"),
    ("G", "An export outside the EU (G)"),
  ) {
    let at = offset(category)
    if (
      category in categories
        and at != none
        and seller.vat-id == none
        and not represented
    ) {
      out.push(error(
        _category-rule(category, 2 + at),
        "sender.vat-id",
        term
          + " requires the seller VAT identifier (BT-31) or the VAT identifier of its tax representative (BT-63).",
        hint: "Set `vat-id` on the sender." + representative-hint,
      ))
    }
  }
  // The buyer VAT identifier (BT-48) of K and AE: see `_check-buyer-vat-id`.
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
  for i in range(lines.len() - 1, -1, step: -1) {
    let parts = lines.at(i).split("#")
    if parts.len() >= 3 and parts.slice(1, -1).join("#") != "" {
      if (
        i < lines.len() - 1 and parts.last().replace(_xml-whitespace, "") == ""
      ) {
        return none
      }
      return (after: lines.at(i).replace(_xml-whitespace, " ").trim(" "))
    }
  }
  none
}

// An input the profile has no business term for: it is not written into the
// e-invoice. `lowest` is the lowest profile that states it.
#let _payment-not-carried(profile, field, term, lowest) = warning(
  "IP-PROFILE-01",
  field,
  "The "
    + profile.name
    + " profile cannot state "
    + term
    + ", so `"
    + field
    + "` is not written into the e-invoice.",
  hint: "Use the " + _quoted(lowest) + " profile or higher to state it.",
)

// What a kind of payment means is, and the input that states it, for
// messages. A means of `paid` without details names its code.
#let _means-names = (
  transfer: "a credit transfer",
  direct-debit: "a direct debit",
  card: "a payment card",
)
#let _code-names = (
  "10": "cash",
  "20": "a cheque",
  "68": "an online payment service",
)
#let _means-description(means) = {
  let name = _means-names.at(means.kind, default: none)
  if name == none {
    name = _code-names.at(
      means.type-code,
      default: "the payment means code " + means.type-code,
    )
  }
  name + " (`" + means.field + "`)"
}

// The inputs of the payment means, besides the bank details of a credit
// transfer, for hints.
#let _means-hint = "`#bank-details(iban: ..)` for a credit transfer, `#direct-debit(mandate: .., creditor-id: .., debtor-iban: ..)` for a SEPA direct debit, `#card-payment(last4: ..)` for a payment card, or `#paid(method: ..)` for an invoice that is paid already"

// The payment means (BG-16): one kind of payment means, each with the
// details of its kind (XRechnung: BR-DE-1, BR-DE-19, BR-DE-20, BR-DE-23,
// BR-DE-24, BR-DE-25, BR-DE-30, BR-DE-31, PEPPOL-EN16931-R061).
#let _check-payment-means(model) = {
  let out = ()
  let profile = model.profile
  let xrechnung = profile.xrechnung
  let payment = model.payment
  let means = payment.means

  if means.len() == 0 {
    if xrechnung {
      out.push(error(
        "BR-DE-1",
        if payment.at("paid", default: false) { "paid.method" } else {
          "bank-details"
        },
        "XRechnung requires payment instructions (BG-16).",
        hint: if payment.at("paid", default: false) {
          "Set `method` on `paid` to the way the invoice was paid, e.g. `paid(method: \"cash\")`, or add the payment means it was paid with, e.g. `#bank-details(iban: ..)` for a credit transfer."
        } else { "Add the payment means of the invoice: " + _means-hint + "." },
      ))
    }
    return out
  }

  // An invoice states one payment means code (BT-81). XRechnung forbids the
  // details of a direct debit (BG-19: the mandate reference, the creditor
  // identifier or a debited account) next to a credit transfer (BR-DE-23-b)
  // or a payment card (BR-DE-24-b); the other combinations are conflicting
  // instructions as well, which could make the buyer pay twice.
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
    let rule = if xrechnung and debit-details and "transfer" in kinds {
      "BR-DE-23-b"
    } else if xrechnung and debit-details and "card" in kinds {
      "BR-DE-24-b"
    } else { "IP-PAY-03" }
    let names = conflicting.map(_means-description)
    let fields = conflicting.map(entry => entry.field)
    let paid = "paid" in fields
    out.push(error(
      rule,
      fields.join(", "),
      "The invoice states several payment means: "
        + names.slice(0, -1).join(", ")
        + " and "
        + names.last()
        + ". An invoice states one payment means (BT-81)"
        + if paid { ": the one it was paid with." } else {
          ", so that the buyer knows how to pay and does not pay twice."
        },
      hint: if paid {
        "Remove the payment means the invoice was not paid with, e.g. `bank-details` of an invoice paid in cash, or set `method` on `paid` to the one it was paid with. To show your bank account for information only, print it as text."
      } else {
        "Keep the payment means the buyer pays with, e.g. remove `bank-details` when the amount is collected by direct debit or charged to a card. To show your bank account for information only, print it as text."
      },
    ))
  }

  let sepa-debit = false
  for entry in means {
    if entry.kind == "transfer" {
      if entry.iban == none {
        // `paid(method: "transfer")` without bank details, or bank details
        // without an IBAN (with `zugferd-errors: "report"`; otherwise
        // `bank-details` stops the compilation).
        let paid = entry.field == "paid"
        out.push(error(
          if xrechnung { "BR-DE-23-a" } else { "BR-61" },
          if paid { "paid.method" } else { "bank-details.iban" },
          "A credit transfer (BT-81 = "
            + entry.type-code
            + ") states the account the amount is transferred to (BT-84), but none is given.",
          hint: if paid {
            "Add `#bank-details(iban: ..)` with the account the invoice was paid to."
          } else { "Set `iban` on `bank-details`." },
        ))
      } else if not iban-valid(entry.iban) {
        out.push(error(
          if xrechnung and entry.type-code == "58" { "BR-DE-19" } else {
            "IP-PAY-01"
          },
          "bank-details.iban",
          "The IBAN (BT-84) "
            + _quoted(format-iban(entry.iban))
            + " is not valid (wrong check digits or format).",
          hint: "Check the IBAN for typos.",
        ))
      }
      if entry.account-name != none and not profile.account-name {
        out.push(_payment-not-carried(
          profile,
          "bank-details.name",
          "the account name (BT-85)",
          "en16931",
        ))
      }
    } else if entry.kind == "direct-debit" {
      sepa-debit = sepa-debit or entry.type-code == "59"
      if entry.field == "paid" {
        // `paid(method: "direct-debit")` without the direct debit: XRechnung
        // requires the direct debit (BG-19) of a SEPA direct debit, and the
        // mandate reference of any direct debit (PEPPOL-EN16931-R061).
        if xrechnung {
          let sepa = entry.type-code == "59"
          out.push(error(
            if sepa { "BR-DE-25-a" } else { "PEPPOL-EN16931-R061" },
            "paid.method",
            if sepa {
              "A SEPA direct debit (BT-81 = 59) states the direct debit (BG-19), but none is given."
            } else {
              (
                "A direct debit (BT-81 = "
                  + entry.type-code
                  + ") states the mandate reference (BT-89), but none is given."
              )
            },
            hint: "Add `#direct-debit(mandate: .., creditor-id: .., debtor-iban: ..)` with the direct debit the invoice was paid with.",
          ))
        }
      } else if xrechnung {
        // The direct debit component requires the mandate reference and
        // the creditor identifier; the debited account is optional.
        if payment.at("mandate", default: none) == none {
          out.push(error(
            "PEPPOL-EN16931-R061",
            "direct-debit.mandate",
            "XRechnung requires the mandate reference (BT-89) of a direct debit.",
            hint: "Set `mandate` on `direct-debit` to the reference of the direct debit mandate.",
          ))
        }
        if payment.at("creditor-id", default: none) == none {
          out.push(error(
            "BR-DE-30",
            "direct-debit.creditor-id",
            "XRechnung requires the creditor identifier (BT-90) of a direct debit.",
            hint: "Set `creditor-id` on `direct-debit` to your SEPA creditor identifier.",
          ))
        }
        if entry.debtor-iban == none {
          out.push(error(
            "BR-DE-31",
            "direct-debit.debtor-iban",
            "XRechnung requires the debited account (BT-91) of a direct debit.",
            hint: "Set `debtor-iban` on `direct-debit` to the IBAN of the buyer's account that is debited.",
          ))
        }
      }
      if entry.debtor-iban != none and not iban-valid(entry.debtor-iban) {
        out.push(error(
          if xrechnung and entry.type-code == "59" { "BR-DE-20" } else {
            "IP-PAY-01"
          },
          "direct-debit.debtor-iban",
          "The IBAN of the debited account (BT-91) "
            + _quoted(format-iban(entry.debtor-iban))
            + " is not valid (wrong check digits or format).",
          hint: "Check the IBAN for typos.",
        ))
      }
    } else if entry.kind == "card" {
      if entry.card == none {
        // `paid(method: "card")` without the payment card.
        if xrechnung {
          out.push(error(
            "BR-DE-24-a",
            "paid.method",
            "A card payment (BT-81 = "
              + entry.type-code
              + ") states the payment card (BG-18), but none is given.",
            hint: "Add `#card-payment(last4: ..)` with the last digits of the card the invoice was paid with.",
          ))
        }
      } else if not profile.payment-card {
        out.push(_payment-not-carried(
          profile,
          "card-payment",
          "the payment card (BG-18)",
          "en16931",
        ))
      }
    }
    if entry.type-code not in codelists.payment-means {
      out.push(error(
        "BR-CL-16",
        "paid.method",
        "The payment means code (BT-81) "
          + _quoted(entry.type-code)
          + " is not in the UNTDID 4461 code list.",
        hint: "Use a code of UNTDID 4461, e.g. \"10\" for cash or \"97\" for a clearing between partners, or one of the methods of `paid`, e.g. `\"cash\"`.",
      ))
    }
  }

  // The check digits of a SEPA creditor identifier (BT-90).
  let creditor-id = payment.at("creditor-id", default: none)
  if sepa-debit and creditor-id != none and not creditor-id-valid(creditor-id) {
    out.push(error(
      "IP-PAY-02",
      "direct-debit.creditor-id",
      "The creditor identifier (BT-90) "
        + _quoted(creditor-id)
        + " is not a valid SEPA creditor identifier (wrong check digits or format).",
      hint: "Check the creditor identifier for typos, e.g. \"DE98ZZZ09999999999\".",
    ))
  }
  out
}

// The payment details the MINIMUM profile cannot state: it states the amount
// due, but no payment means and no payment terms.
#let _check-minimum-payment(model) = {
  let out = ()
  let profile = model.profile
  let payment = model.payment
  for entry in payment.means {
    // BASIC WL states a direct debit in full, but a payment card only by its
    // payment means code: EN 16931 is the lowest profile that states it.
    if entry.field == "direct-debit" {
      out.push(_payment-not-carried(
        profile,
        entry.field,
        "the direct debit (BG-19)",
        "basic-wl",
      ))
    } else if entry.field == "card-payment" {
      out.push(_payment-not-carried(
        profile,
        entry.field,
        "the payment card (BG-18)",
        "en16931",
      ))
    }
  }
  if payment.at("discounts", default: ()).len() > 0 {
    out.push(_payment-not-carried(
      profile,
      "payment-goal.discount",
      "a cash discount (BT-20)",
      "basic-wl",
    ))
  }
  out
}

#let check-payment(model) = {
  if not model.profile.settlement { return _check-minimum-payment(model) }
  let out = ()
  let payment = model.payment
  let terms = profile-terms(payment, model.profile)

  if model.profile.xrechnung and terms != none {
    let problem = _skonto-problem(terms)
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

  // XRechnung states the amount a cash discount applies to with 2 decimals.
  if model.profile.xrechnung {
    for discount in payment.at("discounts", default: ()) {
      let basis = discount.basis
      if basis != none and calc.round(basis, digits: 2) != basis {
        out.push(error(
          "BR-DE-18",
          "payment-goal.discount",
          "The amount a cash discount applies to (#BASISBETRAG) has 2 decimals in XRechnung, but "
            + str(basis)
            + " has more.",
          hint: "Give the `basis` of the cash discount with at most 2 decimals.",
        ))
      }
    }
  }

  if model.totals.due > _zero and payment.due-date == none and terms == none {
    out.push(error(
      "BR-CO-25",
      "payment-goal",
      "An amount is due, but neither the payment due date (BT-9) nor the payment terms (BT-20) are given.",
      hint: "Add `#payment-goal(days: 14)` or set `due-date` on the invoice.",
    ))
  }

  out += _check-payment-means(model)

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
      + check-document-type(model)
      + check-document-data(model)
      + check-parties(model)
      + check-lines(model)
      + check-line-data(model)
      + check-taxes(model)
      + check-payment(model)
      + check-consistency(model)
  )
  (
    diagnostics.filter(d => d.level == "error")
      + diagnostics.filter(d => d.level != "error")
  )
}
