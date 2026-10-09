output "pagos_services" {
  description = "Services de la vertical de Pagos."
  value       = module.pagos.services
}

output "pagos_slo_rule" {
  description = "PrometheusRule del SLO de Pagos."
  value       = module.pagos_slo.prometheus_rule
}
