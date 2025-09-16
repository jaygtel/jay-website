#!/usr/bin/env bash
# Sync GitHub labels to a tidy, professional set.
# - Loads current labels once.
# - Renames or merges legacy names to canonical ones (preserve history).
# - Creates any missing canonical labels; aligns color + description on existing.
# - Relabels issues/PRs/discussions during merges.
# - Lists "artifact" labels not in the catalog (optional delete).
#
# Use [--dry-run | -n] [--force | -f] [--delete-unknown]

set -euo pipefail

# ------------------------------------------------------------------------------
# Pre-flight checks (kept explicit so that I can remember what happened).
# ------------------------------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
need gh
need jq

# ------------------------------------------------------------------------------
# Flags you can flip at runtime:
#   --dry-run | -n      -> runs script and shows result, but wont make changes
#   --delete-unknown    -> runs script and makes changes + deletes left overs
#   --force | -f        -> runs scrript and forces changes
# Flags can be used together for example:
#   ./lable-sync.sh -dry-run --delete-unknown --force
# ------------------------------------------------------------------------------
: "${DRY_RUN:=}"
: "${DELETE_UNKNOWN:=}"

# ---- CLI flags ---------------------------------------------------------------
CREATE_FORCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-f)          CREATE_FORCE="--force" ;;
    --dry|--dry-run|-n)  DRY_RUN="1" ;;
    --delete-unknown)    DELETE_UNKNOWN="1" ;;
    -h|--help)
      echo "Usage: $0 [--force|-f] [--dry-run|-n] [--delete-unknown]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 2
      ;;
  esac
  shift
done

# Log helper: print the command instead of running it when --dry-run is used
do_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY: $*"
  else
    eval "$@"
  fi
}

echo "→ Checking GitHub auth/context…"
do_cmd "gh auth status >/dev/null 2>&1 || gh auth login"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "────────────────────────────────────────────────────────────────────"
  echo " DRY RUN — no changes will be made (read-only gh list commands may run)"
  echo "────────────────────────────────────────────────────────────────────"
fi

# ------------------------------------------------------------------------------
# Canonical label catalog (list of everything that SHOULD exist).
# Colors stick to simple families:
#   type = blues, area = purple, priority = red/yellow/green, status = gray,
#   community/quality = greens/purples.
# ------------------------------------------------------------------------------
CATALOG=$(
cat <<'JSON'
[
  { "name": "type:bug",        "color": "d73a4a", "desc": "A defect that breaks expected behavior." },
  { "name": "type:feature",    "color": "a2eeef", "desc": "New user-facing capability or improvement." },
  { "name": "type:docs",       "color": "0366d6", "desc": "Documentation changes: guides, READMEs, comments." },
  { "name": "type:chore",      "color": "cccccc", "desc": "Maintenance/infra: refactors, deps, config, housekeeping." },
  { "name": "type:question",   "color": "d4c5f9", "desc": "Needs clarification or a decision." },
  { "name": "type:release",    "color": "bfdadc", "desc": "Release/versioning prep and tasks." },

  { "name": "pri:high",        "color": "b60205", "desc": "Urgent: blocks release or critical path." },
  { "name": "pri:medium",      "color": "fbca04", "desc": "Important: should be scheduled soon." },
  { "name": "pri:low",         "color": "0e8a16", "desc": "Nice-to-have: when time permits." },

  { "name": "area:html",       "color": "7057ff", "desc": "Semantic HTML, landmarks, headings, DOM." },
  { "name": "area:scss",       "color": "7057ff", "desc": "Styling/SCSS, tokens, layout, components." },
  { "name": "area:js",         "color": "7057ff", "desc": "JavaScript modules, progressive enhancement." },
  { "name": "area:templating", "color": "7057ff", "desc": "Handlebars templates, layouts, partials." },
  { "name": "area:data",       "color": "7057ff", "desc": "Content data files (e.g., src/data/site.json)." },
  { "name": "area:forms",      "color": "7057ff", "desc": "Forms, validation, ARIA live regions." },
  { "name": "area:seo",        "color": "7057ff", "desc": "Meta tags, canonical, social cards, sitemaps." },
  { "name": "area:images",     "color": "7057ff", "desc": "Images/icons, dimensions, lazyload, assets." },
  { "name": "area:design",     "color": "7057ff", "desc": "Visual design, layout system, typography." },
  { "name": "area:build",      "color": "7057ff", "desc": "Build scripts, tooling, bundling." },
  { "name": "area:ci",         "color": "7057ff", "desc": "CI workflows, Pages deployment, checks." },
  { "name": "area:infra",      "color": "7057ff", "desc": "Repo config, automations, policies." },

  { "name": "a11y",            "color": "0e8a16", "desc": "Accessibility: WCAG, focus, keyboard, screen readers." },
  { "name": "perf",            "color": "1f883d", "desc": "Performance: CLS, LCP, bundle size, image budgets." },
  { "name": "help wanted",     "color": "0e8a16", "desc": "Open to external contributors; assistance appreciated." },
  { "name": "good first issue","color": "7057ff", "desc": "Starter-friendly task with clear scope/steps." },

  { "name": "status:declined",     "color": "cccccc", "desc": "Considered but not pursued." },
  { "name": "status:duplicate",    "color": "cccccc", "desc": "Duplicate of another tracked item." },
  { "name": "status:invalid",      "color": "cccccc", "desc": "Not reproducible, not applicable, or incorrect." },
  { "name": "status:blocked",      "color": "cccccc", "desc": "Blocked by dependency or awaiting prerequisite." },
  { "name": "status:needs review", "color": "cccccc", "desc": "Awaiting code/content review." },
  { "name": "status:needs design", "color": "cccccc", "desc": "Requires design input before proceeding." },
  { "name": "status:needs testing","color": "cccccc", "desc": "Awaiting manual test/verification." }
]
JSON
)

