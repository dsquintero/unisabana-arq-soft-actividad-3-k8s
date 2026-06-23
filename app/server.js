/**
 * server.js — Microservicio Node.js (Express) para la Actividad 3 K8S.
 *
 * Endpoints expuestos:
 *   GET /healthz      -> sonda de vitalidad (liveness/readiness) para K8s.
 *                        Responde 200 {"status":"ok"} siempre que el proceso arriba.
 *   GET /api          -> responde con datos de la versión y el entorno where: configuración del entorno where: obtenida del ConfigMap de Helm.
 *   GET /api/:nombre  -> saludo personalizado, útil para demo en el video.
 *   GET /env          -> devuelve las variables de entorno inyectadas por el chart Helm
 * Estos endpoints permiten probar contenedor, Helm values y ArgoCD sincronizando
 * cambios en el ConfigMap sin tocar la imagen.
 *
 * Variables de entorno (inyectadas por el ConfigMap del chart de Helm):
 *   APP_PORT        -> puerto donde escucha el proceso dentro del contenedor (por defecto 3000).
 *   APP_ENV         -> nombre del entorno (dev / qa / prod).
 *   APP_VERSION     -> versión expuesta por la app (sincronizada con Chart.appVersion).
 *   APP_MESSAGE     -> mensaje configurable desde values.yaml (demostra overrides por entorno).
 */
const express = require("express");
const os = require("os");

// Puerto configurable; si no se define APP_PORT, se usa 3000.
// En el contenedor debe coincidir con containerPort del Deployment.
const PORT = process.env.APP_PORT || 3000;
const ENV = process.env.APP_ENV || "dev";
const VERSION = process.env.APP_VERSION || "1.0.0";
const MESSAGE = process.env.APP_MESSAGE || "Hola desde el microservicio K8s";

const app = express();
// healthz/JSON parsing (por si se agregan endpoints POST más adelante)
app.use(express.json());

// Middleware mínimo de logging: cada petición deja traza; útil en el video.
app.use((req, _res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// GET /healthz — usado por livenessProbe y readinessProbe del Deployment.
//   Se responde 200 siempre que express haya arrancado; ArgoCD también puede usar
//   este endpoint si se configura como health check de la app.
app.get("/healthz", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

// GET /api — información general: versión, entorno, mensaje (ConfigMap) y host (pod).
//   Se incluye el hostname del pod para evidenciar en el video cuál réplica responde
//   al hacer scale up/down con el HPA o el override values-qa.yaml.
app.get("/api", (_req, res) => {
  res.json({
    service: "microservicio-k8s",
    version: VERSION,
    environment: ENV,
    message: MESSAGE,
    hostname: os.hostname(),
    platform: process.platform,
    node: process.version,
  });
});

// GET /api/:nombre — saludo personalizado; útil para demo interactiva en el video.
app.get("/api/:nombre", (req, res) => {
  const nombre = encodeURIComponent(req.params.nombre).slice(0, 50);
  res.json({
    saludo: `Hola '${nombre}' desde el microservicio K8s`,
    environment: ENV,
    version: VERSION,
    hostname: os.hostname(),
  });
});

// GET /env — devuelve las variables APP_* inyectadas por el ConfigMap de Helm.
//   Muestra cómo cambiar values.yaml (o values-dev/values-qa) se refleja en el pod
//   sin reconstruir la imagen: patrón 12-factor y GitOps-friendly.
app.get("/env", (_req, res) => {
  const appEnv = {};
  Object.keys(process.env)
    .filter((k) => k.startsWith("APP_"))
    .forEach((k) => (appEnv[k] = process.env[k]));
  res.json({ environment: ENV, appEnv });
});

// 404 para cualquier otra ruta.
app.use((_req, res) => {
  res.status(404).json({ error: "Not Found", endpoints: ["/healthz", "/api", "/api/:nombre", "/env"] });
});

// Inicia el servidor; el bind es 0.0.0.0 porque en K8s debe escuchar en todas las
// interfaces para que el Service (ClusterIP) enrute tráfico al pod.
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Microservicio escuchando en http://0.0.0.0:${PORT} (env=${ENV}, v${VERSION})`);
});