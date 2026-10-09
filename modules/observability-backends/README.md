# observability-backends

Backends del entorno local. En AWS se reemplazan por servicios gestionados sin cambios en el Gateway:
solo cambian `otel_backend_endpoint` y `legacy_apm.endpoint`.

| Componente | Rol |
|---|---|
| kube-prometheus-stack | Prometheus (SLI, Error Budget), Alertmanager, Grafana y CRDs `ServiceMonitor` / `PrometheusRule` |
| Grafana Tempo | Backend OTel de trazas (OTLP gRPC/HTTP) |
| `apm-legacy-standin` (Jaeger) | Stand-in de Dynatrace: recibe OTLP/HTTP del Dual-Shipping |

Grafana queda provisionado con los datasources de Tempo (service map vía Prometheus) y del APM legado.
