#import "payment-reference.typ": bank-signal, resolve-payment-reference
#import "service-period.typ": format-service-period, service-period-of
#import "../utils/helper.typ": first-given

// An identifier dictionary (e.g. `id.leitweg(..)`) prints as its `id`.
#let _identifier-text(value) = {
  if type(value) == dictionary { value.at("id", default: none) } else { value }
}

#let _recipient(ctx, key) = (
  ctx.at("recipient", default: (:)).at(key, default: none)
)

#let tax-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.tax-number
    } else { label }
    let val = if value == auto {
      ctx.sender.at("tax-nr", default: none)
    } else { value }
    (title, val)
  }
}

#let vat-id(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.vat-id
    } else { label }
    let val = if value == auto {
      ctx.sender.at("vat-id", default: none)
    } else { value }
    (title, val)
  }
}

#let invoice-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.invoice-number
    } else { label }
    let val = if value == auto { ctx.invoice-nr } else { value }
    (title, val)
  }
}

#let invoice-date(label: auto, value: auto) = {
  if value != auto {
    import "../utils/types.typ": require-day
    require-day(value, "references.invoice-date::value")
  }
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.invoice-date
    } else { label }
    let val = if value == auto {
      if type(ctx.invoice-date) == datetime {
        (ctx.locale.format.date)(ctx.invoice-date)
      } else {
        ctx.invoice-date
      }
    } else {
      if type(value) == datetime {
        (ctx.locale.format.date)(value)
      } else {
        value
      }
    }
    (title, val)
  }
}

/// Marks the printed service period, whatever its title, for the e-invoice to
/// compare with the one it states (BT-72, BG-14, IP-PERIOD-01).
#let service-period-label = label("invoice-pro:service-period")

/// Marks a service period given as a text, which cannot be compared by date.
#let service-period-text-label = label("invoice-pro:service-period-text")

#let service-time(label: auto, value: auto) = {
  if value != auto {
    import "../utils/types.typ": require-day
    require-day(value, "references.service-time::value")
  }
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.service-time
    } else { label }
    let format-date = ctx.locale.format.date
    // The service period of the e-invoice (BT-72, BG-14), or a date or
    // period `(start, end)` in the locale's date format; else a text.
    let (val, own-text) = if value == auto {
      let items = ctx.at("items", default: none)
      let period = service-period-of(ctx, if items == none { () } else {
        items
      })
      (format-service-period(period, format-date), false)
    } else if type(value) == datetime {
      (format-date(value), false)
    } else if (
      type(value) == array
        and value.len() == 2
        and type(value.first()) == datetime
        and type(value.last()) == datetime
    ) {
      let period = (start: value.first(), end: value.last())
      (format-service-period(period, format-date), false)
    } else {
      (value, true)
    }
    if val in (none, "", []) { return (title, none) }
    // Marked, so that the e-invoice finds it whatever its title.
    if own-text { (title, [#val<invoice-pro:service-period-text>]) } else {
      (title, [#val<invoice-pro:service-period>])
    }
  }
}

#let customer-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.customer-number
    } else { label }
    let val = if value == auto {
      first-given(
        ctx.at("customer-nr", default: none),
        _recipient(ctx, "customer-nr"),
        _recipient(ctx, "id"),
        _recipient(ctx, "customer-id"),
      )
    } else { value }
    (title, _identifier-text(val))
  }
}

#let buyer-reference(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.buyer-reference
    } else { label }
    // The same order as the buyer reference of the e-invoice (BT-10).
    let val = if value == auto {
      _identifier-text(first-given(
        ctx.at("buyer-reference", default: none),
        _recipient(ctx, "buyer-reference"),
        _recipient(ctx, "leitweg-id"),
      ))
    } else { value }
    (title, val)
  }
}

#let recipient-vat-id(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.recipient-vat-id
    } else { label }
    let val = if value == auto {
      ctx.recipient.at("vat-id", default: none)
    } else { value }
    (title, val)
  }
}

#let recipient-tax-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.recipient-tax-number
    } else { label }
    let val = if value == auto {
      ctx.recipient.at("tax-nr", default: none)
    } else { value }
    (title, val)
  }
}

// A self-billed invoice is issued by the buyer: the sender is the buyer.
#let _self-billed(ctx) = {
  let document = ctx.at("document-type", default: none)
  type(document) == dictionary and document.at("self-billed", default: false)
}

