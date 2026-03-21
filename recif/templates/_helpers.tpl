{{/*
Expand the name of the chart.
*/}}
{{- define "recif.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "recif.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "recif.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "recif.labels" -}}
helm.sh/chart: {{ include "recif.chart" . }}
{{ include "recif.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: recif
{{- end }}

{{/*
Selector labels
*/}}
{{- define "recif.selectorLabels" -}}
app.kubernetes.io/name: {{ include "recif.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component labels helper — pass a dict with Root and Component
*/}}
{{- define "recif.componentLabels" -}}
{{ include "recif.labels" .Root }}
app.kubernetes.io/component: {{ .Component }}
{{- end }}

{{/*
Component selector labels
*/}}
{{- define "recif.componentSelectorLabels" -}}
{{ include "recif.selectorLabels" .Root }}
app.kubernetes.io/component: {{ .Component }}
{{- end }}

{{/*
Database URL template
*/}}
{{- define "recif.databaseUrl" -}}
postgres://{{ .Values.postgresql.credentials.username }}:{{ .Values.postgresql.credentials.password }}@{{ include "recif.fullname" . }}-postgresql:{{ .Values.postgresql.port }}/{{ .Values.postgresql.credentials.database }}?sslmode=disable
{{- end }}

{{/*
Ollama base URL — resolution order:
  1. If .Values.ollama.baseUrl is set, use it (external / user-provided)
  2. Else if .Values.ollama.enabled, point at the in-cluster Ollama Service
  3. Else empty — the caller should omit the env var in that case
*/}}
{{- define "recif.ollamaBaseUrl" -}}
{{- if .Values.ollama.baseUrl -}}
{{ .Values.ollama.baseUrl }}
{{- else if .Values.ollama.enabled -}}
http://{{ include "recif.fullname" . }}-ollama:{{ .Values.ollama.port }}
{{- end -}}
{{- end }}

{{/*
Secrets provider — validated, with default.
Returns "inline", "external", or "none".
*/}}
{{- define "recif.secretsProvider" -}}
{{- $provider := default "inline" .Values.secrets.provider -}}
{{- $valid := list "inline" "external" "none" -}}
{{- if not (has $provider $valid) -}}
{{- fail (printf "secrets.provider must be one of %s, got: %q" (join ", " $valid) $provider) -}}
{{- end -}}
{{- $provider -}}
{{- end }}

{{/*
Agent base URL template — %s is replaced by the agent slug at runtime
*/}}
{{- define "recif.agentBaseUrl" -}}
http://%s.{{ .Values.global.teamNamespace | default "team-default" }}.svc.cluster.local:8000
{{- end }}
