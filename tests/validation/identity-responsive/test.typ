// The identity check after layout (prototype tests/api-frame/identity.typ,
// --input mode=responsive): a poster title that measures its word and steps the
// size down passes under strict.
#import "/tests/theme/identity.typ": identity-invoice, responsive

#identity-invoice(responsive, validation: "strict")
