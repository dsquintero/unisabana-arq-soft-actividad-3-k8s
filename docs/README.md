# ====================================================================
# Actividad 3 — Microservicio en Kubernetes con Helm + ArgoCD + CI/CD
# ====================================================================
Repositorio de la actividad 3 de la asignatura **Arquitectura de Software**:
despliegue de un microservicio Node.js en un clúster Kubernetes local (kind)
usando contenedores Docker, charts de Helm, ArgoCD (GitOps) y un pipeline
CI/CD con GitHub Actions.

---

## Arquitectura

```
+----------------+      push main       +-------------------+   build + push
|  Developer PC  | -------------------> |  GitHub (main)     | ------------->  GHCR
|  (local kind) |                      |  .github/workflows |                |
|       ^        |                      |  ci-cd.yaml        |                v
|       |  sync  |                      +-------------------+         +---------------+
|       | (HTTP) |        poll/git                                              | imagen sha-XXX |
+-------+--------+ ----------------+---------------+                            +---------------+
        |                          |
+-------+--------+       +---------+----------+
|  ArgoCD        |       |  kind cluster       |
|  Application   | ----> |  ns: dev, ns: qa    |
|  ms-dev ms-qa  |       |  Deployment + Svc   |
+----------------+       |  ConfigMap + HPA(qa)|
                         +---------------------+
```

### Flujo GitOps end-to-end

1. Se commitea un cambio en `main` (código o Helm values).
2. **GitHub Actions** (`.github/workflows/ci-cd.yaml`) corre:
   - `npm ci`, `npm test`.
   - `docker build` y `docker push` a GHCR con tags `latest` y `sha-<short>`.
3. El job `deploy` actualiza `image.tag` en `helm/microservicio/values-dev.yaml`
   con `sha-<short>` y commitea+pushea al repo.
4. **ArgoCD** detecta el cambio en Git y aplica los manifiestos renderizados
   del chart de Helm en el namespace **dev**.
5. El pod del microservicio baja, se recrea con la nueva imagen, sanity-check
   vía `/healthz`.

> El rol de ArgoCD es desacoplar al pipeline del clúster: el pipeline sólo se
> encarga de construir+publicar+actualizar Git; ArgoCD sincroniza Git → K8s.

---

## Estructura del repositorio

```
.
├── app/                           # microservicio Node.js + Docker
│   ├── server.js                  # Express: /healthz, /api, /api/:nombre, /env
│   ├── package.json
│   ├── Dockerfile                 # multi-stage node:22-slim, non-root
│   ├── .dockerignore
│   └── test/
│       └── health.test.js         # smoke test (Node 22 test runner)
├── helm/microservicio/            # chart de Helm
│   ├── Chart.yaml
│   ├── values.yaml                # valores por defecto
│   ├── values-dev.yaml            # override DEV (replicas=2, sin HPA)
│   ├── values-qa.yaml             # override QA (replicas=3, HPA + Ingress)
│   ├── values-kind.yaml           # override local para kind (imagen local)
│   └── templates/
│       ├── _helpers.tpl           # labels y env reutilizables
│       ├── configmap.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       └── hpa.yaml
├── argocd/
│   ├── application.yaml           # Application ms-dev (auto-sync)
│   └── application-qa.yaml        # Application ms-qa (auto-sync)
├── .github/workflows/
│   └── ci-cd.yaml                 # pipeline build + publish + bump + sync
├── kind-config.yaml               # 1 nodo control-plane + NodePorts 30080/30081/30043
├── Makefile                       # atajos de operación
└── docs/README.md                 # esta documentación
```

---

## Requisitos previos

| Herramienta  | Versión     | Instalación                                |
|--------------|-------------|--------------------------------------------|
| Docker       | >= 24       | https://docs.docker.com/get-docker/        |
| kubectl      | >= 1.30     | `make install-deps` o manual               |
| helm         | >= 3.20     | `make install-deps`                        |
| kind         | >= 0.23     | `make install-deps`                        |
| argocd CLI   | >= 2.11     | `make install-deps`                        |
| Node.js      | >= 22       | para correr local y tests                  |

Instalar todas las tools:

```bash
make install-deps
```

---

## Paso a paso (laboratorio reproducible)

### 1. Levantar el clúster kind

```bash
make cluster-up
kubectl get nodes   # debe mostrar 'Ready'
```

Incluye metrics-server (HPA para qa funciona).

### 2. Construir y cargar la imagen del microservicio

```bash
make build
make load        # docker build + kind load docker-image
```

### 3. Despliegue manual con Helm (opcional, sin ArgoCD)

```bash
make deploy-dev
make deploy-qa
kubectl get pods -n dev
kubectl get pods -n qa
curl -s localhost:30080/healthz    # -> {"status":"ok"}
curl -s localhost:30081/api         # hostname distinto a dev
```

### 4. Instalar ArgoCD y registrar Applications

```bash
make argocd-up           # instala ArgoCD en el cluster, expone NodePort 30043
make argocd-apps         # crea las Applications ms-dev y ms-qa

# UI:
#   http://localhost:30043  (admin / <password impreso por argocd-up>)
# o vía port-forward (HTTPS):
make port-forward        # https://localhost:8080
```

ArgoCD comenzará a sincronizar automáticamente (syncPolicy.automated +
selfHeal). Verifica:

