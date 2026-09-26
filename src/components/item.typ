#import "../loom-wrapper.typ": data-motif, loom, loom-key
#import "../logic/calc-item.typ": (
  calculate-item-data, require-positive-base-quantity,
)
#import "../utils/types.typ"
#import "../utils/coercion.typ"
#import "../data/tax.typ" as m-tax
#import "../public/unit.typ" as m-unit
#import "../logic/unit.typ" as unit-logic

/// Normalizes a modifier.
///
/// -> dictionary | none
#let normalize-modifier(
  /// The loom context.
  /// -> dictionary
  ctx,
  /// The modifier to normalize.
  /// -> content | dictionary
  modifier,
) = {
  let modifier-type = type(modifier)
  if modifier-type == content {
    let (_, frames) = loom.core.intertwine(
      key: loom-key,
      loom.path.append(ctx, "line-items"),
      modifier,
    )

    let signals = loom.query.collect-signals(frames, kind: "modifier")

    signals.map(s => (
      name: s.name,
      label: s.at("label", default: auto),
      amount: if s.type == "relative" { float(s.amount) * 100% } else {
        s.amount
      },
      description: s.description,
      tax: s.at("tax", default: none),
    ))
  } else if modifier-type == dictionary {
    modifier
  } else {
    none
  }
}

/// Evaluates modifiers into a flat array.
///
/// -> array
#let evaluate-modifier(
  /// The loom context.
  /// -> dictionary
  ctx,
  /// The modifier(s) to evaluate.
  /// -> auto | array | content | dictionary
  modifier,
) = {
  let modifier-type = type(modifier)

  if modifier == auto { return auto }

  if modifier-type == array {
    modifier.map(normalize-modifier.with(ctx)).flatten()
  } else if modifier-type == content {
    (normalize-modifier(ctx, modifier),).flatten()
  } else if modifier-type == dictionary {
    (modifier,)
  } else {
    ()
  }.filter(m => m != none)
}

/// A line item: a product or service on the invoice.
///
/// -> content
#let item(
  /// The name of the item.
  /// -> str | content
  name,
  /// A description of the item.
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

  /// The date or date range of the supply.
  /// -> datetime | array | auto | none
  date: auto,

  /// The price per unit; give it or `total`, not both.
  /// -> int | float | decimal | str | auto
  price: auto,
  /// The total price; give it or `price`, not both.
  /// -> int | float | decimal | str | auto
  total: auto,

  /// Whether `price` or `total` includes tax.
  /// -> bool | auto
  input-gross: auto,

  /// The tax of the item, e.g. `19%`; `auto` inherits it.
  /// -> ratio | dictionary | auto
  tax: auto,

  /// An article identifier (a string or a dictionary).
  /// -> str | dictionary | auto | none
  item-id: auto,
  /// An optional reference string.
  /// -> str | auto | none
  reference: auto,

  /// A note, printed below the description (BT-127). Not inside a `bundle`.
  /// -> str | content | auto | none
  note: auto,
  /// The country of origin (BT-159), e.g. `"DE"`; not inside a `bundle`.
  /// -> function | dictionary | str | auto | none
  origin: auto,

  /// The discounts and surcharges of the item.
  /// -> array | auto | none
  modifier: auto,
) = {
  types.require(name, "item::name", types.text-like)
  types.require(description, "item::description", none, auto, types.text-like)

  types.require(quantity, "item::quantity", auto, types.decimal-like)
  types.require(base-quantity, "item::base-quantity", auto, types.decimal-like)
  require-positive-base-quantity(base-quantity, "item")
  types.require(
    unit,
    "item::unit",
    none,
    auto,
    types.text-like,
    types.unit-input-type,
    dictionary,
    function,
  )

  types.require(date, "item::date", none, auto, types.date-like)
  types.require-day(date, "item::date")

  types.require(price, "item::price", auto, types.decimal-like)
  types.require(total, "item::total", auto, types.decimal-like)
  assert(
    price == auto or total == auto,
    message: "You can only specify the price or the total not both. The other value will be calculated automatically.",
  )

  types.require(input-gross, "item::input-gross", auto, bool)
  types.require(tax, "item::tax", auto, ratio, types.tax-like)

  types.require(item-id, "item::item-id", none, auto, str, dictionary)
  types.require(reference, "item::reference", none, auto, str)
  // Checked only if given, as most items have neither.
  if note != auto { types.require(note, "item::note", none, types.text-like) }
  if origin != auto {
    types.require(
      origin,
      "item::origin",
      none,
      types.text-like,
      dictionary,
      function,
    )
  }

  types.require(
    modifier,
    "item::modifier",
    none,
    auto,
    content,
    loom.matcher.many(loom.matcher.choice(
      types.modifier-like,
      content,
    )),
  )

  data-motif(
    "item",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      derive("description", description)

      derive("quantity", coercion.to-decimal(quantity), default: decimal("1"))
      derive(
        "base-quantity",
        coercion.to-decimal(base-quantity),
        default: decimal("1"),
      )
      // Else the unresolved unit a `group` or `apply` cascades.
      let unit-input = if unit != auto { unit } else {
        ctx.at("unit", default: auto)
      }
      put(
        "unit",
        unit-logic.resolve(
          unit-input,
          ctx.locale,
          quantity: if quantity != auto { coercion.to-decimal(quantity) } else {
            ctx.at("quantity", default: decimal("1"))
          },
          default: m-unit.pc,
        ),
      )
      // Singular form, to detect and name a shared unit.
      put(
        "unit-singular",
        unit-logic.resolve(
          unit-input,
          ctx.locale,
          quantity: decimal("1"),
          default: m-unit.pc,
        ),
      )

      derive("date", coercion.to-date(date))

      derive("item-price", coercion.to-decimal(price), default: auto)
      derive("item-total", coercion.to-decimal(total), default: auto)

      ensure("tax-mode", "exclusive")
      derive(
        "input-gross",
        input-gross,
        default: ctx.at("tax-mode", default: "exclusive") == "inclusive",
      )
      update("tax", t => m-tax.resolve(ctx, t, "item"))
      derive(
        "tax",
        m-tax.resolve(ctx, tax, "item"),
        default: m-tax.implicit-zero(),
      )

      if ctx.at("tax-exempt-small-biz", default: false) {
        put("tax", ctx.locale.tax.small-enterprise-special-scheme)
      }

      derive("item-id", item-id)
      derive("reference", reference)
      if note != auto { put("note", note) }
      if origin != auto { put("origin", origin) }
      if (
        (note not in (auto, none) or origin not in (auto, none))
          and ctx.at("bundle-quantity", default: none) != none
      ) {
        panic(
          "item::note and item::origin are not supported on an item inside a `bundle`: the bundle is one line of the invoice, which prints and states neither the note nor the country of origin of its items. Mention them in the `description` of the bundle, or list the item outside the bundle.",
        )
      }

      derive("modifier", evaluate-modifier(ctx, modifier), default: ())
      update("modifier", evaluate-modifier.with(ctx))

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
    measure: ctx => {
      loom.guards.assert-direct-parent(ctx, "line-items", "bundle", "group")
      return calculate-item-data(ctx, name)
    },
  )
}
