#import "../data/tax.typ"

// The tax of a VAT group: `grounds` joins the exemption grounds of its items
// (BT-120), `grounds-list` keeps several for the notes, `code` or `codes` are
// their reason codes (BT-121), `implicit` marks an item with `tax: none`.
#let group-tax(first-tax, grounds-list, implicit, codes: ()) = (
  rate: first-tax.rate,
  category: first-tax.category,
  grounds: tax.join-grounds(grounds-list),
  ..if grounds-list.len() > 1 { (grounds-list: grounds-list) },
  ..if codes.len() == 1 { (code: codes.first()) },
  ..if codes.len() > 1 { (codes: codes) },
  ..if implicit { (implicit: true) },
)

/// Adds a VAT group for the `tax` a modifier is pinned to (with a total of 0
/// if it has no items) and its exemption grounds.
///
/// -> dictionary
#let with-tax-group(tax-groups, pinned-tax) = {
  let key = tax.to-tax-key(pinned-tax)
  let group = tax-groups.groups.at(key, default: (
    total: decimal("0"),
    tax: pinned-tax,
    grounds-list: (),
    missing-grounds: 0,
    items: (),
  ))
  let grounds-list = tax.merge-grounds(
    group.grounds-list,
    tax.grounds-of(pinned-tax),
  )
  group.grounds-list = grounds-list
  group.tax = group-tax(
    group.tax,
    grounds-list,
    tax.is-implicit(group.tax) or tax.is-implicit(pinned-tax),
    codes: tax.merge-codes(tax.codes-of(group.tax), tax.codes-of(pinned-tax)),
  )
  tax-groups.groups.insert(key, group)
  tax-groups.keys = tax-groups.groups.keys()
  tax-groups
}

/// Groups items by VAT group (rate and category), with their total, the
/// exemption grounds of all items and the count of those without.
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
        codes: (),
        implicit: false,
        ..if include-items { (items: ()) },
      ))
    }

    // In place: a copy of the group would copy its items (quadratic).
    total += item.total
    groups.at(tax-key).total += item.total
    if item-grounds.len() == 0 {
      groups.at(tax-key).missing-grounds += 1
    } else {
      groups.at(tax-key).grounds-list = tax.merge-grounds(
        groups.at(tax-key).grounds-list,
        item-grounds,
      )
    }
    if tax.is-implicit(item.tax) { groups.at(tax-key).implicit = true }
    if "code" in item.tax or "codes" in item.tax {
      groups.at(tax-key).codes = tax.merge-codes(
        groups.at(tax-key).codes,
        tax.codes-of(item.tax),
      )
    }
    if include-items { groups.at(tax-key).items.push(item) }
  }

  for (key, group) in groups {
    let first-tax = group.remove("first-tax")
    let implicit = group.remove("implicit")
    let codes = group.remove("codes")
    group.insert("tax", group-tax(
      first-tax,
      group.grounds-list,
      implicit,
      codes: codes,
    ))
    groups.insert(key, group)
  }

  return (
    total: total,
    keys: groups.keys(),
    groups: groups,
  )
}
