#import "@preview/touying:0.6.1": *
#import components: *
#import utils: *

#let RVL_PRIMARY = rgb("#002060")

// Page geometry (inches)
#let RVL_W = 13.3333in
#let RVL_H = 7.5in

// Title & body placeholders
#let RVL_TITLE_X = 0.9167in
#let RVL_TITLE_Y = 0.659in
#let RVL_TITLE_W = 11.5in
#let RVL_TITLE_H = 1.45in

#let RVL_BODY_X = 0.9167in
#let RVL_BODY_Y = 1.9963in
#let RVL_BODY_W = 11.5in

// Accent bars
#let RVL_LEFT_BAR_X = 0.70in
#let RVL_LEFT_BAR_Y = 0.659in
#let RVL_LEFT_BAR_W = 0.0625in
#let RVL_LEFT_BAR_H = 0.52in

#let RVL_BOTTOM_BAR_Y = 7.2874in
#let RVL_BOTTOM_BAR_H = 0.1307in
#let RVL_BODY_H = RVL_BOTTOM_BAR_Y - RVL_BODY_Y - 0.15in

// Logo (right anchor so it never clips)
#let RVL_LOGO_Y = -0.2564in
#let RVL_LOGO_W = 4.5667in
#let RVL_LOGO_H = 1.1417in
#let RVL_LOGO_RIGHT_PAD = -0.05in // negative moves left a bit (safe margin)

// Footer positioning
#let RVL_FOOTER_Y = 6.9514in
#let RVL_FOOTER_DATE_W = 3.0in
#let RVL_FOOTER_CENTER_X = 4.4167in
#let RVL_FOOTER_CENTER_W = 4.5in
#let RVL_FOOTER_PAGENO_X = 10.0660in
#let RVL_FOOTER_PAGENO_W = 3.0in

// Extra padding inside title boxes to avoid clipping descenders.
#let RVL_TITLE_INSET_TOP = 4pt
#let RVL_TITLE_INSET_BOTTOM = 8pt
#let RVL_COVER_INSET_TOP = 6pt
#let RVL_COVER_INSET_BOTTOM = 10pt

// ----------------------------
// Date helpers
// ----------------------------
#let rvl-date(iso) = {
  let p = iso.split("-")
  datetime(year: int(p.at(0)), month: int(p.at(1)), day: int(p.at(2)))
}

#let rvl-format-date(d) = {
  let dt = if type(d) == str { rvl-date(d) } else { d }
  let mons = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  [#mons.at(dt.month() - 1) #dt.day(), #dt.year()]
}

// ----------------------------
// Auto-fit helper (measure-based)
// ----------------------------
#let rvl-fit-text(content, width, max-height, sizes, leading: 0.98em) = context {
  for s in sizes {
    let c = block(width: width)[
      #set text(size: s)
      #set par(leading: leading)
      #content
    ]
    if measure(c).height <= max-height { return c }
  }

  // Fallback: scale down the smallest candidate.
  let s = sizes.last()
  let c = block(width: width)[
    #set text(size: s)
    #set par(leading: leading)
    #content
  ]
  let h = measure(c).height
  let pct = calc.max(1%, max-height / h * 100%)
  block(width: width, height: max-height)[
    #set align(top + center)
    #scale(x: pct, y: pct, origin: top + center)[#c]
  ]
}

#let rvl-abbrev-author(name) = {
  let parts = name.split(" ").filter(p => p.len() > 0)
  if parts.len() <= 1 { return name }
  let last = parts.last()
  let initials = parts.slice(0, parts.len() - 1).map(p => p.first() + ".").join(" ")
  initials + " " + last
}

#let rvl-format-authors(authors) = {
  if type(authors) == array {
    authors.map(rvl-abbrev-author).join(", ")
  } else {
    authors
  }
}

#let rvl-fit-title(title, width, max-height) = rvl-fit-text(
  title,
  width,
  max-height,
  (36pt, 34pt, 32pt, 30pt, 28pt, 26pt, 24pt),
  leading: 0.96em,
)

