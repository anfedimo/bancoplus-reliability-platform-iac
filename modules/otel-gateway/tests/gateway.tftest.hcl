# Contratos del módulo. Ejecutar: terraform test (desde modules/otel-gateway)

mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  pii_hash_salt         = "test-salt-0123456789"
  otel_backend_endpoint = "tempo.observability:4317"
}

run "dual_shipping_durante_transicion" {
  command = plan

  variables {
    legacy_apm = {
      enabled  = true
      endpoint = "https://abc12345.live.dynatrace.com/api/v2/otlp"
    }
    legacy_apm_api_token = "dt0c01.test"
  }

  assert {
    condition     = output.trace_exporters == ["otlp_http/dynatrace", "otlp_grpc/backend-otel"]
    error_message = "Con legacy_apm.enabled el Gateway debe exportar a ambos destinos."
  }

  assert {
    condition     = strcontains(output.rendered_config, "Api-Token $${env:DT_API_TOKEN}")
    error_message = "El token del APM legado debe resolverse por variable de entorno, nunca embebido."
  }
}

run "cutover_f3_retira_apm_legado" {
  command = plan

  assert {
    condition     = output.trace_exporters == ["otlp_grpc/backend-otel"]
    error_message = "Con legacy_apm.enabled = false solo debe existir el backend OTel."
  }

  assert {
    condition     = !strcontains(output.rendered_config, "dynatrace")
    error_message = "Tras el cutover no debe quedar configuración del APM legado."
  }
}

run "pii_precede_a_todo_exporter" {
  command = plan

  assert {
    condition     = strcontains(output.rendered_config, "processors: [\"memory_limiter\",\"filter/probes\",\"transform/business-semantics\",\"transform/pii\"]")
    error_message = "transform/pii debe estar en el pipeline de ingesta, antes de span_metrics y de los exporters."
  }

  assert {
    condition     = strcontains(output.rendered_config, "$${env:PII_HASH_SALT}")
    error_message = "La sal de PII debe resolverse por variable de entorno."
  }
}

run "pii_cubre_email_url_encoded" {
  command = plan

  assert {
    condition     = strcontains(output.rendered_config, "(@|%40)")
    error_message = "El patrón de email debe cubrir la forma URL-encoded (%40) que registran los agentes en url.query."
  }
}

run "sampling_parametrizable" {
  command = plan

  variables {
    sampling = { baseline_percentage = 2, latency_threshold_ms = 500 }
  }

  assert {
    condition     = strcontains(output.rendered_config, "sampling_percentage: 2") && strcontains(output.rendered_config, "threshold_ms: 500")
    error_message = "La política de sampling debe reflejar las variables."
  }
}

run "rechaza_sal_debil" {
  command = plan

  variables {
    pii_hash_salt = "corta"
  }

  expect_failures = [var.pii_hash_salt]
}

run "rechaza_dual_shipping_sin_endpoint" {
  command = plan

  variables {
    legacy_apm = { enabled = true }
  }

  expect_failures = [var.legacy_apm]
}

run "rechaza_sampling_fuera_de_rango" {
  command = plan

  variables {
    sampling = { baseline_percentage = 150 }
  }

  expect_failures = [var.sampling]
}
