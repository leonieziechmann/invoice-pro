// validation: "draft" inside the `prestige` look, en strings (prototype
// tests/validation/draft.typ and the draft renders of scripts/checks-presets-*.sh):
// the markers, badge, watermark and report render with this look. One draft
// invoice per document: its markers link to its report.
#import "/tests/theme/draft.typ": assert-draft, draft-invoice

#draft-invoice(look: "prestige", lang: "en")
#context assert-draft()