# ------------------------------------------------------------------------------
# Legacy → canonical map. (List of everything that DOES exisst)
# If NEW already exists -> merge OLD into NEW (relabel items, then delete OLD).
# If NEW doesn't exist -> rename OLD → NEW (preserves history in one shot).
# ------------------------------------------------------------------------------
LEGACY_MAP=$(
cat <<'JSON'
[
  { "old": "bug",           "new": "type:bug" },
  { "old": "enhancement",   "new": "type:feature" },
  { "old": "docs",          "new": "type:docs" },
  { "old": "documentation", "new": "type:docs" },
  { "old": "question",      "new": "type:question" },
  { "old": "release",       "new": "type:release" },

  { "old": "wontfix",       "new": "status:declined" },
  { "old": "duplicate",     "new": "status:duplicate" },
  { "old": "invalid",       "new": "status:invalid" },

  { "old": "html",          "new": "area:html" },
  { "old": "scss",          "new": "area:scss" },
  { "old": "js",            "new": "area:js" },
  { "old": "templating",    "new": "area:templating" },
  { "old": "data",          "new": "area:data" },
  { "old": "forms",         "new": "area:forms" },
  { "old": "seo",           "new": "area:seo" },
  { "old": "images",        "new": "area:images" },
  { "old": "design",        "new": "area:design" },
  { "old": "build",         "new": "area:build" },
  { "old": "ci",            "new": "area:ci" },
  { "old": "infra",         "new": "area:infra" },
  { "old": "dev",           "new": "area:infra" },

  { "old": "ux",            "new": "area:design" },
  { "old": "qa",            "new": "status:needs testing" }
]
JSON
)

# ------------------------------------------------------------------------------
# Snapshot the labels I have now (I reuse this to keep jq simple/readable).
# ------------------------------------------------------------------------------
EXISTING="$(gh label list --json name,color,description)"
printf "→ Found %s existing labels.\n" "$(jq 'length' <<<"$EXISTING")"

# ------------------------------------------------------------------------------
# Helpers that read from the snapshots / catalog.
# ------------------------------------------------------------------------------
# why: check if a label with this exact name exists in the current snapshot
has_label() {
  local want="$1"
  jq -e --arg want "$want" '
    .[] | select(.name == $want) | .name
  ' <<<"$EXISTING" >/dev/null 2>&1
}

# why: get color|desc for a canonical label from our catalog
catalog_info_for() {
  local name="$1"
  jq -r --arg name "$name" '
    .[] | select(.name == $name) | "\(.color)|\(.desc)"
  ' <<<"$CATALOG"
}

# why: ensure a label exists with canonical color/description (create or edit)
upsert_label() {
  local name="$1" color="$2" desc="$3"
  if has_label "$name"; then
    do_cmd "gh label edit \"$name\" --color $color --description \"$desc\""
  else
    do_cmd "gh label create \"$name\" --color $color --description \"$desc\" ${CREATE_FORCE:+$CREATE_FORCE}"
  fi
}

