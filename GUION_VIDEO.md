# Guion de video — Actividad 3 K8S

**Duración objetivo:** 4-5 minutos
**Herramientas a mostrar:** terminal, navegador (GitHub + ArgoCD UI), VS Code
**Prerrequisitos:** clúster kind levantado, ArgoCD instalado, pipeline con al menos un run verde

---

## Escena 1 — Introducción y repo de GitHub (0:00 - 0:30)

**Pantalla:** Navegador en https://github.com/dsquintero/unisabana-arq-soft-actividad-3-k8s

**Guion de voz:**

> "Hola, en este video presento la Actividad 3 de Arquitectura de Software.
> El proyecto completo está en este repositorio de GitHub, que es público.
> Aquí pueden ver la estructura: el microservicio Node.js en la carpeta app,
> el chart de Helm, las aplicaciones de ArgoCD, el pipeline de CI/CD y el README
> con toda la documentación. A continuación demostraré el flujo completo:
> Docker, Helm, Kubernetes, ArgoCD y el pipeline automatizado."

**Tips:** Hacer scroll lento por el árbol de archivos. Zoom al README.

---

## Escena 2 — Clúster kind y ArgoCD (0:30 - 1:00)

**Pantalla:** Terminal

**Comandos a ejecutar:**

```bash
kubectl get nodes
kubectl get pods -n argocd
```

**Guion de voz:**

> "Empecemos verificando el clúster. Uso kind, que crea un clúster Kubernetes
> local dentro de Docker. Aquí pueden ver el nodo listo. ArgoCD ya está
> instalado en el namespace argocd con todos sus componentes corriendo.
> Lo instalé usando el chart oficial de Helm."

**Tips:** Resaltar `STATUS: Ready` y el pod `argocd-server`.

---

## Escena 3 — Despliegue con Helm y prueba del microservicio (1:00 - 1:45)

**Pantalla:** Terminal

**Comandos a ejecutar:**

```bash
kubectl get pods -n dev
kubectl get pods -n qa
curl -s localhost:30080/api | jq .
curl -s localhost:30081/api | jq .
```

**Guion de voz:**

> "El microservicio está desplegado en dos entornos usando Helm: dev y qa.
> En dev tengo dos réplicas, y en qa tengo tres réplicas con HPA e Ingress
> habilitados. Esto demuestra la personalización de Helm por entorno.
> Si hago curl al puerto 30080, que es el NodePort de dev, obtengo la respuesta
> del microservicio: el entorno dice dev y el mensaje termina en corchetes DEV.
> Si hago curl al 30081, el entorno dice qa y el mensaje cambia a QA.
> Ambos mensajes vienen del ConfigMap que genera Helm desde Git."

**Tips:** Mostrar el JSON formateado. Resaltar `environment` y `message` distintos
entre dev y qa. Mencionar que el hostname responde a un pod distinto.

---

## Escena 4 — ArgoCD UI y sincronización (1:45 - 2:30)

**Pantalla:** Navegador en http://localhost:30043 (UI de ArgoCD)

**Guion de voz:**

> "Ahora veamos ArgoCD. Esta es la interfaz de ArgoCD, donde puedo ver las dos
> Applications que definí: ms-dev y ms-qa. Ambas están en estado Synced y
> Healthy, lo que significa que el clúster está sincronizado con el repositorio
> Git. ArgoCD lee el chart de Helm desde GitHub y aplica los manifiestos
> automáticamente. Si hago clic en ms-dev, puedo ver los recursos que creó:
> el Deployment, el Service, el ConfigMap. Todo gestionado por GitOps con
> auto-sync, self-heal y prune activados."

**Tips:** Hacer clic en ms-dev. Mostrar el árbol de recursos. Resaltar
`Sync Policy: Automated`. Mostrar el `repoURL` en el detalle de la Application.

---

## Escena 5 — GitOps: cambio de ConfigMap sin tocar la imagen (2:30 - 3:15)

**Pantalla:** VS Code (editar `helm/microservicio/values-dev.yaml`)

**Comandos a ejecutar (en VS Code):**

```yaml
# Cambiar:
app:
  message: "Hola desde el microservicio K8s [DEV - Demo GitOps]"
```

```bash
git add helm/microservicio/values-dev.yaml
git commit -m "feat: cambiar mensaje dev para demo GitOps"
git push origin main
```

**Pantalla:** Terminal + ArgoCD UI

**Comandos a ejecutar:**

```bash
kubectl get pods -n dev
curl -s localhost:30080/api | jq .message
```

