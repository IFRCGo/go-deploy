{{- define "ssh-bastion.name" -}}
ssh-bastion
{{- end -}}

{{/* Common labels. `app` is also the (immutable) StatefulSet selector, so keep it stable. */}}
{{- define "ssh-bastion.labels" -}}
app: ssh-bastion
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- with .Values.environment }}
environment: {{ . | quote }}
{{- end }}
{{- end -}}
