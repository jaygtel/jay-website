// tools/build.mjs
// Builds HTML from Handlebars templates into /dist
// - Registers partials from: src/templates/partials
// - Registers sections from: src/templates/sections  ({{> sections/hero}})
// - Registers layouts from:  src/templates/layouts   ({{#> layouts/base}} ... {{/layouts/base}})
// - Compiles root-level templates in src/templates/*.hbs into dist/*.html
// - Helpers: {{prefixBase href base}}, {{year}}
// - Writes .nojekyll for GitHub Pages

import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import Handlebars from 'handlebars';

const ROOT = process.cwd();
const SRC = path.join(ROOT, 'src');
const DIST = path.join(ROOT, 'dist');

const TEMPLATES_DIR = path.join(SRC, 'templates');
const PARTIALS_DIR = path.join(TEMPLATES_DIR, 'partials');
const SECTIONS_DIR = path.join(TEMPLATES_DIR, 'sections');
const LAYOUTS_DIR = path.join(TEMPLATES_DIR, 'layouts');
const DATA_DIR = path.join(SRC, 'data');

async function ensureDir(p) {
  await fsp.mkdir(p, { recursive: true });
}

async function writeFile(targetPath, content) {
  await ensureDir(path.dirname(targetPath));
  await fsp.writeFile(targetPath, content, 'utf8');
}

function listHbsFilesSync(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .map(name => path.join(dir, name))
    .filter(p => fs.statSync(p).isFile() && p.endsWith('.hbs'));
}

function registerHelpers() {
  // {{prefixBase href base}} → prefixes base for real paths but leaves #anchors and absolute URLs alone
  Handlebars.registerHelper('prefixBase', (href, base) => {
    if (!href) return '';
    if (/^https?:\/\//i.test(href)) return href; // absolute URLs untouched
    if (href.startsWith('#')) return href;       // in-page anchors untouched
    const b = (base || '').replace(/\/$/, '');
    const h = href.startsWith('/') ? href : `/${href}`;
    return `${b}${h}`;
  });

  // {{year}} → current 4-digit year
  Handlebars.registerHelper('year', () => new Date().getFullYear());
}

function registerPartialsDirectory(dir, namePrefix = '') {
  if (!fs.existsSync(dir)) return;

  for (const filePath of listHbsFilesSync(dir)) {
    const raw = fs.readFileSync(filePath, 'utf8');
    const base = path.basename(filePath, '.hbs');
    const name = namePrefix ? `${namePrefix}/${base}` : base;
    Handlebars.registerPartial(name, raw);
  }
}

async function loadSiteData() {
  const siteJsonPath = path.join(DATA_DIR, 'site.json');
  const raw = fs.existsSync(siteJsonPath) ? await fsp.readFile(siteJsonPath, 'utf8') : '{}';
  const parsed = JSON.parse(raw || '{}');

  // Accept either { site: {…} } or a flat object
  const data = parsed && typeof parsed === 'object' && 'site' in parsed
    ? parsed
    : { site: parsed || {} };

  // Allow env override so local dev can use '' while Pages uses '/repo'
  const envBase = process.env.SITE_BASE;
  if (typeof envBase !== 'undefined') data.site.base = envBase;

  // Normalize base (strip trailing slash unless empty)
  if (typeof data.site.base === 'string' && data.site.base !== '') {
    data.site.base = data.site.base.replace(/\/$/, '');
  }

  return data;
}

function listTopLevelTemplatePages() {
  if (!fs.existsSync(TEMPLATES_DIR)) return [];
  return fs.readdirSync(TEMPLATES_DIR)
    .map(name => path.join(TEMPLATES_DIR, name))
    .filter(p => fs.statSync(p).isFile() && p.endsWith('.hbs'));
}

async function compilePages(context) {
  const pages = listTopLevelTemplatePages();
  for (const tplPath of pages) {
    const src = await fsp.readFile(tplPath, 'utf8');
    const template = Handlebars.compile(src);
    const html = template({ ...context, page: context.page || {} });

    const filename = path.basename(tplPath, '.hbs') + '.html';
    const outPath = path.join(DIST, filename);
    await writeFile(outPath, html);
    console.log(`✓ Built ${path.relative(ROOT, outPath)}`);
  }
}

async function writeNoJekyll() {
  await writeFile(path.join(DIST, '.nojekyll'), '');
}

async function main() {
  try {
    await ensureDir(DIST);

    registerHelpers();

    // Register reusable template parts
    registerPartialsDirectory(PARTIALS_DIR);             // {{> header}}
    registerPartialsDirectory(SECTIONS_DIR, 'sections'); // {{> sections/hero}}
    registerPartialsDirectory(LAYOUTS_DIR, 'layouts');   // {{#> layouts/base}} ... {{/layouts/base}}

    const data = await loadSiteData(); // { site: {...} }
    await compilePages(data);

    await writeNoJekyll();

    console.log('Build complete.');
  } catch (err) {
    console.error('Build failed:', err);
    process.exit(1);
  }
}

await main();
