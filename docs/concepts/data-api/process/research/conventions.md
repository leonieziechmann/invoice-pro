# Research: Repository conventions

Phase-1 reader `conventions` of the data-API exploration (2026-11-02). Facts marked [v] were verified (read or run), [i] are inferences. `<repo>` is the repository root, `<session>` the scratch directory of the exploration (not part of the repository).

## Summary

invoice-pro has strict, written conventions. Every public name is kebab-case. A namespace is named after the parameter it feeds (theme, locale, tax, unit, references, country). Public modules are facades in src/public/\* that re-export only documented names, and tests/theme/exports/test.typ pins the root export list exactly, so any new root export (e.g. a `data` namespace) must be added there. Doc comments are `/// text` plus `/// -> type` on every parameter and above every `#let`; types are written `none | str | content` (`str` 163× against 21× `string`, never `dict`). Misuse such as unknown keys or wrong types always panics, whatever the validation level. Its messages carry a `::` path, the value, the allowed set and a did-you-mean hint (`types.require`, `utils/patch.typ fail-unknown`). Missing legally required data becomes a `data` issue that follows `invoice(validation: draft|strict|none)`. The package's own sys.inputs keys carry an `invoice-pro-` prefix (`invoice-pro-validation`). They are read through functions with an injectable `inputs: sys.inputs` parameter, because tytanic cannot pass `--input`. The closest precedent for the feature is the experimental `theme.custom.from-data(data, assets:)` (src/theming/data.typ). It takes a parsed dict, coerces strings, panics on unknown keys and loads images through a callback defined in the user's document. I verified on Typst 0.14.2 and 0.15.1 that a package cannot open a path the user passes, but can decode `json(bytes(sys.inputs.at(k)))` and bytes from `read(..., encoding: none)`. The contributing roadmap already lists the unchecked item "Data Loading: helper functions to load invoice items from JSON, CSV, or YAML". The concept document should copy the shape of docs/concepts/theming-api/README.md and keep a process/ folder (research, designs, review) as produced, with `<session>`/`<repo>` path placeholders. A concept-only PR runs only the Linter workflow (typstyle on all .typ, prettier on all markdown, nixpkgs-fmt). I ran prettier 3.6.2 (the CI version) and 3.8.1, typstyle 0.15.1 (the CI version) and check-docs-examples: the repo is clean today. Branch names for big features follow `feature-<topic>` (`feature-theming-api`, `feature-zugferd-validation`).

## Key facts

