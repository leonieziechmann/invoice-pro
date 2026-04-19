#import "lang/lang.typ"
#import "region/region.typ"

#import "factory.typ": build-locale
#import "custom.typ"

// Region DE Locale
#let de-de = build-locale(lang.de, region.de)
#let en-de = build-locale(lang.en, region.de)
