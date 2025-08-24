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

{{/*
Heimdall fullname helper for parent chart - replicates the exact logic from heimdall subchart
*/}}
{{- define "parent.heimdall.fullname" -}}
{{- if .Values.heimdall.fullnameOverride }}
{{- .Values.heimdall.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "heimdall" .Values.heimdall.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
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


{{/* Get publicDB value for a source with global fallback */}}
{{- define "auth_proxy.getPublicDB" -}}
{{- $source := .source -}}
{{- $root := .root -}}
{{- if hasKey $source "publicDB" -}}
{{- $source.publicDB -}}
{{- else -}}
{{- $root.Values.authProxy.global.publicDB -}}
{{- end -}}
{{- end -}}

{{/* Get autoIAMAuthn value for a source with global fallback */}}
{{- define "auth_proxy.getAutoIAMAuthn" -}}
{{- $source := .source -}}
{{- $root := .root -}}
{{- if hasKey $source "autoIAMAuthn" -}}
{{- $source.autoIAMAuthn -}}
{{- else -}}
{{- $root.Values.authProxy.global.autoIAMAuthn -}}
{{- end -}}
{{- end -}}


{{- define "getSourceDetails" -}}
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
      {{- $port = 10000 -}}
      {{- $autoIAMAuthn := include "auth_proxy.getAutoIAMAuthn" (dict "source" $ds "root" $.root) -}}
      {{- if eq $autoIAMAuthn "true" -}}
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
  {{- fail (printf "Source not found: %s" .sourceRef) -}}
{{- end -}}
{{- $details | toYaml -}}
{{- end -}}

{{- define "getSinkDetails" -}}
{{- $details := dict -}}
{{- range .root.Values.sinks -}}
  {{- if eq .name $.sinkRef -}}
    {{- range $key, $value := . -}}
      {{- if ne $key "name" -}}
        {{- $details = set $details $key $value -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if and (eq (len $details) 0) .sinkRef -}}
  {{- fail (printf "Sink not found: %s" .sinkRef) -}}
{{- end -}}
{{- $details | toYaml -}}
{{- end -}}

{{/* Get auth proxy sidecar for a specific source */}}
{{- define "auth_proxy.single_source" -}}
{{- $sourceRef := .sourceRef -}}
{{- $root := .root -}}
{{- $sourceData := dict -}}
{{- range $source := $root.Values.sources -}}
  {{- if eq $source.name $sourceRef -}}
    {{- $sourceData = $source -}}
  {{- end -}}
{{- end -}}
{{- if and $sourceData.auth_proxy (eq $sourceData.auth_proxy "cloud_sql") -}}
{{- $publicDB := include "auth_proxy.getPublicDB" (dict "source" $sourceData "root" $root) -}}
{{- $autoIAMAuthn := include "auth_proxy.getAutoIAMAuthn" (dict "source" $sourceData "root" $root) -}}
- name: cloud-sql-auth-proxy
  image: asia.gcr.io/cloud-sql-connectors/cloud-sql-proxy:2
  args:
    {{- if eq $publicDB "false" }}
    - --private-ip
    {{- end }}
    {{- if eq $autoIAMAuthn "true" }}
    - --auto-iam-authn
    {{- end }}
    - {{ $sourceData.instance_uri }}?port=10000
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
  {{- with $root.Values.authProxy.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end -}}
{{- else if and $sourceData.auth_proxy (eq $sourceData.auth_proxy "alloydb") -}}
{{- $publicDB := include "auth_proxy.getPublicDB" (dict "source" $sourceData "root" $root) -}}
{{- $autoIAMAuthn := include "auth_proxy.getAutoIAMAuthn" (dict "source" $sourceData "root" $root) -}}
- name: alloydb-auth-proxy
  image: asia.gcr.io/alloydb-connectors/alloydb-auth-proxy:1
  args:
    {{- if eq $publicDB "true" }}
    - --public-ip
    {{- end }}
    {{- if eq $autoIAMAuthn "true" }}
    - --auto-iam-authn
    {{- end }}
    - {{ $sourceData.instance_uri }}?port=10000
  restartPolicy: Always
  {{- with $root.Values.authProxy.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end -}}
  {{- with $root.Values.authProxy.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* Check if a specific source needs auth proxy */}}
{{- define "auth_proxy.needs_proxy" -}}
{{- $sourceRef := .sourceRef -}}
{{- $root := .root -}}
{{- $needsProxy := false -}}
{{- range $root.Values.sources -}}
  {{- if eq .name $sourceRef -}}
    {{- if and .auth_proxy (or (eq .auth_proxy "cloud_sql") (eq .auth_proxy "alloydb")) -}}
      {{- $needsProxy = true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $needsProxy -}}
{{- end -}}
