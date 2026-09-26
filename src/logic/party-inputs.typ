// Checks of the identifier inputs of the parties, for every invoice: an
// identifier without text would be left out without notice.

#import "../utils/text.typ": plain-text

/// The keys of each party that take an identifier.
#let identifier-keys = (
  sender: ("id", "global-id", "legal-id", "electronic-address"),
  recipient: (
    "id",
    "global-id",
    "legal-id",
    "electronic-address",
    "leitweg-id",
    "buyer-reference",
  ),
  delivery-address: ("id", "location-id", "global-id"),
  payee: ("id", "global-id", "legal-id"),
)

// An `id` identifier: the e-invoice reports its problems (IP-ID-01).
#let _is-typed(value) = "kind" in value and "problems" in value

/// Stops the compilation for an identifier of `party` without text: a
/// function (`id.siret` not called) or a dictionary without `id`, except an
/// electronic address, which is then derived.
///
/// -> none
#let check-identifiers(party, field, keys) = {
  if type(party) != dictionary { return }
  for key in keys {
    let value = party.at(key, default: none)
    let path = field + "." + key
    if type(value) == function {
      assert(
        false,
        message: "`"
          + path
          + "` is the function `"
          + repr(value)
          + "`, not an identifier: call it with the identifier, e.g. `"
          + key
          + ": id."
          + repr(value)
          + "(\"..\")` for a constructor of the `id` module.",
      )
    }
    if (
      type(value) == dictionary
        and key != "electronic-address"
        and not _is-typed(value)
        and plain-text(value.at("id", default: none)) == ""
    ) {
      assert(
        false,
        message: "`"
          + path
          + "` has no identifier: its `id` is missing or empty in "
          + repr(value)
          + ". Give the identifier as `id`, e.g. `"
          + key
          + ": (scheme: \"0088\", id: \"4000001123452\")`, or leave out `"
          + key
          + "`.",
      )
    }
  }
}
