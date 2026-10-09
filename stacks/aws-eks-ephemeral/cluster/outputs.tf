output "cluster_name" {
  description = "Nombre del clúster EKS."
  value       = module.eks.cluster_name
}

output "ecr_registry" {
  description = "Registro ECR de la cuenta (prefijo de las imágenes)."
  value       = split("/", aws_ecr_repository.images["payments-qr"].repository_url)[0]
}

output "kubeconfig_command" {
  description = "Configura kubectl con el contexto bancoplus-eks."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --profile ${var.aws_profile} --alias bancoplus-eks"
}
