// data.check over design D's 51 conformance fixtures, as written by
// D (their expectations assumed D's declared extensions; here only the
// agreement of the decoder with python-jsonschema is compared).
#import "/repo/src/lib.typ": data
#let cases = json("d-fixtures.json")
#metadata(cases.map(c => (
  name: c.name,
  report: data.check(c.doc),
))) <r>
