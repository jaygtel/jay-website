#!/usr/bin/env bash
# scripts/setup-tracker.sh
# Batch-create milestones + issues for the Jay Website project.
# Requires: gh CLI (authenticated), git remote set, repo initialized.
set -euo pipefail

### ---------- tiny helpers ----------
say()  { printf "\n\033[1m%s\033[0m\n" "$*"; }
note() { printf "  - %s\n" "$*"; }
warn() { printf "\033[33m! %s\033[0m\n" "$*"; }
die()  { printf "\033[31m✖ %s\033[0m\n" "$*"; exit 1; }

need() { command -v "$1" >/dev/null 2>/dev/null || die "Missing '$1'. Install it first."; }

# DRY_RUN=1 will print commands instead of running them
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY_RUN] gh $*"
  else
    gh "$@"
  fi
}

### ---------- preflight ----------
need gh
need git

# Ensure gh is authenticated
if ! gh auth status >/dev/null 2>&1; then
  die "GitHub CLI not authenticated. Run: gh auth login"
fi

# Determine owner/repo. Prefer GH_REPO env, else ask gh; fallback to parsing remote.
get_repo() {
  if [[ -n "${GH_REPO:-}" ]]; then
    echo "$GH_REPO"
    return
  fi

  if REPO_JSON="$(gh repo view --json owner,name 2>/dev/null)"; then
    # gh supports --jq internally, but I'll keep it simple here
    owner="$(echo "$REPO_JSON" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1 || true)"
    name="$(echo "$REPO_JSON" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -n1 || true)"
    if [[ -n "$owner" && -n "$name" ]]; then
      echo "${owner}/${name}"
      return
    fi
  fi

  origin="$(git config --get remote.origin.url || true)"
  [[ -z "$origin" ]] && die "No git remote 'origin' found. Set GH_REPO=owner/repo or add a remote."

  if [[ "$origin" =~ github\.com[:/]+([^/]+)/([^/.]+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    return
  fi

  die "Could not parse owner/repo from remote: $origin"
}

REPO="$(get_repo)"
export GH_REPO="$REPO"
say "Using repository: $GH_REPO"

### ---------- label utilities ----------
label_exists() {
  local name="$1"
  gh label list --limit 200 --json name --jq ".[] | select(.name==\"$name\")" 2>/dev/null | grep -q .
}

ensure_label() {
  local name="$1" color="$2" desc="$3"
  if label_exists "$name"; then
    note "Label exists: $name"
  else
    note "Creating label: $name"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "[DRY_RUN] gh label create \"$name\" --color \"$color\" --description \"$desc\""
    else
      gh label create "$name" --color "$color" --description "$desc" >/dev/null
    fi
  fi
}

ensure_labels_csv() {
  # Accepts "a,b,c"
  local csv="$1"
  IFS=',' read -r -a arr <<< "$csv"
  for raw in "${arr[@]}"; do
    name="$(echo "$raw" | xargs)" # trim
    case "$name" in
      build)      ensure_label build      "0366d6" "Build tooling & pipeline";;
      infra)      ensure_label infra      "6f42c1" "Repo/infra/config tasks";;
      dev)        ensure_label dev        "0969da" "Local dev workflow tasks";;
      templating) ensure_label templating "0e8a16" "Handlebars layouts/partials";;
      html)       ensure_label html       "1a7f37" "Semantic HTML work";;
      data)       ensure_label data       "d4c5f9" "site.json and data plumbing";;
      scss)       ensure_label scss       "fbca04" "SCSS architecture/styles";;
      a11y)       ensure_label a11y       "b60205" "Accessibility (WCAG)";;
      design)     ensure_label design     "f66a0a" "Design tokens/visual tweaks";;
      forms)      ensure_label forms      "a2eeef" "Forms & validation";;
      qa)         ensure_label qa         "ededed" "Testing & quality checks";;
      perf)       ensure_label perf       "5319e7" "Performance improvements";;
      images)     ensure_label images     "0cf478" "Images & media";;
      js)         ensure_label js         "7057ff" "JavaScript enhancements";;
      ci)         ensure_label ci         "ffab70" "CI/CD & workflows";;
      ux)         ensure_label ux         "c5def5" "Interaction & UX polish";;
      seo)        ensure_label seo        "ffd866" "SEO/meta/sitemap";;
      release)    ensure_label release    "bf8700" "Release prep & tagging";;
      docs)       ensure_label docs       "008672" "Documentation & templates";;
      *)          note "Unknown label requested: $name (skipping color map)"; ensure_label "$name" "cccccc" "Ad-hoc label";;
    esac
  done
}

### ---------- existence checks ----------
milestone_exists() {
  local title="$1"
  gh api -X GET repos/:owner/:repo/milestones --paginate \
    --jq ".[] | select(.title == \"$title\") | .number" 2>/dev/null | grep -q .
}

issue_exists_by_title() {
  local title="$1"
  gh issue list --search "in:title \"$title\"" --state open --json title \
    --jq ".[] | select(.title == \"$title\")" 2>/dev/null | grep -q .
}

