// The checked writer of the write guard, and what it does with elements the
// tables do not know or the profile does not use, with text where the schema
// expects elements, and with base64 data.
//
// `write` of this module is the reference: it writes a document and reports
// every problem it finds as a finding with its rule and path. write.typ
// writes a document that passes every check in one pass without findings
// (its fast path) and hands any other document to this module, which writes
// the same XML. A valid e-invoice needs none of this, so write.typ loads the
// module only then (Typst parses a module when it is first imported).

#import "../xml.typ": xml-escape
#import "../../utils/text.typ": plain-text
#import "lists.typ": lists as code-lists, vat-rules
#import "write.typ": (
  _booleans, _category-ok, _code-rule, _decimal, _decimal2, _decimals,
  _declarations, _digits8, _discriminator, _leaf-text, _plain, _tables, _values,
  _xref-values, namespaces, root-tag, valid-date-102,
)

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

// A problem the guard found: its kind, the official rule (or `none`, for
// which report.typ names the guard's own rule of the kind), the path of
// elements from the element that found it, and details.
#let _finding(kind, rule, path, ..details) = (
  (kind: kind, rule: rule, path: path) + details.named()
)

// The rule of the minimum (0) or the maximum (1) of a child: `rules` are
// as many as there are, or none.
#let _rule(rules, i) = if rules != none { rules.at(i, default: none) }

// Findings of the child `step` of the element `tag`: their paths from `tag`.
#let _lift(found, tag, step) = {
  let out = ()
  for f in found { out.push(f + (path: (tag, step) + f.path.slice(1))) }
  out
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

// Checks the text of a leaf against its node [kind, attributes, list,
// prefix, decimals, date]; `attrs` are the attributes written.
#let _check-text(tag, text, node, attrs) = {
  let found = ()
  let (kind, _, list, prefix, fraction, date) = node
  if kind == "d" {
    if _decimal not in text {
      found.push(_finding(
        "lexical",
        none,
        (tag,),
        value: text,
        expected: "a decimal",
      ))
    }
    if fraction != none {
      let (limit, lexical, rule) = fraction
      if _decimals(text, lexical) > limit {
        found.push(_finding(
          "fraction",
          rule,
          (tag,),
          value: text,
          limit: limit,
        ))
      }
    }
  } else if kind == "b" and text not in _booleans {
    found.push(_finding(
      "lexical",
      none,
      (tag,),
      value: text,
      expected: "an indicator",
    ))
  } else if kind == "x" and not valid-base64(text) {
    found.push(_finding(
      "lexical",
      none,
      (tag,),
      value: text,
      expected: "base64 data",
    ))
  }
  if date != none and attrs.at("format", default: none) == "102" {
    if not valid-date-102(text) {
      // Eight digits that are no calendar date pass the official check
      // (CII-DT-097), but name no day: the guard's own rule.
      let rule = if _digits8(text) { "IP-GUARD-08" } else { date }
      found.push(_finding("date", rule, (tag,), value: text))
    }
  }
  if list != none {
    let rule = _code-rule(text, list)
    if rule != none {
      found.push(_finding("code", rule, (tag,), value: text, list: list.at(0)))
    }
  }
  if prefix != none {
    let (spec, when) = prefix
    if when == none or attrs.at(when.at(0), default: none) == when.at(1) {
      let characters = text.codepoints()
      let first = if characters == () { "" } else {
        characters.slice(0, calc.min(2, characters.len())).join()
      }
      let rule = _code-rule(first, spec)
      if rule != none {
        found.push(_finding(
          "prefix",
          rule,
          (tag,),
          value: first,
          list: spec.at(0),
        ))
      }
    }
  }
  found
}

// Checks the attributes of a leaf against its node: `attrs` are the
// attributes written, with their texts.
#let _check-attributes(tag, node, attrs) = {
  let found = ()
  let specs = node.at(1)
  for (name, value) in attrs {
    let spec = if specs == none { none } else { specs.at(name, default: none) }
    if spec == none {
      found.push(_finding("attribute", none, (tag,), name: name))
      found += attribute-name(tag, name)
      continue
    }
    let (_, forbidden, list) = spec
    if forbidden != none {
      found.push(_finding("attribute-not-used", forbidden, (tag,), name: name))
    }
    if list != none {
      let rule = _code-rule(value, list)
      if rule != none {
        found.push(_finding(
          "code",
          rule,
          (tag,),
          value: value,
          name: name,
          list: list.at(0),
        ))
      }
    }
  }
  if specs != none {
    for (name, spec) in specs {
      let required = spec.at(0)
      if required != false and name not in attrs {
        let rule = if required == true { none } else { required }
        found.push(_finding("attribute-missing", rule, (tag,), name: name))
      }
    }
  }
  found
}

