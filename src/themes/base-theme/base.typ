#import "line-items.typ": *
#import "bank-details.typ": render-bank-details
#import "payment-means.typ": render-payment-means
#import "payment-goal.typ": render-payment-goal
#import "signature.typ": render-signature

#import "../../loom-wrapper.typ": eval-content
#import "../../utils/types.typ"

// The default e-invoice report; imports its module only when it is shown.
#let _render-zugferd-report(ctx, result) = {
  import "../../zugferd/report.typ": render-zugferd-report
  render-zugferd-report(ctx, result)
}

#let base-theme(
  /// Styles the document root.
  /// -> (ctx, content) => content
  document: (ctx, body) => body,
  /// Page header, evaluated by the weave loop; may contain motifs.
  /// -> content
  header: none,
  /// Page footer, evaluated by the weave loop; may contain motifs.
  /// -> content
  footer: none,
  /// -> (ctx, dictionary, content) => content
  line-items: render-line-items,
  /// -> (ctx, dictionary) => content
  bank-details: render-bank-details,
  /// Layout of a direct debit, a payment card or a paid invoice.
  /// -> (ctx, dictionary) => content
  payment-means: render-payment-means,
  /// -> (ctx, dictionary) => content
  payment-goal: render-payment-goal,
  /// -> (ctx, dictionary) => content
  signature: render-signature,
  /// Layout of the e-invoice problems (`zugferd-errors: "report"`); with
  /// `none`, errors stop the compilation.
  /// -> none | (ctx, dictionary) => content
  zugferd-report: _render-zugferd-report,
  /// Flags of what `document` prints besides the body: `references`,
  /// `party-extra` and `page-content` (set by `header` and `footer`).
  /// -> dictionary
  prints: (:),
) = {
  types.require(zugferd-report, "theme::zugferd-report", none, function)
  types.require(prints, "theme::prints", dictionary)
  (
    document: (ctx, body) => {
      if header != none and header != [] {
        set page(header: eval-content(ctx, header))
      }
      if footer != none and footer != [] {
        set page(footer: eval-content(ctx, footer))
      }
      document(ctx, body)
    },
    header: header,
    footer: footer,
    line-items: line-items,
    bank-details: bank-details,
    payment-means: payment-means,
    payment-goal: payment-goal,
    signature: signature,
    zugferd-report: zugferd-report,
    prints: (references: false, party-extra: false, page-content: false)
      + prints
      + if header not in (none, []) or footer not in (none, []) {
        (page-content: true)
      } else { (:) },
  )
}
