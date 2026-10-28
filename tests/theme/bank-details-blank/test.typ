// Bank details without a bank name, or without an account holder (`name:
// none`): every preset leaves the line out instead of printing its label
// without a value. Each case keeps the other line, which shows that the check
// finds the labels of the preset.
#import "/src/lib.typ": *
#import "/tests/theme/body.typ": party, preset-of, presets, test-locale
#import "/tests/integration/payment-reference/harness.typ": find-all

// Records which labels the bank details print: a label is a text of its own.
#let capturing(name) = preset-of(name).with(theme.custom.wrap(
  "bank-details",
  (ctx, view, inner) => {
    let printed = inner(ctx, view)
    let texts = find-all(printed, text).map(it => lower(it.text.trim()))
    let s = ctx.locale.strings.bank-details
    let labels = (
      holder: lower(s.account-holder) in texts,
      bank: lower(s.bank) in texts,
      iban: lower(s.iban) in texts,
    )
    [#metadata((preset: name, labels: labels))<bank-details>#printed]
  },
))

#let iban = "DE75512108001245126199"
#for name in presets {
  for bank in (
    (iban: iban, bic: "SOLADEST600"),
    // the EPC-QR code needs an account holder: it is hidden
    (
      name: none,
      bank: "Hamburger Sparkasse",
      iban: iban,
      qr-code: (display: false),
    ),
  ) {
    invoice(theme: capturing(name), locale: test-locale, ..party)[
      #line-items[#item([Konzeption], price: 1800)]
      #bank-details(..bank)
    ]
  }
}

#context {
  let captured = query(<bank-details>).map(it => it.value)
  assert.eq(captured.len(), 2 * presets.len())
  for (no-bank, no-holder) in captured.chunks(2) {
    let name = no-bank.preset
    assert.eq(
      no-bank.labels,
      (holder: true, bank: false, iban: true),
      message: name + " without a bank",
    )
    assert.eq(
      no-holder.labels,
      (holder: false, bank: true, iban: true),
      message: name + " with name: none",
    )
  }
}
