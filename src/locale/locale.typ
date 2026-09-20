#import "lang/lang.typ"
#import "region/region.typ"

#import "factory.typ": build-locale
#import "custom.typ"

// Region AT locale
#let de-at = build-locale(lang.de, region.at)
#let en-at = build-locale(lang.en, region.at)
#let fr-at = build-locale(lang.fr, region.at)
#let it-at = build-locale(lang.it, region.at)
#let es-at = build-locale(lang.es, region.at)

// Region CH Locale
#let de-ch = build-locale(lang.de, region.ch)
#let en-ch = build-locale(lang.en, region.ch)
#let fr-ch = build-locale(lang.fr, region.ch)
#let it-ch = build-locale(lang.it, region.ch)
#let es-ch = build-locale(lang.es, region.ch)

// Region DE Locale
#let de-de = build-locale(lang.de, region.de)
#let en-de = build-locale(lang.en, region.de)
#let es-de = build-locale(lang.es, region.de)
#let fr-de = build-locale(lang.fr, region.de)
#let it-de = build-locale(lang.it, region.de)

// Region ES Locale
#let de-es = build-locale(lang.de, region.es)
#let en-es = build-locale(lang.en, region.es)
#let fr-es = build-locale(lang.fr, region.es)
#let it-es = build-locale(lang.it, region.es)
#let es-es = build-locale(lang.es, region.es)

// Region FR Locale
#let de-fr = build-locale(lang.de, region.fr)
#let en-fr = build-locale(lang.en, region.fr)
#let fr-fr = build-locale(lang.fr, region.fr)
#let it-fr = build-locale(lang.it, region.fr)
#let es-fr = build-locale(lang.es, region.fr)

// Region IT Locale
#let de-it = build-locale(lang.de, region.it)
#let en-it = build-locale(lang.en, region.it)
#let fr-it = build-locale(lang.fr, region.it)
#let it-it = build-locale(lang.it, region.it)
#let es-it = build-locale(lang.es, region.it)

// Region GB / UK Locale
#let de-gb = build-locale(lang.de, region.uk)
#let en-gb = build-locale(lang.en, region.uk)
#let es-gb = build-locale(lang.es, region.uk)
#let fr-gb = build-locale(lang.fr, region.uk)
#let it-gb = build-locale(lang.it, region.uk)

// Aliases for UK
#let de-uk = de-gb
#let en-uk = en-gb
#let es-uk = es-gb
#let fr-uk = fr-gb
#let it-uk = it-gb
