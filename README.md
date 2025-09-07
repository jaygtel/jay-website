# Jay Telford – Personal Website

Modern, accessible, mobile-first personal website built with HTML, SCSS, JavaScript (ES modules), and Handlebars templates.  
Deployed automatically to GitHub Pages via GitHub Actions.

---

## 🚀 Features

- Semantic HTML5 structure with WCAG 2.2 AA accessibility
- Mobile-first SCSS using 7-1 architecture
- Handlebars templates with partials and centralized data (`src/data/site.json`)
- Progressive enhancement: works without JavaScript
- Automated build pipeline with Sass, PostCSS (autoprefixer + cssnano)
- CI/CD to GitHub Pages (`main` branch deploys)

---

## 📦 Project Setup

### Requirements
- Node.js 20+
- npm 10+

### Installation
```bash
git clone https://github.com/jaygtel/jay-website.git
cd jay-website
npm install
````

### Development

```bash
npm run dev
```

This builds the site and serves `dist/` with live reload.

### Build

```bash
npm run build
```

Outputs production-ready static files to `dist/`.

---

## 🐛 Issues

Found a bug? Please open an issue here:
👉 [Report Issues](https://github.com/jaygtel/jay-website/issues)

---

## 👤 Author

**Jay Telford**
📧 [hello@jaytelford.me](mailto:hello@jaytelford.me)
🌐 [GitHub](https://github.com/jaygtel)

---

## 📄 License

MIT © Jay Telford

