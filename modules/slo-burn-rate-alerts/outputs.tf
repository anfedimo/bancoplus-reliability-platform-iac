output "prometheus_rule" {
  description = "PrometheusRule generado (namespace/nombre)."
  value       = "${var.namespace}/slo-${local.service}"
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
