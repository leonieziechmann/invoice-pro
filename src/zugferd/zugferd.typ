// Entry point of the e-invoice: builds the model, validates it, writes the XML.

#import "model.typ": build-model
#import "profile.typ": switch-profile
#import "rules/engine.typ": diagnostics as rule-diagnostics, run-rules
#import "rules/equivalence.typ": findings as equivalence-findings
#import "build.typ": build-xml

#let _has-errors(diagnostics) = diagnostics.any(d => d.level == "error")

// Adds the invariants (rules/equivalence.typ), errors first.
#let _with-invariants(diagnostics, invariants) = {
  let errors = ()
  let warnings = ()
  for d in diagnostics + rule-diagnostics(invariants) {
    if d.level == "error" { errors.push(d) } else { warnings.push(d) }
  }
  errors + warnings
}

/// Builds and checks the e-invoice: `(profile: .., model: .., diagnostics:
/// .., xml: ..)`, with the XML built even with errors.
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
  // The totals the invoice prints, else those of the line items.
  let printed = ctx.at("global", default: (:)).at("total", default: none)
  if type(printed) != dictionary or printed == (:) {
    printed = (
      net: item-data.at("net-total", default: decimal("0")),
      gross: item-data.at("gross-total", default: decimal("0")),
      prepaid: item-data.at("prepaid-total", default: decimal("0")),
      due: item-data.at("due-total", default: decimal("0")),
    )
  }
  let diagnostics = run-rules(model)
  // All but PEPPOL-EN16931-R120 hold for every candidate (XRechnung is first).
  let invariants = equivalence-findings(model, item-data, printed)
  if invariants != () {
    diagnostics = _with-invariants(diagnostics, invariants)
  }

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
    invariants = invariants.filter(f => f.key != "PEPPOL-EN16931-R120")
    if invariants != () {
      diagnostics = _with-invariants(diagnostics, invariants)
    }
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
