---
name: rvl-group-meeting-typst
description: Use when creating or revising paper presentation slides in this Group-Meeting-Typst repo. Applies the RVL Touying theme, uses rvl-outline-slide and explicit rvl-slide pages, turns paper PDFs and notes into concise English slide content plus Chinese speaker notes, and requires visual render checks for overflow and figure placement.
---

# RVL Group Meeting Typst

This is a repo-local, agent-agnostic workflow guide for paper presentation slides in this repository.

## Scope

Use this when working on slides that:

- live in this repo
- use the RVL Touying theme
- present a paper rather than generic meeting content
- need English slide body plus Chinese speaker notes

Primary source order (use whichever exist):

1. `paper.pdf` — authoritative; extract to `paper.md` if needed
2. `paper.md` — pre-extracted text; use for fact-checking only
3. `note.md` — presenter's own annotations; may not exist
4. current `main.typ` — existing slides; treat as the working draft

`paper.md` and `note.md` are optional. If neither exists, work from `paper.pdf` or from `main.typ` alone. Do not assume these files are present before checking.

Do not invent claims that available sources cannot support.

## Repo Conventions

- Theme import:
  ```typ
  #import "../../rvl_template/rvl_theme.typ": *
  ```
- Cover:
  ```typ
  #rvl-title-slide()
  ```
- Outline: prefer `#rvl-outline-slide(...)`
- Content slides: prefer explicit `#rvl-slide(title: [...])[ ... ]`

When slide stability matters, do not rely on heading-driven auto slide creation. Use explicit `#rvl-slide(...)`.

## Default Workflow

1. Read `main.typ` first.
2. Check which source files exist (`paper.pdf`, `paper.md`, `note.md`). Read whichever are available before rewriting content or notes.
3. Keep slide body concise and interpretive.
4. Keep `#speaker-note` in Chinese.
5. Structure speaker notes as:
   - what to say on this page
   - then likely follow-up questions and safe answers
6. For paper figures: follow Figure Extraction section.
7. After edits, render and visually inspect.

## Slide Writing Rules

- Slides are in English.
- `#speaker-note` is in Chinese.
- Slides are not paper paraphrases.
- Introduction should define scope and contribution, not retell related work.
- Method pages should prefer structure, equations, and figures over long prose.

Avoid Q&A or defensive wording in slide body:

- `actually`
- `what it is not trying to solve`
- `why X?`
- `takeaway`

Prefer neutral academic framing:

- `Research Scope`
- `Contributions`
- `Architecture`
- `Controlled comparison`

## Speaker Note Rules

Speaker notes are not transcripts by default.

Preferred pattern:

```text
1. 這頁我要先講……
2. 這頁的公式 / 圖 / 表格分別對應什麼。
3. 這頁在整篇論文中的角色是什麼。
4. 預備問題：如果教授問……
5. 預備問題：如果教授追問……
```

Rules:

- Answers must stay within the available source files (`paper.pdf`, `paper.md`, `note.md` — whichever exist).
- When a conclusion belongs to experiment, do not preload it into method notes.
- Use phrasing like “這頁只能支持到……” when evidence is limited.

### Prohibited Sentence Patterns

**不是…而是** is prohibited. It wastes words negating before reaching the point.  
Write the positive claim directly.

- Bad: 「這頁不是在做 ablation，而是在問 scaling 的問題。」
- Good: 「這頁要問的是：end-to-end policy 在 desired speed 改變時，能不能比 modular planner 更穩定地 scale。」

**Mechanism attribution without paper support** is prohibited. When the paper reports a result without explaining its cause, the notes must not supply a causal explanation.

- Bad: 「attention 帶來的好處是跨 obstacle 時也比較穩。」
- Good: 「ViT-based 模型在 unseen Trees 環境明顯優於其他模型；paper 沒有進一步拆解是哪個設計元素造成的。」

### Figure and Table Notes

**Speaker notes must be self-sufficient for the presenter.** Do not assume the presenter can read the visual while delivering notes. Every page with a figure or table must include:

For figures:
1. What type of visual it is (line chart with speed on x-axis, top-down trajectory scatter, bar chart, etc.)
2. What each axis represents and which direction is better
3. Whether a reference baseline appears in the plot (e.g., an expert line, an ideal diagonal)
4. For compound figures: walk through each panel in order before drawing cross-panel comparisons

