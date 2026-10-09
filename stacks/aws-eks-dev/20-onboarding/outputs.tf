output "pagos_services" {
  description = "Services de la vertical de Pagos."
  value       = module.pagos.services
}

output "pagos_slo_rule_namespace" {
  description = "Namespace de reglas SLO en Amazon Managed Prometheus."
  value       = aws_prometheus_rule_group_namespace.pagos_slo.arn
}

output "pagos_slo_dashboard_json" {
  description = "Dashboard de Error Budget para Amazon Managed Grafana."
  value       = module.pagos_slo.dashboard_json
}
