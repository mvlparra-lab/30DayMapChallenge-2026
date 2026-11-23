// Render the saved Leaflet widget in Chrome. Export layouts exist only in
// these capture sessions and never modify the interactive HTML.
import { spawn, spawnSync } from "node:child_process";
import { copyFile, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { setTimeout as pause } from "node:timers/promises";

const project = dirname(fileURLToPath(import.meta.url));
const outputs = join(project, "outputs");
const stem = "day23-cadiz-a-meeting-of-flavours";
const mapUrl = pathToFileURL(join(outputs, stem + ".html")).href;
const chromePath = process.env.CHROME_PATH || (process.platform === "win32"
  ? "C:/Program Files/Google/Chrome/Application/chrome.exe"
  : process.platform === "darwin"
    ? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    : "google-chrome");
const python = process.env.PYTHON || (process.platform === "win32" ? "python" : "python3");

// CSS coordinates relative to each projected Leaflet marker. Negative x
// places the end of the label to the left of the marker.
const coverLabels = {
  "las-flores": [20, -22],
  "tio-de-la-tiza": [-22, 15, "El Tío de la Tiza"],
  salicornia: [-22, 34],
  "casa-manteca": [20, 28, "Casa Manteca"],
  "casa-pepe": [-23, 23],
  "casa-tino": [23, -26, "Casa Tino & Sinónimo"],
  "la-sorpresa": [20, 16],
  "casa-lazo": [20, -12],
  "la-rondena": [-20, 11],
  "puerta-del-eden": [19, 24, "Puerta del Edén"],
  ettu: [-20, 46],
  "la-candela": [20, -15],
  gadisushi: [-22, 26],
  "santa-catrina": [19, -24, "Santa Catrina Cádiz"],
  "mercado-central": [-22, -26, "Mercado Central"],
};
const scenes = [
  { mask: 7, duration: 1400 },
  { mask: 0, duration: 550 },
  { mask: 1, duration: 600 },
  { mask: 1, id: "casa-manteca", duration: 2800 },
  { mask: 0, duration: 400 },
  { mask: 2, duration: 600 },
  { mask: 2, id: "la-candela", duration: 3400 },
  { mask: 0, duration: 400 },
  { mask: 4, duration: 600 },
  { mask: 4, id: "mercado-central", duration: 4100 },
];

const captureCss = `
  *, *::before, *::after { animation: none !important; transition: none !important; }
  html, body { overflow: hidden; }
  .page-head { box-sizing: border-box; max-width: none; padding: 34px 30px 17px; }
  .page-head h1 { font-size: 49px; letter-spacing: -.7px; line-height: 1.1; }
  .page-head p { display: none; }
  .map-toolbar { max-width: none; padding: 0 0 11px; }
  #taste-groups { gap: 30px; }
  #taste-groups label { font-size: 21px; gap: 10px; min-height: 41px; }
  #taste-groups label .symbol { width: 18px; height: 18px; }
  .cover #taste-groups input, #taste-count, .leaflet-control-zoom, .leaflet-popup-close-button {
    display: none !important; }
  .leaflet.html-widget { box-sizing: border-box; width: calc(100% - 84px) !important;
    height: 800px !important; }
  .cover .leaflet.html-widget { height: 978px !important; }
  .cover .page-head { padding-top: 43px; padding-bottom: 20px; }
  .cover .page-head h1 { font-size: 55px; }
  .cover #taste-groups label { font-size: 23px; }
  .page-foot { font-size: 15px; padding: 13px 12px 0; line-height: 1.5; }
  .leaflet-control-attribution { font-size: 16px; padding: 3px 7px !important; }
  .leaflet-control-scale-line { font-size: 16px; padding: 4px; }
  .north { width: 41px; font-size: 17px; }
  .leaflet-popup-content { margin: 18px 22px; }
  .place-popup { font-size: 22px; line-height: 1.27; overflow: visible; max-height: none; }
  .place-popup h2 { font-size: 27px; }
  .place-popup .sources, .place-popup figcaption { font-size: 16px; }
  .place-popup img { width: 100%; max-height: 199px; object-fit: contain; background: #f8f3e8; }
  .place-popup figure { margin: 8px 0 0; }
  .cover-labels { position: absolute; z-index: 620; inset: 0; pointer-events: none; }
  .cover-label { position: absolute; color: #3b322b; font: 700 22px/1.12 Roboto,Arial,sans-serif;
    white-space: nowrap; transform: translateY(-50%); padding: 2px 4px;
    text-shadow: -1px -1px #f8f3e8, 1px -1px #f8f3e8, -1px 1px #f8f3e8, 1px 1px #f8f3e8,
      0 0 5px #fffcf5; }
  .cover-label.left { transform: translate(-100%, -50%); }
  .cover-label.market-label { font-size: 25px; }
  .cover-leader { position: absolute; height: 1px; background: #786b5d; transform-origin: left; }
  .cover .place-marker .symbol { width: 15px; height: 15px; }
  .cover .place-marker .market { width: 22px; height: 22px; }
  .cover .close-pair .symbol { width: 8px; height: 8px; border-width: 1px; }
`;

// Executed in the actual widget page after htmlwidgets has installed the map.
async function preparePage(mode, css, labels) {
  const node = document.querySelector(".leaflet.html-widget");
  const map = HTMLWidgets.find(".leaflet").getMap();
  document.body.classList.add(mode);
  const style = document.createElement("style");
  style.textContent = css;
  document.head.append(style);
  await Promise.all([document.fonts.load("400 22px Roboto"), document.fonts.load("700 59px Roboto")]);
  await document.fonts.ready;
  map.invalidateSize({ animate: false, pan: false });

  const markers = Object.values(map._layers).filter(layer => layer instanceof L.Marker);
  if (markers.length !== Object.keys(labels).length || !node.querySelector(".leaflet-overlay-pane path")) {
    throw new Error("The saved map must have all 15 markers and its vector basemap.");
  }
  const bounds = L.latLngBounds(markers.map(marker => marker.getLatLng()));
  map.fitBounds(bounds, { padding: [mode === "cover" ? 133 : 95, 124],
    maxZoom: 17.5, animate: false });
  const initial = { center: map.getCenter(), zoom: map.getZoom() };
  const byId = id => map.layerManager.getLayer("marker", id);
  if (mode === "cover") {
    const overlay = document.createElement("div");
    overlay.className = "cover-labels";
    node.append(overlay);
    for (const [id, [dx, dy, shortName]] of Object.entries(labels)) {
      const marker = byId(id);
      const { x, y } = map.latLngToContainerPoint(marker.getLatLng());
      if (id === "casa-pepe" || id === "casa-tino") marker.getElement().classList.add("close-pair");
      const leader = document.createElement("div");
      leader.className = "cover-leader";
      const length = Math.hypot(dx, dy);
      const gap = id === "mercado-central" ? 13 : 10;
      leader.style.cssText = `left:${x + dx * gap / length}px;top:${y + dy * gap / length}px;
        width:${length - gap}px;transform:rotate(${Math.atan2(dy, dx)}rad)`;
      const label = document.createElement("span");
      label.className = "cover-label" + (dx < 0 ? " left" : "") +
        (id === "mercado-central" ? " market-label" : "");
      label.textContent = shortName || marker.getElement().getAttribute("aria-label");
      label.style.cssText = `left:${x + dx}px;top:${y + dy}px`;
      overlay.append(leader, label);
    }
    const frame = node.getBoundingClientRect();
    const clippedLabels = [...overlay.querySelectorAll(".cover-label")].filter(label => {
      const r = label.getBoundingClientRect();
      return r.left <= frame.left || r.right >= frame.right ||
        r.top <= frame.top || r.bottom >= frame.bottom;
    });
    if (clippedLabels.length) {
      throw new Error("Cover labels outside the map frame: " +
        clippedLabels.map(label => label.textContent).join(", "));
    }
  }

  // Every shot starts from the same map extent. A popup may pan the map once
  // to stay inside the frame. Capture only the settled result.
  const toggles = [...document.querySelectorAll("#taste-groups input")];
  window.capturePlace = async ({ id, mask }) => {
    map.closePopup();
    map.setView(initial.center, initial.zoom, { animate: false });
    toggles.forEach((toggle, index) => { toggle.checked = Boolean(mask & (1 << index)); });
    toggles[0].dispatchEvent(new Event("change", { bubbles: true }));
    const visible = markers.filter(marker => map.hasLayer(marker));
    const expected = [0, 9, 5, 14, 2, 11, 6, 15][mask];
    if (visible.length !== expected || !visible.every(marker => map.getBounds().contains(marker.getLatLng()))) {
      throw new Error("The map does not show the expected places for filter mask " + mask);
    }
    if (id) {
      const marker = byId(id);
      if (!map.hasLayer(marker)) throw new Error("The selected popup marker is hidden: " + id);
      const popup = marker.getPopup();
      Object.assign(popup.options, { maxWidth: 437, minWidth: 390,
        autoPan: false });
      marker.openPopup();
      const image = popup.getElement().querySelector("img");
      if (id === "mercado-central") {
        if (!image) throw new Error("The market popup must contain its licensed photograph.");
      }
      if (image) await image.decode();
      popup.update();
      if (image) {
        await popup.getElement().querySelector("img").decode();
        const photoLicense = popup.getElement().querySelector("figcaption a:last-child");
        photoLicense.textContent = "CC BY-SA 2.0";
      }
      const frame = node.getBoundingClientRect();
      const card = popup.getElement().getBoundingClientRect();
      const horizontal = Math.max(0, card.right - frame.right + 24)
        - Math.max(0, frame.left + 24 - card.left);
      const vertical = Math.max(0, card.bottom - frame.bottom + 35)
        - Math.max(0, frame.top + 30 - card.top);
      map.panBy([horizontal, vertical], { animate: false });
      const settled = popup.getElement().getBoundingClientRect();
      if (settled.top < frame.top || settled.bottom > frame.bottom ||
          settled.left < frame.left || settled.right > frame.right) {
        throw new Error("Popup clipped for " + id);
      }
    }
    if (document.querySelector(".page-foot").getBoundingClientRect().bottom > innerHeight) {
      throw new Error("The export footer is clipped.");
    }
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  };
}

const staging = await mkdtemp(join(project, ".social-"));
let chrome;
let socket;
try {
  chrome = spawn(chromePath, ["--headless=new", "--disable-gpu", "--no-first-run",
    "--no-default-browser-check", "--remote-debugging-port=0",
    "--user-data-dir=" + join(staging, "profile"), "about:blank"],
  { stdio: "ignore", windowsHide: true });
  let launchError;
  chrome.on("error", error => { launchError = error; });
  let port;
  for (let attempt = 0; !port && attempt < 100; attempt++) {
    if (launchError) throw launchError;
    try {
      port = (await readFile(join(staging, "profile", "DevToolsActivePort"), "utf8")).split("\n")[0];
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      await pause(100);
    }
  }
  if (!port) throw new Error("Chrome did not start. Set CHROME_PATH to its executable.");
  const tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  socket = new WebSocket(tabs.find(tab => tab.type === "page").webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  let messageId = 0;
  const pending = new Map();
  socket.addEventListener("message", ({ data }) => {
    const response = JSON.parse(data);
    pending.get(response.id)?.(response);
  });
  function command(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++messageId;
      const timeout = setTimeout(() => {
        pending.delete(id);
        reject(new Error("Chrome timed out during " + method));
      }, 20000);
      pending.set(id, response => {
        clearTimeout(timeout);
        pending.delete(id);
        if (response.error) reject(new Error(response.error.message));
        else resolve(response.result);
      });
      socket.send(JSON.stringify({ id, method, params }));
    });
  }
  async function evaluate(expression) {
    const reply = await command("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (reply.exceptionDetails) throw new Error(reply.exceptionDetails.exception?.description);
    return reply.result.value;
  }
  async function openLayout(mode, height, deviceScaleFactor) {
    await command("Emulation.setDeviceMetricsOverride", { width: 1200, height, deviceScaleFactor, mobile: false });
    await command("Page.navigate", { url: mapUrl });
    for (let attempt = 0; attempt < 100; attempt++) {
      if (await evaluate("document.querySelector('#taste-count')?.textContent === '15 places shown'")) break;
      if (attempt === 99) throw new Error("The Leaflet export did not finish rendering.");
      await pause(100);
    }
    await evaluate(`(${preparePage})(${JSON.stringify(mode)},${JSON.stringify(captureCss)},${JSON.stringify(coverLabels)})`);
  }
  async function screenshot(name) {
    const shot = await command("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
    await writeFile(join(staging, name), Buffer.from(shot.data, "base64"));
  }
  await openLayout("cover", 1200, 2);
  await evaluate("capturePlace({ mask: 7 })");
  await screenshot("cover.png");
  await openLayout("animation", 1000, 1);
  for (const [i, scene] of scenes.entries()) {
    await evaluate(`capturePlace(${JSON.stringify(scene)})`);
    await screenshot(`scene-${i}.png`);
  }
  const encoded = spawnSync(python, [join(project, "encode_social.py"), staging,
    ...scenes.map(scene => String(scene.duration))], { stdio: "inherit" });
  if (encoded.error) throw encoded.error;
  if (encoded.status !== 0) throw new Error("GIF assembly failed.");
  await copyFile(join(staging, "cover.png"), join(outputs, stem + "-cover.png"));
  await copyFile(join(staging, "preview.gif"), join(outputs, stem + "-preview.gif"));
} finally {
  socket?.close();
  if (chrome?.pid && chrome.exitCode === null) {
    chrome.kill();
    await pause(350);
  }
  await rm(staging, { recursive: true, force: true, maxRetries: 8, retryDelay: 250 });
}
