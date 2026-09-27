// Test harness of the e-invoice conformance corpus (tools/zugferd/run.py).
//
// `harness(theme)` wraps a theme so that, with `zugferd-errors: "report"`,
// the diagnostics of invoice-pro's own validation are attached to the PDF as
// `invoice-pro-diagnostics.json` instead of being rendered. One compilation
// then yields both the XML invoice-pro writes and its verdict on it.
//
//   #import "/src/lib.typ": *
//   #import "/tools/zugferd/harness.typ": harness
//   #show: invoice.with(
//     theme: harness(themes.blank),
//     zugferd: "en16931",
//     zugferd-errors: "report",
//     ..
//   )
//
// The hook only runs when there are diagnostics: a PDF without the
// attachment means that invoice-pro reported nothing.

#let _text(value) = if value == none or type(value) == str { value } else {
  repr(value)
}

// A diagnostic as plain JSON data. Unknown fields are kept, so the runner
// sees additions such as `source` or `terms` without a harness change.
#let _diagnostic(d) = {
  let out = (:)
  for (key, value) in d {
    out.insert(key, if type(value) == array { value.map(_text) } else {
      _text(value)
    })
  }
  out
}

#let _profile(profile) = (
  id: _text(profile.at("id", default: none)),
  name: _text(profile.at("name", default: none)),
  automatic: profile.at("automatic", default: false),
  skipped: profile
    .at("skipped", default: ())
    .map(c => _text(c.at("id", default: none))),
)

#let _report(ctx, result) = pdf.attach(
  "/invoice-pro-diagnostics.json",
  bytes(json.encode(
    (
      profile: _profile(result.profile),
      diagnostics: result.diagnostics.map(_diagnostic),
    ),
    pretty: false,
  )),
  mime-type: "application/json",
  description: "invoice-pro diagnostics (conformance test harness)",
)

/// Wraps a theme (a function returning the theme dictionary) so that the
/// e-invoice diagnostics are attached as JSON.
///
/// -> function
#let harness(theme) = () => theme() + (zugferd-report: _report)
