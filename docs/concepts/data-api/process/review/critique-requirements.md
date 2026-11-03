# Critique of the data API concept (requirements)

Reviewer role: requirements and completeness. I read the maintainer's request sentence by sentence and checked whether the concept answers each point, honestly and with evidence, including what it does not do. Reviewed on 2026-11-03: [`../../README.md`](../../README.md) (the concept) and [`../../prototype/README.md`](../../prototype/README.md), against the synthesis, the deviations, the build and verification reports and the prototype (0.6.0 + the ten patches). I also tried the workflow myself: I turned the 0.6.0 template into a skeleton by following the concept, wrote small data files and compiled them against the prototype. Scratch work is in `<session>/critique-requirements/`. The maintainer critique ([`critique-maintainer.md`](critique-maintainer.md)) already covers lint, the ledger kinds, the harness and the plan; I do not repeat its findings.

Every number below is quoted from the reports or was measured during this review, and then it says so. My timings ran on the exploration's shared 4-core VM (single compiles with `-j 1`, medians where stated). They show orders of magnitude, not benchmarks. Findings are numbered RQ1–RQ16, so that they do not collide with the concept's rules R1–R8 of §4.2.

## Verdict

The concept answers every sentence of the request, and it is unusually honest about what is open (§11.5, P4 "fail", the missed import budget, no gain at 5 rows). The core workflow works as described: I hydrated a converted template from a file on both compilers, and its preview stayed byte-identical to the 0.6.0 template.

It is not yet complete as an answer to "leicht integrieren", "möglichst schnell" and "ein allgemeines Interface per CLI". Seven gaps matter:

1. A data-dependent rule written in the skeleton can abort the compile on incomplete data, and the concept never says that rules must tolerate absent values (RQ1). §8.3's "a draft never crashes on bad data" is stated without this condition.
2. There is no recipe for turning an existing invoice into a skeleton. The steps are spread over §2.1, §2.5 and §4.5 (RQ2).
3. The template that `typst init` gives stays non-hydratable, although converting it changes no output byte (RQ3, measured).
4. The roadmap item "Data Loading" (items from JSON, CSV or YAML in Typst) is not delivered, yet stage S6 ticks its checkbox (RQ4).
5. Speed is argued for 300-row invoices. For a typical small invoice the concept gives no absolute time, and it leaves out the largest batch lever the research found: one compile for many print invoices (RQ5, measured).
6. Relative data paths resolve against the skeleton, not against the shell's working directory. This trap is hidden by examples that all run in the skeleton's folder (RQ6, reproduced).
7. The CLI interface defines the success output precisely, but on failure there is only free text on stderr, and the two machine-readable issue lists have different shapes (RQ7, reproduced).

None of these changes the API. Most are documentation; RQ1 and RQ3 are small code or template changes.

## The request, sentence by sentence