### ---------- creation helpers ----------
create_milestone() {
  local title="$1" desc="$2"
  if milestone_exists "$title"; then
    note "Milestone already exists: $title"
  else
    say "Creating milestone: $title"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "[DRY_RUN] gh api -X POST repos/:owner/:repo/milestones -f title='$title' -f description='(omitted here)'"
    else
      run api -X POST repos/:owner/:repo/milestones \
        -f title="$title" \
        -f description="$desc" >/dev/null
    fi
  fi
}

create_issue() {
  local title="$1" body="$2" labels="$3" milestone="$4"
  # Make sure labels exist before creating the issue
  ensure_labels_csv "$labels"
  if issue_exists_by_title "$title"; then
    note "Issue already exists: $title"
  else
    note "Creating issue: $title"
    run issue create --title "$title" --body "$body" \
      --label "$labels" --milestone "$milestone" >/dev/null
  fi
}

### ---------- milestones ----------
say "Creating milestones…"
create_milestone "M0 — Project Baseline" \
"Verify src→dist pipeline works; .gitignore excludes dist; minimal README; dev server runs."

create_milestone "M1 — Templating & Data Plumbing" \
"Wire up site.json, base layout, partials (header, nav, footer, meta). Handle empty arrays gracefully."

create_milestone "M2 — SCSS 7–1 Architecture & Design Tokens" \
"Establish 7–1 SCSS structure, tokens (colors, spacing, type), a11y focus styles, reduced-motion support."

create_milestone "M3 — Core Pages (Semantic HTML, Mobile-First)" \
"Build Home, About, Projects, Contact with proper landmarks, h1 hierarchy, skip links. Mobile-first CSS pass."

create_milestone "M4 — Accessibility (WCAG AA)" \
"Contrast audit, focus visibility, keyboard nav, form labels, aria-live placeholders. Respect reduced-motion."

create_milestone "M5 — Performance & Assets" \
"Minify/autoprefix CSS+JS; lazy-load images with dimensions; fix layout shifts; optimize asset pipeline."

create_milestone "M6 — Forms (Progressive Enhancement)" \
"Contact form works without JS; add accessible validation via aria-live; progressive enhancement only."

create_milestone "M7 — SEO & Social Meta" \
"Reusable meta partial (<title>, desc, canonical, og:, twitter:). Robots.txt + sitemap.xml; per-page overrides."

create_milestone "M8 — CI/CD to GitHub Pages" \
"Set up GitHub Actions (upload-pages-artifact + deploy-pages). Builds only on main. Pages URL confirmed live."

create_milestone "M9 — Enhancements (Scroll-Spy & UX)" \
"IntersectionObserver scroll-spy (reduced-motion safe). Small UX polish (nav active state, etc.)."

create_milestone "M10 — Lighthouse Sweeps (90+ Targets)" \
"Run Lighthouse audits (mobile+desktop). Fix top issues to achieve ≥90 in Performance, A11y, SEO, Best Practices."

create_milestone "M11 — Docs & Maintenance Readiness" \
"Finalize README, add issue/PR templates, CHANGELOG, branch strategy notes, and design log link."

create_milestone "M12 — Release v1.0" \
"Final QA checklist. Tag v1.0.0, create Release notes, confirm Pages deployment, open roadmap for v1.1."

### ---------- issues per milestone ----------
say "Creating issues for M0 — Project Baseline…"
create_issue "Verify build pipeline (src → dist)" \
"Run \`npm run build\` and confirm dist/ contains HTML, CSS, JS. Screenshot as evidence." \
"build" "M0 — Project Baseline"

create_issue "Add dist/ to .gitignore" \
"Ensure dist/ and node_modules/ are ignored. Confirm with \`git status\`." \
"infra" "M0 — Project Baseline"

create_issue "Run dev server locally" \
"Confirm \`npm run dev\` launches live-server and renders index.html." \
"dev" "M0 — Project Baseline"

say "Creating issues for M1 — Templating & Data Plumbing…"
create_issue "Create base.hbs layout with landmarks" \
"Add <header>, <main>, <footer>. Pull in meta partial. Inject {{{body}}}." \
"templating,html" "M1 — Templating & Data Plumbing"

create_issue "Add site.json with site title, nav, footer" \
"Centralize nav + site metadata. Handle empty arrays gracefully." \
"data" "M1 — Templating & Data Plumbing"

create_issue "Build partials: head-meta, header, footer" \
"Reusable partials for meta tags, nav, and footer content." \
"templating" "M1 — Templating & Data Plumbing"

say "Creating issues for M2 — SCSS 7–1 Architecture & Design Tokens…"
create_issue "Scaffold SCSS 7–1 folders" \
"Create abstracts, base, components, layout, sections, utilities. Wire into main.scss." \
"scss" "M2 — SCSS 7–1 Architecture & Design Tokens"

create_issue "Define design tokens (colors, spacing, typography)" \
"Add variables with WCAG AA contrast checked; breakpoints + fluid type mixins." \
"scss,a11y" "M2 — SCSS 7–1 Architecture & Design Tokens"

