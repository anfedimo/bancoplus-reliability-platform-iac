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
  aws-eks-ephemeral/            Entorno efímero en EKS (TTL 72 h): cluster, capas 00-20 y guardrails de costo
slo/                            SLO como código
sample-apps/
  payments-qr-java/             Aplicación de referencia sin dependencias de OpenTelemetry
tests/
  e2e/                          Smoke tests sobre el clúster por capa
scripts/                        Ciclo de vida del entorno efímero (up / teardown)
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
| SLO como código con alertas por burn rate | El SRE de la vertical declara objetivos; la plataforma genera PromQL, alertas multiventana y dashboard. Sustituye los umbrales estáticos de CPU y memoria. |
| Contratos de módulo verificados con `terraform test` | Las entradas inválidas se rechazan antes del `plan`; los invariantes de seguridad (orden de PII, secretos por variable de entorno) se prueban en cada PR. |

## Ciclo de cambio

Todo cambio entra por Pull Request y pasa los controles de `.github/workflows/terraform-ci.yaml`:

| Control | Garantía |
|---|---|
| `terraform fmt` y `terraform validate` | Código homogéneo y sintácticamente válido en todos los módulos y stacks |
| `tflint` (preset recommended) | Variables documentadas, convenciones de nombres, sin código muerto |
| `trivy config` (HIGH/CRITICAL bloqueante) | Sin configuraciones inseguras en IaC ni en manifiestos |
| `terraform test` | Contratos de módulo: Dual-Shipping, cutover, orden de PII, validación de entradas, alertas multiventana |
| `promtool` sobre reglas generadas | Todo SLO de `slo/*.yaml` produce PromQL válido en los perfiles prod y poc |

## Requisitos

Terraform según `.terraform-version` (tfenv), minikube ≥ 1.38, Helm ≥ 3, Docker con 6 CPU y 6 GB disponibles.

## Operación

```bash
make cluster-up                    # clúster local (perfil bancoplus)
make validate test                 # validate de módulos y stacks · terraform test
make plan-<capa>                   # p. ej. make plan-10-telemetry
make apply-<capa>                  # aplica el plan revisado
make smoke                         # smoke test de la capa de telemetría
make app-image                     # imagen de la aplicación de referencia
make smoke-onboarding              # smoke test de onboarding (Job dentro del clúster)
make smoke-slo                     # smoke test del SLO: dispara SLOFastBurn con tráfico real
make status
make cluster-down
```

## Puesta en marcha local

Secuencia completa desde cero hasta el dashboard de Error Budget en Grafana.

```bash
# 1. Preparación
caffeinate -dims -t 10800 &                                   # Evita suspensión del equipo durante la sesión
make cluster-up                                               # Crea clúster minikube con 6 CPU

# 2. Plataforma (capas en orden)
make plan-00-platform-base && make apply-00-platform-base     # Instala cert-manager y OpenTelemetry Operator
make plan-10-telemetry && make apply-10-telemetry             # Despliega Gateway, agentes, Prometheus, Tempo, Grafana
make app-image                                                # Construye imagen Spring Boot sin dependencias OTel
make plan-20-onboarding && make apply-20-onboarding           # Integra vertical Pagos con su SLO

# 3. Validación
make smoke-onboarding                                         # Verifica trazas, PII enmascarada y Dual-Shipping
make smoke-slo                                                # Genera tráfico y dispara alerta SLOFastBurn

# 4. Grafana
terraform -chdir=stacks/local-minikube/10-telemetry output -raw grafana_admin_password | pbcopy   # Copia contraseña admin al portapapeles
kubectl --context bancoplus -n observability port-forward svc/kube-prometheus-stack-grafana 3000:80   # Expone Grafana en localhost:3000
open http://localhost:3000/d/slo-payments-qr                  # Abre dashboard de Error Budget
open http://localhost:3000/explore                            # Explora trazas en Tempo y APM legado

# 5. Cierre
make cluster-down                                             # Elimina el clúster y sus datos
pkill caffeinate                                              # Restaura la suspensión normal del equipo
```

**Login de Grafana:** usuario `admin` y la contraseña copiada en el paso 4 (Cmd+V). No es `admin`:
la capa 10 la genera con `random_password` para que ningún secreto resida en el repositorio, y cambia
cada vez que el clúster se recrea. Los comandos se ejecutan desde la raíz del repositorio.
El port-forward ocupa la terminal: ejecutar `open` desde otra.
`make smoke-slo` justo antes de abrir el dashboard garantiza datos en todos los paneles.

## Puesta en marcha en EKS (entorno efímero, TTL 72 h)

```bash
# 1. Cuenta AWS (una sola vez)
aws configure --profile bancoplus-poc                         # Registra credenciales del usuario IAM
curl -s https://checkip.amazonaws.com                         # Obtiene tu IP para la allowlist
cp stacks/aws-eks-ephemeral/terraform.tfvars.example stacks/aws-eks-ephemeral/terraform.tfvars   # Define cuenta, IP y correo

# 2. Aprovisionamiento completo (~30 min)
make ephemeral-up                                             # Crea EKS, sube imágenes, aplica capas

# 3. Grafana
terraform -chdir=stacks/aws-eks-ephemeral/10-telemetry output -raw grafana_url             # Muestra URL pública de Grafana
terraform -chdir=stacks/aws-eks-ephemeral/10-telemetry output -raw grafana_admin_password | pbcopy   # Copia contraseña admin al portapapeles
kubectl --context bancoplus-eks get pods -A                   # Verifica estado de toda la plataforma

# 4. Ensayo de la demo
make smoke-slo ENV=aws-eks-ephemeral PROFILE=bancoplus-eks    # Genera tráfico y dispara alerta SLO

# 5. Cierre (antes de 72 h)
make ephemeral-down                                           # Destruye todo y verifica costo cero
```

Grafana solo responde desde las IPs de `admin_cidrs`: si cambias de red (por ejemplo, el lugar de la
presentación), agrega la nueva IP en `terraform.tfvars` y ejecuta `make plan-10-telemetry ENV=aws-eks-ephemeral && make apply-10-telemetry ENV=aws-eks-ephemeral`.
