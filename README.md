# bancoplus-reliability-platform-iac

**Owner:** Plataforma de Confiabilidad · **Modelo:** InnerSource · **Estado:** PoC (minikube) · Portable a EKS

Plataforma de telemetría como producto: módulos de Terraform versionados que las verticales consumen para
migrar del APM propietario a OpenTelemetry sin cambiar código fuente. El SRE de una vertical se integra
con un bloque de HCL en un PR; no necesita conocer el Collector ni el Operator.

Configuración funcional de referencia y Quality Gates: [sre-finops-otel-collector](https://github.com/anfedimo/sre-finops-otel-collector).
La configuración del Gateway en este repositorio (`modules/otel-gateway/templates`) es la fuente de verdad para despliegues en Kubernetes.

## Estructura

```
modules/                   Plantillas base (versionadas por tag)
  otel-operator/           cert-manager + Operator · imágenes fijadas                  ✅
  otel-gateway/            Gateway: semántica de negocio, PII, sampling, Dual-Shipping   ✅ + terraform test
  otel-node-agent/         DaemonSet con loadbalancing por traceID                       ⏳
  java-autoinstrumentation/  Autoservicio de verticales (namespace + Instrumentation)    ⏳
  slo-burn-rate-alerts/    PrometheusRule desde slo/*.yaml                               ⏳
  observability-backends/  Backends locales (Prometheus, trazas, stand-in APM legado)    ⏳
charts/otel-instrumentation/  CRs del Operator vía chart local                           ⏳
stacks/local-minikube/     Un state por capa
  00-platform-base/        cert-manager + Operator                                       ✅ aplicado
  10-telemetry/            Gateway, agentes, backends                                    ⏳
  20-onboarding/           Un archivo por vertical                                       ⏳
stacks/aws-eks-dev/        Mismos módulos sobre EKS (no se aplica en la PoC)              ⏳
slo/                       SLO como código
sample-apps/payments-qr-java/  Spring Boot sin dependencias OTel                         ⏳
```

## Decisiones de diseño

| Decisión | Motivo |
|---|---|
| Capas con state independiente (00 → 10 → 20) | Los CRDs del Operator deben existir antes del `plan` de las capas que los usan; además acota el blast radius |
| Ciclo de vida del clúster fuera de Terraform | En producción el clúster EKS es otro stack con otro dueño y otra cadencia de cambio |
| CRs del Operator vía chart local | `kubernetes_manifest` exige el CRD en tiempo de `plan`; un chart difiere la validación al `apply` |
| Imágenes y charts fijados por versión | Una actualización del Operator no cambia el agente Java en producción sin PR |
| Secretos por variable sensible + Secret de Kubernetes | Nunca en `.tfvars` versionados; en AWS desde Secrets Manager |
| Guardia de contexto en stacks locales | `kube_context` restringido a perfiles de minikube: impide un apply accidental sobre EKS |
| `.terraform-version` | Versión de Terraform única para todo el equipo (tfenv) |

## Requisitos

Terraform 1.16.5 (`tfenv install`), minikube ≥ 1.38, Helm ≥ 3, Docker con 4 CPU / 6 GB libres.

## Operación

```bash
make cluster-up                 # minikube, perfil bancoplus
make validate test              # validate de todo + terraform test de módulos
make plan-00-platform-base      # plan revisable
make apply-00-platform-base     # aplica el plan
make status
make cluster-down
```

## CI (`.github/workflows/terraform-ci.yaml`)

`terraform fmt` · `terraform validate` (módulos y stacks) · `tflint` (preset recommended) ·
`trivy config` (HIGH/CRITICAL bloqueante) · `terraform test`.
