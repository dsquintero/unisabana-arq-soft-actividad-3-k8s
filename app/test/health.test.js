/**
 * test/health.test.js — Test mínimo que valida /healthz responde 200.
 *
 * El pipeline de GitHub Actions (Fase 5) usa `npm test` antes de construir la
 * imagen Docker. Con Node 22 usamos el test runner integrado `node --test`,
 * sin dependencias extra: elegimos supertest en un futuro sería opción, pero
 * manteniéndolo cero-dependencies simplifica el build de CI.
 *
 * El test arranca el server, hace una petición HTTP y verifica status + body.
 */
const { test } = require("node:test");
const assert = require("node:assert");
const http = require("node:http");
const { spawn } = require("node:child_process");

// Helper: espera a que el proceso stdout imprima "escuchando" (server levantó).
function waitForReady(child, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error("timeout esperando readiness del server")),
      timeoutMs
    );
    child.stdout.on("data", (d) => {
      if (d.toString().includes("escuchando")) {
        clearTimeout(timer);
        resolve();
      }
    });
    child.on("error", (e) => {
      clearTimeout(timer);
      reject(e);
    });
  });
}

function request(port, path) {
  return new Promise((resolve, reject) => {
    http
      .get(`http://127.0.0.1:${port}${path}`, (res) => {
        let body = "";
        res.on("data", (c) => (body += c));
        res.on("end", () => resolve({ status: res.statusCode, body }));
      })
      .on("error", reject);
  });
}

test("GET /healthz responde 200 status ok", async () => {
  const port = 3099;
  const env = { ...process.env, APP_PORT: port, APP_ENV: "test" };
  const child = spawn("node", ["server.js"], {
    cwd: __dirname + "/..",
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  try {
    await waitForReady(child);
    const r = await request(port, "/healthz");
    assert.strictEqual(r.status, 200);
    assert.match(r.body, /"status":"ok"/);
  } finally {
    child.kill("SIGTERM");
  }
});