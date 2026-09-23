#import "payment-reference.typ": bank-signal, resolve-payment-reference
#import "service-period.typ": format-service-period, resolve-service-period
#import "../utils/helper.typ": first-given

// An identifier given as a dictionary, e.g. a typed identifier of the `id`
// module (`id.leitweg(..)`), is printed as its identifier.
#let _identifier-text(value) = {
  if type(value) == dictionary { value.at("id", default: none) } else { value }
}

// The value of a key of the recipient, or `none`.
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

#let service-time(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.service-time
    } else { label }
    // The service period the e-invoice states as well (BT-72, BG-14).
    let val = if value == auto {
      let items = ctx.at("items", default: none)
      format-service-period(
        resolve-service-period(
          if items == none { () } else { items },
          ctx.invoice-date,
          service-period: ctx.at("service-period", default: none),
        ),
        ctx.locale.format.date,
      )
    } else {
      value
    }
    (title, val)
  }
}

#let customer-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.customer-number
    } else { label }
    // The invoice's `customer-nr`, else the recipient's customer number or
    // identifier (an identifier of the `id` module prints its `id`).
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

#let order-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.order-number
    } else { label }
    // The same order as the purchase order reference of the e-invoice
    // (BT-13).
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
    // The same order as the despatch advice reference of the e-invoice
    // (BT-16).
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
      // The invoice only accepts a dictionary as delivery address and
      // normalizes it into these inline parts.
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

// Preset Packs
#let preset-b2b() = (
  invoice-nr(),
  customer-nr(),
  order-nr(),
  invoice-date(),
  service-time(),
  due-date(),
  tax-nr(),
  vat-id(),
  recipient-vat-id(),
)

#let preset-b2g() = (
  invoice-nr(),
  buyer-reference(),
  order-nr(),
  invoice-date(),
  service-time(),
  due-date(),
  tax-nr(),
  vat-id(),
  recipient-vat-id(),
)

#let preset-project() = (
  invoice-nr(),
  customer-nr(),
  project(),
  invoice-date(),
  service-time(),
  due-date(),
  tax-nr(),
  vat-id(),
  recipient-vat-id(),
)

#let preset-din-5008() = (
  order-nr(),
  order-date(),
  contact-person(),
  invoice-date(),
)
