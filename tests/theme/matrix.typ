// Look x layout matrix (prototype tests/matrix.typ, scripts/checks-presets.sh):
// ONE body, any look on any layout (CI rule: looks patch only look-safe area
// fields). Every case renders the shared 4-item body with a brand colour and a
// logo, and no case publishes a draft finding (no theme or render-time issue:
// strict would pass too).
#import "/tests/theme/body.typ": *
#import "/tests/theme/looks.typ": minimal
#import "/tests/theme/harness.typ": case, close-cases, issues-of, spans

#let brand = theme.custom.brand(color: rgb("#0f766e"), logo: logo-img)

/// Renders every (look, layout) pair; `look` is a preset name or "minimal".
/// -> content
#let matrix(pairs) = {
  for (look, lay) in pairs {
    let preset = if look == "minimal" { minimal } else { preset-of(look) }
    case(
      look + "/" + lay,
      theme: preset.with(brand, layout: layout-of(lay)),
      locale: test-locale,
      ..party,
      body(n: 4),
    )
  }
  close-cases()
  context {
    assert.eq(spans().len(), pairs.len())
    let found = pairs
      .map(((look, lay)) => (look + "/" + lay, issues-of(look + "/" + lay)))
      .filter(((k, i)) => i.len() > 0)
      .map(((k, i)) => k + ": " + i.map(x => x.id).join(", "))
    assert(found == (), message: "findings: " + found.join("; "))
  }
}
