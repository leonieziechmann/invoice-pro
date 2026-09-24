#!/usr/bin/env python3
"""Generates the tables of the XML write guard (src/zugferd/guard/).

  gen_guard.py [--jar PATH] [--kosit-config DIR] [--out DIR] [--check]
               [--stats FILE] [--explain]

The guard (concept, section 4.4) checks every element while the serializer
writes it: that the profile's XSD knows it at this position, in this order
and number, that the profile does not mark it as not used, and that its codes
and lexical values satisfy the official code lists and formats that apply at
this position in this profile. This script compiles those constraints from
the pinned official artefacts inside the Mustang CLI jar 2.14.0 ($MUSTANG_JAR
or --jar; read with zipfile, nothing is vendored):

  schema/ZF_230/<P>/*.xsd                                Factur-X 1.0.07 XSD
  xslt/ZF_230/FACTUR-X_<P>.xslt, FACTUR-X_<P>_codedb.xml Factur-X Schematron
  xslt/cii16931schematron/EN16931-CII-validation.xslt    CEN EN 16931 (CII) 1.3.12
  xslt/XR_30/XRechnung-CII-validation.xslt               XRechnung 3.0 (CII)

and from the unpacked XRechnung configuration of the KoSIT validator
($KOSIT_CONFIG or --kosit-config, configuration 2026-08-31, also pinned):

  resources/cii/16b/xsl/EN16931-CII-validation.xsl       CEN EN 16931 (CII) 1.3.16

Which artefacts apply to which profile mirrors Mustang's validator: the
Factur-X Schematron of the profile for MINIMUM, BASIC WL, BASIC and
EN 16931; the CEN Schematron for BASIC, EN 16931 and XRechnung; the
XRechnung Schematron for XRechnung, which uses the EN 16931 XSD. Every failed
assertion counts, whatever its flag: Mustang reports the warnings of these
Schematrons as errors too. The reports of the Factur-X Schematron mark
elements and attributes as not used in a profile; Mustang ignores them, the
guard does not, since they define the profile.

The KoSIT validator applies a newer CEN Schematron (1.3.16) to EN 16931 and
XRechnung documents, whose code lists have withdrawn codes that the older
lists still have (e.g. the currencies BGN and HRK, the scheme 9901) and added
new ones. Its code list rules join the CEN rules of the profiles with the
CEN Schematron (see `load_cen_code_lists`): a code at such a position must be
in the lists of both versions, but for a currency outside XRechnung, which
is allowed where the Factur-X validation accepts it (NEWEST_XRECHNUNG_ONLY).
Everything else of CEN 1.3.16 is left to the corpus, which runs KoSIT. There
is no fallback without the configuration: the tables would silently accept
the withdrawn codes.

Global variables and parameters of the XRechnung Schematron that stand for
a literal (e.g. $XR-CIUS-ID) or a path (e.g. $documentCurrencyCode) are
replaced by it in the tests of its rules (see `global_values`), so that
rules such as BR-DE-21 and PEPPOL-EN16931-R053 compile.

Output (data shipped with the package, see `emit_lists` and `emit_profile`;
the serializer src/zugferd/guard/write.typ reads it and describes the
format; JSON, which Typst reads several times faster than the same data as
Typst source):

  src/zugferd/guard/lists.json      the code lists, the tables of the VAT
                                    category rules, and the lists of the
                                    validator (see VALIDATOR_LISTS), the one
                                    source of the code lists of
                                    src/zugferd/rules/; src/zugferd/guard/
                                    lists.typ reads it
  src/zugferd/guard/<profile>.json  the nodes of each profile, and the rule
                                    that forbids an empty leaf

A node describes an element at a position. Positions with the same type and
the same constraints share a node, so a complex type is written once unless
the Schematron treats its positions differently. A complex node lists its
children in schema order with their cardinality and the rule that sets it; a
leaf node its lexical kind, its attributes and the code lists of its text.
The code list at a position is the intersection of the lists of every
validator that applies there. The rules of a VAT category on a tax element
(its rate, VAT amount and exemption reason, e.g. BR-S-05, BR-E-10) are
tables by category code in lists.json, shared by the profiles, which the
node of the tax element's parent names (see TAX_ELEMENTS).

The Factur-X XSDs use a small subset of XML Schema, and the Schematron rules
a small set of shapes. The script fails on anything outside of that subset
instead of guessing, so the tables are exact for what they cover. A rule
whose context or test is a condition on values, sums or other elements is a
business rule: it is left to invoice-pro's validator. `--explain` lists
every rule with its disposition, `--stats` writes the numbers as JSON.

`--check` generates into a temporary directory and fails when the committed
tables differ from it (drift test, run by scripts/zugferd-corpus).
"""

import argparse
import collections
import dataclasses
import difflib
import hashlib
import json
import os
import re
import sys
import tempfile
import zipfile
from pathlib import Path

from lxml import etree

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
OUT = REPO / "src" / "zugferd" / "guard"

XS = "{http://www.w3.org/2001/XMLSchema}"
XSL = "{http://www.w3.org/1999/XSL/Transform}"
SVRL = "{http://purl.oclc.org/dsdl/svrl}"
PREFIXES = {
    "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100": "rsm",
    "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100": "ram",
    "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100": "udt",
    "urn:un:unece:uncefact:data:standard:QualifiedDataType:100": "qdt",
}
UNBOUNDED = -1


class GenError(Exception):
    """An artefact or a rule outside of what the generator understands."""


# ================================================================ artefacts

PROFILES = {
    # profile: (XSD directory, Factur-X Schematron, CEN Schematron, XRechnung Schematron)
    "minimum": ("MINIMUM", "MINIMUM", False, False),
    "basic-wl": ("BASIC-WL", "BASIC-WL", False, False),
    "basic": ("BASIC", "BASIC", True, False),
    "en16931": ("EN16931", "EN16931", True, False),
    "xrechnung": ("EN16931", None, True, True),
}
CEN_XSLT = "xslt/cii16931schematron/EN16931-CII-validation.xslt"
XR_XSLT = "xslt/XR_30/XRechnung-CII-validation.xslt"

# SHA-256 of every artefact the tables are compiled from, as found in
# Mustang-CLI-2.14.0.jar. Another jar fails instead of silently changing the
# tables; updating a pin is a deliberate change that regenerates them.
_Z = "schema/ZF_230/"
_Q = "urn_un_unece_uncefact_data_standard_QualifiedDataType_100.xsd"
_R = "urn_un_unece_uncefact_data_standard_ReusableAggregateBusinessInformationEntity_100.xsd"
_U = "urn_un_unece_uncefact_data_standard_UnqualifiedDataType_100.xsd"
PINS = {
    f"{_Z}BASIC-WL/FACTUR-X_BASIC-WL.xsd": "3e32e564c4a7ccbe0e0949f2bb442fd1aa94e74adfa31b52c2d48bab7782ca0f",
    f"{_Z}BASIC-WL/FACTUR-X_BASIC-WL_{_Q}": "fd6958ad55567fbffb127b62b80d9cc76039a6f90315b81cba890646b824743f",
    f"{_Z}BASIC-WL/FACTUR-X_BASIC-WL_{_R}": "aacc882f2b85899befcc3fb8a102237b5db01ce17fe7cf4f8dab6660f3f8062f",
    f"{_Z}BASIC-WL/FACTUR-X_BASIC-WL_{_U}": "39d6b276050cf832b7584c60364ff83b75b834c4026481569633f7a536846f92",
    f"{_Z}BASIC/FACTUR-X_BASIC.xsd": "1335ce8d9311fd88d68c713c3bd441cd0fb036fe7d94c9d3267b9fb4c16733f3",
    f"{_Z}BASIC/FACTUR-X_BASIC_{_Q}": "fd6958ad55567fbffb127b62b80d9cc76039a6f90315b81cba890646b824743f",
    f"{_Z}BASIC/FACTUR-X_BASIC_{_R}": "95d0ca2935ed945b38375dde74423ce5a8cbc5e665fa4b58f40124dbbe9a39e0",
    f"{_Z}BASIC/FACTUR-X_BASIC_{_U}": "1f3b93a872982282fce05893e15f7eb1ed2501fe73fc520c7623bfe98d53056a",
    f"{_Z}EN16931/FACTUR-X_EN16931.xsd": "34e51a9b26c95ef6e09297051b9921a05279a4024e659f236ba5d5e0f5a23bec",
    f"{_Z}EN16931/FACTUR-X_EN16931_{_Q}": "5a3ce756cfa8d4f2ff3165d68123cfb7fbf3c7b64664edb0de38cca64d5c413b",
    f"{_Z}EN16931/FACTUR-X_EN16931_{_R}": "d39f7671991005a14d1422ca870663857350d586d95479504d1ba53ef7e95ee0",
    f"{_Z}EN16931/FACTUR-X_EN16931_{_U}": "9590182879865144dfc6ae069ef7499defaa7d31cb62e30ccacf9146ace5306d",
    f"{_Z}MINIMUM/FACTUR-X_MINIMUM.xsd": "f757df8498471c5813ea44e73cfa394a6229aba7e2961d0f26c380aab4e6b81d",
    f"{_Z}MINIMUM/FACTUR-X_MINIMUM_{_Q}": "7830de0041e47dd035fb482d369414422768ff215a3cf668f9fa83f720cec2cc",
    f"{_Z}MINIMUM/FACTUR-X_MINIMUM_{_R}": "7afe6bac0e2a2b52bc36ef650b1ae1d8600b8d430e0a1258830f4b64d90c90c9",
    f"{_Z}MINIMUM/FACTUR-X_MINIMUM_{_U}": "ea823ec1acb7cbe28690b2176d3f9ca8cc2d7d795303879252100a82758b01a0",
    "xslt/XR_30/XRechnung-CII-validation.xslt": "9fa88a9f8f8a80489987aa0facc7047658bb3b2b882214e32241ecfc837d0e96",
    "xslt/ZF_230/FACTUR-X_BASIC-WL.xslt": "dc36319c73cfde6ec135acbc8f49165d74f4deeff6d11c116597ec655468e82e",
    "xslt/ZF_230/FACTUR-X_BASIC-WL_codedb.xml": "9dda0b5e9bf9016b7e684ddc023ac440184bf469767a7a22032c7362ebc33935",
    "xslt/ZF_230/FACTUR-X_BASIC.xslt": "05ab01cd050b338dfafba3a7beeaa9d10594a44df826457556ac8c8c91a5c2eb",
    "xslt/ZF_230/FACTUR-X_BASIC_codedb.xml": "8cf66b158e05344206bf99431c055fa02280ce5ec83bfb8883e15eb3f112534b",
    "xslt/ZF_230/FACTUR-X_EN16931.xslt": "9f97895482aa1744361129d1a91861de20850ec51f1ae1e4ab424db0d61d830f",
    "xslt/ZF_230/FACTUR-X_EN16931_codedb.xml": "5f2dde09df57bb0c0179168b5c374ade056921b47f582ecc54e516a7cb8914cb",
    "xslt/ZF_230/FACTUR-X_MINIMUM.xslt": "a9fe19121ff10eb1e15ec8b7de513b6ea8fa9afc8071707b6876fb60a48816dd",
    "xslt/ZF_230/FACTUR-X_MINIMUM_codedb.xml": "8b9afcb6fe8b69b4086963b341274fe4f581f8d7c8358d5bf7944a5cd3209d9a",
    "xslt/cii16931schematron/EN16931-CII-validation.xslt": "02136fe6138737cd3be63a7ec7f7604c1b716df1899301e575f7018972444be8",
}


def fx_xslt(name):
    return f"xslt/ZF_230/FACTUR-X_{name}.xslt"


def fx_codedb(name):
    return f"xslt/ZF_230/FACTUR-X_{name}_codedb.xml"


class Jar:
    """Reads members of the Mustang jar and checks them against PINS."""

    def __init__(self, path, pinned=True):
        self.path = Path(path)
        try:
            self.zip = zipfile.ZipFile(self.path)
        except (OSError, zipfile.BadZipFile) as e:
            raise GenError(f"{path}: cannot open the Mustang jar: {e}")
        self.pinned = pinned
        self.digests = {}

    def read(self, name):
        try:
            data = self.zip.read(name)
        except KeyError:
            raise GenError(f"{self.path} has no member {name}; is it Mustang-CLI-2.14.0.jar?")
        digest = hashlib.sha256(data).hexdigest()
        if self.pinned and PINS.get(name) != digest:
            raise GenError(
                f"{name} in {self.path} is not the pinned artefact (sha256 {digest}, pinned "
                f"{PINS.get(name)}); the guard tables are compiled from Mustang-CLI-2.14.0.jar"
            )
        self.digests[name] = digest
        return data

    def names(self, prefix):
        return sorted(n for n in self.zip.namelist() if n.startswith(prefix) and not n.endswith("/"))


# The CEN Schematron of the KoSIT validator's XRechnung configuration
# 2026-08-31 (CEN EN 16931 CII 1.3.16, compiled with SchXslt), relative to the
# unpacked configuration, and its SHA-256: another configuration fails
# instead of silently changing the code lists.
KOSIT_CEN = "resources/cii/16b/xsl/EN16931-CII-validation.xsl"
KOSIT_CEN_VERSION = "1.3.16"
KOSIT_PINS = {
    KOSIT_CEN: "0911e927f13f9ae2cdc7f973643f27bf0ad3c5da02483c04a5b8a47eb4822199",
}


class KositConfig:
    """Reads files of the unpacked KoSIT configuration and checks them
    against KOSIT_PINS."""

    def __init__(self, path, pinned=True):
        if not path:
            raise GenError(
                "the code lists need the KoSIT XRechnung configuration 2026-08-31 (CEN Schematron "
                "1.3.16): set KOSIT_CONFIG or --kosit-config to the unpacked configuration"
            )
        self.path = Path(path)
        self.pinned = pinned
        self.digests = {}

    def read(self, name):
        try:
            data = (self.path / name).read_bytes()
        except OSError as e:
            raise GenError(f"{self.path}: no {name} ({e}); is it the KoSIT XRechnung configuration 2026-08-31?")
        digest = hashlib.sha256(data).hexdigest()
        if self.pinned and KOSIT_PINS.get(name) != digest:
            raise GenError(
                f"{name} in {self.path} is not the pinned artefact (sha256 {digest}, pinned "
                f"{KOSIT_PINS.get(name)}); the code lists are compiled from the configuration 2026-08-31"
            )
        self.digests["kosit:" + name] = digest
        return data


def normalize(text):
    return " ".join((text or "").split())


# ================================================================ XSD

XSD_BUILTINS = ("string", "token", "normalizedString", "decimal", "boolean", "base64Binary")


@dataclasses.dataclass
class Particle:
    tag: str
    min: int
    max: int
    type: str


@dataclasses.dataclass
class XType:
    key: str
    complex: bool
    children: list = dataclasses.field(default_factory=list)  # [Particle]
    base: str = None  # built-in base type of simple content ("decimal", "string", ...)
    attrs: dict = dataclasses.field(default_factory=dict)  # name -> required


