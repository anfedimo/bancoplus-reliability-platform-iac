output "prometheus_rule" {
  description = "PrometheusRule generado (namespace/nombre). null si prometheus_rule_enabled = false."
  value       = var.prometheus_rule_enabled ? "${var.namespace}/slo-${local.service}" : null
}

output "rule_groups_yaml" {
  description = "Reglas en formato estándar de Prometheus para motores gestionados (Amazon Managed Prometheus, Mimir, Thanos)."
  value       = yamlencode({ groups = local.rule_groups })
}

output "dashboard_json" {
  description = "Modelo del dashboard para Grafana gestionado (Amazon Managed Grafana)."
  value       = jsonencode(local.dashboard)
}

output "recording_rules" {
  description = "Reglas de grabación generadas desde el SLO."
  value       = local.recording_rules
}

output "alert_rules" {
  description = "Alertas multiventana generadas desde el SLO."
  value       = local.alert_rules
}

output "dashboard_uid" {
  description = "UID del dashboard de Error Budget en Grafana."
  value       = var.dashboard_enabled ? local.dashboard.uid : null
}