# why: move all items from OLD → NEW so history shows the canonical name everywhere
merge_label_into() {
  local old="$1" new="$2"

  # Issues
  for n in $(gh issue list --label "$old" --state all --limit 1000 --json number -q '.[].number'); do
    do_cmd "gh issue edit $n --add-label \"$new\" --remove-label \"$old\""
  done

  # Pull Requests
  for n in $(gh pr list --label "$old" --state all --limit 1000 --json number -q '.[].number'); do
    do_cmd "gh pr edit $n --add-label \"$new\" --remove-label \"$old\""
  done

  # Discussions (best-effort; skip quietly if not enabled)
  for n in $(gh discussion list --limit 1000 --json number,labels \
             -q ".[] | select([.labels[].name] | index(\"$old\")) | .number" 2>/dev/null || true); do
    do_cmd "gh discussion edit $n --add-label \"$new\" --remove-label \"$old\""
  done

  # After relabeling, remove the old label if it still exists
  if has_label "$old"; then
    do_cmd "gh label delete \"$old\" --yes"
  fi
}

# why: prefer rename (fast, preserves history); if target already exists, merge instead
rename_or_merge() {
  local old="$1" new="$2" color="$3" desc="$4"

  if has_label "$old"; then
    if has_label "$new"; then
      printf "   - Merging '%s' → '%s'…\n" "$old" "$new"
      merge_label_into "$old" "$new"
      do_cmd "gh label edit \"$new\" --color $color --description \"$desc\""
    else
      printf "   - Renaming '%s' → '%s'…\n" "$old" "$new"
      do_cmd "gh label edit \"$old\" --name \"$new\" --color $color --description \"$desc\""
    fi
    # name set changed → refresh snapshot so has_label() stays accurate
    EXISTING="$(gh label list --json name,color,description)"
  fi
}

# ------------------------------------------------------------------------------
# 1) Normalize legacy names to their canonical counterparts.
# ------------------------------------------------------------------------------
echo "→ Normalizing legacy → canonical names…"
while read -r old; do
  [[ -z "$old" ]] && continue

  # find the desired new name
  new="$(jq -r --arg old "$old" '.[] | select(.old == $old) | .new' <<<"$LEGACY_MAP")"
  # look up canonical color/description (fallback to neutral if not listed)
  entry="$(catalog_info_for "$new" || true)"
  color="${entry%%|*}"; desc="${entry#*|}"
  if [[ -z "$color" || -z "$desc" || "$entry" == "$new" ]]; then
    color="cccccc"
    desc="Standardized label."
  fi

  # do the rename (or merge if target already exists)
  rename_or_merge "$old" "$new" "$color" "$desc"

done <<<"$(jq -r '.[].old' <<<"$LEGACY_MAP")"

# ------------------------------------------------------------------------------
# 2) Ensure every canonical label exists and matches color/description.
# ------------------------------------------------------------------------------
echo "→ Ensuring canonical labels exist with correct colors/descriptions…"
while read -r name; do
  [[ -z "$name" ]] && continue
  info="$(catalog_info_for "$name")"
  color="${info%%|*}"; desc="${info#*|}"
  upsert_label "$name" "$color" "$desc"
done <<<"$(jq -r '.[].name' <<<"$CATALOG")"

# ------------------------------------------------------------------------------
# 3) Identify any artifact labels (neither in catalog nor legacy-old list).
# ------------------------------------------------------------------------------
EXISTING_AFTER="$(gh label list --json name,color,description)"

ARTIFACTS="$(
  jq -r \
    --argjson cat "$CATALOG" \
    --argjson legacy "$LEGACY_MAP" \
    '
    # take all current names
    [ .[].name ] as $now
    |
    # canonical names (target state)
    [ $cat[].name ] as $canon
    |
    # legacy OLD names (I expect these to be gone after rename/merge)
    [ $legacy[].old ] as $olds
    |
    # artifacts = now - canonical - legacy_olds
    ($now - $canon - $olds) | unique[]?
    ' <<<"$EXISTING_AFTER"
)"

if [[ -n "${ARTIFACTS:-}" ]]; then
  echo "→ Artifact labels (not in catalog or legacy map):"
  while read -r a; do
    [[ -z "$a" ]] && continue
    echo "   - $a"
  done <<<"$ARTIFACTS"
else
  echo "→ No artifact labels detected."
fi

# ------------------------------------------------------------------------------
# 4) Optionally delete unknown artifacts (opt-in).
# ------------------------------------------------------------------------------
if [[ -n "${ARTIFACTS:-}" && "$DELETE_UNKNOWN" == "1" ]]; then
  echo "→ Deleting unknown artifact labels (requested)…"
  while read -r a; do
    [[ -z "$a" ]] && continue
    do_cmd "gh label delete \"$a\" --yes"
  done <<<"$ARTIFACTS"
elif [[ -n "${ARTIFACTS:-}" ]]; then
  echo "→ Skipping deletion of unknown artifacts (set DELETE_UNKNOWN=1 to remove them)."
fi

echo "✅ Label sync complete."
