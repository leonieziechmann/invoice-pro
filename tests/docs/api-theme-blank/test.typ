// Source: docs/docs/api-reference/theme.md — "Blank Theme Example Usage"
#import "/src/lib.typ": *

// 1. Apply native Typst document-level formatting
#set page("a5", margin: (left: 0.5cm, right: 4cm))

// 2. Initialize the invoice with the blank theme
#show: invoice.with(
  theme: themes.blank, // Bypasses internal layout styles
  sender: (:),
  recipient: (:),
)

// 3. Document body goes here
