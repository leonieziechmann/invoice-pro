#import "prelude.typ": *
// print one sheet with --input proof=1 and hold it against the envelope
#show: invoice.with(locale: locale.de-de, ..party, theme: theme.classic.with({
  import theme.custom: *
  envelopes(theme.layout.envelope.din-dl, (
    name: "ours-c6-5",
    size: (229mm, 114mm),
    fold: (87mm, 192mm),
    window: (left: 22mm, bottom: 16mm, width: 90mm, height: 45mm),
  ))
  proof(sys.inputs.at("proof", default: "") == "1")
}))
#body()
