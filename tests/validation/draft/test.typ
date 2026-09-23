/// [ppi: 60]

// validation: "draft" (prototype tests/validation/draft.typ, concept §7.3): the
// invoice renders with inline markers for the missing data, a badge and a
// watermark on page 1, and the report page (Prüfbericht) with class, legal
// basis and fix per problem, and the note that the XML was withheld. German.
#import "/tests/theme/draft.typ": assert-draft, draft-invoice

#draft-invoice(look: "classic", lang: "de")
#context assert-draft()
#context assert.eq(query(pdf.attach), (), message: "draft withholds the XML")
