# Capa 10 · Telemetría: backends, Gateway y agentes de nodo.
# Requiere la capa 00 (Operator y cert-manager) aplicada.

resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name   = var.namespace
    labels = { "app.kubernetes.io/part-of" = "reliability-platform" }
  }
}

# Secretos locales generados: ningún secreto reside en archivos versionados
resource "random_password" "pii_hash_salt" {
  length  = 32
  special = false
}

resource "random_password" "grafana_admin" {
  length  = 20
  special = false
}

module "backends" {
  source = "../../../modules/observability-backends"

  namespace              = kubernetes_namespace_v1.observability.metadata[0].name
  grafana_admin_password = random_password.grafana_admin.result
}

module "otel_gateway" {
  source = "../../../modules/otel-gateway"

  namespace        = kubernetes_namespace_v1.observability.metadata[0].name
  create_namespace = false
  replicas         = var.gateway_replicas

  pii_hash_salt = random_password.pii_hash_salt.result

  legacy_apm = {
    enabled  = var.legacy_apm_enabled
    endpoint = module.backends.legacy_apm_otlp_http_endpoint
  }
  legacy_apm_api_token = "local-standin"

  otel_backend_endpoint   = module.backends.otel_backend_otlp_grpc_endpoint
  otel_backend_insecure   = true
  service_monitor_enabled = true

  resources = { memory_limit = "768Mi", memory_request = "256Mi", cpu_request = "100m" }

  # El ServiceMonitor del Gateway requiere los CRDs que instala kube-prometheus-stack
  depends_on = [module.backends]
}

module "otel_node_agent" {
  source = "../../../modules/otel-node-agent"

  namespace                     = kubernetes_namespace_v1.observability.metadata[0].name
  gateway_loadbalancing_service = module.otel_gateway.loadbalancing_service

  depends_on = [module.otel_gateway]
}
