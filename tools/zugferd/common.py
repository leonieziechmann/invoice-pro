"""Shared helpers of the e-invoice conformance tools (tools/zugferd).

Everything that talks to the outside world lives here: compiling Typst,
reading PDF attachments and text, XSD validation with lxml, and the official
Mustang validator running in one long-lived JVM.

Configuration comes from the environment, so the tools run the same inside
and outside of Nix:

  TYPST_BIN    Typst executable (default: `typst`)
  MUSTANG_JAR  Mustang-CLI jar, needed for the official validation
               (https://github.com/ZUGFeRD/mustangproject, version 2.14.0)
  JAVA_BIN     `java` executable (default: $JAVA_HOME/bin/java or `java`)
  JAVAC_BIN    `javac` executable (default: $JAVA_HOME/bin/javac or `javac`)
  ZUGFERD_BUILD_DIR  where generated files go (default: <repo>/build/zugferd)
"""

import hashlib
import os
import re
import shutil
import subprocess
import threading
import time
import zipfile
from concurrent.futures import Future
from decimal import Decimal, InvalidOperation
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

# Same creation timestamp as the test suite in CI (`tt run --timestamp`), so
# that every document is reproducible: 1980-01-01T00:00:00Z.
DEFAULT_TIMESTAMP = 315532800

DIAGNOSTICS_ATTACHMENT = "invoice-pro-diagnostics.json"
# Names under which invoice-pro may attach the e-invoice XML, most specific
# first. `invoice-draft.xml` is the name for an XML with errors in "report"
# mode.
XML_ATTACHMENTS = ("factur-x.xml", "xrechnung.xml", "zugferd-invoice.xml", "invoice-draft.xml")

NS = {
    "rsm": "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
    "ram": "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
    "udt": "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100",
    "qdt": "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
}

# Guideline (BT-24) -> (profile id, XSD inside the Mustang jar).
GUIDELINES = {
    "urn:factur-x.eu:1p0:minimum": ("minimum", "MINIMUM/FACTUR-X_MINIMUM.xsd"),
    "urn:factur-x.eu:1p0:basicwl": ("basic-wl", "BASIC-WL/FACTUR-X_BASIC-WL.xsd"),
    "urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic": ("basic", "BASIC/FACTUR-X_BASIC.xsd"),
    "urn:cen.eu:en16931:2017": ("en16931", "EN16931/FACTUR-X_EN16931.xsd"),
    "urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0": (
        "xrechnung",
        "EN16931/FACTUR-X_EN16931.xsd",
    ),
}
GUIDELINE_PATH = "rsm:ExchangedDocumentContext/ram:GuidelineSpecifiedDocumentContextParameter/ram:ID"


class ToolError(Exception):
    """A setup problem (missing tool or file) with a message for the user."""


# ---------------------------------------------------------------- environment


def _java_tool(env_name, tool):
    explicit = os.environ.get(env_name)
    if explicit:
        return explicit
    home = os.environ.get("JAVA_HOME")
    if home and (Path(home) / "bin" / tool).exists():
        return str(Path(home) / "bin" / tool)
    return tool


def typst_bin():
    return os.environ.get("TYPST_BIN") or "typst"


def build_dir(override=None):
    path = Path(override or os.environ.get("ZUGFERD_BUILD_DIR") or REPO / "build" / "zugferd")
    return path.resolve()


def require_under_root(path, root=REPO):
    """Typst only reads files under its root: fail early with a clear message."""
    try:
        Path(path).resolve().relative_to(Path(root).resolve())
    except ValueError:
        raise ToolError(f"{path} must be inside the Typst root {root} (the cases import /src/lib.typ)")


def mustang_jar():
    jar = os.environ.get("MUSTANG_JAR")
    if not jar:
        raise ToolError(
            "MUSTANG_JAR is not set. Point it to Mustang-CLI-2.14.0.jar "
            "(https://github.com/ZUGFeRD/mustangproject/releases), or use the Nix "
            "apps, which set it (see tests/TESTING.md)."
        )
    if not Path(jar).is_file():
        raise ToolError(f"MUSTANG_JAR={jar} does not exist")
    return Path(jar).resolve()


