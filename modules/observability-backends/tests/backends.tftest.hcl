# Contratos del módulo de backends. Ejecutar: terraform test

mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  namespace              = "observability"
  grafana_admin_password = "test-password-0123"
}

run "local_por_defecto_sin_exposicion" {
  command = plan

  assert {
    condition     = strcontains(helm_release.kube_prometheus_stack.values[0], "\"ClusterIP\"")
    error_message = "Por defecto Grafana no se expone fuera del clúster."
  }
}

run "nlb_con_allowlist_y_persistencia" {
  command = plan

  variables {
    grafana_service = { type = "LoadBalancer", source_ranges = ["203.0.113.10/32"] }
    persistence     = { enabled = true, storage_class = "gp3" }
  }

  assert {
    condition     = strcontains(helm_release.kube_prometheus_stack.values[0], "203.0.113.10/32") && strcontains(helm_release.kube_prometheus_stack.values[0], "Recreate")
    error_message = "El NLB debe aplicar la allowlist y Grafana con volumen RWO debe usar estrategia Recreate."
  }
}

run "rechaza_grafana_abierto_a_internet" {
  command = plan

  variables {
    grafana_service = { type = "LoadBalancer", source_ranges = ["0.0.0.0/0"] }
  }

  expect_failures = [var.grafana_service]
}

run "rechaza_loadbalancer_sin_allowlist" {
  command = plan

  variables {
    grafana_service = { type = "LoadBalancer" }
  }

  expect_failures = [var.grafana_service]
}
