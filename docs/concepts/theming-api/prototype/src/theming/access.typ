// Sealing (INTERNAL optimisation, never part of the contract): the resolved theme
// travels through loom ctx inside an opaque `metadata` value, which Typst hashes
// lazily, so the ~20 ns/leaf/closure-call cost does not scale with theme size.
// Parts always receive an UNSEALED ctx: `ctx.theme` is a plain dict for them.
#let seal-enabled = sys.inputs.at("ip-seal", default: "1") == "1"

#let seal(theme) = if seal-enabled { metadata(theme) } else { theme }
#let theme-of(ctx) = {
  let t = ctx.at("theme", default: none)
  if type(t) == content { t.value } else { t }
}
#let unsealed(ctx) = {
  let t = ctx.at("theme", default: none)
  if type(t) == content { ctx + (theme: t.value) } else { ctx }
}
