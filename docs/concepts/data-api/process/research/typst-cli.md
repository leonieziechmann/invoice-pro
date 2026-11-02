# Research: Typst CLI and data loading

Phase-1 reader `typst-cli` of the data-API exploration (2026-11-02). Facts marked [v] were verified (read or run), [i] are inferences. `<repo>` is the repository root, `<session>` the scratch directory of the exploration (not part of the repository).

## Summary

I ran experiments on typst 0.15.1 and 0.14.2 and checked the 0.13, 0.14, 0.15.0 and 0.15.1 changelogs.

1. **Inputs are strings, and decode differs by version.** On the CLI, `sys.inputs` is always a dictionary of strings. Inline JSON has to be decoded with `json(bytes(s))`, because `json(s)` treats the string as a file PATH. `json.decode` gives a warning in 0.14.2 and is a hard error in 0.15 (removed), so `json(bytes(..))` is the only form that works on both.
2. **No Typst size limit, but the OS caps inline data.** Linux allows at most 128 KiB−1 per argument (2 MiB in total), so inline `--input` JSON is only practical for small data or overrides. Anything larger should be a file.
3. **A package cannot read the user's files from a string path.** String paths resolve relative to the file that calls `json()`/`image()`. Inside a package that is the package root, so this fails on both versions. Two portable fixes:
   - the skeleton reads the file and passes bytes (`read(p, encoding: none)`);
   - on 0.15 the skeleton passes a `path` value. The new `path` type resolves against the user's project and crosses package boundaries.
4. **User-file rules keep user-file paths.** A closure written in the user's file keeps resolving paths against that file, even when invoice-pro calls it. This is the right mechanism for "coat of arms (Wappen) by postal code" style rules.
5. **Stdin.** It works through `/dev/stdin` with `--root /` (POSIX only). A generated main file can also be piped in with `typst compile -`, and it can import the skeleton.
6. **No format gives exact money values.** JSON numbers become floats (integers only up to i64). Only TOML gives native dates; TOML offset datetimes leak as `{"$__toml_private_datetime": ..}`. CBOR tags are rejected, and no format yields `decimal`. Money therefore has to travel as strings and be converted with `decimal(str)`. The existing `coercion.to-decimal` is lossy for floats (`49.90` → `49.899999999999999`), while `decimal(str(x))` gives back exactly `49.9`.
7. **Decode speed doesn't matter.** JSON decodes at about 20 ms/MB and CBOR is no faster; YAML and TOML are 4–5× slower. That is negligible next to rendering: the template takes about 530 ms, of which `eval` is 485 ms (package import ~165 ms + `invoice()`/weave ~290 ms) and layout ~80 ms. Each line item adds roughly 15 ms.
8. **Batch generation.**
   - Several invoices with pagebreaks in one document work, with correct per-invoice totals. With ZUGFeRD on, it fails with "attempted to attach file factur-x.xml twice".
   - 0.15's experimental bundle export writes one PDF per invoice, each with its own `factur-x.xml`. It can also write a computed JSON file alongside in the same compile.
   - Throughput for 20 invoices on 4 cores: 9.1 s with sequential processes, 4.95 s as one bundle, 3.0 s with 4 parallel processes, about 2.1–2.5 s with 4 parallel bundles.
9. **Getting computed values back out.** `typst query` (0.14; deprecated in 0.15) and `typst eval` (0.15) each cost a full compile. Every encoder writes decimals and dates in Typst's own notation (e.g. `decimal("12.30")`), so the package should emit labelled metadata containing plain strings. `typst eval` without `--in` can import the package in about 150 ms, with no layout, which suits dumping a schema or validating data.
10. **Feature detection.** Checking `sys.version >= version(0,15,0)` with lazily evaluated branches works on 0.14. `"asset" in dictionary(std)` detects bundle mode.

## Key facts

