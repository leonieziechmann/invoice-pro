#import "/src/lib.typ": *

// 1. Initialize the document using a show rule
#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  // Sender and recipient configurations
  sender: (
    name: "Acme Corporation",
    address: "123 Business Rd, Metropolis, NY 10001",
  ),
  recipient: (
    name: "John Doe",
    address: "456 Consumer Way, Gotham, NJ 07001",
  ),

  // Document metadata
  invoice-nr: "INV-2026-001", // Unique document identifier
  date: datetime.today(), // Sets the invoice date to compilation time

  // Financial configuration
  tax-mode: "exclusive", // Base prices do not include tax
  tax: tax.vat(19%), // Applies a 19% default tax rate
)

// 2. Define the invoice body
= Services Rendered

// Add individual line items; these automatically inherit root settings
#line-items[
  #item(
    ["Consultation Fee"],
    description: "Initial system architecture review.",
    quantity: 10,
    price: 150.00,
  )

  #item(
    ["Server Migration"],
    quantity: 1,
    price: 500.00,
  )
]
