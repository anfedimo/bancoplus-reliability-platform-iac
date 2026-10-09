locals {
  ingest_processors = concat(
    ["memory_limiter", "filter/probes"],
    var.business_semantics_enabled ? ["transform/business-semantics"] : [],
    ["transform/pii"],
  )

  trace_exporters = concat(
    var.legacy_apm.enabled ? ["otlp_http/dynatrace"] : [],
    ["otlp_grpc/backend-otel"],
  )

  config = templatefile("${path.module}/templates/collector-config.yaml.tftpl", {
    business_semantics_enabled = var.business_semantics_enabled
    legacy_apm_enabled         = var.legacy_apm.enabled
    legacy_apm_endpoint        = var.legacy_apm.endpoint
    otel_backend_endpoint      = var.otel_backend_endpoint
    otel_backend_insecure      = var.otel_backend_insecure
    baseline_percentage        = var.sampling.baseline_percentage
    latency_threshold_ms       = var.sampling.latency_threshold_ms
    high_value_amount          = var.sampling.high_value_amount
    span_metrics_dimensions    = var.span_metrics_dimensions
    probe_routes_regex         = var.probe_routes_regex
    ingest_processors          = local.ingest_processors
    trace_exporters            = local.trace_exporters
  })

  selector_labels = {
    "app.kubernetes.io/name"     = "opentelemetry-collector"
    "app.kubernetes.io/instance" = var.name
  }

  namespace = var.create_namespace ? kubernetes_namespace_v1.this[0].metadata[0].name : var.namespace
}

resource "kubernetes_namespace_v1" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "reliability-platform"
    }
  }
}

resource "kubernetes_secret_v1" "gateway" {
  metadata {
    name      = "${var.name}-secrets"
    namespace = local.namespace
  }

  data = {
    PII_HASH_SALT = var.pii_hash_salt
    DT_API_TOKEN  = var.legacy_apm_api_token
  }
}

resource "helm_release" "gateway" {
  name       = var.name
  namespace  = local.namespace
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.chart_version
  wait       = true
  timeout    = 300

  values = [yamlencode({
    fullnameOverride = var.name
    mode             = "deployment"
    replicaCount     = var.replicas

    image   = { repository = "otel/opentelemetry-collector-contrib", tag = var.collector_image_tag }
    command = { name = "otelcol-contrib" }

    alternateConfig = yamldecode(local.config)
    extraEnvsFrom   = [{ secretRef = { name = kubernetes_secret_v1.gateway.metadata[0].name } }]

    # Rollout ante cambios de secretos (sal de PII, token del APM)
    podAnnotations = { "checksum/secrets" = sha256(jsonencode(kubernetes_secret_v1.gateway.data)) }

    ports = {
      jaeger-compact = { enabled = false }
      jaeger-thrift  = { enabled = false }
      jaeger-grpc    = { enabled = false }
      zipkin         = { enabled = false }
      metrics        = { enabled = true }
      red-metrics    = { enabled = true, containerPort = 8889, servicePort = 8889, protocol = "TCP" }
    }

    resources = {
      requests = { cpu = var.resources.cpu_request, memory = var.resources.memory_request }
      limits   = { memory = var.resources.memory_limit }
    }

    podDisruptionBudget = { enabled = var.replicas > 1, minAvailable = 1 }

    serviceMonitor = {
      enabled          = var.service_monitor_enabled
      metricsEndpoints = [{ port = "metrics" }, { port = "red-metrics" }]
    }
  })]
}

# Resolución por pod para el exporter loadbalancing de los agentes de nodo (enrutamiento por traceID)
resource "kubernetes_service_v1" "headless" {
  metadata {
    name      = "${var.name}-headless"
    namespace = local.namespace
  }

  spec {
    cluster_ip = "None"
    selector   = local.selector_labels

    port {
      name        = "otlp"
      port        = 4317
      target_port = 4317
      protocol    = "TCP"
    }
  }
}
