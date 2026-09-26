// The test oracle of the e-invoice XML: the checks the XML of every test
// invoice passes, on top of the rules of the validator (src/zugferd/rules/).
// An invoice the validator lets through must pass them all, or the XML
// would be invalid without a word (tests/zugferd/harness.typ checks this for
// every invoice of `model-test`).
//
// - G1, G2: the guard writer (write.typ) checks every element of the
//   builder's tree against the tables of the profile, which gen_guard.py
//   compiles from the official XSD and Schematron artefacts, and writes the
//   XML the serializer of the package must write too.
// - G4: Typst's XML parser reads the XML, with one root element.
// - G3: the XML states what the data model states, every line included
//   (roundtrip.typ), and its amounts add up as the official rules require
//   (strict.typ).
//
// A finding is `(kind: .., rule: .., path: .., ..details)` (see report.typ).

#import "/src/zugferd/build.typ": build-tree, xml-declaration
#import "/src/zugferd/xml.typ": dict-to-xml
#import "/src/zugferd/model.typ": profile-terms
#import "write.typ": malformed-kinds, root-tag, write
#import "roundtrip.typ": round-trip
#import "strict.typ": strict-findings

/// The findings of the oracle for the XML of an e-invoice data model.
///
/// -> array
#let oracle-findings(model) = {
  let tree = build-tree(model)
  let written = write(tree, model.profile.id)
  let findings = written.findings
  let serialized = dict-to-xml(tree)
  if serialized != written.xml {
    findings.push((
      kind: "serializer",
      rule: none,
      path: (root-tag,),
      written: serialized,
      expected: written.xml,
    ))
  }
  // After a finding of these kinds the XML may not be well-formed, and a
  // parse error would stop the compilation.
  if findings.any(f => f.kind in malformed-kinds) { return findings }
  let roots = ()
  let root = none
  for node in xml(bytes(xml-declaration + serialized)) {
    if type(node) == dictionary {
      roots.push(node.tag)
      root = node
    }
  }
  if roots != ("CrossIndustryInvoice",) {
    findings.push((kind: "well-formed", rule: none, path: (root-tag,)))
  } else if findings == () {
    // The round trip compares a document of the schema whose values have
    // their lexical form: one without findings of G1 and G2.
    findings = round-trip(
      root,
      model,
      profile-terms(model.payment, model.profile),
      strict: true,
    )
    findings += strict-findings(root, model)
  }
  findings
}