- [v] Root exports are pinned by a test: tests/theme/exports/test.typ asserts that dictionary(lib).keys() equals a hard-coded list (apply, bank-details, …, theme, themed, unit). Any new top-level export fails it unless the list is updated, and the same applies to the theme, custom and layout sub-modules. (tests/theme/exports/test.typ:1-55)
- [v] Namespace rule: 'one rule: the namespace is named after the parameter' (theme param → theme namespace; theme.layout and theme.custom mirror locale.region and locale.custom). (docs/concepts/theming-api/README.md:38; src/public/theme.typ:1)
- [v] Public API is exposed through facade modules in src/public/ that re-export only documented names, so internal helpers do not leak. lib.typ imports them as namespaces (theme, tax, country, id, unit, references, info). (src/lib.typ:1-28; src/public/custom.typ:1-4)
- [v] Doc-comment style: `/// description` then `/// -> type` per parameter, `/// -> content` above the function. Deprecated parameters are marked inline: `/// -> none | string | content (deprecated)` (the only deprecation in src). (src/invoice.typ:40-90 (deprecated at :85); src/components/payment-terms.typ:29-52)
- [v] Type spelling in doc comments: `str` 163×, `string` 21×, `dictionary` 114×, `dict` 0×. (grep -rhE '^\s\*/// -> ' src | tally (command in raw_notes))
- [v] All public and private top-level names are kebab-case (0 snake*case, 0 camelCase). Private helpers start with `*` (333 of 915 top-level lets). (grep '^#let' over src/\*.typ)
- [v] Panics vs issues: API misuse (unknown keys, wrong types, cycles, unknown parts, undefined geometry) never becomes an issue; it panics, because no output could honour it. Issue classes data/theme/lint follow the validation level; e-invoice rules follow zugferd-errors. (src/validation/issue.typ:1-25; docs/concepts/theming-api/README.md:47)
- [v] Misuse message format: types.require(value, "component::param", ..types) → "variable `payment-terms::days`(..) must be of ..". Strict-merge unknown key → "a::b has unknown key `k`. Did you mean `x`? Allowed keys: ..". (src/utils/types.typ:9-27; src/utils/patch.typ:81-104; src/components/payment-terms.typ:54-57)
- [v] The package-owned sys.inputs key is prefixed: `invoice-pro-validation` (public), and `ip-seal` is internal. It is read by resolve-level(param, inputs: sys.inputs), which panics on a bad value with a synonym hint. Docs examples use un-prefixed user keys (preset, output, n, qr-bill, window, proof). (src/validation/issue.typ:25-27,80-120; src/theming/access.typ:5; docs/concepts/theming-api/README.md:921,1008,1038)
- [v] Testability convention for --input: tytanic cannot pass --input, so tests call the reader with injected inputs, e.g. resolve-level("draft", inputs: (invoice-pro-validation: "strict")). (tests/validation/api/test.typ:12-22; tests/TESTING.md:421 and step 4 at :278)
- [v] Precedent: theme.custom.from-data(data, assets:) takes a parsed json/yaml/toml dict and does no eval. It coerces strings (#hex→rgb, lengths, %, "none", "auto"→reset()), panics on unknown groups and keys, and loads images via an `assets: p => image(p, ..)` callback 'because packages cannot open user paths'. Its tier is experimental. (src/theming/data.typ:1-104; docs/docs/api-reference/theme/customization.md:253-305; docs/docs/api-reference/theme/index.md:164)
- [v] A package function cannot open a file by a path the user passes. `json(p)` inside the package searches the package directory ("file not found (searched at …/pathprobe/0.1.0/src/data.json)") on 0.15.1 and 0.14.2. Passing bytes from `read(path, encoding: none)`, or decoding `json(bytes(sys.inputs.at(key)))` inside the package, works on both. (experiment <session>/exp/conventions/pathexp (by-path / by-bytes / by-input .typ))
- [v] Stability tiers documented for users: Frozen (no breaking change in 0.6.x), Stable names/evolving look, Provisional (may change in a 0.6.x minor with a changelog entry), Experimental (may change or be removed), 0.6.x preview (specified, not final), Internal. Tiers are also marked in source comments (FROZEN/STABLE/EXPERIMENTAL/PROVISIONAL) and in docs tables as a 'Tier' column or `_(Experimental)_`. (docs/docs/api-reference/theme/index.md:144-166; src/theming/presets.typ:5-111; src/public/layout.typ:4-8; docs/docs/api-reference/invoice/index.md (zugferd row))
- [v] README 'Status': the data model (line-items, item, group, bundle) is stable; the theme API is stable since 0.6.0; locale may change; e-invoicing is experimental. (README.md:158-160)
- [v] The feature is already on the public roadmap as unchecked: "Data Loading: Helper functions to load invoice items directly from JSON, CSV, or YAML data sources." Contributing rules: an issue before any PR, minimal dependencies, EU scope, assess the impact on rendering speed. (docs/docs/contributing.md:63-95)
- [v] No GitHub issue exists yet for data loading (issues and PRs #1–#53 listed). The theming concept and PR used 'Refs #18'. (gh api repos/leonieziechmann/invoice-pro/issues?state=all; git show ac4a11d)
- [v] Concept document = docs/concepts/<name>/README.md (theming: 1616 lines). It has a title line, a long Status paragraph, an Executive summary ending in 'What I need from you', a 'Design decisions at a glance' table (Decision|Choice|Why), 15 numbered sections (incl. error messages, feasibility on 0.14.2/0.15.1, performance table, trade-offs/rejected alternatives, roadmap in maintainer-days) and Appendices A (decisions Q#/open O# with _Recommendation:_), B (requirements traceability), C (changes since v1), D (process & sources). (docs/concepts/theming-api/README.md:1-60, 1269, 1335-1460, 1456-1616)
- [v] process/ keeps research (7 reports + \_digest), designs (4 proposals + 3 verdicts + \_panel-digest), review (draft-1 + 6 critiques) and phase-4 results (+ rename-map.tsv), 'kept as produced; local paths replaced by <session> and <repo>' (170 and 9 hits, no raw /home or /tmp paths). It totals about 1.7 MB. (ls docs/concepts/theming-api/process; README.md:1591-1616; grep over docs/concepts)
- [v] Concept typst blocks carry no package import (0 `@preview/invoice-pro` in the README). They use the undefined names `party` and `body(n:)`, declared in the Status line. All 20 blocks are typstyle-clean, and the implemented snippets were later ported to tests/theme/walkthroughs. (docs/concepts/theming-api/README.md:3; typstyle 0.15.1 --check on the 20 extracted blocks; tests/theme/walkthroughs/test.typ:1-14)
- [v] Concept commits use conventional commits with scope: `docs(concepts): add the theming API concept for v0.5.0`, a bullet body, 'Refs #18' and a Co-Authored-By line. The implementation PR used `feat(theme)!:` with the sections Summary / What changes / Breaking changes / Documentation and tests / Testing (local) / Refs. (git show ac4a11d 6023786 82077bb; gh api pulls/49)
- [v] Branch convention of the maintainer for big features is `feature-<topic>` (feature-theming-api, feature-theming-api-polish, feature-zugferd-validation); smaller ones are `<type>/<topic>` (chore/…, fix/…, release/v0.6.0). The session is on `claude/invoice-pro-programmatic-generation-1uwaga` (= main df934a7, clean). (gh api pulls (head.ref); git status)
- [v] CI for a concept-only PR: only linter.yaml runs on every PR or push to main (nix checks.lint = pre-commit: typstyle -i on files matching \.typ$ repo-wide, prettier on all markdown, nixpkgs-fmt). tests.yaml, zugferd-validation.yaml and package.yaml are path-filtered (src/**, tests/**, template/**, docs/docs/**, tools/**, scripts/** …) and do not run for docs/concepts/** alone. deploy-documentation runs on a push to main touching docs/**. (.github/workflows/linter.yaml:1-22; tests.yaml:1-24; zugferd-validation.yaml:1-31; package.yaml:1-34; deploy-documentation.yaml:1-11; flake.nix:296-304)
- [v] Docusaurus only builds docs/docs (default docs path, autogenerated sidebar), so docs/concepts/\*\* is not part of the site. buildNpmPackage still copies all of ./docs. (docs/docusaurus.config.js:46-62; docs/sidebars.js; flake.nix:258-267)
- [v] CI tool versions: PR #49 states 'Lint with the versions CI uses (typstyle 0.15.1, Prettier 3.6.2)'. The concept used prettier 3.6.2 and typstyle 0.14.1 at the time. The flake pins nixpkgs nixos-unstable 2026-09-29 (typstyle); the prettier hook comes from the pre-commit-hooks nixpkgs (2025-12). (gh api pulls/49 body; docs/concepts/theming-api/README.md App. D; flake.lock nodes nixpkgs_4/nixpkgs_5)
- [v] The repo is lint-clean today with the CI versions: prettier 3.6.2 and 3.8.1 --check "\*_/_.md" both pass (incl. all process/ files); typstyle 0.15.1 --check on all 781 tracked .typ files exits 0. The real `nix build .#checks.x86_64-linux.lint` could not run in this sandbox (HTTP 403 on GitHub flake-input tarballs). (commands in measurements; <session>/exp/conventions/nix-lint.log)
- [v] Docs-page obligations: every non-trivial code block goes into the DOCUMENTATION.md Code Block Registry (Code ID, Description, Version, Test, Notes) and the TESTING.md Documentation Test Registry, with a verbatim test under tests/docs/<page>-<example>/ (.gitignore, test.typ starting with a '// Source: …' comment, a valid placeholder ref/1.png, then tt update). A block without a test is marked ⚠️ in both. (docs/DOCUMENTATION.md:5-11,433-438; tests/TESTING.md:261-303,1025,1139-1149)
- [v] check-docs-examples extracts every ```typst block in docs/docs that imports @preview/invoice-pro:<ver>, rewrites the import to src/lib.typ and compiles it alone in a temp dir with --root / and no --input. A block reading a fixture file therefore needs `[//]: # "check-docs-examples: skip"` or must not depend on the file. Baseline: 41/41 compile. (scripts/check-docs-examples:1-140; run with typst 0.15.1 (13.4 s))
- [v] Version-bump checklist lists every docs page that carries `@preview/invoice-pro:X.Y.Z` by name, the DOCUMENTATION.md version column, template, READMEs, loom-key, videos, contributors and the versioned docs snapshot. check-version only greps _.typ, _.md and \*.toml (all of them, docs/concepts included). (MAINTENANCE.md:7-78; scripts/check-version:13-16; .agents/skills/bump-version/SKILL.md)
- [v] Only `typst.toml README.md LICENSE thumbnail.png src template` are published (tools/, build/, images/ are excluded too). check-package-bundle compiles the template and two e-invoice docs offline from exactly that set, so any runtime file (e.g. a schema) must live under src/ or template/. (.github/workflows/publish-package.yaml:13; typst.toml:19; tests/TESTING.md 'Package Bundle Check')
- [v] The template is one file: a header comment (links, e-invoice export how-to, THEMES cheat-sheet), then `#show: invoice.with(theme, locale, zugferd, sender{…contact, extra}, recipient{…buyer-reference}, invoice-nr)`, `#line-items[ bundle/item/discount/apply/surcharge ]`, `#payment-terms(days: 14)`, `#bank-details(..)` and `#signature()`. It is validated by validate-all-zugferd, has golden XML (tests/zugferd/golden/template/invoice.xml), is compiled by check-package-bundle (typst init), and is the source of thumbnail.png at release. (template/invoice.typ:1-138; scripts/validate-all-zugferd:57; .agents/skills/create-release/SKILL.md step 3)
- [v] Perf conventions: modules that only some invoices need are imported inside the function that needs them (lazy), and the perf gate fails when benchmark invoices load a LAZY_MODULES entry. The module import budget is 12 ms (yellow); PR #49 measured 12.2 ms. (tools/perf/gate.py:15-80; tools/perf/README.md 'Budget'; src/invoice.typ:21-38 (lazy import of languages); PR #49 body)
- [v] Business-term registry: tools/zugferd/bt-disposition.toml maps every EN 16931 BT/BG to an input (e.g. BT-27 → sender.name). It is checked by bt_disposition.py and its tests and generates docs/docs/e-invoicing/invoice-data/business-terms.md. 'A new input updates the entry of its business term in the same change.' (tools/zugferd/bt-disposition.toml:1-60; docs/docs/e-invoicing/invoice-data/business-terms.md:15)
- [v] Extension precedents: custom part names need a package prefix (`acme/rail`), and names without a prefix are reserved for future built-ins. `options.custom` is an open namespace whose values are not interpreted. Parties accept `extra` (label → value dict). item() has no extra or custom field. (docs/docs/api-reference/theme/parts.md:57,183,215; src/theming/schema.typ:156,186; template/invoice.typ:46-49; src/components/item.typ:86-139)
- [v] Minimum compiler is 0.14.0, and the maintainer decided (Q2) that everything must work on 0.14 (tested 0.14.2) and 0.15.1. (typst.toml:18; docs/concepts/theming-api/README.md App. A Q2)

## Implications

- Naming and namespace: if the feature adds an invoice() parameter, its namespace should carry the same name and sit in a new src/public/<name>.typ facade imported in lib.typ. It must be added to the pinned list in tests/theme/exports/test.typ and documented as a row of the api-reference module table. Caution (inference): a root export named `data` would be shadowed by the common idiom `#let data = json(..)` after `import *`, so weigh that name.
- Extend, don't change: precedent is purely additive params with `auto`/`none` defaults (invoice() has about 35 such params). The data layer should feed the existing parameters and components (sender, recipient, invoice-nr, line-items/item/bundle, payment-terms, bank-details) rather than altering signatures, since README promises the data model is stable.
- Format must be a parsed dictionary handed in from the user's document (json/toml/yaml/csv parsed there), or bytes, or a string decoded from sys.inputs inside the package. A package cannot open a path the user names. Images that depend on field values (e.g. a coat of arms by PLZ) need an `assets: path => image(path, ..)`-style callback defined in the skeleton, exactly like from-data.
- CLI interface: the package-owned input key should follow `invoice-pro-<name>` (e.g. `invoice-pro-data` carrying a JSON string). The reader should take `inputs: sys.inputs` so tytanic tests can inject values. A bad value panics with a `--input key=value is not …; use …` message. A file path given via --input can only be read by user code in the skeleton (one `read(..)` line), not by the package.
- Error semantics: unknown keys and wrong types in the data are misuse and panic with a `::` path, did-you-mean and allowed keys (reuse utils/patch.typ fail-unknown and utils/types.typ require). Missing legally required values reuse the existing validation data issues (draft markers, strict panics), so no second error system is needed. Custom fields need an explicit open namespace (like options.custom) or a prefix rule so future built-in keys stay free.
- Coercion: theming/data.typ `_coerce` already maps strings to colors, lengths and ratios. The data format needs similar documented rules for dates (datetime from ISO strings) and money. Tests compare with decimal(".."), so prices should round-trip as strings or decimals, not floats.
- Speed: the hydration module must be lazily imported (imported inside the function that needs it), so invoices without data pay nothing. The root import budget is already at its 12 ms yellow line. The concept should define a perf budget and possibly extend tools/perf (LAZY_MODULES or a share metric) as the ZUGFeRD work did.
- Phase-2 readiness: a machine-readable schema that ships must live under src/ (only src and template are published). If it embeds the package version, check-version will not see it (it greps _.typ/_.md/\*.toml only), so the version-bump checklist and script would need an update. A generated artefact needs a MAINTENANCE.md section and a CI check, like bt_disposition.py --update-docs.
- Docs obligations of the feature: a new api-reference page (sidebar_position 7 after theme) and/or a guide page (top-level slots 3, 8 and 9 are free). Each versioned import page goes on the MAINTENANCE.md bump list. Each code block goes into both registries with a verbatim tests/docs test. Update the contributing roadmap checkbox, the intro 'Key Capabilities' list, both READMEs together, and bt-disposition.toml if new input names appear.
- Template as skeleton: it already separates design (theme:, header comment) from data (sender, recipient, invoice-nr, items, payment, bank). Changing it re-triggers the tests, zugferd and package workflows, the golden XML (zugferd-golden --update) and the thumbnail at release, so it should stay compiling with no inputs.

## Risks

- Forgetting tests/theme/exports/test.typ (or the theme, custom and layout lists in it) when adding exports makes the whole tytanic suite fail.
- Concept typst blocks that import `@preview/invoice-pro:X.Y.Z` become stale-version hits in check-version at every bump. The theming concept avoids imports entirely; follow that.
- A docs/docs example that reads a fixture file (data.json, wappen.svg) or relies on --input fails check-docs-examples, because it is compiled alone with no --input. It needs the skip marker or a default and inline fallback; tytanic tests must change the default and say so in a comment.
- Local prettier (3.8.1) differs from CI's (3.6.2 via the pre-commit-hooks nixpkgs, as stated in PR #49). Both pass today, but writers should check with 3.6.2 before pushing. The real nix lint could not be run here (GitHub tarballs blocked by the proxy).
- Any .typ prototype committed under docs/concepts/\*\* is typstyle-checked by CI (the hook matches \.typ$ repo-wide), so a prototype must be typstyle 0.15.1-clean.
- Process material must not leak local paths (convention: `<session>`, `<repo>`), and every .md in process/ must be prettier-clean.
- Perf: the root module import is already at the 12 ms yellow budget (12.2 ms in PR #49). An eagerly imported data module would make it worse.
- Version-bearing non-.typ/.md/.toml artefacts (e.g. a JSON Schema $id) escape check-version.
- Changing template/invoice.typ shifts its golden XML, ZUGFeRD validation and thumbnail, so it is a larger blast radius than the concept suggests.
- Calling the namespace `data` risks user shadowing (inference, not tested).

## Open questions

- Branch and folder naming: keep the harness branch `claude/invoice-pro-programmatic-generation-1uwaga`, or rename to the maintainer's convention, e.g. `feature-data-api` / `feature-data-hydration` with the concept at `docs/concepts/data-api/` (mirroring `feature-theming-api` and `docs/concepts/theming-api/`)?
- Target release and tier: v0.7.0 with the data layer `experimental` (as from-data, zugferd and themed were), or `provisional` from the start?
- Should a GitHub issue be opened first (contributing.md requires an issue before a PR), so the concept commit can say 'Refs #N'? The roadmap item 'Data Loading' already exists.
- Should the concept keep a full process/ folder (research, designs, review) as the theming concept did, or only the README?
- Public sys.inputs key name: `invoice-pro-data` (JSON string)? Should a second key carry a file path that the skeleton reads?
- Formats in scope for phase 1: the roadmap names JSON, CSV and YAML; Typst also parses TOML, XML and CBOR natively. Is CSV for line items alone in scope?
- Does the concept need a perf gate extension (a budget for the hydration path), and should the hydration module be added to tools/perf LAZY_MODULES?
- Should new input names be reflected in tools/zugferd/bt-disposition.toml (only needed if the data format introduces new inputs rather than re-feeding existing parameters)?

## Measurements

- prettier 3.6.2 (CI version, installed to <session>/prettier362): `prettier --check "**/*.md"` in repo → 'All matched files use Prettier code style!'
- prettier 3.8.1 (local /opt/node22/bin/prettier): `prettier --check "**/*.md"` → all pass, real 9.9 s; `prettier --check "docs/concepts/**/*.md"` → all pass
- typstyle 0.15.1 (cargo install --version 0.15.1 into <session>/typstyle): `git ls-files '*.typ' | xargs typstyle --check` → 781 files, exit 0
- typstyle 0.15.1 --check on the 20 ```typst blocks extracted from docs/concepts/theming-api/README.md → 20/20 ok (no diff)
- typstyle 0.15.1 --check on all ```typst blocks in docs/docs/\*_/_.md whose first line starts with # or // → 123 checked, 0 diffs (DOCUMENTATION.md rule 5 holds)
- TMPDIR=<session>/exp/conventions/tmp TYPST_BIN=<session>/bin/typst ./scripts/check-docs-examples → 'All 41 documentation examples compile.' real 13.4 s; git status clean afterwards
- Path experiment (<session>/exp/conventions/pathexp, @local/pathprobe:0.1.0) on typst 0.15.1 and 0.14.2: package `json(p)` with a user path → error 'file not found (searched at …/pathprobe/0.1.0/src/data.json)'; package `json(read("data.json", encoding: none))` with bytes from the user doc → OK; package `json(bytes(sys.inputs.at("invoice")))` with --input invoice='{…}' → OK on both
- `nix build .#checks.x86_64-linux.lint --no-link --no-write-lock-file` → failed fetching github:numtide/flake-utils (HTTP 403 from the session proxy); log at <session>/exp/conventions/nix-lint.log
- prettier rewrite demo (<session>/exp/conventions/prettier-demo/draft.md): adds blank lines around headings and blocks, aligns tables, `*`→`-` bullets, `1)`→`1.`, `__b__`→`**b**`, `*e*`→`_e_`; prose is not wrapped
- Test inventory: 313 test.typ total; docs 80 (71 with ref/), integration 66, theme 55, zugferd 37, validation 21, line-items 20, layouts 16, presets 10, issues 6, country 1, unit 1

## Notes

### Repository conventions for the data-hydration feature (invoice-pro 0.6.0)

All paths are repo-relative. `<session>` = `<session>` (experiments in `<session>/exp/conventions/`). I modified no file in the repo; `git status` is clean.

---

#### 1. Conventions a new public API must follow

##### 1.1 Naming

- **kebab-case everywhere** (verified: 0 snake*case and 0 camelCase among the 915 top-level `#let`s in `src/`). Private helpers start with `*`(333×), e.g.`\_coerce`, `\_title-to-check`.
- **Semantic, final names; no aliases** (theming concept Q7: "never orient on old code; semantically best names"; rejected alternative 2: "Rename aliases … no code, permanent cost"). The strict merge rejects old keys with the allowed-keys list.
- **Abbreviation style of data keys:** `invoice-nr`, `customer-nr`, `order-nr`, `tax-nr`, `vat-id`, `buyer-reference`, `delivery-address`, `payment-reference`, `service-period`, `document-type`. A data format should reuse exactly these names (they are the parameter names of `invoice()`, `src/invoice.typ:40-200`).

##### 1.2 Namespaces mirror parameters

- Rule: "the namespace is named after the parameter" (`docs/concepts/theming-api/README.md:38`). Examples: `invoice(theme:)` ↔ `theme`, `locale:` ↔ `locale`, `tax:` ↔ `tax`, `unit:` ↔ `unit`, `references:` ↔ `references`, `country` keys ↔ `country`. Sub-namespaces mirror each other (`theme.custom` ↔ `locale.custom`, `theme.layout` ↔ `locale.region`).
- Facade pattern: `src/public/<ns>.typ` re-exports only documented names (`src/public/custom.typ:1-4`: "internal helpers … must not become API"). `src/lib.typ` imports the facade as a module (`#import "public/theme.typ"`).
- **Export pinning test**: `tests/theme/exports/test.typ` compares `dictionary(lib).keys()` with a hard-coded list (root, `theme`, `theme.custom`, `theme.layout`, …). A new export must be added there, or tytanic fails.
- Naming caution (inference): the docs idiom is `#let d = json("job.json")` / `#let e = toml(..)`. A root export named `data` would be shadowed by a user's `#let data = json(..)` after `#import "@preview/invoice-pro:..": *`.

##### 1.3 Doc comments

```typ
/// Displays the payment deadline and terms for the invoice.
///
/// -> content
#let payment-terms(
  /// The number of days allowed for payment from the invoice date.
  /// -> none | int
  days: none,
  ...
) = {
  types.require(days, "payment-terms::days", none, int)
```

- `/// -> type` after each parameter description and above the function (`src/components/payment-terms.typ:29-57`, `src/invoice.typ:40-200`).
- Type spellings: `str` (163) ≫ `string` (21); `dictionary` (114), never `dict`; unions `none | str | content`; callbacks written as `(content|str, content|str) => content`.
- Deprecation: inline `/// -> none | string | content (deprecated)` (`src/invoice.typ:85`, `tax-nr`; the only one). There is no deprecation-warning mechanism (Typst has no user warnings); migration is documented in tables (`docs/docs/api-reference/theme/migration.md`, concept §2.7).
- Normative references go in the prose of the doc comment (e.g. "BT-5", "§ 14 UStG").

##### 1.4 Misuse → panic, data gaps → issues

From `src/validation/issue.typ:1-25`:

> "API misuse (unknown keys, wrong types, cycles, unknown parts, undefined geometry) never becomes an issue: it panics directly, because no output could honour what the user wrote."

| Situation                                     | Mechanism                                                                                                                           | Level-dependent?   |
| :-------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- | :----------------- |
| wrong type of an argument                     | `types.require(value, "comp::param", ..types)` → ``variable `comp::param`(repr) must be of …`` (`src/utils/types.typ:9-27`)         | no, always panics  |
| unknown key in a dict (patch, brand file)     | `fail-unknown(path, key, allowed)` → ``a::b has unknown key `k`. Did you mean `x`? Allowed keys: …`` (`src/utils/patch.typ:81-104`) | no                 |
| invalid enum value                            | `"variable `invoice::validation`(..) must be one of …" + synonym/did-you-mean` (`issue.typ:80-120`)                                 | no                 |
| invalid `--input` value                       | `--input invoice-pro-validation=x is not a validation level; use none, draft or strict.`                                            | no                 |
| missing or invalid legally required data      | `issue(id, "data", message, ref:, fix:, field:, key:, args:)` → draft marker + report page / strict panic / none silent             | yes (`validation`) |
| theme cannot carry required output            | class `theme`                                                                                                                       | yes                |
| quality guard (contrast, footer fit, overlap) | class `lint`                                                                                                                        | yes                |
| e-invoice business rules                      | `zugferd-errors: "panic" \| "report" \| "ignore"`                                                                                   | own switch         |

House style of messages (concept §11): a `theme::`/`comp::` path, the value, the allowed set and a did-you-mean hint. Under strict, one issue panics with its message verbatim; several panic with a header and a numbered list (`issue.typ panic-text`). Issue messages are English (the panic text); report texts are localised via `strings.validation.issues` keyed by `key` and `args`.

##### 1.5 sys.inputs conventions

- Package-owned public key: `invoice-pro-validation` (`src/validation/issue.typ:25-27`); the internal key is `ip-seal` (`src/theming/access.typ:5`). User-level keys in docs/concept examples are un-prefixed (`preset`, `output`, `n`, `qr-bill`, `window`, `proof`). A new package key should be `invoice-pro-<name>`.
- The reader takes the inputs as a parameter: `resolve-level(param, inputs: sys.inputs)`. Tests inject: `resolve-level("draft", inputs: (invoice-pro-validation: "strict"))` (`tests/validation/api/test.typ:12-22`). TESTING.md: "tytanic cannot pass it, so set the level in the test" (around line 421), and docs-test step 4 at line 278: "If the block reads `sys.inputs` (tytanic cannot pass `--input`), change the default in the test and say so in a comment."
- The input wins over the parameter (CI and batch pipelines can enforce strict without editing documents).

##### 1.6 Stability tiers (how to label the new API)

User-facing table (`docs/docs/api-reference/theme/index.md:158-166`):

| Tier                        | Promise                                             |
| :-------------------------- | :-------------------------------------------------- |
| Frozen                      | No breaking change in 0.6.x                         |
| Stable names, evolving look | name stays; appearance may change in a minor        |
| Provisional                 | may change in a 0.6.x minor, with a changelog entry |
| Experimental                | may change or be removed                            |
| 0.6.x preview               | specified, not final                                |
| Internal                    | everything else (ctx keys, `build-theme`, …)        |

- Marking: a Tier column in export tables; `_(Experimental)_` in parameter tables (`zugferd` row of `docs/docs/api-reference/invoice/index.md`); a `:::warning` admonition ("`theme.custom.from-data` is **experimental**.", customization.md:255-257); and source comments (`FROZEN`, `STABLE`, `EXPERIMENTAL`, `PROVISIONAL` in `src/theming/presets.typ`, `src/theming/layouts.typ`, `src/public/layout.typ:4-8`, `src/locale/lang/base.typ:59`).
- Precedent: data-file features shipped as **experimental** (`from-data`), as did `zugferd` and `themed`. README Status (`README.md:158-160`): the data model (`line-items`, `item`, `group`, `bundle`) is stable, the theme API is stable, the locale API may change, e-invoicing is experimental.

##### 1.7 Closest precedent: `theme.custom.from-data` (`src/theming/data.typ`)

- Input: a parsed dict (`toml("brand.toml").theme`); no `eval` ("eval is not file-sandboxed").
- String coercion: `"#0b3d91"`→rgb, `"10.5pt|25mm|cm|in|em"`→length, `"66%"`→ratio, `"none"`→none, `"auto"`→`reset()`, other strings stay strings. "No expression language: a file sets values" (rejected alternative 3: alias strings `"{colors.primary}"` = a second expression language).
- Whitelist of groups and layout keys, with panics naming the allowed set.
- `assets: path => image(path, alt: ..)`, because "packages cannot open files by path"; the function must be defined in the user's document.
- Docs: `docs/docs/api-reference/theme/customization.md:253-305`, with a coercion table and error examples. Test: `tests/docs/api-theme-custom-from-data/` (fixtures `brand.toml` and `logo.svg` next to `test.typ`).

**Verified experiment** (`<session>/exp/conventions/pathexp/`, typst 0.15.1 and 0.14.2):

| Package code                                                                                           | Result                                                                        |
| :----------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------- |
| `#let load-path(p) = json(p)` called with `"data.json"`                                                | `error: file not found (searched at …/pathprobe/0.1.0/src/data.json)` on both |
| `#let load-bytes(b) = json(b)` with `read("data.json", encoding: none)` from the user doc              | OK on both                                                                    |
| `#let load-input(k) = json(bytes(sys.inputs.at(k)))`, `--input invoice='{"items":[{"price":"9.99"}]}'` | OK on both; `"9.99"` stays `str`                                              |

So: the skeleton (user document) must do the file I/O (`json("/data.json")`, `read(..)`), or the data arrives as a string through `--input` and the package decodes it.

##### 1.8 Performance conventions

- "Only what the invoice needs": modules needed by only some invoices are imported inside the function that uses them (`src/invoice.typ:28-31` imports the languages lazily: "a module a function refers to is hashed with it, and the languages are large").
- The perf gate (`tools/perf/gate.py:15-80`, README "Budget") turns red when the benchmark invoices load a `LAZY_MODULES` entry. Yellow when the module import exceeds 12 ms (`IMPORT_BUDGET_MS = 12.0`); PR #49 reported 12.2 ms. Measurements use `typst compile --timings` traces, median of ≥5 runs; `tools/perf/measure.py --instructions` compares checkouts.
- The theming concept reported performance as a table, "median of 5 runs, pinned fonts", on both compilers (§13.4).

##### 1.9 Other policies

- Minimal dependencies: copy or rewrite utilities rather than adding packages (`docs/docs/contributing.md` Dependency Management). Current deps are only sepay (+ibanator) and loom.
- Self-contained: "made in Typst alone: no Java, no network, no external tool" (`docs/docs/e-invoicing/architecture.md:80-83`). This fits phase 1's typst-CLI-only interface.
- Minimum compiler 0.14.0 (`typst.toml:18`); maintainer decision Q2: everything works on 0.14 (tested 0.14.2) and 0.15.1.
- EU scope; issue before PR; "assess its impact on overall usability and rendering speed".
- Reproducibility: the same input, Typst and package version give the same XML (and PDF with a fixed timestamp); golden XML tests check it.

---

#### 2. Structure and format of a concept document

##### 2.1 Location and files

```
docs/concepts/<feature>-api/        (theming-api precedent)
├── README.md                       the concept (1616 lines for theming)
├── figures/                        PNG figures (rendered from test fixtures later; MAINTENANCE.md:82-104)
└── process/                        kept "as produced"
    ├── research/   _digest.md + one report per researcher (path:line evidence)
    ├── designs/    competing proposals + judge verdicts + _panel-digest.md
    ├── review/     draft-1.md + critique-<lens>.md
    └── phase-4/    workstream results, core-bugs.md, rename-map.tsv
```

- The concept is outside Docusaurus (only `docs/docs` is built).
- Local paths in process files are replaced by `<session>` and `<repo>` (verified: 170 + 9 placeholders, no raw `/home` or `/tmp`; App. D says so).
- Research files tag evidence as **VERIFIED** (reproduced), **SOURCE** (read), **REASONED** (argument) (`process/review/critique-maintainer-cost.md` header), or **[verified]** (`process/research/api-philosophy.md`).
- A runnable prototype once lived in `docs/concepts/theming-api/prototype/` and was later removed ("retire the theming prototype", 82077bb). Its `.typ` files were subject to the repo-wide typstyle hook.

##### 2.2 README.md skeleton (theming-api)

1. `# invoice-pro v0.5.0 Theming API: concept v2`
2. **Status paragraph** (one long paragraph): version and date, implementation state, what it replaces, the maintainer decisions applied, the prototype/evidence basis, the compilers, the path conventions (`src/`, `tests/` repo-relative; `figures/`, `process/` doc-relative), and the undefined names used by snippets (`party`, `body(n: 4)`), plus "All 20 blocks are typstyle-formatted".
3. `---`, then `## Executive summary`: bold lead-ins (**What a theme is.**, **What phase 4 added.**, **Implementation.**, **Compiler.**, **Cost.** "About 34–46 maintainer-days …"), ending with **What I need from you:** the open questions, the most important first.
4. `## Design decisions at a glance`: a table `| Decision | Choice | Why |` with about 20 rows, one line each (e.g. `Namespace | singular theme (Q1) … | one rule: the namespace is named after the parameter`).
5. Numbered sections: §1 Pitch & mental model (ASCII pipeline in a `text block, a concept/tier table, the customization ladder); §2 Public API surface (exports table with a Tier column, signatures in `text blocks, migration tables); §3 Schemas (complete key listing); §4 Cascade, precedence & merge; §5 Contract and stability tiers (table); §6–§9 feature specifics; §10 Walkthroughs by persona (P1…P10, each with a typst block); §11 Error messages (house style plus verbatim messages); §12 Internals sketch; §13 Feasibility evidence & Typst 0.14 validation (prototype suite counts, 0.14.2 vs 0.15.1, PDF standards, performance table, **Not verified** list); §14 Trade-offs, risks & rejected alternatives (Weaknesses bullets plus a numbered Rejected list); §15 Implementation roadmap (solo maintainer), a table `Step | Scope | Days` with a total, then "0.5.x (additive, in rough priority)".
6. Appendices: **A** Decisions and open questions: A.1 "Decided by the maintainer (date)" table `# | Question | Decision | Where` (Q1…Q9); A.2 phase rulings; "Interpretations taken … (please confirm or revert)"; A.3 "Still open" numbered **O1…O11**, each bold-titled with _Recommendation:_. **B** Requirements traceability `Req | Prio (MUST/SHOULD) | Status (C/P/X/0.5.x) | Where`. **C** Changes since v1. **D** Process & sources (numbered phases plus a sources table by kind: research, proposals, verdicts, review, phase 4), and the formatter versions used.

##### 2.3 Tone and formatting

- English, plain and precise; no contractions (0 found); no "we" (0); the reader is addressed as "you"; the author speaks as "I" only in "What I need from you".
- Measured claims are qualified ("on the prototype", "verified", the compiler version); unverified things are listed explicitly.
- Typst snippets: ``typst blocks, typstyle-formatted, **without** `#import "@preview/invoice-pro:X.Y.Z"` (0 in the theming README), to avoid stale-version hits in check-version. Undefined helper names are declared in the Status line. Other blocks use ``text (signatures, pipelines, messages) and ```toml (data files).
- Cost estimates are in maintainer-days per step, with a total; the "solo maintainer" framing is explicit.
- Commit: `docs(concepts): add the <x> concept for vX.Y.Z` with a bullet body (what the model is, maintainer decisions, contents), `Refs #N`, and the attribution lines; follow-ups `docs(concepts): add the research and review material behind the concept`.

---

#### 3. The template (`template/invoice.typ`) = the natural skeleton

```
L1      #import "@preview/invoice-pro:0.6.0": *          (version-bumped)
L3-29   /* header comment: author/docs/GitHub links; E-INVOICE how-to
           (web app & CLI --pdf-standard=a-3b; draft vs strict);
           THEMES cheat-sheet (10 names, brand(), layout) */
L31-59  #show: invoice.with(
          theme: theme.bold,           ← DESIGN (stays Typst)
          locale: locale.de-de,        ← config
          zugferd: "en16931",          ← config
          sender: (name, address, city, tax-nr, vat-id,
                   contact: (name, phone, email),
                   extra: ("Tel": .., "E-Mail": ..)),   ← DATA
          recipient: (name, address, city, vat-id, buyer-reference), ← DATA
          invoice-nr: "2026-01")       ← DATA
L61-128 #line-items[ bundle(date:(d1,d2), unit:)[ item(..)…, discount(..),
                       bundle[..] ], apply(tax: tax.vat(7%))[item],
                     item(.., date: datetime.today()),
                     item(total:, input-gross: true), item(price: 0, tax: tax.zero(), description:),
                     discount(.., amount: 50), surcharge(.., amount: 15.00) ]   ← DATA (tree)
L130    #payment-terms(days: 14)       ← DATA
L132    #bank-details(bank:, iban:, bic:)   ← DATA
L138    #signature()                   ← design/content
```

- Design lives in the `theme:` argument (and optionally `themed(..)` scopes); everything else is data. The line items are a **content tree** of components (bundle/apply nest), so hydration must produce that tree or feed an equivalent data path.
- Obligations if touched: validated by `scripts/validate-all-zugferd:57` (Mustang + KoSIT), golden XML `tests/zugferd/golden/template/invoice.xml` (`zugferd-golden`, fixed creation timestamp), compiled offline by `check-package-bundle` (via `typst init`), the source of `thumbnail.png` at release (create-release step 3), the import version on the bump list, and the trigger paths of the tests, zugferd and package workflows (`template/**`).
- Note: `datetime.today()` appears in an item date; the invoice date defaults to today.

---

#### 4. Test & doc obligations of a new feature

##### 4.1 Tests (tytanic; 313 test.typ today)

| Category                                                                 | Count (with ref/) | Use for                                                                                                                                                        |
| :----------------------------------------------------------------------- | :---------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tests/docs/`                                                            | 80 (71)           | verbatim doc code blocks, `// Source: docs/docs/<page> — "<section>"` first line, `prelude.typ` `party`/`body()` for elided headers, fixtures next to test.typ |
| `tests/integration/`                                                     | 66 (8)            | full renders; ZUGFeRD documents also listed in `scripts/validate-all-zugferd` + golden                                                                         |
| `tests/theme/`                                                           | 55 (14)           | engine tests, exports, naming, coverage (helper params == schema keys), errors (41 `catch` cases), walkthroughs (concept snippets)                             |
| `tests/zugferd/`                                                         | 37 (0)            | e-invoice unit tests                                                                                                                                           |
| `tests/validation/`                                                      | 21 (1)            | levels, `--input` override via injected `inputs:`                                                                                                              |
| `tests/line-items/`                                                      | 20 (0)            | `data-test` + `test-locale` + `theme.plain` + `validation: none` value assertions                                                                              |
| `tests/layouts/` 16, `presets/` 10, `issues/` 6, `country/` 1, `unit/` 1 |                   |                                                                                                                                                                |

Rules: every test dir has `test.typ` + `.gitignore` (`# generated by tytanic, do not edit` / `/diff/` / `/out/`). A visual test needs a placeholder `ref/1.png` that is a **valid PNG** (tytanic 0.3.3 fails on an empty file), then `tt update <path>` (never a blanket `tt update`, fix-tests skill). Assertion messages follow `"Field: expected <v>, got " + repr(actual)`. Use `decimal("..")` for money, valid IBAN `DE75512108001245126199` / BIC `SOLADEST600`. `catch` is tytanic-only, so shadow it with `quoted-panic` (`tests/panic-message.typ`) for 0.14/0.15 parity. `/// [ppi: 12]` lowers the render resolution. Panic tests use `validation: "strict"`. Data tests with incomplete parties use `validation: none`. Visual tests need complete data (otherwise they render a draft).

A new feature most likely needs: (a) a new category such as `tests/data/` (add it to the TESTING.md Directory Structure and Naming tables); (b) exports-test updates; (c) error-message cases (misuse panics); (d) a value-level test that a hydrated skeleton gives the same `line-items` signal and totals as the hand-written one (`data-test` + `loom.query.find-signal(data, "line-items")`); (e) tests of `--input` decoding through an injectable `inputs:` parameter; (f) a ZUGFeRD equivalence or golden case if hydration can produce e-invoices; (g) docs tests for every new code block.

##### 4.2 Docs

- New pages under `docs/docs/` only (canary); never edit `docs/versioned_docs/`. Frontmatter `sidebar_position`: top level uses 1, 2, 4, 5, 6, 7, 10, 11, 12 (3, 8 and 9 free); api-reference uses invoice 1, line-items 2, components 3, tax 4, locale 5, theme 6, so a new module page is 7. Sidebar is autogenerated.
- Page format: `# X API`, `:::info` about the show rule, `## \`fn\``with the table`| Key | Type | Description |` (`:---` alignment, types `` `none`\|`str` ``), "Key Parameters Explained", "Minimal Valid Configuration", admonitions `:::tip/:::warning/:::danger/:::note`.
- Also update: the module table in `docs/docs/api-reference/index.md:17-28`, intro "Key Capabilities" (`docs/docs/intro.md:66-72`), the contributing roadmap checkbox (`contributing.md:95`, `- [x] (v0.7.0) **…**`), both READMEs together (MAINTENANCE.md README section; `tests/docs/readme-*` take their code verbatim), and the contributors page at release.
- Registries: **DOCUMENTATION.md** Code Block Registry (one `### \`page.md\``section,`| Code ID | Description | Version | Test | Notes |`) plus **TESTING.md** Documentation Test Registry (`| Source file | Code ID | Description | Test directory | Status |`, ✅ or ⚠️ not implemented). Procedure: DOCUMENTATION.md:433-438.
- `check-docs-examples` compiles complete blocks alone (temp dir, `--root /`, no `--input`). Fixture-dependent blocks need `[//]: # "check-docs-examples: skip"` on the line before (an HTML comment breaks MDX).
- E-invoice docs: if new input names arise, update `tools/zugferd/bt-disposition.toml` in the same change; it regenerates `business-terms.md` (`bt_disposition.py --update-docs`). Editing `docs/docs/e-invoicing/**` also triggers the zugferd workflow.
- Showcase videos (MAINTENANCE.md:107-158) are optional for a new feature but are rebuilt at every bump.

##### 4.3 Version-bump checklist items a new feature adds

- Every new docs page with `@preview/invoice-pro:X.Y.Z` goes on the MAINTENANCE.md:17-43 list (and the bump-version skill list), plus the DOCUMENTATION.md version column.
- A new version-bearing artefact outside `.typ/.md/.toml` (e.g. a JSON Schema `$id`) would escape `scripts/check-version` (globs `*.typ *.md *.toml`), so extend the script or avoid embedding the version.
- Anything the package needs at runtime must be under `src/` or `template/` (`publish-package.yaml:13`, `check-package-bundle`); `tools/` is excluded (`typst.toml:19`).
- If the feature changes a maintained artefact (a generated schema or table), add a MAINTENANCE.md section with checklist and files reference, as for figures and videos.

---

#### 5. CI checks a concept-only commit must pass

| Workflow                                               | Trigger                                                                                       | Runs for `docs/concepts/**` only?                         |
| :----------------------------------------------------- | :-------------------------------------------------------------------------------------------- | :-------------------------------------------------------- |
| `linter.yaml` (`nix build .#checks.x86_64-linux.lint`) | every push/PR to main, no path filter                                                         | **yes**                                                   |
| `tests.yaml` (tt run + check-docs-examples)            | flake, lib.typ, src, tests, template, docs/docs, scripts/check-docs-examples                  | no                                                        |
| `zugferd-validation.yaml`                              | src, tests/{integration,docs,zugferd}, template, tools, scripts, docs/docs/e-invoicing, flake | no (unless tools/ or scripts/ are touched)                |
| `package.yaml`                                         | typst.toml, README.md, LICENSE, thumbnail, src, template, two docs tests, …                   | no (README.md changes would trigger it)                   |
| `deploy-documentation.yaml`                            | push to main, `docs/**`                                                                       | yes on merge (harmless: Docusaurus ignores docs/concepts) |

Lint = pre-commit-hooks (`flake.nix:298-304`):

- `typstyle -i`, files `\.typ$` (all tracked .typ, so any prototype `.typ` under docs/concepts too). CI version typstyle 0.15.1 (PR #49). Verified: 781/781 files clean.
- `prettier`, `types_or = ["markdown"]` (all tracked .md, including every `process/*.md`). CI version Prettier 3.6.2 (PR #49). Verified: clean with 3.6.2 and 3.8.1. Typical rewrites: blank lines around headings and blocks, aligned tables, `-` bullets, `1.` lists, `**bold**`, `_em_`; no prose wrap.
- `nixpkgs-fmt` (only .nix).
- Not checked by CI: typst blocks inside markdown (the convention says typstyle them anyway; DOCUMENTATION.md:11), .json/.toml/.tsv files.
- Local non-nix fallback in `scripts/check-pr:50-57`: `typstyle --check src/ tests/ template/` and `prettier --check "**/*.md"`.
- Recipe to verify a concept commit locally: `<session>/prettier362/node_modules/.bin/prettier --check "docs/concepts/**/*.md"` and `<session>/typstyle/bin/typstyle --check <any .typ>`. The real nix lint could not run here (proxy 403 on GitHub tarballs).

---

#### 6. Branch name

Maintainer convention: `feature-<topic>` for big features (`feature-theming-api`, `feature-theming-api-polish`, `feature-zugferd-validation`, `feature-prepayment-and-modifier-#37`); `<type>/<topic>` for smaller ones (`chore/bump-mustang-typst`, `fix/identity-overlap`, `release/v0.6.0`). Suggested: **`feature-data-api`** (pairs with `docs/concepts/data-api/` like `feature-theming-api` ↔ `docs/concepts/theming-api/`) or `feature-data-hydration`. The session currently sits on the harness branch `claude/invoice-pro-programmatic-generation-1uwaga` (= main df934a7, clean); whether to rename is for the orchestrator or user.

#### 7. Commands used (reproducible)

- `grep -rhE '^\s*/// -> ' src | sed 's/^\s*//' | sort | uniq -c | sort -rn`
- `git ls-files '*.typ' | xargs <session>/typstyle/bin/typstyle --check` → exit 0
- `python3 -I <session>/exp/conventions/extract.py docs/concepts/theming-api/README.md <dir>`, then typstyle --check each block (20/20 ok)
- `TMPDIR=<session>/exp/conventions/tmp TYPST_BIN=<session>/bin/typst ./scripts/check-docs-examples` → 41/41
- `gh api 'repos/leonieziechmann/invoice-pro/issues?state=all&per_page=100'`, `gh api repos/leonieziechmann/invoice-pro/pulls/49`
- path experiment: `<session>/exp/conventions/pathexp/` (`--package-path pkgs`, `@local/pathprobe:0.1.0`)
