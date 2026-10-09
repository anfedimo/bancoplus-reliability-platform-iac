output "argocd_url" {
  description = "URL pública de Argo CD (NLB restringido a admin_cidrs)."
  value       = try("http://${data.kubernetes_service_v1.argocd.status[0].load_balancer[0].ingress[0].hostname}", "pendiente: re-ejecutar terraform refresh")
}

output "argocd_ui" {
  description = "Acceso a la UI de Argo CD."
  value       = module.argocd.ui_command
}

output "argocd_admin_password" {
  description = "Comando para obtener la contraseña inicial de admin."
  value       = module.argocd.admin_password_command
}
