#import "../loom-wrapper.typ": data-motif, loom
#import "../utils/types.typ"
#import "../utils/coercion.typ"

/// An advance payment that reduces the amount due (BT-113, BT-115).
///
/// -> content
#let prepayment(
  /// An amount, e.g. `300`, or a percentage of the gross total.
  /// -> int | float | decimal | str | ratio
  amount,

  /// The name of the prepayment.
  /// -> str | content | auto | none
  name: auto,

  /// The label; `auto` is the locale's, `none` omits it.
  /// -> str | content | auto | none
  label: auto,

  /// The date of the prepayment.
  /// -> datetime | str | content | auto | none
  date: auto,

  /// A reference, e.g. an advance invoice number.
  /// -> str | content | auto | none
  reference: auto,

  /// A description of the prepayment.
  /// -> str | content | auto | none
  description: auto,

  /// The payment method, e.g. "PayPal".
  /// -> str | content | auto | none
  method: auto,
) = {
  types.require(
    amount,
    "prepayment::amount",
    types.decimal-like,
    types.ratio-like,
  )
  types.require(name, "prepayment::name", none, auto, types.text-like)
  types.require(label, "prepayment::label", none, auto, types.text-like)
  types.require(
    date,
    "prepayment::date",
    none,
    auto,
    types.date-like,
    types.text-like,
  )
  types.require-day(date, "prepayment::date")
  types.require(reference, "prepayment::reference", none, auto, types.text-like)
  types.require(
    description,
    "prepayment::description",
    none,
    auto,
    types.text-like,
  )
  types.require(method, "prepayment::method", none, auto, types.text-like)

  let is-relative = type(amount) == ratio
  let final-amount = if is-relative {
    calc.abs(amount)
  } else {
    calc.abs(coercion.to-decimal(amount))
  }

  data-motif(
    "prepayment",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      derive("prepayment-amount", final-amount)
      derive("name", name)
      derive("label", label, default: auto)
      derive("date", date)
      derive("reference", reference)
      derive("description", description)
      derive("method", method)

      nest("locale", {
        nest("normalize", {
          ensure("money", (..) => panic(
            "locale::normalize::money is not provided",
          ))
        })
        nest("format", {
          ensure("date", (..) => panic("locale::format::date is not provided"))
        })
      })
    }),
    measure: ctx => {
      loom.guards.assert-direct-parent(ctx, "line-items")
      let normalize = ctx.locale.normalize

      let raw-amount = ctx.prepayment-amount
      let amount-type = if is-relative { "relative" } else { "absolute" }
      let normalized-amount = if is-relative {
        coercion.to-ratio(raw-amount)
      } else {
        (normalize.money)(raw-amount)
      }

      let current-label = ctx.at("label", default: auto)
      let resolved-label = if current-label == auto {
        let strings = ctx.locale.at("strings", default: (:))
        let summary-strings = strings.at("summary", default: (:))
        summary-strings.at("prepayment", default: "Prepayment")
      } else if current-label == none {
        none
      } else {
        current-label
      }

      let resolved-name = if ctx.name == auto { none } else { ctx.name }
      let resolved-description = if ctx.description == auto { none } else {
        ctx.description
      }
      let resolved-reference = if ctx.reference == auto { none } else {
        ctx.reference
      }
      let resolved-method = if ctx.method == auto { none } else { ctx.method }

      let resolved-date = if ctx.date == auto or ctx.date == none {
        none
      } else if type(ctx.date) == datetime {
        (ctx.locale.format.date)(ctx.date)
      } else {
        ctx.date
      }

      return (
        name: resolved-name,
        label: resolved-label,
        date: resolved-date,
        reference: resolved-reference,
        description: resolved-description,
        method: resolved-method,
        type: amount-type,
        raw-amount: raw-amount,
        amount: normalized-amount,
      )
    },
  )
}
