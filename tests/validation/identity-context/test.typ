// The identity check after layout (prototype tests/api-frame/identity.typ,
// --input mode=context): number and date typeset inside context pass under
// strict.
#import "/tests/theme/identity.typ": identity-invoice, in-context

#identity-invoice(in-context, validation: "strict")