| #   | The maintainer's sentence (abridged)                                                                          | What the concept answers                                                                                                                         | Verdict                                                                                                                                             |
| :-- | :------------------------------------------------------------------------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | "Rechnungen programmatisch zu erzeugen"                                                                       | the whole concept; one compile per invoice from one JSON object                                                                                  | answered                                                                                                                                            |
| 2   | "ein einheitliches Datenformat, um Daten aus einem File oder den sysparametern einzulesen und zu verarbeiten" | `invoice-pro/1`, one JSON object; file, inline `--input`, stdin, TOML, YAML, a 0.15 `path`; `check()` and the result record as the "verarbeiten" | answered; path resolution is a trap (RQ6); a key per field (`--input invoice-nr=…`) is neither offered nor rejected with a reason (RQ10)            |
| 3   | "Das Format muss extensible sein, also custom felder"                                                         | open `custom` bags at document, party and item level; closed core; SchemaVer                                                                     | answered; item-level custom fields have no worked example and cannot be previewed (RQ12, Q30)                                                       |
| 4   | "oder die Möglichkeit abhängig von einem feldwert etwas zu verändern, wie ein wappen je nach plz"             | a static theme patch chosen in the skeleton from `invoice-data.values(record)`; draw-time wrap as the fallback; P7                               | partly: the mechanism is right and verified, but the pattern is fragile in users' hands (RQ1); the post-code rule is illustrative only (RQ11)       |
| 5   | "es muss sich leicht in das aktuelle System integrieren"                                                      | hydration inside `invoice()`; the validation levels, `check-data` and the e-invoice engine reused; P1, P2                                        | partly: no migration recipe (RQ2); the template is not a skeleton (RQ3)                                                                             |
| 6   | "eine Rechnung manuell aufbauen und designen … dann die Daten einfach hydrieren in das Skelett"               | the skeleton workflow (§1, §2); roles per key; the implicit items slot                                                                           | answered for the CLI; previewing with real data while designing is not covered (RQ8); loading only the items is not possible in 0.7.0 (RQ4)         |
| 7   | "möglichst schnell … so weit es geht loom steps zu skippen"                                                   | §7.1 lists what is skipped and what is kept, §7.2 why pass 1 stays; 0.57× at 300 rows, no gain at 5 rows                                         | answered for loom; partly for "möglichst schnell": no absolute time for typical invoices, no one-process batch (RQ5)                                |
| 8   | "Der Design Code und die Appearance … nur in Typst … Allein die Daten sollen ausgetauscht werden"             | R1 "design is never data", closed objects, no expressions in data (§6.3)                                                                         | answered; a data value selects an asset only through the skeleton's own table, which respects the boundary. The locale per invoice is unclear (RQ9) |
| 9   | "die APIs sollen so weit wie möglich nur erweitert werden … Änderung … sehr gut begründet"                    | §9 ledger with ⚠ rows; P2 over 1105 documents                                                                                                   | answered (see the maintainer critique on L15); the cost of `payment(..)` is not stated (RQ15)                                                       |
| 10  | "Phase 1 … ein allgemeines Interface, was per typst cli angesprochen werden kann"                             | §5: input keys, exit codes, result record, layout-free `check`, schemas                                                                          | partly: no machine-readable failure channel, two issue shapes (RQ7); offline and font pinning for pipelines not mentioned (RQ16)                    |
| 11  | "in der Phase 2 … native Bindings … aktuell noch nicht im Scope"                                              | §10 lists the hooks; nothing of phase 2 is built                                                                                                 | answered; the coverage table adds an inferred clause and the plan pulls phase-2 tooling into 0.7.0 (RQ14); one claim about typst-py is wrong (RQ13) |

## Hands-on: hydrating the 0.6.0 template

I took `template/invoice.typ`, changed only its import to the prototype's `lib.typ`, and followed the concept. The data file `d1.json` has the `format`, a number, a date, a recipient in München and two items; `d1-pay.json` adds a direct debit. Results on 0.15.1; where 0.14.2 is named, it was checked too.

| Step | Change to the template                                                                                                          | Result                                                                                                                                                                                                                                |
| :--- | :------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0a   | none; `--input invoice-pro-data="$(cat d1.json)"`                                                                               | hydrates: "RECHNUNGSNUMMER 2026-07", Acme GmbH, the two data rows, `factur-x.xml` attached; the template's terms and bank stay (issuer keys)                                                                                          |
| 0b   | none; inline `d1-pay.json` (with a `payment` section)                                                                           | draft "ENTWURF · 1 Problem · keine E-Rechnung": the coverage issue "replace `payment-terms`/`bank-details` by `payment(terms: .., bank: ..)`"; as documented (§4.5)                                                                   |
| 0c   | none; `--input invoice-pro-data-file=d1.json`                                                                                   | panic with the one-line fix; as documented (§2.5)                                                                                                                                                                                     |
| 1    | the `load` line, `data: record`, and `payment(..)` instead of `payment-terms(..)` + `bank-details(..)` (diff below)             | preview md5 equal to the 0.6.0 template compiled on pristine 0.6.0, on 0.15.1 and 0.14.2, with and without `--pdf-standard a-3b`; hydrated from `d1-pay.json` on both compilers: final, XML attached, result `status: ok`, due 481.79 |
| 2    | a coat-of-arms rule written the obvious way (block in RQ1)                                                                      | good data: fine. Data without `recipient`, a city string without post code, a numeric `post-code`: 3 of 3 abort the compile with a Typst error and no draft, on both compilers                                                        |
| 3    | the concept's rule of §2.1 instead (`prototype/examples/skeleton.typ`), with the same three files and `"custom": {"wappen": 5}` | 4 of 4 compile on both compilers (two drafts, two final invoices)                                                                                                                                                                     |

