// Payment terms (BT-20) keep their line breaks, so a cash discount in the
// XRechnung Skonto syntax stays on a line of its own, and XRechnung checks
// that syntax (BR-DE-18).

#import "/src/lib.typ": *
#import "/tests/zugferd/harness.typ": (
  bank, buyer-de, diagnostic, model-test, rules, xml-values,
)

#let skonto = "#SKONTO#TAGE=14#PROZENT=2.00#"
#let xrechnung = (zugferd: "xrechnung", recipient: buyer-de)

// --- 1. A Skonto line as `due-date` ends with a line break, also if it was
// not typed ---
#model-test(..xrechnung, due-date: skonto + "\n", model => {
  assert.eq(model.payment.terms, skonto + "\n")
  assert.eq(model.payment.terms-input, "due-date")
  assert.eq(rules(model), ())
  assert.eq(xml-values(model, "ram:Description"), (skonto + "\n",))
})[
  #line-items[#item([Consulting], price: 100, quantity: 2, unit: unit.hour)]
  #bank
]

#model-test(..xrechnung, due-date: skonto, model => {
  assert.eq(model.payment.terms, skonto + "\n")
  assert.eq(rules(model), ())
})[
  #line-items[#item([Consulting], price: 100, quantity: 2, unit: unit.hour)]
  #bank
]

// --- 2. Text and Skonto lines of a payment goal stay separate lines ---
#model-test(..xrechnung, model => {
  assert.eq(
    model.payment.terms,
    "Zahlbar innerhalb von 30 Tagen netto.\n"
      + skonto
      + "\n#SKONTO#TAGE=7#PROZENT=3.00#BASISBETRAG=150.00#\n",
  )
  assert.eq(model.payment.terms-input, "payment-goal")
  assert.eq(rules(model), ())
})[
  #line-items[#item([Consulting], price: 100, quantity: 2, unit: unit.hour)]
  #payment-goal(
    date: "Zahlbar innerhalb von 30 Tagen netto.  \n  "
      + skonto
      + "\n#SKONTO#TAGE=7#PROZENT=3.00#BASISBETRAG=150.00#",
  )
  #bank
]

// A line of text that ends with its second "#" after the last Skonto line
// gets the line break as well
#model-test(..xrechnung, due-date: skonto + "\nRef. #A-1#", model => {
  assert.eq(model.payment.terms, skonto + "\nRef. #A-1#\n")
  assert.eq(rules(model), ())
})[
  #line-items[#item([Consulting], price: 100, quantity: 2, unit: unit.hour)]
  #bank
]

// --- 3. A "#" in a line of text is no Skonto line ---
#model-test(
  ..xrechnung,
  due-date: "Zahlbar bis zum 30.09. (Auftrag #12)",
  model => {
    assert.eq(rules(model), ())
  },
)[
  #line-items[#item([Consulting], price: 100, quantity: 2, unit: unit.hour)]
  #bank
]

// --- 4. A line that starts with "#" but breaks the syntax is an error in
// XRechnung (BR-DE-18) ---
#model-test(
  ..xrechnung,
  due-date: "Zahlbar sofort.\n#SKONTO#TAGE=14#PROZENT=2#",
  model => {
    assert.eq(rules(model), ("BR-DE-18",))
    let d = diagnostic(model, "BR-DE-18")
    assert.eq(d.field, "due-date")
    assert(
      d.message.ends-with(
        "followed by a line break, but \"#SKONTO#TAGE=14#PROZENT=2#\" is not.",
      ),
      message: d.message,
    )

    // A missing line break after the last Skonto line breaks the syntax too
    let m = model
    m.payment.terms = skonto
    assert.eq(rules(m), ("BR-DE-18",))
    assert(diagnostic(m, "BR-DE-18").message.ends-with("line break."))
    // Spaces and tabs may end the line, as `\s` of the XRechnung validation
    // allows, but not a no-break space
    m.payment.terms = skonto + " \t\r\n"
    assert.eq(rules(m), ())
    m.payment.terms = skonto + "\u{a0}\n"
    assert.eq(rules(m), ("BR-DE-18",))
    // Only lines that start with "#" are Skonto lines
    m.payment.terms = "Zahlbar sofort. " + skonto + "\n"
    assert.eq(rules(m), ())
    m.payment.terms = "#TAGE=14#\n"
    assert.eq(rules(m), ("BR-DE-18",))

    // XRechnung reads the text between the first and the last "#" of a line
    // as a cash discount: after the last one, a line break must follow it
    m.payment.terms = skonto + "\nBitte Ref. #A-1# angeben\n"
    assert.eq(rules(m), ("BR-DE-18",))
    assert(
      diagnostic(m, "BR-DE-18")
        .message
        .ends-with(
          "but \"Bitte Ref. #A-1# angeben\" goes on after its last \"#\".",
        ),
      message: diagnostic(m, "BR-DE-18").message,
    )
    m.payment.terms = "Bitte Ref. #A-1# angeben\n" + skonto + "\n"
    assert.eq(rules(m), ())
    m.payment.terms = skonto + "\nRef. #A-1#\n"
    assert.eq(rules(m), ())
    m.payment.terms = skonto + "\nRef. ## 12\n"
    assert.eq(rules(m), ())

    // EN 16931 has no Skonto syntax: the terms are free text there
    m.profile = model.profile + (id: "en16931", xrechnung: false)
    m.payment.terms = "#12"
    assert.eq(rules(m), ())
  },
)[
  #line-items[#item([Consulting], price: 100, quantity: 2, unit: unit.hour)]
  #bank
]
