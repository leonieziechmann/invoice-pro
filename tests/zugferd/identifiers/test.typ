// The typed identifiers of the `id` module: scheme, normalized identifier,
// kind and the problems of wrong input, which are reported by the e-invoice
// (IP-ID-01) instead of stopping the compilation.

#import "/src/lib.typ": *
#import "/src/zugferd/guard/lists.typ": validator as lists
#import "/src/zugferd/rules/engine.typ": in-list

// The problems of an identifier.
#let problems(value) = value.problems

// --- 1. Valid identifiers: scheme, identifier without formatting, kind ---
#{
  assert.eq(id.gln("4000001123452"), (
    scheme: "0088",
    id: "4000001123452",
    kind: "party",
    problems: (),
  ))
  assert.eq(id.gln("4000001 12345 2").id, "4000001123452")
  assert.eq(id.gln(4000001123452).id, "4000001123452")
  assert.eq(id.duns("15-048-3782"), (
    scheme: "0060",
    id: "150483782",
    kind: "party",
    problems: (),
  ))
  assert.eq(id.siren("123 456 782"), (
    scheme: "0002",
    id: "123456782",
    kind: "legal",
    problems: (),
  ))
  assert.eq(id.siret("123 456 782 00010"), (
    scheme: "0009",
    id: "12345678200010",
    kind: "legal",
    problems: (),
  ))
  // The establishments of La Poste have a check of their own
  assert.eq(problems(id.siret("35600000012346")), ())
  assert.eq(problems(id.siret("35600000000048")), ())
  // The Swiss UID, also written as VAT number, with the suffix of the
  // commercial register or in lower case
  for value in (
    "CHE-123.456.788",
    "CHE123456788",
    "CHE-123.456.788 MWST",
    "che 123 456 788 tva",
    "CHE-123.456.788 HR",
    "CHE-123.456.788 MWST/TVA/IVA",
  ) {
    assert.eq(
      id.uid-ch(value),
      (scheme: "0183", id: "CHE123456788", kind: "legal", problems: ()),
      message: value,
    )
  }
  assert.eq(problems(id.uid-ch("CHE-111.222.338")), ())
  // A register number has no scheme; the court is written in front of it
  assert.eq(id.register("HRB 4711"), (
    scheme: none,
    id: "HRB 4711",
    kind: "legal",
    problems: (),
  ))
  assert.eq(
    id.register("HRB 4711", court: "Amtsgericht München").id,
    "Amtsgericht München, HRB 4711",
  )
  assert.eq(id.register([HRB #sym.zws 4711 ]).id, "HRB 4711")
  // The Leitweg-ID keeps its hyphens; its check digits are MOD 97-10
  for value in (
    "04011000-1234512345-06",
    "991-33333TEST-33",
    "992-90009-96",
  ) {
    assert.eq(
      id.leitweg(value),
      (scheme: "0204", id: value, kind: "routing", problems: ()),
      message: value,
    )
  }
  assert.eq(id.leitweg(" 991-33333TEST-33\u{200B}").id, "991-33333TEST-33")
  // Any other scheme, in upper case and without spaces
  assert.eq(id.custom("0208", "0123 456 749"), (
    scheme: "0208",
    id: "0123456749",
    kind: "custom",
    problems: (),
  ))
  assert.eq(id.custom("em", "ap@buyer.example").scheme, "EM")
}

// --- 2. Wrong identifiers are problems, never a stop ---
#{
  assert.eq(problems(id.gln("4000001123453")), (
    "The check digit of the GLN \"4000001123453\" is wrong.",
  ))
  assert.eq(problems(id.gln("400000112345")), (
    "The GLN \"400000112345\" must have 13 digits, e.g. \"4000001123452\".",
  ))
  assert.eq(problems(id.gln("")), ("The GLN is empty.",))
  assert.eq(problems(id.gln(none)), ("The GLN is empty.",))
  assert(problems(id.gln((1, 2))).first().contains("must be given as text"))
  assert.eq(problems(id.gln(4.5e12)).len(), 1)
  assert.eq(problems(id.duns("12345678")).len(), 1)
  assert.eq(problems(id.siren("123 456 783")), (
    "The check digit of the SIREN \"123 456 783\" is wrong.",
  ))
  assert.eq(problems(id.siren("12345678A")).len(), 1)
  assert.eq(problems(id.siret("12345678200011")).len(), 1)
  assert.eq(problems(id.siret("35600000012345")).len(), 1)
  assert.eq(problems(id.uid-ch("CHE-123.456.789")), (
    "The check digit of the Swiss UID \"CHE-123.456.789\" is wrong.",
  ))
  assert(problems(id.uid-ch("123.456.788")).first().contains("\"CHE\""))
  assert.eq(problems(id.register("")), ("The register number is empty.",))
  assert.eq(problems(id.register("", court: "Amtsgericht München")), (
    "The register number is empty.",
  ))
  assert.eq(problems(id.leitweg("04011000-12345-34")), (
    "The check digits of the Leitweg-ID \"04011000-12345-34\" are wrong.",
  ))
  // A Leitweg-ID has capital letters only, and 2 check digits
  let lower = problems(id.leitweg("991-33333test-33")).first()
  assert(lower.contains("capital letters"), message: lower)
  assert.eq(problems(id.leitweg("991-33333TEST")).len(), 1)
  assert.eq(problems(id.leitweg("9-33333TEST-33")).len(), 1)
  // `id.custom` checks no identifier, but needs a scheme and an identifier
  assert.eq(problems(id.custom("0088", "4000001123453")), ())
  assert(problems(id.custom(none, "x")).first().contains("has no scheme"))
  assert.eq(id.custom(none, "x").scheme, none)
  assert.eq(problems(id.custom("0208", "")), (
    "The identifier of the scheme \"0208\" is empty.",
  ))
}

// --- 3. The schemes are codes of the lists the e-invoice checks them with:
// ISO/IEC 6523 ICD for party and legal registration identifiers (BR-CL-10,
// BR-CL-11), EAS for electronic addresses (BR-CL-25) ---
#{
  for value in (
    id.gln("4000001123452"),
    id.duns("150483782"),
    id.siren("123456782"),
    id.siret("12345678200010"),
    id.uid-ch("CHE-123.456.788"),
  ) {
    assert(in-list(lists.icd.every, value.scheme), message: value.scheme)
  }
  for value in (
    id.gln("4000001123452"),
    id.siret("12345678200010"),
    id.leitweg("991-33333TEST-33"),
  ) {
    assert(in-list(lists.eas.every, value.scheme), message: value.scheme)
  }
}

