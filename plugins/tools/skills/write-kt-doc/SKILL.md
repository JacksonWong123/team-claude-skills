---
name: write-kt-doc
description: Write a knowledge-transfer (KT) / onboarding wiki for a code module or system through a self-correcting write→review pipeline, then publish it to Confluence as a draft. Starts from a user-provided seed doc, auto-gathers related GitHub code, Confluence pages, and Jira issues, then runs three gated loops — fact-check, de-AI, format/detail — each a writer→reviewer loop that repeats until its reviewer passes. Produces a code-grounded, terminology-reconciled draft; unverifiable-but-important claims are flagged for a human, not invented. Use when the user asks to document a module/system/pipeline for a team, write a KT doc, an onboarding guide, or a "how X works" wiki.
---

# Write a KT Doc — gather → 3 review loops → publish

You are the **orchestrator**. Gather materials once into a single file, then agree a
section **outline** with the user before drafting. Only after they sign off do you run
three sequential write→review loops over one shared draft — **fact-check → de-AI →
format/detail** — each looping until its reviewer passes or a stop condition fires.
Then publish a Confluence **draft**, or hand the draft back to a human if a loop can't
converge. The core discipline: **every claim traces to code or a first-party source;
nothing is invented.** See `SOP.md` for the human-readable methodology.

## When to use
The user wants a KT / onboarding / "how this works" doc for a module, service, pipeline,
or system — usually for a named audience (QA, SRE, new hires, another team) and destined
for Confluence.

## Hard rules
1. **Code is ground truth.** When a doc and the code disagree, the code wins — state the
   code-true fact and surface the discrepancy, don't silently pick one.
2. **No invented file:line / API / field names.** Anything cited must exist; the
   fact-check reviewer re-opens cited files to confirm.
3. **Unverifiable claims are deleted, not guessed** — except important ones, which are
   wrapped in a `NEEDS HUMAN VERIFICATION` panel and listed in the run summary.
4. **Outward-facing publish is a confirmed action.** Never publish to Confluence without
   the user confirming location, language, and draft-vs-published. Default to **draft**.

## Run state (one dir per run)
Create `~/.claude/skills/write-kt-doc/.runs/<slug>-<timestamp>/` (slug from the module
name; timestamp from `date +%Y%m%d-%H%M%S`). Files:
- `materials.md` — single source of truth (audience, repo root path(s), source links,
  code map with `file:line`, glossary, discrepancies).
- `outline.md` — the approved section outline (heading + one-line purpose per section),
  drafted from `materials.md` and signed off by the user before drafting starts.
- `draft.md` — the working draft (Confluence storage-format HTML), shared across loops.
- `flags.md` — accumulated `NEEDS HUMAN VERIFICATION` items.
- `citations.lock` — citation/link inventory, snapshotted when the fact-check loop passes.
- `verdict-<loop>-<round>.json` — each reviewer verdict.

The subagents have isolated context; they read these files from disk. Do **not** paste
materials into the Agent prompt — pass the prompt file's contents plus the file paths.

---

## Phase A — Gather materials

1. **Seed doc.** Take the user's existing doc (path or pasted) as the starting point and
   the audience signal. If they have none, ask what module and audience.
2. **Confirm two things only** (don't over-ask): the target **audience/altitude** (dev =
   low-level; feature-QA = frontend + business meaning; platform-QA = both + backend
   basics; SRE = run/observe/recover) and the Confluence **publish target** (space +
   parent page). Get the **repo root path(s)**.
3. **Auto-search related content**, seeded by the doc's topics:
   - **Code** — launch parallel `Explore` subagents to build a factual map with
     `file:line` citations: entry points, data flow, queues/tables, config namespaces,
     what each stage does. Tell them to flag what they could NOT find.
   - **Confluence** — `search` / `searchConfluenceUsingCql` for related pages to reuse
     and cross-reference (not duplicate). Note what each already covers well.
   - **Jira** — `searchJiraIssuesUsingJql` / `search` for related issues giving history
     and context (why something works the way it does).
4. **Glossary + discrepancies.** Build one terminology table (`audience term | doc term |
   code constant | one-liner`) and a list of every doc-vs-code / doc-vs-doc contradiction.
5. **Write `materials.md`** with: audience + "what they must be able to DO"; the repo
   root path(s); the code map with `file:line`; the Confluence/Jira/seed-doc source links;
   the glossary; the discrepancies. If a source returns nothing, write `None`. If a
   source fails outright (access denied), record it plainly — the reviewer will escalate.

---

## Phase A.5 — Outline gate (human sign-off)

Before any drafting, agree the doc's **shape** with the user. This is a **human gate**:
do not start Phase B until the user approves.

1. **Draft `outline.md`** from `materials.md`: an ordered list of section headings, each
   with a one-line purpose, structured to the audience's tasks (what they must be able to
   DO). Headings + one-line purpose only — no per-section source mapping, no prose.
2. **Present the outline** in chat and ask the user for feedback.
3. **On feedback, revise `outline.md`** and re-present. Repeat until the user approves.
4. **On approval, advance to Phase B.** The approved `outline.md` is the draft skeleton.

---

## Phases B/C/D — The three loops

Each loop repeats `writer → reviewer` for rounds `1..3`. Spawn subagents via the **Agent**
tool: the **writer** as default `claude` type; each **reviewer** as default `claude` type
too (reviewers need Read/Grep tools to verify code, and Write for the verdict).

