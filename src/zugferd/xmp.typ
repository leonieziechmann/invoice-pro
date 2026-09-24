// Factur-X XMP metadata of a hybrid e-invoice PDF, prepared for the day Typst
// can write custom XMP metadata (https://github.com/typst/typst/issues/5667).
//
// A Factur-X / ZUGFeRD PDF/A-3 announces its XML in the XMP metadata of the
// PDF: the properties of the Factur-X extension schema (`fx:DocumentType`,
// `fx:DocumentFileName`, `fx:Version` and `fx:ConformanceLevel`) and, as PDF/A
// requires for every extension schema, the description of that schema in
// `pdfaExtension:schemas`. Typst cannot write custom XMP metadata yet, so no
// code calls this module: invoice-pro attaches the XML, and validators that
// check the PDF itself miss the metadata (docs/docs/e-invoicing.md, "Factur-X
// XMP Metadata").
//
// Once Typst supports it, the attachment of the XML in
// src/components/root.typ hands `factur-x-metadata(result.profile)` (or the
// packet) to the new API, for a valid e-invoice only: an XML attached as a
// draft (`zugferd-errors: "report"` with errors) is no Factur-X invoice. The
// CI test `scripts/zugferd-xmp` fails as soon as the pinned Typst offers a
// new PDF feature, so the integration is not missed.
//
// tests/zugferd/xmp compares the metadata with the XMP that Mustang writes
// (`--action combine`) for every profile.

#import "profile.typ": profiles

/// Namespace URI of the Factur-X extension schema: Factur-X 1.0, which
/// ZUGFeRD 2.1 and later use as well.
#let namespace = "urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#"
/// Namespace prefix of the Factur-X extension schema.
#let prefix = "fx"
/// Name of the Factur-X extension schema in its PDF/A description.
#let schema-name = "Factur-X PDFA Extension Schema"
/// Version of the Factur-X XML schema (`fx:Version`).
#let version = "1.0"
/// Name of the attached XML when the profile names none (`file-name`).
#let default-file-name = "factur-x.xml"

/// The properties of the Factur-X extension schema, in the order of its
/// PDF/A description.
#let properties = (
  (
    name: "DocumentFileName",
    value-type: "Text",
    category: "external",
    description: "name of the embedded XML invoice file",
  ),
  (
    name: "DocumentType",
    value-type: "Text",
    category: "external",
    description: "INVOICE",
  ),
  (
    name: "Version",
    value-type: "Text",
    category: "external",
    description: "The actual version of the ZUGFeRD XML schema",
  ),
  (
    name: "ConformanceLevel",
    value-type: "Text",
    category: "external",
    description: "The selected ZUGFeRD profile completeness",
  ),
)

// A profile id (`"en16931"`) or a profile dictionary (`resolve-profile`).
#let _profile(profile) = if type(profile) == str {
  profiles.at(profile)
} else { profile }

// The values are fixed texts of the package; escaped all the same.
#let _escape(value) = (
  value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
)

/// The values of the Factur-X properties of a profile, in the order of the
/// XMP metadata Mustang writes: the document type (always `INVOICE`, credit
/// notes included), the name of the attached XML, the version of the schema
/// and the conformance level of the profile (`xmp-level` of the profile
/// table).
///
/// -> dictionary
#let factur-x-values(profile) = {
  let profile = _profile(profile)
  (
    ConformanceLevel: profile.xmp-level,
    DocumentType: "INVOICE",
    DocumentFileName: profile.at("file-name", default: default-file-name),
    Version: version,
  )
}

/// The Factur-X metadata as data, as an API for custom XMP metadata would
/// take it (the design of typst/typst#5667 takes a schema and its values):
/// the schema with its name, namespace, prefix and properties, and the values
/// of the profile.
///
/// -> dictionary
#let factur-x-metadata(profile) = (
  schema: (
    name: schema-name,
    uri: namespace,
    prefix: prefix,
    properties: properties,
  ),
  values: factur-x-values(profile),
)

/// The Factur-X metadata as RDF/XML: an `rdf:Description` with the values
/// and one with the PDF/A description of the extension schema. The XMP
/// metadata of a PDF that describes extension schemas of its own (Typst does)
/// takes the `rdf:li` of the Factur-X schema into its `pdfaExtension:schemas`
/// instead, as a property may occur only once.
///
/// -> str
#let factur-x-rdf(profile) = {
  let values = factur-x-values(profile)
  let out = (
    "<rdf:Description rdf:about=\"\" xmlns:"
      + prefix
      + "=\""
      + namespace
      + "\">\n",
  )
  for (name, value) in values {
    out.push(
      "  <"
        + prefix
        + ":"
        + name
        + ">"
        + _escape(value)
        + "</"
        + prefix
        + ":"
        + name
        + ">\n",
    )
  }
  out.push("</rdf:Description>\n")
  out.push(
    "<rdf:Description rdf:about=\"\""
      + " xmlns:pdfaExtension=\"http://www.aiim.org/pdfa/ns/extension/\""
      + " xmlns:pdfaSchema=\"http://www.aiim.org/pdfa/ns/schema#\""
      + " xmlns:pdfaProperty=\"http://www.aiim.org/pdfa/ns/property#\">\n"
      + "  <pdfaExtension:schemas>\n"
      + "    <rdf:Bag>\n"
      + "      <rdf:li rdf:parseType=\"Resource\">\n"
      + "        <pdfaSchema:schema>"
      + schema-name
      + "</pdfaSchema:schema>\n"
      + "        <pdfaSchema:namespaceURI>"
      + namespace
      + "</pdfaSchema:namespaceURI>\n"
      + "        <pdfaSchema:prefix>"
      + prefix
      + "</pdfaSchema:prefix>\n"
      + "        <pdfaSchema:property>\n"
      + "          <rdf:Seq>\n",
  )
  for property in properties {
    out.push(
      "            <rdf:li rdf:parseType=\"Resource\">\n"
        + "              <pdfaProperty:name>"
        + property.name
        + "</pdfaProperty:name>\n"
        + "              <pdfaProperty:valueType>"
        + property.value-type
        + "</pdfaProperty:valueType>\n"
        + "              <pdfaProperty:category>"
        + property.category
        + "</pdfaProperty:category>\n"
        + "              <pdfaProperty:description>"
        + _escape(property.description)
        + "</pdfaProperty:description>\n"
        + "            </rdf:li>\n",
    )
  }
  out.push(
    "          </rdf:Seq>\n"
      + "        </pdfaSchema:property>\n"
      + "      </rdf:li>\n"
      + "    </rdf:Bag>\n"
      + "  </pdfaExtension:schemas>\n"
      + "</rdf:Description>\n",
  )
  out.join()
}

/// A complete XMP packet with the Factur-X metadata of a profile and nothing
/// else, e.g. for a tool that merges it into the metadata of a PDF.
///
/// -> str
#let factur-x-packet(profile) = (
  "<?xpacket begin=\"\u{FEFF}\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n"
    + "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n"
    + "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n"
    + factur-x-rdf(profile)
    + "</rdf:RDF>\n"
    + "</x:xmpmeta>\n"
    + "<?xpacket end=\"w\"?>"
)
