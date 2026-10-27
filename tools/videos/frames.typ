// The frames of a showcase video: one page per frame, 1280 x 720 pt (exported
// at 108 ppi: 1920 x 1080 px). tools/videos/build.py writes the timeline (what
// each frame shows and how long) and passes its path with --input timeline=..;
// every position is computed there, so this file only draws.
//
// A frame shows the editor with the code as typed so far (Typst highlights
// it; a marker shows the changed lines and the caret), the invoice the code
// compiles to (the pages of the last step that compiled, in a viewport that
// grows over the editor to show a region up close), the caption of the step,
// and the title and end cards, which fade over the scene.

#let tl = json(sys.inputs.at("timeline"))
#let geo = tl.geometry

#let W = 1280pt
#let H = 720pt
#set page(width: W, height: H, margin: 0pt)
#set text(font: ("Inter", "Liberation Sans"), size: 16pt, fill: rgb("#1f2937"))

#let accent = rgb(tl.at("accent", default: "#0f766e"))
#let ink = rgb("#1f2937")
#let muted = rgb("#64748b")
#let mono = ("DejaVu Sans Mono",)
#let pt(v) = v * 1pt
#let alpha(c, a) = c.transparentize(100% - a * 100%)
#let shade(a) = rgb(15, 23, 42, int(a * 255))

// Typst sets raw text at 0.8em: the code is geo.code-size, its advance that of
// DejaVu Sans Mono (1233 of 2048 units per em)
#let code-size = pt(geo.code-size)
#let lh = pt(geo.line-height)
#let gutter = 46pt
#let adv = code-size * 1233 / 2048

#let backdrop() = place(rect(
  width: W,
  height: H,
  fill: gradient.linear(rgb("#f1f5f9"), rgb("#e2e8f0"), angle: 35deg),
))

#let header(f) = place(dx: 36pt, dy: 24pt, box(width: 1200pt, {
  set par(leading: 0.55em)
  text(size: 13pt, weight: "bold", fill: accent, "invoice-pro")
  text(size: 13pt, fill: muted, [ · #tl.title])
  v(10pt)
  if f.at("caption", default: none) not in (none, "") {
    let n = f.at("n", default: none)
    grid(
      columns: (auto, 1fr),
      column-gutter: 12pt,
      align: horizon,
      if n != none {
        box(width: 32pt, height: 32pt, radius: 16pt, fill: accent, align(
          center + horizon,
          text(size: 16pt, weight: "bold", fill: white, str(n)),
        ))
      },
      text(size: 26pt, weight: "bold", fill: ink, f.caption),
    )
    if f.at("sub", default: none) not in (none, "") {
      v(5pt)
      pad(
        left: if n != none { 44pt } else { 0pt },
        text(size: 16pt, fill: muted, f.sub),
      )
    }
  }
}))

#let code-view(f) = {
  let hl = f.at("hl", default: none)
  let caret = f.at("caret", default: none)
  let first = f.at("first", default: 0)
  set text(font: mono, size: code-size / 0.8)
  set par(leading: 0pt, spacing: 0pt, justify: false)
  show raw.line: it => {
    let i = it.number - 1
    let marked = hl != none and i >= hl.at(0) and i <= hl.at(1)
    box(
      width: 100%,
      height: lh,
      fill: if marked { rgb("#fef3c7") } else { none },
      inset: (left: gutter),
      {
        place(left + horizon, dx: -gutter, box(width: gutter - 14pt, align(
          right,
          text(size: 11pt, fill: rgb("#a3acb9"), str(it.number)),
        )))
        if marked {
          place(left, dx: -gutter, rect(
            width: 3.5pt,
            height: lh,
            fill: rgb("#f59e0b"),
          ))
        }
        if caret != none and caret.at(0) == i {
          place(left + horizon, dx: caret.at(1) * adv - 1pt, rect(
            width: 2pt,
            height: lh - 4pt,
            fill: accent,
          ))
        }
        align(horizon, it.body)
      },
    )
  }
  box(height: geo.lines * lh, width: 100%, clip: true, move(
    dy: -first * lh,
    raw(f.code, lang: "typ", block: true),
  ))
}

#let editor-panel(f) = {
  let e = geo.editor
  place(dx: pt(e.x), dy: pt(e.y), {
    for (k, a) in ((7pt, 0.05), (3pt, 0.06)) {
      place(dy: k, rect(
        width: pt(e.w),
        height: pt(e.h),
        radius: 10pt,
        fill: shade(a),
      ))
    }
    // every part is placed, so no paragraph spacing moves the code
    box(
      width: pt(e.w),
      height: pt(e.h),
      radius: 10pt,
      fill: white,
      stroke: 0.8pt + rgb("#d5dbe3"),
      clip: true,
      {
        place(box(
          width: 100%,
          height: pt(geo.bar),
          fill: rgb("#f8fafc"),
          inset: (x: 14pt),
          align(horizon, {
            for c in ("#f87171", "#fbbf24", "#34d399") {
              box(width: 10pt, height: 10pt, radius: 5pt, fill: rgb(c))
              h(6pt)
            }
            h(10pt)
            text(size: 13pt, fill: muted, font: mono, tl.at(
              "file",
              default: "invoice.typ",
            ))
          }),
        ))
        place(dy: pt(geo.bar), line(
          length: 100%,
          stroke: 0.8pt + rgb("#e2e8f0"),
        ))
        place(dy: pt(geo.bar + geo.code-top), box(
          width: pt(e.w) - 8pt,
          code-view(f),
        ))
      },
    )
  })
}

