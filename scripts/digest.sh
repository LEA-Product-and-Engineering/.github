#!/usr/bin/env bash
# Weekly CEO digest: merged PRs across the four production repos, their review
# outcome, and any merges without an approving review (bypass merges, which
# require a Code Changes register exception). Posts to Slack.
# Env: GH_TOKEN (read-only PAT), SLACK_WEBHOOK_URL, ORG.
set -euo pipefail

ORG="${ORG:-LEA-Product-and-Engineering}"
SINCE=$(date -u -d '7 days ago' +%F)
REPOS=(lea-app infra lea-k8s lea-wealth-plugins)

sections=""
bypass_count=0
total=0
for R in "${REPOS[@]}"; do
  prs=$(gh pr list -R "$ORG/$R" --state merged --search "merged:>=$SINCE" \
        --json number,title,url,reviewDecision --limit 100)
  n=$(jq length <<<"$prs")
  [ "$n" -eq 0 ] && continue
  total=$((total + n))
  lines=$(jq -r '.[] | "• <\(.url)|#\(.number)> \(.title)" +
    (if .reviewDecision == "APPROVED" then " — approved"
     else " — :warning: MERGED WITHOUT APPROVAL (exception required)" end)' <<<"$prs")
  bypass_count=$((bypass_count + $(jq '[.[] | select(.reviewDecision != "APPROVED")] | length' <<<"$prs")))
  sections+=$'\n'"*${R}* (${n} merged)"$'\n'"${lines}"$'\n'
done

if [ "$total" -eq 0 ]; then
  text="*Weekly change digest* (since ${SINCE}): no PRs merged."
else
  text="*Weekly change digest* (since ${SINCE}): ${total} PRs merged, ${bypass_count} without pipeline approval.${sections}"
fi

jq -n --arg text "$text" '{text: $text}' \
  | curl -sf -X POST -H 'Content-type: application/json' --data @- "$SLACK_WEBHOOK_URL"
echo "digest posted: ${total} PRs, ${bypass_count} bypass merges"
