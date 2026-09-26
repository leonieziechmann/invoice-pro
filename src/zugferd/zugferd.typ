// Entry point of the e-invoice: builds the model, validates it, writes the XML.

#import "model.typ": build-model
#import "profile.typ": switch-profile
#import "rules/engine.typ": run-rules
#import "build.typ": build-xml

#let _has-errors(diagnostics) = diagnostics.any(d => d.level == "error")

/// Builds and checks the e-invoice as `(profile: .., model: .., diagnostics:
/// .., xml: ..)`; the XML is built even with errors.
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

  // `zugferd: auto`: the next candidate while there are errors.
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

  let document = model.invoice.at("document", default: (:))
  if document.at("self-billed", default: false) {
    import "rare.typ": self-billed-diagnostic
    diagnostics = diagnostics.map(self-billed-diagnostic)
  }

  (
    profile: model.profile,
    model: model,
    diagnostics: diagnostics,
    xml: bytes(build-xml(model)),
  )
}