The diff of step 1, the whole change a typical invoice needs:

```diff
+#let record = invoice-data.load(read: p => read(p, encoding: none))
+
 #show: invoice.with(
+  data: record,
   theme: theme.bold, // the look, see THEMES above
@@
-#payment-terms(days: 14)
-
-#bank-details(
-  bank: "Musterbank",
-  iban: "DE07100202005821158846",
-  bic: "EXAMPLEBICX",
+#payment(
+  terms: (days: 14),
+  bank: (
+    bank: "Musterbank",
+    iban: "DE07100202005821158846",
+    bic: "EXAMPLEBICX",
+  ),
 )
```

Friction I met, in the order a user meets it:

1. The executive summary says "add one line". For an invoice with bank details, the real change is the line, `data: record` and the `payment(..)` swap. The swap is needed as soon as the data carries anything about payment. The concept says this only in the bullets under §2.1 and in §4.5.
2. My first rule crashed the compile on the first incomplete file (RQ1).
3. `skel/skeleton.typ` with `--input invoice-pro-data-file=data/d1.json` from the project folder gave "file not found (searched at …/skel/data/d1.json)" (RQ6).
4. To preview the skeleton with a real data file while designing, I needed the `inputs:` parameter, which the concept describes as "injectable for tests" (RQ8).

## Findings

### Major

**RQ1. Rules in the skeleton can abort the compile, and the concept does not say so.** The decoder drops invalid values and rows, so `invoice-data.values(record)` may lack any key, including the required ones. Custom bags are untyped. A rule that assumes a key or a type therefore stops the compile with a Typst error, and the draft that the concept promises never appears. This block assumes the import and a `party` dictionary, as the concept's blocks do; it compiles alone and with complete data:

```typst
#let record = invoice-data.load(read: p => read(p, encoding: none))
#let values = invoice-data.values(record)
// Looks reasonable, but every access assumes the data is complete.
#let recipient = if values == none { party.recipient } else {
  values.recipient
}
#let plz = invoice-data.party(recipient).post-code
#let wappen = image(
  if plz.starts-with("8") { "wappen/bayern.svg" } else {
    "wappen/neutral.svg"
  },
  alt: "Wappen",
)
```

Measured on 0.15.1 and 0.14.2: data without `recipient` → "dictionary does not contain key "recipient"". A city `"München"` without post code, or a numeric `post-code` (an issue, so the value is dropped) → "type none has no method `starts-with`". `"custom": {"wappen": 5}` with `key in arms` → "cannot apply 'in' to integer and dictionary". The concept's own rule in §2.1 survives all four because of its `.at(.., default: none)` and `type(..)` guards. The text never explains those guards, so a user who shortens the rule removes them.

This also qualifies two claims. §8.3 says "A draft never crashes on bad data". That holds for invoice-pro's code only, and P4 is "fail" in §11.2 even for that (O1–O3). The requirement row 3 calls the pattern the answer to "Wappen je nach PLZ". It is, but only when it is written defensively.

_Fix:_ state the rule in §2.1 and §6.2: "A rule must accept every value as absent or of an unexpected type: the decoder drops invalid values, and custom fields are untyped. A panic in a rule stops the compile and loses the draft." Then make the safe form short. Possible shapes, _proposed_:

- `invoice-data.values(record, default: sample)`, which returns the samples without data and the values with data. It replaces the `shown` idiom.
- A safe getter, such as `invoice-data.get(values, "recipient", "city", "post-code", default: none)`, that also accepts `none` on the way.

With both, the §2.1 rule shrinks from 14 lines of logic to about 5. Qualify §8.3 with "in invoice-pro's own code, outside §11.5".

**RQ2. No migration recipe for an existing invoice.** Requirement row 4 ("easy integration") cites P1 and P3 as evidence. They prove correctness, not ease. The concept never shows an existing invoice becoming a skeleton. §2.1 starts from a new skeleton with `sample`, `shown` and `payment(..)`, so a reader cannot tell what is required and what is style. From my exercise, the required changes are:

