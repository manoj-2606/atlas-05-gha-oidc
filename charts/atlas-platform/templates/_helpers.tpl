{{/*
Fullname: release-name truncated to 63 chars (K8s label limit)
*/}}
{{- define "atlas-platform.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to every resource
*/}}
{{- define "atlas-platform.labels" -}}
app.kubernetes.io/name: {{ include "atlas-platform.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/*
Selector labels — used by Deployment + Service
*/}}
{{- define "atlas-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "atlas-platform.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}