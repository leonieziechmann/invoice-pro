#import "../loom-wrapper.typ": compute-motif, loom
#import "../utils/coercion.typ"
#import "../data/tax.typ" as m-tax
#import "group-by-tax.typ": group-by-tax, with-tax-group

// The name of a modifier in error messages.
#let _describe(modifier) = {
  let name = coercion.to-string(modifier.name)
  let amount = str(modifier.amount).replace("\u{2212}", "-")
  if type(name) == str and name.trim() != "" {
    "The modifier `" + name.trim() + "` (" + amount + ")"
  } else { "A modifier of " + amount }
}

#let _pin-hint = (
  " Pin it to one VAT category with `tax:`, e.g."
    + " `surcharge([Shipping], amount: 5, tax: tax.vat(19%))`."
)

// The VAT groups an absolute modifier is spread over: the one it is pinned
// to, else those whose total has the sign of the whole total, so that a
// voucher never turns into a charge on credited lines.
#let _allocation-keys(modifier, tax-groups) = {
  let pinned = modifier.at("tax", default: none)
  if pinned != none { return (m-tax.to-tax-key(pinned),) }

  let groups = tax-groups.groups
  if groups.len() == 1 { return groups.keys() }
  if groups.len() == 0 {
    panic(
      _describe(modifier)
        + " has no items to take its VAT category from."
        + _pin-hint,
    )
  }

  let base-total = tax-groups.total
  let keys = if base-total > 0 {
    groups.keys().filter(key => groups.at(key).total > 0)
  } else if base-total < 0 {
    groups.keys().filter(key => groups.at(key).total < 0)
  } else { () }
  if keys.len() == 0 {
    panic(
      _describe(modifier)
        + " cannot be split over the VAT categories "
        + groups.values().map(g => m-tax.describe(g.tax)).join(", ")
        + ", because their items add up to 0."
        + _pin-hint,
    )
  }
  keys
}

#let apply-mod(ctx, tax-groups, modifier) = {
  let normalize = ctx.locale.normalize
  let modifier-total = decimal("0")
  let tax-split = (:)
  let pinned = modifier.at("tax", default: none)

  let is-net-based = ctx.tax-mode == "exclusive"
  let mod-is-gross = modifier.is-gross
  let needs-adjustment = (
    (is-net-based and mod-is-gross) or (not is-net-based and not mod-is-gross)
  )

  let effective-amount = modifier.amount

  if modifier.type == "relative" {
    for (key, group) in tax-groups.groups {
      if pinned != none and key != m-tax.to-tax-key(pinned) { continue }
      let group-modifier = (normalize.money)(group.total * effective-amount)
      modifier-total += group-modifier
      tax-split.insert(key, (
        tax: (
          rate: group.tax.rate,
          category: group.tax.category,
          absolute: group.tax.rate * group-modifier,
        ),
        absolute: group-modifier,
      ))
    }
  } else if effective-amount != 0 {
    let keys = _allocation-keys(modifier, tax-groups)
    let groups = keys.map(key => tax-groups.groups.at(key))

    if needs-adjustment {
      // Gross to net or back with the mix of VAT rates of its groups.
      let scope-net-total = decimal("0")
      let scope-gross-total = decimal("0")
      for group in groups {
        if is-net-based {
          scope-net-total += group.total
          scope-gross-total += group.total * (1 + group.tax.rate)
        } else {
          scope-net-total += group.total / (1 + group.tax.rate)
          scope-gross-total += group.total
        }
      }
      if scope-net-total == 0 or scope-gross-total == 0 {
        scope-net-total = decimal("1")
        scope-gross-total = 1 + groups.first().tax.rate
      }
      let conversion-ratio = if is-net-based {
        scope-net-total / scope-gross-total
      } else { scope-gross-total / scope-net-total }
      effective-amount = (normalize.money)(modifier.amount * conversion-ratio)
    }

    // Spread proportionally over the groups, whose totals share one sign; the
    // rounding difference goes to the largest group.
    let base-total = groups.map(group => group.total).sum()
    let left-over-total = effective-amount
    let largest-group = none
    let largest-group-total = decimal("-1")

    for (key, group) in keys.zip(groups) {
      let group-modifier = if keys.len() == 1 { effective-amount } else {
        (normalize.money)(effective-amount * (group.total / base-total))
      }

      tax-split.insert(key, (
        tax: (
          rate: group.tax.rate,
          category: group.tax.category,
        ),
        absolute: group-modifier,
      ))

      if calc.abs(group.total) > largest-group-total {
        largest-group = key
        largest-group-total = calc.abs(group.total)
      }

      modifier-total += group-modifier
      left-over-total -= group-modifier
    }

    if left-over-total != 0 {
      tax-split.at(largest-group).absolute += left-over-total
      modifier-total += left-over-total
    }
  }

  return (
    name: modifier.name,
    label: modifier.at("label", default: none),
    description: modifier.description,

    type: modifier.type,
    display: effective-amount,
    absolute: modifier-total,

    split: tax-split,
  )
}

// The share of every modifier in each VAT group: `(key: (modifier, ..))`,
// without the modifiers that have none in it.
#let modifiers-by-tax(modifiers, tax-rates) = {
  return tax-rates
    .keys()
    .map(key => (
      key,
      modifiers
        .filter(mod => key in mod.split)
        .map(mod => (
          name: mod.name,
          label: mod.at("label", default: none),
          description: mod.description,

          type: mod.type,
          display: if mod.type == "relative" { mod.display } else {
            mod.split.at(key).absolute
          },
          absolute: mod.split.at(key).absolute,
        )),
    ))
    .to-dict()
}

#let calculate-modifier(ctx, children) = {
  let items = loom.query.collect-signals(children, kind: "item", depth: 10)
  let modifiers = loom.query.collect-signals(children, kind: "modifier")

  let tax-groups = group-by-tax(items)
  // An absolute amount pinned to a VAT category no item has adds it; a
  // percentage of it is 0 and adds none (no empty VAT or bundle line).
  for mod in modifiers {
    let pinned = mod.at("tax", default: none)
    if pinned == none { continue }
    if (
      m-tax.to-tax-key(pinned) in tax-groups.groups
        or (mod.type == "absolute" and mod.amount != 0)
    ) {
      tax-groups = with-tax-group(tax-groups, pinned)
    }
  }

  let tax-rates = tax-groups
    .groups
    .pairs()
    .map(((key, group)) => (
      key,
      (rate: group.tax.rate, category: group.tax.category),
    ))
    .to-dict()

  let discounts = ()
  let surcharges = ()
  for mod in modifiers {
    let applied-mod = apply-mod(ctx, tax-groups, mod)
    if applied-mod.absolute < 0 { discounts.push(applied-mod) }
    if applied-mod.absolute > 0 { surcharges.push(applied-mod) }
  }

  return (
    tax-rates: tax-rates,
    modifier: (
      discounts: discounts,
      surcharges: surcharges,
    ),
    tax-split: (
      discounts: modifiers-by-tax(discounts, tax-rates),
      surcharges: modifiers-by-tax(surcharges, tax-rates),
    ),

    items: items,
    tax-groups: tax-groups,
  )
}

#let modifier-applicator(
  body,
) = {
  compute-motif(
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

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
      let data = calculate-modifier(ctx, children)

      let filtered-children = children.filter(c => (
        c.at("kind", default: none) != "modifier"
      ))

      return (
        (
          loom.frame.new(
            kind: "modifier-applicator",
            key: loom.path.current(ctx),
            path: loom.path.get(ctx),
            signal: data,
          ),
        )
          + filtered-children
      )
    },
    body,
  )
}
