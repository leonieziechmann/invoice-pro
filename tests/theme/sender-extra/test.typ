// The sender's `extra` (phone, email) is printed by every preset on its
// default layout: next to the address (`sender-details`) or in the legal
// footer (`contact`). `plain`, made for letterhead paper, leaves it out.
// bold, technical and soft printed it nowhere until the footer of their
// digital layouts hosted `contact`.
//
// Without `extra`, the empty `contact` gives up its footer column: the
// register column then follows the company column (bold arranges its footer
// itself, technical takes the arrangement of a4-digital).
#import "/src/lib.typ": *
#import "/tests/theme/body.typ": body, party, preset-of, presets, test-locale

// Records which parts that print the sender's `extra` render content, and
// where the legal footer parts start. An empty part stays empty, so that it
// gives up its column as without the probe.
#let probing(name, case) = preset-of(name).with({
  import theme.custom: *
  for part in ("contact", "sender-details") {
    wrap(part, (ctx, view, inner) => {
      let out = inner(ctx, view)
      if out in (none, [], "") { return out }
      [#metadata((preset: name, case: case, part: part))<extra-part>#out]
    })
  }
  for part in ("company", "registration", "bank-account") {
    wrap(part, (ctx, view, inner) => [#metadata((
        preset: name,
        case: case,
        part: part,
      ))<footer-part>#inner(ctx, view)])
  }
})

#for name in presets {
  invoice(theme: probing(name, "extra"), locale: test-locale, ..party)[
    #body()
  ]
}
#let lean = party + (sender: party.sender + (extra: ()))
#for name in ("bold", "technical") {
  invoice(theme: probing(name, "lean"), locale: test-locale, ..lean)[
    #body()
  ]
}

#context {
  let parts = query(<extra-part>).map(it => it.value)
  for name in presets {
    let printed = parts.filter(p => p.preset == name and p.case == "extra")
    if name == "plain" {
      assert.eq(printed, (), message: "plain prints the sender's extra")
    } else {
      assert(
        printed.len() > 0,
        message: name + " prints the sender's extra nowhere",
      )
    }
  }
  // Where each footer part starts, on the first page that shows it. Columns
  // weighted 0.75 : 1.4 : 1.25 put the register column at about 0.36 of the
  // way from the company to the bank column; an empty contact column of
  // weight 1.05 between company and register would put it at about 0.57.
  for name in ("bold", "technical") {
    let starts = (:)
    for m in query(<footer-part>) {
      let v = m.value
      if v.preset == name and v.case == "lean" and v.part not in starts {
        starts.insert(v.part, m.location().position().x)
      }
    }
    let company = starts.at("company")
    let share = (
      (starts.at("registration") - company)
        / (starts.at("bank-account") - company)
    )
    assert(
      share < 0.47,
      message: name
        + ": without extra, the footer keeps an empty contact column (register at "
        + str(calc.round(share, digits: 2))
        + ")",
    )
  }
}