| Change                                                      | Needed when                                                                              |
| :---------------------------------------------------------- | :--------------------------------------------------------------------------------------- |
| none                                                        | inline JSON without a `payment` section                                                  |
| the `load` line and `data: record`                          | a data file, stdin, or a design rule that reads the data                                 |
| `payment(..)` instead of `payment-terms`, `bank-details`, … | the data has a `payment` section (otherwise a draft with `schema/payment`, strict stops) |
| per-invoice values gathered in a `sample` dictionary (§2.1) | only for a design rule that should also preview the samples                              |
| `invoice-data.items[..]` around the sample rows             | a fixed row that stays on every invoice (R5 of §4.2)                                     |

_Fix:_ add this table as §2.0, "Make an existing invoice a skeleton", with the template diff above. Put the `payment(..)` swap into step 2 of the executive summary. Note under requirement row 4 that the evidence for ease is this recipe.

**RQ3. The template stays non-hydratable, although converting it changes no output.** §9 keeps `template/invoice.typ` "an invoice without data". That is the file a user gets from `typst init @preview/invoice-pro`. As shipped, it panics on `--input invoice-pro-data-file`, and it turns any data with a `payment` section into a draft. Converted as in step 1, its preview stays the same. Measured in this review: the converted template on the prototype, the unchanged template on the prototype and the unchanged template on pristine 0.6.0 have the same md5 on 0.15.1 (`5472f30f5d36` with a-3b, `c218c6e29992` without) and on 0.14.2 (`f38a65ecbc99`, `81793db8e944`). The template contains `datetime.today()`, so these are same-day compiles.

The golden XML and the thumbnail would therefore be unaffected. The cost is two root names in the template (`invoice-data`, `payment`) and a short comment block.

_Fix:_ make the template a skeleton in S6 (the `load` line, `data: record`, `payment(..)`, three comment lines on hydration). Or add it as a question for the maintainer with this evidence. As written, §9 presents "unchanged" as a constraint, and it is a choice.

**RQ4. The roadmap item "Data Loading" is not delivered, but S6 ticks its checkbox.** The roadmap entry (`docs/docs/contributing.md:95`) reads "Helper functions to load invoice items directly from JSON, CSV, or YAML data sources". It means a hand-written Typst invoice whose rows come from a file. In 0.7.0 that is not possible. `data:` hydrates the whole invoice, and document keys come from the data alone. A Typst user who tries the obvious thing gets a draft:

- Tried in this review on 0.15.1: `data: (format: "invoice-pro/1", items: csv("items.csv", row-type: dictionary))` in a skeleton that sets `invoice-nr` and `recipient`.
- Result: "ENTWURF · 5 Probleme", with ‹fehlt: Rechnungsnummer› and the recipient's name and address missing. The skeleton's values were treated as samples.

Q33 defers "CSV rows for the marker" to 0.7.x, and S6 lists "the roadmap checkbox" among the registries. Together they would tick a box for a feature that is not built.

_Fix:_

1. Add a row "Data Loading (roadmap): items from a file in Typst" to the requirement coverage as _not in 0.7.0_, with the workaround: map the rows to `item(..)` calls as in 0.6.0, or put the whole invoice into the data.
2. Warn in §2 that `data:` replaces every document key.
3. Keep the checkbox open, or split the roadmap entry.

**RQ5. "Möglichst schnell" is argued for 300 rows. Typical invoices and batches are missing.** §7 shows clearly which loom steps are skipped and why pass 1 stays. But a typical invoice has fewer than 10 rows, and there the concept reports only ratios ("no gain") and no absolute time.

The verification has one: b-5 with an e-invoice takes 0.455 s written by hand and 0.456 s hydrated on 0.15.1 (round 1, `verification.md` line 216). It also has the import's weight: the root import runs about 514 M instructions (§7.3), a b-5 invoice 1.850 G by hand and 1.894 G hydrated (round 2), so the import is about 27 % of a small invoice.

Measured in this review on 0.15.1 (medians of 9, `-j 1`): an empty document takes 0.068 s, a document that only imports the package takes 0.245 s, and one 2-row hydrated invoice from a file takes 0.444 s. The package import is paid once per process. That makes the one-process batch the largest speed lever for small invoices.

The research found this ([`../research/typst-cli.md`](../research/typst-cli.md), line 67: "otherwise pagebreak (non-ZUGFeRD only)"). The concept dropped it. §5.3 mentions only processes and the experimental 0.15 bundle.

