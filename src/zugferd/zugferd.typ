// Entry point of the e-invoice generation: builds the data model, validates it
// and serializes the XML.

#import "model.typ": build-model
#import "profile.typ": switch-profile
#import "validate.typ": validate
#import "build.typ": build-xml

#let _has-errors(diagnostics) = diagnostics.any(d => d.level == "error")

// On a self-billed invoice, the sender of the document is the buyer and its
// recipient the seller (see `build-model`). The validator names the inputs
// of the seller as `sender` and those of the buyer as `recipient`, so they
// change places in the field and the texts of each diagnostic.
#let _other-party = (sender: "recipient", recipient: "sender")

#let _swap-parties(text) = {
  if type(text) != str { return text }
  text
    .replace("the sender", "\u{E000}")
    .replace("the recipient", "the sender")
    .replace("\u{E000}", "the recipient")
}

#let _self-billed-diagnostic(d) = {
  let field = d.at("field", default: none)
  if type(field) == str {
    let (first, ..rest) = field.split(".")
    if first in _other-party {
      field = (_other-party.at(first), ..rest).join(".")
    }
  }
  (
    d
      + (
        field: field,
        message: _swap-parties(d.at("message", default: none)),
        hint: _swap-parties(d.at("hint", default: none)),
      )
  )
}

// The errors that kept a better candidate profile out of reach and that the
// chosen profile does not report itself, as warnings of the chosen profile.
// A problem the chosen profile reports as an error under a rule of its own
// (e.g. two payment means: `BR-DE-23-b` in XRechnung, `IP-PAY-03` in
// EN 16931) has the same field and message, and is not listed twice either.
#let _skipped-warnings(skipped, diagnostics) = {
  let reported = diagnostics.map(d => (d.rule, d.field))
  let problems = diagnostics
    .filter(d => d.level == "error")
    .map(d => (d.field, d.message))
  let warnings = ()
  for candidate in skipped {
    for d in candidate.diagnostics {
      if (
        d.level == "error"
          and (d.rule, d.field) not in reported
          and (d.field, d.message) not in problems
      ) {
        reported.push((d.rule, d.field))
        warnings.push(
          d
            + (
              level: "warning",
              message: "Needed for " + candidate.name + ": " + d.message,
            ),
        )
      }
    }
  }
  warnings
}

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
  let diagnostics = validate(model)

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
    diagnostics = validate(model)
  }
  if skipped.len() > 0 {
    model.profile.skipped = skipped.map(c => (id: c.id, name: c.name))
    diagnostics += _skipped-warnings(skipped, diagnostics)
  }
  let document = model.invoice.at("document", default: (:))
  if document.at("self-billed", default: false) {
    diagnostics = diagnostics.map(_self-billed-diagnostic)
  }

  (
    profile: model.profile,
    model: model,
    diagnostics: diagnostics,
    xml: bytes(build-xml(model)),
  )
}
