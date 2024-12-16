{{/*
Expand the name of the chart.
*/}}
{{- define "helm-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "helm-chart.fullname" -}}
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
{{- define "helm-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "helm-chart.labels" -}}
helm.sh/chart: {{ include "helm-chart.chart" . }}
{{ include "helm-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helm-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helm-chart.name" . }}
app.kubernetes.io/instance: {{ template "robustName" .Release.Name }}
{{- end }}

{{/*
Create robustName that can be used as Kubernetes resource name, and as subdomain as well
\w – Latin letters, digits, underscore '_' .
\W – all but \w .
*/}}
{{- define "robustName" -}}
{{ regexReplaceAll "\\W+" . "-" | replace "_" "-" | lower | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "standardize-digest" -}}
{{- $digest := . -}}
{{- if not (hasPrefix "sha256:" $digest) -}}
{{- $digest = printf "sha256:%s" $digest -}}
{{- end -}}
{{- $digest -}}
{{- end -}}

{{/*
Create the path of the operator image to use
*/}}
{{- define "flink.imagePath" -}}
{{- if .Values.image.digest }}
{{- .Values.image.repository }}@{{ include "standardize-digest" .Values.image.digest }}
{{- else }}
{{- .Values.image.repository }}:{{ default .Chart.AppVersion .Values.image.tag }}
{{- end }}
{{- end }}

{{/* Determine if cloud_sql is present */}}
{{- define "auth_proxy.has_cloud_sql" -}}
{{- $has_cloud_sql := false -}}
{{- range .Values.sources -}}
  {{- if and .auth_proxy (eq .auth_proxy "cloud_sql") -}}
    {{- $has_cloud_sql = true -}}
  {{- end -}}
{{- end -}}
{{- $has_cloud_sql -}}
{{- end -}}

{{/* Determine if alloydb is present */}}
{{- define "auth_proxy.has_alloydb" -}}
{{- $has_alloydb := false -}}
{{- range .Values.sources -}}
  {{- if and .auth_proxy (eq .auth_proxy "alloydb") -}}
    {{- $has_alloydb = true -}}
  {{- end -}}
{{- end -}}
{{- $has_alloydb -}}
{{- end -}}

{{/* cloud-sql-auth-proxy configuration */}}
{{- define "auth_proxy.cloud_sql" -}}
- name: cloud-sql-auth-proxy
  image: asia.gcr.io/cloud-sql-connectors/cloud-sql-proxy:2
  args:
  {{- if eq .Values.authProxy.publicDB false }}
    - --private-ip
  {{- end }}
  {{- if eq .Values.authProxy.autoIAMAuthn true }}
    - --auto-iam-authn
  {{- end }}
  {{- range $index, $element := .Values.sources }}
    {{- if and .auth_proxy (eq .auth_proxy "cloud_sql") }}
    - {{ .instance_uri -}}?port={{- 10000 | add $index | add1 }}
    {{- end }}
  {{- end }}
  restartPolicy: Always
  securityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    runAsUser: 65532
    runAsGroup: 65532
    capabilities:
      drop:
        - ALL
    seccompProfile:
      type: RuntimeDefault
  {{ if .Values.authProxy.resources }}
  resources:
    {{- toYaml .Values.authProxy.resources | nindent 4 }}
  {{- end }}
{{- end -}}

{{/* alloydb-auth-proxy configuration */}}
{{- define "auth_proxy.alloydb" -}}
- name: alloydb-auth-proxy
  image: asia.gcr.io/alloydb-connectors/alloydb-auth-proxy:1
  args:
  {{- if eq .Values.authProxy.publicDB true }}
    - --public-ip
  {{- end }}
  {{- if eq .Values.authProxy.autoIAMAuthn true }}
    - --auto-iam-authn
  {{- end }}
  {{- range $index, $element := .Values.sources }}
    {{- if and .auth_proxy (eq .auth_proxy "alloydb") }}
    - {{ .instance_uri -}}?port={{- 10000 | add $index | add1 }}
    {{- end }}
  {{- end }}
  restartPolicy: Always
  securityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    runAsUser: 65532
    runAsGroup: 65532
    capabilities:
      drop:
        - ALL
    seccompProfile:
      type: RuntimeDefault
  {{ if .Values.authProxy.resources }}
  resources:
    {{- toYaml .Values.authProxy.resources | nindent 4 }}
  {{- end }}
{{- end -}}

{{- define "getDatasourceDetails" -}}
{{- $serviceAccount := .root.Values.authProxy.serviceAccount -}}
{{- $details := dict -}}
{{- range $index, $ds := .root.Values.sources -}}
  {{- if eq $ds.name $.sourceRef -}}
    {{- $host := $ds.host -}}
    {{- $port := $ds.port -}}
    {{- $username := $ds.username -}}
    {{- $password := $ds.password -}}
    {{- if $ds.auth_proxy -}}
      {{- $host = "localhost" -}}
      {{- $port = 10000 | add $index | add1 -}}
      {{- if $.root.Values.authProxy.autoIAMAuthn -}}
        {{- $password = "auto_iam_authn" -}}
        {{- if eq $ds.driver "mysql" -}}
          {{- $username = regexFind "^[^@]*" $serviceAccount -}}
        {{- else if eq $ds.driver "postgresql" -}}
          {{- $username = regexReplaceAll "\\.gserviceaccount\\.com" $serviceAccount "" -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
    {{- $details = dict "hostname" $host "port" $port "username" $username "password" $password -}}
  {{- end -}}
{{- end -}}
{{- if and (eq (len $details) 0) .sourceRef -}}
  {{- fail (printf "Datasource not found: %s" .sourceRef) -}}
{{- end -}}
{{- $details | toYaml -}}
{{- end -}}

{{- define "getSinkDetails" -}}
{{- $details := dict -}}
{{- range .root.Values.sinks -}}
  {{- if eq .name $.sinkRef -}}
    {{- $fe_host := printf "%v" .fe_host -}}
    {{- $fe_http_port := printf "%v" .fe_http_port -}}
    {{- $fe_query_port := printf "%v" .fe_query_port -}}
    {{- $username := .username -}}
    {{- $password := .password -}}
    {{- $details = dict "fenodes" (printf "%s:%s" $fe_host $fe_http_port) "jdbc-url" (printf "jdbc:mysql://%s:%s" $fe_host $fe_query_port) "username" $username "password" $password -}}
  {{- end -}}
{{- end -}}
{{- if and (eq (len $details) 0) .sinkRef -}}
  {{- fail (printf "Sink not found: %s" .sinkRef) -}}
{{- end -}}
{{- $details | toYaml -}}
{{- end -}}
