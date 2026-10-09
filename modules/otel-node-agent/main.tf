locals {
  config = templatefile("${path.module}/templates/agent-config.yaml.tftpl", {
    gateway_service = var.gateway_loadbalancing_service
  })
}

resource "helm_release" "agent" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.chart_version
  wait       = true
  timeout    = 300

  values = [yamlencode({
    fullnameOverride = var.name
    mode             = "daemonset"

    image   = { repository = "otel/opentelemetry-collector-contrib", tag = var.collector_image_tag }
    command = { name = "otelcol-contrib" }

    alternateConfig = yamldecode(local.config)

    extraEnvs = [{
      name      = "K8S_NODE_NAME"
      valueFrom = { fieldRef = { fieldPath = "spec.nodeName" } }
    }]

    # RBAC explícito: k8sattributes (pods, namespaces, replicasets) y resolver k8s del loadbalancing (endpointslices)
    clusterRole = {
      create = true
      rules = [
        { apiGroups = [""], resources = ["pods", "namespaces", "nodes", "endpoints"], verbs = ["get", "list", "watch"] },
        { apiGroups = ["apps"], resources = ["replicasets", "deployments"], verbs = ["get", "list", "watch"] },
        { apiGroups = ["discovery.k8s.io"], resources = ["endpointslices"], verbs = ["get", "list", "watch"] },
      ]
    }

    # Service con internalTrafficPolicy Local (default del chart en daemonset): cada pod envía al agente de su nodo
    service = { enabled = true }

    ports = {
      jaeger-compact = { enabled = false }
      jaeger-thrift  = { enabled = false }
      jaeger-grpc    = { enabled = false }
      zipkin         = { enabled = false }
    }

    resources = {
      requests = { cpu = "50m", memory = "128Mi" }
      limits   = { memory = var.memory_limit }
    }
  })]
}
