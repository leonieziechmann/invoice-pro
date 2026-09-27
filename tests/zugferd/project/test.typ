// The project (`project`) is written as the project reference (BT-11,
// `ram:SpecifiedProcuringProject`) in EN 16931 and XRechnung, the only
// profiles that have it.

#import "/src/lib.typ": *
#import "/src/zugferd/profile.typ": resolve-profile
#import "/tests/zugferd/harness.typ": (
  bank, diagnostic, model-test, rules, xml-elements,
)

#model-test(project: [Projekt *Apollo*], model => {
  assert.eq(model.invoice.project, "Projekt Apollo")
  let expected = (
    "<ram:SpecifiedProcuringProject><ram:ID>Projekt Apollo</ram:ID><ram:Name>Projekt Apollo</ram:Name></ram:SpecifiedProcuringProject>",
  )
  assert.eq(xml-elements(model, "ram:SpecifiedProcuringProject"), expected)
  assert.eq(rules(model, level: "warning"), ())

  let m = model
  m.profile = resolve-profile("xrechnung", "DE")
  assert.eq(xml-elements(m, "ram:SpecifiedProcuringProject"), expected)

  // BASIC and the profiles below it have no project reference
  for id in ("basic", "basic-wl", "minimum") {
    m.profile = resolve-profile(id, "FR")
    assert.eq(xml-elements(m, "ram:SpecifiedProcuringProject"), ())
    assert.eq(rules(m, level: "warning"), ("IP-PROFILE-01",))
    assert.eq(diagnostic(m, "IP-PROFILE-01").field, "project")
  }
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]

// Without a project, nothing is written
#model-test(model => {
  assert.eq(model.invoice.project, none)
  assert.eq(xml-elements(model, "ram:SpecifiedProcuringProject"), ())
})[
  #line-items[#item([Consulting], price: 1000)]
  #payment-goal(days: 14)
  #bank
]
