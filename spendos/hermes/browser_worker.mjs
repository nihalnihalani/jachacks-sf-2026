#!/usr/bin/env node
/**
 * Small dependency-free Chrome DevTools Protocol worker for SpendOS demos.
 *
 * Chrome must already expose a debugging endpoint. The worker never reads the
 * cookie store, password manager, local storage, or network authorization
 * headers. Consequential checkout controls are deliberately handed to a user.
 */

import http from "node:http";
import { URL } from "node:url";

const CDP_HTTP = (process.env.SPENDOS_CDP_URL || "http://127.0.0.1:9222").replace(/\/$/, "");
const PORT = Number(process.env.SPENDOS_BROWSER_PORT || "9223");
const HOST = process.env.SPENDOS_BROWSER_HOST || "127.0.0.1";
const MAX_BODY = 256 * 1024;
const BLOCKED_SCHEMES = new Set(["file:", "data:", "javascript:", "chrome:", "devtools:"]);
const CONSEQUENTIAL = /\b(place\s+(my\s+)?order|buy\s+now|confirm\s+(purchase|order)|pay\s+now|submit\s+payment|complete\s+(purchase|order)|subscribe)\b/i;

let session = null;
let lastScreenshot = null;
const streamClients = new Set();
let captureInFlight = false;
let streamTimer = null;

function json(res, status, value) {
  const body = Buffer.from(JSON.stringify(value));
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": body.length,
    "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": "http://localhost:8011",
  });
  res.end(body);
}

async function cdpFetch(path, options = {}) {
  const response = await fetch(`${CDP_HTTP}${path}`, options);
  if (!response.ok) {
    throw new Error(`Chrome CDP returned HTTP ${response.status}`);
  }
  return response.json();
}

function safeUrl(raw) {
  const url = new URL(String(raw));
  if (BLOCKED_SCHEMES.has(url.protocol) || !["http:", "https:"].includes(url.protocol)) {
    throw new Error("Only ordinary http and https pages are supported.");
  }
  return url.href;
}

class CdpSession {
  constructor(target) {
    this.target = target;
    this.socket = new WebSocket(target.webSocketDebuggerUrl);
    this.nextId = 1;
    this.pending = new Map();
    this.ready = new Promise((resolve, reject) => {
      this.socket.addEventListener("open", resolve, { once: true });
      this.socket.addEventListener("error", () => reject(new Error("CDP connection failed")), { once: true });
    });
    this.socket.addEventListener("message", (event) => {
      const message = JSON.parse(String(event.data));
      if (!message.id || !this.pending.has(message.id)) return;
      const { resolve, reject } = this.pending.get(message.id);
      this.pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result || {});
    });
    this.socket.addEventListener("close", () => {
      for (const { reject } of this.pending.values()) reject(new Error("CDP connection closed"));
      this.pending.clear();
    });
  }

  async send(method, params = {}) {
    await this.ready;
    const id = this.nextId++;
    const result = new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
    this.socket.send(JSON.stringify({ id, method, params }));
    return Promise.race([
      result,
      new Promise((_, reject) => setTimeout(() => reject(new Error(`CDP timeout: ${method}`)), 15000)),
    ]);
  }

  async initialize() {
    await this.send("Page.enable");
    await this.send("Runtime.enable");
    await this.send("DOM.enable");
  }
}

async function ensureSession(url = "about:blank") {
  if (session && session.socket.readyState === WebSocket.OPEN) return session;
  const targetUrl = url === "about:blank" ? url : safeUrl(url);
  let target;
  try {
    target = await cdpFetch(`/json/new?${encodeURIComponent(targetUrl)}`, { method: "PUT" });
  } catch {
    const targets = await cdpFetch("/json/list");
    target = targets.find((item) => item.type === "page" && item.webSocketDebuggerUrl);
  }
  if (!target) throw new Error("No debuggable Chrome page is available.");
  session = new CdpSession(target);
  await session.initialize();
  return session;
}

