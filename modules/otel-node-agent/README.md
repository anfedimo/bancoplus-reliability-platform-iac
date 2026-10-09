# otel-node-agent

Collector por nodo (DaemonSet). Recibe OTLP de los pods del nodo, agrega contexto de Kubernetes
(`k8sattributes`) y enruta por traceID hacia el Service headless del Gateway (`load_balancing`).

```hcl
module "otel_node_agent" {
  source                        = "git::https://github.com/anfedimo/bancoplus-reliability-platform-iac//modules/otel-node-agent?ref=v1.0.0"
  namespace                     = "observability"
  gateway_loadbalancing_service = module.otel_gateway.loadbalancing_service
}
```

| Decisión | Fundamento |
|---|---|
| DaemonSet, no sidecar | Un Collector por nodo en lugar de uno por pod: costo fijo por nodo e independiente del número de réplicas |
| `internalTrafficPolicy: Local` | El tráfico OTLP no cruza nodos antes de llegar al agente |
| `load_balancing` por traceID | Tail sampling consistente con N réplicas del Gateway |
| RBAC explícito | Permisos mínimos y auditables: lectura de pods, namespaces, replicasets y endpointslices |
