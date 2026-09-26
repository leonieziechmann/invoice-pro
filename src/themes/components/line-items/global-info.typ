#import "../../../utils/types.typ"

#let render-global-info(
  ctx,
  data,

  color-desc: luma(100),
  size-small: 0.85em,
) = {
  types.require(color-desc, "render-global-info::color-desc", color, none)

  let layout = data.layout-information
  let is-net = data.tax-mode == "exclusive"
  let sum-str = ctx.locale.strings.summary
  let info-str = ctx.locale.strings.global-info

  let global-infos = ()

  // Prepared by `line-items`, see `src/logic/exemption-notes.typ`.
  let exemption-notes = data.at("exemption-notes", default: ())

  // The standard tax statement, left out for small businesses and exemptions.
  if (
    not layout.show-tax-rates
      and not layout.multiple-tax-rates
      and data.items.len() > 0
      and not data.tax-exempt-small-biz
      and exemption-notes.all(note => note.at("kind", default: none) == "note")
  ) {
    let tax-rate = data.items.first(default: (tax: (rate: [0%]))).tax.rate
    let tax-text = if is-net { sum-str.excluding } else { sum-str.including }
    global-infos.push((info-str.tax-statement)(
      tax-text,
      tax-rate,
      sum-str.vat-tax,
    ))
  }

  // What all items share: unit, quantity, date.
  if (
    not layout.show-units and not layout.multiple-units and data.items.len() > 0
  ) {
    // The note names the unit, so use its singular form (not "2 days").
    let raw-unit = data
      .items
      .first(default: (unit-singular: none))
      .unit-singular
    let unit = if type(raw-unit) == dictionary {
      raw-unit.at("display", default: raw-unit.at("name", default: none))
    } else {
      raw-unit
    }
    if unit != none {
      global-infos.push([#info-str.unit #unit])
    }
  }

  if not layout.show-quantity and not layout.multiple-quantities {
    let quantity = data.items.first(default: (quantity: 0)).quantity
    global-infos.push([#info-str.quantity #quantity])
  }

  if (
    not layout.show-dates
      and layout.has-dates
      and not layout.multiple-dates
      and data.items.len() > 0
  ) {
    let date = data.items.first(default: (date: none)).date
    global-infos.push([#info-str.date #date])
  }

  // Exemption notes (required by law, BT-120) and invoice notes (BT-22),
  // with their markers: `show-information: false` does not hide them.
  let notes = ()
  for note in exemption-notes {
    let marker-str = if note.marker != none {
      super[#note.marker] + [ ]
    } else {
      []
    }
    notes.push([#marker-str#note.body])
  }

  let lines = if layout.show-global-information {
    global-infos + notes
  } else { notes }
  if lines.len() > 0 {
    pad(
      top: 1em,
      text(
        size: size-small,
        fill: color-desc,
        lines.join([\ ]),
      ),
    )
  }
}