**Guion de voz:**

> "Para demostrar GitOps, voy a cambiar el mensaje del ConfigMap en
> values-dev.yaml. Esto no requiere reconstruir la imagen: es sólo un cambio
> de configuración. Hago commit y push. ArgoCD detecta el cambio en Git y
> actualiza el ConfigMap en el clúster. Si hago curl de nuevo, el mensaje
> ya cambió. Esto demuestra que Git es la única fuente de verdad y ArgoCD
> reconcilia el clúster automáticamente."

**Tips:** Esperar ~30s o forzar sync en la UI. Mostrar el ConfigMap actualizado
con `kubectl get configmap ms-dev-microservicio -n dev -o yaml`. Resaltar que
el pod no se recreó (sólo el ConfigMap).

---

## Escena 6 — Pipeline CI/CD en GitHub Actions (3:15 - 4:00)

**Pantalla:** Navegador en
https://github.com/dsquintero/unisabana-arq-soft-actividad-3-k8s/actions

**Guion de voz:**

> "Ahora veamos el pipeline de CI/CD. Cada vez que hago un push a main con
> cambios en el código o en Helm, GitHub Actions se dispara automáticamente.
> Aquí pueden ver la última ejecución, que fue exitosa. El pipeline tiene tres
> jobs: el primero construye la imagen, corre los tests y la publica en GHCR
> con dos tags, latest y el short SHA del commit. El segundo job actualiza el
> tag de la imagen en values-dev.yaml y hace commit del bot. Y el tercero,
> opcional, fuerza un sync en ArgoCD. Si hago clic en la ejecución, puedo ver
> cada paso verde: checkout, instalar dependencias, tests, build de Docker,
> login a GHCR, push de la imagen, bump del tag y commit."

**Tips:** Hacer clic en la run verde. Expandir el job `build` y mostrar los
steps. Mostrar el commit del bot en el historial de commits del repo.

---

## Escena 7 — Rolling update con la nueva imagen (4:00 - 4:30)

**Pantalla:** Terminal

**Comandos a ejecutar:**

```bash
kubectl get deployment ms-dev-microservicio -n dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo
kubectl get pods -n dev -w
```

**Guion de voz:**

> "Después de que el pipeline publicó la nueva imagen y el bot actualizó el
> tag en Git, ArgoCD detectó el cambio y disparó un rolling update. Puedo ver
> que la imagen del Deployment ahora apunta al tag sha del commit. Y si observo
> los pods, veo cómo se van recreando uno a uno sin downtime, gracias a la
> estrategia RollingUpdate con maxUnavailable cero. La imagen se pulleó
> directamente desde GHCR."

**Tips:** Resaltar el tag `sha-<short>` en el JSON. Mostrar `ScalingReplicaSet`
en los eventos si es visible. Ctrl+C para salir del watch.

---

## Escena 8 — Resumen y cierre (4:30 - 5:00)

**Pantalla:** Navegador en el README del repo

**Guion de voz:**

> "Para resumir, el proyecto cumple los tres criterios de la rúbrica:
> primero, el microservicio está dockerizado, con charts de Helm estructurados
> y personalizados por entorno, desplegado en Kubernetes e integrado con ArgoCD
> sin errores; segundo, el pipeline CI/CD detecta commits, construye, publica
> y despliega automáticamente vía GitOps; y tercero, el código está comentado
> y la documentación es clara y completa. Todo el código fuente está en el
> repositorio de GitHub. Muchas gracias."

**Tips:** Scroll lento por la matriz de la rúbrica al final del README.

---

## Checklist previo a grabar

- [ ] Clúster kind levantado (`kubectl get nodes` -> Ready)
- [ ] ArgoCD corriendo (`kubectl get pods -n argocd` -> todos Running)
- [ ] Image pullable desde GHCR (no ImagePullBackOff)
- [ ] Al menos un run verde en GitHub Actions
- [ ] Endpoint dev funcionando (`curl localhost:30080/healthz`)
- [ ] Endpoint qa funcionando (`curl localhost:30081/healthz`)
- [ ] `jq` instalado para JSON formateado (`sudo apt install jq` o `npm i -g jq`)
- [ ] ArgoCD UI accesible en http://localhost:30043
- [ ] Git remote configurado y push funcional (SSH)
- [ ] VS Code abierto con el repo cargado
- [ ] Terminal con fuente legible (zoom 150%+)
- [ ] Sin notificaciones del sistema durante la grabación