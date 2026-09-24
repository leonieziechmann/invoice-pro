// The write guard on mutated e-invoices (tools/zugferd/mutate.py): reads
// the XML of each case with Typst's XML parser, turns it back into the
// element tree the builder writes (see src/zugferd/guard/write.typ) and
// serializes the tree with the guard. The result is the metadata
// <guard-results>, for `typst query`: per case its id, the XML written and
// the findings as (kind, rule, path).
//
//   typst query --root . --input cases=/build/.../cases.json \
//     tools/zugferd/mutate.typ "<guard-results>" --field value --one
//
// `cases` is a JSON file of (id, path, profile), paths from the root.
// Typst's parser drops the namespace prefixes: the tree gets them back by
// the convention of CII (rsm for the root and its children, udt and qdt for
// the data types, ram for everything else). mutate.py compares the XML
// written here with the mutant, so a case the tree does not express as it
// is (e.g. a repeated element with another one between) is noticed.

#import "/src/zugferd/xml.typ": dict-to-xml
#import "/src/zugferd/guard/write.typ": namespaces

#let _xsi = "http://www.w3.org/2001/XMLSchema-instance"

// The prefix of an element by the convention of CII.
#let _prefix(tag, parent, depth) = if depth <= 1 { "rsm:" } else if (
  tag == "DateTimeString" and parent == "FormattedIssueDateTime"
) { "qdt:" } else if tag in ("DateTimeString", "DateString", "Indicator") {
  "udt:"
} else { "ram:" }

// The builder's tree of an element node of `xml()`: its text, or a
// dictionary of its attributes (`@name`), text (`""`) and children, with an
// array for consecutive elements of the same name; `(:)` for an element
// without anything. `none` for what the tree cannot express: text between
// elements, or elements of one name with another one between.
#let _tree(node, depth) = {
  let out = (:)
  for (name, value) in node.attrs { out.insert("@" + name, value) }
  let elements = node.children.filter(c => type(c) == dictionary)
  let text = node.children.filter(c => type(c) == str).join()
  if elements == () {
    if text == none or text == "" { return out }
    return if out == (:) { text } else { out + ("": text) }
  }
  if text != none and text.trim() != "" { return none }
  let last = none
  for child in elements {
    let key = _prefix(child.tag, node.tag, depth + 1) + child.tag
    let value = _tree(child, depth + 1)
    if value == none { return none }
    if key in out {
      if key != last { return none }
      let items = out.at(key)
      out.insert(key, if type(items) == array { items + (value,) } else {
        (items, value)
      })
    } else { out.insert(key, value) }
    last = key
  }
  out
}

// Runs the guard on one case.
#let _case(case) = {
  let roots = xml(case.path).filter(n => type(n) == dictionary)
  let root = roots.first()
  let body = _tree(root, 0)
  if body == none or type(body) != dictionary {
    return (id: case.id, representable: false)
  }
  // The parser drops the namespace declarations; the tree has them first.
  let declarations = (:)
  for (name, uri) in namespaces { declarations.insert("@" + name, uri) }
  declarations.insert("@xmlns:xsi", _xsi)
  let tree = ((_prefix(root.tag, none, 0) + root.tag): declarations + body)
  let written = dict-to-xml(tree, case.profile)
  (
    id: case.id,
    representable: true,
    xml: written.xml,
    findings: written.findings.map(f => (f.kind, f.rule, f.path.join("/"))),
  )
}

#metadata(json(sys.inputs.cases).map(_case)) <guard-results>
