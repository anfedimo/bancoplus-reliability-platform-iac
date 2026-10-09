# otel-gateway

OpenTelemetry Collector en modo Gateway: semántica de negocio, PII masking, tail sampling, métricas RED
y Dual-Shipping. Despliegue con el chart oficial `open-telemetry/opentelemetry-collector`.

## Uso

```hcl
module "otel_gateway" {
  source = "git::https://github.com/anfedimo/bancoplus-reliability-platform-iac//modules/otel-gateway?ref=v0.1.0"

  pii_hash_salt         = var.pii_hash_salt           # gestor de secretos
  otel_backend_endpoint = "tempo.observability:4317"

  legacy_apm = {
    enabled  = true                                     # false = cutover (F3)
    endpoint = "https://<env-id>.live.dynatrace.com/api/v2/otlp"
  }
  legacy_apm_api_token = var.dynatrace_ingest_token
}
```

## Pipeline

`otlp → memory_limiter → transform/business-semantics → transform/pii → { span_metrics → prometheus | tail_sampling → batch → exporters }`

## Entradas principales

| Variable | Default | Contrato |
|---|---|---|
| `pii_hash_salt` | — | Obligatoria, sensible, ≥ 16 caracteres |
| `otel_backend_endpoint` | — | Obligatoria, `host:puerto` |
| `legacy_apm` | `{ enabled = false }` | `endpoint` http/https obligatorio si `enabled` |
| `sampling` | `5% · 800 ms · 50 M COP` | `baseline_percentage` en (0, 100] |
| `replicas` | `2` | 1–20; PDB `minAvailable: 1` si > 1 |
| `span_metrics_dimensions` | 4 dimensiones | Máximo 8 (cardinalidad) |
| `business_semantics_enabled` | `true` | — |

## Salidas

`otlp_grpc_endpoint`, `otlp_http_endpoint`, `loadbalancing_service` (para `otel-node-agent`),
`red_metrics_endpoint`, `trace_exporters`, `rendered_config`.

## Pruebas

`terraform test` (providers simulados): Dual-Shipping, cutover F3, orden de `transform/pii`,
parametrización del sampling y rechazo de entradas inválidas.