class Schema:
    """The types of one profile's XSD: named and inline complex types with a
    sequence (or a choice of one element) of local elements, and simple
    content extending a built-in type with attributes. Anything else fails."""

    def __init__(self, jar, directory):
        self.types = {}
        self.simple = {}  # simpleType key -> base type key
        self.root = None
        docs = []
        for name in jar.names(f"schema/ZF_230/{directory}/"):
            if name.endswith(".xsd"):
                root = etree.fromstring(jar.read(name))
                ns = root.get("targetNamespace")
                if ns not in PREFIXES:
                    raise GenError(f"{name}: unknown target namespace {ns}")
                if root.get("elementFormDefault") != "qualified":
                    raise GenError(f"{name}: elements are not qualified")
                docs.append((name, PREFIXES[ns], root))
        if not docs:
            raise GenError(f"no XSD in schema/ZF_230/{directory}/")
        for name, prefix, root in docs:
            for node in self._children(root):
                if node.tag == XS + "simpleType":
                    self._simple_type(name, prefix, node)
        for name, prefix, root in docs:
            for node in self._children(root):
                if node.tag in (XS + "import", XS + "simpleType"):
                    continue
                if node.tag == XS + "complexType":
                    key = f"{prefix}:{node.get('name')}"
                    self.types[key] = self._complex(name, prefix, key, node, named=True)
                elif node.tag == XS + "element":
                    if self.root is not None:
                        raise GenError(f"{name}: more than one global element")
                    self._attrs(name, node, {"name", "type"})
                    self.root = (f"{prefix}:{node.get('name')}", self._qname(prefix, node.get("type")))
                else:
                    raise GenError(f"{name}: unsupported top-level construct {etree.QName(node).localname}")
        if self.root is None:
            raise GenError(f"schema/ZF_230/{directory}: no global element")

    @staticmethod
    def _children(node):
        return [c for c in node if isinstance(c.tag, str)]

    @staticmethod
    def _qname(prefix, ref):
        return ref if ":" in ref else f"{prefix}:{ref}"

    @staticmethod
    def _attrs(where, node, allowed):
        extra = set(node.attrib) - allowed
        if extra:
            raise GenError(f"{where}: unsupported XSD attributes {sorted(extra)} on {etree.QName(node).localname}")

    def _simple_type(self, where, prefix, node):
        self._attrs(where, node, {"name"})
        parts = self._children(node)
        if len(parts) != 1 or parts[0].tag != XS + "restriction" or self._children(parts[0]):
            raise GenError(f"{where}: simpleType {node.get('name')} is not a restriction without facets")
        self._attrs(where, parts[0], {"base"})
        self.simple[f"{prefix}:{node.get('name')}"] = self._qname(prefix, parts[0].get("base"))

    def _builtin(self, where, ref):
        seen = set()
        while ref in self.simple:
            if ref in seen:
                raise GenError(f"{where}: circular simple type {ref}")
            seen.add(ref)
            ref = self.simple[ref]
        if not ref.startswith("xs:") or ref[3:] not in XSD_BUILTINS:
            raise GenError(f"{where}: unsupported base type {ref}")
        return ref[3:]

    def _complex(self, where, prefix, key, node, named):
        self._attrs(where, node, {"name"} if named else set())
        parts = self._children(node)
        if not parts:
            return XType(key, True)
        if len(parts) != 1:
            raise GenError(f"{where}: {key} has more than one content model")
        content = parts[0]
        if content.tag == XS + "simpleContent":
            self._attrs(where, content, set())
            inner = self._children(content)
            if len(inner) != 1 or inner[0].tag != XS + "extension":
                raise GenError(f"{where}: {key}: simple content other than an extension")
            ext = inner[0]
            self._attrs(where, ext, {"base"})
            attrs = {}
            for a in self._children(ext):
                if a.tag != XS + "attribute":
                    raise GenError(f"{where}: {key}: unsupported {etree.QName(a).localname} in an extension")
                self._attrs(where, a, {"name", "type", "use"})
                use = a.get("use", "optional")
                if use not in ("optional", "required"):
                    raise GenError(f"{where}: {key}: attribute use {use}")
                self._builtin(where, self._qname(prefix, a.get("type")))
                attrs[a.get("name")] = use == "required"
            base = self._builtin(where, self._qname(prefix, ext.get("base")))
            return XType(key, False, base=base, attrs=attrs)
        if content.tag not in (XS + "sequence", XS + "choice"):
            raise GenError(f"{where}: {key}: unsupported content model {etree.QName(content).localname}")
        self._attrs(where, content, set())
        elements = self._children(content)
        if content.tag == XS + "choice" and len(elements) != 1:
            raise GenError(f"{where}: {key}: a choice between {len(elements)} elements")
        particles = []
        for el in elements:
            if el.tag != XS + "element":
                raise GenError(f"{where}: {key}: unsupported particle {etree.QName(el).localname}")
            self._attrs(where, el, {"name", "type", "minOccurs", "maxOccurs"})
            tag = f"{prefix}:{el.get('name')}"
            if tag in (p.tag for p in particles):
                raise GenError(f"{where}: {key}: element {tag} twice in one sequence")
            low = int(el.get("minOccurs", "1"))
            high = el.get("maxOccurs", "1")
            high = UNBOUNDED if high == "unbounded" else int(high)
            inline = self._children(el)
            ref = f"{key}/{tag}"
            if el.get("type") is not None:
                if inline:
                    raise GenError(f"{where}: {ref}: both a type and an inline type")
                named = self._qname(prefix, el.get("type"))
                if named.startswith("xs:") or named in self.simple:
                    self.types[ref] = XType(ref, False, base=self._builtin(where, named))
                else:
                    ref = named
            else:
                if len(inline) != 1 or inline[0].tag != XS + "complexType":
                    raise GenError(f"{where}: {ref}: element without a type")
                self.types[ref] = self._complex(where, prefix, ref, inline[0], named=False)
            particles.append(Particle(tag, low, high, ref))
        return XType(key, True, children=particles)

    def type(self, key):
        try:
            return self.types[key]
        except KeyError:
            raise GenError(f"unknown XSD type {key}")


# ================================================================ positions

OTHER = "*"  # the variant of a family for any value no rule names

# Families of element variants: the Schematron treats these elements
# differently by the value of a discriminator below them (the "element
# variants" of Factur-X; allowances and charges in EN 16931). The
# discriminator is a path of child steps; the last one is an element (its
# text) or an attribute.
FAMILIES = {
    "ram:SpecifiedTaxRegistration": ("ram:ID", "@schemeID"),
    "ram:SpecifiedTradeAllowanceCharge": ("ram:ChargeIndicator", "udt:Indicator"),
    "ram:AppliedTradeAllowanceCharge": ("ram:ChargeIndicator", "udt:Indicator"),
    "ram:AdditionalReferencedDocument": ("ram:TypeCode",),
}

# The tax elements: the VAT breakdown and the tax of a line
# (ram:ApplicableTradeTax) and of an allowance or charge
# (ram:CategoryTradeTax). The Schematron states the rules of a VAT category
# on the tax elements of that category, e.g. BR-S-05 on
# `ram:ApplicableTradeTax[ram:CategoryCode = 'S']` or BR-E-10 on
# `ram:ApplicableTradeTax/ram:CategoryCode[. = 'E']`. A rule that constrains
# the tax element's own rate, VAT amount or exemption reason is compiled into
# a table of its category (`category_check`), which the writer applies by
# the category code the element states; the others (sums, the identifiers
# of the parties, other elements) are business rules. The positions are not
# split by category, which keeps the tables small.
TAX_ELEMENTS = ("ram:ApplicableTradeTax", "ram:CategoryTradeTax")
EXEMPTION_REASONS = ("ram:ExemptionReason", "ram:ExemptionReasonCode")


@dataclasses.dataclass
class Attr:
    required: str = None  # rule that requires it ("XSD" for the schema)
    forbidden: str = None  # rule that forbids it here
    lists: list = dataclasses.field(default_factory=list)  # [CodeList]


@dataclasses.dataclass
class CodeList:
    codes: frozenset
    rule: str
    source: str  # "FX", "CEN", "XR"
    casefold: bool = False  # the value is compared in upper case
    newest: bool = False  # the list of the newest CEN Schematron (KoSIT, KOSIT_CEN_VERSION)


@dataclasses.dataclass(eq=False)
class Pos:
    """An element at a position of the unfolded schema. A family element has
    one position per variant; so do all positions below it."""

    tag: str
    type: XType
    parent: "Pos"
    index: int  # of its particle in the parent's sequence
    min: int
    max: int
    variant: str = None  # discriminator value of a variant, or OTHER
    children: list = dataclasses.field(default_factory=list)
    # constraints, filled in by the rule compiler
    forbidden: tuple = None  # (rule, text): the profile does not use this position
    cmin: dict = dataclasses.field(default_factory=dict)  # child tag -> [(min, rule)]
    cmax: dict = dataclasses.field(default_factory=dict)  # child tag -> [(max, rule)]
    vmax: dict = dataclasses.field(default_factory=dict)  # child tag -> {variant: [(max, rule)]}
    vmin: dict = dataclasses.field(default_factory=dict)  # child tag -> {variant: [(min, rule)]}
    aggregates: list = dataclasses.field(default_factory=list)  # (child path, min, max, rule)
    anyof: list = dataclasses.field(default_factory=list)  # (child tags, rule)
    exclusive: list = dataclasses.field(default_factory=list)  # (child tags, rule)
    no_empty: str = None  # rule forbidding this element empty
    xref: list = dataclasses.field(default_factory=list)  # complex: cross-reference checks
    # tax element: VAT category -> [(check, value, rule)] (see `category_check`)
    categories: dict = dataclasses.field(default_factory=dict)
    attrs: dict = dataclasses.field(default_factory=dict)  # leaf: name -> Attr
    lists: list = dataclasses.field(default_factory=list)  # leaf text: [CodeList]
    prefix: list = dataclasses.field(default_factory=list)  # leaf text: [CodeList] of its first 2 characters
    prefix_when: tuple = None  # (attribute, value) condition of the prefix lists
    fraction: list = dataclasses.field(default_factory=list)  # leaf text: [(max decimals, lexical, rule)]
    date: str = None  # leaf text: rule of the format 102 check

    @property
    def leaf(self):
        return not self.type.complex

    def path(self):
        parts = []
        p = self
        while p is not None:
            parts.append(p.tag + (f"[{p.variant}]" if p.variant is not None else ""))
            p = p.parent
        return "/".join(reversed(parts))

    def ancestors(self):
        p = self.parent
        while p is not None:
            yield p
            p = p.parent

    def depth(self):
        return sum(1 for _ in self.ancestors())

    def child_positions(self, tag):
        return [c for c in self.children if c.tag == tag]


def unfold(schema, variants):
    """The positions of the schema from its root element. `variants` maps a
    family element tag to the discriminator values its rules name."""

    def visit(tag, type_key, parent, index, low, high, variant):
        pos = Pos(tag, schema.type(type_key), parent, index, low, high, variant)
        if pos.depth() > 30:
            raise GenError(f"{pos.path()}: the schema nests deeper than expected (a recursive type?)")
        if pos.type.complex:
            for i, particle in enumerate(pos.type.children):
                values = variants.get(particle.tag)
                for value in [None] if not values else sorted(values) + [OTHER]:
                    pos.children.append(visit(particle.tag, particle.type, pos, i, particle.min, particle.max, value))
        else:
            for name, required in pos.type.attrs.items():
                pos.attrs[name] = Attr(required="XSD" if required else None)
        return pos

    root_tag, root_type = schema.root
    return visit(root_tag, root_type, None, 0, 1, 1, None)


def walk(pos):
    yield pos
    for child in pos.children:
        yield from walk(child)


# ================================================================ Schematron

@dataclasses.dataclass
class Rule:
    source: str  # "FX", "CEN" or "XR"
    artefact: str
    mode: str
    priority: int
    context: str
    kind: str  # "assert" or "report"
    test: str
    id: str  # official id, or None (the reports of Factur-X)
    flag: str
    text: str
    variables: dict  # template variables, name -> select
    codedb: dict  # Factur-X: code list id -> frozenset
    newest: bool = False  # a code list rule of the newest CEN Schematron (see load_cen_code_lists)

    @property
    def business_id(self):
        """The business rule the Factur-X message names, e.g. BR-CO-26."""
        m = re.match(r"\[((?:BR|CII|PEPPOL)[A-Z0-9-]*)\]", self.text)
        return m.group(1) if m else None

    @property
    def ref(self):
        """The rule id a diagnostic names: the official id, or the business
        rule of a Factur-X message; None for the Factur-X reports."""
        return self.business_id or self.id

    def label(self):
        return f"{self.source} {self.id or '(report)'} [{self.context}] {self.test}"


_LITERAL = re.compile(r"^'([^']*)'$")
_ABSOLUTE_PATH = re.compile(r"^(?:/(?:rsm|ram):\w+)+$")
_GLOBAL_REF = re.compile(r"\$([A-Za-z][\w.-]*)")


def global_values(root):
    """The global variables and parameters of a Schematron that stand for a
    literal or a path, by name: a string literal or a `concat` of literals and
    such variables becomes a quoted literal (e.g. $XR-CIUS-ID), an absolute
    path stays a path (e.g. $documentCurrencyCode). Any other (a condition,
    a regular expression used by `matches`) is left out, and so remains a
    `$name` that no test shape of the compiler accepts."""
    selects = {}
    for tag in ("variable", "param"):
        for node in root.findall(XSL + tag):
            select = node.get("select")
            if node.get("name") and select is not None:
                selects[node.get("name")] = normalize(select)
    values = {}

    def literal(expr, seen):
        expr = expr.strip()
        m = _LITERAL.match(expr)
        if m:
            return m.group(1)
        m = re.fullmatch(r"\$([A-Za-z][\w.-]*)", expr)
        if m and m.group(1) in selects and m.group(1) not in seen:
            return literal(selects[m.group(1)], seen | {m.group(1)})
        m = re.fullmatch(r"concat\((.*)\)", expr)
        if m:
            parts = [literal(part, seen) for part in split_top(m.group(1), ",")]
            return None if None in parts else "".join(parts)
        return None

    for name, select in selects.items():
        text = literal(select, {name})
        if text is not None and "'" not in text:
            values[name] = f"'{text}'"
        elif text is None and _ABSOLUTE_PATH.match(select):
            values[name] = select
    return values


def substitute(test, values):
    """`test` with the references of `values` replaced by their value."""
    return _GLOBAL_REF.sub(lambda m: values.get(m.group(1), m.group(0)), test)


def load_rules(jar, artefact, source, codedb_name=None):
    root = etree.fromstring(jar.read(artefact))
    codedb = {}
    if codedb_name:
        db = etree.fromstring(jar.read(codedb_name))
        for cl in db.findall("cl"):
            codedb[cl.get("id")] = frozenset(e.get("value") for e in cl.findall("enumeration"))
    # The global variables of the XRechnung Schematron (see `global_values`);
    # the other Schematrons use none in their tests.
    values = global_values(root) if source == "XR" else {}
    rules = []
    for template in root.iter(XSL + "template"):
        mode = template.get("mode") or ""
        priority = template.get("priority")
        if not re.fullmatch(r"M\d+", mode) or priority in ("-1", "-2"):
            continue
        variables = {v.get("name"): normalize(v.get("select")) for v in template.findall(XSL + "variable")}
        for kind, tag in (("assert", "failed-assert"), ("report", "successful-report")):
            for node in template.iter(SVRL + tag):
                attrs = {a.get("name"): normalize("".join(a.itertext())) for a in node.findall(XSL + "attribute")}
                text = node.find(SVRL + "text")
                rules.append(
                    Rule(
                        source=source,
                        artefact=artefact,
                        mode=mode,
                        priority=int(priority),
                        context=normalize(template.get("match")),
                        kind=kind,
                        test=substitute(normalize(node.get("test")), values),
                        id=attrs.get("id"),
                        flag=attrs.get("flag"),
                        text=normalize("".join(text.itertext())) if text is not None else "",
                        variables=variables,
                        codedb=codedb,
                    )
                )
    if not rules:
        raise GenError(f"{artefact}: no Schematron rules found")
    return rules


def is_code_list_test(test):
    """Whether a test is a code list of the CEN Schematron (a `contains` of
    the codes, or `@a = '..' or ..` of an attribute)."""
    test = strip_parens(test)
    return bool(_T_LIST.match(test) or _T_ATTR_VALUES.match(test))


def load_cen_code_lists(kosit, cen_rules):
    """The code list rules of the newest CEN Schematron (KOSIT_CEN, compiled
    with SchXslt), as rules of the CEN Schematron the compiler knows: each is
    the twin of the rule of CEN 1.3.12 with the same id and context, whose
    mode and priority it takes, so that it applies at the same positions, and
    adds its list there (`newest`). A code list rule without such a twin
    fails: the newest version then checks a code the tables do not know."""
    root = etree.fromstring(kosit.read(KOSIT_CEN))
    twins = {(r.id, r.context): r for r in cen_rules if r.kind == "assert"}
    rules = []
    for template in root.iter(XSL + "template"):
        context = normalize(template.get("match"))
        for node in template.iter(SVRL + "failed-assert"):
            tests = [a for a in node.findall(XSL + "attribute") if a.get("name") == "test"]
            test = normalize("".join(tests[0].itertext())) if tests else ""
            if not is_code_list_test(test):
                continue
            twin = twins.get((node.get("id"), context))
            if twin is None:
                raise GenError(
                    f"{KOSIT_CEN}: the code list rule {node.get('id')} [{context}] has no rule of the same id "
                    f"and context in {CEN_XSLT}"
                )
            text = node.find(SVRL + "text")
            rules.append(dataclasses.replace(
                twin,
                artefact=KOSIT_CEN,
                test=test,
                flag=node.get("flag"),
                text=normalize("".join(text.itertext())) if text is not None else "",
                newest=True,
            ))
    if not rules:
        raise GenError(f"{KOSIT_CEN}: no code list rules found")
    return rules


# ---------------------------------------------------------------- XPath helpers


def split_top(text, sep):
    """Splits `text` at `sep` outside of brackets, parentheses and quotes."""
    parts, depth, quote, start, i = [], 0, None, 0, 0
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch in "[(":
            depth += 1
        elif ch in "])":
            depth -= 1
        elif depth == 0 and text.startswith(sep, i):
            parts.append(text[start:i])
            i += len(sep)
            start = i
            continue
        i += 1
    if depth != 0 or quote:
        raise GenError(f"unbalanced XPath: {text}")
    parts.append(text[start:])
    return parts


def strip_parens(text):
    """`(x)` -> `x` when the parentheses enclose the whole expression."""
    text = text.strip()
    while text.startswith("(") and text.endswith(")"):
        depth = 0
        for i, ch in enumerate(text):
            depth += ch == "("
            depth -= ch == ")"
            if depth == 0 and i < len(text) - 1:
                return text
        text = text[1:-1].strip()
    return text


@dataclasses.dataclass
class Step:
    name: str  # QName, "prefix:*" or "*"
    predicates: list
    descendant: bool  # preceded by "//" (any ancestor chain in between)


