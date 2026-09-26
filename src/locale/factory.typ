/// Merges a depth-2 patch onto a base dictionary; panics on keys the base
/// does not have.
#let base-pull-deep-merge(base, patch) = {
  if type(patch) != dictionary { return base }

  let result = base

  for (group-key, base-group) in base {
    if group-key not in patch { continue }

    let patch-group = patch.at(group-key, default: (:))

    if type(patch-group) != dictionary { continue }

    let base-sub-keys = base-group.keys()
    let patch-sub-keys = patch-group.keys()

    let valid = patch-sub-keys.all(k => k in base-sub-keys)
    if not valid {
      let bad-key = patch-sub-keys.find(k => k not in base-sub-keys)
      panic(
        "Invalid key '"
          + bad-key
          + "' found in group '"
          + group-key
          + "'. Allowed keys: "
          + str(base-sub-keys),
      )
    }

    result.insert(group-key, base-group + patch-group)
  }

  return result
}

// The index of the last of `sources` that sets `group.key`, or -1.
#let _last-source(sources, group, key) = {
  let found = -1
  for (i, source) in sources.enumerate() {
    let values = if type(source) == dictionary {
      source.at(group, default: none)
    }
    if type(values) == dictionary and key in values { found = i }
  }
  found
}

/// Rebuilds the currency formats and the rounding of the merged `region`
/// from its `currency` (BT-5), unless `sources` (in merge order) set them
/// with or after the currency.
/// -> dictionary
#let derive-from-currency(sources, region) = {
  let level(group, key) = _last-source(sources, group, key)
  let symbol = level("currency", "symbol")
  let decimals = level("currency", "decimals")
  let decimals-fine = level("currency", "decimals-fine")
  let meta = region.currency

  let rebuild = region.format.at("currency-formatters", default: none)
  if type(rebuild) == function {
    if calc.max(symbol, decimals) > level("format", "currency") {
      region.format.currency = rebuild(meta).currency
    }
    if (
      calc.max(symbol, decimals, decimals-fine)
        > level("format", "currency-fine")
    ) {
      region.format.currency-fine = rebuild(meta).currency-fine
    }
  }
  if decimals > level("normalize", "money") {
    region.normalize.money = x => calc.round(x, digits: meta.decimals)
  }
  if decimals-fine > level("normalize", "money-fine") {
    region.normalize.money-fine = x => calc.round(
      x,
      digits: meta.decimals-fine,
    )
  }
  region
}

#let build-locale(lang, region) = {
  (..overrides, base-lang, base-region) => {
    let user-lang-patches = overrides
      .pos()
      .flatten()
      .filter(p => type(p) == dictionary)
      .map(p => p.at("strings", default: (:)))

    let user-region-patches = overrides
      .pos()
      .flatten()
      .filter(p => type(p) == dictionary)
      .map(p => p.at("region", default: (:)))

    let final-lang = (
      lang,
      ..user-lang-patches,
    ).fold(base-lang, base-pull-deep-merge)

    let specific-region = region(final-lang)
    let final-region = derive-from-currency(
      (base-region, specific-region, ..user-region-patches),
      (
        specific-region,
        ..user-region-patches,
      ).fold(base-region, base-pull-deep-merge),
    )

    // `base` is the English fallback schema, not an ISO 639-1 code.
    let lang-code = final-lang.meta.lang
    if lang-code == "base" { lang-code = "en" }

    return (
      lang: lang-code,
      strings: final-lang,
      format: final-region.format,
      normalize: final-region.normalize,
      currency: final-region.currency,
      tax: final-region.tax,
      meta: final-region.meta,
      resolve-plural: final-lang.meta.at("resolve-plural", default: none),
    )
  }
}
