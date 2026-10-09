# Vertical de Pagos · F1 piloto. Cero cambios en el código de las aplicaciones.
module "pagos" {
  source = "../../../modules/java-autoinstrumentation"

  namespace      = "pagos"
  team           = "tribu-pagos"
  migration_wave = "F1-piloto"

  workloads = {
    payments-qr = { image = "bancoplus/payments-qr:1.0.0", env = { FRAUD_API_URL = "http://fraud-api" } }
    fraud-api   = { image = "bancoplus/payments-qr:1.0.0" }
  }
}

# SLO como código: reglas, alertas multiventana y dashboard de Error Budget
module "pagos_slo" {
  source = "../../../modules/slo-burn-rate-alerts"

  slo_file  = "${path.module}/../../../slo/payments-qr.yaml"
  namespace = module.pagos.namespace
  profile   = "poc"
}
