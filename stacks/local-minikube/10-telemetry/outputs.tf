output "app_otlp_http_endpoint" {
  description = "Endpoint OTLP/HTTP que consumen las aplicaciones (Instrumentation de la capa 20)."
  value       = module.otel_node_agent.otlp_http_endpoint
}

output "app_otlp_grpc_endpoint" {
  value = module.otel_node_agent.otlp_grpc_endpoint
}

output "trace_exporters" {
  description = "Destinos activos del Gateway."
  value       = module.otel_gateway.trace_exporters
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}
