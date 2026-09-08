#import "@preview/ibanator:0.1.0"
#import "@preview/sepay:0.1.1": epc-qr-code

#let render-bank-details(ctx, view) = {
  let strings = ctx.locale.strings
  let bd-str = strings.bank-details
  let currency-code = ctx.locale.currency.code

  let qr-image = none
  let remittance-text = view.at("text", default: none)
  let reference = view.at("reference", default: none)

  if currency-code == "EUR" {
    qr-image = epc-qr-code(
      view.sender.name,
      view.sender.iban,
      ..(
        bic: view.sender.bic,
        amount: if float(view.payment-amount) >= 0.1 {
          float(view.payment-amount)
        },
        width: view.qr-code.size,
        height: view.qr-code.size,
      )
        + if remittance-text != none {
          (text: remittance-text)
        } else if reference != none { (reference: reference) },
    )
  }

  block(
    width: 100% - view.qr-code.size,
    grid(
      columns: (auto, 1fr),
      align: top,
      gutter: 1em,
      stroke: none,
    )[
      #set par(leading: 0.4em)
      #set text(number-type: "lining")
      #if view.sender.name != "" [#bd-str.account-holder: #view.sender.name \ ]
      #if view.sender.bank != "" [#bd-str.bank: #view.sender.bank \ ]
      #if view.sender.at("sort-code", default: "") != "" {
        let sc = view.sender.sort-code
        let formatted-sc = if type(sc) == str {
          let cleaned = sc.replace("-", "").replace(" ", "").trim()
          if (
            cleaned.len() == 6
              and cleaned.clusters().all(c => c >= "0" and c <= "9")
          ) {
            let c = cleaned.clusters()
            (
              c.slice(0, 2).join()
                + "-"
                + c.slice(2, 4).join()
                + "-"
                + c.slice(4, 6).join()
            )
          } else {
            sc
          }
        } else {
          sc
        }
        [#bd-str.sort-code: *#formatted-sc* \ ]
      }
      #if (
        view.sender.at("account-number", default: "") != ""
      ) [#bd-str.account-number: *#view.sender.account-number* \ ]
      #if (
        view.sender.iban != ""
      ) [#bd-str.iban: *#ibanator.iban(view.sender.iban)* \ ]
      #if view.sender.bic != "" [#bd-str.bic: #view.sender.bic \ ]
      #if (
        view.show-reference and remittance-text != none
      ) [#bd-str.reference: *#remittance-text*] else if (
        view.show-reference and reference != none
      ) [#bd-str.reference: *#reference*] \
      #h(6.5cm)
    ][
      #if view.qr-code.display {
        block(width: view.qr-code.size, qr-image)
      }
    ],
  )
}
