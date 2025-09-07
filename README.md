# Jay Website

A modern, mobile-first, personal website built with semantic HTML, SCSS (7-1 architecture), ES module JavaScript, and Handlebars templates.  
Accessible, lightweight, and deployed via GitHub Pages with a clear, repeatable build pipeline.

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

---

## 🚀 Getting Started

### Prerequisites
- [Node.js](https://nodejs.org/) (v20 recommended).  
- [GitHub CLI](https://cli.github.com/) if you want to use the automation scripts.  

### Install
```bash
git clone https://github.com/<your-username>/jay-website.git
cd jay-website
npm install
````

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

---

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

---

💡 These scripts are part of the workflow that makes this project repeatable and maintainable.
They’re safe to commit to the repo, and you can re-run them anytime without breaking existing milestones or issues.

---

## 📝 Coding Style

* **Readable, hobbyist-style code**: clear names, comments for intent, no cryptic tricks.
* **Accessibility first**: focus states, ARIA live regions, labels.
* **Progressive enhancement**: works without JS, JS adds niceties.
* **SCSS 7-1**: variables, mixins, utilities, mobile-first media queries.
* **Handlebars**: logic in helpers, not content; partials for sections.

---

## 📌 Roadmap

See GitHub [Milestones](https://github.com/jaygtel/jay-website/milestones) for the step-by-step breakdown (M0 → M12).

---

## 📄 License

This project is licensed under the **MIT License**.  See the [LICENSE](LICENSE) file for the full text.