def sha256_file(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            block = f.read(chunk)
            if not block:
                return h.hexdigest()
            h.update(block)


# ---------------------------------------------------------------- Typst


def typst_compile(src, out, root=REPO, inputs=None, timestamp=DEFAULT_TIMESTAMP, jobs=None, timings=None):
    """Compiles `src` to the PDF/A-3b `out`. Returns (ok, stderr, seconds)."""
    cmd = [typst_bin(), "compile", "--root", str(root), "--pdf-standard=a-3b"]
    if timestamp is not None:
        cmd += ["--creation-timestamp", str(timestamp)]
    if jobs:
        cmd += ["--jobs", str(jobs)]
    if timings:
        cmd += ["--timings", str(timings)]
    for key, value in (inputs or {}).items():
        cmd += ["--input", f"{key}={value}"]
    cmd += [str(src), str(out)]
    start = time.perf_counter()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError:
        raise ToolError(f"Typst not found ({typst_bin()}); set TYPST_BIN")
    return proc.returncode == 0, proc.stderr, time.perf_counter() - start


def read_pdf(pdf, text=True):
    """({name: bytes} of the embedded files, text of all pages or None)."""
    from pypdf import PdfReader

    reader = PdfReader(str(pdf))
    attachments = {name.lstrip("/"): data[0] for name, data in reader.attachments.items() if data}
    content = "\n".join(page.extract_text() or "" for page in reader.pages) if text else None
    return attachments, content


def invoice_xml(attachments):
    """(name, bytes) of the e-invoice XML among the attachments, or (None, None)."""
    for name in XML_ATTACHMENTS:
        if name in attachments:
            return name, attachments[name]
    for name, data in sorted(attachments.items()):
        if name.lower().endswith(".xml"):
            return name, data
    return None, None


# ---------------------------------------------------------------- XSD


class Schemas:
    """The Factur-X 1.0.07 (ZUGFeRD 2.3) XSDs, read from the Mustang jar."""

    def __init__(self, jar, cache_dir):
        self.jar = Path(jar)
        stamp = sha256_file(self.jar)[:16]
        self.dir = Path(cache_dir) / "xsd" / stamp
        self._loaded = {}
        self._lock = threading.Lock()
        if not (self.dir / ".complete").exists():
            self._extract()

    def _extract(self):
        tmp = self.dir.with_name(self.dir.name + ".tmp")
        shutil.rmtree(tmp, ignore_errors=True)
        with zipfile.ZipFile(self.jar) as jar:
            members = [m for m in jar.namelist() if m.startswith("schema/ZF_230/") and m.endswith(".xsd")]
            if not members:
                raise ToolError(f"{self.jar} contains no schema/ZF_230 XSDs; is it the Mustang-CLI jar?")
            for member in members:
                target = tmp / member[len("schema/ZF_230/"):]
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(jar.read(member))
        (tmp / ".complete").write_text("ok\n")
        shutil.rmtree(self.dir, ignore_errors=True)
        tmp.rename(self.dir)

    def schema(self, relative):
        from lxml import etree

        with self._lock:
            if relative not in self._loaded:
                self._loaded[relative] = etree.XMLSchema(etree.parse(str(self.dir / relative)))
            return self._loaded[relative]

    def validate(self, doc):
        """(profile id or None, [errors]) of a parsed CII document."""
        guideline = xtext1(doc, GUIDELINE_PATH)
        if guideline not in GUIDELINES:
            return None, [f"unknown guideline (BT-24) {guideline!r}"]
        profile, relative = GUIDELINES[guideline]
        schema = self.schema(relative)
        with self._lock:
            ok = schema.validate(doc)
            errors = [] if ok else [f"line {e.line}: {e.message}" for e in schema.error_log]
        return profile, errors


def parse_xml(data):
    from lxml import etree

    return etree.fromstring(data, etree.XMLParser(resolve_entities=False, no_network=True)).getroottree()


def xtext(doc, path):
    return [e.text or "" for e in doc.xpath(path, namespaces=NS)]


def xtext1(doc, path, default=None):
    """Text of the first match of `path` (relative to the root element)."""
    values = xtext(doc, path)
    return values[0] if values else default


def dec(value, default=None):
    try:
        return Decimal(str(value).strip())
    except (InvalidOperation, ValueError, TypeError):
        return default


# ---------------------------------------------------------------- Mustang

_RULE_LEADING = re.compile(r"^\s*\[([A-Za-z][A-Za-z0-9-]*)\]")
_RULE_ID = re.compile(r"\[ID ([A-Za-z][A-Za-z0-9-]*)\]")
_MESSAGE = re.compile(r"<(error|warning|notice|info)\b([^>]*)>(.*?)</\1>", re.S)
_STATUS = re.compile(r'<summary status="(\w+)"')


def _unescape(text):
    return text.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"').replace("&apos;", "'").replace("&amp;", "&")


def parse_mustang_report(report):
    """Status and messages of a Mustang validation report.

    Every <error> counts, whatever its type. In particular the XRechnung
    Schematron (BR-DE-*, PEPPOL-*) reports its violations as type 27: as
    <error> for an XRechnung invoice, and as <notice> (ignored) for the
    other profiles, which the XRechnung rules do not apply to. Type 18 is
    the XSD check. The rule id is the leading [BR-..] of the message or,
    without one, its [ID ..].
    """
    if "<crash>" in report:
        return {"status": "crash", "errors": {"MUSTANG-CRASH": _unescape(report)[:500]}, "warnings": []}
    status = _STATUS.findall(report)
    errors, warnings = {}, []
    for kind, attrs, body in _MESSAGE.findall(report):
        text = re.sub(r"\s+", " ", _unescape(body)).strip()
        type_ = re.search(r'type="(\d+)"', attrs)
        type_ = type_.group(1) if type_ else "?"
        if type_ == "18":
            rule = "XSD"
        else:
            m = _RULE_LEADING.match(text) or _RULE_ID.search(text)
            rule = m.group(1) if m else "?"
        if kind == "error":
            errors.setdefault(rule, text[:400])
        elif kind == "warning":
            warnings.append(f"{rule}: {text[:200]}")
    return {"status": status[-1] if status else "?", "errors": errors, "warnings": warnings}


class Mustang:
    """Mustang's validator in one long-lived JVM (tools/zugferd/java).

    `submit(path)` returns a Future of the parsed report; files are validated
    one after the other in submission order, while the caller goes on (for
    example compiling the next documents).
    """

    def __init__(self, jar, cache_dir):
        self.jar = Path(jar)
        self.classes = self._compile(Path(cache_dir))
        self.log = open(Path(cache_dir) / "mustang-stderr.log", "w")
        java = _java_tool("JAVA_BIN", "java")
        cmd = [java, "-Djava.awt.headless=true", "-cp", f"{self.jar}{os.pathsep}{self.classes}", "MustangBatch"]
        try:
            self.proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=self.log,
                text=True,
                encoding="utf-8",
                bufsize=1,
            )
        except FileNotFoundError:
            raise ToolError(f"java not found ({java}); set JAVA_BIN or JAVA_HOME")
        self.pending = {}
        self.lock = threading.Lock()
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()

    def _compile(self, cache_dir):
        source = HERE / "java" / "MustangBatch.java"
        key = hashlib.sha256(source.read_bytes() + str(self.jar).encode() + str(self.jar.stat().st_size).encode())
        out = cache_dir / "java" / key.hexdigest()[:16]
        if (out / "MustangBatch.class").exists():
            return out
        tmp = out.with_name(out.name + ".tmp")
        shutil.rmtree(tmp, ignore_errors=True)
        tmp.mkdir(parents=True)
        javac = _java_tool("JAVAC_BIN", "javac")
        try:
            proc = subprocess.run(
                [javac, "-nowarn", "-cp", str(self.jar), "-d", str(tmp), str(source)],
                capture_output=True,
                text=True,
            )
        except FileNotFoundError:
            raise ToolError(f"javac not found ({javac}); set JAVAC_BIN or JAVA_HOME (a JDK is needed)")
        if proc.returncode != 0:
            raise ToolError("compiling MustangBatch.java failed:\n" + proc.stderr)
        shutil.rmtree(out, ignore_errors=True)
        tmp.rename(out)
        return out

    def _read(self):
        current, body = None, []
        for line in self.proc.stdout:
            if line.startswith("@@@FILE "):
                head = line[len("@@@FILE "):].rstrip("\n")
                path, _, millis = head.rpartition(" ")
                current, body = (path, int(millis) if millis.isdigit() else 0), []
            elif line.startswith("@@@END") and current:
                path, millis = current
                result = parse_mustang_report("".join(body))
                result["ms"] = millis
                with self.lock:
                    future = self.pending.pop(path, None)
                if future:
                    future.set_result(result)
                current = None
            else:
                body.append(line)
        # The JVM ended: fail whatever is still waiting.
        with self.lock:
            pending, self.pending = self.pending, {}
        for future in pending.values():
            future.set_exception(ToolError("the Mustang JVM stopped; see mustang-stderr.log in the build dir"))

    def submit(self, path):
        path = str(Path(path).resolve())
        future = Future()
        with self.lock:
            if self.proc.poll() is not None:
                raise ToolError("the Mustang JVM is not running; see mustang-stderr.log in the build dir")
            self.pending[path] = future
            self.proc.stdin.write(path + "\n")
            self.proc.stdin.flush()
        return future

    def close(self):
        try:
            self.proc.stdin.close()
        except OSError:
            pass
        self.proc.wait(timeout=60)
        self.reader.join(timeout=10)
        self.log.close()
