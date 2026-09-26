#let date(d, m, y) = datetime(day: d, month: m, year: y)

/// The first of `values` that is not `none`, `auto` or empty, else `none`;
/// for context keys, which exist even when not given.
///
/// -> any
#let first-given(..values) = {
  for value in values.pos() {
    if value not in (none, auto, "", []) { return value }
  }
  none
}
