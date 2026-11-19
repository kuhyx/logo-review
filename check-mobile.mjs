// E2E check of the logo review tool at phone size (412x915, touch) and over the local network, in headless chromium over CDP.
// Usage: node check-mobile.mjs <base-url> <answers.json the server reads> [shots-dir]   Exit 0 = every step held.
import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const [base, answersPath, shots = ""] = process.argv.slice(2);
const PORT = 19336;
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
  const click = (sel) => js(`document.querySelector('${sel}').click()`);
  const fits = "document.documentElement.scrollWidth <= document.documentElement.clientWidth";
  const manifest = await (await fetch(`${base}/api/manifest`)).json();
  const KEY = `${manifest.tools[0]}/${manifest.ids[0]}-c`, TYPE = manifest.ids[0][0];

  // 1. Over the network: another device needs the key from the QR code; this computer hands it out.
  const phone = (await (await fetch(`${base}/api/phone`)).json()).url;
  expect(/^http:\/\/\d+\.\d+\.\d+\.\d+:\d+\/\?k=.{32,}$/.test(phone ?? ""), "this computer gets the phone link, with the key");
  const lan = new URL(phone).origin;
  expect((await fetch(`${lan}/`)).status === 403 && (await fetch(`${lan}/api/state`)).status === 403, "over the network nothing opens without the key");
  const first = await fetch(phone, { redirect: "manual" });
  const cookie = (first.headers.get("set-cookie") ?? "").split(";")[0];
  expect(first.status === 303 && cookie.startsWith("k="), "the link with the key answers with a cookie and the plain address");
  expect((await fetch(`${lan}/`, { headers: { cookie } })).status === 200 && (await fetch(`${lan}/img/${KEY}.png`, { headers: { cookie } })).status === 200, "with the cookie the page and the logos load over the network");

  await send("Page.enable");
  await send("Page.navigate", { url: base });
  await sleep(1500);
  await click("#phone-open");
  await sleep(700);
  const qr = await js("(() => { const d = document.querySelector('#phone'), i = d.querySelector('img'); return { open: d.open, ok: i.complete && i.naturalWidth > 0, w: i.getBoundingClientRect().width }; })()");
  expect(qr.open && qr.ok && qr.w >= 240, "on the computer the phone button shows the QR code to scan");
  await shot("phone-qr.png");
  await click("#phone-close");

  // 2. Phone size: 412x915, touch.
  await send("Emulation.setDeviceMetricsOverride", { width: 412, height: 915, deviceScaleFactor: 2.625, mobile: true });
  await send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 5 });
  await send("Page.navigate", { url: base });
  await sleep(1500);
  const grid = await js(`(() => { const t = [...document.querySelectorAll('.tile')].map((e) => e.getBoundingClientRect());
    const small = [...document.querySelectorAll('header button')].filter((b) => b.getClientRects().length && (b.getBoundingClientRect().width < 44 || b.getBoundingClientRect().height < 44)).length;
    return { fits: ${fits}, perRow: t.filter((r) => r.top === t[0].top).length, small, phoneButton: document.querySelector('#phone-open').getClientRects().length }; })()`);
  expect(grid.fits, "the grid does not scroll sideways on a phone");
  expect(grid.perRow === 2, `two logos per row (${grid.perRow})`);
  expect(grid.small === 0, `every top-bar button is at least 44 px for a thumb (${grid.small} too small)`);
  await shot("mobile-grid.png");

  // 3. One logo: the picture fills the width, the controls and previews follow below, nothing is cut off sideways.
  await click(`.tile[data-key="${KEY}"]`);
  await sleep(900);
  const one = await js(`(() => { const d = document.querySelector('#dlg'), r = (s) => document.querySelector(s).getBoundingClientRect();
    const small = [...d.querySelectorAll('button')].filter((b) => b.getClientRects().length && (b.getBoundingClientRect().width < 44 || b.getBoundingClientRect().height < 44)).length;
    return { open: d.open, fits: ${fits} && d.scrollWidth <= d.clientWidth, big: r('#big').width, sideTop: r('.side').top, stageBottom: r('.stage').bottom, ctxTop: r('#contexts').top, sideBottom: r('.side').bottom,
      ctxRight: r('#ctx-inner').right, ctxW: r('#ctx-inner').width, scrolls: d.scrollHeight > d.clientHeight, touch: getComputedStyle(document.querySelector('#overlay')).touchAction, small,
      thread: r('#thread').height, noteW: r('#note').width }; })()`);
  expect(one.open && one.fits, "the opened logo does not scroll sideways");
  expect(one.big >= 380, `the logo fills the phone's width (${Math.round(one.big)} px)`);
  expect(one.sideTop >= one.stageBottom - 1 && one.ctxTop >= one.sideBottom - 1 && one.scrolls, "controls come below the logo, previews below the controls, and the view scrolls down");
  expect(one.ctxRight <= 413 && one.ctxW >= 360, `the previews are scaled to the phone's width (${Math.round(one.ctxW)} px)`);
  expect(one.small === 0 && one.noteW >= 360, `buttons are thumb-sized and the note box is full width (${one.small} too small)`);
  expect(one.touch === "none", "a finger on the logo draws instead of scrolling");
  await shot("mobile-logo.png");

  // 4. Draw a rectangle with a finger.
  await click("[data-tool=rect]");
  const box = await js("(() => { const r = document.querySelector('#overlay').getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; })()");
  const at = (fx, fy) => [{ x: box.x + fx * box.w, y: box.y + fy * box.h }];
  await send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: at(0.2, 0.2) });
  await send("Input.dispatchTouchEvent", { type: "touchMove", touchPoints: at(0.5, 0.4) });
  await send("Input.dispatchTouchEvent", { type: "touchMove", touchPoints: at(0.7, 0.6) });
  await send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
  await sleep(900);
  const mark = (await (await fetch(`${base}/api/state`)).json()).logos?.[KEY]?.marks?.[0];
  expect(mark?.kind === "rect" && Math.abs(mark.x1 - 0.2) < 0.03 && Math.abs(mark.x2 - 0.7) < 0.03, "a finger drag draws a rectangle and it is saved");
  expect((await js("document.querySelector('#dlg').scrollTop")) === 0, "the page stayed still while drawing");
  await click("#hist-toggle");
  await sleep(600);
  const hist = await js(`(() => { const h = document.querySelector('#history').getBoundingClientRect(); return { right: h.right, w: h.width, fits: ${fits} }; })()`);
  expect(hist.fits && hist.right <= 413 && hist.w >= 300, `the history fits the phone's width (${Math.round(hist.w)} px)`);
  await click("#close");

  // 5. Compare: one logo per screen, swipe sideways for the next.
  await click(`[data-type=${TYPE}]`);
  await sleep(900);
  const cmp = await js(`(() => { const c = document.querySelector('#cmp-cols'), cols = [...c.querySelectorAll('.col')].map((e) => e.getBoundingClientRect());
    return { fits: ${fits}, colW: cols[0].width, swipes: c.scrollWidth > c.clientWidth, snap: getComputedStyle(c).scrollSnapType, n: cols.length,
      bottom: Math.max(...cols.map((r) => r.bottom)), tall: innerHeight, pick: document.querySelector('#cmp .pick').getBoundingClientRect().width }; })()`);
  expect(cmp.fits && cmp.colW >= 280 && cmp.colW <= 380, `each compared logo takes most of the screen (${Math.round(cmp.colW)} px)`);
  expect(cmp.n > 1 && cmp.swipes && cmp.snap.startsWith("x"), "the others are a sideways swipe away, snapping one by one");
  expect(cmp.bottom <= cmp.tall + 1 && cmp.pick >= 44, "a compared logo fits the screen's height, with a thumb-sized pick button");
  await shot("mobile-compare.png");

  // 6. Copy: a phone on plain http has no clipboard for pictures, so the picture is shown to long-press and share.
  await js("Object.defineProperty(navigator, 'clipboard', { value: undefined, configurable: true })");
  await click("#cmp-copy");
  await sleep(1500);
  const pic = await js("(() => { const d = document.querySelector('#pic'), i = d.querySelector('img'); return { open: d.open, w: i.naturalWidth, shown: i.getBoundingClientRect().width, src: i.src.slice(0, 5) }; })()");
  expect(pic.open && pic.w > 700 && pic.shown <= 412 && pic.src === "blob:", "without a clipboard the copy button shows the finished picture to long-press");
  await shot("mobile-share.png");
  ws.close();
} catch (error) {
  expect(false, `check ran to the end (${error.message})`);
} finally {
  proc.kill();
}
process.exit(failures.length === 0 ? 0 : 1);
