# Bootstrap de GitOps: Terraform instala Argo CD y la aplicación raíz. A partir de aquí, el estado
# del clúster lo declara el repositorio GitOps y lo reconcilia Argo CD (App of Apps).

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  wait             = true
  timeout          = 600

  values = [yamlencode({
    configs = {
      cm = {
        # Las sync waves entre Application solo esperan la salud de las hijas con este health check
        "resource.customizations.health.argoproj.io_Application" = <<-LUA
          hs = {}
          hs.status = "Progressing"
          hs.message = ""
          if obj.status ~= nil and obj.status.health ~= nil then
            hs.status = obj.status.health.status
            if obj.status.health.message ~= nil then
              hs.message = obj.status.health.message
            end
          end
          return hs
        LUA
      }
      # Acceso por port-forward en el entorno efímero; TLS en el ingress corporativo en producción
      params = { "server.insecure" = true }
    }

    # Componentes no utilizados: menor costo y menor superficie de ataque
    dex           = { enabled = false }
    notifications = { enabled = false }

    controller = { resources = { requests = { cpu = "100m", memory = "256Mi" }, limits = { memory = "1Gi" } } }
    repoServer = { resources = { requests = { cpu = "50m", memory = "128Mi" }, limits = { memory = "512Mi" } } }
    server = {
      resources = { requests = { cpu = "50m", memory = "64Mi" }, limits = { memory = "256Mi" } }
      service = {
        type                     = var.server_service.type
        annotations              = var.server_service.annotations
        loadBalancerSourceRanges = var.server_service.source_ranges
      }
    }
  })]
}

resource "helm_release" "root" {
  name       = "root-application"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  # Al destruir, espera que Argo CD elimine las aplicaciones hijas (finalizer) antes de desinstalarse
  wait = true

  values = [yamlencode({
    applications = {
      root = {
        namespace  = var.namespace
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.target_revision
          path           = var.root_path
        }
        destination = { server = "https://kubernetes.default.svc", namespace = var.namespace }
        syncPolicy  = { automated = { prune = true, selfHeal = true } }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
