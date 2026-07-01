---
name: work-report
description: Generate a manager-facing daily or weekly work report through a self-correcting write→review loop. Gathers the user's GitHub PRs/commits, Jira activity (with comments), and Confluence pages once, then a writer subagent drafts a JIRA-centric report (this period's work + next period's plan) and an independent reviewer subagent validates it, regenerating until it passes or a stop condition fires. Use when the user asks for a 日报 / 周报 / daily report / weekly report / work summary / standup of what they did today or this week.
---

# Work Report (日报 / 周报) — write→review loop

You are the **orchestrator**. Gather the user's activity once into an evidence file,
then run a writer subagent → reviewer subagent loop until the report passes or a stop
condition fires. The report is JIRA-centric: each work item is built around a Jira
issue; open issues become the next-period plan.

## When to use
User asks for a daily/weekly work summary, 日报, 周报, standup, or "what did I do
today / this week".

## Fixed parameters (this user's environment)
| Thing | Value |
|-------|-------|
| Atlassian cloudId | `0632a3fb-15aa-4b67-b1f9-db7b2e773915` (site `yipitdata5`) |
| GitHub author / org | `JacksonWong123` / `agent8` |
| Confluence space | `ED` (Edison) |
| Timezone | `Asia/Chongqing` |

### Jira project → product mapping
| Project key | Product |
|-------------|---------|
| `FEEDS` | Insight |
| `SHFEEDS` | SpendHound Feeds |
| `OPX` | Edison Ops (deploy / infra requests) |

### Branch semantics (shipped vs test merge)
A merged PR is a **real shipped change** only if its **base branch** is a production
branch; everything else is a **test-supporting merge**. `collect_github.sh` tags each
PR `SHIP→<base>` or `test→<base>` — trust the tag. A head branch often embeds the Jira
key (e.g. `py3-12-spendhound_SHFEEDS-1537_qa` → SHFEEDS-1537); use it to link PRs to
issues (key inheritance: a parent-key branch still supports the in-window sub-issue).

| Project | Production (= ship) | Staging (= test) |
|---------|---------------------|------------------|
| Insight | `production` | `release` |
| SpendHound | `py3-12-spendhound` | `py3-12-spendhound-release` |

### Done-set (drives the Next-Week plan)
A Jira counts as **done** if its status is one of: `Closed`, `Done`, `Resolved`,
`Test Done`. Everything else is **open** and goes into the plan (weekly only).

---

## Step 1 — Parse mode
Argument is `daily` (default) or `weekly`. Map phrasings: 日报/today → `daily`;
周报/this week → `weekly`.

## Step 2 — Gather evidence ONCE

Do all gathering yourself (the subagents have isolated context and only read the file
you produce). Collect everything, then write it to
`~/.claude/skills/work-report/.runs/<mode>-<start>_<end>/evidence.md`.

### 2a. GitHub
```
bash ~/.claude/skills/work-report/scripts/collect_github.sh <mode>
```
Parse line 1: `WINDOW mode=… start=YYYY-MM-DD end=YYYY-MM-DD start_iso=… end_iso=… tz=…`.
Keep `start`/`end` (reuse for Jira/Confluence and the run-dir name). The rest of the
output is the PR/commit markdown with SHIP/test tags and `[head → base]` branches —
keep it verbatim for the Evidence section.

### 2b. Jira (`searchJiraIssuesUsingJql`, all projects)
Candidate issues touched in the window:
```
(creator = currentUser() OR assignee = currentUser() OR reporter = currentUser())
  AND updated >= "<start> 00:00"
ORDER BY updated DESC
```
fields `["key","summary","status","project","updated","issuetype"]`, maxResults 50.

For each candidate, `getJiraIssue` with `expand=changelog` and read its comments.
Record **only the user's own in-window actions** — Created / Transitioned / Commented
(keep the comment text as narrative material) / Updated. Skip issues where the user
did nothing in the window. Tag each issue `done` or `open` using the done-set above.

(Comments on issues the user does not own/assign are a known JQL gap. Optionally try
once: `issueFunction in commented("by currentUser() after <start>")`; if Jira rejects
it, skip silently and note "(comment capture limited to issues I'm involved in)" in
the evidence.)

### 2c. Confluence (`searchConfluenceUsingCql`)
```
space = ED AND contributor = currentUser() AND lastmodified >= "<start_yyyy/MM/dd> 00:00"
  AND type = page ORDER BY lastmodified DESC
```
(CQL dates use `yyyy/MM/dd`.) Collect title, webUrl, lastModified.

### 2d. Write evidence.md
```
WINDOW mode=<mode> start=<start> end=<end>
DONE-SET: Closed, Done, Resolved, Test Done

## GitHub PRs
<verbatim PR markdown — SHIP/test tags, [head → base], URLs>
## GitHub Commits
<verbatim commit markdown — URLs>

## Jira
- KEY — <summary> [<status>] (done|open)
  branch: <head branch naming this key, if any>
  my actions: <Created/Transitioned/Commented/Updated …>
  comments: <excerpts of the user's own comments>
- ...one block per issue...

## Confluence
- <title> (<webUrl>) · modified <date>
```
If a source returns nothing, write `None` under its heading. If gathering a source
fails outright (access denied, etc.), record that plainly — the reviewer will escalate.

## Step 3 — Run the write→review loop

Run rounds `1..3`. Each round spawns two subagents via the **Agent** tool (default
`claude` type). Pass file paths and the prompt files' contents into the Agent prompt —
do **not** paste the evidence into the prompt; the subagents read it from disk.

**Writer call** — prompt = contents of `~/.claude/skills/work-report/prompts/writer.md`
plus:
- `MODE` = the mode
- `EVIDENCE_PATH` = `<run-dir>/evidence.md`
- `DRAFT_PATH` = `<run-dir>/draft.md`
- `PRIOR_CHECKLIST` = the previous round's `reasons` (omit on round 1)

**Reviewer call** — prompt = contents of
`~/.claude/skills/work-report/prompts/reviewer.md` plus:
- `MODE` = the mode
- `EVIDENCE_PATH` = `<run-dir>/evidence.md`
- `DRAFT_PATH` = `<run-dir>/draft.md`
- `VERDICT_PATH` = `<run-dir>/verdict-<round>.json`

After the reviewer returns, read `verdict-<round>.json` and apply the stop logic:

```
if verdict.pass:                 → print draft.md to terminal. DONE.
if verdict.escalate:             → STOP. Tell the user the escalate_reason and ask
                                   how to proceed. Do NOT loop.
if round > 1 and
   set(categories this round) == set(categories last round):
                                 → STOP (stuck). Print draft.md + the checklist;
                                   tell the user it is looping on the same issues.
if round == 3:                   → STOP. Print draft.md + the outstanding checklist;
                                   tell the user it did not pass in 3 rounds.
else:                            → next round (feed reasons to the writer).
```

`categories` = the set of `reason.category` values. Compare **sets**, so two rounds
failing on the same category(s) — even with different wording — count as stuck.

## Step 4 — Output
Print the final report (from `draft.md`) to the terminal. On a non-pass stop, print
the best draft followed by the remaining checklist and the reason it stopped. The
`.runs/` files are scratch — leave them for debugging, don't print their paths unless
asked.

## Hard rules (enforced by the subagents, restated for you)
1. **English report.** 2. **No invented references** — only what's in evidence.md.
3. **Every sentence ≤ 30 words.** 4. **All concrete URLs in the Evidence section**,
in both modes. 5. **Next Week = open Jiras only** (weekly); daily has no plan section.
