# argocd-bootstrap

Límite de responsabilidad de Terraform en GitOps: instala Argo CD y la aplicación raíz (App of Apps).
Todo lo que corre dentro del clúster después de este punto lo declara `bancoplus-platform-gitops`.

```hcl
module "argocd" {
  source          = "../../../modules/argocd-bootstrap"
  gitops_repo_url = "https://github.com/anfedimo/bancoplus-platform-gitops.git"
  root_path       = "bootstrap/applications/overlays/eks-ephemeral"
}
```

| Decisión | Fundamento |
|---|---|
| Health check de `Application` en `argocd-cm` | Sin él, las sync waves del App of Apps no esperan la salud de las aplicaciones hijas |
| Aplicación raíz vía chart `argocd-apps` | El CRD `Application` no necesita existir en tiempo de `plan` |
| `wait = true` en la raíz | En el destroy, Argo CD elimina las hijas (finalizer) antes de desinstalarse: sin recursos huérfanos |
| Dex y notificaciones deshabilitados | Componentes sin uso en el entorno: menor costo y superficie |