#let rvl-fit-cover-title(title, width, max-height) = rvl-fit-text(
  title,
  width,
  max-height,
  (42pt, 38pt, 34pt, 30pt, 27pt, 24pt, 22pt),
  leading: 0.98em,
)

#let rvl-fit-cover-meta(content, width, max-height) = rvl-fit-text(
  content,
  width,
  max-height,
  (30pt, 28pt, 26pt, 24pt, 22pt, 20pt, 18pt, 16pt, 14pt),
  leading: 0.95em,
)

#let rvl-fit-cover-authors(content, width, max-height) = rvl-fit-text(
  content,
  width,
  max-height,
  (22pt, 20pt, 18pt, 16pt, 14pt, 12pt, 11pt, 10pt),
  leading: 0.92em,
)

#let rvl-fit-cover-venue(content, width, max-height) = rvl-fit-text(
  content,
  width,
  max-height,
  (20pt, 18pt, 16pt, 14pt, 12pt),
  leading: 0.95em,
)

// ----------------------------
// Decorations & overlay layers
// ----------------------------
#let rvl-decorations(self) = [
  #place(top + left, dx: 0in, dy: RVL_BOTTOM_BAR_Y)[
    #rect(width: RVL_W, height: RVL_BOTTOM_BAR_H, fill: self.colors.primary)
  ]

  #if self.store.title != none {
    place(top + left, dx: RVL_LEFT_BAR_X, dy: RVL_LEFT_BAR_Y)[
      #rect(width: RVL_LEFT_BAR_W, height: RVL_LEFT_BAR_H, fill: self.colors.primary)
    ]
  }
]

#let rvl-logo(self) = [
  #place(top + right, dx: RVL_LOGO_RIGHT_PAD, dy: RVL_LOGO_Y)[
    #image("./assets/logo.png", width: RVL_LOGO_W, height: RVL_LOGO_H, fit: "contain")
  ]
]

#let rvl-footer-layer(self) = [
  #set text(size: 14pt, fill: self.colors.neutral-darkest)

  #if self.info.date != none {
    place(top + left, dx: RVL_TITLE_X, dy: RVL_FOOTER_Y)[
      #box(width: RVL_FOOTER_DATE_W, align(left)[#rvl-format-date(self.info.date)])
    ]
  }

  #if self.store.footer != none {
    place(top + left, dx: RVL_FOOTER_CENTER_X, dy: RVL_FOOTER_Y)[
      #box(width: RVL_FOOTER_CENTER_W, align(center)[#utils.call-or-display(self, self.store.footer)])
    ]
  }

  #place(top + left, dx: RVL_FOOTER_PAGENO_X, dy: RVL_FOOTER_Y)[
    #box(width: RVL_FOOTER_PAGENO_W, align(right)[#context utils.slide-counter.display()])
  ]
]

// ----------------------------
// Slide functions
// ----------------------------
#let rvl-slide(body, title: auto, ..args) = touying-slide-wrapper(self => {
  let slide-title = if title != auto { title } else {
    utils.display-current-heading(level: 2, numbered: false)
  }
  self.store.title = slide-title

  self = utils.merge-dicts(
    self,
    config-page(
      width: RVL_W,
      height: RVL_H,
      fill: self.colors.neutral-lightest,
      margin: 0in,
      header: none,
      footer: none,
      background: rvl-decorations(self),
      foreground: [#rvl-logo(self) #rvl-footer-layer(self)],
    ),
  )

  // Fit to the inner height (box height minus inset).
  let fit_h = RVL_TITLE_H - RVL_TITLE_INSET_TOP - RVL_TITLE_INSET_BOTTOM

  let layer = [
    #if self.store.title != none {
      place(top + left, dx: RVL_TITLE_X, dy: RVL_TITLE_Y)[
        #box(
          width: RVL_TITLE_W,
          height: RVL_TITLE_H,
          clip: true,
          inset: (top: RVL_TITLE_INSET_TOP, bottom: RVL_TITLE_INSET_BOTTOM),
        )[
          #set text(weight: "bold", fill: self.colors.primary)
          #rvl-fit-title(self.store.title, RVL_TITLE_W, fit_h)
        ]
      ]
    }

    #place(top + left, dx: RVL_BODY_X, dy: RVL_BODY_Y)[
      #box(width: RVL_BODY_W, height: RVL_BODY_H, clip: true)[
        #set text(size: 25pt, fill: self.colors.neutral-darkest)
        #set par(leading: 1.12em)
        #set list(spacing: 0.6em)
        #body
      ]
    ]
  ]

  touying-slide(self: self, layer, ..args)
})

