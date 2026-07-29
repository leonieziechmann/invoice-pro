#let trans(template, string-handler, ..args) = {
  if type(template) == string {
    string-handler(template, ..args)
  } else if type(template) == function {
    template(..args)
  } else {
    panic("expected template to be string or function, have: " + type(template))
  }
}
