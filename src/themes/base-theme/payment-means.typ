// Draws the payment means of `direct-debit`, `card-payment` and `paid` from
// the view the component prepares.
#let render-payment-means(ctx, view) = {
  let lines = ()
  let sentence = view.at("text", default: none)
  if sentence != none { lines.push(sentence) }
  for detail in view.at("details", default: ()) {
    let line = [#detail.label: #detail.value]
    if not detail.at("valid", default: true) {
      line += text(fill: rgb("#b91c1c"))[ (invalid)]
    }
    lines.push(line)
  }
  block(width: 100%, {
    set par(leading: 0.4em)
    set text(number-type: "lining")
    lines.join(linebreak())
  })
}
