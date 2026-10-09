# Capa 10 · Telemetría sobre EKS. Mismos módulos que local-minikube; cambian la exposición de
# Grafana (NLB con allowlist) y la persistencia (EBS gp3).

resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name   = "observability"
    labels = { "app.kubernetes.io/part-of" = "reliability-platform" }
  }
}

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
  retention              = "72h"

  grafana_service = {
    type          = "LoadBalancer"
    source_ranges = var.admin_cidrs
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
      # El balanceador lo crea Kubernetes, no Terraform: el TTL viaja por anotación
      "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = join(",", [for k, v in local.ephemeral_tags : "${k}=${v}"])
    }
  }

  persistence = { enabled = true, storage_class = "gp3" }
}

module "otel_gateway" {
  source = "../../../modules/otel-gateway"

  namespace        = kubernetes_namespace_v1.observability.metadata[0].name
  create_namespace = false
  replicas         = 2

  pii_hash_salt = random_password.pii_hash_salt.result

  legacy_apm = {
    enabled  = true
    endpoint = module.backends.legacy_apm_otlp_http_endpoint
  }
  legacy_apm_api_token = "ephemeral-standin"

  otel_backend_endpoint   = module.backends.otel_backend_otlp_grpc_endpoint
  otel_backend_insecure   = true
  service_monitor_enabled = true

  depends_on = [module.backends]
}

module "otel_node_agent" {
  source = "../../../modules/otel-node-agent"

  namespace                     = kubernetes_namespace_v1.observability.metadata[0].name
  gateway_loadbalancing_service = module.otel_gateway.loadbalancing_service

  depends_on = [module.otel_gateway]
}

data "kubernetes_service_v1" "grafana" {
  metadata {
    name      = module.backends.grafana_service_name
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
  }

  depends_on = [module.backends]
}
