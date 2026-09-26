// Rarely needed parts of `process-zugferd`, loaded only when needed.

// On a self-billed invoice the buyer is the `sender`, but the validator
// names the seller's inputs `sender`: swap them in the field and texts.
#let _other-party = (sender: "recipient", recipient: "sender")

#let _swap-parties(text) = {
  if type(text) != str { return text }
  text
    .replace("the sender", "\u{E000}")
    .replace("the recipient", "the sender")
    .replace("\u{E000}", "the recipient")
}

/// A diagnostic with the parties swapped for a self-billed invoice.
///
/// -> dictionary
#let self-billed-diagnostic(d) = {
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

/// The errors that ruled out better candidate profiles, as warnings, unless
/// the chosen profile reports the same field with the same rule or message.
///
/// -> array
#let skipped-warnings(skipped, diagnostics) = {
  let reported = diagnostics.map(d => (d.rule, d.field))
  let problems = diagnostics.map(d => (d.field, d.message))
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
