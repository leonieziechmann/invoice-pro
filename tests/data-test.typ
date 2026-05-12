#import "/src/loom-wrapper.typ": loom, motif
#import "test-locale.typ": test-locale

/// A helper component to test computed values in the loom tree.
///
/// - test: A function `(ctx, children-data) => { ... }` that receives the current
///   loom context and an array of data computed by child components.
/// - body: The children to wrap.
#let data-test(test: (ctx, children-data) => {}, body) = motif(
  scope: ctx => ctx,
  measure: (ctx, children-data) => (children-data, none),
  draw: (ctx, public, _, body) => {
    let _ = test(ctx, public)
    body
  },
  body,
)
