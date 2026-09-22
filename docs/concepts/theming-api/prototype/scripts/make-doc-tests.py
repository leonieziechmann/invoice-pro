# Writes tests/doc/*: the docs prelude, assets and one test per code block of the
# concept document. The DOCUMENT is the source of truth: every ```typst / ```toml
# block must be preceded by a marker line `<!-- doc-test: NAME -->`, and its body
# is copied verbatim into tests/doc/NAME.typ (after the prelude import and the
# hidden prefix/suffix below). Two names are special: `nordlicht.toml` becomes
# tests/doc/nordlicht.toml and `acme-theme` becomes the test package's lib.typ.
#
# Usage (from the prototype root): python scripts/make-doc-tests.py [README.md]
# Default document: ../README.md (the bundle layout), else ../bundle/README.md.
import os, re, shutil, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if len(sys.argv) > 1:
    doc = sys.argv[1]
else:
    cands = [os.path.join(root, "..", "README.md"), os.path.join(root, "..", "bundle", "README.md")]
    doc = next((c for c in cands if os.path.exists(c)), None)
    if doc is None:
        sys.exit("make-doc-tests: concept document not found; pass its path")
text = open(doc, encoding="utf8").read()

d = os.path.join(root, "tests", "doc")
os.makedirs(d, exist_ok=True)
# logos are logo-sized marks (not the full-page letterhead fixture): the snippets
# put them into letterhead areas and plates
for name, src in [("logo.svg", "logo-mark.svg"), ("acme.svg", "logo-acme.svg"),
                  ("sw.svg", "logo-sw.svg"), ("lh-1.svg", "lh1.svg"), ("lh-2.svg", "lh2.svg")]:
    shutil.copy(os.path.join(root, "tests", src), os.path.join(d, name))

# ---- blocks of the document -------------------------------------------------
fence = re.compile(r"^```(\w*)\n(.*?)^```$", re.M | re.S)
marker = re.compile(r"<!-- doc-test: ([\w.-]+) -->\s*\Z")
blocks = {}
for m in fence.finditer(text):
    lang, body = m.group(1), m.group(2)
    if lang not in ("typst", "toml"):
        continue  # text listings are not tests
    mk = marker.search(text[:m.start()][-200:])
    line = text.count("\n", 0, m.start()) + 1
    if not mk:
        sys.exit("make-doc-tests: %s:%d: ```%s block without a `<!-- doc-test: NAME -->` marker" % (doc, line, lang))
    name = mk.group(1)
    if name in blocks:
        sys.exit("make-doc-tests: %s:%d: duplicate doc-test name %s" % (doc, line, name))
    blocks[name] = body

# ---- hidden files -----------------------------------------------------------
files = {}
files["brand.json"] = '{ "tokens": { "colors": { "primary": "#1d4ed8" } },\n  "options": { "totals": { "fill": "none" } } }\n'
files["job.json"] = '{ "region": "us", "locale": "en-de" }\n'
files["prelude.typ"] = r'''// Hidden docs prelude (concept §10): every snippet test imports this, then the
// snippet verbatim. It provides the package, `party` (header data) and `body()`.
#import "/src/lib.typ": *
#let party = (
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
    email: "hallo@atelier-nord.de",
    register: [Amtsgericht Hamburg HRB 123456],
    management: [GF: Lina Berg],
    extra: (Telefon: "+49 40 1234567"),
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
    email: "ap@muster.de",
  ),
  invoice-nr: "2026-0142",
  customer-nr: "K-2201",
)
#let body(n: 4) = [
  Sehr geehrte Damen und Herren, für unsere Leistungen berechnen wir:
  #line-items[
    #item([Konzeption Corporate Design], price: 1800)
    #item([Logo-Reinzeichnung], price: 650)
    #for i in range(n - 2) { item([Druckabwicklung #(i + 1)], price: 240) }
  ]
  #payment-terms(days: 14)
  #bank-details(
    bank: "Hamburger Sparkasse",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  )
  #signature()
]
'''
files["corporate.typ"] = r'''#import "prelude.typ": theme
#let corporate = theme.custom.brand(
  color: rgb("#003a70"),
  accent: rgb("#e2001a"),
)
'''

# ---- hidden prefixes and suffixes (the document names them) -----------------
P = '#import "prelude.typ": *\n'
prefix = {}
suffix = {}
prefix["passing"] = '#import "@local/acme-theme:0.1.0" as acme\n#let acme-brand = theme.custom.brand(color: rgb("#003a70"))\n'
suffix["passing"] = "#body()\n#for th in (a, b, c) { let _ = theme.resolve(th) }\n"
prefix["din"] = "#let derive = theme.layout.derive\n#let E = theme.layout\n"
suffix["din"] = r"""// the listing equals the shipped data (after resolution)
#let R(l) = theme.resolve(theme.classic.with(layout: l)).layout
#assert(R(din-5008-a) == R(theme.layout.din-5008-a))
#assert(R(din-5008-b) == R(theme.layout.din-5008-b))
DIN LISTING MATCHES
"""

special = {"nordlicht.toml", "acme-theme"}
for k in ("nordlicht.toml", "acme-theme"):
    if k not in blocks:
        sys.exit("make-doc-tests: the document has no `%s` block" % k)
for k in list(prefix) + list(suffix):
    if k not in blocks:
        sys.exit("make-doc-tests: hidden prefix/suffix for `%s`, but the document has no such block" % k)

files["nordlicht.toml"] = blocks["nordlicht.toml"]
lib = os.path.join(root, "tests", "pkgs", "local", "acme-theme", "0.1.0", "lib.typ")
open(lib, "w", encoding="utf8", newline="\n").write(blocks["acme-theme"])
for k, v in files.items():
    open(os.path.join(d, k), "w", encoding="utf8", newline="\n").write(v)

snippets = {k: v for k, v in blocks.items() if k not in special}
stale = [f for f in os.listdir(d) if f.endswith(".typ") and f[:-4] not in snippets
         and f not in ("prelude.typ", "corporate.typ")]
for f in stale:
    os.remove(os.path.join(d, f))
for k, v in snippets.items():
    open(os.path.join(d, k + ".typ"), "w", encoding="utf8", newline="\n").write(
        P + prefix.get(k, "") + v + suffix.get(k, ""))
open(os.path.join(d, "snippets.md.txt"), "w", encoding="utf8", newline="\n").write(
    "\n".join("### " + k + "\n" + v for k, v in snippets.items()))
print("wrote", len(snippets), "snippet tests from", os.path.relpath(doc, root),
      "(+ nordlicht.toml, acme-theme lib.typ)" + ("; removed stale: " + ", ".join(stale) if stale else ""))
