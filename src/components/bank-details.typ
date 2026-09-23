#import "../loom-wrapper.typ": loom, managed-motif
#import "../utils/types.typ"
#import "../utils/coercion.typ"
#import "../utils/iban.typ": format-iban, iban-valid, normalize-iban
#import "../logic/payment-reference.typ": resolve-remittance

// With an e-invoice and `zugferd-errors: "report"`, problems are shown in the
// document instead of stopping the compilation.
#let _report-problems(ctx) = (
  ctx.at("zugferd", default: none) != none
    and ctx.at("zugferd-errors", default: "panic") == "report"
)

// What the root context holds for a sender without a name.
#let _is-missing(value) = (
  value in (none, "", [])
    or (type(value) == str and value.starts-with("#sender."))
)

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

  /// Configuration for a payment QR code (e.g., EPC-QR).
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

      nest("theme", {
        ensure("bank-details", (..) => panic(
          "theme::bank-details is not provided",
        ))
      })

      nest("global", {
        nest("total", {
          ensure("gross", 0)
        })
      })
    }),
    measure: (ctx, _) => {
      // The IBAN is checked here, independently of the theme, so that an
      // invalid one never ends up on an invoice unnoticed.
      let electronic-iban = normalize-iban(iban)
      let valid-iban = iban-valid(electronic-iban)
      let report-problems = _report-problems(ctx)
      if not valid-iban and not report-problems {
        panic(
          if electronic-iban == "" {
            "bank-details: the IBAN is missing. Set `iban` on `bank-details`."
          } else {
            (
              "bank-details: the IBAN \""
                + format-iban(electronic-iban)
                + "\" is not valid (wrong check digits or format). Check it for typos."
            )
          },
        )
      }

      // The account holder: the explicit `name`, else the sender's name on
      // one line, as in the e-invoice (BT-27).
      let holder = ctx.sender.name
      if name == auto {
        let inline = ctx.sender.at("name-inline", default: none)
        if not _is-missing(inline) { holder = inline }
      }

      let data = (
        sender: (
          name: holder,
          bank: bank,
          iban: electronic-iban,
          iban-valid: valid-iban,
          bic: bic,
        ),

        qr-code: (
          size: qr-code.at("size", default: 5em),
          display: qr-code.at("display", default: true),
        ),

        reference: ctx.reference,
        text: ctx.text,
        show-reference: show-reference,
        // Whether the theme shows problems (e.g. an IBAN the EPC-QR code
        // cannot carry) in the document instead of stopping the compilation.
        report-problems: report-problems,
        payment-amount: if payment-amount == auto {
          ctx.global.total.at("due", default: ctx.global.total.gross)
        } else {
          payment-amount
        },
      )

      // Expose IBAN/BIC/reference as a public signal so root can embed them in ZUGFeRD XML.
      let public = (
        iban: iban,
        bic: bic,
        reference: ctx.reference,
        text: ctx.text,
        payment-amount: data.payment-amount,
      )

      (public, data)
    },
    draw: (ctx, _, view, ..) => (ctx.theme.bank-details)(ctx, view),
    none,
  )
}