def parse_pattern(pattern):
    """An XSLT match pattern as alternatives of steps, each alternative with
    a flag whether it is anchored at the root."""
    alternatives = []
    for alt in split_top(pattern, "|"):
        alt = alt.strip()
        anchored = alt.startswith("/") and not alt.startswith("//")
        body = alt[1:] if anchored else alt
        steps, descendant = [], True
        if body.startswith("//"):
            body = body[2:]
        for raw in split_top(body, "/"):
            if raw == "":  # "//" between two steps
                descendant = True
                continue
            m = re.match(r"^([A-Za-z0-9_.:*-]+)", raw.strip())
            if not m:
                raise GenError(f"unsupported step {raw!r} in pattern {pattern!r}")
            rest = raw.strip()[m.end():]
            predicates = []
            while rest:
                if not rest.startswith("["):
                    raise GenError(f"unsupported step {raw!r} in pattern {pattern!r}")
                depth = 0
                for i, ch in enumerate(rest):
                    depth += ch == "["
                    depth -= ch == "]"
                    if depth == 0:
                        predicates.append(normalize(rest[1:i]))
                        rest = rest[i + 1:].strip()
                        break
            steps.append(Step(m.group(1), predicates, descendant))
            descendant = False
        alternatives.append((anchored, steps))
    return alternatives


def name_matches(name, tag):
    if name == "*":
        return True
    if name.endswith(":*"):
        return tag.startswith(name[:-1])
    return name == tag


# ---------------------------------------------------------------- predicates

# Outcomes of a predicate at a position.
TRUE, FALSE = "true", "false"
Dynamic = collections.namedtuple("Dynamic", "kind data")  # a condition only the document decides

_ATTR_EXISTS = re.compile(r"^@([\w:]+)$")
_ATTR_EQ = re.compile(r"^@([\w:]+) ?= ?(['\"])([^'\"]*)\2$")
_ANCESTOR_NOT = re.compile(r"^not ?\(ancestor::([\w:]+)\)$")
_NAME_ENDS = re.compile(r"^ends-with\(name\(\), ?'(\w+)'\)$")
_NOT_SELF = re.compile(r"^not ?\(self::([\w:]+)\)$")
_VALUE_EQ = re.compile(r"^([\w:@/]+) ?= ?(?:(['\"])([^'\"]*)\2|(false|true)\(\))$")
_XREF = re.compile(
    r"^@currencyID ?= ?(?:\.\./\.\./|/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/"
    r"ram:ApplicableHeaderTradeSettlement/)ram:(InvoiceCurrencyCode|TaxCurrencyCode)$"
)
_BOOLEAN_LEXICAL = {"false": ("false", "0"), "true": ("true", "1")}


def family_path(pos):
    """The discriminator of `pos` if it is a family element, else None."""
    return FAMILIES.get(pos.tag)


def value_condition(expr):
    """A comparison of a path with literals: (path, set of values, negated),
    for `p="v"`, `p = false()`, `p='a' or p='b'` and `not(p="a") and not(p="b")`.
    None for anything else."""
    expr = strip_parens(expr)
    conj = [strip_parens(c) for c in split_top(expr, " and ")]
    if len(conj) > 1:
        paths, values = set(), set()
        for c in conj:
            m = re.match(r"^not ?\((.*)\)$", c)
            if not m:
                return None
            inner = value_condition(m.group(1))
            if inner is None or inner[2]:
                return None
            paths.add(inner[0])
            values |= inner[1]
        return (paths.pop(), frozenset(values), True) if len(paths) == 1 else None
    disj = [strip_parens(d) for d in split_top(expr, " or ")]
    paths, values = set(), set()
    for d in disj:
        m = _VALUE_EQ.match(d)
        if not m:
            return None
        paths.add(m.group(1))
        if m.group(4):  # XPath 2: a node compared with a boolean is cast to xs:boolean
            values |= set(_BOOLEAN_LEXICAL[m.group(4)])
        else:
            values.add(m.group(3))
    return (paths.pop(), frozenset(values), False) if len(paths) == 1 else None


def family_values(pred, pos):
    """The discriminator values a predicate on `pos` names, when it is a
    condition on the discriminator of pos's family (or, on the first step of
    the discriminator, of its parent's family): (owner, values, negated)."""
    cond = value_condition(pred)
    if cond is None:
        return None
    path, values, negated = cond
    steps = tuple(path.split("/"))
    own = family_path(pos)
    if own and steps == own:
        return pos, values, negated
    parent = pos.parent
    if parent is not None:
        disc = family_path(parent)
        if disc and disc[0] == pos.tag and steps == disc[1:]:
            return parent, values, negated
    return None


_SELF_EQ = re.compile(r"^\. ?= ?'(\w+)'$")
_VAT_TYPE = re.compile(r"^upper-case\((\.\./)?ram:TypeCode\) ?= ?'VAT'$")


def category_condition(pred, pos):
    """The condition of a predicate on the VAT category of a tax element
    (TAX_ELEMENTS): `[ram:CategoryCode = 'S']` on the element, or `[. = 'S']`
    on its `ram:CategoryCode`, as a Dynamic "category" (tax element, codes);
    `[upper-case(ram:TypeCode) = 'VAT']` (`../ram:TypeCode` on the category
    code), the rule's restriction to VAT, as a Dynamic "vat" (tax element).
    None for any other predicate."""
    if pos.tag in TAX_ELEMENTS:
        tax, own = pos, True
    elif pos.tag == "ram:CategoryCode" and pos.parent is not None and pos.parent.tag in TAX_ELEMENTS:
        tax, own = pos.parent, False
    else:
        return None
    m = _VAT_TYPE.match(pred)
    if m:
        return Dynamic("vat", tax) if (m.group(1) is None) == own else None
    if own:
        cond = value_condition(pred)
        if cond is not None and cond[0] == "ram:CategoryCode" and not cond[2]:
            return Dynamic("category", (tax, cond[1]))
        return None
    m = _SELF_EQ.match(pred)
    return Dynamic("category", (tax, frozenset({m.group(1)}))) if m else None


def eval_predicate(pred, pos):
    """TRUE, FALSE or a Dynamic condition of a predicate at `pos`."""
    if "$isExtension" in pred:
        return FALSE  # rules of the XRechnung extension, never active here
    category = category_condition(pred, pos)
    if category is not None:
        return category
    conj = split_top(pred, " and ")
    if len(conj) > 1 and all(_ANCESTOR_NOT.match(strip_parens(c)) for c in conj):
        tags = {p.tag for p in pos.ancestors()}
        return FALSE if any(_ANCESTOR_NOT.match(strip_parens(c)).group(1) in tags for c in conj) else TRUE
    m = _ANCESTOR_NOT.match(pred)
    if m:
        return FALSE if m.group(1) in {p.tag for p in pos.ancestors()} else TRUE
    if len(conj) == 2 and _NAME_ENDS.match(strip_parens(conj[0])) and _NOT_SELF.match(strip_parens(conj[1])):
        suffix = _NAME_ENDS.match(strip_parens(conj[0])).group(1)
        other = _NOT_SELF.match(strip_parens(conj[1])).group(1)
        return TRUE if pos.tag.endswith(suffix) and pos.tag != other else FALSE
    m = _NAME_ENDS.match(pred)
    if m:
        return TRUE if pos.tag.endswith(m.group(1)) else FALSE
    fam = family_values(pred, pos)
    if fam is not None:
        owner, values, negated = fam
        if owner.variant is None:
            return Dynamic("family", (owner, values, negated))  # no split: decided by the document
        hit = owner.variant != OTHER and owner.variant in values
        return TRUE if hit != negated else FALSE
    m = _ATTR_EXISTS.match(pred)
    if m:
        if pos.leaf and m.group(1) not in pos.attrs:
            return FALSE  # the XSD does not allow the attribute here
        return Dynamic("attr", (m.group(1), None))
    m = _ATTR_EQ.match(pred)
    if m:
        if pos.leaf and m.group(1) not in pos.attrs:
            return FALSE
        return Dynamic("attr", (m.group(1), m.group(3)))
    conj = [strip_parens(c) for c in split_top(pred, " and ")]
    if all(_XREF.match(c) or c == "@currencyID" for c in conj):
        refs = [_XREF.match(c).group(1) for c in conj if _XREF.match(c)]
        return Dynamic("xref", (refs[0], False)) if len(refs) == 1 else Dynamic("business", pred)
    if len(conj) == 2 and all(re.match(r"^not ?\(", c) for c in conj):
        refs = [_XREF.match(strip_parens(c[c.index("(") + 1:-1])) for c in conj]
        if all(refs):
            return Dynamic("xref", (tuple(r.group(1) for r in refs), True))
    return Dynamic("business", pred)


def match(alternative, pos):
    """None, or the dynamic conditions [(step index, position, Dynamic)] under
    which the pattern alternative matches `pos`."""
    anchored, steps = alternative

    def rec(i, p):
        step = steps[i]
        if not name_matches(step.name, p.tag):
            return None
        conds = []
        for pred in step.predicates:
            outcome = eval_predicate(pred, p)
            if outcome == FALSE:
                return None
            if outcome != TRUE:
                conds.append((i, p, outcome))
        if i == 0:
            return conds if not anchored or p.parent is None else None
        candidates = list(p.ancestors()) if step.descendant else [p.parent] if p.parent else []
        for a in candidates:
            found = rec(i - 1, a)
            if found is not None:
                return found + conds
        return None

    return rec(len(steps) - 1, pos)


def parse_location(expr):
    """A location path of a test as (absolute, steps, attribute): absolute is
    None, "/" or "//"; steps are (name, predicates) of `..` or element
    steps; attribute is the name of a final `@name` step. None for anything
    else."""
    expr = expr.strip()
    absolute = "//" if expr.startswith("//") else "/" if expr.startswith("/") else None
    body = expr[len(absolute or ""):]
    parts = split_top(body, "/")
    steps, attr = [], None
    for i, part in enumerate(parts):
        part = part.strip()
        if part == "..":
            if absolute or any(s[0] != ".." for s in steps):
                return None
            steps.append(("..", []))
            continue
        m = re.fullmatch(r"@(\w+)", part)
        if m and i == len(parts) - 1 and steps:
            attr = m.group(1)
            continue
        m = re.match(r"^((?:rsm|ram|udt|qdt):\w+)", part)
        if not m:
            return None
        rest, preds = part[m.end():].strip(), []
        while rest:
            if not rest.startswith("["):
                return None
            depth = 0
            for j, ch in enumerate(rest):
                depth += ch == "["
                depth -= ch == "]"
                if depth == 0:
                    preds.append(normalize(rest[1:j]))
                    rest = rest[j + 1:].strip()
                    break
            else:
                return None
        steps.append((m.group(1), preds))
    if not [s for s in steps if s[0] != ".."]:
        return None
    return absolute, steps, attr


# The predicate of the last step of a location that asks for its text.
_WITH_TEXT = re.compile(r"(.*)\[boolean\(normalize-space\(\.\)\)\]")


def presence_atom(text):
    """(location, non-empty) of `E`, `E != ''`, `normalize-space(E) != ''`
    or `E[boolean(normalize-space(.))]` (an E with text, the form of the
    XRechnung Schematron)."""
    text = strip_parens(text)
    m = re.fullmatch(r"normalize-space\((.*)\) ?!= ?''", text)
    if m:
        location = parse_location(m.group(1))
        return (location, True) if location else None
    m = re.fullmatch(r"(.*?) ?!= ?''", text)
    if m:
        location = parse_location(m.group(1))
        return (location, True) if location else None
    m = _WITH_TEXT.fullmatch(text)
    if m:
        location = parse_location(m.group(1))
        return (location, True) if location else None
    location = parse_location(text)
    return (location, False) if location else None


def match_pattern(pattern, pos):
    """The conditions of the first alternative of `pattern` matching `pos`."""
    for alternative in pattern:
        found = match(alternative, pos)
        if found is not None:
            return found
    return None


# ================================================================ compiling the rules

# A relative location path of a test: optional `..` steps, then child steps.
RELPATH = r"(?:\.\./)*(?:ram|udt|qdt|rsm):\w+(?:/(?:ram|udt|qdt|rsm):\w+)*"
_T_REQUIRED = re.compile(rf"^({RELPATH})$")
_T_FORBIDDEN = re.compile(rf"^not ?\(({RELPATH})\)$")
_T_COUNT = re.compile(rf"^count\(({RELPATH})\) ?(=|<=|>=) ?1$")
# `count(ram:A/ram:B[p]) <= 1`: the steps before the counted element (here
# ram:A) must each occur at most once, so that the count is one per element.
_T_VARIANT_COUNT = re.compile(r"^count\(((?:ram:\w+/)*)(ram:\w+)\[(.*)\]\) ?<= ?1$")
_T_ATTR = re.compile(r"^@(\w+)$")
_T_NOT_ATTR = re.compile(r"^not ?\(@(\w+)\)$")
_T_NOT_CHILD_ATTR = re.compile(rf"^not ?\(({RELPATH})/@(\w+)\)$")
_T_COND_COUNT = re.compile(rf"^not ?\(({RELPATH})\) or \(count\(({RELPATH})\) ?= ?1\)$")
_T_COND_ATTR = re.compile(rf"^not ?\(({RELPATH})\) or \(({RELPATH})/@(\w+)\)$")
_T_EXCLUSIVE = re.compile(
    rf"^\(not ?\(({RELPATH})/((?:ram):\w+)\) and \1/((?:ram):\w+)\) or \(\1/\2 and not ?\(\1/\3\)\) "
    rf"or \(not ?\(\1/\2\) and not ?\(\1/\3\)\)$"
)
_T_NOT_OR = re.compile(rf"^not ?\(({RELPATH})\) or (.+)$")
# One of several elements with text: `(A,B)[boolean(normalize-space(.))]`.
_T_ANY_WITH_TEXT = re.compile(rf"^\(({RELPATH}(?:, ?{RELPATH})+)\)\[boolean\(normalize-space\(\.\)\)\]$")
_T_LIST = re.compile(
    r"^(?:\(?\(?not\(contains\(normalize-space\((\.|@\w+)\), ' '\)\) and )?"
    r"contains\('((?: [A-Za-z0-9-]+)+) ', concat\(' ', (normalize-space\((?:upper-case\()?(\.|@\w+)\)?\)"
    r"|substring\(\., ?1, ?2\)), ' '\)\)\)?\)?$"
)
_T_CODEDB = re.compile(
    r"^document\('FACTUR-X_[\w-]+_codedb\.xml'\)//cl\[@id=(\d+)\]/enumeration\[@value=\$(codeValue\d+)\]$"
)
_T_ATTR_VALUES = re.compile(r"^\(?(@\w+ = '[^']+'(?: or @\w+ = '[^']+')*)\)?$")
_T_FRACTION = re.compile(rf"^string-length\(substring-after\((\.|{RELPATH}), ?'\.'\)\) ?<= ?2$")
_T_FRACTION_XREF = re.compile(
    r"^not\(ram:TaxTotalAmount\) or ram:TaxTotalAmount\[\(@currencyID ?=/rsm:CrossIndustryInvoice/"
    r"rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:(InvoiceCurrencyCode|TaxCurrencyCode) "
    r"and \. = round\(\. \* 100\) div 100\) or not \(.*\)\]$"
)
_T_DATE_102 = re.compile(
    r"^matches\(\.,'\^\\s\*\(\\d\{4\}\)\(1\[0-2\]\|0\[1-9\]\)\{1\}\(3\[01\]\|\[12\]\[0-9\]\|0\[1-9\]\)\{1\}\\s\*\$'\)$"
)
_T_VALUE = re.compile(rf"^not ?\(({RELPATH})\) or \(\1 ?= ?'(\w+)'\)$")
# One of several literals: `E = 'a' or E = 'b'` (e.g. BR-DE-21 on the
# specification identifier, once its variables are replaced).
_T_ONE_OF = re.compile(rf"^({RELPATH}) ?= ?'([^'\s]+)'$")
_T_INDICATOR = re.compile(
    r"^normalize-space\(ram:ChargeIndicator/udt:Indicator/text\(\)\) = 'true' or "
    r"normalize-space\(ram:ChargeIndicator/udt:Indicator/text\(\)\) = 'false'$"
)
_EMPTY_CONTEXT = re.compile(r"^//\*\[not\(name\(\) = '([\w:]+)'\) and not\(\*\) and not\(normalize-space\(\)\)\]$")
# Tests of the rules of a VAT category, on the tax element or, with `../`,
# from its category code (see `category_check`).
_T_RATE = re.compile(r"^(\.\./)?ram:RateApplicablePercent ?(>|=) ?0$")
_T_NO_RATE = re.compile(r"^not ?\((\.\./)?ram:RateApplicablePercent\)$")
_T_ZERO_AMOUNT = re.compile(r"^(\.\./)?ram:CalculatedAmount ?= ?0$")
_T_PRESENT = re.compile(r"^(\.\./)?(ram:\w+)$")
_T_ABSENT = re.compile(r"^not ?\((\.\./)?(ram:\w+)\)$")
# A rate for every VAT category but one, on a tax element without a condition
# on its category: `(ram:RateApplicablePercent) or (ram:CategoryCode = 'O')`
# (BR-48); the CEN Schematron restricts both sides to VAT.
_VAT_ONLY = r"(\.\[upper-case\(ram:TypeCode\) ?= ?'VAT'\]/)?"
_T_RATE_UNLESS = re.compile(
    rf"^\({_VAT_ONLY}ram:RateApplicablePercent\) or \({_VAT_ONLY}ram:CategoryCode ?= ?'(\w+)'\)$"
)


