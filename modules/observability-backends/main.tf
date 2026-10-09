locals {
  legacy_apm_name = "apm-legacy-standin"
  pvc_class       = var.persistence.storage_class == "" ? null : var.persistence.storage_class
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
        storageSpec = var.persistence.enabled ? {
          volumeClaimTemplate = {
            spec = {
              storageClassName = local.pvc_class
              accessModes      = ["ReadWriteOnce"]
              resources        = { requests = { storage = var.persistence.prometheus_size } }
            }
          }
        } : {}
      }
    }

    alertmanager = {
      alertmanagerSpec = {
        resources = { requests = { cpu = "20m", memory = "64Mi" } }
      }
    }

    grafana = {
      adminPassword = var.grafana_admin_password

      service = {
        type                     = var.grafana_service.type
        annotations              = var.grafana_service.annotations
        loadBalancerSourceRanges = var.grafana_service.source_ranges
      }

      persistence = {
        enabled          = var.persistence.enabled
        type             = "pvc"
        storageClassName = local.pvc_class
        accessModes      = ["ReadWriteOnce"]
        size             = var.persistence.grafana_size
      }
      # Volumen RWO: RollingUpdate dejaría el pod nuevo esperando el volumen del anterior
      deploymentStrategy = { type = var.persistence.enabled ? "Recreate" : "RollingUpdate" }

      resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { memory = "512Mi" }
      }
      additionalDataSources = [
        {
          name     = "Tempo (backend OTel)"
          type     = "tempo"
          uid      = "tempo"
          url      = "http://tempo.${var.namespace}.svc.cluster.local:3200"
          access   = "proxy"
          jsonData = { serviceMap = { datasourceUid = "prometheus" }, nodeGraph = { enabled = true } }
        },
        # El APM legado se consulta en su propia consola: el plugin Jaeger de Grafana requiere la API v1,
        # eliminada en Jaeger 2.x
      ]
      # Retira el datasource de versiones anteriores (persistido en la base de Grafana con el volumen EBS)
      deleteDatasources = [{ name = "APM legado (stand-in)", orgId = 1 }]
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
    persistence = {
      enabled          = var.persistence.enabled
      storageClassName = local.pvc_class
      size             = var.persistence.tempo_size
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
    name        = local.legacy_apm_name
    namespace   = var.namespace
    annotations = var.legacy_apm_service.annotations
  }

  spec {
    type                        = var.legacy_apm_service.type
    load_balancer_source_ranges = var.legacy_apm_service.source_ranges
    selector                    = { "app.kubernetes.io/name" = local.legacy_apm_name }

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
