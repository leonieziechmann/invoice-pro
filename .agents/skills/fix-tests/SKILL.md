---
name: fix-tests
description: Systematic process for diagnosing and fixing test failures in invoice-pro, differentiating between compile/data test fixes and visual regression snapshot updates.
---

# Fixing Tests in invoice-pro

When tests fail, identify whether the failure is a **compile-time / data assertion error** or a **visual regression mismatch**. Follow the respective workflow below.

---

## Scenario A: Compile-Time / Data Assertion Failure

### Symptoms

- Typst compiler error (syntax error, missing argument, type mismatch).
- `data-test` assertion failure (e.g. `Net total: expected 100.00, got 90.00`).

### Resolution Workflow

1. **Read the error message carefully**: Look for line numbers and signal mismatches in the failure output.
2. **Iterative Tinkering**:
   - For logic errors: modify the underlying calculation functions in `src/logic/` or `src/components/`.
   - For test specification errors: update the expected assertion in `test.typ` if the requirement changed.
3. **Re-run the target test**:
   ```bash
   tt run "<test-path>"
   ```
4. Repeat until the test passes.

---

## Scenario B: Visual Regression Failure (`diff/`)

### CRITICAL RULE

> ⚠️ **NEVER run blanket `tt update` across the whole test suite!**
> Visual regression references must be evaluated and updated **one test case at a time** only after validating that the output matches the expected visual design.

### Resolution Workflow

1. **Identify failing test cases** from `tt run` output.
2. **Inspect the visual difference for EACH failing test**:
   - Check rendered output in `tests/<category>/<test-name>/out/1.png`.
   - Check visual diff in `tests/<category>/<test-name>/diff/1.png`.
   - Compare with reference in `tests/<category>/<test-name>/ref/1.png`.
3. **Evaluate the change**:
   - _Is this an intentional improvement/redesign?_ (e.g. font update, layout alignment, new margin rule).
   - _Is this an unintended bug/regression?_ (e.g. overlapping text, shifted elements, missing line item).
4. **Action**:
   - If **unintended bug**: Fix the source code in `src/` and rerun `tt run "<test-path>"`.
   - If **intentional change**: Update the reference snapshot for **only that specific test**:
     ```bash
     tt update "<test-path>"
     ```
5. **Verify**:
   ```bash
   tt run "<test-path>"
   ```
6. Verify `git diff` or `git status` to ensure only the intended `ref/1.png` was modified.