def category_check(test):
    """The check of a test of a VAT category rule, as (check, value,
    children of the tax element, from its category code): the rate ("r",
    value 1: above 0, 0: zero, None: absent; "any", a rate of any value, comes
    from `resolve_rate_unless`), the VAT amount ("a", 0: zero)
    or the exemption reason ("e", True: `ram:ExemptionReason` or
    `ram:ExemptionReasonCode` is required, False: both are forbidden). None
    for any other test.

    As in XPath, a comparison with 0 needs the element: an absent rate is
    neither above 0 nor zero."""
    test = strip_parens(test)
    m = _T_RATE.match(test)
    if m:
        return "r", 1 if m.group(2) == ">" else 0, m.group(1) is not None
    m = _T_NO_RATE.match(test)
    if m:
        return "r", None, m.group(1) is not None
    m = _T_ZERO_AMOUNT.match(test)
    if m:
        return "a", 0, m.group(1) is not None
    for separator, pattern, value in ((" or ", _T_PRESENT, True), (" and ", _T_ABSENT, False)):
        parts = [pattern.match(strip_parens(p)) for p in split_top(test, separator)]
        if len(parts) != 2 or None in parts:
            continue
        relative = {m.group(1) is not None for m in parts}
        if {m.group(2) for m in parts} == set(EXEMPTION_REASONS) and len(relative) == 1:
            return "e", value, relative.pop()
    return None

# Defects of the official artefacts, with the reading the guard compiles.
# The Schematron of BR-DEC-23 names `ram:SpecifiedTradeSettlement`, which
# does not exist in CII: the rule never fires, and a line net amount (BT-131)
# with three decimals passes. The guard applies the rule to BT-131, which is
# what EN 16931 states.
DEFECTS = {
    "ram:SpecifiedTradeSettlement/ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount": (
        "ram:SpecifiedLineTradeSettlement/ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount"
    ),
}

# The guard's own rule ids the tables name, where no official rule does
# (src/zugferd/guard/report.typ lists every id of the guard).
IP_NOT_USED = "IP-GUARD-05"  # the Factur-X reports that mark an element as not used
IP_DATE = "IP-GUARD-08"  # a date of the format 102 that names no day


def rule_priority(code_list):
    """Order of the rule reported for a code that several lists reject: the
    EN 16931 rule first, then XRechnung, then Factur-X."""
    return {"CEN": 0, "XR": 1, "FX": 2}[code_list.source], code_list.rule


