#import "/" + sys.inputs.tree + "/src/lib.typ": invoice-data
#let names = json("/proto/fuzz/names.json")
#metadata(names.map(n => (
  n,
  invoice-data.check(json("/proto/fuzz/corpus/" + n + ".json"), region: "de"),
))) <r>
