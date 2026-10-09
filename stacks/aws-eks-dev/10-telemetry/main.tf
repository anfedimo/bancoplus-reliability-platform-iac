# Capa 10 · Telemetría sobre EKS. Mismos módulos que local-minikube; los backends son gestionados.

resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name   = var.namespace
    labels = { "app.kubernetes.io/part-of" = "reliability-platform" }
  }
}

data "aws_secretsmanager_secret_version" "pii_hash_salt" {
  secret_id = var.secrets.pii_hash_salt
}

data "aws_secretsmanager_secret_version" "dynatrace_token" {
  secret_id = var.secrets.dynatrace_ingest_token
}

module "otel_gateway" {
  source = "../../../modules/otel-gateway"

  namespace        = kubernetes_namespace_v1.observability.metadata[0].name
  create_namespace = false
  replicas         = var.gateway_replicas

  pii_hash_salt = data.aws_secretsmanager_secret_version.pii_hash_salt.secret_string

  legacy_apm = {
    enabled  = var.legacy_apm_enabled
    endpoint = var.dynatrace_otlp_endpoint
  }
  legacy_apm_api_token = data.aws_secretsmanager_secret_version.dynatrace_token.secret_string

  otel_backend_endpoint = var.otel_backend_endpoint
  otel_backend_insecure = false

  resources = { cpu_request = "500m", memory_request = "1Gi", memory_limit = "2Gi" }
}

module "otel_node_agent" {
  source = "../../../modules/otel-node-agent"

  namespace                     = kubernetes_namespace_v1.observability.metadata[0].name
  gateway_loadbalancing_service = module.otel_gateway.loadbalancing_service

  depends_on = [module.otel_gateway]
}

# Routing de alertas SLO: cada vertical recibe las de su servicio (you build it, you run it);
# Plataforma recibe solo las que no tienen equipo dueño.
locals {
  alertmanager_config = {
    route = {
      receiver        = "plataforma"
      group_by        = ["alertname", "slo_service", "slo_sli"]
      group_wait      = "30s"
      repeat_interval = "4h"
      routes = [for team, _ in var.team_alert_topics : {
        receiver = team
        matchers = ["team=\"${team}\""]
      }]
    }
    receivers = concat(
      [{ name = "plataforma", sns_configs = [{ topic_arn = var.platform_alert_topic, sigv4 = { region = var.region } }] }],
      [for team, arn in var.team_alert_topics : {
        name = team
        sns_configs = [{
          topic_arn  = arn
          sigv4      = { region = var.region }
          subject    = "{{ .CommonLabels.severity }} · {{ .CommonAnnotations.summary }}"
          attributes = { severity = "{{ .CommonLabels.severity }}", slo_service = "{{ .CommonLabels.slo_service }}" }
        }]
      }],
    )
  }
}

resource "aws_prometheus_alert_manager_definition" "platform" {
  workspace_id = var.amp_workspace_id
  definition   = "alertmanager_config: |\n${indent(2, yamlencode(local.alertmanager_config))}"
}
