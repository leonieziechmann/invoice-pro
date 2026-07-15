#let tax-nr(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.tax-number
    } else { label }
    let val = if value == auto { ctx.sender.tax-nr } else { value }
    (title, val)
  }
}

#let vat-id(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto { ctx.locale.strings.reference.vat-id } else {
      label
    }
    let val = if value == auto { ctx.sender.vat-id } else { value }
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
      value
    }
    (title, val)
  }
}

#let service-time(label: auto, value: auto) = {
  ctx => {
    let title = if label == auto {
      ctx.locale.strings.reference.service-time
    } else { label }
    let val = if value == auto {
      let dates = ()
      if "items" in ctx {
        for item in ctx.items {
          if item.date != none {
            if type(item.date) == array {
              for d in item.date {
                if type(d) == datetime {
                  dates.push(d)
                }
              }
            } else if type(item.date) == datetime {
              dates.push(item.date)
            }
          }
        }
      }
      if dates.len() == 0 {
        if type(ctx.invoice-date) == datetime {
          (ctx.locale.format.date)(ctx.invoice-date)
        } else {
          ctx.invoice-date
        }
      } else {
        let min-date = dates.first()
        let max-date = dates.first()
        for d in dates {
          if d < min-date { min-date = d }
          if d > max-date { max-date = d }
        }
        let format-date(d) = {
          if type(d) == datetime {
            (ctx.locale.format.date)(d)
          } else {
            str(d)
          }
        }
        if min-date == max-date {
          format-date(min-date)
        } else {
          format-date(min-date) + " – " + format-date(max-date)
        }
      }
    } else {
      value
    }
    (title, val)
  }
}