// A leaf: the element `tag` with its text and attributes, checked against
// its node (a kind or an array); `empty` is the rule of the profile that
// forbids an empty leaf, or none. Returns (XML, findings).
#let _leaf(tag, body, node, empty) = {
  if type(node) == str { node = (node, none, none, none, none, none) }
  if type(body) != dictionary {
    let text = if type(body) == str { body } else { plain-text(body) }
    let escaped = if _plain in text { text } else { xml-escape(text) }
    if escaped.trim() == "" { return ("", ()) }
    let found = _check-text(tag, text, node, (:))
    if node.at(1) != none { found += _check-attributes(tag, node, (:)) }
    return ("<" + tag + ">" + escaped + "</" + tag + ">", found)
  }
  // Attributes and text, written as `raw` writes them.
  let attrs = (:)
  let written = ""
  let children = ""
  let text = none
  let found = ()
  for (key, value) in body {
    if key == "" {
      if type(value) == dictionary {
        for (k, v) in value {
          let (r, f) = unknown-in-leaf(tag, k, v)
          children += r
          found += f
        }
      } else if value != none {
        text = if type(value) == str { value } else { plain-text(value) }
        children += if _plain in text { text } else { xml-escape(text) }
      }
    } else if key.starts-with("@") {
      if value != none {
        let name = key.slice(1)
        let v = if type(value) == str { value } else { plain-text(value) }
        written += (
          " "
            + name
            + "=\""
            + if _plain in v { v } else { xml-escape(v) }
            + "\""
        )
        attrs.insert(name, v)
      }
    } else {
      let (r, f) = unknown-in-leaf(tag, key, value)
      children += r
      found += f
    }
  }
  if "" in body and children.trim() == "" { return ("", ()) }
  found += _check-attributes(tag, node, attrs)
  if children == "" {
    // An element without text: its text is checked as empty (no decimal,
    // no code), and a rule of the profile may forbid empty elements.
    if empty != none { found.push(_finding("empty", empty, (tag,))) }
    found += _check-text(tag, "", node, attrs)
    return ("<" + tag + written + " />", found)
  }
  if text != none { found += _check-text(tag, text, node, attrs) }
  ("<" + tag + written + ">" + children + "</" + tag + ">", found)
}

// The rules of the VAT category of a tax element (`body`, the child `step`
// of `tag`): the `checks` of its `category` (see lists.typ) on its rate
// ("r": above 0, 0, none, or "any" rate), its VAT amount ("a") and its
// exemption reason ("e"); see `_category-ok` of write.typ.
#let _category-checks(tag, step, body, category, checks) = {
  let found = ()
  for (check, expected, rule) in checks {
    if not _category-ok(body, check, expected) {
      let element = if check == "e" { "ram:ExemptionReason" } else if (
        check == "r"
      ) { "ram:RateApplicablePercent" } else { "ram:CalculatedAmount" }
      found.push(_finding(
        "category",
        rule,
        (tag, step, element),
        category: category,
        check: check,
        expected: expected,
        value: _leaf-text(body.at(element, default: none)),
      ))
    }
  }
  found
}

// The rules of the VAT categories of the tax elements `value` (one, or an
// array) of the child `child` of `tag`, each by the category code it
// states: `rules` names their table in lists.typ (`t` of a node). One
// memoized call on small arguments, so that the lines of one tax are
// checked once.
#let _vat-checks(tag, child, value, rules) = {
  let table = vat-rules.at(rules)
  let many = type(value) == array
  let found = ()
  let i = 0
  for item in if many { value } else { (value,) } {
    i += 1
    if type(item) != dictionary { continue }
    let code = _discriminator(item, ("ram:CategoryCode",))
    let checks = if code == none { none } else {
      table.at(code, default: none)
    }
    if checks == none { continue }
    let step = if many { child + "[" + str(i) + "]" } else { child }
    found += _category-checks(tag, step, item, code, checks)
  }
  found
}

