#import "loom-wrapper.typ": loom, weave
#import "components/root.typ": root
#import "data/tax.typ"
#import "utils/types.typ"
#import "themes/themes.typ"
#import "locale/locale.typ"

#let invoice(
  theme: themes.DIN-5008(),
  locale: locale.de,

  sender: (:),
  recipient: (:),

  date: datetime.today(),
  subject: "Rechnung",
  references: none,
  invoice-nr: none,

  tax: auto,
  tax-mode: "exclusive",
  tax-exempt-small-biz: false,

  body,
) = {
  types.require(theme, "invoice::theme", function)
  types.require(locale, "invoice::locale", function)

  types.require(sender, "invoice::sender", dictionary)
  types.require(recipient, "invoice::recipient", dictionary)

  types.require(date, "invoice::date", datetime)
  types.require(subject, "invoice::subject", str, content)
  types.require(
    references,
    "invoice::references",
    none,
    loom.matcher.dict(types.text-like),
    loom.matcher.many((
      types.text-like,
      types.text-like,
    )),
  )
  types.require(invoice-nr, "invoice::invoice-nr", none, str, content)

  types.require(tax, "invoice::tax", none, auto, types.tax-like)
  types.require(tax-mode, "invoice::tax-mode", "inclusive", "exclusive")
  types.require(tax-exempt-small-biz, "invoice::tax-exempt-small-biz", bool)

  /** Input Calculations **/
  let eval-theme = theme()
  let eval-locale = locale()

  let document-subject = (subject, invoice-nr).join(" ")
  let document-tax = if tax != auto { tax } else { eval-locale.variables.vat }

  if tax-exempt-small-biz {
    if tax != auto {
      panic(
        "If using invoice::tax-exempt-small-biz then the tax must be set to `auto`",
      )
    }
    document-tax = eval-locale.variables.small-biz-tax-exemption-code
  }

  let document-references = ()
  if type(references) == array { document-references = references } else if (
    type(references) == dictionary
  ) {
    document-references = references.pairs()
  }

  let inputs = (
    theme: eval-theme,
    locale: eval-locale,
    format: eval-locale.at("format", default: (:)),

    sender: sender,
    recipient: recipient,

    invoice-date: date,
    subject: document-subject,
    references: document-references,
    invoice-nr: invoice-nr,

    tax: document-tax,
    tax-mode: tax-mode,
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
