# Capa 00 · Prerrequisitos de plataforma: cert-manager + OpenTelemetry Operator (y sus CRDs).
# Va en un state propio: las capas 10 y 20 crean recursos sobre estos CRDs.
module "otel_operator" {
  source = "../../../modules/otel-operator"
}
