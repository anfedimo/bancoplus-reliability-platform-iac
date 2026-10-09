# aws-eks-ephemeral

Entorno efímero en Amazon EKS con **TTL de 72 horas**: se crea y se destruye completo con Terraform,
sin recursos huérfanos. Valida la paridad real de la plataforma en AWS (EKS, NLB, red y cuotas de cómputo)
con los mismos módulos que `local-minikube`.

## Capas

| Capa | Contenido | Tiempo aprox. |
|---|---|---|
| `cluster` | VPC (2 subredes públicas, 2 privadas, 1 NAT) · EKS (`terraform-aws-modules/eks`) · node group Graviton · add-on EBS CSI · ECR · AWS Budget | 15-20 min |
| `00-platform-base` | StorageClass gp3 cifrada · cert-manager · OpenTelemetry Operator | 2 min |
| `10-telemetry` | Gateway ×2 · agentes de nodo · Prometheus, Tempo, stand-in APM · **Grafana en NLB con allowlist y persistencia EBS** | 5 min |
| `ci-identity` | Proveedor OIDC de GitHub y rol de CI con push a ECR (sin llaves de larga duración) | 1 min |
| `gitops-bootstrap` | Argo CD + aplicación raíz: instrumentación, SLO y payments-qr se reconcilian desde `bancoplus-platform-gitops` | 3 min |
| `20-onboarding` | Reemplazada por `gitops-bootstrap` (migración incremental a GitOps) | — |

## Acceso

Todas las consolas están en NLB `internet-facing` restringidos a `admin_cidrs`.

| Consola | URL | Credenciales |
|---|---|---|
| Grafana | `terraform -chdir=10-telemetry output -raw grafana_url` | `admin` · `output -raw grafana_admin_password` |
| Argo CD | `terraform -chdir=gitops-bootstrap output -raw argocd_url` | `admin` · secret `argocd-initial-admin-secret` |
| APM legado (stand-in) | `terraform -chdir=10-telemetry output -raw legacy_apm_url` | — |

Prometheus, Tempo y Alertmanager se consultan desde Grafana (datasources aprovisionados): un solo
punto de acceso público en lugar de uno por componente.

## Guardrails

| Control | Implementación |
|---|---|
| TTL y trazabilidad de costos | `default_tags` en el provider: `Environment=ephemeral-poc`, `Owner`, `Purpose`, `TTL=72h` |
| Recursos creados por Kubernetes | El NLB recibe los tags por anotación; los volúmenes EBS, por `extraVolumeTags` del driver CSI |
| Presupuesto | AWS Budget de US$30 con alertas al 50% y 80% real y al 100% proyectado |
| Destino correcto | `allowed_account_ids`: el plan falla si el perfil apunta a otra cuenta |
| Exposición | API de EKS y Grafana restringidas a `admin_cidrs`; `0.0.0.0/0` rechazado por validación |
| Teardown sin huérfanos | `scripts/teardown-ephemeral.sh`: destruye en orden inverso, espera el borrado de NLB y EBS antes del clúster y verifica por tag |

## Costo estimado (72 h, us-east-1)

| Componente | Spot (default) | On-demand |
|---|---|---|
| 2 nodos Graviton (`t4g.xlarge`, alternativas `m7g`/`m6g` para disponibilidad Spot) | ~US$6 | ~US$19 |
| Plano de control EKS | US$7,20 | US$7,20 |
| NAT Gateway | ~US$3,30 | ~US$3,30 |
| NLB de Grafana | ~US$1,60 | ~US$1,60 |
| **Total** | **~US$18** | **~US$31** |

Cubierto por los créditos de una cuenta nueva (plan gratuito). `node_capacity_type = "ON_DEMAND"` evita
interrupciones Spot el día de la demo.

## Cuotas en cuentas nuevas

Las cuentas nuevas parten con **5 vCPU** de cuota EC2 (Spot y On-Demand): no alcanzan para 2 nodos `*.xlarge`
(8 vCPU). Verificar antes de aprovisionar y, si aplica, usar nodos de 2 vCPU en `terraform.tfvars`:

```bash
aws service-quotas get-service-quota --service-code ec2 --quota-code L-34B43A08 --profile bancoplus-poc   # Consulta cuota Spot de vCPU
```

```hcl
node_instance_types = ["t4g.large", "m7g.large", "m6g.large"]   # 2 × 2 vCPU · 16 GB en total
```

## Riesgos aceptados (`.trivyignore.yaml`, vencen 2026-12-31)

| Control | Justificación |
|---|---|
| AWS-0040 · endpoint público de EKS | Restringido a `/32`; un endpoint privado requiere VPN o bastión |
| AWS-0104 · egress abierto de nodos | Necesario para imágenes y APIs de AWS; cerrarlo requiere VPC endpoints y proxy |