// The further checks of a complex node (`z`) on the values of its tree:
// `v`, `g` and `r` (`write` does the others as it writes the children).
#let _further-checks(tag, body, z, variants) = {
  let found = ()
  for (key, value, low, rule) in z.at("v", default: ()) {
    if variants.at(key, default: (:)).at(value, default: 0) < low {
      found.push(_finding("variant-min", rule, (tag, key), variant: value))
    }
  }
  for (path, low, high, rule) in z.at("g", default: ()) {
    let count = _values(body, path).len()
    if count < low or (high != none and count > high) {
      found.push(_finding(
        "aggregate",
        rule,
        (tag,),
        steps: path,
        count: count,
        low: low,
        high: high,
      ))
    }
  }
  for (kind, refs, rule) in z.at("r", default: ()) {
    // The VAT total (BT-110, BT-111) by the currency it is stated in: one
    // in each currency the settlement names, and no other.
    let (currencies, totals) = _xref-values(body, refs)
    if kind == "count" {
      for currency in currencies {
        let n = 0
        for c in totals { if c == currency { n += 1 } }
        if n > 1 {
          found.push(_finding(
            "xref-count",
            rule,
            (tag,),
            value: currency,
            count: n,
          ))
        }
      }
    } else {
      for currency in totals {
        if currency not in currencies {
          found.push(_finding("xref-other", rule, (tag,), value: currency))
        }
      }
    }
  }
  found
}

