#import "@preview/touying:0.6.1": *
#import "rvl_theme.typ": *

#show: rvl-theme.with(
  // Fill these manually:
  config-info(
    title: [LiteVLoc:\ Map-Lite Visual Localization for\ Image Goal Navigation],
    presenter: [Your Name],
    paper_authors: [First Author, Second Author, Third Author, et al.],
    paper_venue: [ICRA 2026],
    date: rvl-date("2026-01-09"),
  ),
  footer: self => self.info.institution,
)

// Cover
#rvl-title-slide()

= Introduction
== Outline
- Motivation
- Method
- Experiment
- Conclusion

== Motivation
This theme follows the PPTX geometry:
- Title at top-left
- Content starts lower (PPT-like)
- Bottom blue bar + top-right logo
- Footer: date | center text | page number

= Method
== System Overview
- ...

= Experiment
== Results
#grid(
  columns: (1fr, 1fr),
  gutter: 0.35in,
  [
    *Setup*
    - Dataset: ...
    - Metrics: ...
  ],
  [
    *Results*
    - Accuracy: ...
    - Latency: ...
  ],
)

= Conclusion
== Conclusion
- Summary
- Future work
