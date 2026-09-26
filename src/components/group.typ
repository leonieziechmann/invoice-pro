#import "../loom-wrapper.typ": compute-motif, loom
#import "../utils/types.typ"
#import "../utils/coercion.typ"
#import "../data/tax.typ" as m-tax
#import "../data/unit.typ"

/// A section of line items with hierarchical positions and a subtotal.
///
/// -> content
#let group(
  /// The name of the group.
  /// -> str | content
  name,
  /// A description of the group.
  /// -> str | content | auto | none
  description: none,

  /// Whether to show a subtotal row; `auto` shows it.
  /// -> bool | auto
  show-subtotal: auto,

  /// The default tax of the items in the group.
  /// -> ratio | dictionary | auto
  tax: auto,
  /// Whether the prices in the group are gross.
  /// -> bool | auto
  input-gross: auto,
  /// The default date or date range of the items.
  /// -> datetime | array | auto | none
  date: auto,
  /// The default unit of the items.
  /// -> str | content | dictionary | auto | none
  unit: auto,

  /// The grouped items.
  /// -> content
  body,
) = {
  types.require(name, "group::name", types.text-like)
  types.require(description, "group::description", none, auto, types.text-like)
  types.require(show-subtotal, "group::show-subtotal", auto, bool)

  types.require(tax, "group::tax", auto, types.tax-like)
  types.require(input-gross, "group::input-gross", auto, bool)
  types.require(date, "group::date", none, auto, types.date-like)
  types.require-day(date, "group::date")
  types.require(
    unit,
    "group::unit",
    none,
    auto,
    types.text-like,
    types.unit-input-type,
    dictionary,
    function,
  )

  types.require(body, "group::body", none, content)

  compute-motif(
    name: "group",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      if description != auto and description != none {
        put("group-description", description)
      }

      if input-gross != auto {
        put("input-gross", input-gross)
      }

      if date != auto and date != none {
        derive("date", coercion.to-date(date))
      }

      if tax != auto {
        update("tax", t => if type(t) != ratio { t } else {
          let infer-tax = ctx
            .at("locale", default: (:))
            .at("normalize", default: (:))
            .at("infer-tax", default: (..) => panic(
              "group::tax can not be of type `ratio`.",
            ))
          infer-tax(t)
        })
        derive(
          "tax",
          {
            if type(tax) == ratio {
              let infer-tax = ctx
                .at("locale", default: (:))
                .at("normalize", default: (:))
                .at("infer-tax", default: (..) => panic(
                  "group::tax can not be of type `ratio`.",
                ))
              infer-tax(tax)
            } else {
              m-tax.to-tax(tax)
            }
          },
          default: m-tax.zero(),
        )
      }

      // Unresolved: each item resolves it with its own quantity ("2 hours").
      if unit != auto and unit != none {
        put("unit", unit)
      }
    }),
    measure: (ctx, children) => {
      loom.guards.assert-direct-parent(ctx, "line-items", "group")
      return (
        kind: "group",
        name: name,
        description: if description == auto { none } else { description },
        show-subtotal: if show-subtotal == auto { true } else { show-subtotal },
        children: children,
      )
    },
    body,
  )
}
