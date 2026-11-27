// E2E check of the logo review tool in headless chromium over CDP.
// Usage: node check.mjs <base-url> <answers.json the server reads> [shots-dir]   Exit 0 = every step held.
import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const [base, answersPath, shots = ""] = process.argv.slice(2);
const PORT = 19334;
let KEY = "";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const profile = mkdtempSync(join(tmpdir(), "review-e2e-"));
const proc = spawn("chromium", [
  "--headless=new", `--remote-debugging-port=${PORT}`, `--user-data-dir=${profile}`,
  "--no-first-run", "--disable-extensions", "--window-size=1500,1100", "about:blank",
], { stdio: "ignore" });

async function target() {
  for (let i = 0; i < 50; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json`)).json();
      const page = list.find((t) => t.type === "page");
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(200);
  }
  throw new Error("chromium did not start");
}

const failures = [];
// The saved state once `ok` holds for it, or after 4 s: a save is debounced, and the machine may be busy.
const savedState = async (ok) => { let s; for (let i = 0; i < 40; i++) { s = await (await fetch(`${base}/api/state`)).json(); if (ok(s)) break; await sleep(100); } return s; };
const expect = (ok, what) => { console.log(`${ok ? "PASS" : "FAIL"} ${what}`); if (!ok) failures.push(what); };

try {
  const ws = new WebSocket(await target());
  await new Promise((r) => (ws.onopen = r));
  let id = 0;
  const pending = new Map();
  ws.onmessage = (m) => { const msg = JSON.parse(m.data); pending.get(msg.id)?.(msg); pending.delete(msg.id); };
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const n = ++id;
    pending.set(n, (msg) => (msg.error ? reject(new Error(`${method}: ${msg.error.message}`)) : resolve(msg.result)));
    ws.send(JSON.stringify({ id: n, method, params }));
  });
  const js = async (expression) => (await send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true })).result.value;
  const mouse = (type, x, y, buttons) => send("Input.dispatchMouseEvent", { type, x, y, button: "left", buttons, clickCount: 1 });
  const shot = async (name) => {
    if (!shots) return;
    const { data } = await send("Page.captureScreenshot", { format: "png" });
    writeFileSync(join(shots, name), Buffer.from(data, "base64"));
  };
  // Tiles a person can actually see (a `hidden` attribute that CSS overrides does not count).
  const SEEN = "[...document.querySelectorAll('.tile')].filter(t => t.getClientRects().length).length";
  const click = (sel) => js(`document.querySelector('${sel}').click()`);

  // The round on show is whatever the manifest lists: tools x designs x (mono, colour).
  const manifest = await (await fetch(`${base}/api/manifest`)).json();
  const perToolOf = (tool) => (manifest.ids.length - (manifest.skip?.[tool] ?? []).length) * manifest.modes[tool].length;
  const total = manifest.tools.reduce((n, tool) => n + perToolOf(tool), 0);
  KEY = `${manifest.tools[0]}/${manifest.ids[0]}-c`;
  expect(manifest.round === 13 && manifest.tools.join() === "css,rough,sketch" && manifest.ids.length === 14, "the server shows round 13: the gallery of every M picture");
  expect(perToolOf("css") === 14 && perToolOf("rough") === 10 && perToolOf("sketch") === 1, "14 css pictures, 10 rough.js ones and the one loose sketch");
  expect((await fetch(`${base}/img/svg/A1-c.png`)).status === 404, "the flat svg version is no longer served as a tool");
  
  for (const gone of ["O3", "P2", "D3"]) expect((await fetch(`${base}/img/rough/${gone}-c.png`)).status === 404, `no rough ${gone} is served`);
  expect(manifest.tools.every((tool) => manifest.modes[tool].join() === "c"), "every tool is colour only");
  for (const tool of manifest.tools) expect((await fetch(`${base}/img/${tool}/A1-m.png`)).status === 404, `no mono ${tool} logo is served`);
  expect(!manifest.tools.includes("blender") && !manifest.tools.includes("generative") && !manifest.tools.includes("pixel"), "the rejected tools (Blender, dots, pixel art) are gone");

  await send("Page.enable");
  await send("Page.navigate", { url: base });
  await sleep(1500);
  expect((await js("document.querySelectorAll('.tile').length")) === total, `grid shows ${total} logos`);
  expect((await js("document.querySelectorAll('[data-key^=pixel], [data-filter=pixel]').length")) === 0, "no pixel-art tile or filter is left");
  expect((await fetch(`${base}/img/pixel/A1-c.png`)).status === 404, "the server does not serve pixel art");
  expect((await js("[...document.querySelectorAll('.tile img')].every(i => i.complete && i.naturalWidth > 0)")) === true, "every logo image loads");
  expect((await js("[...document.querySelectorAll('#tools img')].every(i => i.complete && i.naturalWidth > 0)")) === true, "each tool button shows a logo that tool really drew");

  // 1. Every toolbar button changes what is on screen.
  for (const tool of manifest.tools) {
    const perTool = perToolOf(tool);
    await click(`[data-filter=${tool}]`);
    expect((await js(SEEN)) === perTool, `the ${tool} filter leaves ${perTool} logos on screen`);
    expect((await js("document.querySelector('#shown').textContent")) === String(perTool), `the counter shows ${perTool}`);
    expect((await js(`document.querySelector('[data-filter=${tool}]').getAttribute('aria-pressed')`)) === "true", "the clicked filter is shown as pressed");
  }
  await click("[data-filter=all]");
  expect((await js(SEEN)) === total, `the all-tools button brings back ${total}`);
  for (const [show, count] of [["approve", 0], ["improve", 0], ["reject", 0], ["none", total], ["all", total]]) {
    await click(`[data-show=${show}]`);
    expect((await js(SEEN)) === count, `verdict filter ${show} leaves ${count} on screen`);
  }
  expect((await js("getComputedStyle(document.querySelector('#empty')).display")) === "none", "the empty-result sign hides again when logos are shown");
  await shot("review-grid.png");

  // 7. Compare: one type's variants side by side as the 20 px round avatar, and pick one per type.
  await click("[data-type=O]");
  await sleep(900);
  const cmp = await js(`(() => {
    const d = document.querySelector('#cmp'), cols = [...d.querySelectorAll('.col')];
    const still = (e) => e.scrollHeight <= e.clientHeight && e.scrollWidth <= e.clientWidth;
    return { open: d.open, now: cols.filter((c) => c.dataset.key).map((c) => c.dataset.key).join(), before: cols.filter((c) => c.classList.contains('before')).length,
      tiny: cols.every((c) => c.querySelector('canvas').width === 20), zoom: cols[0].querySelector('canvas').getBoundingClientRect().width,
      real: cols[0].querySelector('img.real').getBoundingClientRect().width, fits: still(document.documentElement) && still(d), full: d.getBoundingClientRect().width === innerWidth };
  })()`);
  expect(cmp.open && cmp.now === "css/O1-c,css/O2-c,css/O3-c,rough/O1-c,rough/O2-c", "the O button opens every outline picture side by side");
  expect(cmp.before === 0, "a gallery has no round-before columns");
  expect(cmp.tiny && cmp.zoom >= 120 && cmp.real === 20, "each shows its 20 px round avatar at real size and enlarged pixel for pixel");
  expect(cmp.fits && cmp.full, "the compare view fills the screen and does not scroll");
  await shot("review-compare.png");
  await click('#cmp .col[data-key="css/O2-c"] .pick');
  expect((await savedState((s) => s.picks?.O === "css/O2-c")).picks?.O === "css/O2-c", "picking a variant saves it as that type's finalist");
  expect((await js(`document.querySelector('[data-type=O]').dataset.picked`)) === "1", "the type button shows that it has a pick");
  await click("#cmp-close");
  await click('[data-type="*"]');
  await sleep(700);
  expect((await js("[...document.querySelectorAll('#cmp .col')].map((c) => c.dataset.key).join()")) === "css/O2-c", "the star button lines up the picked finalists");
  await click('#cmp .col[data-key="css/O2-c"] .pick');
  expect((await savedState((s) => s.winner === "css/O2-c")).winner === "css/O2-c", "picking among the finalists saves the winner");
  await shot("review-finalists.png");
  await click("#cmp-close");

  // 10. Share everything: one button copies every logo on the grid as one picture, grouped by category.
  await send("Browser.grantPermissions", { origin: base, permissions: ["clipboardReadWrite", "clipboardSanitizedWrite"] });
  await send("Emulation.setFocusEmulationEnabled", { enabled: true });
  await click("#grid-copy");
  for (let i = 0; i < 60 && (await js("document.querySelector('#grid-copy').dataset.done")) !== "1"; i++) await sleep(100);
  const whole = await js(`(async () => {
    const done = document.querySelector('#grid-copy').dataset.done;
    const items = await navigator.clipboard.read().catch(() => []);
    const type = items[0]?.types.find((t) => t === 'image/png');
    const bmp = type ? await createImageBitmap(await items[0].getType(type)) : null;
    const blob = await window.galleryPicture();
    const pic = await createImageBitmap(blob);
    const b64 = await new Promise((r) => { const f = new FileReader(); f.onload = () => r(f.result.split(',')[1]); f.readAsDataURL(blob); });
    return { done, w: bmp?.width ?? 0, h: bmp?.height ?? 0, pw: pic.width, ph: pic.height, layout: window.galleryLayout, b64 };
  })()`);
  expect(whole.done === "1" && whole.w === whole.pw && whole.h === whole.ph && whole.w > 1500, `the grid's copy button puts one picture of everything on the clipboard (${whole.w}x${whole.h})`);
  expect(whole.layout?.cells === total && whole.layout?.sections.join() === "1,2,3", `the picture holds all ${total} logos in the three categories 1, 2, 3`);
  expect(whole.layout?.sizes.join() === "21,2,2", "category 1 has the 21 K U / H Y pictures, 2 the two Ks, 3 the two kuhy lines");
  if (shots && whole.b64) writeFileSync(join(shots, "gallery-picture.png"), Buffer.from(whole.b64, "base64"));

  // Marks, verdict and note (as before).
  await click(`.tile[data-key="${KEY}"]`);
  await sleep(500);
  expect((await js("document.querySelector('#dlg').open")) === true, "clicking a logo opens the review view");

  // 5. Full screen, nothing scrolls, at every window size kuhy uses.
  for (const [w, h] of [[1280, 800], [1920, 1080], [1920, 2160], [3840, 2160]]) {
    await send("Emulation.setDeviceMetricsOverride", { width: w, height: h, deviceScaleFactor: 1, mobile: false });
    await sleep(500);
    const fit = await js(`(() => {
      const still = (sel) => { const e = document.querySelector(sel); return e.scrollHeight <= e.clientHeight && e.scrollWidth <= e.clientWidth; };
      const d = document.querySelector('#dlg').getBoundingClientRect(), c = document.querySelector('#contexts').getBoundingClientRect();
      const inner = document.querySelector('#ctx-inner').getBoundingClientRect(), stage = document.querySelector('.stage').getBoundingClientRect();
      return { page: still('html'), dlg: still('#dlg'), side: still('.side'), thread: still('#thread'), ctx: still('#contexts'),
        full: d.x === 0 && d.y === 0 && d.width === innerWidth && d.height === innerHeight,
        inside: inner.right <= c.right + 1 && inner.bottom <= c.bottom + 1 && inner.left >= c.left - 1 && inner.top >= c.top - 1,
        square: Math.abs(stage.width - stage.height) < 1 && stage.bottom <= innerHeight && stage.width >= 300,
        zoom: Number(document.querySelector('#ctx-inner').dataset.zoom) };
    })()`);
    expect(fit.full, `${w}x${h}: the opened logo fills the whole window`);
    expect(fit.page && fit.dlg, `${w}x${h}: neither the page nor the view scrolls`);
    expect(fit.side && fit.thread && fit.ctx && fit.inside, `${w}x${h}: side panel, thread and previews all fit without scrolling`);
    expect(fit.square, `${w}x${h}: the big logo is square, on screen and at least 300 px`);
    if (w === 3840) expect(fit.zoom === 1, "at 4K the previews are at their real sizes (100%)");
    await shot(`review-${w}x${h}.png`);
  }
  await send("Emulation.setDeviceMetricsOverride", { width: 1500, height: 1100, deviceScaleFactor: 1, mobile: false });
  await sleep(400);
  await js("document.querySelector('[data-tool=rect]').click(); document.querySelector('[data-like=\"0\"]').click()");
  await js("document.querySelector('#overlay').scrollIntoView({ block: 'start' })");
  const box = await js("(() => { const r = document.querySelector('#overlay').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; })()");
  await mouse("mousePressed", box.x + box.w * 0.2, box.y + box.h * 0.3, 1);
  await mouse("mouseMoved", box.x + box.w * 0.4, box.y + box.h * 0.5, 1);
  await mouse("mouseMoved", box.x + box.w * 0.6, box.y + box.h * 0.7, 1);
  await mouse("mouseReleased", box.x + box.w * 0.6, box.y + box.h * 0.7, 0);
  await sleep(200);
  expect((await js("document.querySelectorAll('#overlay rect.mark').length")) === 1, "dragging draws a rectangle on the logo");
  await js("document.querySelector('#marks input').focus()");
  await send("Input.insertText", { text: "too thin" });
  await js("document.querySelector('[data-tool=arrow]').click(); document.querySelector('[data-like=\"1\"]').click()");
  await mouse("mousePressed", box.x + box.w * 0.8, box.y + box.h * 0.2, 1);
  await mouse("mouseMoved", box.x + box.w * 0.7, box.y + box.h * 0.4, 1);
  await mouse("mouseReleased", box.x + box.w * 0.7, box.y + box.h * 0.4, 0);
  await click("[data-tool=point]");
  await mouse("mousePressed", box.x + box.w * 0.5, box.y + box.h * 0.1, 1);
  await mouse("mouseReleased", box.x + box.w * 0.5, box.y + box.h * 0.1, 0);
  await click("[data-tool=ellipse]");
  await mouse("mousePressed", box.x + box.w * 0.1, box.y + box.h * 0.8, 1);
  await mouse("mouseMoved", box.x + box.w * 0.3, box.y + box.h * 0.95, 1);
  await mouse("mouseReleased", box.x + box.w * 0.3, box.y + box.h * 0.95, 0);
  await click("[data-verdict=reject]");
  await js("document.querySelector('#note').focus()");
  await send("Input.insertText", { text: "wrong direction" });

  // 2. Context previews: where the logo will really be shown.
  const ctx = (sel) => `document.querySelectorAll('#contexts ${sel}').length`;
  expect((await js(ctx("[data-scheme=light]"))) === 1 && (await js(ctx("[data-scheme=dark]"))) === 1, "contexts are shown on light and on dark");
  const SERVICES = ["signal", "discord", "steam", "linkedin", "facebook", "github", "whatsapp", "telegram", "instagram", "x", "reddit", "youtube", "slack", "gmail"];
  for (const name of SERVICES) expect((await js(ctx(`[data-ctx=${name}]`))) === 2, `service ${name} is a preview in both schemes`);
  // The frame badge is the service's real logo (fake mirror: every service but gmail), the chip only where none is fetched.
  await js("Promise.all([...document.querySelectorAll('#contexts img.badge')].map(i => i.decode().catch(() => {})))");
  await sleep(300);
  const badges = await js(`(() => { const out = {}; for (const el of document.querySelectorAll('#contexts [data-scheme] .ctx')) {
    const b = el.querySelector('img.badge'), chip = el.querySelector('.chip'), scheme = el.closest('[data-scheme]').dataset.scheme;
    out[scheme + '/' + el.dataset.ctx] = { logo: !!b && !b.hidden && b.naturalWidth > 0 && b.getAttribute('src') === '/services/' + el.dataset.ctx + '.svg',
      chip: !!chip && !chip.hidden && chip.getClientRects().length > 0, filter: b ? getComputedStyle(b).filter : '' }; } return out; })()`);
  const logos = SERVICES.filter((s) => s !== "gmail");
  expect(logos.every((s) => badges[`light/${s}`].logo && !badges[`light/${s}`].chip && badges[`dark/${s}`].logo && !badges[`dark/${s}`].chip), "every fetched service shows its real logo as the frame badge, no chip");
  expect(badges["light/gmail"].chip && !badges["light/gmail"].logo && badges["dark/gmail"].chip, "a service with no logo file keeps its chip");
  expect(badges["light/square"].chip, "the square app icon keeps its chip");
  expect(logos.every((s) => badges[`light/${s}`].filter === "none" && badges[`dark/${s}`].filter.includes("invert(1)")), "badges are brand colour on light, white on dark");
  expect((await js("[...document.querySelectorAll('#contexts [data-ctx=signal] .row img')].every(i => i.getAttribute('src') === '/img/' + " + JSON.stringify(KEY) + " + '.png')")), "the candidate stays the avatar in a service's frame");
  for (const name of ["linkedin", "facebook", "discord", "github", "square", "tab", "header-desktop", "header-mobile", "og"]) {
    expect((await js(ctx(`[data-ctx=${name}]`))) === 2, `context ${name} is shown in both schemes`);
  }
  // Sizes are true pixels times the shown scale (100% once the window is big enough).
  const zoom = await js("Number(document.querySelector('#ctx-inner').dataset.zoom)");
  const near = (got, want) => Math.abs(got / zoom - want) < 0.6;
  expect((await js("document.querySelector('#ctx-scale').textContent")) === `${Math.round(zoom * 100)}%`, "the previews show their scale");
  const avatar = await js("(() => { const i = document.querySelector('#contexts [data-ctx=linkedin] img[width=\"48\"]'); const s = getComputedStyle(i); return { w: i.getBoundingClientRect().width, r: s.borderRadius, src: i.getAttribute('src') }; })()");
  expect(near(avatar.w, 48) && avatar.r === "50%" && avatar.src === `/img/${KEY}.png`, "the LinkedIn avatar is this logo, round, 48 px at the shown scale");
  expect(near(await js("document.querySelector('#contexts [data-ctx=square] img').getBoundingClientRect().width"), 180), "the square icon is 180 px at the shown scale");
  expect((await js("getComputedStyle(document.querySelector('#contexts [data-ctx=square] img')).borderRadius")) !== "50%", "the square icon is not cropped round");
  expect((await js("[...document.querySelectorAll('#contexts [data-scheme=light] [data-ctx=tab] img')].map(i => i.getAttribute('width')).join()")) === "16,32", "the browser tab shows the favicon at 16 and 32 px");
  const og = await js("(() => { const r = document.querySelector('#contexts [data-ctx=og] .card').getBoundingClientRect(); return r.width / r.height; })()");
  expect(Math.abs(og - 1200 / 630) < 0.02, "the og card keeps the 1200x630 shape");
  const mark = await js("(() => { const c = document.querySelector('#contexts [data-ctx=og] .card').getBoundingClientRect(), i = document.querySelector('#contexts [data-ctx=og] .card img').getBoundingClientRect(); return { dx: (i.left + i.right) / 2 - (c.left + c.right) / 2, dy: (i.top + i.bottom) / 2 - (c.top + c.bottom) / 2, inside: i.top >= c.top && i.bottom <= c.bottom, ratio: i.height / c.height }; })()");
  expect(Math.abs(mark.dx) < 1 && Math.abs(mark.dy) < 1 && mark.inside && Math.abs(mark.ratio - 0.67) < 0.02, "the whole logo sits centred on the og card");
  expect(near(await js("document.querySelector('#contexts [data-ctx=header-mobile] .bar').getBoundingClientRect().width"), 360), "the mobile header is 360 px wide at the shown scale");
  // Overlays: the corner mark a service draws over an avatar (a status dot, Google's pencil) at every listed size.
  const overlays = await js(`(() => { const out = {}; for (const el of document.querySelectorAll('#contexts [data-scheme] .ctx')) {
    const imgs = [...el.querySelectorAll('.row img')];
    out[el.closest('[data-scheme]').dataset.scheme + '/' + el.dataset.ctx] = imgs.map((img) => { const o = img.parentElement.querySelector('.ov'); if (!o) return null;
      const i = img.getBoundingClientRect(), r = o.getBoundingClientRect(), mx = i.left + i.width / 2, my = i.top + i.height / 2;
      return { tip: o.getAttribute('title'), corner: r.left >= mx && r.top >= my && r.left < i.right && r.top < i.bottom && (r.left + r.right) / 2 > mx && (r.top + r.bottom) / 2 > my }; }); } return out; })()`);
  const OVERLAID = { discord: "Online", gmail: "Edit", slack: "Online", telegram: "Online", facebook: "Online" };
  for (const scheme of ["light", "dark"]) {
    for (const [name, tip] of Object.entries(OVERLAID)) {
      const cells = overlays[`${scheme}/${name}`] || [];
      expect(cells.length > 0 && cells.every((c) => c && c.corner && c.tip === tip), `${scheme}: every ${name} preview has its "${tip}" overlay over the bottom-right corner`);
    }
    const plain = SERVICES.filter((s) => !(s in OVERLAID)).concat("square");
    expect(plain.every((s) => (overlays[`${scheme}/${s}`] || []).every((c) => c === null)), `${scheme}: the other services have no overlay`);
  }

  // 6. History: how this design looked in earlier rounds, what kuhy said then, and what changed.
  await click("#hist-toggle");
  await sleep(600);
  const hist = await js(`(() => {
    const steps = [...document.querySelectorAll('#history .step')];
    const still = (sel) => { const e = document.querySelector(sel); return e.scrollHeight <= e.clientHeight && e.scrollWidth <= e.clientWidth; };
    return { shown: getComputedStyle(document.querySelector('#history')).display !== 'none', previewsHidden: document.querySelector('#ctx-inner').getClientRects().length === 0,
      rounds: steps.map((s) => s.dataset.round).join(), loaded: steps.every((s) => { const i = s.querySelector('img'); return i.complete && i.naturalWidth > 0; }),
      quoted: steps.filter((st) => (st.querySelector('.said')?.textContent ?? '').trim().length > 3).length, said: steps[2]?.querySelector('.said')?.textContent ?? '', marks: steps[2]?.querySelectorAll('svg .mark').length ?? 0,
      said2: steps[1]?.querySelector('.said')?.textContent ?? '', said4: steps[3]?.querySelector('.said')?.textContent ?? '', said5: steps[4]?.querySelector('.said')?.textContent ?? '', said6: steps[5]?.querySelector('.said')?.textContent ?? '', said9: steps[8]?.querySelector('.said')?.textContent ?? '',
      changed: steps.at(-1)?.querySelector('.changed')?.textContent ?? '', now: steps.at(-1)?.querySelector('img').getAttribute('src'),
      pressed: document.querySelector('#hist-toggle').getAttribute('aria-pressed'), fits: still('html') && still('#dlg') && still('#contexts') };
  })()`);
  expect(hist.shown && hist.previewsHidden && hist.pressed === "true", "the history button swaps the previews for the design's history");
  expect(hist.rounds === "4,5,6,7,8,13" && hist.loaded, "the history shows the rounds that picture was in, and now, with every picture loaded");
  expect(hist.quoted >= 1, `earlier steps quote what kuhy said about that logo then (${hist.quoted} steps)`);
  // What kuhy wrote in a logo's thread in an archived round is part of what he said then.
  const archive = await (await fetch(`${base}/api/history`)).json();
  const threadSaid = await js(`[...document.querySelectorAll('#history .step')].map((s) => [s.dataset.round, s.querySelector('.head span').textContent.split(' · ')[1], s.querySelector('.said')?.textContent ?? ''])`);
  const archivedAsks = threadSaid.flatMap(([round, id, said]) => (archive.tools[round] ?? []).flatMap((t) => (archive.said[round]?.[`${t}/${id}-c`]?.thread ?? []).map((m) => ({ text: m.text, said }))));
  expect(archivedAsks.every((m) => m.said.includes(m.text)), `earlier steps quote kuhy's thread messages of that round (${archivedAsks.length} in this history)`);
  expect(hist.changed.length > 30 && hist.now === `/img/${KEY}.png`, "the last step is the current logo with what changed");
  expect(hist.fits, "the history view does not scroll either");
  await shot("review-history.png");
  await click("#hist-toggle");
  await sleep(300);
  expect((await js("document.querySelector('#ctx-inner').getClientRects().length > 0 && getComputedStyle(document.querySelector('#history')).display === 'none'")) === true, "pressing it again brings the previews back");
  await sleep(300);

  // 4. Discussion: the stored rationale, a question, and an answer from the design side.
  expect((await js("document.querySelector('#thread .msg.claude')?.textContent.length > 20")) === true, "the logo's thread opens with its design rationale");
  await js("document.querySelector('#ask').focus()");
  await send("Input.insertText", { text: "why kitty?" });
  await click("#send");
  await sleep(300);
  expect((await js("document.querySelector('#thread .msg.kuhy')?.textContent.includes('why kitty?')")) === true, "the question appears in the thread");
  expect((await js("document.querySelector('#ask').value")) === "", "the question box empties after sending");
  await sleep(1000);
  await shot("review-logo.png");
  const asked = (await (await fetch(`${base}/api/state`)).json()).logos?.[KEY]?.thread?.[0];
  expect(asked?.text === "why kitty?" && typeof asked?.at === "string", "the question reaches the server with its time");
  writeFileSync(answersPath, JSON.stringify({ [KEY]: [{ text: "It was meant to be an owl.", at: new Date(Date.now() + 1000).toISOString() }] }));
  await click("#next");
  await click("#prev");
  await sleep(500);
  expect((await js("[...document.querySelectorAll('#thread .msg')].map(m => m.className.includes('claude') ? 'c' : 'k').join('')")) === "ckc", "the answer shows in that logo's thread, after the question");
  expect((await js("document.querySelector('#thread .msg:last-child').textContent.includes('meant to be an owl')")) === true, "the answer text is the one written for this logo");
  await click("#close");

  // 3. Suggest a new direction, with a reference and a picture.
  await click("#ideas-open");
  expect((await js("document.querySelector('#ideas').open")) === true, "the lightbulb opens the suggestions view");
  await js("document.querySelector('#idea-text').focus()");
  await send("Input.insertText", { text: "try a brush-stroke K" });
  await js("document.querySelector('#idea-ref').focus()");
  await send("Input.insertText", { text: "https://example.com/brush" });
  await click("#idea-add");
  await sleep(1000);
  expect((await js("document.querySelectorAll('#idea-list .idea').length")) === 1, "the suggestion is listed");
  expect((await js("document.querySelector('#ideas-open .n').textContent")) === "1", "the lightbulb shows 1 suggestion");
  await shot("review-ideas.png");
  const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==", "base64");
  const up = await fetch(`${base}/api/ref`, { method: "POST", headers: { "Content-Type": "image/png" }, body: png });
  const file = up.ok ? (await up.json()).file : "";
  expect(up.ok && /^[0-9a-f]{16}\.png$/.test(file), "a reference picture can be uploaded");
  expect((await fetch(`${base}/ref/${file}`)).status === 200, "the uploaded picture is served back");
  expect((await fetch(`${base}/api/ref`, { method: "POST", headers: { "Content-Type": "text/html" }, body: "<b>" })).status === 400, "a non-image upload is refused");

  const state = await (await fetch(`${base}/api/state`)).json();
  const logo = state.logos?.[KEY];
  expect(logo?.verdict === "reject" && logo?.note === "wrong direction", "the verdict and the note reach the server");
  expect(logo?.marks?.map((m) => m.kind).join() === "rect,arrow,point,ellipse", "all four mark kinds are saved in order");
  const rect = logo?.marks?.[0];
  expect(rect?.text === "too thin" && rect?.like === false, "the rectangle keeps its comment and its dislike");
  expect(rect && Math.abs(rect.x1 - 0.2) < 0.02 && Math.abs(rect.y2 - 0.7) < 0.02, "the rectangle's position is saved relative to the logo");
  expect(state.ideas?.[0]?.text === "try a brush-stroke K" && state.ideas?.[0]?.ref === "https://example.com/brush", "the suggestion and its reference reach the server");

  await send("Page.navigate", { url: base });
  await sleep(1500);
  expect((await js(`document.querySelector('.tile[data-key="${KEY}"]').dataset.verdict`)) === "reject", "after a reload the logo still shows as rejected");
  expect((await js(`document.querySelector('.tile[data-key="${KEY}"] .count').textContent`)) === "4", "the tile shows its 4 marks");
  await click("[data-show=reject]");
  expect((await js(SEEN)) === 1, "the rejected filter leaves only that logo on screen");
  await click("[data-show=approve]");
  expect((await js(SEEN)) === 0 && (await js("getComputedStyle(document.querySelector('#empty')).display")) !== "none", "an empty result shows the empty sign instead of nothing");

  // 8. The winner: once every type has a pick and no winner is chosen, the page opens on the finalists by itself.
  const all = { O: "css/O3-c", P: "css/P3-c", B: "css/B2-c", D: "css/D2-c", S: "css/S1-c" };
  await fetch(`${base}/api/state`, { method: "PUT", body: JSON.stringify({ ...state, picks: all, winner: null }) });
  await send("Page.navigate", { url: base });
  await sleep(1500);
  const final = await js(`(() => { const d = document.querySelector('#cmp'), picks = [...d.querySelectorAll('.col .pick')];
    return { open: d.open, cols: d.querySelectorAll('.col').length, crowns: picks.every((b) => b.classList.contains('crown') && b.getBoundingClientRect().width >= 72),
      pending: document.querySelector('#types [data-type="*"]').dataset.pending }; })()`);
  expect(final.open && final.cols === 5, "with a pick in every type and no winner, the five finalists open by themselves");
  expect(final.crowns && final.pending === "1", "each finalist has one large winner button, and the top-bar button is marked as waiting");
  await shot("review-winner.png");

  // 9. Share: one button copies the line-up on screen as a single picture, ready to paste into a chat.
  await send("Browser.grantPermissions", { origin: base, permissions: ["clipboardReadWrite", "clipboardSanitizedWrite"] });
  await send("Emulation.setFocusEmulationEnabled", { enabled: true });
  await click("#cmp-copy");
  await sleep(1500);
  const copied = await js(`(async () => {
    const done = document.querySelector('#cmp-copy').dataset.done;
    const items = await navigator.clipboard.read().catch(() => []);
    const type = items[0]?.types.find((t) => t === 'image/png');
    const bmp = type ? await createImageBitmap(await items[0].getType(type)) : null;
    const pic = await createImageBitmap(await window.sharePicture());
    const g = new OffscreenCanvas(pic.width, pic.height).getContext('2d'); g.drawImage(pic, 0, 0);
    // The enlarged 20 px avatar is drawn pixel for pixel: inside one of its big pixels every dot has one colour.
    const z = window.shareLayout, px = z.zoom / 20, x0 = z.pad + (z.col - z.zoom) / 2 + 9 * px, y0 = z.zoomTop + 9 * px;
    const d = g.getImageData(x0 + 2, y0 + 2, px - 4, px - 4).data; let flat = true;
    for (let i = 4; i < d.length; i += 4) if (d[i] !== d[0] || d[i + 1] !== d[1] || d[i + 2] !== d[2]) flat = false;
    return { done, w: bmp?.width ?? 0, h: bmp?.height ?? 0, pw: pic.width, ph: pic.height, flat, cols: z.count };
  })()`);
  expect(copied.done === "1", "the copy button shows that the picture was copied");
  expect(copied.w === copied.pw && copied.h === copied.ph && copied.w > 1200, `the clipboard holds the line-up as one PNG (${copied.w}x${copied.h})`);
  expect(copied.cols === 5 && copied.flat, "the picture has every logo on screen, each with its 20 px avatar enlarged pixel for pixel");
  await click('#cmp .col[data-key="css/D2-c"] .pick');
  await sleep(700);
  expect((await (await fetch(`${base}/api/state`)).json()).winner === "css/D2-c", "one press on a finalist saves the winner");
  expect((await js(`document.querySelector('#cmp .col[data-key="css/D2-c"]').dataset.picked`)) === "1" && (await js(`document.querySelector('#types [data-type="*"]').dataset.pending`)) === undefined, "the winner is marked and nothing is waiting any more");
  await send("Page.navigate", { url: base });
  await sleep(1200);
  expect((await js("document.querySelector('#cmp').open")) === false, "with a winner saved the page opens on the grid again");
  ws.close();
} catch (error) {
  expect(false, `check ran to the end (${error.message})`);
} finally {
  proc.kill();
}
process.exit(failures.length === 0 ? 0 : 1);
