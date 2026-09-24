// Factur-X XMP metadata (src/zugferd/xmp.typ), prepared for the day Typst
// can write custom XMP metadata. The references mustang-<letter>.xmp are the
// XMP metadata Mustang writes with `--action combine` for each profile
// letter; `scripts/zugferd-xmp --update` rewrites them, and the CI checks
// that they are still what Mustang writes.

#import "/src/zugferd/xmp.typ": (
  default-file-name, factur-x-metadata, factur-x-packet, factur-x-values,
  namespace,
)
#import "/src/zugferd/profile.typ": profiles, resolve-profile

// Mustang's profile letter of every profile.
#let letters = (
  minimum: "M",
  basic-wl: "W",
  basic: "B",
  en16931: "E",
  xrechnung: "X",
)

// The elements named `tag` in a tree of `xml` (which drops the namespace
// prefixes of the names).
#let find-all(node, tag) = {
  let found = ()
  if type(node) == array {
    for child in node { found += find-all(child, tag) }
  } else if type(node) == dictionary {
    if node.tag == tag { found.push(node) }
    found += find-all(node.children, tag)
  }
  found
}

#let children(element, tag) = element.children.filter(c => (
  type(c) == dictionary and c.tag == tag
))

#let text-of(element) = {
  element.children.filter(c => type(c) == str).join(default: "").trim()
}

// The Factur-X values of an XMP packet and the PDF/A description of the
// Factur-X extension schema.
#let facts(tree) = {
  let values = (:)
  for name in (
    "ConformanceLevel",
    "DocumentType",
    "DocumentFileName",
    "Version",
  ) {
    values.insert(name, find-all(tree, name).map(text-of))
  }
  let schemas = find-all(tree, "li").filter(li => (
    children(li, "schema").map(text-of) == ("Factur-X PDFA Extension Schema",)
  ))
  assert.eq(schemas.len(), 1, message: "one description of the schema")
  let schema = schemas.first()
  let properties = find-all(children(schema, "property"), "li").map(p => (
    ("name", "valueType", "category", "description").map(field => (
      children(p, field).map(text-of).join()
    ))
  ))
  (
    values: values,
    namespace: children(schema, "namespaceURI").map(text-of).join(),
    prefix: children(schema, "prefix").map(text-of).join(),
    properties: properties,
  )
}

// --- 1. Every profile states its conformance level ---
#{
  assert.eq(profiles.keys().sorted(), letters.keys().sorted())
  for (id, profile) in profiles {
    assert("xmp-level" in profile, message: id + " has no xmp-level")
  }
}

// --- 2. The metadata equals the metadata Mustang writes ---
#for (id, letter) in letters {
  let mustang = facts(xml("mustang-" + letter + ".xmp"))
  let packet = factur-x-packet(id)
  let ours = facts(xml(bytes(packet)))

  // The description of the extension schema, as PDF/A requires it.
  assert.eq(ours.namespace, mustang.namespace)
  assert.eq(ours.prefix, mustang.prefix)
  assert.eq(ours.properties, mustang.properties)
  // The namespaces are declared with the prefixes the names use.
  for declaration in (
    "xmlns:fx=\"" + namespace + "\"",
    "xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"",
    "xmlns:pdfaExtension=\"http://www.aiim.org/pdfa/ns/extension/\"",
    "xmlns:pdfaSchema=\"http://www.aiim.org/pdfa/ns/schema#\"",
    "xmlns:pdfaProperty=\"http://www.aiim.org/pdfa/ns/property#\"",
  ) {
    assert(packet.contains(declaration), message: declaration)
  }

  // The values: document type, version and conformance level as Mustang
  // states them.
  for name in ("ConformanceLevel", "DocumentType", "Version") {
    assert.eq(ours.values.at(name), mustang.values.at(name), message: id)
  }
  // The file name is the name of the attached XML: `file-name` of the
  // profile, else factur-x.xml. It equals Mustang's, which names the XML of
  // the XRECHNUNG profile xrechnung.xml, as ZUGFeRD 2.3 does.
  let file-name = profiles.at(id).at("file-name", default: default-file-name)
  assert.eq(ours.values.DocumentFileName, (file-name,))
  assert.eq(ours.values.DocumentFileName, mustang.values.DocumentFileName)
}

// --- 3. The data equals the packet ---
#for id in letters.keys() {
  let data = factur-x-metadata(id)
  let packet = facts(xml(bytes(factur-x-packet(id))))
  assert.eq(data.schema.uri, packet.namespace)
  assert.eq(data.schema.prefix, packet.prefix)
  assert.eq(
    data.schema.properties.map(p => (
      p.name,
      p.value-type,
      p.category,
      p.description,
    )),
    packet.properties,
  )
  for (name, value) in data.values {
    assert.eq(packet.values.at(name), (value,))
  }
}

// --- 4. A resolved profile and a profile that names its file ---
#{
  // `zugferd: auto` for a buyer in Germany tries XRechnung first.
  assert.eq(
    factur-x-values(resolve-profile(auto, "DE")).ConformanceLevel,
    "XRECHNUNG",
  )
  assert.eq(factur-x-values("basic-wl").ConformanceLevel, "BASIC WL")
  let named = profiles.en16931 + (file-name: "zugferd-invoice.xml")
  assert.eq(factur-x-values(named).DocumentFileName, "zugferd-invoice.xml")
}
