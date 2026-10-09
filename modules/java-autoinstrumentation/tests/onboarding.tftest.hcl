# Contratos de la plantilla de autoservicio. Ejecutar: terraform test

mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  namespace      = "pagos"
  team           = "tribu-pagos"
  migration_wave = "F1-piloto"
}

run "namespace_activa_inyeccion_java" {
  command = apply

  assert {
    condition     = kubernetes_namespace_v1.this.metadata[0].annotations["instrumentation.opentelemetry.io/inject-java"] == "true"
    error_message = "El namespace debe activar la inyección del agente Java."
  }

  assert {
    condition     = kubernetes_namespace_v1.this.metadata[0].labels["migration.bancoplus.co/wave"] == "F1-piloto"
    error_message = "El namespace debe registrar la ola de migración."
  }
}

run "captura_contrato_de_negocio" {
  command = plan

  assert {
    condition     = strcontains(helm_release.instrumentation.values[0], "X-Business-Outcome")
    error_message = "El Instrumentation debe capturar las cabeceras X-Business-*."
  }
}

run "sin_workloads_por_defecto" {
  command = plan

  assert {
    condition     = length(kubernetes_deployment_v1.workload) == 0
    error_message = "Las verticales con CD propio no deben recibir Deployments del módulo."
  }
}

run "rechaza_ola_invalida" {
  command = plan

  variables {
    migration_wave = "piloto"
  }

  expect_failures = [var.migration_wave]
}

run "rechaza_java_tool_options" {
  command = plan

  variables {
    workloads = {
      app = { image = "app:1.0.0", env = { JAVA_TOOL_OPTIONS = "-javaagent:/oneagent.jar" } }
    }
  }

  expect_failures = [var.workloads]
}
