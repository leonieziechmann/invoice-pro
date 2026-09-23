// Units given as text are mapped to their UN/ECE Recommendation 20 code
// (BT-130) by the names and abbreviations invoice-pro knows. A text without
// a known code is an error instead of the code C62 ("one"), and a code that
// is also a common abbreviation of another unit is warned about.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": resolve-unit
#import "/tests/zugferd/harness.typ": (
  bank, diagnostic, model-test, rules, xml-elements,
)

// --- 1. Symbols, names and abbreviations ---
#{
  let code(unit) = resolve-unit(unit).code
  let expected = (
    // Area, volume, length and mass
    ("m²", "MTK"),
    ("M2", "MTK"),
    ("qm", "MTK"),
    ("m³", "MTQ"),
    ("cbm", "MTQ"),
    ("km", "KMT"),
    ("cm", "CMT"),
    ("lfm", "MTR"),
    ("t", "TNE"),
    ("to", "TNE"),
    ("Tonnen", "TNE"),
    ("kg", "KGM"),
    ("l", "LTR"),
    // Time
    ("Std.", "HUR"),
    ("Stunden", "HUR"),
    ("min", "MIN"),
    ("Min.", "MIN"),
    ("Minute", "MIN"),
    ("Tage", "DAY"),
    ("Woche", "WEE"),
    ("Wochen", "WEE"),
    ("Monat", "MON"),
    ("Jahre", "ANN"),
    // Energy
    ("kWh", "KWH"),
    ("MWh", "MWH"),
    // Counts
    ("Stk.", "H87"),
    ("Stück", "H87"),
    ("St.", "H87"),
    ("pcs", "H87"),
    ("Paar", "PR"),
    ("Satz", "SET"),
    ("pauschal", "LS"),
    ("Pauschale", "LS"),
    ("psch.", "LS"),
    ("lump sum", "LS"),
    ("Seiten", "ZP"),
    ("Pers.", "IE"),
    ("%", "P1"),
    // Other languages, also in the plural
    ("heures", "HUR"),
    ("jours", "DAY"),
    ("pièce", "H87"),
    ("forfait", "LS"),
    ("horas", "HUR"),
    ("metro cuadrado", "MTK"),
    // Codes as they are
    ("H87", "H87"),
    ("MIN", "MIN"),
    ("C62", "C62"),
  )
  for (unit, expected-code) in expected {
    assert.eq(code(unit), expected-code, message: unit)
  }
  assert.eq(code([m#super[2]]), "MTK")
  assert.eq(code((display: "Pauschale")), "LS")
  assert.eq(code((display: "Nacht", code: "C62")), "C62")

  // Without a unit, the quantity is a number of "one"
  assert.eq(resolve-unit(none), (code: "C62", issue: none))
  // An unknown text keeps "one" only as placeholder, and is marked
  assert.eq(resolve-unit("Nacht"), (
    code: "C62",
    issue: (kind: "unknown", text: "Nacht"),
  ))
  // "ms" is no plural of "m"
  assert.eq(resolve-unit("ms").issue.kind, "unknown")
  assert.eq(resolve-unit("STK").issue.kind, "ambiguous")
}

// --- 2. A unit text without a known code is an error (BR-CL-23), a code
// that is a common abbreviation too is a warning ---
#model-test(model => {
  assert.eq(xml-elements(model, "ram:BilledQuantity"), (
    "<ram:BilledQuantity unitCode=\"MTK\">12.00</ram:BilledQuantity>",
    "<ram:BilledQuantity unitCode=\"C62\">3.00</ram:BilledQuantity>",
    "<ram:BilledQuantity unitCode=\"STK\">5.00</ram:BilledQuantity>",
  ))
  assert.eq(rules(model), ("BR-CL-23",))
  let d = diagnostic(model, "BR-CL-23")
  assert.eq(d.field, "item 2 (Hotel)")
  assert.eq(
    d.message,
    "The unit \"Nacht\" has no UN/ECE Recommendation 20 code (BT-130) invoice-pro knows.",
  )
  assert.eq(rules(model, level: "warning"), ("IP-UNIT-01",))
  assert.eq(
    diagnostic(model, "IP-UNIT-01").message,
    "The unit \"STK\" is written as the UN/ECE Recommendation 20 code for stick, although it is also a common abbreviation of \"Stück\".",
  )
})[
  #line-items[
    #item([Fliesen], price: 40, quantity: 12, unit: "qm")
    #item([Hotel], price: 1, quantity: 3, unit: "Nacht")
    #item([Schrauben], price: 1, quantity: 5, unit: "STK")
  ]
  #payment-goal(days: 14)
  #bank
]

// An explicit code is taken as it is
#model-test(model => {
  assert.eq(model.lines.map(l => l.unit-code), ("C62", "STK"))
  assert.eq(rules(model), ())
  assert.eq(rules(model, level: "warning"), ())
})[
  #line-items[
    #item([Hotel], price: 1, quantity: 3, unit: (display: "Nacht", code: "C62"))
    #item([Zigarren], price: 1, quantity: 5, unit: (
      display: "STK",
      code: "STK",
    ))
  ]
  #payment-goal(days: 14)
  #bank
]