- [v] sys.inputs is a dictionary of strings on the CLI in both versions; '--input k=v' values like 42/true/empty are str. Repeated keys: last wins. Keys can be any string (dots, brackets, umlauts), whitespace around the key/value is trimmed, an empty key is rejected, and a missing '=' is rejected. (exp/typst-cli/e1.typ, e1c.typ, gotchas/proj/keys.typ (outputs: {"recipient.zip":"80331","items[0].price":"1","Größe":"x","sp":"y"}); docs https://typst.app/docs/reference/foundations/sys/ ('The value is always of type string'))
- [v] json(str) interprets the string as a PATH; inline JSON text must be decoded with json(bytes(s)). Same for yaml/toml/cbor/csv/xml. (proj/main.typ case B2 (json(sys.inputs.data) -> file not found) vs case I (json(bytes(..)) -> {"where":"inline"}); 0.13 changelog: data functions 'now support a path string or bytes' https://typst.app/docs/changelog/0.13.0/)
- [v] json.decode: deprecated in 0.13/0.14 (warning 'it will be removed in Typst 0.15.0'), REMOVED in 0.15 (error: function `json` does not contain field `decode`). Same for cbor/csv/toml/xml/yaml/image .decode. (e1b.typ on both binaries; https://typst.app/docs/changelog/0.15.0/ Removals section)
- [v] --input size: Typst imposes no limit, but Linux execve limits a single argv string to 131072 bytes incl. NUL (MAX_ARG_STRLEN); 'data=' + 131066 chars worked, 131067 failed with 'Argument list too long'. Total ARG_MAX=2 MiB (17×120 KB inputs = 2.04 MB worked). (exp/typst-cli/e2.typ loop; getconf ARG_MAX=2097152)
- [i] Windows caps the whole command line at 32,767 chars, and macOS ARG_MAX is about 1 MiB in total. (OS documentation knowledge; not tested here)
- [v] Relative data paths resolve against the .typ file that calls json()/read()/image(), not against the CWD. A leading '/' means relative to the project (or package) root, NOT the filesystem root. Filesystem-absolute paths only work with --root / . Paths escaping the root error. (gotchas/proj/load.typ: data=/abs/path -> 'file not found (searched at <root>/abs/path)'; ../outside.json -> 'would escape the project root'; with --root parent both work; proj/sub/load.typ with data=in.json searched proj/sub/in.json)
- [v] A string path handed to a package (or read by the package from sys.inputs) resolves inside the PACKAGE, on both 0.14 and 0.15, and fails with a hard error (no try/catch in Typst). (proj/main.typ cases B, B2: 'file not found (searched at .../pkgs/local/datapkg/0.1.0/data/inv.json)'; case F: '/data.json' in package -> package-root file)
- [v] Portable workaround on 0.14 and 0.15: the user file reads bytes and hands them to the package: (pkg.load)(read(sys.inputs.data, encoding: none)). (proj/main.typ case C -> 'project data/inv.json' on both versions)
- [v] 0.15 adds a `path` type: path(str) in the user file resolves against the user project, and the value can be passed into a package, which loads the user's file with plain json(p)/image(p). Limits: repr hides the root (a package-constructed path has the same repr as a user-constructed one, but they compare unequal and load different files); str(path), path+str and field access all error; it rejects backslashes and '..' escapes; 'C:/x' and URLs are accepted as weird relative paths. (proj/paths2.typ: user-path-loads='project data/inv.json', pkg-path-loads='package data/inv.json', equal=false, both repr 'path("/data/inv.json")'; https://typst.app/docs/reference/foundations/path/ ; 0.15 changelog Foundations)
- [v] On 0.14, `path` is the deprecated drawing element: path("x.json") warns 'the path function is deprecated, use curve' and errors 'expected array, found string'. "path" in dictionary(std) is TRUE on 0.14, so feature detection must use sys.version (or str(type(x)) == "path"), not presence in std. (proj/main.typ case D/H on 0.14.2 (type(path) = function); featdetect/p14.typ)
- [v] Version-gated code is safe: branches are evaluated lazily, so `if sys.version >= version(0,15,0) { std.path(..) / dict.filter / int.max / range(inclusive:) }` compiles and runs on 0.14.2 when the branch isn't taken. (featdetect/fd.typ: identical results on both binaries; proj/detect.typ (path on 0.15, bytes on 0.14, same loaded data))
- [v] A closure DEFINED in the user's file but CALLED inside the package resolves image()/json() paths relative to the USER file, on both versions. image(str) called from package code resolves to the package's file. (proj/rule.typ: user wappen/80331.svg (80px -> 60pt) was loaded via (dp.apply-rule)(data, d => image("wappen/"+d.zip+".svg")); proj/rule2.typ: package-side image(str) loaded package's 99px SVG (74.25pt))
- [v] stdin: '--input data=-' is just the string "-" (no special meaning). read("/dev/stdin") or /proc/self/fd/0 works only with --root / (POSIX only). The MAIN source can be piped: `typst compile - out.pdf` / `typst query -`; relative imports from the stdin source resolve against CWD (or --root), and '-' as output writes the PDF to stdout. (exp/typst-cli/stdin/\*: both versions; without --root it searched <dir>/dev/stdin)
- [v] JSON numbers: integer for whole numbers within i64, float otherwise (1.0, 1e2 -> float; 9223372036854775808 -> float 9.223372036854776e18). 12.30 -> float 12.3 (trailing zero lost). 0.1+0.2 = 0.30000000000000004. Identical on 0.14 and 0.15. (formats/fmt.typ + fmt-results.txt (diff: json IDENTICAL))
- [v] Only TOML yields native datetime (date, time, local datetime). A TOML offset datetime (2026-11-02T10:30:00+01:00) decodes to a leaky dict {"$\_\_toml_private_datetime": "..."}. YAML timestamps and JSON dates are strings. YAML 'yes' stays a string (YAML 1.2). TOML/YAML/JSON big ints beyond i64 become floats. (formats/fmt-results.txt (toml, yaml sections), both versions identical)
- [v] CSV gives only strings (array of arrays, or dicts with row-type: dictionary); the delimiter is configurable and quoting works. XML gives {tag, attrs, children}; 0.15 adds a `namespace` field (0.14 lacks it; both strip the prefix from tag). CBOR: plain maps/ints/floats/bytes work; any CBOR tag (decimal fraction tag 4, bignum tag 2, datetime tags 0/1) fails: 'invalid type: enum'. (formats/fmt-results.txt (xml DIFF only in namespace; cbor-tags error on both))
- [v] No data format yields Typst `decimal`. decimal("12.30") keeps the scale (repr decimal("12.30"), displays 12.30). decimal(float) is exact-binary and lossy (decimal(12.3) = 12.300000000000000710542735756). decimal(str(float)) uses the shortest round-trip repr (12.3, 1.005). decimal() rejects '12,30', '1e3', leading spaces, and more than 28-29 digits. decimal+float and decimal\*float error. calc.round on decimal rounds half away from zero (1.005 -> 1.01, 2.5 -> 3, -2.5 -> -3); the float version gives 1.0. (decimal/dec.typ (out-typst.txt == out-typst-0.14.2.txt) and eval one-liners)
- [v] The repo's coercion.to-decimal (src/utils/coercion.typ:3-19) handles str/int/decimal exactly but converts floats via calc.round(decimal(value), digits: 15). Common prices come out slightly off: 12.30 -> 12.300000000000001, 49.90 -> 49.899999999999999, 19.99 -> 19.989999999999998, 123456789012.345 -> 123456789012.345001220703125. decimal(str(x)) is exact for all of them. The template's rendered/XML totals were still correct (6477.30 etc.), so the error is latent precision only. (typst eval --root <repo> '{ import "/src/utils/coercion.typ": to-decimal; ... }' (same on 0.14.2 via stdin query))
- [v] Output encoders (json.encode / yaml.encode / toml.encode, and the query/eval JSON serializer) write decimal, datetime, duration, length, color, label and version as Typst repr STRINGS (e.g. "decimal(\"12.30\")", "datetime(year: 2026, month: 11, day: 2)"). bytes -> "bytes(N)"; content -> {func, children...}. Same on both versions. (extract/ser.typ outputs)
- [v] `typst query` exists in both, but is deprecated in 0.15 (warning + hint to use `typst eval 'query(<r>).first().value' --in file`). `typst eval` exists only in 0.15 ('unrecognized subcommand' in 0.14.2). 0.15.1 changelog: eval exits 1 on evaluation failure. (CLI help of both binaries; https://typst.app/docs/changelog/0.15.1/)
- [v] `typst eval` without --in can import @preview packages: `typst eval '{ import "@preview/invoice-pro:0.6.0": unit; ... }'` took 148 ms median with no layout. The 0.14 equivalent is `typst query -` with a stdin stub (147 ms). (extract/: timeit runs)
- [v] invoice-pro today exposes metadata labels <ip-issue> (src/validation/render.typ:34), <ip-invoice-start>/<ip-invoice-end> (src/theming/frame.typ:679, 861) and <ip-report>, but no totals. Totals can be recovered from the ZUGFeRD attachment: in 0.15 `typst eval` can xml(query(pdf.attach).first().data) and read the MonetarySummation (Line 6477.30, TaxBasis 6442.30, Grand 7654.43). In 0.14, query --field data only yields "bytes(12519)". (inv/template.typ eval/query runs)
- [v] Several invoice() calls in one document (pagebreak between them, zugferd: none) compile on both versions with correctly isolated totals (verified against Python Decimal sums). PDF title = last invoice's (set document, last one wins, src/components/root.typ:596). With zugferd on, it fails: 'attempted to attach file factur-x.xml twice' (src/components/root.typ:542). (batch/batch.typ with b2.json; z2 run)
- [v] 0.15 bundle export (experimental: --features bundle --format bundle): wrapping each invoice in document(nr + ".pdf")[invoice(..)] produces one PDF per invoice. Each PDF has the correct title and totals and its OWN factur-x.xml (TaxBasis matches per invoice). --pdf-standard a-3b applies to every bundle PDF (pdfaid 3B). `context asset("x.json", json.encode(...query...))` writes a computed JSON file alongside the PDFs in the same compile. document() outside the bundle target errors in 0.15 ('only supported in the bundle target') and in 0.14 ('can only be used in set rules'). Introspection, counters and states are GLOBAL across the bundle (docs). (batch/bundle.typ, out-bundle-zf/, out-a3b/, sidecar.typ -> out-sidecar/invoice.json; https://typst.app/docs/reference/bundle/)
- [v] `"asset" in dictionary(std)` is true only when the bundle feature is enabled (0.15 + --features bundle), so it can detect bundle mode. A portable helper (bundle mode -> document() per invoice, else pagebreak) works on 0.14 (3 pages), 0.15 PDF (3 pages) and 0.15 bundle (A.pdf, B.pdf, C.pdf). (featdetect/batch-helper.typ)
- [v] --pages only filters the export; the whole document is still compiled (b10: 2445 ms full vs 2341 ms --pages 3). (batch/ timing)
- [v] --creation-timestamp / SOURCE_DATE_EPOCH pins datetime.today(), which is invoice()'s default `date` (src/invoice.typ:90). Works on both versions, giving reproducible batch and test output. (extract/today.typ)
- [v] JSON with a UTF-8 BOM fails on both versions (0.15 adds a hint). CSV and YAML strip the BOM. Workaround: json(bytes(read(p).trim("\u{feff}", at: start))). (formats/bom.\*)
- [i] Embedders: the CLI wraps every --input as a string Value, but the Rust API `Library::builder().with_inputs(Dict)` accepts arbitrary Typst Values (dict, int, decimal...). typst-py exposes sys_inputs as Dict[str, str] (documents the json(bytes(sys.inputs.x)) idiom) and has a reusable Compiler class. (typst-cli world.rs snippet https://github.com/typst/typst/blob/fb399a003c273acc40d3391e2684896d2682bc77/crates/typst-cli/src/world.rs ; https://typst-py.readthedocs.io/en/latest ; https://docs.rs/typst-as-lib/0.17.0/typst_as_lib/struct.TypstEngine.html)

## Implications

- Data entry point: use ONE loader that accepts (a) a dictionary (already decoded, also what Rust embedders can pass via sys.inputs), (b) bytes (raw JSON), or (c) on 0.15 a `path` value. A plain string should be read as JSON TEXT only if it starts with '{' or '['. Otherwise treat it as a path to be resolved BY THE USER FILE: a package cannot resolve it, so the docs pattern is `hydrate(read(sys.inputs.data, encoding: none))` or `hydrate(path(sys.inputs.data))` on 0.15.
- Use JSON as the canonical wire format: fastest decoder (~20 ms/MB), universal for phase-2 bindings, and json(bytes(..)) is identical on 0.14 and 0.15. Allow YAML/TOML only as convenience (4-5× slower; TOML offset-datetime quirk). CBOR brings no speed gain and rejects tags, so skip it.
- Money and quantities: the format should REQUIRE decimal strings ("12.30") for amounts, prices, quantities and rates. If JSON numbers are accepted, convert floats with decimal(str(x)), not the current coercion.to-decimal float path, which yields 49.899999999999999 for 49.90. Validate strings with a regex before calling decimal() (no try/catch: invalid strings like '12,30' abort the compile).
- Dates: use ISO strings 'YYYY-MM-DD' parsed in the package (JSON and YAML give strings, and only TOML gives datetime), so one parsing path serves all formats. Set --creation-timestamp/SOURCE_DATE_EPOCH for reproducible output when date is omitted.
- Extensibility / conditional rules (Wappen by postal code): implement rules as Typst closures written in the USER skeleton (e.g. `rules: (recipient-zip: z => image("wappen/" + z + ".svg"))`). Experiments prove that paths inside such closures resolve against the user's file even when the package calls them. Custom fields can travel as an open `custom`/`extra` dictionary in the JSON and be read by those closures.
- Inline `--input data='{...}'` is fine for small payloads and overrides (≤128 KiB per argument on Linux, ~32K chars total on Windows); recommend file paths for real use. Stdin works via `--root / --input data=/dev/stdin` (POSIX), or by piping a generated main .typ via `typst compile -` that imports the skeleton. The latter is a good phase-2 trick (data embedded as a Typst literal; no file needed).
- Package-level auto-hydration from sys.inputs is possible (packages CAN read sys.inputs, e.g. a namespaced key like `invoice-pro`), but only inline JSON. File paths must be resolved by the user file. Namespace the key to avoid clashing with the user's own inputs.
- Speed: data decoding is <1% of a compile. Cost is package import ~165 ms + invoice()/weave ~290 ms + layout ~80 ms + ~15 ms per line item. Hydration should therefore avoid extra loom passes and per-item overhead; parse speed is irrelevant. Process startup is ~15 ms; system-font discovery adds ~50-95 ms (--ignore-system-fonts / --font-path help when fonts are known).
- Batch: for e-invoices (ZUGFeRD) one PDF per invoice is mandatory (multi-invoice PDF errors on the duplicate attachment). Best throughput is parallel processes, or on 0.15 parallel _bundle_ processes (each bundle = several invoices sharing one package import). Document the portable helper: bundle mode -> document(nr + ".pdf") per invoice; otherwise pagebreak (non-ZUGFeRD only).
- Extraction for tests and phase 2: add a labelled metadata (e.g. <invoice-pro:result>) with JSON-friendly values (str(decimal), date.display("[year]-[month]-[day]"), plain strings). The built-in serializers otherwise emit Typst repr strings like "decimal(\"12.30\")". Readable with `typst query` (0.14, still works but warns in 0.15) or `typst eval` (0.15); both cost a full compile. On 0.15 bundle mode, the same values can be written to a JSON file alongside the PDF in the same compile.
- Machine-readable schema for phase 2: expose it as a Typst value (e.g. `invoice-pro.data-schema`), dumpable without layout via `typst eval 'import "@preview/invoice-pro:X": data-schema; data-schema'` (0.15, ~150 ms) or a `typst query -` stdin stub (0.14). The same route allows fast data validation before rendering.
- Compatibility: keep compiler = 0.14.0 and gate 0.15 extras (path type, bundle) behind `sys.version >= version(0,15,0)` and `"asset" in dictionary(std)`, using lazy branches. Never reference json.decode (removed in 0.15), and never rely on `"path" in std` (true on 0.14 for the deprecated drawing element).

## Risks

- Hard errors, no recovery: Typst has no try/catch. A bad path, an invalid decimal string, a BOM in JSON, or a type mismatch aborts the whole compile, which in batch mode loses every invoice in that process. A validator must pre-check strings (regex) and report issues instead of calling decimal()/datetime() blindly.
- String-path confusion: json("...") inside the package silently means 'package file'. If the hydration API accepts path strings, users will hit 'file not found (searched at …/invoice-pro/0.6.0/…)'. The API must make the user file do the reading (bytes or path value).
- 0.15 `path` values have an opaque repr (same repr for user- and package-rooted paths), no str() conversion and no join. They are useful only to pass through to json()/read()/image(); the package cannot inspect or log them.
- The existing coercion.to-decimal float path is imprecise (12.3 -> 12.300000000000001). Feeding JSON numbers through it may cause off-by-ε amounts in XML or comparisons. Rendering looked correct in the template, but this is a latent risk for programmatic data.
- TOML offset datetimes decode to {"$\_\_toml_private_datetime": …} (both versions), a leaky internal representation. Big integers beyond i64 silently become floats in JSON, YAML and TOML.
- Multi-invoice single PDF + ZUGFeRD = hard error. set document is last-wins, so the metadata of earlier invoices is lost. Bundle export is experimental ('do not rely on this feature for production'), 0.15-only and CLI-only (not in the web app). Its introspection, counters and states are global across documents (worked for invoice-pro here, but future loom changes could leak state between bundled invoices).
- Windows: no /dev/stdin, a ~32K command-line limit (OS fact, not tested), shell quoting of JSON in --input is painful, and 0.15 rejects backslashes in Typst paths. Recommend file paths with forward slashes.
- OS argv limits: Linux 128 KiB per argument (verified). Large inline JSON fails with 'Argument list too long' before Typst even starts.
- `typst query` is deprecated in 0.15 and may be removed later. Scripts/bindings must switch to `typst eval` by version (eval doesn't exist in 0.14).
- Extracting computed data costs a second full compile (query/eval ≈ compile time) unless the bundle JSON-file trick (0.15 experimental) is used.

## Open questions

- Should the hydration API accept plain JSON numbers for money at all, or require decimal strings (and reject floats with a validation issue)? If accepted, should coercion.to-decimal's float branch switch to decimal(str(x)) (a behaviour change of an internal util, which affects Typst-literal prices like 49.90 too)?
- Should the package auto-read a namespaced sys.inputs key (e.g. `invoice-pro`) when no data is passed explicitly (zero-code CLI hydration for inline JSON), or must the user skeleton always opt in explicitly (needed anyway for file paths)?
- Is bundle export worth supporting officially in phase 1 (big batch win plus a JSON file next to the PDF), given it is experimental and 0.15-only? Or should it just be documented as an optional pattern with the portable fallback helper?
- Which result metadata label/shape should be the stable contract for phase 2 (totals, tax breakdown, issues, invoice-nr), and should it always be emitted or only when requested (e.g. via sys.inputs flag) to avoid extra introspection cost?
- Do other loom-focused explorations find that a data-driven invoice() can skip one of the 2 weave passes? Per-item cost (~15 ms) and weave (~290 ms) dominate, so that is where 'fast' must be won, not in parsing.
- For phase 2, will bindings embed typst as a library (warm cache: watch recompile showed ~280 ms vs ~420 ms cold, i.e. the ~140 ms package import is amortised) or shell out to the CLI? This decides whether non-string sys.inputs values (Rust Dict) should be accepted by the loader.

## Measurements

- Machine: 4 vCPU Linux; medians of N runs via python perf_counter (script: exp/typst-cli/timeit.py). Root E=<session>/exp/typst-cli
- Process startup: `typst --version` 3.3 ms (0.15) / 3.7 ms (0.14). Trivial doc `typst compile empty.typ /dev/null -f pdf`: 64.5 ms (0.15) / 76.6 ms (0.14) with system fonts; 16.5 / 19.2 ms with --ignore-system-fonts.
- Decode cost (`typst compile --ignore-system-fonts load.typ /dev/null -f pdf --input f=<file>`, 0.15 / 0.14 medians incl. ~17 ms base): small.json 4 KB 17.4/17.4 ms; 1mb.json (1,024,780 B) 37.1/42.8 ms; 5mb.json (5,165,082 B) 112.3/123.2 ms; 1mb.yaml 122.2/113.9; 5mb.yaml 450.4/472.7; 1mb.toml 156.2/109.9; 5mb.toml 497.8/582.7; 1mb.cbor (749,959 B) 44.3/42.4; 5mb.cbor (3.77 MB) 140.3/129.1. 5mb.json + decimal(price)\*decimal(qty) sum over 26,500 items: 229.6/220.4 ms.
- Template invoice (repo template/invoice.typ, 1 page, zugferd en16931): `typst compile template.typ /dev/null -f pdf` 595.7 ms (0.15) / 600.5 ms (0.14); with --ignore-system-fonts 500.3 / 522.1 ms; -j1 567.4 / 577.8 ms.
- Timings trace (`typst compile --ignore-system-fonts --timings trace15.json template.typ`): compile 564.6 ms = eval 485.0 ms [lib.typ import 172.5 ms, of which src/invoice.typ module 134.1; invoice() call at src/invoice.typ:44 289.2 ms; item() calls 11 ms] + layout iter(1) 70.1 ms + iter(2) 9.3 ms; pdf export 11.3 ms. Import-only doc (`#import "@preview/invoice-pro:0.6.0": *`): 138.4 ms (0.15) / 155.9 ms (0.14), eval 163.8 ms in trace.
- Line-item scaling (batch.typ, 1 invoice, zugferd none, 0.15): 1 item 280 ms; 10 items 426 ms; 50 items 1059 ms; 200 items 3307 ms (trace: eval 1850 ms, iter1 676 ms, iter2 719 ms, iter3 12 ms, pdf 34 ms) ≈ 15 ms per item.
- Multi-invoice single document (8 items each, zugferd none, `typst compile --ignore-system-fonts batch.typ /dev/null --input data=bN.json`), 0.15 / 0.14: n=1 378/388 ms; n=2 620/623; n=5 1331/1311; n=10 2330/2694; n=20 4787/5255 ms → ≈232 ms marginal per invoice.
- 20 ZUGFeRD invoices (0.15): 20 sequential processes 9070 ms (single standalone 422 ms median); `seq 0 19 | xargs -P4 typst compile -j 1 ...` 3022 ms (3002 ms with default -j); one bundle `typst compile --features bundle --format bundle bundle.typ out --input data=b20.json --input zugferd=en16931` 4953 ms (n=5 1355, n=10 2523); 4 parallel bundles × 5 invoices 2116–2504 ms.
- typst watch warm recompile after atomically replacing data.json (watch/drive.py): initial 390 ms (0.15) / 428 ms (0.14); subsequent recompiles 276–336 ms (0.15), 280–360 ms (0.14) including watcher debounce.
- Extraction cost (0.15): `typst eval 'query(<ip-issue>).len()' --in template.typ` 544.6 ms vs compile 533.8 ms; 0.14 `typst query template.typ '<ip-issue>'` 547.2 ms; `typst eval '1+1'` 5.4 ms; `typst eval '{ import "@preview/invoice-pro:0.6.0": unit; ... }'` 147.9 ms; 0.14 `typst query -` stdin stub importing package 147.4 ms.
- --pages subset still compiles everything: b10 full 2445 ms vs --pages 3 2341 ms.
- Export variants (0.15, template): PNG page 1 620.9 ms; --pdf-standard a-3b 517.2 ms; --no-pdf-tags 590.9 ms (noise-level differences).

## Notes

#### Setup

- Binaries: typst 0.15.1 (9dfd3a08), typst 0.14.2 (b33de9de). invoice-pro is linked as @preview/invoice-pro:0.6.0 → <repo> (repo untouched; `git status` clean).
- All experiment files: `E=<session>/exp/typst-cli` (subdirs: proj+pkgs = path tests with a fake `@local/datapkg:0.1.0` package via `--package-path $E/pkgs`; formats; decimal; perf; inv; batch; watch; extract; featdetect; gotchas; stdin). Helpers: `$E/timeit.py` (median timer), `$E/trace_agg.py` (aggregates `--timings` B/E events).
- Gotcha while writing tests: in markup mode, `#let x = if a {..}` followed by `else if` on the NEXT line silently ends the expression (the else becomes text). Multi-line if/else chains must be inside a `{ }` code block. Also `none` cannot be a dict key in literal syntax, and keys containing `.` must be quoted.

#### (1) sys.inputs

| Aspect             | 0.14.2                                                                                             | 0.15.1                                                                             |
| ------------------ | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Type               | `dictionary` of `str`                                                                              | same                                                                               |
| `--input num=42`   | `"42"` (str)                                                                                       | same                                                                               |
| empty value `k=`   | `""`                                                                                               | same                                                                               |
| repeated key       | last wins                                                                                          | same                                                                               |
| key chars          | anything (`recipient.zip`, `items[0].price`, `Größe`), trimmed                                     | same                                                                               |
| `=empty`           | CLI error: key missing or empty                                                                    | same                                                                               |
| `noequals`         | CLI error                                                                                          | same                                                                               |
| value with `=`     | `a=b=c` → `{a: "b=c"}`                                                                             | same                                                                               |
| env var for inputs | none (no `[env:]` in --help)                                                                       | none                                                                               |
| decode JSON text   | `json(bytes(s))` ✔; `json.decode(s)` ✔ + deprecation warning ("will be removed in Typst 0.15.0") | `json(bytes(s))` ✔; `json.decode` ✘ `function json does not contain field decode` |
| `json(s)`          | s = PATH                                                                                           | s = PATH                                                                           |

Size: Linux MAX_ARG_STRLEN = 131072 bytes per argv string (incl. NUL). `data=` + 131066 chars OK, more → `Argument list too long` (a shell/OS error; Typst never starts). ARG_MAX 2 MiB total (17 inputs × 120 KB = 2.04 MB worked). From OS docs, not tested: Windows ~32,767-char command line, macOS ARG_MAX ~1 MiB.

Embedders (web evidence): the CLI converts inputs with `v.as_str().into_value()` (typst-cli/src/world.rs), but `Library::builder().with_inputs(Dict)` takes arbitrary Values, so Rust hosts could pass structured dicts/decimals. typst-py: `sys_inputs: Dict[str, str]`, README uses `json(bytes(sys.inputs.persons))`, has a reusable `Compiler`. papermake (docs.rs) uses `json.decode(sys.inputs.data)` → would break on 0.15.

#### (2) File paths: user doc vs package

Fake package `@local/datapkg:0.1.0` (compiler = "0.14.0") with `load(src) = json(src)`. Project `proj/` with `data/inv.json`. `--input data=data/inv.json`:

| Case                                                       | 0.14.2                                                                            | 0.15.1                                                                                                      |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| A: user doc `json(sys.inputs.data)`                        | project file ✔                                                                   | ✔                                                                                                          |
| B: `(dp.load)(sys.inputs.data)` (string into package)      | ✘ file not found `…/datapkg/0.1.0/data/inv.json`                                  | ✘ same                                                                                                      |
| B2: package reads `json(sys.inputs.data)` itself           | ✘ (package-relative)                                                              | ✘                                                                                                           |
| C: `(dp.load)(read(sys.inputs.data, encoding: none))`      | ✔                                                                                | ✔                                                                                                          |
| D: `(dp.load)(path(sys.inputs.data))`                      | ✘ (`path` = deprecated drawing element: warning + `expected array, found string`) | ✔ loads project file                                                                                       |
| E: package builds `path(s)` itself                         | ✘                                                                                 | builds a PACKAGE-rooted path; repr `path("/data/inv.json")`, identical to D's repr, but `pu == pp` is false |
| F: package `json("/data.json")`                            | package root file                                                                 | package root file                                                                                           |
| I: package `json(bytes(sys.inputs.data))` with inline JSON | ✔                                                                                | ✔                                                                                                          |

Path type (0.15) probes: `str(path(..))` error ("expected integer, … or string, found path"); `path + "/b"` error; `.stem` error ("cannot access fields on type path"); `path("../x")` → "would escape the project root"; `path("a\\b")` → "must not contain a backslash"; `path("C:/x")` → `path("/C:/x")`; `path("https://x/y.json")` → `path("/https:/x/y.json")`. The docs say: "paths can be passed across package boundaries", "On its own, code in a package cannot construct a path that lives in the project". File-existence checks and directory walking are "planned".

Portable loader pattern (verified on both):

```typ
#let has-path-type = sys.version >= version(0, 15, 0)
#let src = if has-path-type { std.path(sys.inputs.data) } else { read(sys.inputs.data, encoding: none) }
#let is-pathval(x) = str(type(x)) == "path"   // don't write `type(x) == path` (0.14: path is a function)
#(dp.load)(src)   // package just calls json(src): accepts str|bytes|path
```

Closures (critical for "Wappen by PLZ"):

```typ
// user file
#let wappen-rule = d => image("wappen/" + d.zip + ".svg")
#(dp.apply-rule)(data, wappen-rule)   // package: apply-rule(data, rule) = rule(data)
```

→ loads the USER's `wappen/80331.svg` (measured 60pt = 80px), on both versions. The package-side `image("wappen/80331.svg")` loads the package's file (74.25pt). The same holds for `json()` inside a closure.

Root semantics: a relative path is relative to the calling .typ file (not CWD). A leading `/` is relative to `--root` (default: main file's dir). A filesystem-absolute path is reinterpreted under the root (`…/proj/tmp/...`). Use `--root /` to allow absolute paths (security tradeoff) or `--root <common ancestor>` + root-relative path.

#### (3) stdin

- `--input data=-` → the string `"-"` (no magic).
- `read("/dev/stdin", encoding: none)` or `/proc/self/fd/0`: works with `--root /` on both versions (compile and query). Without it: searched `<root>/dev/stdin`. POSIX only.
- Main source from stdin: `printf '#import "skeleton.typ": render\n#render((...))' | typst compile - out.pdf`. The relative import resolves against CWD; with `--root X` and `/skeleton.typ` it works from any CWD. `-` as output → PDF on stdout (`%PDF-1.7`). Works on 0.14 and 0.15. Phase-2 binding trick: generate a tiny main file embedding data as a Typst literal (e.g. `decimal("12.30")` directly) and import the user's skeleton.
- 0.14 changelog: "The CLI will now warn when trying to watch the standard input".

#### (4) Formats (identical on both versions unless noted)

JSON (`d.json`):
| JSON | Typst |
|---|---|
| 12.30 | float 12.3 |
| 0.1 / 0.2 | float; sum 0.30000000000000004 |
| 42 | integer |
| 1.0 / 1e2 | float 1.0 / 100.0 |
| 9223372036854775807 | integer |
| 9223372036854775808 / -9223372036854775809 | float ±9.223372036854776e18 |
| "12.30" | str |
| "2026-11-02" | str |
| null | none |
YAML: 12.30 float; `2026-11-02` and `2026-11-02T10:30:00Z` → str; `yes` → str (YAML 1.2); `0o17` → 15; `0x1F` → 31; anchors/refs resolved; big int → float.
TOML: `date`/`time`/local `datetime` → datetime ✔; `2026-11-02T10:30:00+01:00` → `{"$__toml_private_datetime": "2026-11-02T10:30:00+01:00"}` ✘ leak; i64 max int OK; nested tables/arrays-of-tables OK.
CSV: all strings; `delimiter: ";"`; quoted fields with delimiters OK; `row-type: dictionary` uses the header. German `12,30` stays a string.
XML: `(tag, attrs, children)`; 0.15 adds `namespace` (0.14 lacks the field; both give tag `custom` for `x:custom`). Entities decoded.
CBOR: plain map/int/float/bytes ✔; tags 0, 1, 2, 4 → `failed to parse CBOR (invalid type: enum, expected a Typst value)`.
BOM: JSON with BOM fails on both (0.15: "unexpected Byte Order Mark" + hint; 0.14: "expected value at line 1 column 1"). CSV header and YAML strip the BOM. Workaround: `json(bytes(read(p).trim("\u{feff}", at: start)))` ✔ both.

Decimal (identical on both):

```
decimal("0.1")+decimal("0.2") = 0.3        (0.1+0.2 float = 0.30000000000000004)
decimal("12.30") repr decimal("12.30"), str "12.30"; == decimal("12.3") true
decimal(0.1)   = 0.1000000000000000055511151231   (lossy)
decimal(12.3)  = 12.300000000000000710542735756
decimal(str(1.005)) = 1.005 ; decimal(repr(1.005)) = 1.005
calc.round(1.005 float, digits:2) = 1.0 ; calc.round(decimal("1.005"), digits:2) = 1.01
calc.round(decimal("2.5")) = 3 ; (-2.5) = -3   (half away from zero)
decimal("12.30")*3 = 36.90 ; decimal("19.99")*decimal("0.19") = 3.7981 → round 3.80
decimal("10")/3 = 3.3333333333333333333333333333
max decimal("79228162514264337593543950335"); +1 → invalid; scale down to 1e-28
int(decimal("12.99")) = 12 ; float(decimal("12.30")) = 12.3
errors: decimal("12,30"), decimal("1e3"), decimal(" 12.30"), decimal("abc"), decimal + float, decimal * float, decimal(1e30) ("float is not a valid decimal")
str(float) never uses exponent: str(1e-7)="0.0000001", str(1e21)="1000000000000000000000" (repr(1e-7) = "1e-7" does!) → decimal(str(x)) is the safe float→decimal path
```

Repo coercion (`src/utils/coercion.typ:3-19`): str/int/decimal exact; float → `calc.round(decimal(value), digits: 15)` then trims zeros. Measured: 12.3→12.300000000000001, 49.9→49.899999999999999, 19.99→19.989999999999998, 1234.56→1234.559999999999945, 99999.99→99999.990000000005239, 123456789012.345→123456789012.345001220703125, 0.30000000000000004→0.3. `decimal(str(x))` gives the shortest exact repr for all of them except the last (keeps 0.30000000000000004, which is the true float value).

#### (5) Decode performance

See measurements. Takeaways: JSON ≈ 20 ms/MB on top of a ~17 ms base; CBOR (smaller files) is no faster; YAML/TOML 4–5× slower. 0.14 and 0.15 are within noise. The whole decoded 5 MB (26.5k items) plus decimal math is ~230 ms, i.e. less than one invoice render.

#### (6) Batch

- Single doc, N × `invoice(...)[...]` with pagebreak: works, isolated totals (verified b2: 5963.26/5808.29 net, matches Python Decimal). Title = last invoice. With `zugferd: "en16931"` → `error: attempted to attach file factur-x.xml twice` at src/components/root.typ:542.
- 0.15 bundle (`--features bundle --format bundle`, output = directory):

```typ
#for d in all { document(d.at("invoice-nr") + ".pdf")[ #invoice(zugferd: "en16931", ...)[ ... ] ] }
#asset("manifest.json", json.encode(all.map(d => d.at("invoice-nr"))))
#context asset("invoice.json", json.encode((issues: query(<ip-issue>).len(), xml-bytes: query(pdf.attach).map(a => a.data.len()))))
```

→ 2026-0000.pdf … each 1 page, own title, own factur-x.xml with matching TaxBasisTotalAmount; `--pdf-standard a-3b` → every PDF has pdfaid 3B. Warns "bundle export is experimental … do not rely on this feature for production use cases". Introspection/counters/state are global across the bundle (docs); the page counter is per document.

- `document(..)[..]` outside bundle: 0.15 "constructing a document is only supported in the bundle target"; 0.14 "can only be used in set rules". The portable helper (verified 0.14 / 0.15 pdf / 0.15 bundle):

```typ
#let bundle-mode = "asset" in dictionary(std)
#let emit-all(items, name, render) = context {
  let in-bundle = bundle-mode and target() == "bundle"
  for (k, x) in items.enumerate() {
    if in-bundle { document(name(x))[#render(x)] } else { if k > 0 { pagebreak() }; render(x) }
  }
}
```

- Throughput (20 ZUGFeRD invoices): sequential processes 9.07 s; one bundle 4.95 s; 4 parallel processes 3.0 s; 4 parallel bundles of 5: 2.1–2.5 s. Typst eval is effectively single-threaded, so parallelism comes from processes.
- `typst watch` as a warm server: ~280 ms per recompile vs ~420 ms cold (saves import + startup). Watch reacts only to file changes, not argv, so data must be a file.
- `--deps deps.json` lists the data file and all package files (151 inputs), useful for build systems.

#### (7) Query/eval for extraction

```bash
### 0.15
typst eval 'query(<ip-issue>)' --in invoice.typ --pretty
typst eval '{ let x = xml(query(pdf.attach).first().data).first(); let find(n, tag) = if type(n) == dictionary { if n.tag == tag { (n,) } else { n.children.map(c => find(c, tag)).flatten() } } else { () }; find(x, "SpecifiedTradeSettlementHeaderMonetarySummation").first().children.filter(c => type(c) == dictionary).map(c => (c.tag, c.children.first())).to-dict() }' --in template.typ
### → {"LineTotalAmount":"6477.30","ChargeTotalAmount":"15.00","AllowanceTotalAmount":"50.00","TaxBasisTotalAmount":"6442.30","TaxTotalAmount":"1212.13","GrandTotalAmount":"7654.43","DuePayableAmount":"7654.43"}
### 0.14 (and 0.15 with deprecation warning)
typst query template.typ 'pdf.attach' --field data   # → ["bytes(12519)"]  (not usable)
typst query template.typ '<r>' --field value --one --pretty
```

Serialization of metadata values (both versions): decimal → `"decimal(\"12.30\")"`, float → number, int → number, datetime → `"datetime(year: 2026, month: 11, day: 2)"`, duration → `"duration(weeks: 2)"`, length `"12pt"`, ratio `"19%"`, color `"rgb(\"#e4572e\")"`, content → `{func: sequence, children: [...]}`, bytes → `"bytes(2)"`, label `"<foo>"`, version `"version(1, 2)"`, function `"abs"`. json.encode/yaml.encode/toml.encode behave the same (toml.encode does NOT emit a native TOML datetime). → A result-metadata API must pre-stringify decimals and dates.
Existing labels: `<ip-issue>` (validation issues), `<ip-invoice-start>`/`<ip-invoice-end>` (value = invoice index k), `<ip-report>`, `<ip-identity>`, `<ip-reserve>`; loom key `<invoice-pro:0.6.0>` (src/loom-wrapper.typ:3). No totals label today.
`typst eval` without `--in` can import packages (148 ms), giving a schema dump / validation without layout. 0.14 equivalent: `printf '#import "@preview/invoice-pro:0.6.0": x\n#metadata(x) <r>' | typst query - '<r>' --field value --one` (147 ms).

#### (8) 0.15-only features and detection (compiler floor stays 0.14.0)

From https://typst.app/docs/changelog/0.15.0/:

- `path` type (all path-taking places accept it; crosses package boundaries) — most relevant.
- `typst eval` CLI supersedes `typst query` (query deprecated).
- Bundle export (experimental): multiple PDFs/HTML/assets per compile.
- Data loading: xml namespaces; URL-looking-path hint; BOM hint for json; file paths in binary-load diagnostics.
- dict `.map`/`.filter` (callback receives VALUE only: `(a:1,b:2).filter(v => v > 1)`), `int.min`/`int.max`, `range(inclusive:)`, `int(str, base:)`, `within` selector, `target()` without the html flag, `panic` shows strings as-is (nicer user-facing validation errors on 0.15!), float determinism across platforms.
- Removals: `json.decode` & co, `path` element, `pattern`, `pdf.embed`. Backslashes in paths are now an error.
  0.14 relevant: "Improved consistency of how large numbers are handled in data loading functions", `toml` guaranteed dict, `typst query --target`, `--deps`. 0.13: data functions accept bytes, `.decode` deprecated, `decimal` ctor accepts decimals.
  0.15.1: eval exits 1 on failure; watch server Content-Type for json etc.
  Detection (verified on both): `sys.version >= version(0, 15, 0)` plus lazy branches; `"asset" in dictionary(std)` ⇔ bundle feature enabled; `str(type(x)) == "path"` to recognise path values without referencing `path` (on 0.14 `"path" in dictionary(std)` is true and `type(path)` = function).

#### Misc

- `--creation-timestamp` / `SOURCE_DATE_EPOCH` pins `datetime.today()` (invoice default `date`, src/invoice.typ:90) on both versions.
- `--pages` only filters export; full document still compiled.
- Font discovery costs ~50–95 ms per process; `--ignore-system-fonts` (+ `--font-path`) reduces startup; template warns `unknown font family: arial` (8×), which is harmless.
- `pdfinfo` prints "Syntax Error: Suspects object is wrong type (boolean)" for every Typst PDF here (incl. trivial ones). This is a Typst/poppler quirk, not related to batching.
