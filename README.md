# WIP

To be used with ArgoCD Hooks for settings commit status on GitHub

## Helm templates

### `values.yaml`

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

### `secrets.yaml`

Provide either `argocdAdminPass` or `argocdToken` but recommended if you create a `GET` only Role in ArgoCD and static token.

```
apiVersion: v1
kind: Secret
metadata:
  name: argo-hook-secrets
  namespace: {{ .Values.namespace }}
stringData:
  argocdAdminPass: ""
  argocdToken: ""
  githubToken: ""
```

### `githubstatus.yaml`
```
{{- if .Values.argocd.enabled }}
{{- range $hook := $.Values.argocd.github.hooks }}
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
          - name: ARGOCD_HOOKSTATE
            value: {{ $hook }}
          - name: ARGOCD_SERVER
            value: {{ $.Values.argocd.url }}
          - name: ARGOCD_APP
            value: {{ $.Values.argocd.appName }}
          - name: ARGOCD_TOKEN
            valueFrom:
              secretKeyRef:
                name: argo-hook-secrets
                key: argocdToken
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