class Compiler:
    """Applies the rules of the validators of one profile to its positions."""

    def __init__(self, profile, schema, rules, known_tags):
        self.profile = profile
        self.schema = schema
        self.rules = rules
        self.known_tags = known_tags  # element names of every Factur-X profile
        self.dispositions = []  # (rule, disposition, detail)
        self.deferred = []  # path constraints resolved after the direct ones
        self.xref_lists = []  # (rule, currency element, list) of the VAT total
        self.vat_types = []  # (rule, tax element) of the category rules for VAT only
        self.rate_unless = []  # (rule, tax element, category) of a rate every other category needs
        self.empty_leaf = None  # the rule that forbids empty leaves, if any
        self.variants = self._variant_values()
        self.root = unfold(schema, self.variants)
        self.positions = list(walk(self.root))
        self.patterns = {}
        self.modes = collections.defaultdict(list)  # (source, mode) -> [(priority, context)]
        for r in rules:
            if r.context not in self.patterns:
                self.patterns[r.context] = None if _EMPTY_CONTEXT.match(r.context) else parse_pattern(r.context)
            key = (r.source, r.mode)
            if (r.priority, r.context) not in self.modes[key]:
                self.modes[key].append((r.priority, r.context))

    # ------------------------------------------------------------ variants

    def _variant_values(self):
        """The discriminator values each family's rules name."""
        values = collections.defaultdict(set)
        family_pred = re.compile(r"(ram:\w+)(?:/(ram:\w+))?\[([^\[\]]*)\]")
        for r in self.rules:
            for text in (r.context, r.test):
                for m in family_pred.finditer(text):
                    first, second, pred = m.groups()
                    cond = value_condition(pred)
                    if cond is None:
                        continue
                    path = tuple(cond[0].split("/"))
                    if second is None and FAMILIES.get(first) == path:
                        values[first] |= cond[1]
                    elif second is not None and FAMILIES.get(second) == path:
                        values[second] |= cond[1]
                    elif second is not None and FAMILIES.get(first) and FAMILIES[first][0] == second:
                        if FAMILIES[first][1:] == path:
                            values[first] |= cond[1]
            m = re.search(r"self::ram:AdditionalReferencedDocument", r.test)
            if m:
                values["ram:AdditionalReferencedDocument"] |= set(re.findall(r"ram:TypeCode ?= ?'(\w+)'", r.test))
        return dict(values)

    # ------------------------------------------------------------ helpers

    def record(self, rule, disposition, detail=""):
        self.dispositions.append((rule, disposition, detail))

    def resolve(self, pos, relpath):
        """The positions a relative path reaches from `pos`: a list of
        (parent position, child tag) for its last step."""
        steps = relpath.split("/")
        bases = [pos]
        while steps and steps[0] == "..":
            bases = [b.parent for b in bases if b.parent is not None]
            steps = steps[1:]
        for tag in steps[:-1]:
            bases = [c for b in bases for c in b.child_positions(tag)]
        return [(b, steps[-1]) for b in bases]

    def targets(self, pos, relpath):
        return [c for b, tag in self.resolve(pos, relpath) for c in b.child_positions(tag)]

    def shadowed(self, rule, pos, conds=()):
        """Whether a rule of higher priority in the same Schematron pattern
        takes `pos`: "yes", "maybe" (only under a condition) or "no". `conds`
        are the rule's own conditions at `pos`: a rule of another VAT
        category of the same tax element never takes it."""
        own = {id(d.data[0]): d.data[1] for _, _, d in conds if d.kind == "category"}
        outcome = "no"
        for priority, context in self.modes[(rule.source, rule.mode)]:
            if priority <= rule.priority or context == rule.context:
                continue
            pattern = self.patterns[context]
            if pattern is None:
                continue
            found = match_pattern(pattern, pos)
            if found is None:
                continue
            if any(
                d.kind == "category" and id(d.data[0]) in own and not (d.data[1] & own[id(d.data[0])])
                for _, _, d in found
            ):
                continue
            if not found:
                return "yes"
            outcome = "maybe"
        return outcome

    # ------------------------------------------------------------ rules

    def compile(self):
        for r in self.rules:
            self.compile_rule(r)
        self.resolve_deferred()
        self.resolve_rate_unless()
        self.check_xref_lists()
        self.check_vat_types()
        return self

    def resolve_rate_unless(self):
        """A rate for every VAT category but one (BR-48): the check "any"
        (a rate is there) in the table of every category the code lists of
        the tax element's category code know, once all lists are compiled.
        A code no list knows fails its code list anyway."""
        for r, tax, excluded in self.rate_unless:
            codes = set()
            for leaf in tax.child_positions("ram:CategoryCode"):
                for code_list in leaf.lists:
                    codes |= code_list.codes
            if not codes:
                raise GenError(f"no code list of the VAT category at {tax.path()}: {r.label()}")
            for code in sorted(codes - {excluded}):
                entry = ("r", "any", r.ref)
                if entry not in tax.categories.setdefault(code, []):
                    tax.categories[code].append(entry)

    def check_vat_types(self):
        """A rule of a VAT category that applies to VAT only
        (`[upper-case(ram:TypeCode) = 'VAT']`) is compiled for every tax
        element of the category. That is exact where the tax type is
        required and its code list is "VAT" alone: an element of another
        type fails that list."""
        for r, tax in self.vat_types:
            leaves = tax.child_positions("ram:TypeCode")
            ref = combine_lists(leaves[0].lists) if len(leaves) == 1 else None
            if ref is None or ref.codes != frozenset({"VAT"}) or effective_min(tax, "ram:TypeCode") < 1:
                raise GenError(f"a rule for VAT at {tax.path()}, whose tax type may be another: {r.label()}")

    def check_xref_lists(self):
        """The list of the VAT total's currency where it equals a currency
        element of the settlement is left to that element's list: they
        must be the same codes of the same validator."""
        for r, ref, code_list in self.xref_lists:
            targets = [
                c for p in self.positions if p.tag == "ram:ApplicableHeaderTradeSettlement"
                for c in p.child_positions("ram:" + ref)
            ]
            same = [
                t for t in targets
                if any(cl.codes == code_list.codes and cl.source == code_list.source for cl in t.lists)
            ]
            if not targets or same != targets:
                raise GenError(f"the currency list of the VAT total differs from the list of ram:{ref}: {r.label()}")

    def compile_rule(self, r):
        test = strip_parens(r.test)
        if r.kind == "assert" and test == "true()":
            return self.record(r, "tautology")
        empty = _EMPTY_CONTEXT.match(r.context)
        if empty:
            if test != "false()":
                raise GenError(f"unsupported test of an empty-element rule: {r.label()}")
            for pos in self.positions:
                if pos.tag != empty.group(1):
                    if pos.leaf:
                        self.empty_leaf = r.ref
                    else:
                        pos.no_empty = r.ref
                elif pos.leaf:
                    raise GenError(f"an empty-element rule that excepts the leaf {pos.tag}: {r.label()}")
            return self.record(r, "compiled", "no empty element")
        pattern = self.patterns[r.context]
        matched, maybe = [], []
        business = shadowed = None
        for pos in self.positions:
            found = match_pattern(pattern, pos)
            if found is None:
                continue
            kinds = {d.kind for _, _, d in found}
            if "business" in kinds:
                business = next(d.data for _, _, d in found if d.kind == "business")
                continue
            if "vat" in kinds and "category" not in kinds:
                business = "on the tax type"
                continue
            if r.source in ("CEN", "XR"):
                # Within a Schematron pattern, only the rule of the highest
                # priority whose context matches fires on an element. When
                # that rule only matches under a condition on values, this
                # rule is applied anyway: stricter, and what the rule says.
                state = self.shadowed(r, pos, found)
                if state == "yes":
                    shadowed = pos
                    continue
                if state == "maybe":
                    maybe.append(pos)
            matched.append((pos, found))
        if not matched:
            if business is not None:
                return self.record(r, "business", f"condition {business}")
            if shadowed is not None:
                return self.record(r, "shadowed", "a rule of higher priority takes every position")
            return self.record(r, "unmatched", "no position of the profile")
        if any(d.kind == "category" for _, conds in matched for _, _, d in conds):
            applied = self.apply_category(r, test, matched)
            if applied is None:
                return self.record(r, "business", "a rule of a VAT category on sums or other elements")
        else:
            applied = self.apply_test(r, test, matched)
            if applied is None:
                applied = self.apply_presence(r, test, matched)
        if applied is None:
            return self.record(r, "business", "test")
        for pos in maybe:
            self.record(r, "conservative", f"{pos.path()}: a rule of higher priority may take it")
        return self.record(r, "compiled", applied)

    def apply_category(self, r, test, matched):
        """A rule of a VAT category (see TAX_ELEMENTS): its check joins the
        table of the category at every matched tax element. None when the
        test is no check of the element's own rate, VAT amount or exemption
        reason (a business rule)."""
        check = category_check(test)
        if check is None:
            return None
        kind, value, relative = check
        targets = {"r": ("ram:RateApplicablePercent",), "a": ("ram:CalculatedAmount",), "e": EXEMPTION_REASONS}[kind]
        plans = []
        for pos, conds in matched:
            categories = [d for _, _, d in conds if d.kind == "category"]
            others = [d for _, _, d in conds if d.kind not in ("category", "vat")]
            if len(categories) != 1 or others:
                raise GenError(f"unsupported conditions {conds} of a rule of a VAT category: {r.label()}")
            tax, codes = categories[0].data
            if any(d.data is not tax for _, _, d in conds if d.kind == "vat"):
                raise GenError(f"a restriction to VAT of another element: {r.label()}")
            # From the category code, the test names the tax element's
            # children with `../`; from the tax element, without.
            if relative != (pos is not tax):
                raise GenError(f"a rule of a VAT category on other elements than its tax element's: {r.label()}")
            tags = {p.tag for p in tax.type.children}
            if not set(targets) <= tags:
                raise GenError(f"{tax.path()} has no {', '.join(targets)}: {r.label()}")
            if any(d.kind == "vat" for _, _, d in conds):
                self.vat_types.append((r, tax))
            plans.append((tax, codes))
        for tax, codes in plans:
            for code in sorted(codes):
                entry = (kind, value, r.ref)
                if entry not in tax.categories.setdefault(code, []):
                    tax.categories[code].append(entry)
        what = {
            ("r", 1): "a rate above 0", ("r", 0): "the rate 0", ("r", None): "no rate",
            ("a", 0): "the VAT amount 0", ("e", True): "an exemption reason", ("e", False): "no exemption reason",
        }[(kind, value)]
        return f"VAT category {', '.join(sorted(set().union(*(c for _, c in plans))))}: {what}"

    def apply_test(self, r, test, matched):
        """Compiles the test at every matched position; None for a test that
        is no structural, code list or lexical constraint."""
        if r.kind == "report":
            if test != "true()" or r.source != "FX":
                raise GenError(f"unsupported report: {r.label()}")
            for pos, conds in matched:
                attr = [d.data[0] for i, p, d in conds if d.kind == "attr" and p is pos]
                others = [d for i, p, d in conds if not (d.kind == "attr" and p is pos)]
                if attr:
                    if others or len(attr) != 1 or not r.text.startswith(f"Attribute @{attr[0]}"):
                        raise GenError(f"unsupported report of an attribute: {r.label()}")
                    pos.attrs[attr[0]].forbidden = IP_NOT_USED
                elif [d for d in others if d.kind == "xref"]:
                    self.xref(pos, others, "other", IP_NOT_USED)
                elif others:
                    raise GenError(f"unsupported condition of a report: {r.label()}")
                else:
                    pos.forbidden = (IP_NOT_USED, r.text)
            return "not used"
        # Conditions on the context itself: attributes and cross references.
        plain, conditional = [], []
        for pos, conds in matched:
            (conditional if conds else plain).append((pos, conds))
        rule = r.ref
        m = _T_RATE_UNLESS.match(test)
        if m:
            if m.group(1) != m.group(2):
                raise GenError(f"a restriction to VAT of one side only: {r.label()}")
            for pos, conds in matched:
                if pos.tag not in TAX_ELEMENTS or conds:
                    raise GenError(f"a rate rule of VAT categories at {pos.path()}: {r.label()}")
                if m.group(1):
                    self.vat_types.append((r, pos))
                self.rate_unless.append((r, pos, m.group(3)))
            return f"VAT categories other than {m.group(3)}: a rate"
        m = _T_DATE_102.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds, allowed={("format", "102")})
                pos.date = rule
            return "date format 102"
        m = _T_LIST.match(test)
        if m:
            target = m.group(4) or "."
            if m.group(1) and m.group(1) != target:
                raise GenError(f"unsupported code list test: {r.label()}")
            codes = frozenset(m.group(2).split())
            prefix = m.group(3).startswith("substring")
            casefold = "upper-case(" in m.group(3)
            for pos, conds in matched:
                self.add_list(r, pos, conds, target, CodeList(codes, rule, r.source, casefold, r.newest), prefix)
            return "prefix list" if prefix else f"code list of {target}"
        m = _T_CODEDB.match(test)
        if m:
            target = r.variables.get(m.group(2))
            if target not in (".",) and not re.fullmatch(r"@\w+", target or ""):
                raise GenError(f"unsupported code database target {target}: {r.label()}")
            codes = r.codedb.get(m.group(1))
            if not codes:
                raise GenError(f"unknown code list {m.group(1)}: {r.label()}")
            for pos, conds in matched:
                self.add_list(r, pos, conds, target, CodeList(codes, rule, r.source), False)
            return f"code list of {target}"
        m = _T_ATTR_VALUES.match(test)
        if m:
            pairs = re.findall(r"@(\w+) = '([^']+)'", m.group(1))
            names = sorted({a for a, _ in pairs})
            if len(names) != 1:
                raise GenError(f"unsupported attribute list: {r.label()}")
            codes = frozenset(v for _, v in pairs)
            for pos, conds in matched:
                self.add_list(r, pos, conds, "@" + names[0], CodeList(codes, rule, r.source, newest=r.newest), False)
            return f"code list of @{names[0]}"
        m = _T_INDICATOR.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                for leaf in self.targets(pos, "ram:ChargeIndicator/udt:Indicator"):
                    leaf.lists.append(CodeList(frozenset({"true", "false"}), rule, r.source))
            return "indicator values"
        m = _T_VALUE.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                for leaf in self.targets(pos, m.group(1)):
                    leaf.lists.append(CodeList(frozenset({m.group(2)}), rule, r.source))
            return f"value of {m.group(1)}"
        one_of = [_T_ONE_OF.match(strip_parens(d)) for d in split_top(test, " or ")]
        if len(one_of) > 1 and all(one_of) and len({o.group(1) for o in one_of}) == 1:
            path = one_of[0].group(1)
            codes = frozenset(o.group(2) for o in one_of)
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                leaves = self.targets(pos, path)
                if any(not leaf.leaf for leaf in leaves):
                    raise GenError(f"a value list of a complex element {path}: {r.label()}")
                for leaf in leaves:
                    leaf.lists.append(CodeList(codes, rule, r.source))
            return f"one of the values of {path}"
        m = _T_FRACTION.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                self.add_fraction(r, pos, m.group(1), lexical=True)
            return "decimals"
        m = _T_FRACTION_XREF.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                for leaf in self.targets(pos, "ram:TaxTotalAmount"):
                    leaf.fraction.append((2, False, rule))
            return "decimals of the VAT total"
        m = _T_REQUIRED.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds, xref=True)
                self.require(pos, m.group(1), r)
            return f"requires {m.group(1)}"
        m = _T_FORBIDDEN.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                for parent, tag in self.resolve(pos, m.group(1)):
                    parent.cmax.setdefault(tag, []).append((0, rule))
            return f"forbids {m.group(1)}"
        m = _T_COUNT.match(test)
        if m:
            path, op = m.group(1), m.group(2)
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                if op in ("=", ">="):
                    self.require(pos, path, r)
                if op in ("=", "<="):
                    self.limit(pos, path, r)
            return f"count({path}) {op} 1"
        m = _T_VARIANT_COUNT.match(test)
        if m:
            steps, tag, pred = m.group(1).rstrip("/"), m.group(2), m.group(3)
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                bases = [pos]
                for step in steps.split("/") if steps else []:
                    if any(effective_max(b, step) not in (0, 1) for b in bases):
                        raise GenError(f"a count through {step}, which may occur more than once: {r.label()}")
                    bases = [c for b in bases for c in b.child_positions(step)]
                for base in bases:
                    self.variant_limit(r, base, tag, pred)
            return f"count({m.group(1)}{tag}[...]) <= 1"
        m = _T_ATTR.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds, xref=True)
                self.require_attr(r, pos, m.group(1))
            return f"requires @{m.group(1)}"
        m = _T_NOT_ATTR.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                self.forbid_attr(r, pos, m.group(1))
            return f"forbids @{m.group(1)}"
        m = _T_NOT_CHILD_ATTR.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                for leaf in self.targets(pos, m.group(1)):
                    self.forbid_attr(r, leaf, m.group(2))
            return f"forbids {m.group(1)}/@{m.group(2)}"
        m = _T_COND_COUNT.match(test)
        if m:
            guard, counted = m.group(1), m.group(2)
            if not counted.startswith(guard + "/") or "/" in counted[len(guard) + 1:]:
                raise GenError(f"unsupported conditional count: {r.label()}")
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                for child in self.targets(pos, guard):
                    self.deferred.append(("single", pos, guard, r))
                    tag = counted[len(guard) + 1:]
                    child.cmin.setdefault(tag, []).append((1, rule))
                    child.cmax.setdefault(tag, []).append((1, rule))
            return f"if {guard}: count({counted}) = 1"
        m = _T_COND_ATTR.match(test)
        if m:
            if m.group(1) != m.group(2):
                raise GenError(f"unsupported conditional attribute: {r.label()}")
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                self.deferred.append(("single", pos, m.group(1), r))
                for leaf in self.targets(pos, m.group(1)):
                    self.require_attr(r, leaf, m.group(3))
            return f"if {m.group(1)}: requires @{m.group(3)}"
        m = _T_EXCLUSIVE.match(test)
        if m:
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                self.deferred.append(("single", pos, m.group(1), r))
                for child in self.targets(pos, m.group(1)):
                    child.exclusive.append(((m.group(2), m.group(3)), rule))
            return f"{m.group(1)}: {m.group(2)} or {m.group(3)}, not both"
        disjuncts = [strip_parens(d) for d in split_top(test, " or ")]
        if len(disjuncts) > 1 and all(_T_REQUIRED.match(d) for d in disjuncts):
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                self.any_of(r, pos, disjuncts)
            return "requires one of " + ", ".join(disjuncts)
        m = _T_ANY_WITH_TEXT.match(test)
        if m:
            alternatives = [p.strip() for p in m.group(1).split(",")]
            for pos, conds in matched:
                self.expect_conditions(r, pos, conds)
                self.any_of(r, pos, alternatives)
            return "requires one of " + ", ".join(alternatives) + " with text"
        m = _T_NOT_OR.match(test)
        if m:
            outcomes = []
            for pos, conds in matched:
                outcome = self.static_condition(m.group(2), pos)
                if outcome is None:
                    return None
                outcomes.append((pos, conds, outcome))
            for pos, conds, outcome in outcomes:
                self.expect_conditions(r, pos, conds)
                if outcome == FALSE:
                    for parent, tag in self.resolve(pos, m.group(1)):
                        parent.cmax.setdefault(tag, []).append((0, rule))
            return f"forbids {m.group(1)} unless {m.group(2)}"
        return None

    # ------------------------------------------------------------ presence

    def apply_presence(self, r, test, matched):
        """Presence rules: an element or attribute must exist (`E`,
        `E != ''`, `normalize-space(E) != ''`,
        `E[boolean(normalize-space(.))]`), must exist when another one does
        (`E or not(F)`, `(F and E) or not(F)`), or one of several children
        must exist. The writer treats a required leaf without text as
        missing (a "blank" finding of its checked writer, see
        src/zugferd/guard/rare.typ), so "exists" and "is not empty" are the
        same for what it accepts. None when the test is anything else."""
        disjuncts = [strip_parens(d) for d in split_top(test, " or ")]
        plans = []
        for pos, conds in matched:
            if conds:
                return None
            if len(disjuncts) == 1:
                atom = presence_atom(disjuncts[0])
                plan = atom and self.plan_require(pos, atom, r)
                label = "requires " + disjuncts[0]
            elif len(disjuncts) == 2:
                negated = [d for d in disjuncts if re.match(r"^not ?\(", d)]
                if len(negated) != 1:
                    return None
                condition = parse_location(strip_parens(negated[0][negated[0].index("("):]))
                other = next(d for d in disjuncts if d is not negated[0])
                parts = [strip_parens(p) for p in split_top(other, " and ")]
                atoms = [presence_atom(p) for p in parts]
                if condition is None or None in atoms:
                    return None
                # `(F and E) or not(F)`: F holds wherever the rule matters.
                atoms = [a for a in atoms if a[0] != condition]
                if len(atoms) != 1:
                    return None
                plan = self.plan_conditional(pos, condition, atoms[0], r)
                label = f"requires {other} if {negated[0][4:].strip()}"
            else:
                return None
            if plan is None:
                return None
            plans.append(plan)
        for plan in plans:
            for action in plan:
                action()
        return label

    def walk_location(self, pos, location, r):
        """(positions, actions, complete): the positions a location path
        reaches from `pos` and the actions that require every step of it.
        A step that may occur more than once ends the walk when every
        further step is required anyway ("some A with a B" is "some A" when
        every A has a B); `complete` is then False. None when that does not
        hold, or for a predicate other than a variant, `[1]` of an element
        that occurs at most once, or an attribute value of the last leaf."""
        absolute, steps, attr = location
        steps = lift_family_predicates(steps)
        actions = []
        complete = True
        if absolute == "//":
            # From the root: the first step may be anywhere, but it must be at
            # a single position whose ancestors occur at most once.
            if pos.parent is not None:
                return None
            found = [p for p in walk(pos) if p.tag == steps[0][0] and p is not pos]
            parents = {id(p.parent): p.parent for p in found}
            if len(parents) != 1:
                return None
            parent = next(iter(parents.values()))
            chain = [parent] + list(parent.ancestors())[:-1]  # below the root
            for p in reversed(chain):
                if p.parent is None:
                    continue
                if effective_max(p.parent, p.tag) not in (0, 1):
                    return None
                if effective_min(p.parent, p.tag) < 1:
                    actions.append(self.require_action(p.parent, p.tag, None, r))
            level = [parent]
        elif absolute == "/":
            if pos.parent is not None or not steps or steps[0][0] != pos.tag:
                return None
            level, steps = [pos], steps[1:]
        else:
            level = [pos]
        for i, (name, preds) in enumerate(steps):
            last = i == len(steps) - 1
            if name == "..":
                level = [p.parent for p in level if p.parent is not None]
                continue
            nxt = []
            for parent in level:
                children = parent.child_positions(name)
                chosen, first, values = None, False, []
                for pred in preds:
                    if isinstance(pred, tuple):
                        _, names, negated = pred
                        if not children or any(c.variant is None for c in children):
                            return None
                        selected = {c.variant for c in children if (c.variant != OTHER and c.variant in names) != negated}
                        chosen = selected if chosen is None else chosen & selected
                    elif pred == "1":
                        first = True
                    elif last and attr is None and re.fullmatch(r"@\w+ ?= ?'[^']*'", pred):
                        values.append(re.fullmatch(r"@(\w+) ?= ?'([^']*)'", pred).groups())
                    else:
                        return None
                if chosen is not None and len(chosen) != 1:
                    return None
                selected = [c for c in children if chosen is None or c.variant in chosen]
                high = self.multiplicity(parent, name, chosen)
                if first and high not in (0, 1):
                    return None
                if not last and high not in (0, 1):
                    if values or not self.guaranteed(selected, steps[i + 1:], attr):
                        return None
                    actions.append(self.require_action(parent, name, chosen, r))
                    complete = False
                    continue
                # An intermediate element the schema requires anyway keeps
                # its own finding; the rule is about the last step.
                if last or chosen is not None or effective_min(parent, name) < 1:
                    actions.append(self.require_action(parent, name, chosen, r))
                for leaf in selected:
                    for a, v in values:
                        if not leaf.leaf or a not in leaf.attrs:
                            return None
                        actions.append(self.attr_value_action(leaf, a, v, r))
                nxt += selected
            level = nxt
        if attr is not None:
            for leaf in level:
                if not leaf.leaf or attr not in leaf.attrs:
                    return None
                actions.append(self.attr_action(leaf, attr, r))
        return level, actions, complete

    def multiplicity(self, parent, tag, variants):
        """How often an element (of the given variants) may occur."""
        high = effective_max(parent, tag)
        if variants is None:
            return high
        limits = parent.vmax.get(tag, {})
        bounds = [min(v for v, _ in limits[v]) if v in limits else high for v in variants]
        if UNBOUNDED in bounds:
            return high
        return sum(bounds) if high == UNBOUNDED else min(high, sum(bounds))

    def guaranteed(self, positions, steps, attr):
        """Whether every element of `positions` has the further steps."""
        if attr is not None:
            return False
        for name, preds in steps:
            if name == ".." or preds:
                return False
            nxt = []
            for p in positions:
                if effective_min(p, name) < 1:
                    return False
                nxt += p.child_positions(name)
            positions = nxt
        return True

    def require_action(self, parent, tag, variants, r):
        def act():
            if variants is None:
                parent.cmin.setdefault(tag, []).append((1, r.ref))
            else:
                if len(variants) != 1:
                    raise GenError(f"a requirement of several variants: {r.label()}")
                parent.vmin.setdefault(tag, {}).setdefault(next(iter(variants)), []).append((1, r.ref))

        return act

    def attr_action(self, leaf, name, r):
        def act():
            leaf.attrs[name].required = r.ref

        return act

    def attr_value_action(self, leaf, name, value, r):
        def act():
            leaf.attrs[name].required = r.ref
            leaf.attrs[name].lists.append(CodeList(frozenset({value}), r.ref, r.source))

        return act

    def plan_require(self, pos, atom, r):
        location, _ = atom
        walked = self.walk_location(pos, location, r)
        return None if walked is None else walked[1]

    def plan_conditional(self, pos, condition, atom, r):
        """`E or not(F)`: E is F followed by more steps, required in F."""
        location, _ = atom
        c_abs, c_steps, c_attr = condition
        e_abs, e_steps, e_attr = location
        if c_attr is not None or c_abs != e_abs:
            return None
        plain = [(n, [p for p in preds if p != "1"]) for n, preds in e_steps]
        if plain[: len(c_steps)] != c_steps or (len(e_steps) == len(c_steps) and e_attr is None):
            return None
        walked = self.walk_location(pos, condition, r)
        if walked is None or not walked[2]:
            return None
        bases = walked[0]  # F itself is not required
        actions = []
        suffix = (None, e_steps[len(c_steps):], e_attr)
        for base in bases:
            if effective_max(base.parent, base.tag) not in (0, 1):
                return None
            inner = self.walk_location(base, suffix, r)
            if inner is None:
                return None
            actions += inner[1]
        return actions

    def expect_conditions(self, r, pos, conds, allowed=(), xref=False):
        """Fails unless every dynamic condition is one the check itself
        honours: an attribute (value) the leaf check reads, or a cross
        reference of the VAT total (`xref`), which the guard checks
        separately."""
        for i, p, d in conds:
            if d.kind == "attr" and p is pos and (d.data in allowed or (d.data[0], None) in allowed):
                continue
            if d.kind == "xref" and xref:
                continue
            raise GenError(f"unsupported condition {d} at {pos.path()}: {r.label()}")

    def static_condition(self, expr, pos):
        """TRUE or FALSE of the right side of `not(x) or (...)` at `pos`
        (self::, ancestor:: and the family discriminator); None when it is a
        condition on values."""
        expr = strip_parens(expr)
        disj = split_top(expr, " or ")
        if len(disj) > 1:
            outcomes = [self.static_condition(d, pos) for d in disj]
            if TRUE in outcomes:
                return TRUE
            return None if None in outcomes else FALSE
        conj = split_top(expr, " and ")
        if len(conj) > 1:
            outcomes = [self.static_condition(c, pos) for c in conj]
            if FALSE in outcomes:
                return FALSE
            return None if None in outcomes else TRUE
        m = re.fullmatch(r"self::([\w:]+)", expr)
        if m:
            return TRUE if pos.tag == m.group(1) else FALSE
        m = re.fullmatch(r"ancestor::([\w:]+)", expr)
        if m:
            return TRUE if m.group(1) in {a.tag for a in pos.ancestors()} else FALSE
        fam = family_values(expr, pos)
        if fam is not None:
            owner, values, negated = fam
            if owner.variant is None:
                return None
            return TRUE if (owner.variant != OTHER and owner.variant in values) != negated else FALSE
        m = re.fullmatch(r"ram:TypeCode ?= ?'(\w+)'", expr)
        if m and pos.tag not in FAMILIES:
            return None
        return None

    def add_list(self, r, pos, conds, target, code_list, prefix):
        xrefs = [d for i, p, d in conds if d.kind == "xref"]
        if xrefs:
            # The list of the VAT total's currency where it is the invoice
            # (or VAT accounting) currency: then the list of that element
            # checks the same value (`check_xref_lists` makes sure it is the
            # same list), and another currency is a cross reference check.
            refs, negated = xrefs[0].data
            others = [
                d for i, p, d in conds
                if d.kind != "xref" and not (d.kind == "attr" and p is pos and d.data == ("currencyID", None))
            ]
            if len(xrefs) > 1 or negated or target != "@currencyID" or others:
                raise GenError(f"unsupported condition of a code list at {pos.path()}: {r.label()}")
            self.xref_lists.append((r, refs, code_list))
            return
        condition = None
        for i, p, d in conds:
            if d.kind == "attr" and p is pos:
                name, value = d.data
                if value is None and "@" + name == target:
                    continue  # [@a] with a test on @a: checked when present
                if value is not None and target == ".":
                    condition = (name, value)
                    continue
            raise GenError(f"unsupported condition {d} of a code list at {pos.path()}: {r.label()}")
        if not pos.leaf:
            raise GenError(f"code list on complex element {pos.path()}: {r.label()}")
        if target == ".":
            if prefix:
                if pos.prefix_when not in (None, condition):
                    raise GenError(f"two conditions of prefix lists at {pos.path()}")
                pos.prefix_when = condition
                pos.prefix.append(code_list)
            elif condition is not None:
                raise GenError(f"conditional code list at {pos.path()}: {r.label()}")
            else:
                pos.lists.append(code_list)
        else:
            name = target[1:]
            if name not in pos.attrs:
                return  # the XSD does not allow the attribute here: nothing to check
            pos.attrs[name].lists.append(code_list)

    def add_fraction(self, r, pos, path, lexical):
        if path == ".":
            leaves = [pos]
        else:
            leaves = self.targets(pos, path)
            if not leaves and path in DEFECTS:
                leaves = self.targets(pos, DEFECTS[path])
                self.record(r, "defect", f"{path} read as {DEFECTS[path]}")
            elif not leaves and not set(path.split("/")) <= self.known_tags:
                raise GenError(f"{path} is no element of any Factur-X profile: {r.label()}")
        for leaf in leaves:
            if not leaf.leaf or leaf.type.base != "decimal":
                raise GenError(f"decimals of a non-decimal element {leaf.path()}: {r.label()}")
            leaf.fraction.append((2, lexical, r.ref))

    def require(self, pos, path, r):
        steps = path.split("/")
        if steps[0] == "..":
            if any(s == ".." for s in steps[1:]) or len([s for s in steps if s != ".."]) != 1:
                raise GenError(f"unsupported path {path}: {r.label()}")
            for parent, tag in self.resolve(pos, path):
                parent.cmin.setdefault(tag, []).append((1, r.ref))
        elif len(steps) == 1:
            pos.cmin.setdefault(path, []).append((1, r.ref))
        else:
            self.deferred.append(("min", pos, path, r))

    def limit(self, pos, path, r):
        steps = path.split("/")
        if ".." in steps:
            raise GenError(f"unsupported path {path}: {r.label()}")
        if len(steps) == 1:
            pos.cmax.setdefault(path, []).append((1, r.ref))
        else:
            self.deferred.append(("max", pos, path, r))

    def variant_limit(self, r, pos, tag, pred):
        for child in pos.child_positions(tag):
            fam = family_values(pred, child)
            if fam is None:
                xref = eval_predicate(pred, child)
                if isinstance(xref, Dynamic) and xref.kind == "xref":
                    self.xref(child, [xref], "count", r.ref)
                    continue
                raise GenError(f"unsupported variant count: {r.label()}")
            owner, values, negated = fam
            if owner is not child or child.variant is None:
                raise GenError(f"variant count without variants at {child.path()}: {r.label()}")
            if (child.variant != OTHER and child.variant in values) != negated:
                pos.vmax.setdefault(tag, {}).setdefault(child.variant, []).append((1, r.ref))

    def require_attr(self, r, pos, name):
        if not pos.leaf or name not in pos.attrs:
            raise GenError(f"required attribute @{name} that the XSD does not allow at {pos.path()}: {r.label()}")
        pos.attrs[name].required = r.ref

    def forbid_attr(self, r, pos, name):
        if pos.leaf and name in pos.attrs:
            pos.attrs[name].forbidden = r.ref

    def any_of(self, r, pos, paths):
        tags = []
        for path in paths:
            resolved = self.resolve(pos, path)
            if len(resolved) != 1 or "/" in path.replace("../", ""):
                raise GenError(f"unsupported alternative requirement: {r.label()}")
            parent, tag = resolved[0]
            tags.append(tag)
        parents = {id(p) for path in paths for p, _ in self.resolve(pos, path)}
        if len(parents) != 1:
            raise GenError(f"alternatives with different parents: {r.label()}")
        self.resolve(pos, paths[0])[0][0].anyof.append((tuple(tags), r.ref))

    def xref(self, pos, conds, kind, rule):
        """Cross references of the VAT total amount (BT-110, BT-111): the
        variant of a `ram:TaxTotalAmount` is decided by comparing its
        currency with the currency codes of the settlement."""
        if pos.tag != "ram:TaxTotalAmount" or pos.parent.tag != "ram:SpecifiedTradeSettlementHeaderMonetarySummation":
            raise GenError(f"cross reference outside of the VAT total: {pos.path()}")
        settlement = pos.parent.parent
        for d in conds:
            refs, negated = d.data
            refs = refs if isinstance(refs, tuple) else (refs,)
            if kind == "other" and not negated:
                raise GenError("a report of a named currency variant")
            if kind == "count" and negated:
                raise GenError("a count of the other currency variant")
            entry = (kind, tuple(sorted(refs)), rule)
            if entry not in settlement.xref:
                settlement.xref.append(entry)

    def resolve_deferred(self):
        """Path constraints: exact per parent when every intermediate element
        occurs at most once, else a count over the whole path."""
        for kind, pos, path, r in self.deferred:
            if kind == "single":
                # The constraint was compiled per element of `path`, which
                # is exact only when it occurs at most once.
                for parent, tag in self.resolve(pos, path):
                    if effective_max(parent, tag) not in (0, 1):
                        raise GenError(f"{path} may occur more than once below {pos.path()}: {r.label()}")
                continue
            steps = path.split("/")
            single = True
            level = [pos]
            for tag in steps[:-1]:
                if any(effective_max(p, tag) not in (0, 1) for p in level):
                    single = False
                level = [c for p in level for c in p.child_positions(tag)]
            if single:
                level = [pos]
                for tag in steps[:-1]:
                    if kind == "min":
                        for p in level:
                            p.cmin.setdefault(tag, []).append((1, r.ref))
                    level = [c for p in level for c in p.child_positions(tag)]
                for p in level:
                    target = p.cmin if kind == "min" else p.cmax
                    target.setdefault(steps[-1], []).append((1, r.ref))
            else:
                low, high = (1, UNBOUNDED) if kind == "min" else (0, 1)
                pos.aggregates.append((tuple(steps), low, high, r.ref))


