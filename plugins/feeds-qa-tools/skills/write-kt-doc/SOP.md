# KT Doc Writing SOP

A standard operating procedure for writing a knowledge-transfer wiki for a code module, targeted at a specific audience. Human- and AI-readable. The companion `SKILL.md` is the Claude-invocable version (`/write-kt-doc`), which runs this procedure as a gather → 3-loop → publish pipeline.

> **Guiding principle:** every statement traces to code or a first-party source. The doc's job is not to *sound* authoritative — it's to be *verifiably* correct and *useful to one audience*.

---

## Why these steps exist (lessons that shaped this SOP)

- **Audience determines altitude.** A dev doc, a feature-QA doc, and a platform-QA doc about the same system are three different documents. Writing "a doc about X" without pinning the reader produces something nobody can use.
- **Terminology is the silent killer.** Real systems accumulate synonyms: the code, the dev wiki, and the QA wiki each name the same thing differently. A reader who doesn't know `Auto Rerun` == `Template Rerun` == `rerun_type=0` is lost from page one. A glossary up front fixes this once.
- **Docs go stale; code doesn't lie.** Emergency changes, reverted experiments, and renamed fields linger in wikis. Always reconcile against code; tag time-sensitive facts so a future reader knows they can drift.
- **Reuse beats rewrite.** Existing wikis that already nail something (e.g. a field-by-field UI table) should be linked, not re-transcribed. Spend your words where your audience differs from theirs.
- **A self-checked draft is not a verified draft.** Splitting verification into its own loop, with an independent reviewer that re-opens the code, catches what an author rereading their own prose does not.
- **Agree the shape before drafting.** A one-line-per-section outline the human signs off on is far cheaper to fix than restructuring a finished draft across three loops. Wrong ordering, a missing topic, or wrong altitude surface here, not after 2,000 words exist.

---

## The shape: gather once, then three gated loops

```
[A] Gather materials  → materials.md (single source of truth)
        ↓
[A.5] Outline agreed with human → outline.md (headings + purpose)
        ↓
[B] Fact-check loop    writer → reviewer (re-opens code)   until pass
        ↓   (snapshot citations.lock on pass)
[C] De-AI loop         writer → reviewer (tone)            until pass
        ↓
[D] Format/detail loop writer → reviewer (render/width)    until pass
        ↓
[E] Publish draft  /  hand back to human (if a loop can't converge)
```

Each loop runs at most 3 rounds. The reviewer never rewrites — it passes the draft or
returns a precise, fixable checklist that the writer applies in the next round. Stop a
loop early on `pass`, `escalate` (data/permission), a stuck loop (same failure categories
two rounds running), or 3 rounds. Any non-`pass` stop means **do not publish** — hand the
best draft plus the remaining checklist back to a human.

---

## The procedure

### A. Gather materials  ☐
- [ ] Take the user's **seed doc** as the starting point and audience signal.
- [ ] Confirm only two things: **audience/altitude** (dev / feature-QA / platform-QA / SRE) and the Confluence **publish target** (space + parent). Get the **repo root path(s)**.
- [ ] Auto-search related content seeded by the doc's topics:
  - [ ] **Code** — parallel read-only exploration → factual map with `file:line` (entry points, data flow, queues/tables, configs). Record what could NOT be found.
  - [ ] **Confluence** — related pages to reuse/cross-reference; note what they cover well.
  - [ ] **Jira** — related issues for history and context.
- [ ] Build the **glossary** (`audience term | doc | code constant | one-liner`); pick ONE canonical name per concept.
- [ ] List every **doc-vs-code / doc-vs-doc discrepancy**.
- [ ] Write all of the above to `materials.md`, including the repo root path.

### A.5 Outline gate (human sign-off)  ☐
- [ ] Draft `outline.md` from `materials.md`: ordered section headings, each with a
  one-line purpose, structured to the audience's tasks. Headings + purpose only.
- [ ] Show the outline to the human and gather feedback.
- [ ] Revise and re-show until the human approves. Proceed to B only on approval.

