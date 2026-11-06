{{- define "wpwin.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "wpwin.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "wpwin.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ include "wpwin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Usage: include "wpwin.selectorLabels" (dict "ctx" $ "component" "mysql") */}}
{{- define "wpwin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wpwin.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "wpwin.phpImage" -}}
{{- printf "%s:%s" .Values.images.php.repository (.Values.images.php.tag | default (toString .Values.windows.version)) -}}
{{- end -}}

{{- define "wpwin.mysqlImage" -}}
{{- printf "%s:%s" .Values.images.mysql.repository (.Values.images.mysql.tag | default (toString .Values.windows.version)) -}}
{{- end -}}

{{- define "wpwin.mysqlHost" -}}
{{- printf "%s-mysql.%s.svc.cluster.local" (include "wpwin.fullname" .) .Release.Namespace -}}
{{- end -}}

{{- define "wpwin.wordpressUrl" -}}
{{- printf "http://%s-wordpress.%s.svc.cluster.local:%v" (include "wpwin.fullname" .) .Release.Namespace .Values.wordpress.service.port -}}
{{- end -}}

{{/*
Windows Server release -> build, matching the node.kubernetes.io/windows-build label.
*/}}
{{- define "wpwin.nodeBuild" -}}
{{- $builds := dict "2019" "10.0.17763" "2022" "10.0.20348" "2025" "10.0.26100" -}}
{{- $v := toString .Values.windows.nodeVersion -}}
{{- if not (hasKey $builds $v) -}}
{{- fail (printf "windows.nodeVersion %q is not one of 2019, 2022, 2025" $v) -}}
{{- end -}}
{{- get $builds $v -}}
{{- end -}}

{{/*
Process isolation requires the image build to match the node build. An older image can
run on a newer node with Hyper-V isolation; a newer image can never run on an older node.
*/}}
{{- define "wpwin.runtimeClassName" -}}
{{- $image := int (toString .Values.windows.version) -}}
{{- $node := int (toString .Values.windows.nodeVersion) -}}
{{- if gt $image $node -}}
{{- fail (printf "ltsc%d images cannot run on an ltsc%d node" $image $node) -}}
{{- end -}}
{{- if .Values.windows.runtimeClassName -}}
{{- .Values.windows.runtimeClassName -}}
{{- else if lt $image $node -}}
{{- .Values.windows.hypervRuntimeClassName -}}
{{- end -}}
{{- end -}}

{{/* Pod-level scheduling shared by every Windows pod in the chart. */}}
{{- define "wpwin.windowsPodSpec" -}}
{{- with (include "wpwin.runtimeClassName" .) }}
runtimeClassName: {{ . }}
{{- end }}
nodeSelector:
  kubernetes.io/os: windows
  node.kubernetes.io/windows-build: {{ include "wpwin.nodeBuild" . | quote }}
  {{- with .Values.windows.nodeSelector }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- with .Values.windows.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.images.pullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/* "-d extension=mysqli -d memory_limit=256M ..." for php.exe */}}
{{- define "wpwin.phpArgs" -}}
{{- $args := list -}}
{{- range .Values.wordpress.phpExtensions -}}
{{- $args = append $args (printf "-d extension=%s" .) -}}
{{- end -}}
{{- range $k, $v := .Values.wordpress.phpIni -}}
{{- $args = append $args (printf "-d %s=%v" $k $v) -}}
{{- end -}}
{{- join " " $args -}}
{{- end -}}

{{/* ConfigMap data from a chart directory; .cmd files get CRLF line endings. */}}
{{- define "wpwin.filesAsConfig" -}}
{{- $root := .ctx -}}
{{- range $path, $_ := $root.Files.Glob .glob }}
{{- $content := $root.Files.Get $path | replace "\r\n" "\n" }}
{{- if hasSuffix ".cmd" $path }}
{{- $content = $content | replace "\n" "\r\n" }}
{{- end }}
{{ base $path }}: {{ $content | toJson }}
{{- end }}
{{- end -}}

{{- define "wpwin.sqlString" -}}
{{- . | replace "\\" "\\\\" | replace "'" "''" -}}
{{- end -}}
