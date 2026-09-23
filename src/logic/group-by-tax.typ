#import "../data/tax.typ"

// The tax of a VAT group: rate, category and every distinct exemption ground
// of its items. `grounds` joins them into the one exemption reason of the
// category (BT-120). With several grounds, `grounds-list` keeps each of them
// for the printed notes. `implicit` marks a group with an item whose tax was
// never set (`tax: none`), see `tax.implicit-zero`.
#let group-tax(first-tax, grounds-list, implicit) = (
  rate: first-tax.rate,
  category: first-tax.category,
  grounds: tax.join-grounds(grounds-list),
  ..if grounds-list.len() > 1 { (grounds-list: grounds-list) },
  ..if implicit { (implicit: true) },
)

/// Groups items by VAT group (rate and category) and sums their totals.
///
/// Every group keeps the distinct exemption grounds of all its items, not
/// only those of the first one, and counts the items that have none
/// (`missing-grounds`).
///
/// -> dictionary
#let group-by-tax(items, include-items: true) = {
  let total = decimal("0")
  let groups = (:)

  for item in items {
    let tax-key = tax.to-tax-key(item.tax)
    let item-grounds = tax.grounds-of(item.tax)
    if tax-key not in groups {
      groups.insert(tax-key, (
        total: decimal("0"),
        first-tax: item.tax,
        grounds-list: (),
        missing-grounds: 0,
        implicit: false,
        ..if include-items { (items: ()) },
      ))
    }

    total += item.total
    let group = groups.at(tax-key)
    group.total += item.total
    group.grounds-list = tax.merge-grounds(group.grounds-list, item-grounds)
    if item-grounds.len() == 0 { group.missing-grounds += 1 }
    if tax.is-implicit(item.tax) { group.implicit = true }
    if include-items { group.items.push(item) }
    groups.insert(tax-key, group)
  }

  for (key, group) in groups {
    let first-tax = group.remove("first-tax")
    let implicit = group.remove("implicit")
    group.insert("tax", group-tax(first-tax, group.grounds-list, implicit))
    groups.insert(key, group)
  }

  return (
    total: total,
    keys: groups.keys(),
    groups: groups,
  )
}
