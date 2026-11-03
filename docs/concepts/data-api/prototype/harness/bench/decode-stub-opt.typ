// P9 decoder cost: decode + check of one data file (no invoice, no layout).
#import "/repo-opt/src/lib.typ": invoice-data
#let mode = sys.inputs.at("mode", default: "check")
#metadata(if mode == "none" { none } else {
  invoice-data.check(json(sys.inputs.f), region: "de").valid
}) <r>
