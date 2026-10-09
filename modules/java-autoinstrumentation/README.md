# java-autoinstrumentation

Plantilla de autoservicio para verticales. Integra un namespace completo a la plataforma de telemetría
sin cambios en código, imagen ni manifiestos de las aplicaciones.

```hcl
module "pagos" {
  source         = "git::https://github.com/anfedimo/bancoplus-reliability-platform-iac//modules/java-autoinstrumentation?ref=v1.0.0"
  namespace      = "pagos"
  team           = "tribu-pagos"
  migration_wave = "F1-piloto"
}
```

## Qué provee

| Recurso | Efecto |
|---|---|
| Namespace con `instrumentation.opentelemetry.io/inject-java: "true"` | El Operator inyecta el agente Java en todo pod creado en el namespace |
| `Instrumentation` (chart `charts/otel-instrumentation`) | Exporta al agente de nodo; captura `X-Business-*`; muestreo delegado al Gateway |
| Atributos `team.tribe`, `migration.wave` | Routing de alertas y seguimiento del avance de la migración por ola |
| `workloads` (opcional) | Deployment + Service endurecidos (non-root, read-only rootfs, seccomp) |

## Reglas

- Un agente por JVM: el namespace se excluye de la inyección de OneAgent en el mismo cambio.
- `JAVA_TOOL_OPTIONS` lo gestiona el Operator; el módulo rechaza definirlo en `workloads`.
- Un cambio en `Instrumentation` dispara rollout de las cargas (checksum en el template del pod).
- Rollback a OneAgent: revertir el PR que agregó la vertical.
