resource "helm_release" "cert_manager" {
  count = var.install_cert_manager ? 1 : 0

  name             = "cert-manager"
  namespace        = var.cert_manager_namespace
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  wait             = true
  timeout          = 600

  values = [yamlencode({
    crds = { enabled = true, keep = true }
  })]
}

resource "helm_release" "operator" {
  name             = "opentelemetry-operator"
  namespace        = var.operator_namespace
  create_namespace = true
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-operator"
  version          = var.operator_chart_version
  wait             = true
  timeout          = 600

  values = [yamlencode({
    # El webhook de inyección lo sirven todas las réplicas (no solo el líder): HA del onboarding
    replicaCount = var.replicas
    pdb          = { create = var.replicas > 1, minAvailable = 1 }

    manager = {
      collectorImage           = var.collector_image
      autoInstrumentationImage = { java = var.java_agent_image }
      # Sin requests el pod es BestEffort: bajo contención pierde el leader election y se reinicia
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { memory = "256Mi" }
      }
    }
    admissionWebhooks = {
      certManager = { enabled = true }
    }
  })]

  depends_on = [helm_release.cert_manager]
}
