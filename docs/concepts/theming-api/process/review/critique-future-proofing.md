# Critique of concept draft 1: freeze regret (key `future-proofing`)

Lens: everything draft 1 marks **frozen** or **stable** (§5.2, §3.1–§3.8, §2.5 helper names) is permanent for a
solo maintainer. For each item: what will we regret at v0.6 / v1.0, and should we **change it now** or
**mark it provisional**? The goal is a stable surface that is as small as possible without making the API useless.

Prototype copy: `scratchpad/crit-future-proofing/` (copied from `proto-synthesis`, typst 0.15.1). Every new probe
is in `crit-future-proofing/fp/*.typ` and writes to `out/fp/`. Evidence tags: **VERIFIED** (reproduced here),
**SOURCE** (read in code, docs or a standard), **REASONED** (argument only).

---

## 0. Verdict in one paragraph

The structural backbone (layouts as data, regions, a parts registry, one patch engine) ages well. Adding fields
to views and records is additive-safe: Typst dict destructuring ignores extra keys (VERIFIED, `fp/destr.typ`).
Unknown named args and non-dict patches panic today, which reserves them for later. But draft 1 freezes three things
that bake in **"invoice, German, SEPA, one bank account"**, and freezes a token tier where **a third of the leaves
have no consumer**:

1. **Required parts and roles** are global rather than per document kind. They block delivery notes, receipts and
   plain letters, yet an empty renderer bypasses them (FP-1, blocker).
2. **12 of 35 frozen tokens** change nothing when set (FP-2), and several names encode the sign of an amount or an
   arbitrary grey scale (FP-3).
3. **Frame, bank and payment views** freeze a single `bank`, non-nullable `totals`, a `date: str` and an EUR-only
   `qr(size)`. EN 16931 itself allows 0..n credit-transfer accounts plus direct debit (FP-5, FP-6).
4. **Standard region names** are a hidden mandatory contract for every third-party layout. Adding one in v0.6
   breaks them all (FP-4).
5. **`env`** is frozen but never validated and never read. `kind: "banana-note"` is accepted, and no vocabulary
   exists (FP-7).

Most of this is fixed by one rule: **"freeze only what a built-in consumer exercises at the lock and what is
kind-neutral; everything else is provisional."** Section 3 has a concrete minimal frozen list.

---

## 1. Regret list (most severe first)

### FP-1 (blocker): required parts and roles are invoice-only, frozen, and both too strong and too weak

**Where:** §3.6 (Required column), §5.2 ("required parts and roles" frozen), §5.3 rows "invoice identity" and
"recipient address", §8 messages 4–7. Code: `src/theming/validate.typ:8-10`, `:88-97`, `:119-121`;
`src/theming/frame.typ:48-55`.

**Too strong (VERIFIED, `fp/kinds.typ --input case=…`):**

