// Source: docs/docs/api-reference/theme.md — "DIN-5008 Example Usage"
#import "/src/lib.typ": *

// Initialize the invoice with a customized DIN-5008 theme
#show: invoice.with(
  // We configure the theme function and pass it to the invoice
  theme: themes.DIN-5008(
    form: "B", // Form B pushes the address block further down
    font: "libertinus serif",
    hole-mark: false, // Disabling the punch hole mark for digital-only PDFs
  ),
  sender: (name: "Acme Corp"),
  recipient: (name: "Jane Doe"),
)

// Document body goes here
