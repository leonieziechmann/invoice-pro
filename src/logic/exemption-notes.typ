// The exemption notes below the line items and the markers that link each
// note to the VAT line of its category or to its items.

#import "../data/tax.typ" as m-tax

#let _symbols = ("*", "**", "***", "****")

/// Assigns a marker to every distinct exemption ground of the VAT groups:
/// `"*"` to `"****"`, then `"*5"`, ... Returns `(grounds: .., itemized: ..)`,
/// the markers by ground key and the VAT groups whose items are marked.
///
/// -> dictionary
#let assign-markers(
  /// The VAT groups of the tax applicator by key.
  /// -> dictionary
  taxes,
) = {
  let markers = (:)
  let itemized = (:)
  for (tax-key, tax) in taxes {
    let list = m-tax.grounds-of(tax)
    for grounds in list {
      let key = m-tax.grounds-key(grounds)
      if key not in markers {
        let index = markers.len()
        markers.insert(key, if index < _symbols.len() {
          _symbols.at(index)
        } else { "*" + str(index + 1) })
      }
    }
    if list.len() > 1 { itemized.insert(tax-key, true) }
  }
  (grounds: markers, itemized: itemized)
}

/// The markers of the exemption grounds of a VAT group, in their order.
///
/// -> array
#let group-markers(
  /// A VAT group of the tax applicator.
  /// -> dictionary
  tax,
  /// The markers, see `assign-markers`.
  /// -> dictionary
  markers,
) = {
  let result = ()
  for grounds in m-tax.grounds-of(tax) {
    result.push(markers.grounds.at(m-tax.grounds-key(grounds), default: none))
  }
  result
}

/// The marker of an item's exemption grounds if its VAT group has several,
/// else `none`.
///
/// -> none | str
#let item-marker(
  /// The tax of the item.
  /// -> dictionary
  tax,
  /// The markers, see `assign-markers`.
  /// -> dictionary
  markers,
) = {
  if m-tax.to-tax-key(tax) not in markers.itemized { return none }
  let result = ()
  for grounds in m-tax.grounds-of(tax) {
    result.push(markers.grounds.at(m-tax.grounds-key(grounds), default: none))
  }
  if result.len() == 0 { none } else { result.join(",") }
}

// A VAT group printed as 0% has no VAT line in the totals to mark.
#let _zero-rated(tax) = (
  tax.raw-rate == 0
    or tax.rate == [0%]
    or tax.rate == [0,0%]
    or tax.rate == [0.0%]
)

/// The exemption notes below the line items, in print order, as
/// `(kind: .., marker: .., body: ..)`: the small business clause, then every
/// distinct exemption ground once.
///
/// -> array
#let exemption-notes(
  /// The VAT groups of the view of `line-items`.
  /// -> array
  taxes,
  /// Whether the totals, with a VAT line per category, are shown.
  /// -> bool
  show-total: true,
  /// Whether the tax column, with the markers of the items, is shown.
  /// -> bool
  show-tax-rates: false,
  /// With `tax-exempt-small-biz`, `(clause: .., grounds: .., same-language:
  /// ..)`: the clause in the document's language, the region's grounds.
  /// -> none | dictionary
  small-business: none,
) = {
  let notes = ()
  let printed = ()

  if small-business != none {
    let (clause, grounds, same-language) = small-business
    // The clause is linked to the VAT line of the scheme's category.
    let scheme-tax = none
    for tax in taxes {
      if tax.grounds == grounds {
        scheme-tax = tax
        break
      }
    }
    let marker = if (
      scheme-tax != none and not _zero-rated(scheme-tax) and show-total
    ) { scheme-tax.marker }
    // Without regional grounds, the clause stands alone: it is never dropped.
    let body = if grounds == none { clause } else if same-language {
      grounds
    } else [#clause (#grounds)]
    notes.push((kind: "small-business", marker: marker, body: body))
    if grounds != none { printed.push(m-tax.grounds-key(grounds)) }
  }

  for tax in taxes {
    // Shown on the VAT line (not for 0%) or on the items (tax column).
    let show-marker = (
      (not _zero-rated(tax) and show-total)
        or (tax.itemized-grounds and show-tax-rates)
    )
    for (grounds, marker) in tax.grounds-list.zip(tax.grounds-markers) {
      if not m-tax.has-grounds(grounds) { continue }
      let key = m-tax.grounds-key(grounds)
      if key in printed { continue }
      printed.push(key)
      notes.push((
        kind: "grounds",
        marker: if show-marker { marker },
        body: grounds,
      ))
    }
  }
  notes
}
