#import "loom-wrapper.typ": loom, weave
#import "components/root.typ": root
#import "data/tax.typ"
#import "utils/types.typ"
#import "themes/themes.typ"

#import "locale/locale.typ"
#import "locale/lang/base.typ": base-language
#import "locale/region/base.typ": base-region
#import "logic/country.typ": normalize-party, resolve-party-country
#import "logic/document-type.typ": document-title, resolve-document-type
#import "logic/notes.typ": normalize-notes

/// The main entry point for creating an invoice document.
/// It orchestrates the theme, localization, and data calculation passes.
///
/// -> content
#let invoice(
  /// The visual theme to apply to the invoice.
  /// -> function
  theme: themes.DIN-5008(),
  /// The locale settings for language and number formatting.
  /// -> function
  locale: locale.de-de,

  /// A dictionary containing sender details (e.g., name, address).
  /// -> dictionary
  sender: (:),
  /// A dictionary containing recipient details (e.g., name, address).
  /// -> dictionary
  recipient: (:),
  /// Separate delivery or shipping address (e.g. if different from billing address).
  /// Can also be specified as `recipient.delivery-address`. Without a
  /// `country` of its own, it is in the recipient's country.
  /// -> none | dictionary
  delivery-address: none,

  /// Your company's unique tax identifier / VAT ID (backwards compatibility).
  /// -> none | string | content (deprecated)
  tax-nr: none,

  /// The date of the invoice. Defaults to today.
  /// -> datetime
  date: datetime.today(),
  /// The date or period `(start, end)` of the supply, printed by
  /// `references.service-time()` and written to the e-invoice (BT-72 or
  /// BG-14). If `none`, the earliest to the latest date of the items, or the
  /// invoice date if no item has a date.
  /// -> none | datetime | array
  service-period: none,
  /// The subject line of the invoice. If `auto`, the title of the
  /// `document-type` in the language of the locale, e.g. "Rechnung".
  /// -> string | content
  subject: auto,
  /// The type of the document (BT-3 of the e-invoice): `"invoice"` (380),
  /// `"credit-note"` (381, amounts credited to the buyer, stated as positive
  /// amounts), `"corrected"` (384, replaces `preceding-invoice-nr`),
  /// `"prepayment"` (386), `"self-billed"` (389, issued by the buyer: the
  /// sender is the buyer and the recipient the seller), or another code of
  /// UNTDID 1001 for invoices and credit notes, e.g. `"326"` for a partial
  /// invoice. `auto` is an invoice.
  /// -> auto | str | int
  document-type: auto,
  /// Reference information for the document header (e.g., customer number).
  /// If `auto`, defaults to displaying sender tax-nr, sender vat-id, and recipient vat-id in exclusive tax-mode (B2B), or none in inclusive tax-mode (B2C).
  /// -> auto | none | dictionary | array | function
  references: auto,
  /// The unique identifier or number of the invoice.
  /// -> none | string | content
  invoice-nr: none,

  /// Customer number or client identifier.
  /// -> none | string | content
  customer-nr: none,
  /// Order / purchase order number (PO number).
  /// -> none | string | content
  order-nr: none,
  /// Order placement date.
  /// -> none | datetime | string | content
  order-date: none,
  /// Project name or reference code.
  /// -> none | string | content
  project: none,
  /// Contract or framework agreement number.
  /// -> none | string | content
  contract-nr: none,
  /// Quote or estimate reference number.
  /// -> none | string | content
  quote-nr: none,
  /// Delivery note / shipping advice number.
  /// -> none | string | content
  delivery-note-nr: none,
  /// Preceding invoice number (for credit notes / corrections).
  /// -> none | string | content
  preceding-invoice-nr: none,
  /// The date of the preceding invoice (BT-26 of the e-invoice), next to
  /// `preceding-invoice-nr`.
  /// -> none | datetime
  preceding-invoice-date: none,
  /// Explicit due date for payment.
  /// -> none | datetime | string | content
  due-date: none,
  /// Custom payment reference / purpose (Verwendungszweck).
  /// -> none | string | content
  payment-reference: none,
  /// Notes about the invoice as a whole: a text, or an array of texts and
  /// dictionaries `(text: .., subject-code: ..)` with a UNTDID 4451 subject
  /// code (e.g. `"AAI"`). They are printed below the line items and written
  /// into the e-invoice (BT-22, BT-21).
  /// -> none | str | content | array
  notes: none,

  /// The default tax rate to apply if not specified elsewhere.
  /// If `auto`, it is inferred from the locale.
  /// -> auto | ratio | dictionary | none
  tax: auto,
  /// Determines if prices are handled as inclusive or exclusive of tax.
  /// -> "inclusive" | "exclusive"
  tax-mode: "exclusive",
  /// If true, applies small business tax exemption logic according to the locale.
  /// -> bool
  tax-exempt-small-biz: false,

  /// ZUGFeRD / Factur-X profile for embedding machine-readable XML into the PDF.
  /// Requires exporting with PDF/A-3 (`typst compile --pdf-standard=a-3b`).
  /// `auto` chooses the richest profile the invoice satisfies: `"xrechnung"`
  /// for a buyer in Germany, otherwise `"en16931"`.
  /// -> none | auto | "minimum" | "basic-wl" | "basic" | "en16931" | "xrechnung"
  zugferd: none,
  /// What to do when the e-invoice data violates the rules of the profile.
  /// `"panic"` stops the compilation with a list of all problems, `"report"`
  /// lists them in the document instead and attaches the XML of an invoice
  /// with errors only as a draft (`invoice-draft.xml`), and `"ignore"`
  /// attaches the XML as usual anyway.
  /// -> "panic" | "report" | "ignore"
  zugferd-errors: "panic",

  /// The content of the invoice, typically containing line-items and other components.
  /// -> content
  body,
) = {
  types.require(theme, "invoice::theme", function)
  types.require(locale, "invoice::locale", function)

  types.require(sender, "invoice::sender", dictionary)
  types.require(recipient, "invoice::recipient", dictionary)
  types.require(
    delivery-address,
    "invoice::delivery-address",
    none,
    dictionary,
  )
  types.require(
    recipient.at("delivery-address", default: none),
    "invoice::recipient.delivery-address",
    none,
    dictionary,
  )

  types.require(date, "invoice::date", datetime)
  types.require(
    service-period,
    "invoice::service-period",
    none,
    types.date-like,
  )
  if (
    type(service-period) == array
      and service-period.last() < service-period.first()
  ) {
    panic(
      "invoice::service-period ends before it starts: "
        + service-period.first().display()
        + " to "
        + service-period.last().display()
        + ". Give it as `(start, end)`.",
    )
  }
  types.require(subject, "invoice::subject", auto, str, content)
  types.require(document-type, "invoice::document-type", auto, str, int)
  types.require(
    references,
    "invoice::references",
    auto,
    none,
    function,
    loom.matcher.dict(loom.matcher.choice(types.text-like, function)),
    loom.matcher.many(loom.matcher.choice(
      function,
      array,
      (types.text-like, types.text-like),
      (types.text-like, function),
    )),
  )
  types.require(invoice-nr, "invoice::invoice-nr", none, str, content)
  types.require(customer-nr, "invoice::customer-nr", none, str, content)
  types.require(order-nr, "invoice::order-nr", none, str, content)
  types.require(order-date, "invoice::order-date", none, datetime, str, content)
  types.require(project, "invoice::project", none, str, content)
  types.require(contract-nr, "invoice::contract-nr", none, str, content)
  types.require(quote-nr, "invoice::quote-nr", none, str, content)
  types.require(
    delivery-note-nr,
    "invoice::delivery-note-nr",
    none,
    str,
    content,
  )
  types.require(
    preceding-invoice-nr,
    "invoice::preceding-invoice-nr",
    none,
    str,
    content,
  )
  types.require(
    preceding-invoice-date,
    "invoice::preceding-invoice-date",
    none,
    datetime,
  )
  types.require(due-date, "invoice::due-date", none, datetime, str, content)
  types.require(
    payment-reference,
    "invoice::payment-reference",
    none,
    str,
    content,
  )
  types.require(tax-nr, "invoice::tax-nr", none, str, content)
  types.require(notes, "invoice::notes", none, str, content, array)

  types.require(tax, "invoice::tax", none, auto, types.tax-like)
  types.require(tax-mode, "invoice::tax-mode", "inclusive", "exclusive")
  types.require(tax-exempt-small-biz, "invoice::tax-exempt-small-biz", bool)
  types.require(
    zugferd,
    "invoice::zugferd",
    none,
    auto,
    "minimum",
    "basic-wl",
    "basic",
    "en16931",
    "xrechnung",
  )
  types.require(
    zugferd-errors,
    "invoice::zugferd-errors",
    "panic",
    "report",
    "ignore",
  )

  /** Input Calculations **/
  let eval-theme = theme()
  let eval-locale = locale(base-language, base-region)
  let document = resolve-document-type(document-type)

  let default-region = eval-locale.meta.region
  let sender = sender
  if tax-nr != none {
    if zugferd != none {
      panic(
        "Top-level 'tax-nr' is not allowed when 'zugferd' (e-invoicing) is enabled. Please specify 'tax-nr' inside the 'sender' dictionary instead.",
      )
    }
    if "tax-nr" in sender and sender.tax-nr != none {
      panic(
        "Both the top-level 'tax-nr' parameter and 'sender.tax-nr' are populated, but they are mutually exclusive.",
      )
    }
    sender.insert("tax-nr", tax-nr)
  }

  let resolved-recipient-country = resolve-party-country(
    recipient,
    default-region,
    field: "recipient",
  ).country

  let normalized-sender = normalize-party(
    sender,
    default-region,
    recipient-country-code: resolved-recipient-country.code,
  )
  let normalized-recipient = normalize-party(
    recipient,
    default-region,
    is-recipient: true,
    sender-country-code: normalized-sender.country.code,
  )

  let raw-delivery-address = if delivery-address != none {
    delivery-address
  } else if (
    "delivery-address" in recipient and recipient.delivery-address != none
  ) {
    recipient.delivery-address
  } else {
    none
  }
  // Without a country of its own, the delivery address is in the buyer's
  // country, not in the country of the locale: the recipient's, or the
  // sender's on a self-billed invoice, which the buyer issues.
  let normalized-delivery-address = if raw-delivery-address != none {
    normalize-party(
      raw-delivery-address,
      default-region,
      is-recipient: true,
      sender-country-code: normalized-sender.country.code,
      default-country: if document.self-billed {
        normalized-sender.country
      } else { normalized-recipient.country },
      field: if delivery-address != none { "delivery-address" } else {
        "recipient.delivery-address"
      },
    )
  } else {
    none
  }
  if normalized-delivery-address != none {
    normalized-recipient.insert("delivery-address", normalized-delivery-address)
  }

  if subject == auto { subject = document-title(document, eval-locale.strings) }

  let document-subject = (subject, invoice-nr).join(" ")
  let document-tax = if tax != auto { tax } else { eval-locale.tax.default-vat }

  if tax-exempt-small-biz {
    if tax != auto {
      panic(
        "If using invoice::tax-exempt-small-biz then the tax must be set to `auto`",
      )
    }
    document-tax = eval-locale.tax.small-enterprise-special-scheme
  }

  let document-references = ()
  if references == auto {
    if tax-mode != "inclusive" {
      let sender-tax-nr = normalized-sender.tax-nr
      if sender-tax-nr != none and sender-tax-nr != "" {
        document-references.push((
          eval-locale.strings.reference.tax-number,
          sender-tax-nr,
        ))
      }
      let sender-vat-id = normalized-sender.vat-id
      if sender-vat-id != none and sender-vat-id != "" {
        document-references.push((
          eval-locale.strings.reference.vat-id,
          sender-vat-id,
        ))
      }
      let recipient-vat-id = normalized-recipient.vat-id
      if recipient-vat-id != none and recipient-vat-id != "" {
        document-references.push((
          eval-locale.strings.reference.recipient-vat-id,
          recipient-vat-id,
        ))
      }
    }
    // A self-billed invoice, which the buyer (the sender) issues for the
    // seller (the recipient), states the seller's tax number or VAT ID (e.g.
    // § 14 Abs. 4 Satz 1 Nr. 2 UStG), and the buyer's VAT ID.
    if tax-mode != "inclusive" and document.self-billed {
      let labels = eval-locale.strings.reference
      document-references = ()
      for (label, value) in (
        (labels.recipient-tax-number, normalized-recipient.tax-nr),
        (labels.recipient-vat-id, normalized-recipient.vat-id),
        (labels.vat-id, normalized-sender.vat-id),
      ) {
        if value != none and value != "" {
          document-references.push((label, value))
        }
      }
    }
  } else if type(references) == function {
    document-references = references
  } else if type(references) == array {
    document-references = references
  } else if type(references) == dictionary {
    document-references = references.pairs()
  }

  let inputs = (
    theme: eval-theme,
    locale: eval-locale,
    format: eval-locale.at("format", default: (:)),

    sender: normalized-sender,
    recipient: normalized-recipient,
    delivery-address: normalized-delivery-address,

    invoice-date: date,
    service-period: service-period,
    subject: document-subject,
    // The title of the document, the subject without the invoice number.
    title: subject,
    // The resolved `document-type`, see `resolve-document-type`.
    document-type: document,
    references: document-references,
    invoice-nr: invoice-nr,

    customer-nr: customer-nr,
    order-nr: order-nr,
    order-date: order-date,
    project: project,
    contract-nr: contract-nr,
    quote-nr: quote-nr,
    delivery-note-nr: delivery-note-nr,
    preceding-invoice-nr: preceding-invoice-nr,
    preceding-invoice-date: preceding-invoice-date,
    due-date: due-date,
    payment-reference: payment-reference,
    // `(text: .., subject-code: ..)` each, see `normalize-notes`.
    notes: normalize-notes(notes),

    tax: document-tax,
    tax-mode: tax-mode,
    tax-exempt-small-biz: tax-exempt-small-biz,

    zugferd: zugferd,
    zugferd-errors: zugferd-errors,
  )

  /** Data Calculations **/
  let weaved-body = weave(
    max-passes: 2,
    inputs: inputs,
    injector: (ctx, payload) => {
      ctx + (global: payload.first(default: (:)).at("signal", default: (:)))
    },
    root(body),
  )

  weaved-body
}