/// Serializes the builder's element tree `data` and checks it against the
/// guard tables of `profile` in the same pass: the reference writer, which
/// reports every finding (see `write` of write.typ).
///
/// -> dictionary
#let write(data, profile) = {
  let tables = _tables(profile)
  if tables == none {
    panic("no guard tables for the profile " + repr(profile))
  }
  let nodes = tables.nodes
  let empty = tables.empty
  if data == none { data = (:) }
  if type(data) != dictionary {
    // No element tree: its text, and no root element.
    return (
      xml: xml-escape(data),
      findings: (_finding("root", none, (root-tag,), missing: true),),
    )
  }

  // An element of a complex node. Returns (XML, findings). The checks of
  // G1 on the names of the children run as they are written: that each is
  // in schema order after the one before and within its maximum, and after
  // the loop that the required ones are there and the node's further checks
  // on names (`e`, `y`, `x`). Their findings follow those of the children.
  let element(tag, body, id) = {
    let node = nodes.at(id)
    let children = node.c
    let out = ""
    let attrs = ""
    let found = ()
    let problems = ()
    // The index of the last child written (-1: none yet) and the number of
    // children written that the node requires (a minimum is 0 or 1).
    let last = -1
    let required = 0
    // The children the node allows that are not written.
    let skipped = ()
    let variants = (:)
    for (key, value) in body {
      if key not in children {
        if value == none { continue }
        // The namespace declarations of the root, its only attributes.
        if id == 0 and key.starts-with("@") and key.slice(1) in _declarations {
          let v = if type(value) == str and _plain in value { value } else {
            xml-escape(value)
          }
          attrs += " " + key.slice(1) + "=\"" + v + "\""
          continue
        }
        // Another attribute, text, or an element the profile does not use
        // here or does not know.
        let (a, x, f) = other-child(
          tag,
          key,
          value,
          node.at("u", default: (:)).at(key, default: none),
          if id == 0 { _declarations },
        )
        attrs += a
        out += x
        found += f
        continue
      }
      let (action, index, low, high, target, rules) = children.at(key)
      let t = type(value)
      // A leaf that a plain text of its form satisfies: a text, a decimal,
      // an indicator, or a code of its list (a code has no space and nothing
      // to escape).
      if (
        t == str
          and (
            action == "s" and _plain in value
              or action == "d2" and _decimal2 in value
              or action == "d" and _decimal in value
              or action == "b" and value in _booleans
              or (
                type(action) == str
                  and action.len() > 2
                  and not (" " in value)
                  and (" " + value + " ") in code-lists.at(action)
              )
          )
      ) {
        out += "<" + key + ">" + value + "</" + key + ">"
      } else if t == dictionary and type(action) == int {
        let (xml, f) = element(key, value, action)
        if f != () { found += _lift(f, tag, key) }
        if xml == "" {
          skipped.push(key)
          continue
        }
        out += xml
      } else if value == none {
        skipped.push(key)
        continue
      } else {
        // Everything else: repeated elements, variants, leaves with further
        // checks or attributes, other values.
        let n = nodes.at(target)
        let many = t == array
        let dispatch = type(n) == dictionary and "d" in n
        let count = 0
        // Leaves written without text: a required one counts as missing,
        // as the official rules require its text (`normalize-space(..) !=
        // ''`, XRechnung's `[boolean(normalize-space(.))]`).
        let blank = 0
        let i = 0
        for item in if many { value } else { (value,) } {
          i += 1
          if item == none { continue }
          let child = target
          if dispatch {
            // The node of the variant, by the value of the discriminator.
            let v = _discriminator(item, n.d)
            let variant = if v != none and v in n.m { v } else { "*" }
            child = if variant == "*" { n.o } else { n.m.at(variant) }
            let seen = variants.at(key, default: (:))
            seen.insert(variant, seen.at(variant, default: 0) + 1)
            variants.insert(key, seen)
          }
          let (xml, f) = if type(child) == str {
            // A variant the profile does not use.
            unchecked(key, item, child)
          } else if type(nodes.at(child)) != dictionary {
            let (xml, f) = _leaf(key, item, nodes.at(child), empty)
            // A leaf without text is written as an empty element.
            if xml.ends-with(" />") { blank += 1 }
            (xml, f)
          } else if type(item) == dictionary {
            element(key, item, child)
          } else {
            // Text where the schema expects elements.
            unchecked(key, item, none)
          }
          if f != () {
            found += _lift(f, tag, if many { key + "[" + str(i) + "]" } else {
              key
            })
          }
          if xml == "" { continue }
          out += xml
          count += 1
        }
        if blank > 0 and blank == count and low > 0 {
          found.push(_finding("blank", _rule(rules, 0), (tag, key)))
        }
        if dispatch and "k" in n {
          for (v, limit) in n.k {
            let c = variants.at(key, default: (:)).at(v, default: 0)
            if c > limit.at(0) {
              found.push(_finding(
                "variant-max",
                limit.at(1),
                (tag, key),
                variant: v,
                count: c,
                limit: limit.at(0),
              ))
            }
          }
        }
        if count == 0 {
          skipped.push(key)
          continue
        }
        // Written `count` times: its order, whether the node requires it,
        // and its number.
        if index < last { problems.push(_finding("order", none, (tag, key))) }
        last = index
        required += low
        if count > 1 and high != none and count > high {
          problems.push(_finding(
            "max",
            _rule(rules, 1),
            (tag, key),
            count: count,
            limit: high,
          ))
        }
        continue
      }
      // Written once: its order and whether the node requires it.
      if index < last { problems.push(_finding("order", none, (tag, key))) }
      last = index
      required += low
    }
    // A child the node allows is written when it is in the tree and not
    // skipped.
    if required < node.n {
      for (key, spec) in children {
        if spec.at(2) > 0 and (key not in body or key in skipped) {
          problems.push(_finding("min", _rule(spec.at(5), 0), (tag, key)))
        }
      }
    }
    let z = if "z" in node { node.z }
    if z != none {
      if "y" in z {
        for (tags, rule) in z.y {
          let any = false
          for key in tags {
            if key in body and key not in skipped { any = true }
          }
          if not any {
            problems.push(_finding("any-of", rule, (tag,), tags: tags))
          }
        }
      }
      if "x" in z {
        for (tags, rule) in z.x {
          let all = true
          for key in tags {
            if key not in body or key in skipped { all = false }
          }
          if all {
            problems.push(_finding("exclusive", rule, (tag,), tags: tags))
          }
        }
      }
      if "e" in z and last == -1 {
        problems.push(_finding("empty", z.e, (tag,)))
      }
    }
    if problems != () { found += problems }
    if z != none {
      if "t" in z {
        // The tax elements among the children, by their VAT categories.
        for (child, rules) in z.t {
          let value = body.at(child, default: none)
          if value != none {
            let f = _vat-checks(tag, child, value, rules)
            if f != () { found += f }
          }
        }
      }
      if "v" in z or "g" in z or "r" in z {
        found += _further-checks(tag, body, z, variants)
      }
    }
    if "" in body and out.trim() == "" { return ("", found) }
    (
      if out == "" { "<" + tag + attrs + " />" } else {
        "<" + tag + attrs + ">" + out + "</" + tag + ">"
      },
      found,
    )
  }

  let xml = ""
  let findings = ()
  for (tag, body) in data {
    if body == none { continue }
    if tag != root-tag or type(body) != dictionary {
      // A second root, or text: the XML is no document of the schema.
      let (r, f) = not-root(tag, body)
      xml += r
      findings += f
      continue
    }
    for (name, uri) in namespaces {
      if body.at("@" + name, default: none) != uri {
        findings.push(_finding(
          "namespace",
          none,
          (tag,),
          name: name,
          value: uri,
        ))
      }
    }
    let (x, f) = element(tag, body, 0)
    xml += x
    findings += f
  }
  if xml.trim() == "" or data.at(root-tag, default: none) == none {
    findings.push(_finding("root", none, (root-tag,), missing: true))
  }
  (xml: xml, findings: findings)
}
