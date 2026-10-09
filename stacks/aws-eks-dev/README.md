# aws-eks-dev

Los mismos módulos y capas de `local-minikube` sobre Amazon EKS. Lo que cambia entre entornos es la
configuración de providers, el origen de los secretos y los backends; el contrato de los módulos y el
bloque de cada vertical son idénticos.

| Aspecto | local-minikube | aws-eks-dev |
|---|---|---|
| State | Local | S3 con `use_lockfile` (bloqueo nativo, sin DynamoDB), una key por capa |
| Guardia de destino | `kube_context` restringido a minikube | `allowed_account_ids` en el provider AWS |
| Autenticación al clúster | kubeconfig | `aws eks get-token` por invocación |
| Secretos | `random_password` | AWS Secrets Manager |
| APM legado | Stand-in (Jaeger) | Dynatrace (`/api/v2/otlp`) |
| Backend OTel | Tempo en el clúster | Elastic APM / Grafana Tempo gestionado (TLS) |
| Reglas SLO | `PrometheusRule` | Amazon Managed Prometheus (`aws_prometheus_rule_group_namespace`) |
| Alertas | Alertmanager local | AMP Alertmanager: routing por `team` al tópico SNS de cada guardia |
| Perfil del SLO | `poc` | `prod` (30d · 1h/5m · 6h/30m) |
| Gateway | 2 réplicas | 3 réplicas, 1 Gi / 2 Gi |

## Prerrequisitos (gestionados por otros stacks)

Clúster EKS, bucket S3 de state, workspace de Amazon Managed Prometheus con scraper gestionado sobre el
endpoint de métricas RED del Gateway (`:8889`), secretos en Secrets Manager (sal de PII y token de
ingesta de Dynatrace), tópicos SNS por equipo y repositorio ECR con la imagen de la vertical.

## Operación

```bash
cp stacks/aws-eks-dev/backend.hcl.example stacks/aws-eks-dev/backend.hcl          # Configura bucket y región del state
cp stacks/aws-eks-dev/terraform.tfvars.example stacks/aws-eks-dev/terraform.tfvars # Define cuenta, región y clúster
make plan-00-platform-base ENV=aws-eks-dev && make apply-00-platform-base ENV=aws-eks-dev   # Instala Operator sobre EKS
make plan-10-telemetry ENV=aws-eks-dev && make apply-10-telemetry ENV=aws-eks-dev           # Despliega Gateway, agentes y routing de alertas
make plan-20-onboarding ENV=aws-eks-dev && make apply-20-onboarding ENV=aws-eks-dev         # Integra Pagos y publica reglas SLO
```

Variables por capa adicionales a las comunes: `secrets`, `dynatrace_otlp_endpoint`, `otel_backend_endpoint`,
`amp_workspace_id`, `team_alert_topics`, `platform_alert_topic` (capa 10); `amp_workspace_id`,
`ecr_registry` (capa 20). En CI se inyectan como `TF_VAR_*` desde el entorno de despliegue.
