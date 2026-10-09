# Capa gitops-bootstrap · Argo CD + aplicación raíz. Migración incremental: Argo CD gobierna lo que
# declara el overlay eks-ephemeral (instrumentación, SLO y workloads); las capas 00 y 10 siguen en
# Terraform hasta el cutover (overlay eks-ephemeral-full). Reemplaza a la capa 20-onboarding.
module "argocd" {
  source = "../../../modules/argocd-bootstrap"

  gitops_repo_url = var.gitops_repo_url
  target_revision = var.gitops_target_revision
  root_path       = "bootstrap/applications/overlays/eks-ephemeral"

  # UI pública con allowlist, mismo patrón que Grafana (NLB con tags del entorno)
  server_service = {
    type          = "LoadBalancer"
    source_ranges = var.admin_cidrs
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"                     = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = join(",", [for k, v in local.ephemeral_tags : "${k}=${v}"])
    }
  }
}

data "kubernetes_service_v1" "argocd" {
  metadata {
    name      = module.argocd.server_service_name
    namespace = module.argocd.namespace
  }

  depends_on = [module.argocd]
}
