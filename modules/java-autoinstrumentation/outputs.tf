output "namespace" {
  description = "Namespace instrumentado."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "instrumentation" {
  description = "Recurso Instrumentation aplicado (namespace/nombre)."
  value       = "${kubernetes_namespace_v1.this.metadata[0].name}/${helm_release.instrumentation.name}"
}

output "services" {
  description = "Services internos de las cargas desplegadas."
  value       = { for k, s in kubernetes_service_v1.workload : k => "http://${s.metadata[0].name}.${s.metadata[0].namespace}.svc.cluster.local" }
}
