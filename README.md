# Actividad 3 — Microservicio en Kubernetes (Helm + ArgoCD + CI/CD)

Trabajo de la asignatura **Arquitectura de Software**: despliegue de un
microservicio Node.js en un clúster Kubernetes local con **Docker**, **Helm**,
**ArgoCD** (GitOps) y **GitHub Actions**.

> La documentación completa (arquitectura, paso a paso, guión de video y mapeo a rúbrica) está en [`docs/README.md`](docs/README.md).

## Resumen

| Componente       | Dónde                                  |
|------------------|----------------------------------------|
| Microservicio    | `app/server.js`, `app/Dockerfile`       |
| Docker           | imagen multi-stage, non-root            |
| Helm             | `helm/microservicio/` (values dev+qa)   |
| ArgoCD           | `argocd/application*.yaml`              |
| CI/CD            | `.github/workflows/ci-cd.yaml`         |
| Clúster local    | `kind-config.yaml` (kind Kubernetes)    |

## Quickstart

```bash
make install-deps            # instala kubectl, helm, kind, argocd CLI
make cluster-up              # levanta clúster kind
make build load              # construye y carga la imagen del microservicio
make argocd-up argocd-apps   # instalo ArgoCD y registro las Applications
kubectl get applications -n argocd
curl -s localhost:30080/api  # -> JSON del microservicio en DEV
```

Password admin de ArgoCD:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Más detalles en [`docs/README.md`](docs/README.md).