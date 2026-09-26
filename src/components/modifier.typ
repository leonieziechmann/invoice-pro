#import "../loom-wrapper.typ": data-motif, loom
#import "../utils/types.typ"
#import "../utils/coercion.typ"
#import "../data/tax.typ" as m-tax

/// A discount or surcharge of an item, a bundle or the whole invoice.
///
/// -> content
#let modifier(
  /// The name of the modifier.
  /// -> str | content
  name,
  /// The label; `auto` is the locale's, `none` omits it.
  /// -> none | auto | str | content
  label: auto,
  /// A description of the modifier.
  /// -> str | content | auto | none
  description: auto,
  /// A percentage or an amount; negative for a discount.
  /// -> ratio | int | float | decimal | str | auto
  amount: auto,
  /// Whether an amount is gross; `auto` inherits it.
  /// -> bool | auto
  input-gross: auto,
  /// Internal; `auto` by the sign of `amount`.
  /// -> bool | auto
  is-discount: auto,
  /// The VAT category, e.g. `tax.vat(19%)`; `auto` spreads it over all.
  /// -> ratio | dictionary | auto
  tax: auto,
) = {
  types.require(name, "modifier::name", types.text-like)
  types.require(label, "modifier::label", none, auto, types.text-like)
  types.require(
    description,
    "modifier::description",
    none,
    auto,
    description,
    types.text-like,
  )
  types.require(
    amount,
    "modifier::amount",
    auto,
    types.decimal-like,
    types.ratio-like,
  )
  types.require(input-gross, "modifier::input-gross", auto, bool)
  types.require(tax, "modifier::tax", auto, types.tax-like)

  data-motif(
    "modifier",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      // Not cascaded: the context's `tax` is the items' default.
      let small-biz = ctx.at("tax-exempt-small-biz", default: false)
      put("modifier-tax", if tax == auto { none } else if small-biz {
        ctx.locale.tax.small-enterprise-special-scheme
      } else {
        m-tax.resolve(ctx, tax, "modifier")
      })
      derive("modifier-amount", amount, default: decimal("0"))
      derive("description", description)
      derive(
        "input-gross",
        input-gross,
        default: ctx.at("tax-mode", default: "exclusive") == "inclusive",
      )
      derive("label", label, default: auto)

      nest("locale", {
        nest("normalize", {
          ensure("money", (..) => panic(
            "locale::normalize::money is not provided",
          ))
        })
      })
    }),
    measure: ctx => {
      loom.guards.assert-direct-parent(ctx, "line-items", "bundle")
      let normalize = ctx.locale.normalize

      let raw-amount = ctx.modifier-amount

      let amount = 0
      let amount-type = none

      if type(raw-amount) == ratio {
        amount = coercion.to-ratio(raw-amount)
        amount-type = "relative"
      } else {
        amount = (normalize.money)(raw-amount)
        amount-type = "absolute"
      }

      let discount-mode = if is-discount != auto {
        is-discount
      } else {
        amount < 0
      }

      let current-label = ctx.at("label", default: auto)
      let resolved-label = if current-label == auto {
        let strings = ctx
          .locale
          .at("strings", default: (:))
          .at(
            "line-items",
            default: (:),
          )
        if discount-mode {
          strings.at("discount", default: "Discount")
        } else {
          strings.at("surcharge", default: "Surcharge")
        }
      } else if current-label == none {
        none
      } else {
        current-label
      }

      return (
        name: name,
        label: resolved-label,
        description: ctx.description,

        type: amount-type,
        amount: amount,

        is-gross: ctx.input-gross,
        tax: ctx.modifier-tax,
      )
    },
  )
}

#let discount(
  /// The name of the discount.
  /// -> str | content
  name,
  /// The label; `auto` is the locale's, `none` omits it.
  /// -> none | auto | str | content
  label: auto,
  /// A description of the discount.
  /// -> str | content | auto | none
  description: auto,
  /// The value of the discount. Must be positive.
  /// -> ratio | int | float | decimal | str
  amount: 0,
  /// Whether an amount is gross; `auto` inherits it.
  /// -> bool | auto
  input-gross: auto,
  /// The VAT category, see `modifier`.
  /// -> ratio | dictionary | auto
  tax: auto,
) = {
  types.require(label, "discount::label", none, auto, types.text-like)
  types.require(
    amount,
    "discount::amount",
    types.decimal-like,
    types.ratio-like,
  )

  let final-amount = 0
  if type(amount) == ratio {
    assert(amount >= 0%, message: "discount::amount must be positive!")
    final-amount = -amount
  } else {
    let normalized-amount = coercion.to-decimal(amount)
    assert(
      normalized-amount >= 0,
      message: "discount::amount must be positive!",
    )
    final-amount = -normalized-amount
  }

  modifier(
    name,
    label: label,
    description: description,
    amount: final-amount,
    input-gross: input-gross,
    is-discount: true,
    tax: tax,
  )
}

#let surcharge(
  /// The name of the surcharge.
  /// -> str | content
  name,
  /// The label; `auto` is the locale's, `none` omits it.
  /// -> none | auto | str | content
  label: auto,
  /// A description of the surcharge.
  /// -> str | content | auto | none
  description: auto,
  /// The value of the surcharge. Must be positive.
  /// -> ratio | int | float | decimal | str
  amount: 0,
  /// Whether an amount is gross; `auto` inherits it.
  /// -> bool | auto
  input-gross: auto,
  /// The VAT category, see `modifier`.
  /// -> ratio | dictionary | auto
  tax: auto,
) = {
  types.require(label, "surcharge::label", none, auto, types.text-like)
  types.require(
    amount,
    "surcharge::amount",
    types.decimal-like,
    types.ratio-like,
  )

  let final-amount = 0
  if type(amount) == ratio {
    assert(amount >= 0%, message: "surcharge::amount must be positive!")
    final-amount = amount
  } else {
    let normalized-amount = coercion.to-decimal(amount)
    assert(
      normalized-amount >= 0,
      message: "surcharge::amount must be positive!",
    )
    final-amount = normalized-amount
  }

  modifier(
    name,
    label: label,
    description: description,
    amount: final-amount,
    input-gross: input-gross,
    is-discount: false,
    tax: tax,
  )
}