**Writer call** — prompt = contents of `prompts/writer.md` plus:
- `LOOP` = `facts` | `deai` | `format` (this loop)
- `MATERIALS_PATH`, `DRAFT_PATH`, `FLAGS_PATH` = the run-dir files
- `OUTLINE_PATH` = the run-dir `outline.md` (loop `facts` only — the approved skeleton)
- `CITATIONS_LOCK_PATH` = the run-dir file (loops `deai`/`format` only)
- `PRIOR_CHECKLIST` = the previous round's `reasons` (omit on round 1)

**Reviewer call** — prompt = contents of the loop's reviewer file
(`prompts/reviewer-facts.md` | `reviewer-deai.md` | `reviewer-format.md`) plus:
- `MATERIALS_PATH` (facts loop), `DRAFT_PATH`, `CITATIONS_LOCK_PATH` (deai/format loops)
- `VERDICT_PATH` = `<run-dir>/verdict-<loop>-<round>.json`

After the reviewer returns, read the verdict and apply the stop logic:
```
if verdict.pass:                 → loop done. (facts loop: snapshot citations.lock now.)
                                   Advance to the next loop, or to Phase E after format.
if verdict.escalate:             → STOP. Tell the user escalate_reason. Do NOT loop.
if round > 1 and
   set(categories this round) == set(categories last round):
                                 → STOP (stuck). Hand draft.md + checklist to the user.
if round == 3:                   → STOP (max rounds). Hand draft.md + outstanding
                                   checklist to the user.
else:                            → next round (feed verdict.reasons to the writer).
```
`categories` = the set of `reason.category` values. Compare **sets**, so two rounds
failing on the same category(s) — even with different wording — count as stuck. A stop
that is not `pass` means **do not publish**; hand back the best draft + remaining
checklist + the reason it stopped.

### Loop B — fact-check  (`LOOP = facts`)
Round 1 builds the full draft from `materials.md`, following the approved `outline.md` as
its section skeleton; later rounds fix only the checklist.
The reviewer (`reviewer-facts.md`) re-opens cited code under the repo root and verifies
each claim has a real source, code wins conflicts, high-risk assertions are confirmed,
time-sensitive facts are tagged, and unverifiable claims are deleted or panel-flagged.
**On pass:** snapshot every citation and `<a href>` in `draft.md` into `citations.lock`
(one per line) before advancing — the next two loops must preserve them all.

### Loop C — de-AI  (`LOOP = deai`)
Facts frozen. The reviewer (`reviewer-deai.md`) enforces: no emoji, sentences ≤ 30 words
(split on `;`), no filler phrases, no em-dash overuse, no marketing adjectives, no `bloat`
(out-of-scope content, a caveat repeated across sections, or citations over-proving one
fact), and no dropped citation (vs `citations.lock`, except citations removed as part of an
accepted `bloat` deletion).

### Loop D — format/detail  (`LOOP = format`)
Facts frozen. The reviewer (`reviewer-format.md`) enforces: no code-block line > 90 chars
(unless marked `wide-line-exception`), valid Confluence HTML, working links, and no
dropped citation.

---

## Phase E — Publish / hand back

- **All three loops passed** → confirm with the user: target space + parent, language,
  and draft-vs-published (default **draft**). Then publish (see mechanics below) and
  re-fetch to verify render. Hand back the **URL plus a run summary** that lists every
  `NEEDS HUMAN VERIFICATION` flag from `flags.md`. Flags do not block publishing.
- **A loop stopped on stuck-loop / max-rounds** → do NOT publish. Hand back `draft.md`
  + the outstanding checklist + which loop stalled.
- **A loop escalated** → STOP, surface the `escalate_reason`, ask how to proceed.

The `.runs/` files are scratch — leave them for debugging; don't print their paths unless
asked.

## Confluence mechanics (when publishing)
- Get `cloudId` (the site host like `yoursite.atlassian.net` usually works directly) and
  the `spaceId` (numeric — `getConfluenceSpaces` with the space `key`).
- `createConfluencePage` with `contentFormat: "html"` (the draft is storage-format HTML),
  `status: "draft"`, `parentId` = the parent page id. The body is `draft.md` verbatim.
- Title convention: **"«Topic» — KT for «Audience»"** (e.g. "Insight De-dup Logic — KT for
  Platform QA").
- HTML supports headings, tables, `data-type="panel-info|warning|note"`, code blocks,
  internal links. Keep nesting valid (no block-in-inline; no headings in table cells).
- Re-fetch with `getConfluencePage` to verify render (tables, panels, links) before
  telling the user it's done.

## Anti-patterns
- Writing from existing wikis alone, without reading code (you inherit their staleness).
- A "complete" doc that re-explains everything instead of linking — bloated and instantly
  stale. Reuse existing docs; write new content only where THIS audience differs.
- Citing `file.py:123` you never opened — the fact reviewer will catch it; don't ship it.
- Citing a local/seed file path the audience can't open, or guessing an author/owner/date —
  cite a shareable link or drop the claim.
- Out-of-scope "for awareness" padding, a caveat repeated across sections, or several
  citations over-proving one fact — the human just deletes these; the `bloat` check does too.
- Publishing live without asking, or publishing past a non-pass stop.
- Letting de-AI or format edits silently drop a citation — `citations.lock` guards this
  (the one exception is a citation removed as part of an accepted `bloat` deletion).
