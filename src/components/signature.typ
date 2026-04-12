#import "../loom-wrapper.typ": loom, managed-motif
#import "../utils/types.typ"

#let signature(
  name: auto,
  signature: none,
) = {
  types.require(name, "signature::name", none, auto, str, content)
  types.require(signature, "signature::signature", none, content)

  managed-motif(
    "signature",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      derive("sender", "name", name, default: "")

      nest("theme", {
        ensure("signature", (..) => [Signature])
      })
    }),
    measure: (ctx, _) => {
      let data = (
        name: if name == auto { ctx.sender.name } else { name },
        signature: signature,
      )

      (none, data)
    },
    draw: (ctx, _, view, ..) => (ctx.theme.signature)(ctx, view),
    none,
  )
}