async function waitForChrome() {
  let lastError = null;
  for (let attempt = 0; attempt < 30; attempt += 1) {
    try {
      return await cdpFetch("/json/version");
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  throw lastError || new Error("Chrome CDP is unavailable.");
}

async function evaluate(expression, returnByValue = true) {
  const active = await ensureSession();
  const result = await active.send("Runtime.evaluate", {
    expression,
    returnByValue,
    awaitPromise: true,
    userGesture: true,
  });
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.text || "Page evaluation failed");
  }
  return result.result?.value;
}

async function navigate(url) {
  const href = safeUrl(url);
  const active = await ensureSession();
  await active.send("Page.navigate", { url: href });
  await new Promise((resolve) => setTimeout(resolve, 1000));
  return snapshot();
}

async function snapshot() {
  return evaluate(`(() => {
    const clean = (value) => String(value || "").replace(/\\s+/g, " ").trim();
    const visible = (el) => {
      const style = getComputedStyle(el);
      const rect = el.getBoundingClientRect();
      return style.visibility !== "hidden" && style.display !== "none" && rect.width > 0 && rect.height > 0;
    };
    const nodes = [...document.querySelectorAll("a,button,input,select,textarea,[role=button]")]
      .filter(visible).slice(0, 120).map((el, index) => ({
        ref: "e" + (index + 1),
        tag: el.tagName.toLowerCase(),
        text: clean(el.innerText || el.value || el.getAttribute("aria-label") || el.getAttribute("placeholder")).slice(0, 160),
        type: el.getAttribute("type") || "",
        disabled: !!el.disabled,
      }));
    window.__spendosRefs = nodes.map((_, index) =>
      [...document.querySelectorAll("a,button,input,select,textarea,[role=button]")].filter(visible)[index]
    );
    return {
      url: location.href,
      title: document.title,
      text: clean(document.body?.innerText).slice(0, 6000),
      elements: nodes,
    };
  })()`);
}

async function elementInfo(ref) {
  return evaluate(`(() => {
    const index = ${JSON.stringify(String(ref))}.match(/^e(\\d+)$/);
    if (!index || !window.__spendosRefs) throw new Error("Take a fresh snapshot and use an e-number reference.");
    const el = window.__spendosRefs[Number(index[1]) - 1];
    if (!el || !el.isConnected) throw new Error("The element reference is stale; take a fresh snapshot.");
    return {
      text: String(el.innerText || el.value || el.getAttribute("aria-label") || "").replace(/\\s+/g, " ").trim(),
      type: el.getAttribute("type") || "",
      tag: el.tagName.toLowerCase(),
    };
  })()`);
}

async function click(ref) {
  const info = await elementInfo(ref);
  if (CONSEQUENTIAL.test(info.text)) {
    return {
      status: "NEEDS_USER",
      reason: "A consequential checkout control requires user takeover.",
      element: info,
    };
  }
  await evaluate(`(() => {
    const match = ${JSON.stringify(String(ref))}.match(/^e(\\d+)$/);
    const el = window.__spendosRefs[Number(match[1]) - 1];
    el.scrollIntoView({block: "center"});
    el.click();
    return true;
  })()`);
  await new Promise((resolve) => setTimeout(resolve, 500));
  return { status: "CLICKED", element: info, page: await snapshot() };
}

async function typeText(ref, value) {
  const info = await elementInfo(ref);
  if (["password"].includes(info.type.toLowerCase())) {
    return { status: "NEEDS_USER", reason: "Password entry requires user takeover." };
  }
  await evaluate(`(() => {
    const match = ${JSON.stringify(String(ref))}.match(/^e(\\d+)$/);
    const el = window.__spendosRefs[Number(match[1]) - 1];
    el.focus();
    const setter = Object.getOwnPropertyDescriptor(
      el.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype,
      "value"
    )?.set;
    if (setter) setter.call(el, ${JSON.stringify(String(value))});
    else el.value = ${JSON.stringify(String(value))};
    el.dispatchEvent(new Event("input", {bubbles: true}));
    el.dispatchEvent(new Event("change", {bubbles: true}));
    return true;
  })()`);
  return { status: "TYPED", element: info };
}

