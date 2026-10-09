output "namespace" {
  description = "Namespace de Argo CD."
  value       = var.namespace
}

output "server_service_name" {
  description = "Service de la UI de Argo CD."
  value       = "argocd-server"
}

output "ui_command" {
  description = "Acceso a la UI de Argo CD (usuario admin)."
  value       = "kubectl -n ${var.namespace} port-forward svc/argocd-server 8080:80"
}

output "admin_password_command" {
  description = "Contraseña inicial del usuario admin."
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
