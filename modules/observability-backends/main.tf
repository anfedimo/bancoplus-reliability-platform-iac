locals {
  legacy_apm_name = "apm-legacy-standin"
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version
  wait       = true
  timeout    = 900

  values = [yamlencode({
    # Componentes del control plane no expuestos en minikube
    kubeEtcd              = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeProxy             = { enabled = false }
    nodeExporter          = { enabled = false }

    # Costo del propio stack de observabilidad: cientos de reglas y scrapes que no usa la plataforma
    defaultRules  = { create = var.cluster_monitoring_enabled }
    kubeApiServer = { enabled = var.cluster_monitoring_enabled }
    kubelet       = { enabled = var.cluster_monitoring_enabled }
    coreDns       = { enabled = var.cluster_monitoring_enabled }

    prometheus = {
      prometheusSpec = {
        retention = var.retention
        # Descubre ServiceMonitor y PrometheusRule de cualquier release (Gateway, verticales)
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        resources = {
          requests = { cpu = "200m", memory = "512Mi" }
          limits   = { memory = "1536Mi" }
        }
      }
    }

    alertmanager = {
      alertmanagerSpec = {
        resources = { requests = { cpu = "20m", memory = "64Mi" } }
      }
    }

    grafana = {
      adminPassword = var.grafana_admin_password
      additionalDataSources = [
        {
          name     = "Tempo (backend OTel)"
          type     = "tempo"
          uid      = "tempo"
          url      = "http://tempo.${var.namespace}.svc.cluster.local:3200"
          access   = "proxy"
          jsonData = { serviceMap = { datasourceUid = "prometheus" }, nodeGraph = { enabled = true } }
        },
        {
          name   = "APM legado (stand-in)"
          type   = "jaeger"
          uid    = "apm-legacy"
          url    = "http://${local.legacy_apm_name}.${var.namespace}.svc.cluster.local:16686"
          access = "proxy"
        },
      ]
    }
  })]
}

resource "helm_release" "tempo" {
  name       = "tempo"
  namespace  = var.namespace
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = var.tempo_chart_version
  wait       = true
  timeout    = 300

  values = [yamlencode({
    tempo = {
      retention = var.retention
      receivers = {
        otlp = {
          protocols = {
            grpc = { endpoint = "0.0.0.0:4317" }
            http = { endpoint = "0.0.0.0:4318" }
          }
        }
      }
      resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { memory = "1Gi" }
      }
    }
  })]
}

resource "kubernetes_deployment_v1" "legacy_apm" {
  metadata {
    name      = local.legacy_apm_name
    namespace = var.namespace
    labels    = { "app.kubernetes.io/name" = local.legacy_apm_name }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { "app.kubernetes.io/name" = local.legacy_apm_name }
    }

    template {
      metadata {
        labels = { "app.kubernetes.io/name" = local.legacy_apm_name }
      }

      spec {
        container {
          name  = "jaeger"
          image = var.legacy_apm_standin_image

          port {
            name           = "otlp-http"
            container_port = 4318
          }
          port {
            name           = "ui"
            container_port = 16686
          }

          resources {
            requests = { cpu = "50m", memory = "128Mi" }
            limits   = { memory = "512Mi" }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 16686
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "legacy_apm" {
  metadata {
    name      = local.legacy_apm_name
    namespace = var.namespace
  }

  spec {
    selector = { "app.kubernetes.io/name" = local.legacy_apm_name }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
    }
    port {
      name        = "ui"
      port        = 16686
      target_port = 16686
    }
  }
}
