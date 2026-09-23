// Entry point of the e-invoice generation: builds the data model, validates it
// and serializes the XML.

#import "model.typ": build-model
#import "validate.typ": validate
#import "build.typ": build-xml

/// Builds and checks the e-invoice of the computed invoice.
///
/// Returns `(profile: .., model: .., diagnostics: .., xml: ..)`. The XML is
/// always built; `diagnostics` lists every problem found (errors first), so
/// the caller decides whether to stop, report or ignore them.
///
/// -> dictionary
#let process-zugferd(ctx, item-data, payment-goal: none, bank: none) = {
  let model = build-model(
    ctx,
    item-data,
    payment-goal: payment-goal,
    bank: bank,
  )
  (
    profile: model.profile,
    model: model,
    diagnostics: validate(model),
    xml: bytes(build-xml(model)),
  )
}
