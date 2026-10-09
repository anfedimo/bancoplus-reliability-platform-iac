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
    manager = {
      collectorImage           = var.collector_image
      autoInstrumentationImage = { java = var.java_agent_image }
    }
    admissionWebhooks = {
      certManager = { enabled = true }
    }
  })]

  depends_on = [helm_release.cert_manager]
}