/// The seller's tax number (§ 14 Abs. 4 Satz 1 Nr. 2 UStG): the sender's,
/// or the recipient's on a self-billed invoice.
///
/// -> function
#let seller-tax-nr(label: auto, value: auto) = {
  ctx => {
    let strings = ctx.locale.strings.reference
    let self-billed = _self-billed(ctx)
    let title = if label != auto { label } else if self-billed {
      strings.recipient-tax-number
    } else { strings.tax-number }
    let val = if value != auto { value } else {
      let seller = if self-billed { ctx.recipient } else { ctx.sender }
      seller.at("tax-nr", default: none)
    }
    (title, val)
  }
}

/// The seller's VAT ID (Art. 226 No. 3 VAT Directive): the sender's, or the
/// recipient's on a self-billed invoice.
///
/// -> function
#let seller-vat-id(label: auto, value: auto) = {
  ctx => {
    let strings = ctx.locale.strings.reference
    let self-billed = _self-billed(ctx)
    let title = if label != auto { label } else if self-billed {
      strings.recipient-vat-id
    } else { strings.vat-id }
    let val = if value != auto { value } else {
      let seller = if self-billed { ctx.recipient } else { ctx.sender }
      seller.at("vat-id", default: none)
    }
    (title, val)
  }
}

/// The buyer's VAT ID (Art. 226 No. 4 VAT Directive): the recipient's, or the
/// sender's on a self-billed invoice.
///
/// -> function
#let buyer-vat-id(label: auto, value: auto) = {
  ctx => {
    let strings = ctx.locale.strings.reference
    let self-billed = _self-billed(ctx)
    let title = if label != auto { label } else if self-billed {
      strings.vat-id
    } else { strings.recipient-vat-id }
    let val = if value != auto { value } else {
      let buyer = if self-billed { ctx.sender } else { ctx.recipient }
      buyer.at("vat-id", default: none)
    }
    (title, val)
  }
}

/// The name of the payee (`invoice(payee: ..)`, BG-10) on one line.
///
/// -> function
#let payee(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.payee
    } else { label }
    let val = if value != auto { value } else {
      let party = ctx.at("payee", default: none)
      let name = if type(party) == dictionary {
        party.at("name", default: none)
      }
      if type(name) == array { name.join(", ") } else { name }
    }
    (title, val)
  }
}

#let order-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.order-number
    } else { label }
    // The same order as the purchase order reference of the e-invoice (BT-13).
    let val = if value == auto {
      first-given(
        ctx.at("order-nr", default: none),
        _recipient(ctx, "order-nr"),
        ctx.at("po-nr", default: none),
        _recipient(ctx, "po-nr"),
      )
    } else { value }
    (title, val)
  }
}

#let order-date(label: auto, value: auto) = {
  if value != auto {
    import "../utils/types.typ": require-day
    require-day(value, "references.order-date::value")
  }
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.order-date
    } else { label }
    let val = if value == auto {
      let raw = first-given(
        ctx.at("order-date", default: none),
        _recipient(ctx, "order-date"),
      )
      if type(raw) == datetime {
        (ctx.locale.format.date)(raw)
      } else {
        raw
      }
    } else {
      if type(value) == datetime {
        (ctx.locale.format.date)(value)
      } else {
        value
      }
    }
    (title, val)
  }
}

#let project(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.project
    } else { label }
    let val = if value == auto {
      first-given(
        ctx.at("project", default: none),
        ctx.at("project-nr", default: none),
      )
    } else { value }
    (title, val)
  }
}

#let contract-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.contract-number
    } else { label }
    // The same order as the contract reference of the e-invoice (BT-12).
    let val = if value == auto {
      first-given(
        ctx.at("contract-nr", default: none),
        _recipient(ctx, "contract-nr"),
      )
    } else { value }
    (title, val)
  }
}

#let quote-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.quote-number
    } else { label }
    let val = if value == auto {
      first-given(
        ctx.at("quote-nr", default: none),
        ctx.at("offer-nr", default: none),
      )
    } else { value }
    (title, val)
  }
}

#let delivery-note-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.delivery-note-number
    } else { label }
    // The same order as the despatch advice reference (BT-16).
    let val = if value == auto {
      first-given(
        ctx.at("delivery-note-nr", default: none),
        _recipient(ctx, "delivery-note-nr"),
      )
    } else { value }
    (title, val)
  }
}

