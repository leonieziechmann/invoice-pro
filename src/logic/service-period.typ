// The service period of an invoice (BT-72 or BG-14), resolved once for the
// printed `references.service-time` and the e-invoice, so they cannot differ.

/// Resolves the service period: the invoice's `service-period`, else from the
/// earliest to the latest date of the items, else the invoice date. Returns
/// `(start: .., end: .., source: ..)`, or `none` without any date.
///
/// -> none | dictionary
#let resolve-service-period(
  /// The computed items (each with its `date`).
  /// -> array
  items,
  /// The date of the invoice.
  /// -> datetime | any
  invoice-date,
  /// The invoice's `service-period`.
  /// -> none | datetime | array
  service-period: none,
) = {
  if type(service-period) == datetime {
    return (start: service-period, end: service-period, source: "invoice")
  }
  if type(service-period) == array and service-period.len() == 2 {
    let (start, end) = service-period
    return (start: start, end: end, source: "invoice")
  }

  let start = none
  let end = none
  for item in items {
    let date = if type(item) == dictionary { item.at("date", default: none) }
    let dates = if type(date) == datetime { (date,) } else if (
      type(date) == array
    ) { date } else { () }
    for d in dates {
      if type(d) != datetime { continue }
      if start == none or d < start { start = d }
      if end == none or d > end { end = d }
    }
  }
  if start != none {
    return (start: start, end: end, source: "items")
  }
  if type(invoice-date) == datetime {
    return (start: invoice-date, end: invoice-date, source: "invoice-date")
  }
  none
}

/// Whether the date of a document is the date of its supply when nothing
/// else dates it: not for a credit note or a prepayment invoice.
///
/// -> bool
#let supply-dated(document) = (
  type(document) != dictionary
    or not (
      document.at("credit", default: false)
        or document.at("prepayment", default: false)
    )
)

/// The service period of the invoice of the root context `ctx` with its
/// computed `items`, for `references.service-time` and the e-invoice.
///
/// -> none | dictionary
#let service-period-of(ctx, items) = {
  let document = ctx.at("document-type", default: none)
  resolve-service-period(
    items,
    if supply-dated(document) { ctx.at("invoice-date", default: none) },
    service-period: ctx.at("service-period", default: none),
  )
}

/// The printed text of a service period, formatted with `format-date`.
///
/// -> str | content | none
#let format-service-period(period, format-date) = {
  if period == none { return none }
  if period.start == period.end { return format-date(period.start) }
  format-date(period.start) + " – " + format-date(period.end)
}
