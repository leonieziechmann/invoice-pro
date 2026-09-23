#import "line-items.typ": *
#import "bank-details.typ": render-bank-details
#import "payment-means.typ": render-payment-means
#import "payment-goal.typ": render-payment-goal
#import "signature.typ": render-signature

#import "../../loom-wrapper.typ": eval-content
#import "../../utils/types.typ"

// The default e-invoice report. Its module is loaded only when a report is
// shown, so that invoices without an e-invoice load no e-invoice code.
#let _render-zugferd-report(ctx, result) = {
  import "../../zugferd/report.typ": render-zugferd-report
  render-zugferd-report(ctx, result)
}

#let base-theme(
  /// Document Root Styling.
  /// -> (ctx, content) => content
  document: (ctx, body) => body,
  /// Header that will be evaluted by the weave loop and then by appled to the
  /// document. Can include motifs/active items.
  /// -> content
  header: none,
  /// Footer that will be evaluted by the weave loop and then by appled to the
  /// document. Can include motifs/active items.
  /// -> content
  footer: none,
  /// Layout of the aggregated line item data.
  /// -> (ctx, dictionary, content) => content
  line-items: render-line-items,
  /// Layout of the bank-details the customer should send the payment to.
  /// -> (ctx, dictionary) => content
  bank-details: render-bank-details,
  /// Layout of the other payment means: a direct debit, a payment card, a
  /// paid invoice.
  /// -> (ctx, dictionary) => content
  payment-means: render-payment-means,
  /// Layout of the payment-goal. Time until payment is due.
  /// -> (ctx, dictionary) => content
  payment-goal: render-payment-goal,
  /// Layout of the signature.
  /// -> (ctx, dictionary) => content
  signature: render-signature,
  /// Layout of the e-invoice problems listed with `zugferd-errors: "report"`.
  /// `none` shows no list; errors then stop the compilation as with
  /// `zugferd-errors: "panic"`.
  /// -> none | (ctx, dictionary) => content
  zugferd-report: _render-zugferd-report,
) = {
  types.require(zugferd-report, "theme::zugferd-report", none, function)
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
  )
}
