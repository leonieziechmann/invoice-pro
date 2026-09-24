// The rarely needed parts of the write guard (write.typ): what it does with
// elements the tables do not know or the profile does not use, with text
// where the schema expects elements, and with base64 data. A valid e-invoice
// needs none of them, so write.typ loads this module only when it meets such
// an element (Typst parses a module when it is first imported).

#import "../xml.typ": xml-escape
#import "write.typ": _finding, _lift

// The patterns of this module, compiled on their first use (a call without
// arguments is memoized): base64 data, and the names of elements and
// attributes the tables do not know. An element name has one of the
// prefixes the root declares; an attribute name none, or `xml` or `xmlns`.
// Base64 data is the lexical space of xs:base64Binary after the XSD
// collapses its whitespace: groups of four characters with single spaces
// between them, and a last group that ends with its padding.
#let _patterns() = (
  whitespace: regex("[ \\t\\n\\r]+"),
  base64: regex(
    "^(?:(?:[A-Za-z0-9+/] ?){4})*(?:(?:[A-Za-z0-9+/] ?){3}[A-Za-z0-9+/]"
      + "|(?:[A-Za-z0-9+/] ?){2}[AEIMQUYcgkosw048] ?="
      + "|[A-Za-z0-9+/] ?[AQgw] ?= ?=)?$",
  ),
  element: regex("^(?:rsm|ram|udt|qdt):[A-Za-z_][A-Za-z0-9._-]*$"),
  attribute: regex(
    "^(?:(?:xml|xmlns):)?[A-Za-z_][A-Za-z0-9._-]*$",
  ),
)

/// Whether `text` is base64 data (xs:base64Binary).
///
/// -> bool
#let valid-base64(text) = {
  let patterns = _patterns()
  let collapsed = text.replace(patterns.whitespace, " ").trim(" ")
  collapsed.match(patterns.base64) != none
}

/// An element without checks, for elements of no known position: the same
/// output the checked writer produces.
///
/// -> str
#let raw(tag, body) = {
  if body == none { return "" }
  if type(body) == array {
    let out = ""
    for item in body { out += raw(tag, item) }
    return out
  }
  if type(body) == dictionary {
    let attrs = ""
    let children = ""
    for (key, value) in body {
      if key.starts-with("@") {
        if value != none {
          attrs += " " + key.slice(1) + "=\"" + xml-escape(value) + "\""
        }
      } else if key == "" {
        if type(value) == dictionary {
          for (k, v) in value { children += raw(k, v) }
        } else if value != none {
          children += xml-escape(value)
        }
      } else {
        children += raw(key, value)
      }
    }
    // An identifier or code without its value would be invalid.
    if "" in body and children.trim() == "" { return "" }
    return if children == "" {
      "<" + tag + attrs + " />"
    } else {
      "<" + tag + attrs + ">" + children + "</" + tag + ">"
    }
  }
  let value = xml-escape(body)
  if value.trim() == "" { return "" }
  "<" + tag + ">" + value + "</" + tag + ">"
}

/// A finding when the attribute `name` of the element `tag` is no valid
/// name.
///
/// -> array
#let attribute-name(tag, name) = if (
  name.match(_patterns().attribute) == none
) {
  (_finding("name", none, (tag,), value: name),)
} else { () }

/// Names in an unchecked subtree that would break the document.
///
/// -> array
#let bad-names(tag, body) = {
  let found = ()
  if tag.match(_patterns().element) == none {
    found.push(_finding("name", none, (tag,), value: tag))
  }
  if type(body) == array {
    for item in body { found += bad-names(tag, item) }
  } else if type(body) == dictionary {
    for (key, value) in body {
      if key.starts-with("@") {
        found += attribute-name(tag, key.slice(1))
      } else if key == "" {
        if type(value) == dictionary {
          for (k, v) in value { found += _lift(bad-names(k, v), tag, k) }
        }
      } else {
        found += _lift(bad-names(key, value), tag, key)
      }
    }
  }
  found
}

/// Children of the element `tag` without an entry among the children of its
/// node: an attribute (`@name`) other than the namespace declarations of the
/// root (`declarations` for the root, else `none`), text between the
/// elements (`""`), or an element the profile does not use there (the rule
/// of the node's `u`) or does not know. Returns (attributes, XML, findings).
///
/// -> array
#let other-child(tag, key, value, rule, declarations) = {
  if key.starts-with("@") {
    // No complex element of the schema has attributes; the root declares
    // the namespaces.
    let name = key.slice(1)
    let found = ()
    if declarations == none or name not in declarations {
      found.push(_finding("attribute", none, (tag,), name: name))
      found += attribute-name(tag, name)
    }
    return (" " + name + "=\"" + xml-escape(value) + "\"", "", found)
  }
  if key == "" {
    // Text between the elements.
    let out = ""
    let found = ()
    if type(value) == dictionary {
      for (k, v) in value {
        out += raw(k, v)
        found += _lift(bad-names(k, v), tag, k)
      }
    } else { out = xml-escape(value) }
    found.push(_finding("text", none, (tag,)))
    return ("", out, found)
  }
  // Unknown here, or not used in the profile at this position (the rule
  // that says so).
  let r = raw(key, value)
  if r == "" { return ("", "", ()) }
  let found = (
    if rule == none { _finding("unknown", none, (tag, key)) } else {
      _finding("not-used", rule, (tag, key))
    },
  )
  ("", r, found + _lift(bad-names(key, value), tag, key))
}

/// An element the tables do not know below a leaf (`tag`), written
/// unchecked. Returns (XML, findings).
///
/// -> array
#let unknown-in-leaf(tag, key, value) = {
  let r = raw(key, value)
  if r == "" { return ("", ()) }
  (
    r,
    (_finding("unknown", none, (tag, key)),)
      + _lift(bad-names(key, value), tag, key),
  )
}

/// A variant of an element (`tag`) that the profile does not use (`rule`),
/// or text where the schema expects elements (`rule: none`), written
/// unchecked. Returns (XML, findings).
///
/// -> array
#let unchecked(tag, item, rule) = {
  let w = raw(tag, item)
  if w == "" { return ("", ()) }
  if rule == none { return (w, (_finding("text", none, (tag,)),)) }
  (w, (_finding("not-used", rule, (tag,)),) + bad-names(tag, item))
}

/// A child of the document other than its root element: a second root, or
/// text; the XML is no document of the schema. Returns (XML, findings).
///
/// -> array
#let not-root(tag, body) = {
  let r = raw(tag, body)
  if r == "" { return ("", ()) }
  (r, (_finding("root", none, (tag,), value: tag),) + bad-names(tag, body))
}
