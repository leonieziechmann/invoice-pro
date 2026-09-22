#import "loom-wrapper.typ": loom, weave
#import "components/root.typ": root
#import "data/tax.typ"
#import "utils/types.typ"
#import "public/theme.typ" as theme-ns
#import "theming/build.typ": schema as theme-schema
#import "theming/access.typ": seal
#import "validation/issue.typ": resolve-level
#import "validation/data.typ": check-data

#import "locale/locale.typ"
#import "locale/lang/base.typ": base-language
#import "locale/region/base.typ": base-region
#import "logic/country.typ": (
  normalize-party, normalize-region-to-string, resolve-country,
)

/// The main entry point for creating an invoice document.
/// It orchestrates the theme, localization, and data calculation passes.
///
/// -> content
#let invoice(
  /// The theme: a lazy theme such as `theme.classic`, customised with
  /// `.with(..patches, layout: ..)`. Pass it uncalled (calling it is equivalent).
  /// Without `layout:`, the preset picks its page master from the sender's
  /// region (the sender's country, else the locale's region): e.g. DIN 5008
  /// form A in Germany, SN 010130 in Switzerland, US Letter #10 in the US
  /// (`theme.layout.for-region`). An explicit `layout:` always wins.
  /// -> function
  theme: theme-ns.classic,
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
  /// Can also be specified as `recipient.delivery-address`.
  /// -> none | dictionary
  delivery-address: none,

  /// Your company's unique tax identifier / VAT ID (backwards compatibility).
  /// -> none | string | content (deprecated)
  tax-nr: none,

  /// The date of the invoice. Defaults to today.
  /// -> datetime
  date: datetime.today(),
  /// The subject line of the invoice.
  /// -> string | content
  subject: auto,
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
  /// Explicit due date for payment.
  /// -> none | datetime | string | content
  due-date: none,
  /// Custom payment reference / purpose (Verwendungszweck).
  /// -> none | string | content
  payment-reference: none,

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
  /// -> none | "minimum" | "basic-wl" | "basic" | "en16931"
  zugferd: none,

  /// What happens when legally required data or output is missing, or a
  /// theme check fails:
  /// - `"draft"`: the document renders, and every problem is shown in it: an
  ///   inline marker where data is missing (‹fehlt: Rechnungsnummer›), a badge
  ///   and a watermark on each page, and a report page with the legal basis of
  ///   each problem. A ZUGFeRD XML with missing data is withheld. A complete
  ///   document renders exactly as under `"strict"`.
  /// - `"strict"`: the compilation stops and lists every problem. Use it for
  ///   sending and in CI.
  /// - `none`: no checks; the document renders what it was given. Off means
  ///   off: with `zugferd` set, the XML is attached even when required data is
  ///   missing, so an incomplete e-invoice can leave the building. Use `none`
  ///   for thumbnails and tests, never for sending.
  /// Misuse (unknown keys, wrong types, unknown parts, ..) always panics.
  /// `--input invoice-pro-validation=strict|draft|none` overrides this value.
  /// -> none | "draft" | "strict"
  validation: "draft",

  /// The content of the invoice, typically containing line-items and other components.
  /// -> content
  body,
) = {
  if type(theme) != function {
    panic(
      "variable `invoice::theme` must be of function (a lazy theme such as `theme.classic`), found "
        + str(type(theme))
        + ". For a brand file write `theme.classic.with(theme.custom.from-data(toml(\"brand.toml\")))`.",
    )
  }
  types.require(locale, "invoice::locale", function)

  types.require(sender, "invoice::sender", dictionary)
  types.require(recipient, "invoice::recipient", dictionary)
  types.require(
    delivery-address,
    "invoice::delivery-address",
    none,
    dictionary,
  )

  types.require(date, "invoice::date", datetime)
  types.require(subject, "invoice::subject", auto, str, content)
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
  types.require(due-date, "invoice::due-date", none, datetime, str, content)
  types.require(
    payment-reference,
    "invoice::payment-reference",
    none,
    str,
    content,
  )
  types.require(tax-nr, "invoice::tax-nr", none, str, content)

  types.require(tax, "invoice::tax", none, auto, types.tax-like)
  types.require(tax-mode, "invoice::tax-mode", "inclusive", "exclusive")
  types.require(tax-exempt-small-biz, "invoice::tax-exempt-small-biz", bool)
  types.require(
    zugferd,
    "invoice::zugferd",
    none,
    "minimum",
    "basic-wl",
    "basic",
    "en16931",
    "xrechnung",
  )

  /** Input Calculations **/
  let validation-level = resolve-level(validation)
  let eval-locale = locale(base-language, base-region)

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

  let recipient-region = normalize-region-to-string(
    recipient.at("region", default: none),
    default-region,
  )
  let resolved-recipient-country = resolve-country(
    recipient.at("country", default: auto),
    recipient-region,
  )

  let normalized-sender = normalize-party(
    sender,
    default-region,
    recipient-country-code: resolved-recipient-country.code,
  )
  // The theme environment. `region` is the SENDER's region (its country, else the
  // locale's region): presets pick their default layout from it (envelopes and
  // paper belong to the sender; theme.layout.for-region).
  let eval-theme = theme(base: theme-schema, env: (
    kind: "invoice",
    lang: eval-locale.strings.meta.lang,
    region: lower(str(normalized-sender.country.at(
      "code",
      default: default-region,
    ))),
    e-invoice: zugferd,
  ))
  if (
    type(eval-theme) != dictionary or "__invoice-pro-theme__" not in eval-theme
  ) {
    panic(
      "variable `invoice::theme` must be a lazy theme such as `theme.classic`; the given function returned "
        + str(type(eval-theme)),
    )
  }

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
  let normalized-delivery-address = if raw-delivery-address != none {
    normalize-party(
      raw-delivery-address,
      default-region,
      is-recipient: true,
      sender-country-code: normalized-sender.country.code,
    )
  } else {
    none
  }
  if normalized-delivery-address != none {
    normalized-recipient.insert("delivery-address", normalized-delivery-address)
  }

  if subject == auto { subject = eval-locale.strings.document.invoice }

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
  } else if type(references) == function {
    document-references = references
  } else if type(references) == array {
    document-references = references
  } else if type(references) == dictionary {
    document-references = references.pairs()
  }

  // Compliance and lint findings known before layout: the theme's and the
  // document data's. Root adds the measured ones and applies the level.
  let issues = if validation-level == none { () } else {
    (
      eval-theme.issues
        + check-data(
          "invoice",
          "input",
          (
            invoice-nr: invoice-nr,
            sender: normalized-sender,
            recipient: normalized-recipient,
          ),
          region: lower(str(eval-locale.meta.region)),
        )
    )
  }

  let inputs = (
    theme: seal(eval-theme),
    validation: (level: validation-level, issues: issues),
    locale: eval-locale,
    format: eval-locale.at("format", default: (:)),

    sender: normalized-sender,
    recipient: normalized-recipient,
    delivery-address: normalized-delivery-address,

    invoice-date: date,
    subject: document-subject,
    subject-text: subject,
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
    due-date: due-date,
    payment-reference: payment-reference,

    tax: document-tax,
    tax-mode: tax-mode,
    tax-exempt-small-biz: tax-exempt-small-biz,

    zugferd: zugferd,
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
