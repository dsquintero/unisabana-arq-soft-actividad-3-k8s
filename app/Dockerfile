# ====================================================================
# Dockerfile — Microservicio Node.js para la Actividad 3 K8S.
# Multi-stage (builder + runner) para minimizar el tamaño de la imagen
# y reducir superficie de ataque: capa final sólo con código y node runtime.
# ====================================================================

# --- Stage 1: builder -----------------------------------------------------
# Se usa la imagen oficial slim de Node 22; instala dependencias con producción
# (sin devDependencies) para que node_modules quede más liviano y seguro.
FROM node:22-slim AS builder
WORKDIR /app

# Copia SOLO package.json + package-lock (si existiese) para aprovechar el cache
# de capas de Docker: si no cambian las dependencias, este layer se reutiliza.
COPY package.json ./

# Instala dependencias de producción. Si más adelante se añade package-lock.json,
# cambiar a `npm ci --omit=dev`. Aquí usamos `npm install` porque aún no hay lock.
RUN npm install --omit=dev --no-audit --no-fund

# --- Stage 2: runner ------------------------------------------------------
# Imagen final mínima: mismo runtime que el builder para evitar sorpresas ABI.
FROM node:22-slim AS runner

# Instala curl para que los probes HTTP y el debugging funcionen dentro del pod.
# Si se quisiese distroless, se usaría /app/server.js como entrypoint y se quitaría.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Crea usuario no-root por seguridad; K8s permite runAsNonRoot en el Pod.
WORKDIR /app

# Copia node_modules del builder y el código de la app.
COPY --from=builder /app/node_modules ./node_modules
COPY package.json server.js ./

# Usuario sin privilegios: el proceso express no correrá como root.
USER node

# APP_PORT llega del ConfigMap de Helm (values.yaml). El 3000 debe coincidir con
# containerPort del Deployment y el targetPort del Service.
ENV APP_PORT=3000
EXPOSE 3000

# Healthcheck de Docker (no reemplaza a livenessProbe/readinessProbe de K8s,
# pero es útil para `docker run` local durante la fase de pruebas).
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -fs http://localhost:3000/healthz || exit 1

# CMD forma exec (JSON) para que Node reciba SIGTERM y el Pod haga graceful shutdown.
CMD ["node", "server.js"]