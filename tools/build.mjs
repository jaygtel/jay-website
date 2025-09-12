// tools/build.mjs
// Minimal Handlebars build for Jay Website (src -> dist)
// - Registers partials + layouts
// - Compiles src/templates/index.hbs with data context
// - Copies JS to dist/assets/js
// - Writes .nojekyll for GitHub Pages

import fs from 'fs';
import path from 'path';
import Handlebars from 'handlebars';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SRC = path.join(__dirname, '..', 'src');
const DIST = path.join(__dirname, '..', 'dist');

// Ensure dist structure exists
fs.mkdirSync(path.join(DIST, 'assets', 'css'), { recursive: true });
fs.mkdirSync(path.join(DIST, 'assets', 'js'), { recursive: true });

// Helpers
Handlebars.registerHelper('year', () => new Date().getFullYear());
// Optional "newline" helper; handy if a partial lacks a trailing newline.
Handlebars.registerHelper('nl', () => '\n');

// Load data
const dataPath = path.join(SRC, 'data', 'site.json');
const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));

// Allow CI to override the base path for project pages, e.g. "/jays-website"
const envBase = process.env.SITE_BASE || '';
data.site = { ...data.site, base: envBase || data.site.base || '' };

// Register partials (src/templates/partials/*.hbs as {{> name}})
const partialsDir = path.join(SRC, 'templates', 'partials');
if (fs.existsSync(partialsDir)) {
  for (const file of fs.readdirSync(partialsDir)) {
    if (file.endsWith('.hbs')) {
      const name = file.slice(0, -4); // 'meta.hbs' -> 'meta'
      const content = fs.readFileSync(path.join(partialsDir, file), 'utf8');
      Handlebars.registerPartial(name, content);
    }
  }
}

// Register layouts as block partials under the "layouts/" namespace
// Use in pages as: {{#> layouts/base this}} ... {{/layouts/base}}
const layoutsDir = path.join(SRC, 'templates', 'layouts');
if (fs.existsSync(layoutsDir)) {
  for (const file of fs.readdirSync(layoutsDir)) {
    if (file.endsWith('.hbs')) {
      const name = `layouts/${file.slice(0, -4)}`; // 'base.hbs' -> 'layouts/base'
      const content = fs.readFileSync(path.join(layoutsDir, file), 'utf8');
      Handlebars.registerPartial(name, content);
    }
  }
}

// Compile the page(s)
// NOTE: "data: true" enables @root and data frames.
const page = path.join(SRC, 'templates', 'index.hbs');
const templateSrc = fs.readFileSync(page, 'utf8');
const template = Handlebars.compile(templateSrc, { noEscape: true, data: true });
const html = template(data);

fs.writeFileSync(path.join(DIST, 'index.html'), html, 'utf8');

// Copy JS (CSS is built by separate npm script)
const srcJs = path.join(SRC, 'js', 'main.js');
const outJs = path.join(DIST, 'assets', 'js', 'main.js');
if (fs.existsSync(srcJs)) {
  fs.copyFileSync(srcJs, outJs);
}

// Prevent Jekyll from interfering with static files on Pages
fs.writeFileSync(path.join(DIST, '.nojekyll'), '');

console.log('HTML built → dist/index.html');
