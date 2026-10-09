output "grafana_url" {
  description = "URL pública de Grafana (NLB restringido a admin_cidrs). La resolución DNS del NLB tarda 2-3 minutos."
  value       = try("http://${data.kubernetes_service_v1.grafana.status[0].load_balancer[0].ingress[0].hostname}", "pendiente: re-ejecutar terraform refresh")
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}

output "app_otlp_http_endpoint" {
  value = module.otel_node_agent.otlp_http_endpoint
}

output "trace_exporters" {
  value = module.otel_gateway.trace_exporters
}
