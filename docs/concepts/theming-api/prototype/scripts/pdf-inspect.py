"""compat-014: stdlib-only PDF inspection.

Usage: python pdf-inspect.py file.pdf [...]
Prints for each PDF: header version, PDF/A + PDF/UA identification from XMP,
the embedded files (name, AFRelationship, decompressed size) and whether the
embedded factur-x.xml is a CrossIndustryInvoice. Exit code 1 if a PDF that
declares PDF/A-3 has no factur-x.xml attachment while the name was expected.
"""
import re
import sys
import zlib


def streams(data):
    # yields (dict_bytes, raw_stream_bytes) for every object stream
    for m in re.finditer(rb"(\d+) 0 obj\s*(<<.*?>>)\s*stream\r?\n", data, re.S):
        start = m.end()
        length = re.search(rb"/Length (\d+)", m.group(2))
        if not length:
            continue
        n = int(length.group(1))
        yield int(m.group(1)), m.group(2), data[start:start + n]


def inflate(d, raw):
    if b"/FlateDecode" in d:
        try:
            return zlib.decompress(raw)
        except zlib.error:
            return b""
    return raw


def main(paths):
    rc = 0
    for p in paths:
        data = open(p, "rb").read()
        print(f"== {p}  ({len(data)} bytes, header {data[:8].decode('latin1').strip()})")
        xmp = b""
        files = []
        for num, d, raw in streams(data):
            body = inflate(d, raw)
            if b"/Metadata" in d or b"x:xmpmeta" in body[:400]:
                if b"xmpmeta" in body:
                    xmp = body
            if b"/EmbeddedFile" in d:
                files.append((num, body))
        part = re.search(rb"pdfaid:part[>=\"']+(\d)", xmp)
        conf = re.search(rb"pdfaid:conformance[>=\"']+(\w)", xmp)
        ua = re.search(rb"pdfuaid:part[>=\"']+(\d)", xmp)
        print("   PDF/A:", (part.group(1).decode() + (conf.group(1).decode() if conf else "")) if part else "-",
              "| PDF/UA:", ua.group(1).decode() if ua else "-")
        names = re.findall(rb"/F(?:ile)?\s*\((factur-x\.xml|[^)]*\.xml)\)", data)
        rel = re.findall(rb"/AFRelationship\s*/(\w+)", data)
        print("   filespec names:", sorted(set(n.decode() for n in names)) or "-",
              "| AFRelationship:", sorted(set(r.decode() for r in rel)) or "-")
        for num, body in files:
            kind = "CrossIndustryInvoice" if b"CrossIndustryInvoice" in body else "other"
            guid = re.search(rb"GuidelineSpecifiedDocumentContextParameter>\s*<ram:ID>([^<]+)</ram:ID>", body)
            print(f"   embedded obj {num}: {len(body)} bytes, {kind}, starts {body[:38]!r}",
                  "| guideline:", guid.group(1).decode() if guid else "-")
        if part and part.group(1) == b"3" and not any(b"CrossIndustryInvoice" in b for _, b in files):
            print("   MISSING factur-x.xml")
            rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
