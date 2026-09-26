#import "../loom-wrapper.typ": loom, managed-motif
#import "../utils/types.typ"
#import "../utils/coercion.typ"
#import "../utils/bic.typ": normalize-bic
#import "../utils/iban.typ": format-iban, iban-valid, normalize-iban
#import "../logic/epc.typ"
#import "../logic/payment-reference.typ": resolve-remittance
#import "../logic/document-type.typ": sender-pays
#import "../logic/payment-means.typ": (
  of-context, report-problems, transfer-requested,
)
#import "../logic/currency.typ": currency-code

// What the root context holds for a sender or recipient without a name.
#let _is-missing(value) = (
  value in (none, "", [])
    or (
      type(value) == str
        and (value.starts-with("#sender.") or value.starts-with("#recipient."))
    )
)

/// Defines and renders the bank account information for payments.
///
/// -> content
#let bank-details(
  /// The account holder. `auto`: the `payee` (not on a credit note), else the
  /// sender, or the recipient on a credit note or self-billed invoice.
  /// -> auto | none | string
  name: auto,

  /// The name of the banking institution.
  /// -> none | string
  bank: none,

  /// The IBAN, with or without spaces. Required; it is checked.
  /// -> none | string
  iban: none,

  /// The BIC; `none` omits it.
  /// -> none | string
  bic: none,

  /// The structured payment reference. `auto` falls back to the invoice's
  /// `payment-reference`, then to the `invoice-nr`; `none` omits it.
  /// -> auto | none | string
  reference: auto,

  /// An unstructured payment reference, instead of `reference`.
  /// -> none | string
  text: none,

  /// The amount to be paid; `auto` is the amount due.
  /// -> auto | none | decimal | float | int
  payment-amount: auto,

  /// Whether to show the payment reference.
  /// -> bool
  show-reference: true,

  /// A custom label of the account holder.
  /// -> auto
  account-holder-text: auto,

  /// The EPC-QR code `(size: .., display: ..)`, by default shown on a transfer.
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
      // Inside the line items, it would be printed but not stated.
      let _ = loom.guards.assert-not-inside(ctx, "line-items")
      let electronic-iban = normalize-iban(iban)
      let valid-iban = iban-valid(electronic-iban)
      let report = report-problems(ctx)
      if not valid-iban and not report {
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

      let document = ctx.at("document-type", default: none)
      let recipient-account = sender-pays(document)

      // `auto`: the payee (BG-10), not on a credit note, else the party paid.
      let credit = (
        type(document) == dictionary and document.at("credit", default: false)
      )
      let holder = ctx.sender.name
      if name == auto {
        let payee = ctx.at("payee", default: none)
        let payee-name = if type(payee) == dictionary and not credit {
          payee.at("name", default: none)
        }
        if not _is-missing(payee-name) {
          holder = if type(payee-name) == array {
            payee-name.join(", ")
          } else { payee-name }
        } else {
          let party = if recipient-account { ctx.recipient } else {
            ctx.sender
          }
          if recipient-account { holder = party.name }
          let inline = party.at("name-inline", default: none)
          if not _is-missing(inline) { holder = inline }
        }
      }

      let electronic-bic = normalize-bic(bic)
      let amount = if payment-amount == auto {
        ctx.global.total.at("due", default: ctx.global.total.gross)
      } else {
        payment-amount
      }

      // Generated only when shown, and in EUR only (SEPA).
      let qr-display = qr-code.at(
        "display",
        default: not recipient-account and transfer-requested(of-context(ctx)),
      )
      let epc-code = if qr-display and currency-code(ctx.locale) == "EUR" {
        epc.qr-code(
          holder,
          electronic-iban,
          bic: electronic-bic,
          reference: ctx.reference,
          text: ctx.text,
          amount: amount,
        )
      } else {
        (payload: none, problems: ())
      }

      // The view is documented in "Data for Custom Layouts" (theme.md).
      let data = (
        sender: (
          name: holder,
          bank: bank,
          iban: electronic-iban,
          iban-valid: valid-iban,
          bic: electronic-bic,
        ),

        qr-code: (
          size: qr-code.at("size", default: 5em),
          display: qr-display,
          payload: epc-code.payload,
          problems: epc-code.problems,
        ),

        reference: ctx.reference,
        text: ctx.text,
        show-reference: show-reference,
        report-problems: report,
        payment-amount: amount,
      )

      // The account name (BT-85) only if given: the default is BT-59 or BT-27.
      let public = (
        iban: iban,
        bic: bic,
        account-name: if name not in (auto, "") { name },
        reference: ctx.reference,
        text: ctx.text,
        payment-amount: data.payment-amount,
      )

      (public, data)
    },
    draw: (ctx, _, view, ..) => {
      // Stops in `draw`: the errors of components drawn before come first.
      let problems = view.qr-code.problems
      if problems.len() > 0 and not view.report-problems {
        panic(
          "bank-details: the EPC-QR code cannot be generated: "
            + problems.map(problem => problem.message).join("; ")
            + ". Hide it with `qr-code: (display: false)` on `bank-details` if it is not needed.",
        )
      }
      (ctx.theme.bank-details)(ctx, view)
    },
    none,
  )
}
