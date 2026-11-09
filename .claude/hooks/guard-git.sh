#!/usr/bin/env bash
# Claude Code PreToolUse hook for the Bash tool. Blocks git commands that would
# move the shared main clone or commit on main. Exit 2 blocks the call and the
# stderr line is shown to the model as the reason.
set -uo pipefail

input=$(cat)
field() {
  printf '%s' "$input" | python3 -c '
import json, sys
d = json.load(sys.stdin)
k = sys.argv[1]
v = d.get("tool_input", {}).get("command") if k == "command" else d.get(k)
print(v or "")' "$1"
}
cmd=$(field command)
cwd=$(field cwd)
case "$cmd" in *git*) ;; *) exit 0 ;; esac

dir="$cwd"
if [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
  dir="${BASH_REMATCH[1]/#\~/$HOME}"
elif [[ "$cmd" =~ ^[[:space:]]*cd[[:space:]]+([^[:space:]\;\&\|]+) ]]; then
  dir="${BASH_REMATCH[1]/#\~/$HOME}"
fi
git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

mapfile -t gd < <(git -C "$dir" rev-parse --path-format=absolute --git-dir --git-common-dir)
git_dir="${gd[0]}"; common_dir="${gd[1]}"
repo=$(basename "$(dirname "$common_dir")")
branch=$(git -C "$dir" branch --show-current 2>/dev/null || true)

block() { printf 'guard-git: %s\n' "$1" >&2; exit 2; }
git_re='(^|[[:space:];&|])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'

if [ "$git_dir" = "$common_dir" ] && [[ "$cmd" =~ ${git_re}(checkout|switch|stash|reset|rebase)([[:space:]]|$) ]]; then
  block "$dir is the shared main clone of $repo; 'git ${BASH_REMATCH[3]}' there moves the checkout under the person using it. Use a worktree: git -C $dir fetch origin && git -C $dir worktree add -b <gitBranchName> $HOME/Workspace/$repo-worktrees/<gitBranchName> origin/main"
fi
if [ "$branch" = "main" ] && [[ "$cmd" =~ ${git_re}commit([[:space:]]|$) ]]; then
  block "refusing to commit on main in $repo. Create a worktree branch first (AGENTS.md, Git flow)."
fi
if [[ "$cmd" =~ ${git_re}push[[:space:]]+(.*[[:space:]])?(-f|--force)([[:space:]]|$) ]]; then
  block "force-push without a lease is not allowed; use --force-with-lease."
fi
exit 0