def lift_family_predicates(steps):
    """Steps with every predicate on a family discriminator as a tuple
    ("family", values, negated) on the family element's step, including a
    predicate on the discriminator's first step (`ram:ID[@schemeID='VA']`
    below `ram:SpecifiedTaxRegistration`)."""
    lifted = [[] for _ in steps]
    for i, (name, preds) in enumerate(steps):
        disc = FAMILIES.get(name)
        parent_disc = FAMILIES.get(steps[i - 1][0]) if i > 0 else None
        for pred in preds:
            cond = value_condition(pred)
            path = tuple(cond[0].split("/")) if cond else None
            if disc and path == disc:
                lifted[i].append(("family", cond[1], cond[2]))
            elif parent_disc and parent_disc[0] == name and path == parent_disc[1:]:
                lifted[i - 1].append(("family", cond[1], cond[2]))
            else:
                lifted[i].append(pred)
    return [(name, lifted[i]) for i, (name, _) in enumerate(steps)]


def effective_min(pos, tag):
    particles = [p for p in pos.type.children if p.tag == tag]
    low = particles[0].min if particles else 0
    for value, _ in pos.cmin.get(tag, []):
        low = max(low, value)
    return low


def effective_max(pos, tag):
    particles = [p for p in pos.type.children if p.tag == tag]
    if not particles:
        return 0
    high = particles[0].max
    for value, _ in pos.cmax.get(tag, []):
        high = value if high == UNBOUNDED else min(high, value)
    instances = pos.child_positions(tag)
    if instances and all(c.forbidden for c in instances):
        return 0
    return high


# ================================================================ nodes


def rule_rank(rule):
    """Which of several rules stating the same constraint a diagnostic names:
    the EN 16931 business rule, then the syntax binding rules and XRechnung,
    then Factur-X, then the guard's own ids; ties by name."""
    if rule is None:
        return (9, "")
    for rank, prefix in enumerate(("BR-", "CII-", "PEPPOL-", "FX-", "IP-")):
        if rule.startswith(prefix):
            return (rank, rule)
    return (8, rule)


def best_rule(rules):
    rules = [r for r in rules if r is not None]
    return min(rules, key=rule_rank) if rules else None


def category_table(pos):
    """The VAT category rules of a tax element as ((category, ((check,
    value, rule), ...)), ...), sorted: one value per check, and of the rules
    that state it, the one a diagnostic names. Two validators that want
    different values of one check fail: no element of the category could be
    valid."""
    table = []
    for code in sorted(pos.categories):
        by_check = collections.defaultdict(dict)
        for check, value, rule in pos.categories[code]:
            by_check[check].setdefault(value, []).append(rule)
        entries = []
        for check in sorted(by_check):
            # A rate above 0 or of 0 is a rate: it takes the place of "any".
            if "any" in by_check[check] and {0, 1} & set(by_check[check]):
                del by_check[check]["any"]
            if len(by_check[check]) != 1:
                raise GenError(f"contradicting rules of the VAT category {code} at {pos.path()}: {dict(by_check)}")
            [(value, rules)] = by_check[check].items()
            entries.append((check, value, best_rule(rules)))
        table.append((code, tuple(entries)))
    return tuple(table)


@dataclasses.dataclass(frozen=True)
class ListRef:
    """A code list at a position: the intersection of every list that
    applies, the rule reported for a code outside of it, and the rule of
    another list for the codes only that list rejects."""

    codes: frozenset
    rule: str
    exceptions: tuple  # ((code, rule), ...)
    casefold: bool


def combine_lists(code_lists):
    """One ListRef for the lists of every validator at a position."""
    if not code_lists:
        return None
    # The list of the newest CEN Schematron comes after the list of the same
    # rule it narrows, which stays the primary list.
    ordered = sorted(code_lists, key=lambda c: (rule_priority(c), c.newest, sorted(c.codes)))
    primary = ordered[0]
    # A list compared in upper case only counts as such when all are.
    casefold = all(c.casefold for c in code_lists)
    codes = frozenset.intersection(*(c.codes for c in code_lists))
    exceptions = {}
    for c in ordered[1:]:
        # Two versions of a list of one rule (CEN 1.3.12 and 1.3.16) name the
        # primary's rule, which a code outside of `codes` gets anyway.
        if c.rule == primary.rule:
            continue
        for code in sorted(primary.codes - c.codes):
            if code not in codes and code not in exceptions:
                exceptions[code] = c.rule
    if primary.rule is None:
        raise GenError("a code list without a rule")
    return ListRef(codes, primary.rule, tuple(sorted(exceptions.items())), casefold)


class Nodes:
    """Hash-consed nodes of one profile: positions with equal constraints
    share one node. Keys are nested tuples; ids follow a depth-first walk
    from the root, so the output is stable."""

    def __init__(self, compiler, emitted):
        self.compiler = compiler
        self.emitted = emitted  # element names the builder can write
        self.keys = {}  # id(pos) -> key
        self.order = []  # keys, by node id
        self.ids = {}  # key -> id
        self.positions = collections.defaultdict(list)  # key -> positions
        self.omitted = 0  # child elements of the schema the builder never writes
        root_key = self.key(compiler.root)
        self.number(root_key)

    # ------------------------------------------------------------ keys

    def key(self, pos):
        cached = self.keys.get(id(pos))
        if cached is not None:
            return cached
        k = self.leaf_key(pos) if pos.leaf else self.complex_key(pos)
        self.keys[id(pos)] = k
        self.positions[k].append(pos)
        return k

    def leaf_key(self, pos):
        base = {"decimal": "d", "boolean": "b", "base64Binary": "x"}.get(pos.type.base, "s")
        attrs = []
        for name in sorted(pos.attrs):
            a = pos.attrs[name]
            attrs.append((name, a.required, a.forbidden, combine_lists(a.lists)))
        fraction = None
        if pos.fraction:
            digits = min(f[0] for f in pos.fraction)
            lexical = any(f[1] for f in pos.fraction)
            fraction = (digits, lexical, best_rule(f[2] for f in pos.fraction if f[0] == digits and f[1] == lexical))
        date = None
        if pos.tag.endswith(":DateTimeString") and "format" in pos.attrs:
            date = pos.date or IP_DATE
        elif pos.date:
            raise GenError(f"a date check of {pos.path()}, which has no format attribute")
        prefix = None
        if pos.prefix:
            prefix = (combine_lists(pos.prefix), pos.prefix_when)
        return ("L", base, tuple(attrs), combine_lists(pos.lists), prefix, fraction, date)

    def complex_key(self, pos):
        children = []
        # The VAT category rules of tax elements among the children: they
        # belong to the parent's node, so that the node of the tax element
        # itself stays one for all of its positions.
        categories = []
        for i, particle in enumerate(pos.type.children):
            instances = [c for c in pos.children if c.index == i]
            tag = particle.tag
            if tag not in self.emitted:
                # Not an element the builder writes: the guard rejects it as
                # unknown, so it needs no node. The builder must write every
                # element the schema requires, though.
                if max([particle.min] + [v for v, _ in pos.cmin.get(tag, [])]) > 0:
                    raise GenError(f"{pos.path()} requires {tag}, which src/zugferd/build.typ never writes")
                self.omitted += 1
                continue
            low_rules = pos.cmin.get(tag, [])
            high_rules = pos.cmax.get(tag, [])
            low = max([particle.min] + [v for v, _ in low_rules])
            high = particle.max
            for v, _ in high_rules:
                high = v if high == UNBOUNDED else min(high, v)
            # A rule that only restates the XSD's bound is named when it is a
            # business rule of EN 16931 (the validator reports those, too);
            # otherwise the finding is the XSD's.
            low_rule = best_rule([r for v, r in low_rules if v == low and (low > particle.min or r.startswith("BR-"))])
            high_rule = best_rule([r for v, r in high_rules if v == high and (high != particle.max or r.startswith("BR-"))])
            if low == 0:
                low_rule = None
            targets = [self.target(c) for c in instances]
            if all(isinstance(t, tuple) and t[0] == "F" for t in targets):
                high, high_rule = 0, best_rule([t[1] for t in targets])
                if low > 0:
                    raise GenError(f"{pos.path()}/{tag} is required and not used")
            if low > 0 and high == 0:
                raise GenError(f"{pos.path()}/{tag} is required and forbidden")
            if instances[0].variant is None:
                target = targets[0]
            else:
                target = self.dispatch(pos, tag, instances, targets)
            children.append((tag, i, low, high, target, low_rule, high_rule))
            with_rules = [c for c, t in zip(instances, targets) if c.categories and t[0] != "F"]
            if with_rules and high != 0:
                if len(instances) != 1:
                    raise GenError(f"VAT category rules of a variant of {tag} at {pos.path()}")
                categories.append((tag, category_table(with_rules[0])))
        extras = (
            tuple(sorted(set(pos.aggregates))),
            tuple(sorted({(tags, best_rule([r for t, r in pos.anyof if t == tags])) for tags, _ in pos.anyof})),
            tuple(sorted({(tags, best_rule([r for t, r in pos.exclusive if t == tags])) for tags, _ in pos.exclusive})),
            tuple(sorted(pos.xref)),
            tuple(categories),
        )
        required = any(c[2] > 0 for c in children)
        empty = None if required else pos.no_empty or "ok"
        return ("C", tuple(children), empty) + extras

    def target(self, pos):
        if pos.forbidden:
            return ("F", pos.forbidden[0])
        if pos.variant is not None and not pos.leaf:
            # A variant whose rules require a child they also forbid (e.g. a
            # document reference of a type no rule allows) cannot occur.
            for particle in pos.type.children:
                lows = [v for v, _ in pos.cmin.get(particle.tag, [])] + [particle.min]
                zeros = [r for v, r in pos.cmax.get(particle.tag, []) if v == 0]
                if max(lows) > 0 and zeros:
                    return ("F", best_rule(zeros))
            # Nor can a variant whose value the discriminator's own code list
            # rejects (e.g. a charge indicator "0" where only "true" and
            # "false" are allowed): the list names the rule.
            rejected = self.rejected_variant(pos)
            if rejected:
                return ("F", rejected)
        return ("N", self.key(pos))

    def rejected_variant(self, pos):
        if pos.variant == OTHER:
            return None
        *steps, last = FAMILIES[pos.tag]
        level = [pos]
        for tag in steps + ([] if last.startswith("@") else [last]):
            level = [c for p in level for c in p.child_positions(tag)]
        for leaf in level:
            lists = leaf.attrs[last[1:]].lists if last.startswith("@") and last[1:] in leaf.attrs else leaf.lists
            ref = combine_lists(lists)
            if ref is not None and pos.variant not in ref.codes:
                return dict(ref.exceptions).get(pos.variant, ref.rule)
        return None

    def dispatch(self, parent, tag, instances, targets):
        """The variants of a family element: the target of each value, and
        the number of elements each value allows."""
        disc = FAMILIES[tag]
        by_value = {c.variant: t for c, t in zip(instances, targets)}
        other = by_value.pop(OTHER)
        limits = {}
        for value in sorted(by_value) + [OTHER]:
            lows = parent.vmin.get(tag, {}).get(value, [])
            highs = parent.vmax.get(tag, {}).get(value, [])
            if lows or highs:
                low = max(v for v, _ in lows) if lows else 0
                high = min(v for v, _ in highs) if highs else UNBOUNDED
                limits[value] = (low, high, best_rule([r for v, r in lows if v == low]),
                                 best_rule([r for v, r in highs if v == high]))
        values = tuple((v, t) for v, t in sorted(by_value.items()) if t != other or v in limits)
        if not values and not limits:
            return other
        return ("D", disc, values, other, tuple(sorted(limits.items())))

    # ------------------------------------------------------------ numbering

    def number(self, key):
        """Numbers the nodes depth-first: complex nodes ("C"), leaves ("L")
        and the dispatch of a family element by its variants ("D"), so that
        every child entry names its node by index."""
        if key in self.ids:
            return
        self.ids[key] = len(self.order)
        self.order.append(key)
        if key[0] == "C":
            for child in key[1]:
                target = child[4]
                if target[0] == "N":
                    self.number(target[1])
                elif target[0] == "D":
                    self.number(target)
        elif key[0] == "D":
            for _, target in key[2] + ((None, key[3]),):
                if target[0] == "N":
                    self.number(target[1])

    def lists(self):
        """Every distinct code set the nodes use."""
        found = set()
        for key in self.order:
            if key[0] == "L":
                refs = [a[3] for a in key[2]] + [key[3]] + ([key[4][0]] if key[4] else [])
                found.update(r.codes for r in refs if r is not None)
        return found


# ================================================================ names of the lists

# The header of the tables as Typst source, which the generator wrote before
# the JSON: `is_generated` tells such files apart, so that the drift test
# reports one that comes back.
HEADER = """// Generated by tools/zugferd/gen_guard.py from the Mustang CLI jar 2.14.0;
// do not edit, rerun it (scripts/zugferd-corpus checks for drift).
"""

