#import "../loom-wrapper.typ": compute-motif, loom, weave
#import "../logic/modifier-applicator.typ": modifier-applicator
#import "../logic/calc-bundle.typ": calculate-bundle
#import "../logic/calc-item.typ": require-positive-base-quantity
#import "../utils/types.typ"
#import "../utils/coercion.typ"
#import "../data/unit.typ"
#import "../data/tax.typ" as m-tax
#import "../logic/unit.typ" as m-unit

/// Aggregates items into one line item (one per VAT rate).
///
/// -> content
#let bundle(
  /// The name of the bundle.
  /// -> str | content
  name,
  /// A description; `auto` joins the names of the bundled items.
  /// -> str | content | auto | none
  description: auto,

  /// The quantity, by default 1.
  /// -> int | float | decimal | str | auto
  quantity: auto,
  /// The quantity the price refers to, by default 1.
  /// -> int | float | decimal | str | auto
  base-quantity: auto,
  /// The unit of measurement.
  /// -> str | content | dictionary | auto | none
  unit: auto,

  /// The date or date range; `auto` spans the items' dates.
  /// -> datetime | array | auto | none
  date: auto,

  /// Whether the prices inside are gross.
  /// -> bool | auto
  input-gross: auto,
  /// The default tax of the items; `auto` inherits it.
  /// -> ratio | dictionary | auto
  tax: auto,

  /// An article identifier (a string or a dictionary).
  /// -> str | dictionary | auto | none
  item-id: auto,
  /// An optional reference string.
  /// -> str | auto | none
  reference: auto,

  /// The bundled items.
  /// -> content
  body,
) = {
  types.require(name, "bundle::name", types.text-like)
  types.require(description, "bundle::description", none, auto, types.text-like)

  types.require(quantity, "bundle::quantity", auto, types.decimal-like)
  types.require(
    base-quantity,
    "bundle::base-quantity",
    auto,
    types.decimal-like,
  )
  types.require(
    unit,
    "bundle::unit",
    none,
    auto,
    types.text-like,
    types.unit-input-type,
    dictionary,
    function,
  )

  types.require(date, "bundle::date", none, auto, types.date-like)
  types.require-day(date, "bundle::date")

  types.require(input-gross, "bundle::input-gross", auto, bool)
  types.require(tax, "bundle::tax", auto, types.tax-like)

  types.require(item-id, "bundle::item-id", none, auto, str, dictionary)
  types.require(reference, "bundle::reference", none, auto, str)

  types.require(body, "bundle::body", none, content)
  require-positive-base-quantity(base-quantity, "bundle")

  let bundle-quantity = if quantity == auto { decimal("1") } else {
    coercion.to-decimal(quantity)
  }
  let bundle-base-quantity = if base-quantity == auto { decimal("1") } else {
    coercion.to-decimal(base-quantity)
  }

  compute-motif(
    name: "bundle",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      derive("description", description)
      put("bundle-description", ctx.at("description", default: description))

      // A nested bundle's quantity is per unit of the enclosing bundle.
      remove("quantity")
      put("bundle-quantity", bundle-quantity)
      remove("base-quantity")
      put("bundle-base-quantity", bundle-base-quantity)
      // Kept apart from "unit", which cascades to the bundled items unresolved.
      let unit-input = if unit != auto { unit } else {
        ctx.at("unit", default: auto)
      }
      put(
        "bundle-unit",
        m-unit.resolve(
          unit-input,
          ctx.locale,
          quantity: bundle-quantity,
          default: m-unit.pcs,
        ),
      )
      // Singular form, to detect and name a shared unit.
      put(
        "bundle-unit-singular",
        m-unit.resolve(
          unit-input,
          ctx.locale,
          quantity: decimal("1"),
          default: m-unit.pcs,
        ),
      )

      derive("date", date)
      put("bundle-date", if date == auto {
        ctx.at("date", default: auto)
      } else {
        date
      })

      derive(
        "input-gross",
        input-gross,
        default: ctx.at("tax-mode", default: "exclusive") == "inclusive",
      )
      ensure("tax-mode", "exclusive")
      update("tax", t => m-tax.resolve(ctx, t, "bundle"))
      derive(
        "tax",
        m-tax.resolve(ctx, tax, "bundle"),
        default: m-tax.implicit-zero(),
      )

      derive("item-id", item-id)
      derive("reference", reference)

      remove("modifier")

      nest("locale", {
        nest("normalize", {
          ensure("money", (..) => panic(
            "locale::normalize::money is not provided",
          ))
          ensure("money-fine", (..) => panic(
            "locale::normalize::money-fine is not provided",
          ))
        })
      })
    }),
    measure: (ctx, children) => {
      loom.guards.assert-direct-parent(ctx, "line-items", "bundle", "group")
      return calculate-bundle(ctx, children, name)
    },
    (
      modifier-applicator,
    ).fold(body, (c, f) => f(c)),
  )
}
