// tools/build.mjs
// Tiny Handlebars build: load data, register partials, compile index.hbs → dist/index.html
// Intent: keep it simple and readable; expand later as we add pages.

import fs from 'fs';
import path from 'path';
import Handlebars from 'handlebars';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SRC = path.join(__dirname, '..', 'src');
const DIST = path.join(__dirname, '..', 'dist');

// helper: current year for footer
Handlebars.registerHelper('year', () => new Date().getFullYear());

// 1) load data (fail early with a helpful message if missing)
const dataPath = path.join(SRC, 'data', 'site.json');
if (!fs.existsSync(dataPath)) {
  console.error('Missing src/data/site.json');
  process.exit(1);
}
const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));

// 2) register partials
function registerPartials(dir, prefix = '') {
  if (!fs.existsSync(dir)) return;
  for (const file of fs.readdirSync(dir)) {
    if (!file.endsWith('.hbs')) continue;
    const name = `${prefix}${file.replace('.hbs', '')}`;
    const content = fs.readFileSync(path.join(dir, file), 'utf8');
    Handlebars.registerPartial(name, content);
    console.log('Registered partial:', name);
  }
}

registerPartials(path.join(SRC, 'templates', 'partials'));              // e.g., "meta"
registerPartials(path.join(SRC, 'templates', 'sections'), 'sections/'); // e.g., "sections/home"
registerPartials(path.join(SRC, 'templates', 'layouts'), 'layouts/');   // e.g., "layouts/base"

// 3) compile pages (tiny list → tiny loop)
const pages = [
  ['index.hbs', 'index.html'], // builds index.html for home
  ['pages/about.hbs', path.join('about', 'index.html')], // builds index.html for about
  ['pages/projects.hbs', path.join('projects', 'index.html')], // builds index.html for projects
];

for (const [tplRel, outRel] of pages) {
  const tplAbs = path.join(SRC, 'templates', tplRel);
  if (!fs.existsSync(tplAbs)) {
    console.warn('Skipping missing template:', tplRel);
    continue;
  }
  const tplFn = Handlebars.compile(fs.readFileSync(tplAbs, 'utf8'), { noEscape: true });
  const html = tplFn(data);
  const outAbs = path.join(DIST, outRel);
  fs.mkdirSync(path.dirname(outAbs), { recursive: true });
  fs.writeFileSync(outAbs, html, 'utf8');
  console.log('Wrote:', outRel);
}

// 4) write the output + ensure JS is available in /assets/js
fs.mkdirSync(path.join(DIST, 'assets', 'js'), { recursive: true });

// copy main.js (defensive: only if it exists)
const jsSrc = path.join(SRC, 'js', 'main.js');
const jsOut = path.join(DIST, 'assets', 'js', 'main.js');
if (fs.existsSync(jsSrc)) {
  fs.copyFileSync(jsSrc, jsOut);
}

console.log('HTML built.');
