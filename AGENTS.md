# .github

The organisation's `.github` repository. It holds the reusable Claude review
and mention workflows that `lea-app`, `lea-infra`, `lea-k8s` and
`lea-wealth-plugins` call, and the weekly `ceo-digest`, which is the
management-oversight evidence for the CHG-1 change-management control.
Nothing here runs the application. `lea-engineering-skills` carries the shared
engineering conventions.

## Hard rules

- **Repository names in workflows must match the current names.**
  `ceo-digest.yml` mints its token with an explicit `repositories:` list, and
  `scripts/digest.sh` repeats it in `REPOS`. Token minting does not follow
  GitHub's rename redirects. A stale name fails the whole run with a 422
  ("at least one repository that does not exist or is not accessible"),
  which is how the 2026-11-09 digest was lost (ENG-2335). Renaming,
  archiving or adding a production repository therefore needs a PR here in
  the same change, and both lists must stay identical.
- **The digest is control evidence.** If a scheduled run fails, fix it and run
  `gh workflow run ceo-digest -R LEA-Product-and-Engineering/.github` the same
  week; don't wait for the next Monday.
- **This repository stays public.** Public `lea-wealth-plugins` calls the
  reusable workflows, and a public caller needs a public workflow repository.
  A Vanta finding about visibility is fixed by deactivating the entity, never
  by changing visibility.
- **Third-party Actions are pinned to a full commit SHA**, with the version in
  a trailing comment (`uses: owner/repo@<sha> # vX`), never a tag. The only
  `@main` references are this repository's own reusable workflows called from
  the thin `*-caller.yml` stubs.
- **The review bot (`lea-pr-reviewer`) reviews its own workflows here.** A
  change to `claude-review.yml` is exercised by the PR that makes it; read the
  bot's run on that PR before calling the change done.
- **`~/Workspace/.github` is a shared checkout.** Work only in
  `~/Workspace/.github-worktrees/<branch>`; the hook blocks the rest.
- Pushes that touch `.github/workflows/` go over SSH; the `gh` token lacks the
  `workflow` scope.

## Git flow

Two rules above everything else: **no work without a Linear issue** and
**one issue equals one PR**. Linear status is driven by GitHub (PR opened on
the `gitBranchName` branch → In Progress, merged with `Closes ENG-<n>` → Done);
never set it by hand.

1. A feature or anything with design choices: `superpowers:brainstorming` →
   spec → `superpowers:writing-plans` → plan. A small bug or chore skips to 2.
2. `lea-engineering:lea-linear-issues` creates the issues: one sub-issue per
   PR per repository, blocked-by relations from plan ordering.
3. `lea-engineering:lea-start-issue ENG-<n>` creates the worktree at
   `~/Workspace/.github-worktrees/<gitBranchName>` from `origin/main`. Never
   `git checkout`, `switch`, `stash`, `reset` or `rebase` in
   `~/Workspace/.github` itself; `.claude/hooks/guard-git.sh` blocks it.
4. Implement in the worktree. Conventional Commits with the issue key at the
   end of the subject: `fix(review): fail the run without a verdict (ENG-2282)`.
   Scopes in use: `review`, `mention`, `digest`, `repo`. No AI attribution in
   commits or PR bodies.
5. `lea-engineering:lea-ship-issue` runs the Verification block, rebases onto
   `origin/main`, opens the PR ready for review with `Closes ENG-<n>`, and
   waits for checks and the review bot. A draft needs a stated reason (the PR
   must not merge yet). Review feedback, even on an approved PR, is pushed to
   the same PR: reply on the thread with the commit, say a fix is in flight,
   and wait for checks and the bot on the new head. Never push after the
   merge.
6. After merge: remove the worktree; the next PR branches from the new
   `origin/main`, never from the merged branch.

Full rules: https://github.com/LEA-Product-and-Engineering/lea-engineering-skills/blob/main/plugins/lea-engineering/references/conventions.md

### Git flow extras

None.

## Layout

- `.github/workflows/claude-review.yml`, `claude-mention.yml`: reusable
  workflows (`workflow_call`) that the four product repositories call. Bedrock
  access is the cicd-account role (ENG-2009).
- `.github/workflows/*-caller.yml`: thin stubs so this repository reviews
  changes to itself.
- `.github/workflows/ceo-digest.yml` + `scripts/digest.sh`: Mondays 13:00 UTC,
  merged PRs across the four repositories, bypass merges flagged, posted to
  Slack.

## Verification

Run before opening a PR. There is no lint workflow; CodeQL runs on push.

```bash
bash -n scripts/*.sh
python3 -c 'import yaml,glob; [yaml.safe_load(open(f)) for f in glob.glob(".github/workflows/*.yml")]'
grep -nE 'uses:' .github/workflows/*.yml | grep -vE '@[0-9a-f]{40}|LEA-Product-and-Engineering/\.github/'   # must print nothing
diff <(sed -n '/repositories: |/,/^$/p' .github/workflows/ceo-digest.yml | grep -oE '^\s+[a-z0-9-]+$' | tr -d ' ' | sort) \
     <(grep -oP '^REPOS=\(\K[^)]+' scripts/digest.sh | tr ' ' '\n' | sort)                                       # must print nothing
for r in $(grep -oP '^REPOS=\(\K[^)]+' scripts/digest.sh); do
  gh api "repos/LEA-Product-and-Engineering/$r" -q .name | grep -qx "$r" || echo "STALE $r"                     # must print nothing
done
command -v actionlint >/dev/null && actionlint
```

The last loop catches a rename. `gh api` follows the redirect and returns
the new name, so a mismatch means the list is stale.

## Skills

- Shared (plugin `lea-engineering`): `lea-linear-issues`, `lea-start-issue`,
  `lea-ship-issue`.
- Permission prompts: extend `.claude/settings.json` with
  `/fewer-permission-prompts`.

## Docs index

- GitHub Actions: https://docs.github.com/en/actions
- create-github-app-token: https://github.com/actions/create-github-app-token
- Claude Code: https://code.claude.com/docs/llms.txt
