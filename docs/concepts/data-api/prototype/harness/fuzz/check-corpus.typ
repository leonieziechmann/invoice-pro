#import "/" + sys.inputs.tree + "/src/lib.typ": data
#let names = json("/proto/fuzz/names.json")
#metadata(names.map(n => (
  n,
  data.check(json("/proto/fuzz/corpus/" + n + ".json"), region: "de"),
))) <r>
