output "app_otlp_http_endpoint" {
  description = "Endpoint OTLP/HTTP que consumen las aplicaciones (Instrumentation de la capa 20)."
  value       = module.otel_node_agent.otlp_http_endpoint
}

output "trace_exporters" {
  description = "Destinos activos del Gateway: evidencia del estado de la migración."
  value       = module.otel_gateway.trace_exporters
}

output "red_metrics_endpoint" {
  description = "Endpoint de métricas RED del Gateway para el scraper gestionado de AMP."
  value       = module.otel_gateway.red_metrics_endpoint
}
