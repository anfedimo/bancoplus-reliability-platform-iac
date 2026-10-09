locals {
  datasource  = { type = "prometheus", uid = "prometheus" }
  avail_sel   = "slo_service=\"${local.service}\",slo_sli=\"availability\""
  avail_bgt   = local.slis["availability"].budget
  short_w     = local.window.fast_burn.short
  http_vs_sli = "sum(rate(${local.calls}{${local.selector},http_response_status_code=~\"5..\"}[${local.short_w}])) / sum(rate(${local.calls}{${local.selector}}[${local.short_w}]))"

  dashboard = {
    uid           = "slo-${local.service}"
    title         = "SLO · ${local.service} (${local.slo.journey})"
    tags          = ["slo", "error-budget", local.owner]
    timezone      = "browser"
    schemaVersion = 39
    refresh       = "30s"
    time          = { from = "now-1h", to = "now" }
    panels = [
      {
        id         = 1, type = "stat", title = "Error Budget restante · disponibilidad (${local.window.budget_window})"
        gridPos    = { h = 6, w = 6, x = 0, y = 0 }
        datasource = local.datasource
        targets    = [{ refId = "A", expr = "clamp_min(slo:error_budget_remaining:ratio{${local.avail_sel}}, 0)" }]
        fieldConfig = { defaults = { unit = "percentunit", min = 0, max = 1, thresholds = { mode = "absolute", steps = [
        { color = "red", value = null }, { color = "orange", value = 0.25 }, { color = "green", value = 0.5 }] } } }
      },
      {
        id          = 2, type = "stat", title = "SLI disponibilidad (${local.window.budget_window}) · objetivo ${local.slo.slis.availability.objective}%"
        gridPos     = { h = 6, w = 6, x = 6, y = 0 }
        datasource  = local.datasource
        targets     = [{ refId = "A", expr = "1 - slo:sli_error:ratio_rate${local.window.budget_window}{${local.avail_sel}}" }]
        fieldConfig = { defaults = { unit = "percentunit", decimals = 3 } }
      },
      {
        id         = 3, type = "timeseries", title = "Burn rate · disponibilidad (umbral fast ${local.window.fast_burn.threshold}x)"
        gridPos    = { h = 6, w = 12, x = 12, y = 0 }
        datasource = local.datasource
        targets = [for w in [local.window.fast_burn.long, local.window.fast_burn.short] : {
          refId = "W${w}", legendFormat = "ventana ${w}", expr = "slo:sli_error:ratio_rate${w}{${local.avail_sel}} / ${local.avail_bgt}"
        }]
        fieldConfig = { defaults = { unit = "x", thresholds = { mode = "absolute", steps = [
        { color = "green", value = null }, { color = "red", value = local.window.fast_burn.threshold }] }, custom = { thresholdsStyle = { mode = "line" } } } }
      },
      {
        id         = 4, type = "timeseries", title = "Tasa de error por código HTTP vs. tasa de falla técnica real"
        gridPos    = { h = 8, w = 12, x = 0, y = 6 }
        datasource = local.datasource
        targets = [
          { refId = "A", legendFormat = "HTTP 5xx (visión por código de estado)", expr = local.http_vs_sli },
          { refId = "B", legendFormat = "Falla técnica real (SLI normalizado)", expr = "slo:sli_error:ratio_rate${local.short_w}{${local.avail_sel}}" },
        ]
        fieldConfig = { defaults = { unit = "percentunit" } }
      },
      {
        id         = 5, type = "timeseries", title = "Resultado de negocio (transacciones/s)"
        gridPos    = { h = 8, w = 12, x = 12, y = 6 }
        datasource = local.datasource
        targets = [{
          refId = "A", legendFormat = "{{business_outcome}}"
          expr  = "sum by (business_outcome) (rate(${local.calls}{${local.selector}}[${local.short_w}]))"
        }]
        fieldConfig = { defaults = { unit = "reqps", custom = { stacking = { mode = "normal" }, fillOpacity = 30 } } }
      },
    ]
  }
}

resource "kubernetes_config_map_v1" "dashboard" {
  count = var.dashboard_enabled ? 1 : 0

  metadata {
    name      = "slo-dashboard-${local.service}"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1", team = local.owner }
  }

  data = {
    "slo-${local.service}.json" = jsonencode(local.dashboard)
  }
}