#let delivery-address(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.delivery-address
    } else { label }
    let val = if value == auto {
      let da = ctx.at(
        "delivery-address",
        default: ctx.recipient.at("delivery-address", default: none),
      )
      // `invoice` normalizes a delivery address into these inline parts.
      if type(da) == dictionary {
        let parts = ()
        for key in ("name-inline", "address-inline", "city-inline") {
          let part = da.at(key, default: none)
          if part != none and part != "" { parts.push(part) }
        }
        if parts.len() > 0 { parts.join(", ") } else { none }
      } else {
        none
      }
    } else { value }
    (title, val)
  }
}

#let preceding-invoice-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.preceding-invoice-number
    } else { label }
    let val = if value == auto {
      first-given(
        ctx.at("preceding-invoice-nr", default: none),
        ctx.at("original-invoice-nr", default: none),
      )
    } else { value }
    (title, val)
  }
}

#let preceding-invoice-date(label: auto, value: auto) = {
  if value != auto {
    import "../utils/types.typ": require-day
    require-day(value, "references.preceding-invoice-date::value")
  }
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.preceding-invoice-date
    } else { label }
    let val = if value == auto {
      ctx.at("preceding-invoice-date", default: none)
    } else { value }
    if type(val) == datetime { val = (ctx.locale.format.date)(val) }
    (title, val)
  }
}

#let due-date(label: auto, value: auto) = {
  if value != auto {
    import "../utils/types.typ": require-day
    require-day(value, "references.due-date::value")
  }
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.due-date
    } else { label }
    let val = if value == auto {
      let d = ctx.at("due-date", default: none)
      if d == none and "payment-goal" in ctx and ctx.payment-goal != none {
        if ctx.payment-goal.at("date", default: none) != none {
          d = ctx.payment-goal.date
        } else if (
          ctx.payment-goal.at("days", default: none) != none
            and type(ctx.invoice-date) == datetime
        ) {
          d = ctx.invoice-date + duration(days: ctx.payment-goal.days)
        }
      }
      if type(d) == datetime {
        (ctx.locale.format.date)(d)
      } else {
        d
      }
    } else {
      if type(value) == datetime {
        (ctx.locale.format.date)(value)
      } else {
        value
      }
    }
    (title, val)
  }
}

#let payment-reference(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.payment-reference
    } else { label }
    let val = if value == auto {
      resolve-payment-reference(ctx, bank: bank-signal(ctx))
    } else { value }
    (title, val)
  }
}

#let contact-person(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.contact-person
    } else { label }
    let val = if value == auto {
      let contact = ctx.sender.at("contact", default: none)
      if type(contact) == dictionary {
        contact.at("name", default: none)
      } else if ctx.sender.at("contact-name", default: none) != none {
        ctx.sender.contact-name
      } else if contact != none {
        contact
      } else {
        ctx.at("contact-person", default: ctx.at("clerk", default: none))
      }
    } else { value }
    (title, val)
  }
}

#let contact-phone(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.contact-phone
    } else { label }
    let val = if value == auto {
      let contact = ctx.sender.at("contact", default: none)
      if type(contact) == dictionary and "phone" in contact {
        contact.phone
      } else {
        ctx.sender.at("phone", default: none)
      }
    } else { value }
    (title, val)
  }
}

#let contact-email(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.contact-email
    } else { label }
    let val = if value == auto {
      let contact = ctx.sender.at("contact", default: none)
      if type(contact) == dictionary and "email" in contact {
        contact.email
      } else {
        ctx.sender.at("email", default: none)
      }
    } else { value }
    (title, val)
  }
}

// --- Presets ---
// Each prints what the law requires besides the parties and the items
// (§ 14 Abs. 4 UStG, Art. 226 VAT Directive); references without value are
// left out.

#let _party-references() = (
  seller-tax-nr(),
  seller-vat-id(),
  buyer-vat-id(),
  payee(),
)

#let preset-b2b() = (
  invoice-nr(),
  customer-nr(),
  order-nr(),
  invoice-date(),
  service-time(),
  due-date(),
  .._party-references(),
)

#let preset-b2g() = (
  invoice-nr(),
  buyer-reference(),
  order-nr(),
  invoice-date(),
  service-time(),
  due-date(),
  .._party-references(),
)

#let preset-project() = (
  invoice-nr(),
  customer-nr(),
  project(),
  invoice-date(),
  service-time(),
  due-date(),
  .._party-references(),
)

#let preset-din-5008() = (
  order-nr(),
  order-date(),
  contact-person(),
  invoice-date(),
  service-time(),
  .._party-references(),
)
