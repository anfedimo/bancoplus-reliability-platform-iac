# slo-burn-rate-alerts

Genera, desde un SLO como código (`slo/*.yaml`), las reglas de grabación, las alertas multiventana de
burn rate y el dashboard de Error Budget de una vertical. El SRE de la vertical declara objetivos;
no escribe PromQL.

```hcl
module "pagos_slo" {
  source    = "git::https://github.com/anfedimo/bancoplus-reliability-platform-iac//modules/slo-burn-rate-alerts?ref=v1.0.0"
  slo_file  = "${path.module}/slo/payments-qr.yaml"
  namespace = "pagos"
}
```

## Qué genera

| Artefacto | Contenido |
|---|---|
| Reglas de grabación | `slo:sli_error:ratio_rate<ventana>` por SLI, `slo:objective:ratio`, `slo:error_budget_remaining:ratio` |
| `SLOFastBurn` | 14.4x en 1h y 5m (2% del budget mensual por hora) · `severity: page` |
| `SLOSlowBurn` | 6x en 6h y 30m (5% del budget mensual cada 6h) · `severity: ticket` |
| Dashboard de Grafana | Budget restante, SLI, burn rate, tasa por código HTTP vs. falla técnica real, resultado de negocio |

Todas las alertas llevan `team` (dueño del SLO), `slo_service`, `slo_sli` y `journey`: el routing de
Alertmanager entrega cada alerta a la guardia de la vertical dueña (*you build it, you run it*).

## Decisiones

| Decisión | Fundamento |
|---|---|
| Multiventana (larga y corta) | La ventana larga da significancia; la corta, reset rápido al mitigar. Elimina las alertas por picos transitorios de los umbrales estáticos |
| SLI sobre el estado normalizado del span | Los rechazos de negocio expuestos como 5xx no consumen budget; las fallas ocultas en 2xx sí |
| Nombres de métrica genéricos con etiquetas | Un solo runbook y un solo modelo de dashboard para todos los SLO de la organización |
| Perfil `poc` | Mismas reglas con ventanas comprimidas para validación local |
