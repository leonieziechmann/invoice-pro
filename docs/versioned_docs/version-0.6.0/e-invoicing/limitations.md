---
sidebar_position: 4
---

# Scope and Limitations

This page lists what `invoice-pro` does not support, the details of the XML that are fixed, and the Factur-X XMP metadata that Typst cannot write yet.

## Scope

- **Format:** hybrid PDF/A-3 invoices with the XML of Factur-X 1.09.2 / ZUGFeRD 2.5.2 in the syntax of the UN/CEFACT Cross Industry Invoice (CII), in the profiles MINIMUM, BASIC WL, BASIC, EN 16931 and XRechnung 3.0.
- **Not supported:** the EXTENDED profile of Factur-X, the UBL syntax (XRechnung is written in CII), and an XML file of its own (see [The XML on Its Own](#the-xml-on-its-own)).
- **Documents:** invoices and credit notes, including corrected, prepayment and self-billed invoices (see [Document Type](./invoice-data/document.md#document-type-bt-3)). Quotes, delivery notes and other documents that are no invoice have no e-invoice.
- **Business terms:** some business terms of EN 16931 have no input, e.g. the VAT accounting currency (BT-6, BT-111, see [VAT in the National Currency](./invoice-data/document.md#vat-in-the-national-currency-bt-6-bt-111)) and additional supporting documents (BG-24). [Business Terms](./invoice-data/business-terms.md) lists every term that `invoice-pro` does not support, with the reason.
- **Legal requirements:** the rules of `invoice-pro` check some requirements of the law that the official rules miss (see [Rules of invoice-pro](./validation.md#rules-of-invoice-pro)), but they are no legal advice: they cannot tell whether your data is right.

## Fixed Details

- **Business Process URN (BT-23):** Whenever using the `"en16931"` or `"xrechnung"` profiles, the Business Process context URN is hardcoded to `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0` (standard billing transaction).
- **EAS Scheme Fallback:** If the prefix of a party's VAT ID has no known scheme and neither a custom `electronic-address` nor an email address is specified, the electronic address block is omitted from the XML payload.
- **Plain Text:** Names, addresses and references given as content are written as their plain text; formatting is dropped.

## The XML on Its Own

`invoice-pro` attaches the XML to the PDF and writes no separate file. XRechnung is primarily exchanged as the XML file itself: if a recipient asks for an XRechnung, extract the XML from the PDF, e.g. with `pdfdetach -saveall invoice.pdf` of the poppler utilities, or with Mustang (step 2 below).

## Factur-X XMP Metadata

A Factur-X / ZUGFeRD PDF announces its XML in the XMP metadata of the PDF, with the Factur-X extension schema (`fx:DocumentType`, `fx:DocumentFileName`, `fx:Version` and `fx:ConformanceLevel`). Typst cannot write custom XMP metadata yet, so `invoice-pro` cannot add these entries. This is a limitation of the Typst platform, not of the invoice data:

- The embedded XML (`factur-x.xml`, or `xrechnung.xml` in the XRechnung profile) is complete and valid for its profile. Most receiving systems only extract and process this XML.
- Validators that check the PDF itself reject it. The Mustang validator, for example, reports `XMP Metadata: ConformanceLevel not found` together with the missing `DocumentType`, `DocumentFileName` and `Version`, and rates the PDF (not the XML) as invalid.

`invoice-pro` will write the metadata as soon as Typst supports custom XMP metadata ([typst/typst#5667](https://github.com/typst/typst/issues/5667)). It is prepared already: `tools/zugferd/xmp.typ` of the repository builds the Factur-X metadata of every profile (the document type `INVOICE`, the name of the attached XML, the version `1.0` and the conformance level `MINIMUM`, `BASIC WL`, `BASIC`, `EN 16931` or `XRECHNUNG`) together with the PDF/A description of its extension schema, and a test compares it with the metadata that Mustang writes (see below). The package does not ship it until Typst can write the metadata, so it costs no compile time.

:::info Optional post-processing, outside the package
You do not need any of this to create an invoice, and `invoice-pro` does not run external tools. If a recipient requires a PDF that passes the Factur-X PDF check, you can add the metadata afterwards with the [Mustang](https://www.mustangproject.org/) command line tool, which needs Java: download `Mustang-CLI-2.26.0.jar` from the [Mustang releases](https://github.com/ZUGFeRD/mustangproject/releases) and run it with `java -jar`. The steps below were tested with Mustang CLI 2.26.0.
:::

```bash
# 1. Compile the invoice as usual.
typst compile --pdf-standard=a-3b invoice.typ invoice.pdf

# 2. Extract the XML that invoice-pro embedded.
java -jar Mustang-CLI-2.26.0.jar --action extract \
  --source invoice.pdf --out invoice.xml

# 3. Embed it again together with the Factur-X XMP metadata. The profile
#    letter must match the profile of the invoice (see the table below).
java -jar Mustang-CLI-2.26.0.jar --action combine \
  --source invoice.pdf --source-xml invoice.xml --out invoice-facturx.pdf \
  --format fx --version 1 --profile E --no-additional-attachments

# 4. Check the result: PDF, XML and the summary must be "valid".
java -jar Mustang-CLI-2.26.0.jar --action validate --source invoice-facturx.pdf
```

| `zugferd` profile of the invoice | `--profile` |
| :------------------------------- | :---------- |
| `"minimum"`                      | `M`         |
| `"basic-wl"`                     | `W`         |
| `"basic"`                        | `B`         |
| `"en16931"`                      | `E`         |
| `"xrechnung"`                    | `X`         |

With `zugferd: auto`, use the profile the invoice was written in: `X` if the guideline ID of the XML (BT-24) ends in `xrechnung_3.0`, otherwise `E`. `--format fx --version 1` writes the metadata of Factur-X 1.0, which ZUGFeRD 2.1 and later use as well. For `X`, Mustang names the XML `xrechnung.xml`, as `invoice-pro` does, and replaces it with the same XML, so the PDF carries it once. XRechnung is primarily exchanged as the XML file itself: if a recipient asks for an XRechnung, you can send `invoice.xml` from step 2.
