# Capa 00 · Prerrequisitos de plataforma sobre EKS. Mismo módulo que local-minikube.
module "otel_operator" {
  source = "../../../modules/otel-operator"

  # false si cert-manager ya está instalado como add-on de EKS
  install_cert_manager = var.install_cert_manager
  replicas             = 2
}
