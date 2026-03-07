#import "../loom-wrapper.typ": loom, managed-motif
#import "../logic/modifier-applicator.typ": modifier-applicator
#import "../logic/tax-applicator.typ": tax-applicator
#import "../utils/coercion.typ"
#import "../utils/types.typ"
#import "../data/tax.typ" as m-tax
#import "../layout/line-item-layout.typ": render-invoice

/// The root container for all invoice items, bundles, and modifiers.
/// It establishes overarching tax settings, manages the global application of modifiers,
/// and handles the formatting of the generated invoice data.
///
/// -> content
#let line-items(
  /// Defines whether the input prices within this container are treated as gross (inclusive of tax) by default. Defaults to `false`.
  /// -> bool | auto
  input-gross: auto,

  /// The default tax rate or tax dictionary applied to the items within this container. Defaults to a zero tax rate.
  /// -> ratio | dictionary | auto
  tax: auto,
  /// Determines how taxes are calculated globally. Defaults to `"exclusive"`.
  /// "exclusive" | "inclusive" | auto
  tax-mode: auto,

  /// Whether to show the quantity column. `auto` hides it if all quantities are 1.
  /// -> bool | auto
  show-quantity: auto,
  /// Whether to show the VAT column per item. `auto` shows it if VAT rates differ.
  /// -> bool | auto
  show-vat-per-item: auto,

  /// The content block containing the `item`s, `bundle`s, and `modifier`s.
  /// -> content
  body,
) = {
  types.require(input-gross, "line-items::input-gross", auto, bool)

  types.require(tax, "line-items::tax", auto, types.tax-like)
  types.require(
    tax-mode,
    "line-items::tax-mode",
    auto,
    "exclusive",
    "inclusive",
  )

  managed-motif(
    "line-items",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      derive("input-gross", input-gross, default: tax-mode == "inclusive")

      derive("tax", tax, default: m-tax.zero())
      derive("tax-mode", tax-mode, default: "exclusive")

      nest("format", {
        ensure("percent", x => str(calc.round(x * 100)) + "%")
        ensure("number", x => str(x))
        ensure("currency", x => str(calc.round(x, digits: 2)) + "€")
        ensure("currency-fine", x => str(calc.round(x, digits: 4)) + "€")
        ensure("date", date => {
          if type(date) == datetime { date.display() } else if (
            type(date) == array
          ) { date.first().display() + " - " + date.last().display() } else {
            none
          }
        })
      })
    }),
    measure: (ctx, children) => {
      let modifier-applicator = loom.query.find-signal(
        children,
        "modifier-applicator",
      )
      let tax-applicator = loom.query.find-signal(children, "tax-applicator")
      let items = modifier-applicator.items

      let formated-items = items.map(item => loom.mutator.batch(item, {
        import loom.mutator: *

        update("name", x => [#x])
        put("has-description", item.description != none)
        update("description", x => [#x])

        put("has-date", item.date != none)
        update("date", ctx.format.date)

        update("quantity", ctx.format.number)
        update("base-quantity", ctx.format.number)

        update("unit", x => [#x])

        update("price", ctx.format.currency-fine)
        update("total", ctx.format.currency)

        update("tax", x => (
          rate: (ctx.format.percent)(x.rate),
          category: x.category,
        ))

        put("has-discounts", item.discounts.len() >= 1)
        update("discounts", discounts => discounts.map(d => {
          let display-format = if d.type == "relative" {
            ctx.format.percent
          } else { ctx.format.currency }
          (
            name: [#d.name],
            description: [#d.description],
            display: display-format(d.display),
            has-description: d.description != none,
          )
        }))

        put("has-surcharge", item.surcharge.len() >= 1)
        update("surcharge", discounts => discounts.map(s => {
          let display-format = if s.type == "relative" {
            ctx.format.percent
          } else { ctx.format.currency }
          (
            name: [#s.name],
            description: [#s.description],
            display: display-format(s.display),
            has-description: s.description != none,
          )
        }))

        put("has-item-id", item.item-id != none)
        put("has-reference", item.reference != none)
      }))

      let formated-taxes = tax-applicator
        .taxes
        .pairs()
        .map(((key, tax)) => {
          let formated-rate = (ctx.format.percent)(tax.rate)
          let formated-value = (ctx.format.currency)(tax.absolute)
          (
            rate: [#formated-rate],
            category: [#tax.category],
            amount: [#formated-value],
          )
        })

      let formated-total = (
        net: (ctx.format.currency)(tax-applicator.net-total),
        gross: (ctx.format.currency)(tax-applicator.gross-total),
      )

      let formated-discounts = modifier-applicator.modifier.discounts.map(
        discount => loom.mutator.batch(discount, {
          import loom.mutator: *

          update("name", x => [#x])
          update("description", x => [#x])

          remove("type")
          update("display", d => {
            if discount.type == "absolute" [#(ctx.format.currency)(
              calc.abs(d),
            )] else [#(ctx.format.percent)(calc.abs(d)) (#(ctx.format.currency)(discount.absolute))]
          })
          remove("absolute")

          if discount.type == "relative" { put("split", (:)) }
          update("split", split => split
            .pairs()
            .map(((_, group)) => {
              (
                tax: (
                  rate: [#(ctx.format.percent)(group.tax.rate)],
                  category: [#group.tax.category],
                ),
                amount: [#(ctx.format.currency)(calc.abs(group.absolute))],
              )
            }))
        }),
      )

      let formated-surcharges = modifier-applicator.modifier.surcharges.map(
        surcharge => loom.mutator.batch(surcharge, {
          import loom.mutator: *

          update("name", x => [#x])
          update("description", x => [#x])

          remove("type")
          update("display", d => {
            if surcharge.type == "absolute" [#(ctx.format.currency)(
              calc.abs(d),
            )] else [#(ctx.format.percent)(calc.abs(d))]
          })
          remove("absolute")

          if surcharge.type == "relative" { put("split", (:)) }
          update("split", split => split
            .pairs()
            .map(((_, group)) => {
              (
                tax: (
                  rate: [#(ctx.format.percent)(group.tax.rate)],
                  category: [#group.tax.category],
                ),
                amount: [#(ctx.format.currency)(calc.abs(group.absolute))],
              )
            }))
        }),
      )

      let item-dates = items.map(i => i.date).filter(i => i != none).dedup()

      let item-information = (
        has-dates: item-dates.len() != 0,
        multiple-dates: item-dates.len() > 1,
        multiple-quantities: items.map(i => i.quantity).dedup().len() > 1,
        multiple-units: items.map(i => i.unit).dedup().len() > 1,
        multiple-tax-rates: items.map(i => i.tax).dedup().len() > 1,
      )

      let view = (
        items: formated-items,
        discounts: formated-discounts,
        surcharges: formated-surcharges,
        taxes: formated-taxes,
        total: formated-total,
        layout-information: item-information,
      )

      return (1, view)
    },
    draw: (ctx, _, view, body) => {
      [= Line Items]
      render-invoice(view)
      body
    },
    (
      modifier-applicator,
      tax-applicator,
    ).fold(body, (c, f) => f(c)),
  )
}
