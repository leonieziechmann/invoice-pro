#import "../loom-wrapper.typ": loom, managed-motif
#import "../utils/types.typ"
#import "../utils/coercion.typ"

#let bank-details(
  name: auto,
  bank: none,
  iban: none,
  bic: none,

  reference: auto,
  payment-amount: auto,

  show-reference: true,
  account-holder-text: auto,
  qr-code: (:),
) = {
  types.require(name, "bank-details::name", none, auto, str)
  types.require(bank, "bank-details::bank", none, str)
  types.require(iban, "bank-details::iban", none, str)
  types.require(bic, "bank-details::bic", none, str)

  types.require(reference, "bank-details::reference", none, auto, str)
  types.require(
    payment-amount,
    "bank-details::payment-amount",
    none,
    auto,
    types.decimal-like,
  )

  types.require(show-reference, "bank-details::show-reference", bool)

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
      derive("reference", reference)

      nest("theme", {
        ensure("bank-details", (..) => [Bank Details])
      })

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
          size: qr-code.at("size", default: 5em),
          display: qr-code.at("display", default: true),
        ),

        reference: ctx.reference,
        show-reference: show-reference,
        payment-amount: if payment-amount == auto {
          ctx.global.total.gross
        } else {
          payment-amount
        },
      )

      (none, data)
    },
    draw: (ctx, _, view, ..) => (ctx.theme.bank-details)(ctx, view),
    none,
  )
}