async function screenshot() {
  const active = await ensureSession();
  const result = await active.send("Page.captureScreenshot", {
    format: "jpeg",
    quality: 70,
    captureBeyondViewport: false,
  });
  lastScreenshot = Buffer.from(result.data, "base64");
  broadcastFrame(lastScreenshot);
  const screenshotUrl = `http://localhost:${PORT}/screenshot.jpg?t=${Date.now()}`;
  return {
    status: "CAPTURED",
    url: screenshotUrl,
    screenshot_url: screenshotUrl,
    preview_url: `http://localhost:${PORT}/stream.mjpg`,
  };
}

async function withPreview(result) {
  const captured = await screenshot();
  return { ...result, preview_url: captured.preview_url };
}

function broadcastFrame(frame) {
  if (!frame || !streamClients.size) return;
  const header = Buffer.from(
    `--spendosframe\r\nContent-Type: image/jpeg\r\nContent-Length: ${frame.length}\r\n\r\n`
  );
  const footer = Buffer.from("\r\n");
  for (const client of [...streamClients]) {
    try {
      client.write(header);
      client.write(frame);
      client.write(footer);
    } catch {
      streamClients.delete(client);
    }
  }
}

function ensureStreamLoop() {
  if (streamTimer) return;
  streamTimer = setInterval(async () => {
    if (!streamClients.size) {
      clearInterval(streamTimer);
      streamTimer = null;
      return;
    }
    if (captureInFlight) return;
    captureInFlight = true;
    try {
      await screenshot();
    } catch {
      // A navigation can briefly invalidate a frame. The next tick retries.
    } finally {
      captureInFlight = false;
    }
  }, 350);
}

async function body(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY) throw new Error("Request body is too large.");
    chunks.push(chunk);
  }
  return chunks.length ? JSON.parse(Buffer.concat(chunks).toString("utf8")) : {};
}

const server = http.createServer(async (req, res) => {
  try {
    const path = new URL(req.url, `http://${req.headers.host}`).pathname;
    if (req.method === "GET" && path === "/health") {
      const version = await cdpFetch("/json/version");
      return json(res, 200, { status: "ok", browser: version.Browser || "Chrome", cdp: CDP_HTTP });
    }
    if (req.method === "GET" && path === "/screenshot.jpg") {
      if (!lastScreenshot) return json(res, 404, { error: "No screenshot has been captured." });
      res.writeHead(200, {
        "Content-Type": "image/jpeg",
        "Content-Length": lastScreenshot.length,
        "Cache-Control": "no-store",
        "Access-Control-Allow-Origin": "http://localhost:8011",
      });
      return res.end(lastScreenshot);
    }
    if (req.method === "GET" && path === "/stream.mjpg") {
      res.writeHead(200, {
        "Content-Type": "multipart/x-mixed-replace; boundary=spendosframe",
        "Cache-Control": "no-store, no-cache, must-revalidate",
        "Connection": "keep-alive",
        "Access-Control-Allow-Origin": "http://localhost:8011",
      });
      streamClients.add(res);
      if (lastScreenshot) broadcastFrame(lastScreenshot);
      ensureStreamLoop();
      req.on("close", () => streamClients.delete(res));
      return;
    }
    if (req.method !== "POST") return json(res, 404, { error: "Not found" });
    const input = await body(req);
    if (path === "/navigate") return json(res, 200, await withPreview(await navigate(input.url)));
    if (path === "/snapshot") return json(res, 200, await withPreview(await snapshot()));
    if (path === "/click") return json(res, 200, await withPreview(await click(input.ref)));
    if (path === "/type") return json(res, 200, await withPreview(await typeText(input.ref, input.text)));
    if (path === "/screenshot") return json(res, 200, await screenshot());
    if (path === "/takeover") {
      return json(res, 200, await withPreview({
        status: "NEEDS_USER",
        reason: String(input.reason || "The browser needs user input."),
        page: await snapshot(),
      }));
    }
    return json(res, 404, { error: "Not found" });
  } catch (error) {
    return json(res, 500, { status: "FAILED", error: String(error.message || error) });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`SpendOS browser worker listening on http://${HOST}:${PORT}`);
});

waitForChrome().catch((error) => {
  console.error(`Chrome CDP is not ready at ${CDP_HTTP}: ${error.message}`);
});