// --- 4. An identifier input that produces no text stops the compilation
// with the field, with and without e-invoice: it would be missing from the
// printed invoice and the XML without notice ---
#{
  let party = (name: "Party", address: "Street 1", city: "10115 Berlin")
  let message(zugferd: none, ..args) = catch(() => invoice(
    zugferd: zugferd,
    sender: party,
    recipient: party,
    ..args,
  )[])
  // A constructor of the `id` module that is not called
  for zugferd in (none, "en16931") {
    let error = message(zugferd: zugferd, sender: party + (legal-id: id.siret))
    assert(
      error.contains("`sender.legal-id` is the function `siret`"),
      message: error,
    )
  }
  assert(
    message(recipient: party + (global-id: id.gln)).contains(
      "`recipient.global-id` is the function `gln`",
    ),
  )
  assert(
    message(recipient: party + (electronic-address: id.leitweg)).contains(
      "`recipient.electronic-address` is the function `leitweg`",
    ),
  )
  assert(
    message(payee: (name: "Factor", id: id.gln)).contains(
      "`payee.id` is the function `gln`",
    ),
  )
  // A scheme without an identifier
  let error = message(sender: party + (legal-id: (scheme: "0002")))
  assert(
    error.contains("`sender.legal-id` has no identifier"),
    message: error,
  )
  assert(error.contains("(scheme: \"0002\")"), message: error)
  assert(
    message(
      zugferd: "en16931",
      recipient: party + (id: (scheme: "0088", id: "")),
    ).contains("`recipient.id` has no identifier"),
  )
  assert(
    message(delivery-address: party + (location-id: (scheme: "0088"))).contains(
      "`delivery-address.location-id` has no identifier",
    ),
  )
  assert(
    message(
      recipient: party + (delivery-address: party + (global-id: (id: none))),
    ).contains("`recipient.delivery-address.global-id` has no identifier"),
  )
  // Not stopped: an electronic address without identifier counts as not
  // given, empty values of imported data are no identifiers, and an
  // identifier of the `id` module reports its problems in the e-invoice
  // (IP-ID-01)
  let fine = invoice(
    sender: party
      + (legal-id: "", id: none, electronic-address: (scheme: "EM")),
    recipient: party + (global-id: id.gln("")),
  )[]
}
