# Capa 00 · Prerrequisitos de plataforma sobre EKS. Mismo módulo que local-minikube.

# Volúmenes gp3 cifrados para Grafana, Prometheus y Tempo (driver EBS CSI de la capa cluster)
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

module "otel_operator" {
  source = "../../../modules/otel-operator"
}