Measured in this review, 20 hydrated 2-row print invoices (without an e-invoice), `-j 1`:

| Compiler | 20 sequential processes, one file each | one document, 20 `invoice(data: ..)` calls from one JSON array |
| :------- | -------------------------------------: | -------------------------------------------------------------: |
| 0.15.1   |                         9.09 s, 9.22 s |                                                 2.96 s, 3.15 s |
| 0.14.2   |                                10.42 s |                                                         4.28 s |

The one-document form works with the prototype as it is: 20 pages, one result record per invoice (`typst query` returned 20 records with status `ok`). With `zugferd` set, it stops with "attempted to attach file factur-x.xml twice", as the research says.

_Fix:_

1. Add §7.0 "A typical invoice": the absolute time of a small invoice on both compilers, from the reports, and where it goes (startup, package import, fonts, layout).
2. Add the one-document print batch to §5.3, with its limit (no e-invoice; one PDF for all, so it suits a print or letter shop).
3. Mention it in Q31. The import costs about 0.18 s per process (0.245 s − 0.068 s above), so the 1.2–1.5 ms debated in Q2 is small next to what a one-process batch saves.

**RQ6. Data paths resolve against the skeleton, and the examples hide it.** `load` calls the skeleton's `read`, so a relative `--input invoice-pro-data-file` is relative to the skeleton file, not to the shell's working directory. Every example in §2.2 and §5 runs with the skeleton in the current folder, so the difference never shows.

Reproduced on 0.15.1: `typst compile --root . skel/skeleton.typ out.pdf --input invoice-pro-data-file=data/d1.json` → "file not found (searched at …/skel/data/d1.json)". An absolute filesystem path fails the same way, because it is read from the project root. A pipeline that writes its data to a spool or temp folder must therefore put the data under `--root`.

§5.2 recommends `--root /` for stdin. That gives the skeleton read access to the whole filesystem. `prototype/run.sh` avoids it with a link `<root>/dev/stdin → /dev/stdin`, but the concept does not show that variant.

_Fix:_

1. Add one example with the skeleton in another folder, and recommend the root-relative form (`/data/x.json`) for pipelines.
2. State that the data file must lie under `--root`.
3. Show the `dev/stdin` link as the POSIX way that keeps the root narrow, and keep `--root /` as the simple way with its trade-off.

**RQ7. The failure channel of the CLI interface is free text, and the two issue lists differ.** For phase 1, "an interface addressed via the Typst CLI", the outputs are the PDF, the exit code and `<invoice-pro-result>`. Under `strict` a failing build exits 1, writes no result, and lists the problems only in the panic text. Typst exits 1 for every error, so a program cannot tell bad data from a missing font or a typo in the skeleton without parsing stderr.

To learn why a build failed, a program must compile again in `draft` and query the result (a second full compile), or run `check()` first, which misses skeleton and e-invoice rules (Q34). The concept describes these pieces in §5.4 and §5.5 but gives no recipe.

Reproduced on 0.15.1 with the prototype's `data/bad.json`. `check()` returns 6 issues with the keys `{id, path, key, message, fix}`. The result record of the hydrated draft has 8 issues with the keys `{id, class, path, message, ref}`: no `key`, no `fix`. The same problem thus has two shapes, depending on where a binding reads it.

_Fix:_

1. Add §5.9 "A pipeline": `check` → compile `strict` → on exit 1, `typst query … --input invoice-pro-validation=draft` for `issues[]`.
2. Name the stable message prefixes ("invoice data:", "invoice-pro found n problems") as part of the contract, or state that they are not.
3. Unify the issue shape of `check` and of the result (or document the mapping), before the result schema is frozen as `invoice-pro-result/1`.

### Minor

**RQ8. Previewing the skeleton with real data while designing.** The workflow is "design by hand, then hydrate". While designing, a user wants to see long names, 50 rows or a direct debit. That happens in the web app, which has no `--input`, or in an editor, which needs extra configuration for it. The injectable `inputs:` already allows it. Verified on both compilers, a CLI input still wins:

```typst
// Preview with a real data file in an editor or the web app; a data input
// given on the CLI still wins, because the right operand of `+` overrides.
#let record = invoice-data.load(
  read: p => read(p, encoding: none),
  inputs: (invoice-pro-data-file: "d1.json") + sys.inputs,
)
```

