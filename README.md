# team-claude-skills

Shared [Claude Code](https://code.claude.com) skills for the team,
distributed as a plugin marketplace.

## Install

In Claude Code:

```
/plugin marketplace add JacksonWong123/team-claude-skills
/plugin install feeds-qa-tools@team-claude-skills
```

`owner/repo` shorthand works for public repos. For a private repo over SSH, use the full URL:

```
/plugin marketplace add git@github.com:JacksonWong123/team-claude-skills.git
```

After install the skills are available immediately — no restart needed.

## What's included

The `feeds-qa-tools` plugin bundles two skills:

| Skill | Command | What it does |
|-------|---------|--------------|
| write-kt-doc | `/write-kt-doc` | Writes a code-grounded KT / onboarding wiki via a write→review pipeline (fact-check → de-AI → format), then publishes it to Confluence as a **draft**. Every claim traces to code or a first-party source; nothing is invented. |
| work-report | `/work-report` | Generates a manager-facing daily/weekly work report from your GitHub PRs/commits, Jira activity, and Confluence pages, via a self-correcting write→review loop. |

## Prerequisites

Both skills depend on tools that each teammate must set up in **their own** environment:

1. **Atlassian MCP server** — connected and authenticated to the `yipitdata5` site
   (each person logs in with their own account).
2. **`gh` CLI** — installed and authenticated (`gh auth login`) for pulling GitHub code / PRs.

The `yipitdata5` Atlassian `cloudId` baked into `work-report` is a shared, non-secret
site identifier — no per-user editing required.

## Updating

Maintainers: edit the skill files under `plugins/feeds-qa-tools/skills/`, bump `version`
in `plugins/feeds-qa-tools/.claude-plugin/plugin.json`, and push. Teammates pull updates with:

```
/plugin marketplace update team-claude-skills
```

## Layout

```
.claude-plugin/marketplace.json      # marketplace manifest (lists plugins)
plugins/feeds-qa-tools/
  .claude-plugin/plugin.json         # plugin manifest
  skills/
    write-kt-doc/{SKILL.md,SOP.md,prompts/}
    work-report/{SKILL.md,scripts/,prompts/}
```

> Note: runtime run artifacts (each skill's `.runs/` scratch dir) are intentionally **not**
> committed — they hold per-run drafts and links, not part of the skill.
