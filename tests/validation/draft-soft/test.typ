// validation: "draft" inside the `soft` look, it strings (prototype
// tests/validation/draft.typ and the draft renders of scripts/checks-presets-*.sh):
// the markers, badge, watermark and report render with this look. One draft
// invoice per document: its markers link to its report.
#import "/tests/theme/draft.typ": assert-draft, draft-invoice

#draft-invoice(look: "soft", lang: "it")
#context assert-draft()
