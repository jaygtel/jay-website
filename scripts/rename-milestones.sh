#!/usr/bin/env bash
# rename-milestones.sh
# Normalize milestone titles:
#   - EXACT "^M[0-9]+$"  -> leave alone
#   - "M# <sep> rest"    -> rename to "M#" and move "rest" into description Focus
#   - other titles       -> assign next free M# and put old title into Focus
# Snapshot -> plan -> preview -> --apply uses the plan (no refetch)
# Requires: gh, jq. Works on macOS (Bash 3.2) and Linux.

set -Eeuo pipefail

# ----------------------------- flags ------------------------------------------
REPO=""
STATE="all"        # open|closed|all (GET list endpoint permits "all")
APPLY=0
QUIET=0
DEBUG=0
SPINNER=1

TMPFILES=""

# ----------------------------- utils ------------------------------------------
die() { printf "Error: %s\n" "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

mktemp_track() { f="$(mktemp)"; TMPFILES="$TMPFILES $f"; printf "%s" "$f"; }
cleanup() { [ -n "$TMPFILES" ] && rm -f $TMPFILES 2>/dev/null || true; }
trap cleanup EXIT

# Colors (TTY only)
if [[ -t 1 ]]; then
  BOLD=$(tput bold); DIM=$(tput dim); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1); RESET=$(tput sgr0)
else
  BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

ts()   { date +"%H:%M:%S"; }
log()  { (( QUIET )) || printf "%s %s%s%s %s\n" "$(ts)" "$DIM" ">" "$RESET" "$*"; }
ok()   { (( QUIET )) || printf "%s %s%s%s %s\n" "$(ts)" "$GREEN" "✓" "$RESET" "$*"; }
warn() { (( QUIET )) || printf "%s %s%s%s %s\n" "$(ts)" "$YELLOW" "!" "$RESET" "$*"; }

# Spinner (ASCII)
start_spinner() {
  (( SPINNER )) || return 0
  local pid="$1" msg="$2" frames='|/-\' i=0
  (( QUIET )) && wait "$pid" && return 0
  printf "%s %s" "$(ts)" "$msg"
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\r%s %s %s" "$(ts)" "$msg" "${frames:i:1}"
    sleep 0.1
  done
  printf "\r"
}

usage() {
  cat <<EOF
Usage: $0 [--apply] [-R|--repo owner/repo] [--only-open|--only-closed] [--quiet] [--debug] [--no-spinner]

Dry-run by default (lists milestones, shows preview, makes NO changes).

Examples:
  $0
  $0 -R yourname/yourrepo
  $0 --apply
  $0 --apply --only-open
EOF
}

# ----------------------------- args -------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -R|--repo)      REPO="$2"; shift 2 ;;
    --apply)        APPLY=1; shift ;;
    --only-open)    STATE="open"; shift ;;
    --only-closed)  STATE="closed"; shift ;;
    --quiet)        QUIET=1; shift ;;
    --debug)        DEBUG=1; shift ;;
    --no-spinner)   SPINNER=0; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "Unknown argument: $1" ;;
  esac
done

(( DEBUG )) && set -x

# ----------------------------- preflight --------------------------------------
need gh; need jq
gh auth status >/dev/null 2>&1 || die "You must 'gh auth login' first."

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  [[ -n "$REPO" ]] || die "Could not determine repo. Use -R owner/repo."
fi

log "Repo: ${BOLD}${REPO}${RESET}"
log "Mode: $([[ $APPLY -eq 1 ]] && echo "${BOLD}APPLY${RESET}" || echo "${BOLD}DRY-RUN${RESET}")"
log "Scope: state=${STATE}"
echo

# ----------------------------- fetch (snapshot) --------------------------------
log "Fetching milestones (per_page=100)..."
MILES_JSON="$(mktemp_track)"; : > "$MILES_JSON"
PAGE=1; TOTAL=0

while :; do
  POUT="$(mktemp_track)"; PERR="$(mktemp_track)"
  (
    gh api --method GET -H "Accept: application/vnd.github+json" \
      "/repos/$REPO/milestones?state=$STATE&per_page=100&page=$PAGE"
  ) >"$POUT" 2>"$PERR" &
  PID=$!
  start_spinner "$PID" "Fetching page $PAGE..."
  if ! wait "$PID"; then
    echo; cat "$PERR" >&2; die "Failed to fetch page $PAGE"
  fi
  echo

  COUNT=$(jq 'length' <"$POUT")
  log "Page $PAGE: $COUNT item(s)"
  (( COUNT == 0 )) && break

  if (( TOTAL == 0 )); then
    cat "$POUT" > "$MILES_JSON"
  else
    TMP_JOIN="$(mktemp_track)"
    jq -s 'add' "$MILES_JSON" "$POUT" > "$TMP_JOIN"
    mv "$TMP_JOIN" "$MILES_JSON"
  fi

  TOTAL=$(( TOTAL + COUNT ))
  (( COUNT < 100 )) && break
  PAGE=$(( PAGE + 1 ))
done

if (( TOTAL == 0 )); then
  warn "No milestones found."
  exit 0
fi
ok "Fetched $TOTAL milestone(s)."

# ----------------------------- list all milestones -----------------------------
printf "\n%s\n" "${BOLD}All milestones (snapshot):${RESET}"
printf "%-6s | %-8s | %-40s | %s\n" "Number" "State" "Title" "Due"
printf -- "---------------------------------------------------------------------------------------------\n"
jq -r '.[] | [.number, .state, .title, (.due_on // "—")] | @tsv' <"$MILES_JSON" |
while IFS=$'\t' read -r num state title due; do
  printf "%-6s | %-8s | %-40s | %s\n" "$num" "$state" "${title:0:40}" "$due"