§4.3 calls `inputs:` "injectable for tests". _Fix:_ document this as the design-time preview, in §2.2.

**RQ9. The locale per invoice reads as impossible, but it works.** Q32 says "The locale from data … no in v1". The most common "change by a field value" after a logo is the language for foreign recipients. It works today with the same pattern as the coat of arms. Verified on both compilers, with `"custom": {"lang": "en"}` the title reads "Invoice 2026-07":

```typst
#let record = invoice-data.load(read: p => read(p, encoding: none))
#let values = invoice-data.values(record)
#let custom = if values != none { values.at("custom", default: none) }
#let lang = if type(custom) == dictionary { custom.at("lang", default: none) }

#show: invoice.with(
  data: record,
  locale: if lang == "en" { locale.en-de } else { locale.de-de },
  ..party,
)
```

_Fix:_ add it as a row and an example in §6.2. Rephrase Q32 as "no locale key in the format; the skeleton selects the locale by a value".

**RQ10. One key per field is neither offered nor rejected with a reason.** "aus … den sysparametern" can be read as `--input invoice-nr=2026-0042 --input date=…`. The concept chooses one JSON document per key. That is right: inputs are strings only, the format is nested, and one schema covers it. But Appendix B gives no reason. A skeleton can merge a value of its own key into the data, `data: json(sys.inputs.f) + (invoice-nr: sys.inputs.nr)` (verified on 0.15.1), as long as no `invoice-pro-data*` key is given too (R7 of §4.2). _Fix:_ one paragraph in §5.1, a row in Appendix B, and this merge as the pattern for a single overriding value until `derive` exists.

**RQ11. The post-code rule is illustrative, and the text should say so.** The first digit does not pick a Land. 88xxx and parts of 89xxx are Baden-Württemberg. 1xxxx includes Brandenburg and Mecklenburg-Vorpommern. 2xxxx includes Schleswig-Holstein, Bremen and Lower Saxony. Since the maintainer named this case, readers will copy it.

A realistic rule is a lookup table in the skeleton's project. Measured in this review on 0.15.1 (medians of 7): `csv("plz.csv")` with 8246 rows turned into a dictionary adds no measurable time, 0.532 s against 0.526 s for the first-digit rule.

_Fix:_ one sentence and a table variant in §6.2.

**RQ12. Item custom fields have no worked example.** §3.8 and §6.1 say that `view.items[i].custom` reaches table parts. Printing a per-row value means replacing or wrapping the items table, which is theme work. Hand-written sample rows have no `custom` (Q30), so the preview cannot show it. _Fix:_ show one wrap, or say plainly that printed per-row text belongs in `description` or `note`, and that item custom fields serve theme authors and pipelines.

**RQ13. The typst-py claim is wrong.** §10.4 says that embedders, "Rust `Library::with_inputs`, typst-py `sys_inputs`", may pass a dictionary as the value of `invoice-pro-data`; the docs of `load` and §5.1 repeat it for embedders in general. Tried in this review with typst-py 0.15.0 (PyPI): `typst.compile(.., sys_inputs={"invoice-pro-data": <dict>})` raises "TypeError: 'dict' object is not an instance of 'str'". JSON text works (a 59 632-byte PDF). The Rust path is plausible but was not run in any round; the unit test only injects `inputs:`. _Fix:_ correct §10.4 (typst-py: JSON text) and mark the Rust case as _not verified_.

**RQ14. Phase 2 leaks into the requirement table and the plan.** Requirement row 8 reads "Phase 2 (native bindings) is not in scope, but phase 1 should not stand in its way". The second half is the author's inference, not the maintainer's words. Elsewhere, the codegen CI job of S1 brings three generators and their toolchains (Python, Node, Rust) into 0.7.0. Phase-1 design choices for code generators (`dependentSchemas`, no `maxLength`, `""` for texts only) are defensible. A CI job is phase-2 work. _Fix:_ mark inferred requirements as such in the table. Move the codegen job to phase 2, or mark it optional in S1.

