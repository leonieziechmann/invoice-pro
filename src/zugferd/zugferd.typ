// Entry point of the e-invoice generation: builds the data model, validates it
// and serializes the XML, which the write guard checks while it is written
// (G1, G2) and once more as the bytes that are attached (G4).

#import "model.typ": build-model
#import "profile.typ": switch-profile
#import "rules/engine.typ": run-rules
#import "build.typ": build-tree, xml-declaration
#import "xml.typ": dict-to-xml
// The code of the write guard loads with the other modules; the tables of a
// profile only when an invoice of the profile is written.
#import "guard/write.typ": malformed-kinds, root-tag

#let _has-errors(diagnostics) = diagnostics.any(d => d.level == "error")

// What only some invoices need (a fallback of `zugferd: auto`, a self-billed
// invoice) is in rare.typ, which loads when an invoice needs it.

/// Builds and checks the e-invoice of the computed invoice.
///
/// With `zugferd: auto`, the richest candidate profile the invoice satisfies
/// is chosen (see `resolve-profile`); the errors that ruled out a better one
/// are listed as warnings.
///
/// Returns `(profile: .., model: .., diagnostics: .., xml: ..)`. The XML is
/// always built; `diagnostics` lists every problem found (errors first), so
/// the caller decides whether to stop, report or ignore them.
///
/// -> dictionary
#let process-zugferd(
  ctx,
  item-data,
  payment-goal: none,
  bank: none,
  payment-means: none,
) = {
  let model = build-model(
    ctx,
    item-data,
    payment-goal: payment-goal,
    bank: bank,
    payment-means: payment-means,
  )
  let diagnostics = run-rules(model)

  // The model does not depend on the candidate profile, so switching the
  // profile only repeats the validation.
  let skipped = ()
  for id in model.profile.candidates.slice(1) {
    if not _has-errors(diagnostics) { break }
    skipped.push((
      id: model.profile.id,
      name: model.profile.name,
      diagnostics: diagnostics,
    ))
    model.profile = switch-profile(model.profile, id)
    diagnostics = run-rules(model)
  }
  if skipped.len() > 0 {
    import "rare.typ": skipped-warnings
    model.profile.skipped = skipped.map(c => (id: c.id, name: c.name))
    diagnostics += skipped-warnings(skipped, diagnostics)
  }

  // G1 + G2: the serializer checks every element while it writes it.
  let written = dict-to-xml(build-tree(model), model.profile.id)
  let xml-bytes = bytes(xml-declaration + written.xml)
  let findings = written.findings
  // G4: Typst's XML parser reads the bytes that are attached. The serializer
  // escapes all text and checks the names it writes, so the parser cannot
  // fail on them; a finding after which the document may not be well-formed
  // (an invalid name, a missing namespace, not one root element) skips the
  // parse, as a parse error would stop the compilation (it is an error
  // anyway).
  if findings.all(f => f.kind not in malformed-kinds) {
    // A loop, as a closure (`filter`) would hash the parsed document.
    let roots = ()
    for node in xml(xml-bytes) {
      if type(node) == dictionary { roots.push(node.tag) }
    }
    if roots != ("CrossIndustryInvoice",) {
      findings.push((kind: "well-formed", rule: none, path: (root-tag,)))
    }
  }
  if findings != () {
    // The report is loaded only for a document with findings.
    import "guard/report.typ": guard-diagnostics, merge
    diagnostics = merge(
      diagnostics,
      guard-diagnostics(findings, model.lines, model.profile.name),
    )
  }

  let document = model.invoice.at("document", default: (:))
  if document.at("self-billed", default: false) {
    import "rare.typ": self-billed-diagnostic
    diagnostics = diagnostics.map(self-billed-diagnostic)
  }

  (
    profile: model.profile,
    model: model,
    diagnostics: diagnostics,
    xml: xml-bytes,
  )
}
