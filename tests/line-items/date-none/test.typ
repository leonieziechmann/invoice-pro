// `date: none` on items and bundles resolves to no date, overriding any date
// inherited from a surrounding group. In the ZUGFeRD delivery date
// determination, undated items do not count, and the invoice date is the
// delivery date only if no item has a date.

#import "/src/lib.typ": *
#import "/src/zugferd/build.typ": determine-delivery-dates
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#let invoice-date = datetime(year: 2026, month: 7, day: 9)
#let group-date = datetime(year: 2026, month: 7, day: 1)
#let child-date = datetime(year: 2026, month: 7, day: 2)
#let bundle-date = datetime(year: 2026, month: 7, day: 3)

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Test Sender"),
  recipient: (name: "Test Recipient"),
  date: invoice-date,
)

#data-test(test: (ctx, data) => {
  let li = loom.query.find-signal(data, "line-items")
  assert.ne(li, none, message: "line-items signal not found")

  let items = li.item-data.items
  assert.eq(
    items.len(),
    7,
    message: "Expected 7 items, got " + repr(items.len()),
  )

  let expected = (
    ("Item none", none),
    ("Bundle none", none),
    ("Bundle auto", child-date),
    ("Group item auto", group-date),
    ("Group item none", none),
    ("Group bundle none", none),
    ("Group bundle explicit", bundle-date),
  )
  for (i, (label, date)) in expected.enumerate() {
    assert.eq(
      items.at(i).date,
      date,
      message: label
        + " date: expected "
        + repr(date)
        + ", got "
        + repr(items.at(i).date),
    )
  }

  // ZUGFeRD: without any dated item, the invoice date is the delivery date
  let undated = items.filter(i => i.date == none)
  let undated-delivery = determine-delivery-dates(ctx, undated)
  assert.eq(
    undated-delivery,
    (date: invoice-date, period: none),
    message: "Undated delivery: expected invoice date, got "
      + repr(undated-delivery),
  )

  // Undated items do not count when others are dated
  let delivery = determine-delivery-dates(ctx, items)
  assert.eq(
    delivery,
    (date: none, period: (group-date, bundle-date)),
    message: "Delivery period: expected "
      + repr((group-date, bundle-date))
      + ", got "
      + repr(delivery),
  )
})[
  #line-items[
    #item([Item none], price: 10, date: none)
    #bundle([Bundle none], date: none)[
      #item([Dated child], price: 10, date: child-date)
    ]
    #bundle([Bundle auto])[
      #item([Dated child], price: 10, date: child-date)
    ]
    #group([Dated group], date: group-date)[
      #item([Group item auto], price: 10)
      #item([Group item none], price: 10, date: none)
      #bundle([Group bundle none], date: none)[
        #item([Child], price: 10)
      ]
      #bundle([Group bundle explicit], date: bundle-date)[
        #item([Child], price: 10)
      ]
    ]
  ]
]
