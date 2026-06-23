{{/*
  _helpers.tpl — Funciones reutilizables del chart de Helm.

  Centralizar labels/selectores evita errores tipográficos entre Deployment,
  Service, HPA, etc. Permite cambiar la convención en un solo lugar.
*/}}

{{/*
  Nombre completo de los recursos: release-chart para evitar colisiones entre
  releases instalados en el mismo namespace (ms-dev, ms-qa, ...).
*/}}
{{- define "microservicio.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
  Etiquetas comunes (labels) que todos los recursos deben llevar.
  Helm/Chart labels sirven para que `helm list` y ArgoCD identifiquen el release.
  app.kubernetes.io/* siguen la convención推荐ada de K8s.
*/}}
{{- define "microservicio.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "microservicio.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.app.version | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/environment: {{ .Values.app.env | quote }}
{{- end -}}

{{/*
  Selector labels: éstas SÓLO deben contener claves estables que no cambien
  entre deploys (de lo contrario, Helm fallaría al actualizar al no matchear).
  El entorno va en una label aparte para poder filtrar pods por namespace.
*/}}
{{- define "microservicio.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
  Env vars comunes derivadas de app.values: usadas por deployment y configmap
  para que las sondas y los endpoints arrojen datos coherentes.
*/}}
{{- define "microservicio.env" -}}
- name: APP_ENV
  valueFrom:
    configMapKeyRef:
      name: {{ include "microservicio.fullname" . }}
      key: APP_ENV
- name: APP_VERSION
  valueFrom:
    configMapKeyRef:
      name: {{ include "microservicio.fullname" . }}
      key: APP_VERSION
- name: APP_MESSAGE
  valueFrom:
    configMapKeyRef:
      name: {{ include "microservicio.fullname" . }}
      key: APP_MESSAGE
- name: APP_PORT
  value: "3000"
{{- end -}}