done
echo

# ----------------------------- compute taken M# --------------------------------
TAKEN="$(mktemp_track)"; : > "$TAKEN"
jq -r '
  .[] | (.title // "") as $t
  | $t | gsub("[\u2014\u2013]"; "-")
  | capture("^M(?<n>[0-9]+)")? | .n?
' <"$MILES_JSON" | sed '/^$/d' | sort -n | uniq > "$TAKEN"

is_taken() { grep -qx "$1" "$TAKEN"; }
reserve()  { echo "$1" >> "$TAKEN"; sort -n "$TAKEN" -o "$TAKEN"; }
next_free() { local i=0; while is_taken "$i"; do i=$((i+1)); done; echo "$i"; }

# ----------------------------- build changes list ------------------------------
# EXACT ^M[0-9]+$ -> skip
# "M# <sep> rest" -> keep M#, focus=rest
# other           -> next free M#, focus=old title
CHANGES="$(mktemp_track)"; : > "$CHANGES"

jq -r '
  def norm: gsub("[\u2014\u2013]"; "-");
  .[] | {
    number: .number,
    title:  (.title // ""),
    desc:   (.description // ""),
    normt:  ((.title // "") | norm)
  }' <"$MILES_JSON" | jq -c '.' | while read -r row; do
  num=$(jq -r '.number' <<<"$row")
  title=$(jq -r '.title'  <<<"$row")
  desc=$(jq -r '.desc'    <<<"$row")
  normt=$(jq -r '.normt'  <<<"$row")

  if [[ "$normt" =~ ^M[0-9]+$ ]]; then
    continue
  elif [[ "$normt" =~ ^M([0-9]+)[[:space:]]*[-:]+[[:space:]]+(.+)$ ]]; then
    short="M${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
    rest="$(printf "%s" "$rest" | sed -E 's/^[-: ]+[[:space:]]*//')"
    reserve "${BASH_REMATCH[1]}" || true
    # one-line JSON
    jq -nc --argjson number "$num" \
           --arg old_title "$title" \
           --arg kind "with_rest" \
           --arg new_short "$short" \
           --arg focus "$rest" \
           --arg existing_desc "$desc" \
           '{number:$number, old_title:$old_title, kind:$kind, new_short:$new_short, focus:$focus, existing_desc:$existing_desc}' \
      >> "$CHANGES"
  else
    free="$(next_free)"; reserve "$free"
    short="M${free}"
    jq -nc --argjson number "$num" \
           --arg old_title "$title" \
           --arg kind "other" \
           --arg new_short "$short" \
           --arg focus "$title" \
           --arg existing_desc "$desc" \
           '{number:$number, old_title:$old_title, kind:$kind, new_short:$new_short, focus:$focus, existing_desc:$existing_desc}' \
      >> "$CHANGES"
  fi
done

COUNT_CHANGES="$(jq -s 'length' "$CHANGES")"
if [[ "$COUNT_CHANGES" -eq 0 ]]; then
  ok "Nothing to change (all titles are exact M#)."
  exit 0
fi
ok "Planned $COUNT_CHANGES change(s)."

# ----------------------------- preview changes --------------------------------
printf "\n%s\n" "${BOLD}Planned changes:${RESET}"
printf "%-8s | %-40s | %-6s | %s\n" "Number" "Old Title" "->New" "Focus"
printf -- "---------------------------------------------------------------------------------------------\n"
jq -r '[.number, .old_title, .new_short, .focus] | @tsv' <"$CHANGES" |
while IFS=$'\t' read -r num old new_short focus; do
  printf "%-8s | %-40s | %-6s | %s\n" "$num" "${old:0:40}" "$new_short" "$focus"
done
echo

# ----------------------------- apply? -----------------------------------------
if [[ $APPLY -eq 0 ]]; then
  warn "Dry-run only. Re-run with --apply to make these changes."
  exit 0
fi

log "Applying updates..."
UPDATED=0; FAILED=0

# Apply using the CHANGES list (compact JSON per line)
while IFS= read -r jline; do
  num=$(jq -r '.number' <<<"$jline")
  new_short=$(jq -r '.new_short' <<<"$jline")
  focus=$(jq -r '.focus' <<<"$jline")
  details=$(jq -r '.existing_desc' <<<"$jline")

  # Build description (raw string)
  DESC=$(jq -nr --arg focus "$focus" --arg details "$details" '
    def t: gsub("^(\\s+)|(\\s+)$";"");
    ( (if ($focus|length)>0 then "## Focus\n"+$focus+"\n\n" else "" end)
      + (if (($details|t|length)>0) then "## Details\n"+($details|t)+"\n" else "" end)
    )
  ')

  printf "%s Updating #%s -> \"%s\"..." "$(ts)" "$num" "$new_short"
  (
    jq -nc --arg title "$new_short" --arg description "$DESC" \
      '{title:$title, description:$description}' \
    | gh api --method PATCH \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/json" \
        "/repos/$REPO/milestones/$num" \
        --input -
  ) >/dev/null 2>&1 &
  PID=$!
  start_spinner "$PID" "Updating #$num"
  if wait "$PID"; then
    printf "\r"; ok "Updated #$num -> $new_short"
    UPDATED=$((UPDATED+1))
  else
    printf "\r"; warn "Update failed for #$num"
    FAILED=$((FAILED+1))
  fi
done < "$CHANGES"

printf "\n"
ok "Done. Updated: $UPDATED, Failed: $FAILED"