#let preview(f) = {
  let vp = f.vp
  let panel = f.at("panel", default: 0)
  if panel > 0 {
    for (k, a) in ((10pt, 0.07), (4pt, 0.08)) {
      place(dx: pt(vp.x), dy: pt(vp.y) + k, rect(
        width: pt(vp.w),
        height: pt(vp.h),
        radius: 12pt,
        fill: shade(a * panel),
      ))
    }
    place(dx: pt(vp.x), dy: pt(vp.y), rect(
      width: pt(vp.w),
      height: pt(vp.h),
      radius: 12pt,
      fill: alpha(rgb("#f8fafc"), panel),
      stroke: 1pt + alpha(rgb("#cbd5e1"), panel),
    ))
  }
  place(dx: pt(vp.x), dy: pt(vp.y), box(
    width: pt(vp.w),
    height: pt(vp.h),
    clip: true,
    radius: if panel > 0 { 12pt } else { 0pt },
    {
      for p in f.at("pages", default: ()) {
        let (x, y, w, h) = (pt(p.x), pt(p.y), pt(p.w), pt(p.h))
        for (k, a) in ((7pt, 0.04), (4pt, 0.06), (2pt, 0.08)) {
          place(dx: x - k * 0.25, dy: y + k, rect(
            width: w + k * 0.5,
            height: h,
            radius: 2pt,
            fill: shade(a),
          ))
        }
        place(dx: x, dy: y, image(p.img, width: w, height: h))
      }
    },
  ))
}

// While the spotlight covers the editor, the line being typed shows in a chip
// right of the caption.
#let chip(f) = {
  let c = f.at("chip", default: none)
  if c == none { return }
  let size = 22pt
  let a = size * 1233 / 2048
  let sp = geo.spotlight
  place(dx: pt(sp.x), dy: 34pt, box(
    width: pt(sp.w),
    height: pt(sp.y) - 46pt,
    align(
      right + horizon,
      box(
        fill: white,
        stroke: 1.5pt + accent,
        radius: 10pt,
        inset: (x: 18pt, y: 12pt),
        {
          text(size: 11pt, fill: muted, font: mono, tl.at(
            "file",
            default: "invoice.typ",
          ))
          v(6pt, weak: false)
          set text(font: mono, size: size / 0.8)
          box(height: size * 1.25, {
            align(horizon, raw(c.code, lang: "typ"))
            place(left + horizon, dx: c.col * a - 1pt, rect(
              width: 2.5pt,
              height: size * 1.3,
              fill: accent,
            ))
          })
        },
      ),
    ),
  ))
}

#let badge(f) = {
  let b = f.at("badge", default: none)
  if b == none { return }
  let a = b.at("alpha", default: 1.0)
  let vp = geo.preview
  place(dx: pt(vp.x), dy: pt(vp.y + vp.h) - 66pt, box(width: pt(vp.w), align(
    center,
    box(
      fill: alpha(rgb("#065f46"), a * 0.95),
      radius: 22pt,
      inset: (x: 20pt, y: 11pt),
      text(size: 17pt, weight: "bold", fill: alpha(white, a), b.text),
    ),
  )))
}

#let progress(f) = {
  let p = f.at("progress", default: 0)
  place(dy: H - 5pt, rect(width: W, height: 5pt, fill: rgb("#cbd5e1")))
  place(dy: H - 5pt, rect(width: W * p, height: 5pt, fill: accent))
}

#let card(f) = {
  let c = f.at("card", default: none)
  if c == none { return }
  let a0 = c.at("alpha", default: 1.0)
  place(rect(width: W, height: H, fill: alpha(rgb("#0f172a"), a0)))
  // the text shows once the backdrop is dark enough to carry it
  let a = calc.max(0, a0 * 2 - 1)
  let fg = alpha(white, a)
  let soft = alpha(rgb("#cbd5e1"), a)
  let teal = alpha(rgb("#5eead4"), a)
  if c.kind == "title" {
    place(dx: 96pt, dy: 196pt, box(width: 1090pt, {
      set par(leading: 0.5em)
      text(size: 22pt, weight: "bold", fill: teal, "invoice-pro")
      v(16pt)
      text(size: 56pt, weight: "bold", fill: fg, tl.title)
      v(12pt)
      text(size: 26pt, fill: soft, tl.subtitle)
      v(44pt)
      text(size: 16pt, fill: alpha(rgb("#94a3b8"), a), tl.at(
        "tagline",
        default: "An invoice template for Typst · open source",
      ))
    }))
  } else {
    place(dx: 96pt, dy: 168pt, box(width: 1090pt, {
      set par(leading: 0.5em)
      text(size: 22pt, weight: "bold", fill: teal, "invoice-pro")
      v(16pt)
      text(size: 48pt, weight: "bold", fill: fg, tl.outro)
      v(28pt)
      box(
        fill: alpha(rgb("#1e293b"), a),
        radius: 8pt,
        inset: (x: 20pt, y: 15pt),
        text(
          font: mono,
          size: 22pt,
          fill: alpha(rgb("#e2e8f0"), a),
          tl.import,
        ),
      )
      v(30pt)
      text(size: 21pt, fill: soft, tl.link)
    }))
  }
}

#for (i, f) in tl.frames.enumerate() {
  if i > 0 { pagebreak() }
  let c = f.at("card", default: none)
  if c == none or c.at("alpha", default: 1.0) < 1.0 {
    backdrop()
    header(f)
    editor-panel(f)
    preview(f)
    chip(f)
    badge(f)
    progress(f)
  }
  card(f)
}