| Document kind (#10, R27)                                                   | Needs                                            | Result on draft 1                                                               |
| -------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------- |
| Delivery note (no prices, no bank, no totals)                              | `part("totals", none)`                           | `theme::parts::totals carries legally required output and cannot be none`       |
| Delivery note                                                              | `part("bank-details", none)`                     | same panic for `bank-details`                                                   |
| Delivery note (priceless table)                                            | `part("items-table", none)` or a different table | same panic for `items-table`                                                    |
| Receipt / Kleinbetragsrechnung (§ 33 UStDV: no recipient address required) | `region("address", none)`                        | `must host part recipient in exactly one first-page or flow region (found 0)`   |
| Plain cover letter (§ 35a GmbHG applies to all business letters)           | `region("title", none)`                          | `must host part title … (document title, invoice number and date: § 14 UStG …)` |

None of `bank-details`, `totals` or `items-table` is legally required, even on an invoice. § 14 UStG requires
amounts, but not a totals _part_ and never bank details. EN 16931 has BG-16 payment instructions as 0..1. The
EPC-QR guarantee already lives in core (`view.qr`), so "`bank-details` cannot be `none`" protects nothing.

**Too weak (VERIFIED, `fp/bypass.typ` → `out/fp/bypass-1.png`):** this compiles cleanly and produces a page
with no invoice number, no date, no items, no totals and no bank block, while the "identity guard" passes:

```typst
part("totals", (ctx, view) => none), part("bank-details", (ctx, view) => none),
part("items-table", (ctx, view) => none), part("title", (ctx, view) => [x]),
```

The only check is "non-empty output" (`frame.typ:54`). Also (SOURCE, `parts/frame.typ:84-87`): the default
`"line"` title never renders `document.number`. The number reaches the page only because core pre-concatenates it
into `subject` (VERIFIED, `fp/subj.typ`: subject `Leistungen September` renders as "Leistungen September
2026-0142"). The frozen message "title carries invoice number and date" is therefore a promise the contract
does not enforce.

**Regret at v0.6:** document kinds (roadmap item 1 in #10, §12 "0.5.x document kinds") need required-set changes.
A frozen global list can only be _relaxed_ (a breaking semantic change to "frozen") or worked around with
`(ctx, view) => none`, which the error messages themselves teach as the escape hatch.

**Change now:**

- Freeze the _mechanism_, not the list. `required` is a function of `env.kind`, documented as a table:
  - `invoice`, `credit-note`, `corrected-invoice`: `title` + `recipient` + `notices`;
  - `receipt`: `title` + `notices`;
  - `delivery-note`, `quote`, `order-confirmation`: `title` + `recipient`;
  - `letter`: `recipient`.

  Ship only the `invoice` row in 0.5.0 and mark the table **provisional**.

- Remove `items-table`, `totals` and `bank-details` from `required-parts`. Keep `notices`. It is the only part
  whose content core decides. `line-items` may stay non-`none` for kinds that have line items.
- Make identity a **core** guarantee, not a role test. Core emits the number and date as tagged text through
  the view (`view.document.identity: content`, built in root) or at least checks that the `title` part output
  contains `view.document.number`. Otherwise drop the promise from the frozen docs.
- Reword the messages to be neutral: "document identity (number and date)", with no "invoice" and no "§ 14 UStG"
  unless `env.kind` is `invoice`.

### FP-2 (major): 12 of the 35 frozen tokens have no consumer, so their semantics are frozen without a reference implementation

**Where:** §3.2 ("frozen", all 35 paths), §5.2 "token paths". Code: `src/theming/schema.typ:31-71`.

**VERIFIED** (`fp/tok.typ`, `fp/tokm.typ`, `--input case=…`; the rendered PNGs are byte-identical to `base`
under **both** `classic` and `modern`):

| Token(s) set to an extreme value                                   | Visual effect                                                                                |
| ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `colors.accent`, `on-accent`, `accent-text` = red                  | none (md5 `e624250a…` = base)                                                                |
| `colors.paper` = black                                             | none                                                                                         |
| `colors.mark` = red                                                | none. Marks read `layout.marks.stroke` (`parts/frame.typ` `marks`), a second source of truth |
| `fonts.numeric` = "DejaVu Serif", `fonts.figures` = "proportional" | none. R4 is claimed but not built                                                            |
| `weights.regular` = 900                                            | none                                                                                         |
| `spacing.xs`, `spacing.lg` = 5em                                   | none                                                                                         |
| `strokes.hairline` = 5pt                                           | none                                                                                         |
| `colors.rule` = red                                                | changes (control)                                                                            |

SOURCE (grep of `src/`): zero consumers outside `schema.typ` and `validate.typ` (contrast) for all of these.
Tokens that _are_ consumed are often bypassed:

- the stacked title uses a literal `2em` rather than `sizes.title` (`parts/frame.typ:78`);
- references use `8pt` (`:57`), page number `0.85em` (`:121`) and continuation `0.8em` (`:130`);
- region `gap: 0.6em` is a literal (`schema.typ:109`), although §3.2 documents `spacing.md` as "region gap".

**Regret:** a frozen name with no consumer gets its meaning from the first third-party package that uses it. By
v0.6 the maintainer either can't change it, or finds that `accent-text` means different things in built-ins and in
packages. `colors.mark` vs `layout.marks.stroke` is already a two-sources-of-truth bug.

**Change now:** adopt the rule **"a token is frozen only if a built-in part reads it at 0.5.0, verified by a CI
mutation test"**: set each frozen token to an extreme value and assert that the rendered output differs. That
is ~35 compiles and cheap.

- Remove `colors.mark`. Derive `marks.stroke` from `t => t.strokes.hairline + t.colors.text` (or keep `mark` and
  make `marks.stroke` default to a derivation of it; don't have both).
- Wire the literals above to tokens.
- Everything else goes to **provisional** (FP-3 lists which).

### FP-3 (major): several token names encode sign or arbitrary greys and will age badly (DTCG, Material 3, credit notes)

**Where:** §3.2 rows `negative` ("discounts"), `positive` ("#333333", "surcharges"), `label` ("tax labels"),
`muted` (luma 100), `subtle` (luma 80), `surface`, `paper`; §2.5 `colors` helper. Code: `schema.typ:38-47`.

**Findings (SOURCE, REASONED):**

- **`negative`/`positive` name the sign of an amount.** In every design system (Material 3 `error`, Carbon
  `support-error/success`, Atlassian `danger/success`), "positive" means _good/success_ (green). Here it is dark
  grey for surcharges. On a **credit note** or a Storno invoice every amount is negative, so a part following the
  token name paints the whole document red. A **reminder** needs an _alert/overdue_ colour for the due date and fees,
  and nothing covers it.
- **`subtle` (luma 80) is darker than `muted` (luma 100)**, the opposite of the usual meaning ("subtle" is the
  lighter one). `label` (#475569) is a third, blue-grey tier whose only consumer is the VAT label. Three
  secondary-text greys with no ordering rule become three names nobody can explain in v1.0 docs.
- **`surface` means "zebra tint" here.** In Material 3, `surface` is the page background, the role `paper` plays
  here, and tints are `surface-container*`. The planned DTCG adapter (§12, 0.5.x) will need a mapping table with
  inverted names forever.
- **`rule`** is a print term. `border`/`outline` is what DTCG and Material users look for.
- **`sizes.*` and `spacing.*` in `em`:** DTCG 2025.10 `dimension` allows only `px`/`rem`, so em tokens can't
  round-trip. The planned `sizes.fine ≥ 6pt` check (§8 "specified, not built") can't be evaluated at resolve time
  when a brand sets `fine: 0.6em`, because it needs layout context.

**Change now (rename before the lock; the house has no aliases for frozen names):**

| Draft 1                                                | Proposed                                                                                                                                      | Tier                                                                                             |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `colors.text` / `muted` / `subtle` / `label`           | `colors.text` / `text-muted` (single secondary grey)                                                                                          | frozen. Move `label` and `subtle` to options (`totals.label-color`, `line-items.subtitle-color`) |
| `colors.negative` / `positive`                         | `colors.critical` (alert, overdue, errors), frozen. Discount/surcharge colours become options `items-table.decrease-color` / `increase-color` | critical frozen, others provisional                                                              |
| `colors.surface`                                       | `colors.tint` (or `surface-variant`)                                                                                                          | frozen                                                                                           |
| `colors.paper`                                         | `colors.background`                                                                                                                           | provisional until something paints it                                                            |
| `colors.rule`                                          | `colors.border`                                                                                                                               | frozen                                                                                           |
| `colors.accent`, `on-accent`, `accent-text`            | keep the names                                                                                                                                | **provisional** until a built-in look uses them                                                  |
| `colors.mark`                                          | delete (FP-2)                                                                                                                                 | –                                                                                                |
| `fonts.numeric`, `fonts.figures`                       | keep                                                                                                                                          | provisional until the M3 table consumes them                                                     |
| `weights.regular`, `spacing.xs/lg`, `strokes.hairline` | keep                                                                                                                                          | provisional                                                                                      |
| `sizes.fine`                                           | type `length` restricted to **absolute** (pt/mm); `small`/`large`/`title` may be em                                                           | frozen, with a validation rule                                                                   |

This yields ~20 frozen tokens instead of 35. "Tokens grow only additively" (§3.2) still holds, because promoting
a token from provisional to frozen is additive.

### FP-4 (major): standard region names are an undeclared mandatory contract for third-party layouts, and new standard names in v0.6 break them

**Where:** §3.4 "Standard region names … Looks may only patch standard names"; §6 "A new format without forking is
a layout dict"; walkthrough (9), where the sidebar layout carries **empty dummy regions** `marks`, `letterhead`,
`continuation`, `footer` (`tests/pkgs/local/acme-theme/0.1.0`).

**VERIFIED** (`fp/stdnames.typ`, a layout that only defines `title` and `address`):

- `theme.classic` compiles (the classic look is empty);
- `theme.modern` panics: ``theme::layout::regions has no region `letterhead` in layout `pkg-min`… To ADD a region, give it a `place`.``;
- `theme.minimal` panics the same way for `footer`.

**Regret:** every package layout must declare every standard name, even when it doesn't use it. When v0.6 adds a
standard name (a `stamp` region for R26, `payment-slip`/`qr-bill`, a `sidebar`) and a built-in look patches it,
**every published layout breaks**. That contradicts the §6 promise that "keys added later arrive with their
defaults", which today holds for keys but not for region names.

**Change now:** the injected `base` layout supplies **every standard region as an empty stub**
(`parts: ()`, a place-appropriate default, renders nothing when all parts are empty). A user layout merges over it,
so new standard names arrive through injection exactly as new keys do. Keep "did you mean" for _non-standard_
names. Freeze the _list_ of standard names as "may grow; stubs are injected". Also check that an empty stub with a
look-applied `fill` (e.g. the modern band) renders nothing. Today `render-region` does not guard this (REASONED).

### FP-5 (major): the frame view freezes invoice- and DE-specific shapes (single `bank`, non-null `totals`, `date: str`, raw party dicts)

**Where:** §3.8 frame view (bold = frozen), appendix Q7 ("freeze frame, bank, payment, signature views").
Code: `src/theming/frame.typ:19-46`.

**SOURCE findings:**

- `document.kind: "invoice"` and `document.title: ctx.locale.strings.document.invoice` are hard-coded
  (`frame.typ:25-26`). The locale has only `strings.document.invoice` (repo `src/locale/lang/base.typ:32-34`).
- `document.date` is a **pre-formatted `str`**. Body views v2 say "every amount, rate and date is
  `(value, text)`" (§3.8). Freezing the frame view with `date: str` makes the two frozen contracts inconsistent
  from day one, and a part can't compute "due in N days" or format the date differently.
- `document.subject` already contains the number (VERIFIED, `fp/subj.typ`), so a part showing `subject` and
  `number` prints the number twice. The semantics of `subject` are unclear.
- `bank`: **one** "bank signal or none". EN 16931 **BG-17 CREDIT TRANSFER is 0..n** (several accounts are common in
  DE footers), and BG-19 DIRECT DEBIT is a different payment means. Core itself hard-codes `TypeCode 58` (repo
  `src/zugferd/build.typ:492`) and document `TypeCode 380` (`:117`). The theme contract should not freeze that
  limitation.
- `totals: (net, gross, due, prepaid)` is non-nullable. A delivery note has none. A reminder needs `outstanding`,
  `fees` and `interest`. A credit note's sign convention is undefined. There is no `currency` field (multi-currency,
  QR-bill CHF).
- `sender`/`recipient` pass the raw `ctx.sender`/`ctx.recipient` input dicts (`frame.typ:32-33`), including
  internal `name-inline`/`address-inline`/`city-inline` keys. Freezing "normalized parties" here freezes the
  `invoice()` header normalization. `address` + `city` as two strings also bakes in the DE address order. US
  (`City, ST ZIP`), UK and JP orders need a locale-formatted `lines: array<content>`.

**Change now:**

- `document`: freeze only `kind`, `number`, `date: (value: datetime, text)`, `title` (content, taken from
  `strings.document.<kind>`) and `subject` (the user text **without** the number).
- Party views: freeze `name` and `lines: array<content>` (locale-formatted). Structured fields are provisional.
- Mark `bank`, `totals` and `references` **provisional**. Declare `totals: none | record` and add `currency: str`
  at the view root now.

### FP-6 (major): bank/payment view and the `qr(size)` contract are EUR/SEPA-credit-transfer-only; v0.6 payment features don't fit

**Where:** §3.8 body views "`bank.qr: none | (size) => content` … (EUR only …)", §3.6 `bank-details` required,
appendix Q7 (freeze the bank and payment views), §3.5 `bank-details.qr`/`qr-size`. Code:
`src/components/bank-details.typ:128-140`.

**REASONED + SOURCE.** The obvious v0.6 needs don't fit:

| Need                                               | Why it doesn't fit                                                                                                                                                                                                                                                         |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Swiss QR-bill as a real component                  | CHF/EUR; structured creditor/debtor addresses; reference type QRR/SCOR/NON; a fixed 46 mm code in a regulated 210×105 slip. This is not "a QR of any size ≥ 20 mm", and it needs data (reference, debtor, currency) that neither the bank view nor the frame view carries. |
| Several bank accounts                              | BG-17 is 0..n                                                                                                                                                                                                                                                              |
| SEPA direct debit                                  | mandate reference BT-89, creditor ID BT-90. A "pay now" QR on a direct-debit invoice is _wrong_, and the correct text differs.                                                                                                                                             |
| Payment links / URL-QR (Stripe-style "pay online") | no field                                                                                                                                                                                                                                                                   |
| Card / cash / "already paid" receipts              | no field                                                                                                                                                                                                                                                                   |

**Change now:** don't freeze the bank view. Freeze a neutral **`payment`** envelope instead: `payment.means:
array<(type: str, ..)>` with `type` values aligned to UNTDID 4461 (`credit-transfer` ≈ 30/58, `direct-debit` ≈ 59,
`card` ≈ 48, `link`, `cash` ≈ 10). Each entry's fields are **provisional**. Keep the part name `bank-details`, or
better `payment-details`, and make it non-required (FP-1). Rename the QR contract to
`qr: none | (size: auto | length) => content`, so that fixed-size codes can ignore the argument. Rename
`bank-details.qr`/`qr-size` options accordingly, while they are still provisional.

### FP-7 (major): `env` is frozen but has no vocabulary, no validation and no consumer; `zugferd` is a product name in a frozen record

**Where:** §3.1 `env` (stable), §2.2 (`env: (kind, lang, region, zugferd)`), §2.4 `resolve-theme` default
`kind: "invoice"`, §12 "0.5.x document kinds (`env.kind` patches)".

**VERIFIED** (`fp/env.typ`): `theme.resolve-theme(theme.classic, env: (kind: "banana-note", lang: "xx",
region: "zz", zugferd: 42))` resolves without error. So does `env: (kind: "invoice")`, with the other keys missing.
SOURCE: `validate-layout(layout, parts)` (`validate.typ:80`) never receives `env`, so nothing reads `env.kind`.

**Regret:** the first release that gives `kind` meaning (0.5.x) inherits whatever strings people have passed. The
record freezes `zugferd` although the product line is Factur-X / ZUGFeRD / XRechnung (CII, UBL) with profiles.

**Change now:**

- Define the `env.kind` vocabulary now as **exactly the keys of `locale.strings.document`**, with a documented
  mapping to UNTDID 1001 (which ZUGFeRD BT-3 uses; today hard-coded `380`):

  | `env.kind`           | UNTDID 1001 |
  | -------------------- | ----------- |
  | `invoice`            | 380         |
  | `credit-note`        | 381         |
  | `corrected-invoice`  | 384         |
  | `prepayment-invoice` | 386         |
  | `proforma`           | 325         |
  | `quote`              | 310         |
  | `order-confirmation` | 231         |
  | `delivery-note`      | 270         |
  | `reminder`           | –           |
  | `receipt`            | –           |
  | `letter`             | –           |

  Validate it with the house did-you-mean error. 0.5.0 accepts only `invoice`, but the name set is fixed.

- Rename `zugferd` to `e-invoice: none | (format: str, profile: str)` and mark it provisional.
- Freeze only `env.kind`, `env.lang` and `env.region`.
- State in the frozen docs that derivations `t => v` may in future receive `env` as `t.env`, and that no token
  group will ever be named `env` (a reserved key), so kind-aware derivations (R29: a red accent for reminders)
  arrive additively.

### FP-8 (minor): three different frozen things are called `kind`

**Where:** §3.1 `kind: "invoice-pro/theme"` (the type tag, stable), `env.kind` (document kind, stable),
`document.kind` in the frame view (frozen), and `notices: array<(kind, text, marker)>`. Code: `build.typ:61`,
`frame.typ:25`.

`ctx.theme.kind == "invoice-pro/theme"` next to `ctx.theme.env.kind == "invoice"` is a permanent confusion in
docs and in package code. **Change now:** rename the tag to a namespaced sentinel key
(`"__invoice-pro-theme__": 1`, the same pattern as the wrap marker) or to `type`. Keep `kind` for the document
kind only.

### FP-9 (minor): custom part names and `options.custom` share a namespace with future built-ins

**Where:** §3.1 `parts` "open for custom names", §3.5 `custom` (open), §4.2 "open maps". REASONED.

If v0.6 adds a built-in part `stamp`, `qr-bill` or `ship-to`, a package that already registers a custom part of
the same name silently _replaces_ the new built-in, or is replaced by it. **Change now:** a validator rule that
custom part names (those not built in) must contain a prefix separator, e.g. `acme-rail` or `acme:rail`. The
walkthrough package already follows this. Reserve all un-prefixed names for built-ins. Do the same for
`options.custom.<pkg>`.

### FP-10 (minor): physical-direction defaults in the frozen region schema (RTL)

**Where:** §3.4 `align` default `top + left`, `x | right`, the `arrange` column order. REASONED.

For RTL locales (ar, he, fa), a frozen `left` default puts every region's content on the wrong side. Typst's
`start`/`end` alignments already follow the text direction. **Change now:** make the default `top + start`
(identical in LTR, correct in RTL). Document `x`/`right` as **physical** (envelope windows are physical), and
reserve `start`/`end` as future alternatives to `x`/`right` (an additive change). The literal "No." in the title
part (`parts/frame.typ:80`) is an English string that bypasses the locale. That's not a freeze issue, but it will
be copied by package authors who eject the part.

### FP-11 (minor): tagging behaviour is implicitly frozen through `place` semantics; the legal footer is an artifact

**Where:** §5.3 (recipient "tagged, reading order"), §6 ("Fixed regions for other page sets go into the
foreground as artifacts"), P7 ("furniture is artifacts"), §3.3 regions "ordered". REASONED/SOURCE.

Typst's page `header`/`footer` content is artifact-tagged, so the § 35a / GmbHG footer (the only place where the
register court and management appear) is invisible to assistive technology on every page except the one with a
reserved zone, where it is relocated into the flow and _is_ tagged (`frame.typ:206-213`). Reading order equals dict
insertion order: a patched-in region always lands last, and there is no way to insert it earlier. Typst's tagging
is still evolving (0.14 introduced it, and 0.15 refines it). **Mark provisional:** tagging and reading order are
"best effort, may improve". Reserve the region keys `tag: auto | "artifact" | "content"` and `order: auto | int`
(adding them later is additive). Don't freeze "header/footer = artifact" in docs.

### FP-12 (minor): part name `payment-goal` is a German calque, frozen as a part name

**Where:** §3.6, §2.5 (P6 uses `part("payment-goal", ..)`). The part name follows the 0.4 component
(`src/components/payment-goal.typ` in the repo). EN 16931 calls it **BT-20 "Payment terms"**. Quotes need
"validity" and reminders need a "new due date" in the same slot. **Change now:** name the part `payment-terms`.
Decision 1 (no back-compat) makes this free now and expensive after the lock. Rename the component in the same
release, or keep the component name and map it.

### FP-13 (nit): `paper` with `height: auto` works but is undocumented

VERIFIED (`fp/roll.typ --input case=a`): `paper: (width: 80mm, height: auto)` compiles to a single continuous page.
That is a thermal-roll receipt, one of the #10 kinds and a "any format" (decision 2) win. §3.3 types `paper` as
`(width: length, height: length)`. Document `height: auto | length` now, and make `bottom`-anchored and ratio-height
regions panic on auto-height paper, before users rely on undefined behaviour.

---

## 2. Probe results for the mandatory questions

**(a) Document kinds.** The layout/region/part _structure_ survives every kind, because a delivery note is a
layout without the bank/totals parts. The **contract** around it does not:

- the required sets (FP-1);
- the invoice-only frame view (FP-5);
- `env.kind` without a vocabulary (FP-7);
- `bank-details` required with EUR-only payment (FP-6);
- `negative`/`positive` colour names on credit notes (FP-3);
- `payment-goal` (FP-12).

Part names `line-items`, `items-table`, `totals`, `notices`, `signature`, `title` and `recipient` are kind-neutral
and fine. A "reminder" needs a new `open-items` part and a `critical` colour. Both are additive if FP-3 lands.

**(b) Tokens.** See FP-2 and FP-3. Net recommendation: about 20 frozen tokens, all consumer-verified by a mutation
test. Rename the sign-based names and the grey scale. Absolute-only `sizes.fine`.

**(c) Region schema.**

- Sidebar: works (walkthrough 9), because margins are global.
- Landscape: works (`flipped`).
- Thermal roll: works (FP-13).
- Two-column body: needs a future `layout.columns` key (additive).
- Multi-address (bill-to plus ship-to): needs a new `ship-to` part (additive; FP-9 protects the name).
- DL-folded: `marks.fold` is data.
- Swiss QR-bill as a real component: the region mechanics (`float`, `isolate`) are fine, but the data is missing
  from the views (FP-5, FP-6).

The only structural regret is standard-name coupling (FP-4). The closed `pages` enum can grow additively (odd/even
for duplex).

**(d) Views.** Multi-currency: add `currency` now. Multiple bank accounts, payment links, Swiss reference and SEPA
direct debit: FP-6. E-invoice-only XRechnung: fine, because compliance output is core-only and independent of theme
resolution (§5.3). Keep it that way. `typst query` on the attached XML metadata is the future no-visual path, and
needs no theme change.

**(e) Accessibility, RTL and CJK.** Tagging: FP-11. RTL: FP-10. CJK: `fonts.*` accepts fallback arrays, and
em-relative sizes behave. `weights.strong: "bold"` on CJK fonts without a bold face depends on Typst's font
fallback (REASONED; no change needed, but document it). Nothing here is Typst-0.15-only.

**What ages well (keep frozen):**

- the lazy calling convention;
- `layout:` as the only named argument (other named args panic, which reserves them);
- non-dict patches panic (which reserves `env => patch` for kind-aware themes);
- the merge rules;
- the `(ctx, view) => content` / wrap signatures;
- that view records grow additively (VERIFIED: destructuring ignores extra keys);
- core-owned compliance output.

---

## 3. Proposed minimal frozen surface for 0.5.0

| Keep frozen                                                                                                               | Demote to provisional                                                                                               | Change before the lock                                                                                          |
| ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Calling convention, `layout:`, the "other named args panic" rule, merge rules, helper _mechanism_                         | option paths (already), line-items view (already)                                                                   | required sets keyed by `env.kind` (FP-1)                                                                        |
| Layout keys (`paper` incl. `height: auto`, `flipped`, `margin`, `body-top`, `body-gap`, `stationery`, `marks`, `regions`) | the `required` table per kind (only the invoice row ships)                                                          | remove `items-table`, `totals`, `bank-details` from required (FP-1)                                             |
| Region keys, **with injected standard stubs**                                                                             | `accent` family, `paper`/`background`, `numeric`, `figures`, `weights.regular`, `spacing.xs/lg`, `strokes.hairline` | token renames: `text-muted`, `critical`, `tint`, `border`; delete `mark` (FP-2, FP-3)                           |
| ~20 consumer-verified tokens                                                                                              | frame `bank`, `totals`, `references`; party structured fields                                                       | `document.date: (value, text)`; `subject` without the number; `currency` in the view (FP-5)                     |
| part names (with `payment-terms`), part signature                                                                         | `payment.means` entries, `qr` sizing                                                                                | `payment` envelope instead of a frozen bank view (FP-6)                                                         |
| `env.kind` vocabulary, `env.lang`, `env.region`                                                                           | `env.e-invoice`                                                                                                     | `env.kind` validated; `zugferd` renamed (FP-7)                                                                  |
| `themed`, `build-theme`, `resolve-theme`                                                                                  | tagging and reading order (FP-11)                                                                                   | rename the theme tag away from `kind` (FP-8); prefix rule for custom parts (FP-9); `align: top + start` (FP-10) |

Estimated extra cost before M6: about a day of schema and validator edits plus a 35-compile mutation test. None
of it needs loom changes or Typst 0.15.

---

## 4. Reproduction index

| File (in `scratchpad/crit-future-proofing/`) | Command                                                                                                                                                 | Shows                                                               |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `fp/tok.typ`, `fp/tokm.typ`                  | `typst compile --root . fp/tok.typ out/fp/tok-<c>-{p}.png --input case=<c>` for `c` in base, mark, figures, accent, paper, weights, spacing, hair, rule | 12 tokens with no effect (identical md5); `rule` as the control     |
| `fp/kinds.typ`                               | `--input case=dn-totals\|dn-bank\|dn-items\|receipt\|letter`                                                                                            | kind-blocking panics (FP-1)                                         |
| `fp/bypass.typ`                              | `out/fp/bypass-1.png`                                                                                                                                   | empty renderers pass every guard (FP-1)                             |
| `fp/subj.typ`                                | `out/fp/subj-1.png`                                                                                                                                     | the number lives inside `subject` (FP-1, FP-5)                      |
| `fp/stdnames.typ`                            | `--input case=a\|b\|c`                                                                                                                                  | modern/minimal panic on a layout without the standard names (FP-4)  |
| `fp/env.typ`                                 | compile                                                                                                                                                 | an invalid `env` is accepted (FP-7)                                 |
| `fp/destr.typ`                               | compile                                                                                                                                                 | adding view fields does not break destructuring (a positive result) |
| `fp/roll.typ`                                | `--input case=a`                                                                                                                                        | `paper.height: auto` works (FP-13)                                  |
