locals {
  slo     = yamldecode(file(var.slo_file))
  window  = local.slo.profiles[var.profile]
  service = local.slo.service
  owner   = local.slo.owner

  selector = join(",", [for k, v in local.slo.selector : "${k}=\"${v}\""])
  calls    = var.metrics.calls

  windows = distinct([
    local.window.fast_burn.long, local.window.fast_burn.short,
    local.window.slow_burn.long, local.window.slow_burn.short,
    local.window.budget_window,
  ])

  slis = {
    for name, sli in local.slo.slis : name => {
      # Formateado: la aritmética de precisión arbitraria de Terraform produce decimales ilegibles
      budget = format("%.6g", (100 - sli.objective) / 100)
      labels = { slo_service = local.service, slo_sli = name }
      # Fracción de eventos malos por ventana. availability: estado normalizado por el Gateway
      # (no el código HTTP). latency: requests por encima del umbral del SLO.
      ratio = {
        for w in local.windows : w => (
          name == "availability"
          ? "(sum(rate(${local.calls}{${local.selector},status_code=\"STATUS_CODE_ERROR\"}[${w}])) or vector(0)) / sum(rate(${local.calls}{${local.selector}}[${w}]))"
          : "1 - (sum(rate(${var.metrics.histogram}_bucket{${local.selector},le=~\"${sli.threshold_ms}|${sli.threshold_ms}.0\"}[${w}])) / sum(rate(${var.metrics.histogram}_count{${local.selector}}[${w}])))"
        )
      }
    }
  }

  recording_rules = flatten([
    for name, sli in local.slis : concat(
      [for w, expr in sli.ratio : { record = "slo:sli_error:ratio_rate${w}", expr = expr, labels = sli.labels }],
      [
        { record = "slo:objective:ratio", expr = "vector(${format("%.6g", local.slo.slis[name].objective / 100)})", labels = sli.labels },
        {
          record = "slo:error_budget_remaining:ratio"
          expr   = "1 - (slo:sli_error:ratio_rate${local.window.budget_window}{slo_service=\"${local.service}\",slo_sli=\"${name}\"} / ${sli.budget})"
          labels = sli.labels
        },
      ],
    )
  ])

  rule_groups = [
    { name = "slo:${local.service}:recording", interval = "30s", rules = local.recording_rules },
    { name = "slo:${local.service}:alerts", rules = local.alert_rules },
  ]

  alert_rules = flatten([
    for name, sli in local.slis : [
      for burn in [
        { alert = "SLOFastBurn", cfg = local.window.fast_burn, severity = "page" },
        { alert = "SLOSlowBurn", cfg = local.window.slow_burn, severity = "ticket" },
        ] : {
        alert = burn.alert
        expr = join("\nand\n", [
          for w in [burn.cfg.long, burn.cfg.short] :
          "slo:sli_error:ratio_rate${w}{slo_service=\"${local.service}\",slo_sli=\"${name}\"} > (${burn.cfg.threshold} * ${sli.budget})"
        ])
        labels = merge(sli.labels, {
          severity = burn.severity
          team     = local.owner
          journey  = local.slo.journey
        })
        annotations = {
          summary     = "${local.service}: ${name} quema el Error Budget a ≥ ${burn.cfg.threshold}x (ventanas ${burn.cfg.long}/${burn.cfg.short})"
          description = "Fracción de eventos malos en ${burn.cfg.short}: {{ $value | humanizePercentage }}. Objetivo ${local.slo.slis[name].objective}%. Mitigar primero: rollback del último release."
          runbook_url = var.runbook_url
        }
      }
    ]
  ])
}

resource "kubernetes_manifest" "rules" {
  count = var.prometheus_rule_enabled ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "slo-${local.service}"
      namespace = var.namespace
      labels    = { team = local.owner, "app.kubernetes.io/managed-by" = "reliability-platform" }
    }
    spec = { groups = local.rule_groups }
  }
}
