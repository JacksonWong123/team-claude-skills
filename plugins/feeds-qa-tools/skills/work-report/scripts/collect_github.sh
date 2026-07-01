#!/usr/bin/env bash
# Collect the GitHub activity (PRs + commits) authored by the user within a
# daily or weekly window, for the /work-report skill.
#
# Usage: collect_github.sh [daily|weekly]
#
# Output:
#   - line 1: machine-readable WINDOW header (start/end dates for JQL/CQL reuse)
#   - then:   clean markdown of PRs and commits, grouped by repo
#
# Deterministic on purpose: date math + gh JSON parsing live here so the skill
# does not have to redo them ad-hoc each run.

set -euo pipefail

MODE="${1:-daily}"
TZNAME="Asia/Chongqing"
AUTHOR="JacksonWong123"
OWNER="agent8"
OFFSET="+08:00"   # Asia/Chongqing is fixed UTC+8, no DST

case "$MODE" in
  daily|weekly) ;;
  *) echo "ERROR: mode must be 'daily' or 'weekly' (got '$MODE')" >&2; exit 2 ;;
esac

# --- compute window (local time) -------------------------------------------
today=$(TZ="$TZNAME" date +%Y-%m-%d)
if [ "$MODE" = "daily" ]; then
  start_date="$today"
else
  # weekly: back up to Monday of the current week (%u: 1=Mon .. 7=Sun)
  dow=$(TZ="$TZNAME" date +%u)
  days_back=$(( dow - 1 ))
  start_date=$(TZ="$TZNAME" date -v-"${days_back}"d +%Y-%m-%d)
fi
end_date="$today"

start_iso="${start_date}T00:00:00${OFFSET}"
end_iso=$(TZ="$TZNAME" date +%Y-%m-%dT%H:%M:%S)"${OFFSET}"

echo "WINDOW mode=${MODE} start=${start_date} end=${end_date} start_iso=${start_iso} end_iso=${end_iso} tz=${TZNAME}"
echo ""

range="${start_iso}..${end_iso}"

# --- Pull Requests ----------------------------------------------------------
# We enrich each PR with its base/head branch (via `gh pr view`, since
# `gh search prs` does not expose refs) and tag it SHIP vs test:
#   - base branch in PROD_BRANCHES  -> real shipped code change (production)
#   - any other base (release/staging/test/feature) -> test-supporting merge
# The head branch often embeds a Jira key (e.g. py3-12-spendhound_SHFEEDS-1537_qa),
# which the synthesis step uses to link the PR to the issue (and its sub-issues).
echo "## GitHub Pull Requests (author=${AUTHOR}, org=${OWNER})"
echo ""
gh search prs --author="$AUTHOR" --owner="$OWNER" --created="$range" \
  --json repository,title,url,state,createdAt,number --limit 50 2>/dev/null \
  | python3 -c '
import sys, json, subprocess

# Production branches: merging here = a real code change / ship.
# Everything else (…-release / release / feature / qa branches) = test merge.
PROD_BRANCHES = {"production", "py3-12-spendhound"}

data = json.load(sys.stdin)
if not data:
    print("无")
else:
    by_repo = {}
    for p in data:
        by_repo.setdefault(p["repository"]["name"], []).append(p)
    for repo in sorted(by_repo):
        print("- **" + repo + "**")
        for p in by_repo[repo]:
            base = head = ""
            try:
                refs = json.loads(subprocess.run(
                    ["gh", "pr", "view", p["url"],
                     "--json", "baseRefName,headRefName"],
                    capture_output=True, text=True, timeout=20).stdout or "{}")
                base = refs.get("baseRefName", "") or ""
                head = refs.get("headRefName", "") or ""
            except Exception:
                pass
            tag = p["state"]
            if p["state"] == "merged":
                tag = "SHIP→" + base if base in PROD_BRANCHES else "test→" + (base or "?")
            brinfo = ("  [" + head + " → " + base + "]") if base else ""
            print("  - [" + tag + "] " + p["title"] + " (" + p["url"] + ")" + brinfo)
' || echo "无 (gh PR 查询失败)"
echo ""

# --- Commits ----------------------------------------------------------------
echo "## GitHub Commits (author=${AUTHOR}, org=${OWNER})"
echo ""
gh search commits --author="$AUTHOR" --owner="$OWNER" --author-date="$range" \
  --json repository,commit,url --limit 50 2>/dev/null \
  | python3 -c '
import sys, json
data = json.load(sys.stdin)
if not data:
    print("无")
else:
    by_repo = {}
    for c in data:
        by_repo.setdefault(c["repository"]["name"], []).append(c)
    for repo in sorted(by_repo):
        print("- **" + repo + "**")
        for c in by_repo[repo]:
            msg = c["commit"]["message"].splitlines()[0]
            print("  - " + msg + " (" + c["url"] + ")")
' || echo "无 (gh commit 查询失败)"
