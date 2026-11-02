---
sidebar_position: 12
---

# Contributors

invoice-pro is written and maintained by [Leonie Ziechmann](https://github.com/leonieziechmann). Many people have made it better, with code, bug reports and ideas. Thank you!

Everyone is listed by the kind of help, with the pull request or issue behind it and, for code, the version it first shipped in. The list is updated with every release. Want to help as well? See [Contributing](./contributing.md).

## Features

- [autinerd](https://github.com/autinerd): a free remittance text in the bank details ([#31](https://github.com/leonieziechmann/invoice-pro/pull/31)), v0.4.1
- [joelsa](https://github.com/joelsa): a configurable row fill for the items table ([#36](https://github.com/leonieziechmann/invoice-pro/pull/36)), v0.4.2
- [MLNW](https://github.com/MLNW): alternative payment goals, a better header and better IBAN handling ([#5](https://github.com/leonieziechmann/invoice-pro/pull/5), [#4](https://github.com/leonieziechmann/invoice-pro/pull/4), [#1](https://github.com/leonieziechmann/invoice-pro/pull/1)), v0.1.1
- [RTUnreal](https://github.com/RTUnreal): unit names in the singular and the plural ([#27](https://github.com/leonieziechmann/invoice-pro/pull/27)), v0.4.1
- [theexiile1305](https://github.com/theexiile1305) (Michael Fuchs): the first ZUGFeRD / Factur-X export, which started the e-invoicing ([#23](https://github.com/leonieziechmann/invoice-pro/pull/23)), v0.4.0

## Bug Fixes

- [autinerd](https://github.com/autinerd): no empty BIC line in the bank details, and a space between amount and currency ([#30](https://github.com/leonieziechmann/invoice-pro/pull/30), [#32](https://github.com/leonieziechmann/invoice-pro/pull/32)), v0.4.1
- [MLNW](https://github.com/MLNW): the EPC QR code ([#3](https://github.com/leonieziechmann/invoice-pro/pull/3)), v0.1.1
- [ralph](https://github.com/ralph): the validation finds the invoice number and the date when one contains the other ([#53](https://github.com/leonieziechmann/invoice-pro/pull/53)), v0.6.0
- [toddy15](https://github.com/toddy15): the German closing without a comma, as the Duden writes it ([#47](https://github.com/leonieziechmann/invoice-pro/pull/47)), v0.6.0

## Tooling and CI

- [theexiile1305](https://github.com/theexiile1305): GitHub Actions pinned to commit SHAs, against attacks on the supply chain ([#25](https://github.com/leonieziechmann/invoice-pro/pull/25))

## Bug Reports

- [alyxbb](https://github.com/alyxbb): a ZUGFeRD seller identifier that needed a tax number ([#42](https://github.com/leonieziechmann/invoice-pro/issues/42))
- [dbongartz](https://github.com/dbongartz): `sender.extra` that was no longer printed ([#14](https://github.com/leonieziechmann/invoice-pro/issues/14))
- [FabianBartl](https://github.com/FabianBartl): a 0 % tax line that could not be left out of the totals ([#39](https://github.com/leonieziechmann/invoice-pro/issues/39))
- [HarHarLinks](https://github.com/HarHarLinks): mandatory tax IDs that were not printed, and a missing full stop after the tax rate ([#34](https://github.com/leonieziechmann/invoice-pro/issues/34), [#35](https://github.com/leonieziechmann/invoice-pro/issues/35))
- [imalik8088](https://github.com/imalik8088): the invoice number missing from the EPC QR code ([#15](https://github.com/leonieziechmann/invoice-pro/issues/15))
- [JuliDi](https://github.com/JuliDi): a ZUGFeRD crash when a 0 % tax hid the seller's VAT ID, and missing fields that gave invalid XRechnung XML ([#28](https://github.com/leonieziechmann/invoice-pro/issues/28), [#29](https://github.com/leonieziechmann/invoice-pro/issues/29))
- [marcschn](https://github.com/marcschn): units that were never pluralized ([#43](https://github.com/leonieziechmann/invoice-pro/issues/43))
- [MLNW](https://github.com/MLNW): a misaligned header ([#2](https://github.com/leonieziechmann/invoice-pro/issues/2))
- [MrToWy](https://github.com/MrToWy): an example that did not work, and item discounts and extras that were not printed ([#17](https://github.com/leonieziechmann/invoice-pro/issues/17), [#19](https://github.com/leonieziechmann/invoice-pro/issues/19))
- [Proxycon](https://github.com/Proxycon): the tax number hidden when references were given ([#26](https://github.com/leonieziechmann/invoice-pro/issues/26))

## Ideas and Feature Requests

- [DerDennisOP](https://github.com/DerDennisOP): a switch for the reference in the bank details, and the VAT ID next to the tax number ([#7](https://github.com/leonieziechmann/invoice-pro/issues/7), [#8](https://github.com/leonieziechmann/invoice-pro/issues/8))
- [joelsa](https://github.com/joelsa): row striping for the items table ([#33](https://github.com/leonieziechmann/invoice-pro/issues/33))
- [JuliDi](https://github.com/JuliDi): the net total always in bold ([#41](https://github.com/leonieziechmann/invoice-pro/issues/41))
- [Leandros](https://github.com/Leandros): more lines for the addresses of sender and recipient ([#21](https://github.com/leonieziechmann/invoice-pro/issues/21))
- [lucaschoeneberg](https://github.com/lucaschoeneberg): document titles such as Angebot, Rechnung and Gutschrift ([#10](https://github.com/leonieziechmann/invoice-pro/issues/10))
- [marcschn](https://github.com/marcschn): modifier labels and partial payments, which led to `prepayment` ([#37](https://github.com/leonieziechmann/invoice-pro/issues/37))
- [MrToWy](https://github.com/MrToWy): a footer on every page ([#18](https://github.com/leonieziechmann/invoice-pro/issues/18))
- [theexiile1305](https://github.com/theexiile1305): ZUGFeRD support and pinned GitHub Actions ([#22](https://github.com/leonieziechmann/invoice-pro/issues/22), [#24](https://github.com/leonieziechmann/invoice-pro/issues/24))
