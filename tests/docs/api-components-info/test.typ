// Source: docs/docs/api-reference/components.md — "info Module"
// Both code blocks of the section, inside a complete invoice.
#import "/tests/docs/prelude.typ": *

#show: invoice.with(..party, order-nr: "PO-4711", order-date: "12.01.2026")

Thank you for your order #info.order-nr from #info.order-date.
Please settle the total of #info.total.gross by #info.due-date to IBAN #info.iban.

Our company #info.sender.name is registered under VAT ID #info.sender.vat-id.
Invoiced to #info.recipient.name in #info.recipient.city.

#info.dynamic("locale", "region", "code")
#info.dynamic("sender", "extra", default: "N/A")
#info.dynamic("invoice-date", format: d => [Year #d.year()])
#info.dynamic(ctx => [Issuer country code: #upper(ctx.sender.country.code)])

#body()
