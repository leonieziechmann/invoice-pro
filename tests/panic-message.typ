// The message of a panic as tytanic's `catch` returns it, in one form for
// every Typst version: Typst 0.14 quotes a string payload
// (`panicked with: "..."`), Typst 0.15 writes it as it is. The tests compare
// with the quoted form, which `quoted-panic` restores.
//
// A test shadows `catch` with it:
//
//   #import "/tests/panic-message.typ": quoted-panic
//   #let _catch = catch
//   #let catch(f) = quoted-panic(_catch(f))

#let _prefix = "panicked with: "

#let quoted-panic(message) = {
  if (
    type(message) != str
      or not message.starts-with(_prefix)
      or message.slice(_prefix.len()).starts-with("\"")
  ) {
    return message
  }
  _prefix + repr(message.slice(_prefix.len()))
}
