# WIP

To be used with ArgoCD Hooks for settings commit status on GitHub

Helm templates

`githubstatus.yaml`
```
{{- if .Values.argocd.enabled }}
{{- range $hook := $.Values.argocd.hooks }}
apiVersion: batch/v1
kind: Job
metadata:
  generateName: github-commit-status-
  namespace: {{ $.Values.argocd.namespace }}
  annotations:
    argocd.argoproj.io/hook: {{ $hook }}
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: github-status-post
        image: ilirbekteshi/argocd-github-status
        env:
          - name: ARGOCD_SERVER
            value: {{ $.Values.argocd.url }}
          - name: ARGOCD_APP
            value: {{ $.Values.argocd.appName }}
          - name: ARGOCD_APP_URL
            value: {{ printf "%s/applications/%s" $.Values.argocd.url $.Values.argocd.appName | quote }}
          - name: ARGOCD_ADMIN_PASS
            valueFrom:
              secretKeyRef:
                name: argo-hook-secrets
                key: argocdAdminPass
          - name: GITHUB_OWNER
            value: {{ $.Values.argocd.github.owner }}
          - name: GITHUB_REPO
            value: {{ $.Values.argocd.github.repo }}
          - name: GITHUB_TOKEN
            valueFrom:
              secretKeyRef:
                name: argo-hook-secrets
                key: githubToken
      restartPolicy: Never
  backoffLimit: 4
---
{{- end }}
{{- end }}
```

`secrets.yaml`
```
apiVersion: v1
kind: Secret
metadata:
  name: argo-hook-secrets
  namespace: {{ .Values.namespace }}
stringData:
  argocdAdminPass: ""
  githubToken: ""
```

`values.yaml`
```
argocd:
  enabled: true
  namespace:
  url:
  appName:
  github:
    owner:
    repo:
  hooks:
    - PostSync
    - PreSync
    - SyncFail
...
```