# Contratos del módulo SLO. Ejecutar: terraform test

mock_provider "kubernetes" {}

variables {
  slo_file  = "../../slo/payments-qr.yaml"
  namespace = "pagos"
}

run "alertas_multiventana_por_sli" {
  command = plan

  assert {
    condition     = length(output.alert_rules) == 4
    error_message = "Se esperan fast y slow burn para cada SLI (disponibilidad y latencia)."
  }

  assert {
    condition     = alltrue([for a in output.alert_rules : strcontains(a.expr, "\nand\n")])
    error_message = "Toda alerta debe exigir ventana larga y corta (multiwindow) para evitar falsos positivos."
  }
}

run "fast_burn_pagina_al_equipo_dueno" {
  command = plan

  assert {
    condition = alltrue([for a in output.alert_rules :
    a.labels.team == "tribu-pagos" && a.labels.severity == (a.alert == "SLOFastBurn" ? "page" : "ticket")])
    error_message = "Fast burn = page y slow burn = ticket, enrutados al equipo dueño del SLO."
  }
}

run "ventanas_prod_del_workbook" {
  command = plan

  assert {
    condition = anytrue([for a in output.alert_rules :
    a.alert == "SLOFastBurn" && strcontains(a.expr, "ratio_rate1h") && strcontains(a.expr, "ratio_rate5m") && strcontains(a.expr, "14.4 * 0.0005")])
    error_message = "Fast burn de disponibilidad en prod: 14.4x sobre ventanas 1h y 5m con budget 0.0005."
  }
}

run "sli_usa_estado_normalizado_no_codigo_http" {
  command = plan

  assert {
    condition = anytrue([for r in output.recording_rules :
    r.labels.slo_sli == "availability" && strcontains(r.expr, "STATUS_CODE_ERROR") && !strcontains(r.expr, "http_response_status_code")])
    error_message = "El SLI de disponibilidad debe medir el estado normalizado del span, no el código HTTP."
  }
}

run "perfil_poc_comprime_ventanas" {
  command = plan

  variables {
    profile = "poc"
  }

  assert {
    condition = anytrue([for a in output.alert_rules :
    a.alert == "SLOFastBurn" && strcontains(a.expr, "ratio_rate5m") && strcontains(a.expr, "ratio_rate1m")])
    error_message = "El perfil poc debe usar las ventanas comprimidas del SLO (5m/1m)."
  }
}

run "rechaza_perfil_inexistente" {
  command = plan

  variables {
    profile = "staging"
  }

  expect_failures = [var.profile]
}

run "motor_gestionado_sin_crd" {
  command = plan

  variables {
    prometheus_rule_enabled = false
  }

  assert {
    condition     = length(kubernetes_manifest.rules) == 0 && strcontains(output.rule_groups_yaml, "SLOFastBurn")
    error_message = "Sin CRD, las reglas deben exportarse en formato estándar para el motor gestionado."
  }
}