#let rvl-title-slide(..args) = touying-slide-wrapper(self => {
  let info = self.info + args.named()
  let presenter = info.at("presenter", default: info.at("author", default: none))
  let paper_authors = info.at("paper_authors_short", default: info.at("paper_authors", default: none))
  let paper_venue = info.at("paper_venue", default: none)

  self = utils.merge-dicts(self, config-page(
    width: RVL_W,
    height: RVL_H,
    fill: self.colors.neutral-lightest,
    margin: 0in,
    header: none,
    footer: none,
    background: none,
    foreground: none,
  ))

  let cover_w = 12.2in
  let cover_h = 2.3in
  let fit_h = cover_h - RVL_COVER_INSET_TOP - RVL_COVER_INSET_BOTTOM
  let meta_w = 10.8in
  let authors_h = if paper_venue != none { 0.80in } else { 0.92in }
  let venue_h = 0.22in
  let group_sep = 0.22in
  let item_sep = 0.07in
  let divider_stroke = 0.8pt + rgb("#c8ccd2")

  let presenter_date = if presenter != none and info.date != none {
    [#presenter #h(0.35em)·#h(0.35em) #rvl-format-date(info.date)]
  } else if presenter != none {
    presenter
  } else if info.date != none {
    rvl-format-date(info.date)
  } else {
    none
  }

  let body = [
    #set align(center + horizon)
    #set text(fill: self.colors.neutral-darkest)
    #set par(justify: false)

    #box(width: cover_w, inset: (top: RVL_COVER_INSET_TOP, bottom: RVL_COVER_INSET_BOTTOM))[
      #set text(weight: "bold")
      #rvl-fit-cover-title(info.title, cover_w, fit_h)
    ]

    #v(group_sep)
    #line(length: 6.5in, stroke: divider_stroke)

    #if paper_authors != none {
      v(0.12in)
      if paper_venue != none {
        box(width: meta_w, height: venue_h, clip: true)[
          #set align(center + horizon)
          #set text(fill: rgb("#666666"))
          #rvl-fit-cover-venue(paper_venue, meta_w, venue_h)
        ]
        v(item_sep)
      }

      box(width: meta_w, height: authors_h, clip: true)[
        #set align(center + horizon)
        #rvl-fit-cover-authors(rvl-format-authors(paper_authors), meta_w, authors_h)
      ]
    }

    #if presenter_date != none {
      v(group_sep)
      set text(size: 16pt, fill: rgb("#666666"), weight: "regular")
      presenter_date
    }
  ]

  touying-slide(self: self, body)
})

#let alert(body) = touying-fn-wrapper(self => utils.alert-with-primary-color.with(self: self)(body))

#let speaker-note(mode: "typ", setting: it => it, note) = {
  touying-fn-wrapper(utils.speaker-note, mode: mode, setting: setting, note)
}

#let rvl-theme(footer: none, ..args, body) = {
  set text(font: "DejaVu Sans", size: 28pt, fill: rgb("#000000"))

  show heading.where(level: 1): it => none
  show heading.where(level: 2): it => none

  show heading.where(level: 3): it => [
    #set text(size: 30pt, weight: "bold")
    #it.body
    #v(0.10in)
  ]

  show: touying-slides.with(
    config-page(width: RVL_W, height: RVL_H, margin: 0in),
    config-common(slide-fn: rvl-slide, new-section-slide-fn: none),
    config-methods(title-slide: rvl-title-slide, alert: utils.alert-with-primary-color),
    config-colors(
      primary: RVL_PRIMARY,
      neutral-lightest: rgb("#ffffff"),
      neutral-darkest: rgb("#000000"),
    ),
    config-store(title: none, footer: footer),
    ..args,
  )

  body
}