For tables:
1. State explicitly which direction is better (higher / lower success rate = better)
2. Describe how to segment compound tables before reading values (e.g., “先切成兩個環境再逐列看”)
3. Name the column structure before citing specific cells

### Evidence Level

Distinguish these four levels in speaker notes:

1. **Paper direct quote** — paper 原文說 / paper 明寫
2. **Paper's own inference** — paper 的結論是 / 作者自己給的解釋是
3. **Presenter's organizational framing** — 這是根據整個 model design 做出的整理式解讀
4. **Open question** — paper 沒有展開 / 安全講法是停在這裡

When a statement is level 3 or 4, say so explicitly.

## Outline Slide Pattern

Prefer:

```typ
#rvl-outline-slide(
  question: [
    One central research question.
  ],
)[
  #speaker-note[
    Chinese notes focused on why this question is well-posed,
    what it does and does not claim,
    and where later slides answer it.
  ]
]
```

The central question should come from the paper’s real motivation, not from hype around a method family.

## Figure Extraction

When a slide needs a figure from `paper.pdf`:

1. Render the page at high resolution: prefer `mutool draw -r 600`, fallback `pdftocairo -png -r 400`.
2. Crop to the figure body only. **Trim large white margins before adjusting slide layout.**
3. Save under `YYYY-MM-DD/figs/` with a descriptive name (e.g., `fig2_pipeline_hd_trim.png`).
4. Update `main.typ`, re-render the full deck, and inspect the actual slide — not the raw crop.

If required tools are missing (`mutool`, `convert`, `typst`), tell the user before doing layout work.

## Validation Checklist

Always do all of these:

1. Compile the deck.
2. Check page count is as expected.
3. Render slides to PNG if possible.
4. Inspect visually for:
   - overflow at bottom
   - clipped bullets
   - math too large
   - paper captions accidentally left in figure crops
   - figure text illegible at rendered size
   - footer collisions
5. Fix layout and re-render. Do not stop at "compile succeeds".

## Cross-Slide Consistency

Before finalizing, verify:

1. **Numbers match across slides.** Any numeric threshold (speed, success rate, parameter count) cited in a speaker note must be the same value as the corresponding slide that introduced it. The most common failure is early notes being written before experiment results are finalized.
2. **Terminology is consistent.** If the Outline uses "temporal state," every other slide must use the same term. Do not alternate between synonyms (e.g., "temporal state" vs "temporal memory") without explanation.
3. **Central question maps to Conclusion.** The question posed in the Outline slide must receive a direct answer in the Conclusion slide. Verify that the Conclusion echoes the exact framing of the Outline question.
4. **Method notes do not contain quantitative experiment outcomes.** If an experiment result is previewed in a method note, add the phrase "Experiment 頁再展開" to signal scope.

## Experiment Slide Pattern

### Page Order

Write experiment pages in this order:

1. Protocol page: environments, metrics, hardware, trial counts
2. Main backbone comparison (largest result figure)
3. Secondary analysis (path, energy, feature maps) if needed
4. Ablations
5. Hardware transfer last

### Each Experiment Page Speaker Note

Each note must include:

1. What specific claim this page supports (one sentence)
2. How to read the visual (see Figure and Table Notes rules)
3. What this page does not claim or cannot support
4. Prepared questions about limitations of the comparison

Do not write the note as a results summary. Write it as a guide for a presenter who has not re-read the paper in 30 minutes.

## Conclusion Slide Pattern

The Conclusion slide must:

1. **Echo the Outline question directly.** Use the same terminology and framing. Do not rephrase in a way that changes the scope.
2. **Carry correct numeric thresholds from the experiment.** Copy exact numbers from the experiment speaker notes, not a rounded or simplified version.
3. **Acknowledge scope limitations explicitly.** State the evaluation boundary (indoor/outdoor, speed range, obstacle type, motion capture vs wild).
4. **Not introduce new claims.** The Conclusion cannot contain any result that was not introduced and supported earlier in the deck.

If a key experiment result (e.g., modular baseline comparison) had a dedicated slide, include a one-sentence summary or prepared answer for it in the Conclusion speaker notes, even if it does not appear on the card.

## Good Defaults For This Repo

- Use `#rvl-outline-slide(...)` for outline.
- Use explicit `#rvl-slide(...)` for each content page.
- Keep slide body compact enough for the fixed RVL layout.
- Prefer one idea per page.
- When method pages compare models, describe design roles first and leave outcome claims for experiments.
