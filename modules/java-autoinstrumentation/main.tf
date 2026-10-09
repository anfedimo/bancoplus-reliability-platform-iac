locals {
  instrumentation_values = {
    exporter           = { endpoint = var.otlp_endpoint }
    resourceAttributes = { "team.tribe" = var.team, "migration.wave" = var.migration_wave }
    java = {
      captureResponseHeaders = var.business_headers
      extensions             = var.agent_extensions
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      "team"                         = var.team
      "migration.bancoplus.co/wave"  = var.migration_wave
      "app.kubernetes.io/managed-by" = "reliability-platform"
    }
    annotations = {
      # Activación por namespace: ninguna aplicación cambia código, imagen ni manifiesto
      "instrumentation.opentelemetry.io/inject-java" = "true"
    }
  }
}

resource "helm_release" "instrumentation" {
  name      = "java-zero-code"
  namespace = kubernetes_namespace_v1.this.metadata[0].name
  chart     = "${path.module}/../../charts/otel-instrumentation"
  wait      = true

  values = [yamlencode(local.instrumentation_values)]
}

resource "kubernetes_deployment_v1" "workload" {
  for_each = var.workloads

  metadata {
    name      = each.key
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { "app.kubernetes.io/name" = each.key, "team" = var.team }
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = { "app.kubernetes.io/name" = each.key }
    }

    template {
      metadata {
        labels = { "app.kubernetes.io/name" = each.key, "team" = var.team }
        annotations = {
          # La inyección ocurre al crear el pod: un cambio de Instrumentation provoca rollout
          "checksum/instrumentation" = sha256(jsonencode(local.instrumentation_values))
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 10001
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = each.key
          image = each.value.image

          port {
            container_port = each.value.port
          }

          env {
            name  = "JDK_JAVA_OPTIONS"
            value = each.value.jvm_options
          }

          dynamic "env" {
            for_each = each.value.env
            content {
              name  = env.key
              value = env.value
            }
          }

          # Sin límite de CPU: el agente instrumenta bytecode en el arranque y un límite provoca throttling
          resources {
            requests = { cpu = "250m", memory = "384Mi" }
            limits   = { memory = each.value.memory }
          }

          # Arranque JVM + agente: hasta 3 min sin reinicios ni salida del balanceo
          startup_probe {
            http_get {
              path = each.value.health_path
              port = each.value.port
            }
            period_seconds    = 5
            timeout_seconds   = 3
            failure_threshold = 36
          }

          readiness_probe {
            http_get {
              path = each.value.health_path
              port = each.value.port
            }
            period_seconds  = 5
            timeout_seconds = 3
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }

  # El webhook del Operator requiere el recurso Instrumentation antes de crear los pods
  depends_on = [helm_release.instrumentation]
}

resource "kubernetes_service_v1" "workload" {
  for_each = var.workloads

  metadata {
    name      = each.key
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    selector = { "app.kubernetes.io/name" = each.key }

    port {
      name        = "http"
      port        = 80
      target_port = each.value.port
    }
  }
}
