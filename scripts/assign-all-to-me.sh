#!/usr/bin/env bash
# scripts/assign-all-to-me.sh
# Assign issues to yourself (@me).
# - No args  → assign ALL open issues.
# - --milestone "NAME" (repeatable) → assign only issues in those milestones.
# Optional: DRY_RUN=1 to preview without making changes.

set -euo pipefail

say()  { printf "\033[1m%s\033[0m\n" "$*"; }
note() { printf "  - %s\n" "$*"; }
die()  { printf "\033[31m✖ %s\033[0m\n" "$*"; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "Missing '$1'. Install it first."; }

run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY_RUN] gh $*"
  else
    gh "$@"
  fi
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [--milestone "M1 — …"] [--milestone "M2 — …"]

Examples:
  # Assign ALL open issues to me
  $(basename "$0")

  # Assign only issues in specific milestones
  $(basename "$0") --milestone "M3 — Core Pages (Semantic HTML, Mobile-First)" \\
                   --milestone "M4 — Accessibility (WCAG AA)"

Env:
  DRY_RUN=1   Preview commands without changing anything
EOF
}

# ----- Parse args -----
MILESTONES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --milestone)
      shift
      [[ $# -gt 0 ]] || { usage; die "Missing value after --milestone"; }
      MILESTONES+=("$1")
      ;;
    -h|--help)
      usage; exit 0;;
    *)
      usage; die "Unknown argument: $1";;
  esac
  shift
done

# ----- Preflight -----
need gh
gh auth status >/dev/null 2>&1 || die "Not logged in to gh. Run: gh auth login"

# ----- Collect issue numbers -----
collect_all_open() {
  gh issue list --state open --json number --jq '.[].number'
}

collect_by_milestone() {
  local m="$1"
  gh issue list --state open --milestone "$m" --json number --jq '.[].number'
}

say "Assigning issues to @me…"
ISSUES_TMP="$(mktemp)"
trap 'rm -f "$ISSUES_TMP"' EXIT

if [[ ${#MILESTONES[@]} -eq 0 ]]; then
  note "No milestones specified → selecting ALL open issues"
  collect_all_open > "$ISSUES_TMP" || true
else
  note "Filtering by milestones:"
  for m in "${MILESTONES[@]}"; do
    note "• $m"
    collect_by_milestone "$m" >> "$ISSUES_TMP" || true
  done
fi

# de-duplicate and remove empties
mapfile -t ISSUE_NUMS < <(grep -E '^[0-9]+$' "$ISSUES_TMP" | sort -u)

if [[ ${#ISSUE_NUMS[@]} -eq 0 ]]; then
  say "Nothing to assign — zero matching open issues."
  exit 0
fi

# ----- Assign -----
for num in "${ISSUE_NUMS[@]}"; do
  echo "  → assigning issue #$num"
  run issue edit "$num" --add-assignee @me
done

say "All done ✅"