### B. Fact-check loop  ☐
- [ ] Writer drafts the doc grounded only in `materials.md`; every claim carries a source.
- [ ] Code citations as `file:line`; on code-vs-doc conflict, the code wins and the discrepancy is noted.
- [ ] Time-sensitive facts (versions, thresholds, schedules) tagged so they read as "as of <commit/date>".
- [ ] Unverifiable + unimportant → deleted. Unverifiable + important → kept, wrapped in a `NEEDS HUMAN VERIFICATION` panel, and logged to `flags.md`.
- [ ] Reviewer **re-opens cited files** and verifies; absolutes ("never/always/all/only") get special scrutiny.
- [ ] On pass: snapshot every citation/link into `citations.lock`.

### C. De-AI loop (facts frozen)  ☐
- [ ] Writer edits tone only; never alters facts, citations, or panels; keeps every locked citation.
- [ ] No emoji. Every sentence ≤ 30 words (split long ones at `;` before condensing).
- [ ] No filler phrases, no em-dash overuse, no marketing adjectives.
- [ ] No meta-commentary — asides aimed at the writer/editor ("reuse those, don't restate", "see above", "TODO") are deleted; only reader-facing content remains.

### D. Format/detail loop (facts frozen)  ☐
- [ ] Writer reflows code-block lines so none exceed **90 chars** (shell continuations, JSON line breaks); truly unbreakable lines marked as accepted exceptions.
- [ ] Valid Confluence HTML (no block-in-inline, no headings in table cells); every link works; no locked citation dropped.

### E. Publish / hand back  ☐
- [ ] All loops passed → confirm location/language/draft; default to **draft**; create, then re-fetch to verify render (tables, panels, links).
- [ ] Hand back the URL **plus a run summary listing every `NEEDS HUMAN VERIFICATION` flag**. Flags do not block publishing.
- [ ] A loop stalled (stuck / 3 rounds) → do NOT publish; hand back the draft + outstanding checklist + which loop stalled.

---

## Copy-paste checklist

```
[ ] A. Seed doc taken; audience + publish target confirmed; repo root recorded
[ ] A. Code/Confluence/Jira auto-searched; glossary + discrepancies built; materials.md written
[ ] A.5 Outline (headings + purpose) drafted, reviewed, and approved by human
[ ] B. Every claim sourced; code wins conflicts; time-sensitive tagged; unverifiable deleted or panel-flagged
[ ] B. Reviewer re-opened cited files; passed; citations.lock snapshotted
[ ] C. No emoji; sentences ≤30 words; no filler/em-dash-overuse/marketing adjectives; no meta-commentary; no citation dropped
[ ] D. Code lines ≤90 chars (or marked exception); valid HTML; links work; no citation dropped
[ ] E. Location/language/draft confirmed; published; render re-verified; URL + flag summary shared
```

---

## Reviewer category labels (stable — used to detect stuck loops)

| Loop | Categories |
|------|------------|
| Fact-check | `missing-source`, `invented-citation`, `unverified-highrisk`, `code-conflict`, `time-sensitive-unflagged`, `unverifiable-not-handled` |
| De-AI | `no-emoji`, `sentence-too-long`, `filler-phrase`, `emdash-overuse`, `marketing-adjective`, `meta-commentary`, `citation-dropped` |
| Format | `code-line-too-wide`, `invalid-html`, `broken-link`, `citation-dropped` |

---

## Confluence cheat-sheet
- `cloudId`: the site host (e.g. `yoursite.atlassian.net`) usually works directly.
- `spaceId`: numeric — fetch via `getConfluenceSpaces` using the space `key`.
- Create: `createConfluencePage`, `contentFormat: html`, `status: draft`, `parentId` = parent page id. Body = `draft.md` verbatim (storage-format HTML).
- HTML: headings, tables, `data-type="panel-info|warning|note"`, code blocks, links. Keep nesting valid.
- Verify: `getConfluencePage` after creating.
