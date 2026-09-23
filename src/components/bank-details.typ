#import "../loom-wrapper.typ": loom, managed-motif
#import "../utils/types.typ"
#import "../theming/parts/body.typ": call-part
#import "@preview/sepay:0.1.1": epc-qr-code
#import "@preview/ibanator:0.1.0"
#import "../utils/coercion.typ"
#import "../logic/payment-reference.typ": resolve-remittance

/// Defines and renders the bank account information for payments.
///
/// The payment reference is resolved in this order: the `reference` or `text`
/// argument, the invoice's `payment-reference`, the `invoice-nr`. The resolved
/// value is printed, encoded in the EPC-QR code and written to the ZUGFeRD XML
/// (BT-83).
///
/// -> content
#let bank-details(
  /// The name of the account holder. Defaults to the sender's name.
  /// -> auto | none | string
  name: auto,

  /// The name of the banking institution.
  /// -> none | string
  bank: none,

  /// The International Bank Account Number (IBAN).
  /// -> none | string
  iban: none,

  /// The Bank Identifier Code (BIC/SWIFT). If omitted or `none`, the BIC is not displayed in the bank details block.
  /// -> none | string
  bic: none,

  /// The structured payment reference to be used by the customer.
  /// If `auto`, falls back to the invoice's `payment-reference` (as
  /// unstructured text) and then to the `invoice-nr`. `none` omits it.
  /// -> auto | none | string
  reference: auto,

  /// The unstructured payment reference text to be used by the customer.
  /// Takes precedence over the invoice's `payment-reference` and `invoice-nr`.
  /// -> none | string
  text: none,

  /// The specific amount to be paid. If `auto`, it uses the document total.
  /// -> auto | none | decimal | float | int
  payment-amount: auto,

  /// Whether to display the reference field in the output.
  /// -> bool
  show-reference: true,

  /// Optional custom text to label the account holder field.
  /// -> auto
  account-holder-text: auto,

  /// Configuration for a payment QR code (e.g., EPC-QR): `display` (bool) and
  /// `size` (length, at least 20mm), which overrides the theme's QR size.
  /// -> dictionary
  qr-code: (:),
) = {
  types.require(name, "bank-details::name", none, auto, str)
  types.require(bank, "bank-details::bank", none, str)
  types.require(iban, "bank-details::iban", none, str)
  types.require(bic, "bank-details::bic", none, str)

  types.require(reference, "bank-details::reference", none, auto, str)
  types.require(text, "bank-details::text", none, str)
  types.require(
    payment-amount,
    "bank-details::payment-amount",
    none,
    auto,
    types.decimal-like,
  )

  types.require(show-reference, "bank-details::show-reference", bool)

  assert(
    (reference == auto or reference == none) or text == none,
    message: "Cannot specify both 'reference' and 'text'. Use one or the other.",
  )

  if name == none { name = "" }
  if iban == none { iban = "" }
  if bank == none { bank = "" }
  if bic == none { bic = "" }
  if payment-amount == none { payment-amount = 0 }
  if payment-amount != auto {
    payment-amount = coercion.to-decimal(payment-amount)
  }

  managed-motif(
    "bank-details",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      derive("sender", "name", name, default: "")

      let remittance = resolve-remittance(
        ctx,
        reference: reference,
        text: text,
      )
      put("reference", remittance.reference)
      put("text", remittance.text)

      nest("global", {
        nest("total", {
          ensure("gross", 0)
        })
      })
    }),
    measure: (ctx, _) => {
      let data = (
        sender: (
          name: ctx.sender.name,
          bank: bank,
          iban: iban,
          bic: bic,
        ),

        qr-code: (
          size: qr-code.at("size", default: auto),
          display: qr-code.at("display", default: true),
        ),

        reference: ctx.reference,
        text: ctx.text,
        show-reference: show-reference,
        // v2: IBAN as (value: normalised, text: grouped in fours), and the one
        // string the payer must quote (structured reference or unstructured text)
        // `valid`: ISO 13616 check (ibanator); an invalid IBAN is a data issue
        // (root), never a panic in a renderer, and gets no QR code
        iban: {
          let v = upper(iban.replace(regex("\s"), ""))
          (
            value: v,
            text: range(0, v.len(), step: 4)
              .map(i => v.slice(i, calc.min(v.len(), i + 4)))
              .join("\u{00A0}", default: ""),
            valid: v == "" or ibanator.lib.check_iban(bytes(v)).at(0) == 1,
          )
        },
        payment-reference: if ctx.text != none { ctx.text } else {
          ctx.reference
        },
        payment-amount: if payment-amount == auto {
          ctx.global.total.at("due", default: ctx.global.total.gross)
        } else {
          payment-amount
        },
      )

      // CORE builds the EPC-QR payload (EUR only, amount >= 0.10, text vs reference).
      // The part may only choose placement/size (a size given here wins); size is
      // clamped to >= 20 mm and the code is always black on white.
      let cur = ctx.locale.currency.code
      data.qr = if (
        cur != "EUR" or not data.qr-code.display or not data.iban.valid
      ) { none } else {
        let payload = (
          (
            bic: bic,
            amount: if float(data.payment-amount) >= 0.1 {
              float(data.payment-amount)
            },
          )
            + if ctx.text != none { (text: ctx.text) } else if ctx.reference
              != none { (reference: ctx.reference) }
        )
        let holder = ctx.sender.name
        let fixed = data.qr-code.size
        let code(s) = {
          let s = calc.max(s, 20mm)
          box(fill: white, inset: 1mm, epc-qr-code(
            holder,
            iban,
            ..payload,
            width: s,
            height: s,
          ))
        }
        size => {
          let size = if fixed == auto { size } else { fixed }
          // an em size needs the font size, so only it is resolved in context
          if size.em == 0 { code(size.abs) } else {
            context code(size.to-absolute())
          }
        }
      }

      // Expose IBAN/BIC/reference as a public signal so root can embed them in ZUGFeRD XML.
      let public = (
        iban: iban,
        iban-valid: data.iban.valid,
        bic: bic,
        reference: ctx.reference,
        text: ctx.text,
        payment-amount: data.payment-amount,
      )

      (public, data)
    },
    draw: (ctx, _, view, ..) => call-part(ctx, "bank-details", view),
    none,
  )
}
