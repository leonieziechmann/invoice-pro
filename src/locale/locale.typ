#import "lang/lang.typ"
#import "region/region.typ"

#import "factory.typ": build-locale
#import "custom.typ"

#let de-at = build-locale(lang.de, region.at)
#let en-at = build-locale(lang.en, region.at)
#let fr-at = build-locale(lang.fr, region.at)
#let it-at = build-locale(lang.it, region.at)
#let es-at = build-locale(lang.es, region.at)

#let de-ch = build-locale(lang.de, region.ch)
#let en-ch = build-locale(lang.en, region.ch)
#let fr-ch = build-locale(lang.fr, region.ch)
#let it-ch = build-locale(lang.it, region.ch)
#let es-ch = build-locale(lang.es, region.ch)

#let de-de = build-locale(lang.de, region.de)
#let en-de = build-locale(lang.en, region.de)
#let es-de = build-locale(lang.es, region.de)
#let fr-de = build-locale(lang.fr, region.de)
#let it-de = build-locale(lang.it, region.de)

#let de-es = build-locale(lang.de, region.es)
#let en-es = build-locale(lang.en, region.es)
#let fr-es = build-locale(lang.fr, region.es)
#let it-es = build-locale(lang.it, region.es)
#let es-es = build-locale(lang.es, region.es)

#let de-fr = build-locale(lang.de, region.fr)
#let en-fr = build-locale(lang.en, region.fr)
#let fr-fr = build-locale(lang.fr, region.fr)
#let it-fr = build-locale(lang.it, region.fr)
#let es-fr = build-locale(lang.es, region.fr)

#let de-it = build-locale(lang.de, region.it)
#let en-it = build-locale(lang.en, region.it)
#let fr-it = build-locale(lang.fr, region.it)
#let it-it = build-locale(lang.it, region.it)
#let es-it = build-locale(lang.es, region.it)
