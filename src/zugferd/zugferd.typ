// Entry point of the e-invoice generation: builds the data model, validates it
// and serializes the XML, which the write guard checks while it is written
// (G1, G2), reads back as the bytes that are attached (G4) and compares with
// the data model (G3).

#import "model.typ": build-model, profile-terms
#import "profile.typ": switch-profile
#import "rules/engine.typ": diagnostics as rule-diagnostics, run-rules
#import "rules/equivalence.typ": findings as equivalence-findings
#import "build.typ": build-tree, xml-declaration
#import "xml.typ": dict-to-xml
// The code of the write guard loads with the other modules; the tables of a
// profile only when an invoice of the profile is written.
#import "guard/write.typ": malformed-kinds, root-tag
#import "guard/roundtrip.typ": round-trip

#let _has-errors(diagnostics) = diagnostics.any(d => d.level == "error")

// The diagnostics of the validator with the invariants that the model
// states what the invoice prints (rules/equivalence.typ), errors first,
// each level in the order of the checks.
#let _with-invariants(diagnostics, invariants) = {
  let errors = ()
  let warnings = ()
  for d in diagnostics + rule-diagnostics(invariants) {
    if d.level == "error" { errors.push(d) } else { warnings.push(d) }
  }
  errors + warnings
}

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
/// With `strict: true` (`zugferd-strict`), the write guard also compares
/// every line of the XML with the data model and checks the arithmetic of
/// the amounts it states (guard/strict.typ, which loads only then).
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
  strict: false,
) = {
  let model = build-model(
    ctx,
    item-data,
    payment-goal: payment-goal,
    bank: bank,
    payment-means: payment-means,
  )
  // The totals the invoice prints (`ctx.global.total` of the root), else
  // those of the line items.
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
  // The invariants do not depend on the profile, except the rule of
  // XRechnung among them (PEPPOL-EN16931-R120), the first candidate if any.
  let invariants = equivalence-findings(model, item-data, printed)
  if invariants != () {
    diagnostics = _with-invariants(diagnostics, invariants)
  }

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
    invariants = invariants.filter(f => f.key != "PEPPOL-EN16931-R120")
    if invariants != () {
      diagnostics = _with-invariants(diagnostics, invariants)
    }
  }
  if skipped.len() > 0 {
    model.profile.skipped = skipped.map(c => (id: c.id, name: c.name))
    diagnostics += _skipped-warnings(skipped, diagnostics)
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
    let root = none
    for node in xml(xml-bytes) {
      if type(node) == dictionary {
        roots.push(node.tag)
        root = node
      }
    }
    if roots != ("CrossIndustryInvoice",) {
      findings.push((kind: "well-formed", rule: none, path: (root-tag,)))
    } else if findings == () {
      // G3: the XML states what the model states (guard/roundtrip.typ); in
      // the strict mode every line, and the arithmetic of the amounts. It
      // compares a document of the schema whose values have their lexical
      // form, so only one without findings of G1 and G2, which are errors
      // anyway.
      findings = round-trip(
        root,
        model,
        profile-terms(model.payment, model.profile),
        strict: strict,
      )
      if strict {
        import "guard/strict.typ": strict-findings
        findings += strict-findings(root, model)
      }
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
    diagnostics = diagnostics.map(_self-billed-diagnostic)
  }

  (
    profile: model.profile,
    model: model,
    diagnostics: diagnostics,
    xml: xml-bytes,
  )
}
