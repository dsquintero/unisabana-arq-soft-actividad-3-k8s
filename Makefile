# ====================================================================
# Makefile — Atajos para el Ciclo de vida del laboratorio K8S.
#
# Targets principales:
#   make install-deps  -> instala kubectl/helm/kind/argocd en ~/.local/bin
#   make cluster-up    -> levanta el clúster kind
#   make cluster-down  -> borra el clúster kind
#   make build         -> construye la imagen Docker local
#   make load          -> carga la imagen en el clúster kind
#   make deploy-dev    -> despliegue manido con Helm en namespace dev
#   make deploy-qa     -> ídem qa
#   make argocd-up     -> instala ArgoCD en el clúster
#   make argocd-apps   -> apply de las Applications
#   make port-forward  -> port-forward argocd-server:8080
#   make undeploy      -> desinstala releases ms-dev y ms-qa
#   make test          -> tests locales node
# ====================================================================

CLUSTER_NAME ?= arqsoft
REGISTRY     ?= ghcr.io/dsquintero
IMAGE        ?= microservicio-k8s
TAG          ?= 1.0.0
# Variable de PATH salida para que los binarios locales esten primero
# aunque es relevante no prioriza inconvenientemente
BINDIR       ?= $(HOME)/.local/bin

.PHONY: help install-deps cluster-up cluster-down build load deploy-dev deploy-qa argocd-up argocd-apps port-forward undeploy test clean

# listar targets disponibles
help:
	@grep -E '^# *Makefile|^# *Targets' Makefile
	@awk '/^[a-zA-Z0-9_-]+:/ { sub(/:.*/, "", $$1); printf "  make %s\n", $$1 }' Makefile

# Instala las herramientas del laboratorio en ~/.local/bin (sin sudo).
install-deps:
	@mkdir -p $(BINDIR)
	@$(foreach tool, kubectl helm kind argocd, \
	  command -v $(tool) >/dev/null 2>&1 || \
	  $(MAKE) -s install-$(tool);)
	@echo "Herramientas: $$(which kubectl helm kind argocd 2>/dev/null | tr '\n' ' ')"

# Targets internos descargan los binarios
install-kubectl:
	@curl -sSL -o $(BINDIR)/kubectl https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl
	@chmod +x $(BINDIR)/kubectl
install-helm:
	@curl -sSL https://get.helm.sh/helm-v3.21.2-linux-amd64.tar.gz | tar -xz --strip-components=1 -C $(BINDIR) linux-amd64/helm
install-kind:
	@curl -sSL -o $(BINDIR)/kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
	@chmod +x $(BINDIR)/kind
install-argocd:
	@curl -sSL -o $(BINDIR)/argocd https://github.com/argoproj/argo-cd/releases/download/v2.11.2/argocd-linux-amd64
	@chmod +x $(BINDIR)/argocd

# Clúster kind
cluster-up:
	kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml
	@sleep 8
	@kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml >/dev/null 2>&1
	@kubectl patch deployment metrics-server -n kube-system --type='json' \
	  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1

cluster-down:
	kind delete cluster --name $(CLUSTER_NAME)

# Imagen y carga
build:
	docker build -t $(IMAGE):$(TAG) app/

load: build
	kind load docker-image $(IMAGE):$(TAG) --name $(CLUSTER_NAME)

# Despliegues manuides con Helm (sin ArgoCD) — para pruebas rápidas
deploy-dev:
	helm upgrade --install ms-dev ./helm/microservicio \
	  --namespace dev --create-namespace \
	  -f helm/microservicio/values-dev.yaml \
	  -f helm/microservicio/values-kind.yaml

deploy-qa:
	helm upgrade --install ms-qa ./helm/microservicio \
	  --namespace qa --create-namespace \
	  -f helm/microservicio/values-qa.yaml \
	  -f helm/microservicio/values-kind.yaml

undeploy:
	helm uninstall ms-dev --namespace dev || true
	helm uninstall ms-qa --namespace qa || true

# ArgoCD
argocd-up:
	helm repo add argo https://argoproj.github.io/argo-helm || true
	helm repo update
	helm upgrade --install argocd argo/argo-cd \
	  --namespace argocd --create-namespace \
	  --set server.service.type=NodePort \
	  --set server.service.nodePortHttp=30043 \
	  --wait
	@echo "Password admin:"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

argocd-apps:
	kubectl apply -f argocd/application.yaml -n argocd
	kubectl apply -f argocd/application-qa.yaml -n argocd

# Port-forward de ArgoCD server al host (comodidad para UI/API desde el host)
port-forward:
	@echo "ArgoCD UI en https://localhost:8080 (admin / leer secret argocd-initial-admin-secret)"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

# Tests unitarios del microservicio
test:
	npm --prefix app test

# Limpieza completa
clean: cluster-down
	rm -rf app/node_modules