**RQ15. The cost of `payment(..)` is not stated.** The concept recommends the block and lists its nested weave as risk 4, but gives no number. Measured in this review on 0.15.1 with cachegrind (one run each, no data): the template with `payment(..)` runs 2.337 G instructions against 2.320 G with the raw components, +16.7 M (+0.72 %). Wall clock is within noise (0.761 s against 0.754 s, medians of 11). Small, but it is about four times the import delta the concept discusses at length. _Fix:_ one line in §7.3.

**RQ16. Pipelines need offline packages and pinned fonts.** The md5 identities hold per machine and font set. A production pipeline wants `--font-path` with `--ignore-system-fonts` (reproducible PDFs; §8.5 already names a font-dependent PDF/A stop) and a package cache or `--package-path` for builds without network. _Fix:_ two lines in §5.2.

## Questions the maintainer will ask that the concept does not answer yet

1. "How does a new user start?" `typst init` gives a template that is not a skeleton (RQ3).
2. "What do I change in my existing invoice?" (RQ2)
3. "How long does one ordinary invoice take, and 1000 of them?" (RQ5)
4. "Can I load just the line items from a CSV in my Typst invoice?" Not in 0.7.0 (RQ4).
5. "Can I see my skeleton with real data in the editor?" (RQ8)
6. "Can the language follow the recipient?" Yes, but the concept suggests no (RQ9).
7. "Why one JSON key instead of `--input invoice-nr=…`?" (RQ10)
8. "How does my program learn why a strict build failed?" (RQ7)
9. "Can a mistake in my own skeleton rule break a batch?" Yes (RQ1).

## Missing

- A section "Make an existing invoice a skeleton" with the template diff (RQ2).
- An explicit list of what 0.7.0 does not deliver for the request, next to the coverage table. Today it is spread over Q17, Q18 and Q30–Q33: items only from Typst, `derive` for document keys, the result in the same compile, a one-process batch helper, declared custom fields.
- The absolute time of a typical invoice and the one-document print batch (RQ5).
- A pipeline recipe with the failure path (RQ7).
- The rule that skeleton rules must tolerate absent values, and a helper that makes it easy (RQ1).

## What I ran

All under `<session>/critique-requirements/`, against the prototype tree (`--root` at the session folder, `lib.typ` of the patched tree), Typst 0.15.1 and 0.14.2.

| Check                                                                                   | Result                                                                                       |
| :-------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------- |
| template unchanged, inline data without and with `payment`; file input                  | hydrates; coverage draft; panic with the fix (as documented)                                 |
| template converted (step 1), preview md5 against pristine 0.6.0, ± a-3b, both compilers | equal (4 of 4 pairs)                                                                         |
| converted template hydrated from a file with a direct debit, both compilers             | final, `factur-x.xml` attached, `status: ok`                                                 |
| naive rule (RQ1) on 3 incomplete files, both compilers                                  | 6 of 6 compiles abort                                                                        |
| §2.1 rule on the same 3 files + an integer `custom.wappen`, both compilers              | 8 of 8 compile                                                                               |
| skeleton in a subfolder with a cwd-relative data path                                   | file not found (RQ6)                                                                         |
| `data:` with only CSV items (RQ4)                                                       | draft, 5 problems                                                                            |
| 20 print invoices: processes against one document (RQ5)                                 | 9.1 s vs 3.0 s (0.15.1), 10.4 s vs 4.3 s (0.14.2); with `zugferd`: "attach … twice"          |
| empty document, import only, one small invoice (RQ5)                                    | 0.068 s, 0.245 s, 0.444 s (0.15.1, medians of 9)                                             |
| `inputs:` preview with CLI override (RQ8), locale by `custom.lang` (RQ9)                | both work on both compilers                                                                  |
| `check()` vs the result's `issues[]` for `data/bad.json` (RQ7)                          | 6 issues `{id, path, key, message, fix}` vs 8 issues `{id, class, path, message, ref}`       |
| typst-py 0.15.0 with a dictionary input (RQ13)                                          | `TypeError`; JSON text works                                                                 |
| `payment(..)` vs components, cachegrind (RQ15)                                          | +16.7 M instructions (+0.72 %)                                                               |
| 8246-row post-code table (RQ11)                                                         | 0.532 s vs 0.526 s                                                                           |
| the three `typst` blocks of this critique                                               | typstyle 0.15.1 clean; compile on 0.15.1 and 0.14.2 with a `party` dictionary and the import |
