// P2 as an e-invoice (prototype tests/p2-stationery.typ, output=einvoice): the
// complete invoice attaches factur-x.xml (the PDF/A-3b export itself is not
// portable to tytanic, which renders PNG pages).
#import "/tests/theme/stationery.typ": stationery-invoice

#stationery-invoice("einvoice")
#context assert.eq(query(pdf.attach).map(a => a.path), ("/factur-x.xml",))
