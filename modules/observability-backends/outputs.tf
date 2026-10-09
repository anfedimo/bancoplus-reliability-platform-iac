output "otel_backend_otlp_grpc_endpoint" {
  description = "Endpoint OTLP/gRPC de Tempo (backend OTel)."
  value       = "tempo.${var.namespace}.svc.cluster.local:4317"
}

output "legacy_apm_otlp_http_endpoint" {
  description = "Endpoint OTLP/HTTP del stand-in del APM legado."
  value       = "http://${kubernetes_service_v1.legacy_apm.metadata[0].name}.${var.namespace}.svc.cluster.local:4318"
}

output "prometheus_service" {
  description = "Service de Prometheus."
  value       = "kube-prometheus-stack-prometheus.${var.namespace}.svc.cluster.local:9090"
}

output "grafana_service" {
  description = "Service de Grafana."
  value       = "kube-prometheus-stack-grafana.${var.namespace}.svc.cluster.local:80"
}

output "legacy_apm_service_name" {
  description = "Nombre del Service del stand-in del APM legado."
  value       = kubernetes_service_v1.legacy_apm.metadata[0].name
}

output "grafana_service_name" {
  description = "Nombre del Service de Grafana (para resolver la URL del balanceador)."
  value       = "kube-prometheus-stack-grafana"
}
