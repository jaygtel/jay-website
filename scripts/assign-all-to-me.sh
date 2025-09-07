#!/usr/bin/env bash
# scripts/assign-all-to-me.sh
# Assign all open issues in the current repo to yourself (@me).
set -euo pipefail

say() { printf "\033[1m%s\033[0m\n" "$*"; }

# sanity check
command -v gh >/dev/null 2>&1 || { echo "✖ GitHub CLI not found"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "✖ Not logged in to gh. Run: gh auth login"; exit 1; }

say "Assigning all open issues to @me…"

gh issue list --state open --json number --jq '.[].number' \
| while read -r num; do
    if [[ -n "$num" ]]; then
      echo "  → assigning issue #$num"
      gh issue edit "$num" --add-assignee @me
    fi
  done

say "All done ✅"
