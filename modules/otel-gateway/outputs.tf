output "namespace" {
  description = "Namespace del Gateway."
  value       = local.namespace
}

output "otlp_grpc_endpoint" {
  description = "Endpoint OTLP/gRPC para agentes de nodo y collectors de tarea."
  value       = "${var.name}.${local.namespace}.svc.cluster.local:4317"
}

output "otlp_http_endpoint" {
  description = "Endpoint OTLP/HTTP."
  value       = "http://${var.name}.${local.namespace}.svc.cluster.local:4318"
}

output "loadbalancing_service" {
  description = "Service headless para el resolver k8s del exporter loadbalancing (formato servicio.namespace)."
  value       = "${kubernetes_service_v1.headless.metadata[0].name}.${local.namespace}"
}

output "red_metrics_endpoint" {
  description = "Endpoint de scrape de las métricas RED (fuente del Error Budget)."
  value       = "${var.name}.${local.namespace}.svc.cluster.local:8889"
}

output "trace_exporters" {
  description = "Destinos activos. Evidencia del estado de la migración (Dual-Shipping vs. cutover)."
  value       = local.trace_exporters
}

output "rendered_config" {
  description = "Configuración renderizada del Collector (sin secretos: se resuelven por variables de entorno)."
  value       = local.config
}