# Names of the code lists, by the element (or `element@attribute`) they are
# first used for. A list without an entry here fails the generator, so that
# every list in the tables has a name that says what it is.
LIST_NAMES = {
    "ram:CountryID": "country",
    "ram:ID@country": "country",
    "ram:InvoiceCurrencyCode": "currency",
    "ram:TaxCurrencyCode": "currency",
    "ram:TaxTotalAmount@currencyID": "currency",
    "ram:BilledQuantity@unitCode": "unit",
    "ram:BasisQuantity@unitCode": "unit",
    "ram:URIID@schemeID": "eas",
    "ram:GlobalID@schemeID": "icd",
    "ram:ID@schemeID": "icd",
    "ram:ID#prefix": "vat-prefix",
    "ram:TypeCode": "type-code",
    "ram:CategoryCode": "vat-category",
    "ram:ExemptionReasonCode": "vatex",
    "ram:SubjectCode": "note-subject",
    "ram:ReasonCode": "allowance-charge-reason",
    "ram:ReferenceTypeCode": "reference-type",
    "ram:ClassCode@listID": "item-classification",
    "ram:AttachmentBinaryObject@mimeCode": "mime",
    "udt:DateTimeString@format": "date-format",
    "qdt:DateTimeString@format": "date-format",
    "udt:DateString@format": "date-format",
    "ram:DueDateTypeCode": "due-date-type",
    "udt:Indicator": "indicator",
}


def usage_keys(pos, what):
    """The keys of LIST_NAMES for a list of `pos`, most specific first."""
    parent = pos.parent.tag if pos.parent is not None else ""
    return [f"{parent}/{pos.tag}{what}", f"{pos.tag}{what}"]


LIST_NAMES.update({
    "rsm:ExchangedDocument/ram:TypeCode": "document-type",
    "ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode": "payment-means",
    "ram:ApplicableTradeTax/ram:TypeCode": "tax-type",
    "ram:CategoryTradeTax/ram:TypeCode": "tax-type",
    "ram:AdditionalReferencedDocument/ram:TypeCode": "reference-document-type",
    "ram:GuidelineSpecifiedDocumentContextParameter/ram:ID": "guideline",
    "ram:OriginTradeCountry/ram:ID": "country",
    "ram:ApplicableHeaderTradeSettlement/ram:InvoiceCurrencyCode": "currency",
    "ram:SpecifiedTaxRegistration/ram:ID@schemeID": "tax-scheme",
})


def count_text(n, noun):
    return f"{n} {noun}" + ("" if n == 1 else "s")


# The code lists of the validator (src/zugferd/rules/), which are lists of
# the tables: per name, the position whose lists they are, as (path,
# attribute or None, factur-x). `validator_lists` takes them from the tables
# of the profiles, so that the validator accepts the codes the validation of
# each profile accepts (see `code-finding` of src/zugferd/rules/rare.typ):
#
#   every      the codes of every validation of BASIC, EN 16931 and
#              XRechnung: the Factur-X list and both CEN lists (1.3.12 in
#              Mustang, 1.3.16 in KoSIT, which BASIC applies as well, see
#              `withdrawn`). Every list of a profile holds them, so the
#              validator accepts a code of `every` in every profile without
#              a look at the others
#   xrechnung  the codes of the validation of XRechnung, which applies both
#              CEN lists and no Factur-X list (e.g. the scheme 0219, which
#              the Factur-X list lacks); only where they are not `every`
#   factur-x   with `factur-x` true: the Factur-X list, which the validation
#              of MINIMUM and BASIC WL applies alone, with the codes the CEN
#              lists lack (e.g. South Sudan, SS) and their withdrawn codes;
#              without, these profiles accept `every`, their Factur-X list
#              without the withdrawn codes (which is checked here)
#   newer      the codes only the newest CEN list has: right, but newer than
#              the other lists, which the messages name as such
#   withdrawn  the codes of the older CEN list that the newest has withdrawn
#              (e.g. BGN, the euro since 2026, and the scheme 9901): only
#              KoSIT rejects them, which does not validate BASIC, MINIMUM and
#              BASIC WL, but a receiver that applies the current lists does.
#              invoice-pro rejects them in every profile but in MINIMUM and
#              BASIC WL for a name with `factur-x` (IP-CODE-01 where no
#              validator of the profile does), and warns of a currency where
#              the Factur-X validation accepts it (NEWEST_XRECHNUNG_ONLY)
_SELLER = "rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty"
_SETTLEMENT = "rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement"
_LINE = "rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem"
VALIDATOR_LISTS = {
    "country": (f"{_SELLER}/ram:PostalTradeAddress/ram:CountryID", None, True),
    "currency": (f"{_SETTLEMENT}/ram:InvoiceCurrencyCode", None, True),
    "eas": (f"{_SELLER}/ram:URIUniversalCommunication/ram:URIID", "schemeID", False),
    "icd": (f"{_SELLER}/ram:GlobalID", "schemeID", False),
    "payment-means": (f"{_SETTLEMENT}/ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode", None, False),
    "unit": (f"{_LINE}/ram:SpecifiedLineTradeDelivery/ram:BilledQuantity", "unitCode", False),
    "vat-category": (f"{_SETTLEMENT}/ram:ApplicableTradeTax/ram:CategoryCode", None, False),
    "vatex": (f"{_SETTLEMENT}/ram:ApplicableTradeTax/ram:ExemptionReasonCode", None, False),
}
# The names whose codes the validator checks with `every` in every profile
# (the unit codes, `_lines` of src/zugferd/rules/engine.typ): the list of
# XRechnung must be `every` as well.
VALIDATOR_EVERY_ONLY = ("unit",)


def _validator_position(compilers, names, name, profile, path, attr):
    """The code lists at a position of VALIDATOR_LISTS in a profile and the
    codes of their intersection (a list of the tables), or None where the
    profile has no such position (e.g. no lines in BASIC WL)."""
    found = [p for p in compilers[profile].positions if p.path() == path and p.leaf]
    if not found:
        return None
    if len(found) != 1:
        raise GenError(f"VALIDATOR_LISTS {name}: {len(found)} leaves {path} in the profile {profile}")
    pos = found[0]
    lists = pos.attrs[attr].lists if attr else pos.lists
    ref = combine_lists(lists)
    if ref is None or ref.codes not in names.names:
        raise GenError(f"VALIDATOR_LISTS {name}: no code list of the tables at {path} ({profile})")
    return lists, ref.codes


def validator_lists(compilers, names):
    """The lists of VALIDATOR_LISTS: per name, the name in lists.json of each
    list (`every`, `xrechnung` where it is another, `factur-x`) and the codes
    of `newer` and `withdrawn`, sorted. Fails where the lists of a profile
    are not what the validator assumes (see VALIDATOR_LISTS)."""
    out = {}
    for name, (path, attr, factur_x) in sorted(VALIDATOR_LISTS.items()):
        at = {p: _validator_position(compilers, names, name, p, path, attr) for p in PROFILES}
        for profile in ("en16931", "xrechnung"):
            if at[profile] is None:
                raise GenError(f"VALIDATOR_LISTS {name}: no leaf {path} in the profile {profile}")
        own_lists, en16931 = at["en16931"]
        xr_lists, xrechnung = at["xrechnung"]
        if at["basic"] is not None and at["basic"][1] != en16931:
            raise GenError(f"VALIDATOR_LISTS {name}: the list of BASIC is not the one of EN 16931")
        # The lists of every validation of the profiles based on EN 16931:
        # XRechnung applies the newest CEN list to codes the others do not
        # (NEWEST_XRECHNUNG_ONLY), which `every` then lacks as well.
        lists = list(own_lists) + [c for c in xr_lists if c not in own_lists]
        every = en16931 & xrechnung
        entry = {"every": names.add(every, name)}
        older = frozenset().union(*(c.codes for c in lists if not c.newest))
        newest = [c.codes for c in lists if c.newest]
        newer = frozenset().union(*newest) - older
        cen = [c.codes for c in lists if c.source == "CEN" and not c.newest]
        withdrawn = (frozenset.intersection(*cen) - frozenset.intersection(*newest)) if cen and newest else frozenset()
        fx = [c.codes for c in lists if c.source == "FX"]
        own = [at[p][1] for p in ("minimum", "basic-wl") if at[p] is not None]
        if factur_x:
            if not own or any(codes != own[-1] for codes in own):
                raise GenError(f"VALIDATOR_LISTS {name}: MINIMUM and BASIC WL have no common list at {path}")
            entry["factur-x"] = names.name(own[-1])
        else:
            # The engine accepts `every` in MINIMUM and BASIC WL and names a
            # withdrawn code as IP-CODE-01 in them and in BASIC: each is in
            # the Factur-X list.
            if any(codes - withdrawn != every for codes in own):
                raise GenError(f"VALIDATOR_LISTS {name}: the list of MINIMUM or BASIC WL is not `every` "
                               "and the withdrawn codes; give it `factur-x`")
            if fx and not withdrawn <= frozenset.intersection(*fx):
                raise GenError(f"VALIDATOR_LISTS {name}: withdrawn codes that the Factur-X list lacks; "
                               "give it `factur-x`")
        if any(not every <= codes for codes in own):
            raise GenError(f"VALIDATOR_LISTS {name}: a list of a profile lacks codes of `every`")
        # BASIC and EN 16931 accept beyond `every` only the withdrawn
        # currencies, of which the validator warns (IP-CODE-01).
        beyond = en16931 - every
        if beyond and (name != "currency" or not beyond <= withdrawn):
            raise GenError(f"VALIDATOR_LISTS {name}: the list of EN 16931 has codes beyond `every` that "
                           f"are no withdrawn currencies: {sorted(beyond)[:8]}")
        if xrechnung != every:
            if name in VALIDATOR_EVERY_ONLY:
                raise GenError(f"VALIDATOR_LISTS {name}: the list of XRechnung is not `every`, which the "
                               "validator checks in every profile (VALIDATOR_EVERY_ONLY)")
            entry["xrechnung"] = names.name(xrechnung)
        if newer:
            entry["newer"] = sorted(newer)
        if withdrawn:
            entry["withdrawn"] = sorted(withdrawn)
        out[name] = entry
    return out


# Names of the tables of VAT category rules, by where they apply: (parent,
# its variant, tax element). A table elsewhere fails the generator.
VAT_TABLE_NAMES = {
    ("ram:SpecifiedLineTradeSettlement", None, "ram:ApplicableTradeTax"): "vat-line",
    ("ram:ApplicableHeaderTradeSettlement", None, "ram:ApplicableTradeTax"): "vat-breakdown",
    ("ram:SpecifiedTradeAllowanceCharge", "false", "ram:CategoryTradeTax"): "vat-allowance",
    ("ram:SpecifiedTradeAllowanceCharge", "true", "ram:CategoryTradeTax"): "vat-charge",
}


class ListNames:
    """Readable, stable names of the distinct code sets of all profiles:
    the name of what they list, numbered by size when several differ; and
    of the distinct tables of VAT category rules (`vat`), by where they
    apply."""

    def __init__(self, all_nodes):
        all_nodes = list(all_nodes)
        self.vat = self._vat_names(all_nodes)
        by_base = collections.defaultdict(list)
        for nodes in all_nodes:
            for key in nodes.order:
                if key[0] != "L":
                    continue
                pos = nodes.positions[key][0]
                uses = [(r, "") for r in [key[3]]]
                uses += [(a[3], "@" + a[0]) for a in key[2]]
                if key[4]:
                    uses.append((key[4][0], "#prefix"))
                for ref, what in uses:
                    if ref is None:
                        continue
                    base = next((LIST_NAMES[k] for k in usage_keys(pos, what) if k in LIST_NAMES), None)
                    if base is None:
                        raise GenError(f"no name for the code list of {pos.path()}{what}: add it to LIST_NAMES")
                    if ref.codes not in by_base[base]:
                        by_base[base].append(ref.codes)
        self.names = {}
        self.base = {}
        for base, sets in sorted(by_base.items()):
            for i, codes in enumerate(sorted(sets, key=lambda s: (-len(s), sorted(s)))):
                if codes in self.names:
                    continue  # the same codes under two names: keep the first
                self.names[codes] = base if i == 0 else f"{base}-{i + 1}"
                self.base[codes] = sorted(sets, key=lambda s: (-len(s), sorted(s)))[0]

    @staticmethod
    def _vat_names(all_nodes):
        found = collections.defaultdict(list)
        for nodes in all_nodes:
            for key in nodes.order:
                if key[0] != "C":
                    continue
                for tag, table in key[7]:
                    bases = {VAT_TABLE_NAMES.get((p.tag, p.variant, tag)) for p in nodes.positions[key]}
                    if len(bases) != 1 or None in bases:
                        raise GenError(f"no name for the VAT category rules of {tag} below "
                                       f"{nodes.positions[key][0].path()}: add it to VAT_TABLE_NAMES")
                    base = bases.pop()
                    if table not in found[base]:
                        found[base].append(table)
        names = {}
        for base, tables in sorted(found.items()):
            for i, table in enumerate(sorted(tables, key=repr)):
                names[table] = base if i == 0 else f"{base}-{i + 1}"
        return names

    def name(self, codes):
        return self.names[codes]

    def add(self, codes, base):
        """The name of a code set the validator needs besides the lists of
        the tables (see `validator_lists`): its name, or the next free name
        of `base`."""
        if codes not in self.names:
            taken, name, i = set(self.names.values()), base, 1
            while name in taken:
                i += 1
                name = f"{base}-{i}"
            self.names[codes] = name
        return self.names[codes]

    def variable(self, codes):
        return "_" + self.names[codes]


def chunks(codes, width=72):
    """The codes as strings of at most `width` characters."""
    lines, line = [], ""
    for code in codes:
        if line and len(line) + 1 + len(code) > width:
            lines.append(line)
            line = code
        else:
            line = f"{line} {code}" if line else code
    if line:
        lines.append(line)
    return lines


def emit_lists(names, validator=None):
    """src/zugferd/guard/lists.json: every code list as the lines of its
    codes, which src/zugferd/guard/lists.typ joins into one string of the
    codes, each between two spaces (a lookup is one substring search); the
    tables of the rules of the VAT categories (see TAX_ELEMENTS) by name;
    and `validator` (see `validator_lists`): per name, the names of its
    lists (e.g. `every`) and, for a kind that is a set of codes of its own
    (e.g. `newer`), the codes in lines as those of a list. One code list,
    table or validator list per line or lines of its own, so that a change
    reads as a diff."""
    validator = validator or {}
    own = [codes for entry in validator.values() for codes in entry.values() if isinstance(codes, (list, tuple))]
    for codes in list(names.names) + own:
        bad = sorted(c for c in codes if not c or re.search(r"\s", c))
        if bad:
            raise GenError(f"codes that are empty or contain whitespace cannot be listed: {bad}")
    lines = ["{", f'"generated":{json_value(LISTS_NOTICE)},', '"lists":{']
    ordered = sorted(names.names.items(), key=lambda kv: kv[1])
    lines += json_members(
        # Lines of at most 75 characters: `"<line>",` fills the width of 80.
        (name, "[\n" + ",\n".join(json_value(line) for line in chunks(sorted(codes), 75)) + "\n]")
        for codes, name in ordered
    )
    lines += ["},", '"vat-rules":{']
    lines += json_members(
        (name, "{" + ",".join(f"{json_value(code)}:{json_value([list(c) for c in checks])}" for code, checks in table) + "}")
        for table, name in sorted(names.vat.items(), key=lambda kv: kv[1])
    )
    lines += ["},", '"validator":{']
    lines += json_members(
        (name, json_value({kind: chunks(v, 75) if isinstance(v, (list, tuple)) else v for kind, v in entry.items()}))
        for name, entry in validator.items()
    )
    lines += ["}", "}"]
    return "\n".join(lines) + "\n"


def json_members(items):
    """The lines of JSON object members `"name":<value>`, one per line (a
    value may span lines), separated by commas."""
    items = list(items)
    return [f"{json_value(name)}:{value}" + ("," if i < len(items) - 1 else "") for i, (name, value) in enumerate(items)]


# ================================================================ JSON output

# The fast classes of a leaf (see `leaf_fast`), which the writer tells apart
# from the names of code lists in the action of a child.
FAST_CLASSES = ("s", "d", "d2", "b")

# The notice at the top of every generated JSON file (JSON has no comments).
JSON_NOTICE = (
    "Generated by tools/zugferd/gen_guard.py from the Mustang CLI jar 2.14.0; do not edit, "
    "rerun it (scripts/zugferd-corpus checks for drift). src/zugferd/guard/write.typ describes the nodes."
)
LISTS_NOTICE = (
    "Generated by tools/zugferd/gen_guard.py from the Mustang CLI jar 2.14.0; do not edit, "
    "rerun it (scripts/zugferd-corpus checks for drift). src/zugferd/guard/lists.typ reads it."
)


def json_value(value):
    """A value as compact JSON: no spaces, the keys in the order given."""
    return json.dumps(value, separators=(",", ":"))


