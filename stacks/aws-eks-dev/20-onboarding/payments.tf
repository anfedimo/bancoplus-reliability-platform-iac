# Vertical de Pagos · F1 piloto. Mismo contrato que local-minikube: cambian la imagen y el perfil del SLO.
module "pagos" {
  source = "../../../modules/java-autoinstrumentation"

  namespace      = "pagos"
  team           = "tribu-pagos"
  migration_wave = "F1-piloto"

  workloads = {
    payments-qr = { image = "${var.ecr_registry}/payments-qr:1.0.0", replicas = 2, env = { FRAUD_API_URL = "http://fraud-api" } }
    fraud-api   = { image = "${var.ecr_registry}/payments-qr:1.0.0", replicas = 2 }
  }
}

# SLO como código sobre motor gestionado: mismas reglas, publicadas en Amazon Managed Prometheus
module "pagos_slo" {
  source = "../../../modules/slo-burn-rate-alerts"

  slo_file                = "${path.module}/../../../slo/payments-qr.yaml"
  namespace               = module.pagos.namespace
  profile                 = "prod"
  prometheus_rule_enabled = false
  dashboard_enabled       = false
}

resource "aws_prometheus_rule_group_namespace" "pagos_slo" {
  name         = "slo-payments-qr"
  workspace_id = var.amp_workspace_id
  data         = module.pagos_slo.rule_groups_yaml
}