```bash
kubectl get applications -n argocd
# NAME     SYNC STATUS   HEALTH STATUS
# ms-dev   Synced        Healthy
# ms-qa    Synced        Healthy
```

### 5. Pipeline CI/CD (GitHub Actions)

El workflow `.github/workflows/ci-cd.yaml` se dispara al hacer push a `main` con
cambios en `app/`, `helm/ ` o el propio workflow. Resumen:

1. **build**: `npm ci`, `npm test`, `docker build`, `docker push` a GHCR con
   tags `latest` y `sha-<short>`.
2. **deploy**: bump de `image.tag` en `values-dev.yaml` y commit/push (GitOps).
3. **sync-argocd** (opcional): `argocd app sync ms-dev`. Requiere configurar
   los secretos `ARGOCD_SERVER` y `ARGOCD_TOKEN` (ver siguiente sección).

### 6. Demo GitOps (cómo crear un cambio end-to-end)

```bash
# 1. Haz cualquier cambio, por ejemplo en app/server.js
git add .
git commit -m "feat: cambio demo"
git push origin main
# 2. Abre GitHub Actions y observa el pipeline en verde
# 3. ArgoCD verá el nuevo commit (latest tag bumped) y recreará los pods en dev
kubectl get pods -n dev -w
```

---

## Personalización por entorno (Helm values)

| Clave               | `values.yaml` | `values-dev.yaml` | `values-qa.yaml` |
|---------------------|----------------|--------------------|------------------|
| `replicaCount`      | 2              | 2                  | 3                |
| `service.type`      | ClusterIP      | NodePort (30080)   | NodePort (30081) |
| `hpa.enabled`       | true           | **false**          | **true**         |
| `ingress.enabled`   | false          | false              | **true** (ms-qa.local) |
| `resources.limits.cpu` | 250m        | 150m               | 300m             |
| `app.message`       | "Hola..."      | "...[DEV]"         | "...[QA]"        |
| `image.tag`         | 1.0.0          | latest (bump pipeline) | 1.0.0         |

El override `values-kind.yaml` (instruct recomiendo conservarlo en el repo
para la demo local) apunta `image.repository` a la imagen local cargada en el
nodo kind; al destrabar el pipeline CI/CD y publicar GHCR se puede eliminar.

---

## Secretos / variables en GitHub Actions (opcional si se usa sync inmediato)

| Nombre variable    | Descripción                                  |
|--------------------|----------------------------------------------|
| `ARGOCD_SERVER`    | `host:port` del server de ArgoCD accesible desde el runner. Para runner cloud: túnel (ngrok/cloudflared). |
| `ARGOCD_TOKEN`     | Token de ArgoCD generado con `argocd account generate-token`. |

Si no se definen, el job `sync-argocd` se salta y se confía en el polling
automático de ArgoCD (~2-3 min).

---

## Guión sugerido para el video (3-5 minutos)

1. **0:00-0:30** Mostrar el repo en GitHub y la rúbrica.
2. **0:30-1:00** `make cluster-up` + `kubectl get nodes` y `make argocd-up`.
3. **1:00-1:30** `docker build` + `kind load` + `make deploy-dev`, abrir
   `curl localhost:30080/api` y mostrar `values-dev.yaml` override.
4. **1:30-2:00** `make argocd-apps` y en la UI de ArgoCD mostrar `ms-dev`
   sincronizado en Healthy, abrir el pod y ver el ConfigMap.
5. **2:00-2:30** Editar `values-dev.yaml` (cambiar `app.message`), commitear y
   hacer push; **ArgoCD self-heal** sincroniza el ConfigMap sin tocar la imagen.
6. **2:30-3:00** Disparar el pipeline con un cambio en el código (`app/server.js`)
   y mostrar en GitHub Actions: build → tests → push GHCR → bump `values-dev.yaml`
   → commit del bot.
7. **3:00-3:30** En ArgoCD, observar cómo cambia el `image.tag` en Git y cómo
   recrea los pods con `kubectl get pods -n dev -w`.
8. **3:30-4:00** Resumen: rúbrica cumplida en sus tres criterios.

---

## Limpieza

```bash
make undeploy        # elimina los releases Helm ms-dev/ms-qa
make cluster-down    # elimina el clúster kind por completo
```

---

## Criterios de la rúbrica — cómo se cumple

| Criterio                                            | Dónde                              |
|-----------------------------------------------------|------------------------------------|
| Microservicio completamente funcional               | `app/server.js` + `Dockerfile`     |
| Correctamente dockerizado (multi-stage non-root)   | `app/Dockerfile`                   |
| Charts de Helm bien estructurados y personalizados | `helm/microservicio/**`           |
| Personalización por entorno                         | `values-dev.yaml` + `values-qa.yaml`|
| Despliegue en Kubernetes                            | kind + `deployment.yaml` + Service |
| Integración con ArgoCD sin errores                  | `argocd/application*.yaml`        |
| Pipelines completamente automatizados              | `.github/workflows/ci-cd.yaml`     |
| Detectan commits y despliegan sin errores          | trigger `push` rama `main`         |
| Código bien estructurado y comentado               | comentarios en todo el código      |
| Documentación clara y completa                     | este README + `Makefile`           |
| Video profesional que explica todo el flujo         | guión anterior                     |