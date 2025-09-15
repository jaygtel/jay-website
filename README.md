# Jay Website

A modern, mobile-first, personal website built with semantic HTML and SCSS (7-1 architecture), ES module JavaScript, and Handlebars templates. Accessible, lightweight, and deployed via GitHub Pages with a clear, repeatable build pipeline.

**THIS PROJECT WAS RESET AND RESTARTED**

---

## 📖 Project Overview

This project follows a simple but strict separation:

- **`src/`** → All editable source files (templates, SCSS, JS, assets, data).  
- **`dist/`** → Compiled output (ready for deployment). Never committed to git.  

### Key Goals
- WCAG AA accessibility (high contrast, visible focus, keyboard navigation, reduced-motion safe).  
- Semantic HTML5 landmarks and correct heading hierarchy.  
- Mobile-first CSS with progressive enhancement for larger viewports.  
- Centralised content in `src/data/site.json`.  
- GitHub Actions for CI/CD (deploy to Pages on push to `main`).

## ➕ Suggestions

We welcome suggstions and ideas to help us plan out future development phases.  To make one visit our discussions category:

[➕ Suggest an idea](https://github.com/jaygtel/jay-website/discussions/new?category=ideas)

---

## 🚀 Getting Started

### Prerequisites
- [Node.js](https://nodejs.org/) (v20 recommended)  
- [GitHub CLI](https://cli.github.com/) if you want to use the automation scripts

### Install
```bash
git clone https://github.com/<your-username>/jay-website.git
cd jay-website
npm install
````

> Note: `npm install` auto-activates local Git hooks that prevent commits/pushes directly to `main`.

### Local environment (`.env.local`)

For local builds, create a `.env.local` file in the repo root:

```ini
# Controls the base path used by templates during local dev.
# Leave empty for local development.
SITE_BASE=
```

### Development

```bash
npm run dev
```

Builds the site into `dist/` and serves it locally with live reload.

### Build

```bash
npm run build
```

Cleans and rebuilds all assets into `dist/`.

---

## 🧩 Project Structure

```
jay-website/
├── src/             # Editable source
│   ├── templates/   # Handlebars layouts, pages, partials, sections
│   ├── scss/        # SCSS 7–1 architecture
│   ├── js/          # ES modules (progressive enhancement)
│   ├── assets/      # Images, icons, fonts
│   └── data/        # Centralised content (site.json)
├── dist/            # Build output (ignored in git)
├── tools/           # Build scripts (e.g. build.mjs)
├── scripts/         # Local automation helpers (see below)
├── .githooks/       # Repo-managed Git hooks (auto-enabled on install)
├── .github/         # Workflows, issue templates
├── package.json
└── README.md
```

---

## ✅ Deployment

GitHub Actions handles deployment:

* On push to `main`, build runs and outputs to `dist/`.
* Uses `actions/upload-pages-artifact` and `actions/deploy-pages`.
* Pages is served at `https://<username>.github.io/<repo>/`.

Checklist:

* [x] `dist/` in `.gitignore`
* [x] CI/CD workflow configured
* [x] `.nojekyll` added automatically in `dist/`
* [x] Custom `404.html` for broken deep links

---

## 🔀 Branching & Release Model (Ephemeral)

We’ve moved from a permanent `dev` branch to **short-lived release branches**.

* **`main`** is the default and deployment branch (GitHub Pages).
* **PR-only:** all changes land in `main` via Pull Requests (no direct pushes).
* **Ephemeral branches:** create `release/<name>` from `main`, open a PR to `main`, merge, and let GitHub auto-delete the branch.
* **Signed commits required** (PRs must show as “Verified”).
* **Local safety:** repo-managed Git hooks in `.githooks/` block commits/pushes to `main`. They auto-activate on `npm install`.

**Typical release flow**

```bash
git checkout main && git pull
git switch -c release/<name>       # e.g., release/M1 or release/2025-09-14
# ...make changes, commits...
git push -u origin HEAD
gh pr create --base main --head release/<name> \
  --title "Release: <name>" \
  --body "Short-lived release branch"
gh pr merge --merge                 # merge commit; branch auto-deletes on merge
```

---

## 🔧 Project Automation Scripts

To keep the project tracker and issues organised, this repo includes a couple of helper scripts in `scripts/`.
They use the [GitHub CLI](https://cli.github.com/) (`gh`) — make sure you’ve installed it and run `gh auth login` first.

### `scripts/setup-tracker.sh`

Creates the full milestone + issue structure for this project.

* Checks if each milestone/issue already exists — safe to run multiple times.
* Creates any missing labels automatically (e.g., `a11y`, `perf`, `docs`).
* Seeds starter issues under each milestone.
* Has a `DRY_RUN=1` mode to preview without making changes.

**Examples:**

```bash
# Preview everything it *would* create
DRY_RUN=1 ./scripts/setup-tracker.sh

# Actually create milestones, labels, issues
./scripts/setup-tracker.sh
```

### `scripts/assign-all-to-me.sh`

Assigns issues to yourself (`@me`).

* With **no arguments**: assigns **all open issues**.
* With `--milestone "NAME"`: assigns only issues in that milestone (repeatable).
* Has a `DRY_RUN=1` mode to preview.

**Examples:**

```bash
# Assign all open issues to me
./scripts/assign-all-to-me.sh

# Assign only issues in specific milestones
./scripts/assign-all-to-me.sh \
  --milestone "M3 — Core Pages (Semantic HTML, Mobile-First)" \
  --milestone "M4 — Accessibility (WCAG AA)"

# Dry run (no changes, just shows what it would do)
DRY_RUN=1 ./scripts/assign-all-to-me.sh
```

> These scripts are part of the workflow that makes this project repeatable and maintainable.

---

## 📝 Coding Style

* **Readable code**: clear names, comments for intent, no cryptic tricks.
* **Accessibility first**: focus states, ARIA live regions, labels.
* **Progressive enhancement**: works without JS; JS adds niceties.
* **SCSS 7-1**: variables, mixins, utilities, mobile-first media queries.
* **Handlebars**: logic in helpers, not content; partials for sections.

---

## 📌 Roadmap

See GitHub [Milestones](https://github.com/jaygtel/jay-website/milestones) for the step-by-step breakdown (M0 → M12).

---

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for the full text.
