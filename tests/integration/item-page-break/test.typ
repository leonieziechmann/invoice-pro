// Page breaks in the line-items table must not separate the rows of an item.
//
// Each item is built from several table rows (padding caps, title,
// description, modifiers, subtotal). A page break could fall between them, so
// a description was carried over alone to the next page, under the repeated
// table header, while its title stayed on the previous page.
//
// The test sweeps the table's offset on small pages so that page breaks fall
// inside each item, then checks in the final layout that all parts of an item
// land on one page. Items taller than a page must still break across pages
// instead of overflowing one.

#import "/src/lib.typ": *
#import "/src/themes/components/line-items/table.typ": (
  default-render-description, default-render-modifier, default-render-title,
  render-table,
)
#import "/tests/test-locale.typ": test-locale

// Small pages that show nothing but the body (every standard area is an empty
// stub), so the table's offset alone decides where the page breaks fall.
#let small-pages = (
  name: "item-page-break",
  paper: (width: 120mm, height: 70mm),
  margin: 6mm,
  areas: (:),
)

#let plain(name) = if type(name) == str { name } else { name.text }

// Tags a rendered part of an item so the final layout can be queried for the
// page it landed on.
#let part-marker(scenario, name, part) = [#metadata((
  scenario: scenario,
  item: plain(name),
  part: part,
)) <item-part>]

// The `items-table` part is the table renderer of the built-in part, called
// with marker callbacks. No area hosts the parts an invoice requires, so
// validation is off.
#let marked-invoice(scenario, body) = invoice(
  theme: theme.plain.with(
    theme.custom.part("items-table", (ctx, view) => render-table(
      ctx,
      view,
      render-title: (ctx, item, layout, styles) => {
        part-marker(scenario, item.name, "title")
        default-render-title(ctx, item, layout, styles)
      },
      render-description: (ctx, item, layout, styles) => {
        part-marker(scenario, item.name, "description")
        default-render-description(ctx, item, layout, styles)
        part-marker(scenario, item.name, "description-end")
      },
      // Modifiers are named after the item they belong to.
      render-modifier: (ctx, mod, styles, is-discount: true) => {
        let parts = default-render-modifier(
          ctx,
          mod,
          styles,
          is-discount: is-discount,
        )
        parts.label = [#part-marker(scenario, mod.name, "modifier")#parts.label]
        parts
      },
    )),
    layout: small-pages,
  ),
  locale: test-locale,
  sender: (name: "Test Sender"),
  recipient: (name: "Test Recipient"),
  validation: none,
  body,
)

#let two-lines(name) = [Description of #name. #linebreak() Second line.]
#let lines(n) = range(n).map(i => [Line #(i + 1)]).join(linebreak())

// 1. Sweep: page breaks fall inside plain, modified, grouped and bundled
//    items. Without keeping items together, each of A2, A3, G2 and B is split
//    over a window of about 5mm of offset. Every invoice starts a new page
//    (the frame owns `set page`), so the offset is part of its body. A2 and
//    G2 start the second page from about 27mm of offset on.
#let offsets = range(0, 40, step: 2)
#for offset in offsets {
  marked-invoice("sweep-" + str(offset))[
    #v(offset * 1mm)
    #line-items[
      #item("A1", description: two-lines("A1"), price: 10)
      #item(
        "A2",
        description: two-lines("A2"),
        price: 20,
        modifier: discount("A2", amount: 10%),
      )
      #item("A3", description: two-lines("A3"), price: 30)
      #group("G", description: [Group description])[
        #item("G1", description: two-lines("G1"), price: 40)
        #item(
          "G2",
          description: two-lines("G2"),
          price: 50,
          modifier: surcharge("G2", amount: 5),
        )
      ]
      #bundle("B")[
        #item("B1", price: 60)
        #item("B2", price: 70)
      ]
      #item("A4", description: two-lines("A4"), price: 80)
    ]
  ]
}

// 2. An item that does not fit below the others but fits on a page of its own
//    moves to the next page as a whole.
#marked-invoice("tall")[
  #line-items[
    #item("T1", description: two-lines("T1"), price: 10)
    #item("T2", description: two-lines("T2"), price: 20)
    #item("T3", description: lines(10), price: 30)
  ]
]

// 3. An item taller than a page cannot be kept on one page; it breaks across
//    pages instead of overflowing the page.
#marked-invoice("overflow")[
  #line-items[
    #item("O1", description: two-lines("O1"), price: 10)
    #item("O2", description: lines(20), price: 20)
    #item("O3", description: two-lines("O3"), price: 30)
  ]
]

#context {
  let parts = query(<item-part>).map(m => (
    ..m.value,
    page: m.location().page(),
  ))
  let pages-of(scenario, name) = parts
    .filter(p => p.scenario == scenario and p.item == name)
    .map(p => (p.part, p.page))
  let page-of(scenario, name, part) = {
    parts
      .find(p => p.scenario == scenario and p.item == name and p.part == part)
      .page
  }

  // 1. Every part of every item lands on the page of its title.
  let sweep-items = ("A1", "A2", "A3", "G1", "G2", "B", "A4")
  for offset in offsets {
    let scenario = "sweep-" + str(offset)
    for name in sweep-items {
      let item-pages = pages-of(scenario, name)
      assert(
        item-pages.len() >= 2,
        message: "Sweep "
          + scenario
          + ": expected title and description of "
          + name
          + ", got "
          + repr(item-pages),
      )
      assert(
        item-pages.all(((_, page)) => page == item-pages.first().at(1)),
        message: "Sweep "
          + scenario
          + ": expected all parts of "
          + name
          + " on one page, got "
          + repr(item-pages),
      )
    }
  }

  // The sweep must move each item (after the first) to a new page for some
  // offset, otherwise no page break has fallen inside it.
  for (previous, name) in sweep-items.zip(sweep-items.slice(1)) {
    assert(
      offsets.any(offset => {
        let scenario = "sweep-" + str(offset)
        page-of(scenario, name, "title") > page-of(scenario, previous, "title")
      }),
      message: "Sweep: expected "
        + name
        + " to start a new page for some offset, got none",
    )
  }

  // 2. The tall item fits on a page of its own and moves there as a whole.
  let t3 = pages-of("tall", "T3")
  assert(
    t3.all(((_, page)) => page == t3.first().at(1)),
    message: "Tall item: expected all parts of T3 on one page, got " + repr(t3),
  )
  assert(
    page-of("tall", "T3", "title") > page-of("tall", "T2", "title"),
    message: "Tall item: expected T3 to move to the next page, got "
      + repr(pages-of("tall", "T2") + t3),
  )

  // 3. The item taller than a page is broken across pages.
  let o2-title = page-of("overflow", "O2", "title")
  let o2-end = page-of("overflow", "O2", "description-end")
  assert(
    o2-end > o2-title,
    message: "Overflowing item: expected O2 to break across pages, got title on page "
      + str(o2-title)
      + " and description end on page "
      + str(o2-end),
  )
}
