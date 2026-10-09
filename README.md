# bancoplus-reliability-platform-iac

**Owner:** Plataforma de Confiabilidad · **Modelo:** InnerSource · **Entornos:** local (minikube) · AWS (EKS)

Plataforma de telemetría como producto: módulos de Terraform versionados que las verticales consumen para
migrar del APM propietario a OpenTelemetry sin cambiar código fuente. El SRE de una vertical se integra con
un bloque de HCL en un Pull Request; no requiere conocimiento del Collector ni del Operator.

La configuración del Gateway (`modules/otel-gateway/templates`) es la fuente de verdad para Kubernetes.
Referencia funcional y Quality Gates de CI/CD: [sre-finops-otel-collector](https://github.com/anfedimo/sre-finops-otel-collector).

## Arquitectura del repositorio

```
modules/                        Plantillas base, versionadas por tag semántico
  otel-operator/                cert-manager y OpenTelemetry Operator con imágenes fijadas
  otel-gateway/                 Gateway: semántica de negocio, PII, tail sampling, métricas RED, Dual-Shipping
  otel-node-agent/              Collector por nodo con enrutamiento por traceID hacia el Gateway
  java-autoinstrumentation/     Autoservicio de verticales: namespace, Instrumentation, contrato X-Business-*
  slo-burn-rate-alerts/         Alertas multiventana generadas desde slo/*.yaml
  observability-backends/       Backends del entorno local; en AWS, servicios gestionados
charts/
  otel-instrumentation/         Recursos personalizados del Operator empaquetados como chart
stacks/                         Composición por entorno, un state por capa
  local-minikube/
    00-platform-base/           Prerrequisitos de plataforma y CRDs
    10-telemetry/               Gateway, agentes de nodo y backends
    20-onboarding/              Un archivo por vertical
  aws-eks-dev/                  Mismos módulos sobre EKS, backend S3 con locking nativo
slo/                            SLO como código
sample-apps/
  payments-qr-java/             Aplicación de referencia sin dependencias de OpenTelemetry
tests/
  e2e/                          Smoke tests sobre el clúster por capa
```

## Modelo de consumo

| Rol | Interfaz | Cambio típico |
|---|---|---|
| SRE de vertical | `modules/java-autoinstrumentation`, `modules/slo-burn-rate-alerts` | PR con un archivo en `stacks/<entorno>/20-onboarding/` |
| Plataforma de Confiabilidad | `modules/otel-*`, capas 00 y 10 | Release de módulo con tag semántico y changelog |
| DevSecOps | Patrones de PII en `modules/otel-gateway`, reglas de trivy | PR con aprobación obligatoria de DevSecOps |

```hcl
module "pagos" {
  source         = "git::https://github.com/anfedimo/bancoplus-reliability-platform-iac//modules/java-autoinstrumentation?ref=v1.0.0"
  namespace      = "pagos"
  team           = "tribu-pagos"
  migration_wave = "F1-piloto"
}
```

## Decisiones de diseño

| Decisión | Fundamento |
|---|---|
| State independiente por capa (00 → 10 → 20) | Los CRDs del Operator existen antes de que las capas superiores se planifiquen. Cada capa tiene su propio radio de impacto y su propio ciclo de aprobación. |
| Ciclo de vida del clúster fuera de este repositorio | El clúster es un activo con dueño, cadencia de cambio y controles distintos a los de la plataforma de telemetría. |
| Recursos personalizados del Operator como chart | Desacopla la planificación de Terraform de la disponibilidad del CRD y permite instalar la plataforma desde cero en un solo flujo. |
| Imágenes y charts fijados por versión | Ningún componente cambia en producción sin PR: una actualización del Operator no altera el agente Java desplegado. |
| Secretos como variables sensibles y Secret de Kubernetes | Los secretos nunca residen en archivos versionados; en AWS se resuelven desde Secrets Manager. |
| Restricción de contexto por stack | Cada stack valida el contexto de Kubernetes de destino e impide aplicar configuración de un entorno sobre otro. |
| Versión única de Terraform (`.terraform-version`) | Planes reproducibles e idénticos entre estaciones de trabajo y CI. |
| Contratos de módulo verificados con `terraform test` | Las entradas inválidas se rechazan antes del `plan`; los invariantes de seguridad (orden de PII, secretos por variable de entorno) se prueban en cada PR. |

## Ciclo de cambio

Todo cambio entra por Pull Request y pasa los controles de `.github/workflows/terraform-ci.yaml`:

| Control | Garantía |
|---|---|
| `terraform fmt` y `terraform validate` | Código homogéneo y sintácticamente válido en todos los módulos y stacks |
| `tflint` (preset recommended) | Variables documentadas, convenciones de nombres, sin código muerto |
| `trivy config` (HIGH/CRITICAL bloqueante) | Sin configuraciones inseguras en IaC ni en manifiestos |
| `terraform test` | Contratos de módulo: Dual-Shipping, cutover, orden de PII, validación de entradas |

## Requisitos

Terraform según `.terraform-version` (tfenv), minikube ≥ 1.38, Helm ≥ 3, Docker con 4 CPU y 6 GB disponibles.

## Operación

```bash
make cluster-up                    # clúster local (perfil bancoplus)
make validate test                 # validate de módulos y stacks · terraform test
make plan-<capa>                   # p. ej. make plan-10-telemetry
make apply-<capa>                  # aplica el plan revisado
make smoke                         # smoke test de la capa de telemetría
make app-image                     # imagen de la aplicación de referencia
make smoke-onboarding              # smoke test de onboarding (Job dentro del clúster)
make status
make cluster-down
```
