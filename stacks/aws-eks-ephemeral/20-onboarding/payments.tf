# Vertical de Pagos · F1 piloto. Mismo contrato que local-minikube: cambia solo el origen de la imagen.
module "pagos" {
  source = "../../../modules/java-autoinstrumentation"

  namespace      = "pagos"
  team           = "tribu-pagos"
  migration_wave = "F1-piloto"

  workloads = {
    payments-qr = { image = "${local.registry}/bancoplus/payments-qr:1.0.0", env = { FRAUD_API_URL = "http://fraud-api" } }
    fraud-api   = { image = "${local.registry}/bancoplus/payments-qr:1.0.0" }
  }
}

module "pagos_slo" {
  source = "../../../modules/slo-burn-rate-alerts"

  slo_file  = "${path.module}/../../../slo/payments-qr.yaml"
  namespace = module.pagos.namespace
  profile   = "poc"
}

locals {
  registry = data.terraform_remote_state.cluster.outputs.ecr_registry
}
