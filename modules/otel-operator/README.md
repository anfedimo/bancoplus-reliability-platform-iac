# otel-operator

cert-manager + OpenTelemetry Operator con imágenes fijadas (Collector y agente Java).
Se aplica en la capa `00-platform-base`, en un state propio, porque registra los CRDs
(`Instrumentation`, `OpenTelemetryCollector`) que consumen las capas superiores.

```hcl
module "otel_operator" {
  source               = "git::https://github.com/anfedimo/bancoplus-reliability-platform-iac//modules/otel-operator?ref=v0.1.0"
  install_cert_manager = false   # si el clúster ya lo provee
}
```

| Variable | Default |
|---|---|
| `cert_manager_chart_version` | `v1.21.2` |
| `operator_chart_version` | `0.124.1` (Operator 0.160.0) |
| `collector_image` | `otel/opentelemetry-collector-contrib:0.162.0` |
| `java_agent_image` | `autoinstrumentation-java:2.32.0` |
