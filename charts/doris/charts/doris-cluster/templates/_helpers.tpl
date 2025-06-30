{{/*
Expand the name of the chart.
*/}}
{{- define "doris-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "doris-cluster.fullname" -}}
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
{{- define "doris-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "doris-cluster.labels" -}}
helm.sh/chart: {{ include "doris-cluster.chart" . }}
{{ include "doris-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "doris-cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "doris-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "doris-cluster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "doris-cluster.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* 
CommonSpec template for DorisDisaggregatedCluster components
This template renders all fields from the CommonSpec API
*/}}
{{- define "doris-cluster.commonSpec" -}}
{{- $componentValues := .componentValues -}}
{{- $root := .root -}}

{{- with $componentValues.replicas }}
replicas: {{ . }}
{{- end }}
{{- with $componentValues.image }}
image: {{ . }}
{{- end }}
{{- with $componentValues.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.startTimeout }}
startTimeout: {{ . }}
{{- end }}
{{- with $componentValues.liveTimeout }}
liveTimeout: {{ . }}
{{- end }}
{{- with $componentValues.requests }}
requests:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.limits }}
limits:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.labels }}
labels:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.annotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.logNotStore }}
logNotStore: {{ . }}
{{- end }}
{{- with $componentValues.persistentVolumes }}
persistentVolumes:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.service }}
service:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if or $componentValues.configMaps $componentValues.conf }}
configMaps:
  {{- with $componentValues.configMaps }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with $componentValues.conf }}
  - name: {{ if eq $componentValues.component "ms" }}ms-configmap{{ else if eq $componentValues.component "fe" }}fe-configmap{{ else if eq $componentValues.component "cn" }}be-configmap-{{ $componentValues.uniqueId | replace "_" "-" }}{{ end }}
    mountPath: /etc/doris
  {{- end }}
{{- end }}
{{- with $componentValues.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccount: {{ include "doris-cluster.serviceAccountName" $root }}
{{- with $componentValues.hostAliases }}
hostAliases:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.securityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.containerSecurityContext }}
containerSecurityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.envVars }}
envVars:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.envFrom }}
envFrom:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.systemInitialization }}
systemInitialization:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $componentValues.secrets }}
secrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if or $componentValues.initContainers (and $root.Values.authProxy.enabled (or (eq $componentValues.component "fe") (eq $componentValues.component "cn") ) ) }}
initContainers:
  {{- with $componentValues.initContainers }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- if and $root.Values.authProxy.enabled (or (eq $componentValues.component "fe") (eq $componentValues.component "cn") ) }}
  {{- if eq (include "auth_proxy.has_cloud_sql" $root) "true" }}
  {{- include "auth_proxy.cloud_sql" $root | nindent 2 }}
  {{- end }}
  {{- if eq (include "auth_proxy.has_alloydb" $root) "true" }}
  {{- include "auth_proxy.alloydb" $root | nindent 2 }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Determine if cloud_sql is present */}}
{{- define "auth_proxy.has_cloud_sql" -}}
{{- $has_cloud_sql := false -}}
{{- range .Values.authProxy.datasources -}}
  {{- if and .auth_proxy (eq .auth_proxy "cloud_sql") -}}
    {{- $has_cloud_sql = true -}}
  {{- end -}}
{{- end -}}
{{ $has_cloud_sql }}
{{- end -}}

{{/* Determine if alloydb is present */}}
{{- define "auth_proxy.has_alloydb" -}}
{{- $has_alloydb := false -}}
{{- range .Values.authProxy.datasources -}}
  {{- if and .auth_proxy (eq .auth_proxy "alloydb") -}}
    {{- $has_alloydb = true -}}
  {{- end -}}
{{- end -}}
{{ $has_alloydb }}
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
  {{- range $index, $element := .Values.authProxy.datasources }}
    {{- if and .auth_proxy (eq .auth_proxy "cloud_sql") }}
    - {{ .instance_uri -}}?port={{- 10000 | add $index | add1 }}
    {{- end }}
  {{- end }}
  restartPolicy: Always
  securityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    runAsUser: 65534
    runAsGroup: 65534
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: RuntimeDefault
  {{- if .Values.authProxy.resources }}
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
  {{- range $index, $element := .Values.authProxy.datasources }}
    {{- if and .auth_proxy (eq .auth_proxy "alloydb") }}
    - {{ .instance_uri -}}?port={{- 10000 | add $index | add1 }}
    {{- end }}
  {{- end }}
  restartPolicy: Always
  {{- with .Values.authProxy.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.authProxy.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
