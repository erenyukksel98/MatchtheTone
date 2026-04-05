import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEB_DIR = path.resolve(__dirname, "../../echoed/build/web");

const PORT = Number(process.env.PORT);
if (!PORT) throw new Error("PORT env var is required");

const MIME = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".mjs": "application/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".wasm": "application/wasm",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
};

const tryServe = (fp, res) => {
  try {
    const stat = fs.statSync(fp);
    if (stat.isDirectory()) return tryServe(path.join(fp, "index.html"), res);
    const ext = path.extname(fp).toLowerCase();
    const mime = MIME[ext] || "application/octet-stream";
    res.writeHead(200, { "Content-Type": mime, "Cache-Control": "no-cache" });
    fs.createReadStream(fp).pipe(res);
    return true;
  } catch {
    return false;
  }
};

const server = http.createServer((req, res) => {
  const urlPath = req.url.split("?")[0];
  const filePath = path.join(WEB_DIR, urlPath);

  if (!tryServe(filePath, res)) {
    const index = path.join(WEB_DIR, "index.html");
    res.writeHead(200, { "Content-Type": "text/html", "Cache-Control": "no-cache" });
    fs.createReadStream(index).pipe(res);
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Flutter web app serving on port ${PORT}`);
});