def emit_profile(profile, nodes, names, digests):
    """src/zugferd/guard/<profile>.json: the nodes of one profile, and the
    rule that forbids an empty leaf (`empty`, or null).

    JSON rather than Typst source: Typst reads JSON natively, several times
    faster than it parses and evaluates the same data as a module, and the
    file stays reviewable line by line: one node per line, the children of a
    complex node on lines of their own (see `emit_node`)."""
    directory, fx, cen, xr = PROFILES[profile]
    sources = [f"Factur-X 1.0.07 XSD {directory}"]
    if fx:
        sources.append(f"Factur-X Schematron {fx}")
    if cen:
        sources.append("CEN EN 16931 CII Schematron")
    if xr:
        sources.append("XRechnung 3.0 CII Schematron")
    body = [emit_node(key, nodes, names) for key in nodes.order]
    out = [
        "{",
        f'"generated":{json_value(JSON_NOTICE)},',
        f'"profile":{json_value(profile)},',
        f'"sources":{json_value(", ".join(sources))},',
        f'"empty":{json_value(nodes.compiler.empty_leaf)},',
        '"nodes":[',
        ",\n".join(body),
        "]}",
    ]
    return "\n".join(out) + "\n"


def emit_high(high):
    return None if high == UNBOUNDED else high


def emit_target(target, nodes):
    """The index of the node of a child element or of a variant, or the rule
    that marks a variant as not used."""
    kind = target[0]
    if kind == "N":
        return nodes.ids[target[1]]
    if kind == "D":
        return nodes.ids[target]
    return target[1]


def emit_dispatch(key, nodes):
    """The dispatch of a family element by the value of its discriminator:
    {d: discriminator path, m: value -> node or rule, o: node or rule of any
    other value, k: value -> [maximum, rule]}."""
    _, disc, values, other, limits = key
    return {
        "d": list(disc),
        "m": {v: emit_target(t, nodes) for v, t in values},
        "o": emit_target(other, nodes),
        "k": {v: [hi, hr] for v, (lo, hi, lr, hr) in limits if hi != UNBOUNDED},
    }


def leaf_fast(kind, attrs, text, prefix, fraction, date):
    """The class of plain texts (a value without attributes) that pass every
    check of a leaf by their form alone, for the writer's fast path: "s" any
    text, "d" a decimal, "d2" a decimal with at most two decimals, "b" an
    indicator; `None` when a text needs the full check (a code list, a
    prefix, a date, a required attribute)."""
    if text is not None or prefix is not None or date is not None or kind == "x":
        return None
    if any(required is not None for _, required, _, _ in attrs):
        return None
    if fraction is None:
        return kind
    if kind == "d" and fraction[0] == 2:
        return "d2"
    return None


def leaf_list(kind, attrs, text, prefix, fraction, date):
    """The code list of a leaf whose only check is that list, else `None`:
    a plain text in the list (the intersection of the validators' lists)
    passes every check, in any case and whatever the exceptions say."""
    if kind != "s" or text is None or prefix is not None or fraction is not None or date is not None:
        return None
    if any(required is not None for _, required, _, _ in attrs):
        return None
    return text


def emit_action(target, nodes, names):
    """What the writer does with a child in its fast path: write a
    dictionary value as the complex node of this index, a plain text of
    this fast class (see `leaf_fast`), or a plain text in the code list of
    this name (in lists.typ); `None` when every value takes the general path
    (a leaf with further checks, a family element)."""
    if target[0] != "N":
        return None
    key = target[1]
    if key[0] == "C":
        return nodes.ids[key]
    ref = leaf_list(*key[1:])
    if ref is not None:
        # The writer tells a list from a fast class by the length of its name.
        name = names.name(ref.codes)
        if len(name) <= max(len(c) for c in FAST_CLASSES):
            raise GenError(f"the name of the code list {name!r} is too short for the writer's fast path")
        return name
    return leaf_fast(*key[1:])


def emit_list(ref, names):
    if ref is None:
        return None
    exceptions = dict(ref.exceptions) if ref.exceptions else None
    return [names.name(ref.codes), ref.rule, exceptions, ref.casefold]


def emit_node(key, nodes, names):
    """A node in JSON: a leaf as its kind, or as an array [kind, attributes,
    list, prefix list, decimals, date]; a complex node as an object {n:
    number of required children, z: further checks, u: the children not used
    at this position, each with the rule that says so (z and u only when
    there are any), c: the children}, one child per line; the dispatch of a
    family element (see `emit_dispatch`). The tables of VAT category rules
    (`t`) are named by their name in lists.typ."""
    if key[0] == "D":
        return json_value(emit_dispatch(key, nodes))
    if key[0] == "L":
        _, kind, attrs, text, prefix, fraction, date = key
        if not attrs and text is None and prefix is None and fraction is None and date is None:
            return json_value(kind)  # a leaf without further checks: its kind
        items = [kind]
        if attrs:
            specs = {}
            for name, required, forbidden, lst in attrs:
                req = False if required is None else True if required == "XSD" else required
                specs[name] = [req, forbidden, emit_list(lst, names)]
            items.append(specs)
        else:
            items.append(None)
        items.append(emit_list(text, names))
        if prefix:
            ref, when = prefix
            items.append([emit_list(ref, names), None if when is None else list(when)])
        else:
            items.append(None)
        items.append(None if fraction is None else [fraction[0], fraction[1], fraction[2]])
        items.append(date)
        return json_value(items)
    _, children, empty = key[:3]
    aggregates, anyof, exclusive, xref, categories = key[3:]
    specs = []
    unused = {}
    for tag, index, low, high, target, low_rule, high_rule in children:
        if high == 0:
            # Not used at this position: the rule that says so.
            unused[tag] = high_rule or target[1]
            continue
        if low > 1:
            # The writer checks that a required child is there and counts
            # the required children by their minimum.
            raise GenError(f"{tag}: a minimum of {low}; the guard supports 0 and 1")
        # The rules of the minimum and the maximum, as far as there are any,
        # or null: every child has six entries, which the writer binds with
        # one destructuring.
        rules = [low_rule, high_rule] if high_rule else [low_rule] if low_rule else None
        spec = [emit_action(target, nodes, names), index, low, emit_high(high), emit_target(target, nodes), rules]
        specs.append(f"{json_value(tag)}:{json_value(spec)}")
    node = {"n": sum(1 for c in children if c[2] > 0)}
    extras = {}
    if empty not in (None, "ok"):
        extras["e"] = empty
    minima = [
        [tag, v, lo, lr]
        for tag, _, _, high, target, _, _ in children
        if high != 0 and target[0] == "D"
        for v, (lo, hi, lr, hr) in target[4]
        if lo > 0
    ]
    if minima:
        extras["v"] = minima
    if aggregates:
        extras["g"] = [[list(path), lo, emit_high(hi), rule] for path, lo, hi, rule in aggregates]
    if anyof:
        extras["y"] = [[list(tags), rule] for tags, rule in anyof]
    if exclusive:
        extras["x"] = [[list(tags), rule] for tags, rule in exclusive]
    if xref:
        extras["r"] = [[kind, ["ram:" + r for r in refs], rule] for kind, refs, rule in xref]
    if categories:
        extras["t"] = {tag: names.vat[table] for tag, table in categories}
    if extras:
        node["z"] = extras
    if unused:
        node["u"] = unused
    head = json_value(node)[:-1]
    if not specs:
        return head + ',"c":{}}'
    return head + ',"c":{\n' + ",\n".join(" " + s for s in specs) + "}}"


# ================================================================ main


def known_tags(schemas):
    tags = set()
    for schema in schemas:
        tags.add(schema.root[0])
        for t in schema.types.values():
            tags.update(p.tag for p in t.children)
    return tags


# The code list rules of the newest CEN Schematron that apply to XRechnung
# only: the currencies of the invoice (BR-CL-04), of its amounts (BR-CL-03)
# and of its VAT accounting (BR-CL-05). A currency the newest list has
# withdrawn (e.g. BGN and HRK, replaced by the euro) is allowed wherever the
# Factur-X validation of the profile accepts it (maintainer decision of
# 2026-09-24): the tables of BASIC and EN 16931 take the Factur-X list and
# CEN 1.3.12 at these positions, and the validator warns (IP-CODE-01).
NEWEST_XRECHNUNG_ONLY = frozenset({"BR-CL-03", "BR-CL-04", "BR-CL-05"})


def newest_code_lists(profile, cen_code_lists):
    """The code list rules of the newest CEN Schematron that join the CEN
    rules of a profile (see NEWEST_XRECHNUNG_ONLY)."""
    return [r for r in cen_code_lists if profile == "xrechnung" or r.id not in NEWEST_XRECHNUNG_ONLY]


def load_profile(jar, profile, schemas, cen_code_lists=()):
    """The compiled rules of a profile. `cen_code_lists` are the code list
    rules of the newest CEN Schematron (`load_cen_code_lists`), which join
    the CEN rules (see `newest_code_lists`); without them, the lists are
    those of the Mustang jar."""
    directory, fx, cen, xr = PROFILES[profile]
    rules = []
    if fx:
        rules += load_rules(jar, fx_xslt(fx), "FX", fx_codedb(fx))
    if cen:
        rules += load_rules(jar, CEN_XSLT, "CEN")
        rules += newest_code_lists(profile, cen_code_lists)
    if xr:
        rules += load_rules(jar, XR_XSLT, "XR")
    return Compiler(profile, schemas[directory], rules, known_tags(schemas.values())).compile()


def load_schemas(jar):
    return {directory: Schema(jar, directory) for directory in sorted({p[0] for p in PROFILES.values()})}


BUILDER = REPO / "src" / "zugferd" / "build.typ"


def builder_tags(path=BUILDER):
    """The element names the builder can write: every string literal of an
    element name in src/zugferd/build.typ. The guard only knows elements
    below these names ("not emitted" otherwise): exact tables for all the
    builder may write, and no tables for what it never writes. A new element
    in the builder changes the tables, which the drift test catches."""
    text = Path(path).read_text(encoding="utf-8")
    tags = set(re.findall(r'"((?:rsm|ram|udt|qdt):\w+)"', text))
    if not tags:
        raise GenError(f"{path}: no element names found")
    return tags


OUTPUT_FILES = ["lists.json"] + [f"{p}.json" for p in PROFILES]
# The generated files may not grow beyond this (maintainer decision 13).
SIZE_BUDGET = 100 * 1024


def generate(jar_path, out_dir, pinned=True, builder=BUILDER, kosit_config=None):
    """Compiles the tables and writes them into `out_dir`; returns the
    statistics. `kosit_config` is the unpacked KoSIT configuration
    (default: $KOSIT_CONFIG), whose CEN Schematron narrows the code lists."""
    jar = Jar(jar_path, pinned=pinned)
    kosit = KositConfig(kosit_config or os.environ.get("KOSIT_CONFIG"), pinned=pinned)
    schemas = load_schemas(jar)
    cen_code_lists = load_cen_code_lists(kosit, load_rules(jar, CEN_XSLT, "CEN"))
    compilers = {p: load_profile(jar, p, schemas, cen_code_lists) for p in PROFILES}
    emitted = builder_tags(builder)
    nodes = {p: Nodes(c, emitted) for p, c in compilers.items()}
    names = ListNames(nodes[p] for p in PROFILES)
    files = {"lists.json": emit_lists(names, validator_lists(compilers, names))}
    for p in PROFILES:
        files[f"{p}.json"] = emit_profile(p, nodes[p], names, jar.digests)
    size = sum(len(text.encode("utf-8")) for text in files.values())
    if size > SIZE_BUDGET:
        raise GenError(f"the tables take {size} bytes, more than the budget of {SIZE_BUDGET}")
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, text in files.items():
        (out_dir / name).write_text(text, encoding="utf-8")
    jar.digests.update(kosit.digests)
    return stats(compilers, nodes, names, files, jar)


def stats(compilers, nodes, names, files, jar):
    """What the tables cover, per profile: positions, nodes, and every rule
    with its disposition."""
    out = {
        "artefacts": dict(sorted(jar.digests.items())),
        "bytes": {name: len(text.encode("utf-8")) for name, text in files.items()},
        "lists": {name: len(codes) for codes, name in sorted(names.names.items(), key=lambda kv: kv[1])},
        "profiles": {},
    }
    out["bytes"]["total"] = sum(out["bytes"].values())
    for p, c in compilers.items():
        dispositions = collections.defaultdict(list)
        for r, d, detail in c.dispositions:
            # `artefact` tells the twins of the CEN code lists apart (the
            # KoSIT configuration's CEN 1.3.16, see `load_cen_code_lists`).
            dispositions[d].append({
                "source": r.source, "id": r.id, "rule": r.ref, "context": r.context, "detail": detail,
                "artefact": r.artefact,
            })
        out["profiles"][p] = {
            "positions": len(c.positions),
            "nodes": len(nodes[p].order),
            "omitted children (not written by the builder)": nodes[p].omitted,
            "rules": {d: len(v) for d, v in sorted(dispositions.items())},
            "dispositions": {d: v for d, v in sorted(dispositions.items())},
        }
    return out


DISPOSITIONS = {
    "compiled": "compiled into the tables",
    "conservative": "compiled, although a rule of higher priority may take the position (stricter)",
    "defect": "compiled as corrected (see DEFECTS)",
    "business": "a condition on values, sums or other elements: left to the validator",
    "tautology": "always true",
    "shadowed": "a rule of higher priority takes every position",
    "unmatched": "no position of the profile",
}


def explain(result):
    for p, info in result["profiles"].items():
        print(f"== {p}: {info['positions']} positions, {info['nodes']} nodes, rules {info['rules']}")
        for d, rules in info["dispositions"].items():
            print(f"  -- {d}: {DISPOSITIONS.get(d, d)}")
            for r in rules:
                print(f"     {r['source']:3} {r['id'] or '(report)':22} {r['detail'][:60]:60} [{r['context'][:90]}]")


def is_generated(path):
    """Whether `path` is a file the generator writes or wrote: Typst source
    that starts with its HEADER (the tables were Typst source before), or
    JSON with one of its notices."""
    if path.suffix == ".typ":
        return path.read_text(encoding="utf-8").startswith(HEADER)
    if path.suffix == ".json":
        text = path.read_text(encoding="utf-8")
        return any(f'"generated":{json_value(notice)}' in text for notice in (JSON_NOTICE, LISTS_NOTICE))
    return False


def compare(fresh_dir, committed_dir=OUT):
    """The differences between freshly generated tables and the committed
    ones, as unified diffs (empty when there are none), including generated
    files the generator no longer writes."""
    fresh_dir, committed_dir = Path(fresh_dir), Path(committed_dir)
    diffs = []
    for name in OUTPUT_FILES:
        fresh = (fresh_dir / name).read_text(encoding="utf-8")
        committed_path = committed_dir / name
        committed = committed_path.read_text(encoding="utf-8") if committed_path.exists() else ""
        if fresh != committed:
            diffs.append("".join(difflib.unified_diff(
                committed.splitlines(keepends=True), fresh.splitlines(keepends=True),
                f"committed/{name}", f"generated/{name}", n=1,
            )))
    stale = sorted(
        p.name for p in committed_dir.iterdir()
        if p.name not in OUTPUT_FILES and is_generated(p)
    )
    if stale:
        diffs.append(f"generated files in {committed_dir} the generator no longer writes: {', '.join(stale)}\n")
    return diffs


def check(jar_path, kosit_config=None):
    """Regenerates into a temporary directory and compares with the
    committed tables (see `compare`)."""
    with tempfile.TemporaryDirectory() as tmp:
        generate(jar_path, tmp, kosit_config=kosit_config)
        return compare(tmp)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--jar", default=os.environ.get("MUSTANG_JAR"), help="Mustang-CLI-2.14.0.jar ($MUSTANG_JAR)")
    ap.add_argument(
        "--kosit-config",
        default=os.environ.get("KOSIT_CONFIG"),
        help="the unpacked KoSIT XRechnung configuration 2026-08-31 ($KOSIT_CONFIG)",
    )
    ap.add_argument("--out", default=str(OUT), help="output directory (default: src/zugferd/guard)")
    ap.add_argument("--check", action="store_true", help="fail when the committed tables differ from a fresh generation")
    ap.add_argument("--stats", help="write the statistics as JSON to this file")
    ap.add_argument("--explain", action="store_true", help="list every rule with its disposition")
    args = ap.parse_args(argv)
    if not args.jar:
        print("error: set MUSTANG_JAR or --jar to Mustang-CLI-2.14.0.jar", file=sys.stderr)
        return 2
    try:
        if args.check:
            diffs = check(args.jar, args.kosit_config)
            if diffs:
                print("The guard tables in src/zugferd/guard/ differ from a fresh generation. "
                      "Run `python3 tools/zugferd/gen_guard.py` and commit the result:\n", file=sys.stderr)
                for d in diffs:
                    print(d[:6000], file=sys.stderr)
                return 1
            print("✔ the guard tables match the pinned artefacts and src/zugferd/build.typ")
            return 0
        result = generate(args.jar, args.out, kosit_config=args.kosit_config)
    except GenError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    total = result["bytes"]["total"]
    print(f"✔ guard tables written to {args.out}: {total} bytes "
          + ", ".join(f"{p} {info['nodes']} nodes" for p, info in result["profiles"].items()))
    if args.stats:
        Path(args.stats).write_text(json.dumps(result, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    if args.explain:
        explain(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