create_issue "Implement focus + reduced-motion utilities" \
"Add :focus-visible outlines and @media (prefers-reduced-motion) guards." \
"a11y,scss" "M2 — SCSS 7–1 Architecture & Design Tokens"

say "Creating issues for M3 — Core Pages…"
create_issue "Implement Home page structure" \
"Hero (H1), featured projects loop, contact CTA. Mobile-first layout." \
"html,templating" "M3 — Core Pages (Semantic HTML, Mobile-First)"

create_issue "Build About + Projects templates" \
"About: bio + portrait. Projects: loop over project cards." \
"html" "M3 — Core Pages (Semantic HTML, Mobile-First)"

create_issue "Add skip-to-content link" \
"Visually-hidden skip link before nav. Links to #main." \
"a11y" "M3 — Core Pages (Semantic HTML, Mobile-First)"

say "Creating issues for M4 — Accessibility (WCAG AA)…"
create_issue "Contrast audit & token tweaks" \
"Run axe DevTools or Lighthouse. Adjust color tokens if contrast < 4.5:1." \
"a11y,design" "M4 — Accessibility (WCAG AA)"

create_issue "Label all form fields" \
"Ensure each input has a label; add aria-describedby where needed." \
"a11y,forms" "M4 — Accessibility (WCAG AA)"

create_issue "Keyboard navigation QA" \
"Tab through entire site. Confirm no traps, visible focus, logical order." \
"a11y,qa" "M4 — Accessibility (WCAG AA)"

say "Creating issues for M5 — Performance & Assets…"
create_issue "Enable image lazy-loading + dimensions" \
"Add width/height or aspect-ratio attributes; loading='lazy' for non-critical images." \
"perf,images" "M5 — Performance & Assets"

create_issue "Autoprefixer + cssnano pass" \
"Run postcss with autoprefixer + cssnano. Confirm CSS minimized and prefixed." \
"build,perf" "M5 — Performance & Assets"

create_issue "Defer non-critical JS" \
"Mark scripts as defer. Confirm no blocking resources in Lighthouse." \
"perf,js" "M5 — Performance & Assets"

say "Creating issues for M6 — Forms…"
create_issue "Implement static contact form (no-JS fallback)" \
"Simple POST or mailto:. Works without JavaScript." \
"forms" "M6 — Forms (Progressive Enhancement)"

create_issue "Add client-side validation with aria-live" \
"JS enhancement: show errors inline in aria-live region. Preserve native HTML validation." \
"forms,a11y,js" "M6 — Forms (Progressive Enhancement)"

say "Creating issues for M7 — SEO & Social Meta…"
create_issue "Meta partial with title/desc/canonical/og/twitter" \
"Reusable meta.hbs partial with sensible defaults. Page-specific overrides allowed." \
"seo" "M7 — SEO & Social Meta"

create_issue "Add robots.txt + sitemap.xml" \
"Static versions generated into dist/. Cover all published routes." \
"seo" "M7 — SEO & Social Meta"

say "Creating issues for M8 — CI/CD to GitHub Pages…"
create_issue "Create Pages workflow" \
"GitHub Actions: build on main, upload-pages-artifact, deploy-pages." \
"ci,infra" "M8 — CI/CD to GitHub Pages"

create_issue "Confirm Pages deployment" \
"Push main, verify site loads on https://<username>.github.io/<repo>/ ." \
"ci,qa" "M8 — CI/CD to GitHub Pages"

say "Creating issues for M9 — Enhancements…"
create_issue "IntersectionObserver scroll-spy" \
"Highlight active nav section. Respect reduced-motion." \
"js,ux" "M9 — Enhancements (Scroll-Spy & UX)"

say "Creating issues for M10 — Lighthouse Sweeps…"
create_issue "Run Lighthouse audit (mobile + desktop)" \
"Save reports in /docs/lh/. Fix top 3 issues in each category." \
"qa,perf" "M10 — Lighthouse Sweeps (90+ Targets)"

say "Creating issues for M11 — Docs & Maintenance…"
create_issue "Finalize README" \
"Update with run/build/deploy instructions, screenshots, roadmap." \
"docs" "M11 — Docs & Maintenance Readiness"

create_issue "Add issue & PR templates" \
"Create .github/ISSUE_TEMPLATE + pull_request_template.md." \
"infra,docs" "M11 — Docs & Maintenance Readiness"

create_issue "Start CHANGELOG.md" \
"Log initial versions starting at v0.1.0 → v1.0.0." \
"docs" "M11 — Docs & Maintenance Readiness"

say "Creating issues for M12 — Release v1.0…"
create_issue "Final QA checklist" \
"Run through links, forms, a11y, images, meta, build size. Document pass/fail." \
"qa,release" "M12 — Release v1.0"

create_issue "Tag and publish v1.0.0" \
"Create GitHub Release with notes. Pages URL included. Open roadmap issue for v1.1 ideas." \
"release" "M12 — Release v1.0"

say "All done ✅"
