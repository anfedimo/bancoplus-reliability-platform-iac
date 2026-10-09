#!/usr/bin/env bash
# Destruye el entorno efímero y verifica costo residual cero.
#
#   1. Capas 20 → 10 → 00 (mientras el clúster existe, Kubernetes elimina el NLB y los volúmenes EBS)
#   2. Espera a que AWS confirme el borrado de NLB y EBS creados por Kubernetes
#   3. Capa cluster (EKS, nodos, NAT, VPC, ECR, Budget)
#   4. Barrido por tag Environment=ephemeral-poc y reporte de recursos residuales
#
#   scripts/teardown-ephemeral.sh [--yes] [--force-orphans]
#   --force-orphans  elimina volúmenes EBS, balanceadores e IPs elásticas huérfanos con el tag del entorno
set -uo pipefail
# shellcheck source=scripts/lib-ephemeral.sh
source "$(dirname "$0")/lib-ephemeral.sh"

FORCE_ORPHANS=false
for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=true ;;
    --force-orphans) FORCE_ORPHANS=true ;;
    *) die "argumento desconocido: $arg" ;;
  esac
done

log "Preflight"
require_tools terraform aws python3
load_config
check_identity
confirm "Se destruirá TODO el entorno efímero en la cuenta $ACCOUNT_ID. ¿Continuar?"

destroy_layer() {
  local layer="$1"
  if [[ ! -f "$ENV_DIR/$layer/terraform.tfstate" ]]; then
    warn "capa $layer sin state local: se omite (el barrido cubre sus recursos)"
    return 0
  fi
  log "Destruyendo capa $layer"
  tf "$layer" init -input=false >/dev/null
  tf "$layer" destroy -input=false -auto-approve -var-file="$VARS" || warn "destroy de $layer con errores: el barrido final lo verificará"
}

tagged_count() {
  # tagged_count <servicio>: recursos vivos con el tag del entorno según la API de cada servicio
  case "$1" in
    volumes) "${AWS[@]}" ec2 describe-volumes --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query 'length(Volumes)' --output text ;;
    loadbalancers)
      local arns
      arns="$("${AWS[@]}" elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' --output text)"
      [[ -z "$arns" ]] && { echo 0; return; }
      # shellcheck disable=SC2086
      "${AWS[@]}" elbv2 describe-tags --resource-arns $arns \
        --query "length(TagDescriptions[?Tags[?Key=='$TAG_KEY' && Value=='$TAG_VALUE']])" --output text ;;
  esac
}

if cluster_exists; then
  # gitops-bootstrap primero: Argo CD elimina sus aplicaciones (finalizer) antes de desinstalarse
  for layer in gitops-bootstrap 20-onboarding 10-telemetry 00-platform-base; do destroy_layer "$layer"; done

  log "Esperando que AWS elimine el NLB y los volúmenes EBS creados por Kubernetes"
  for _ in $(seq 1 30); do
    lbs="$(tagged_count loadbalancers)"; vols="$(tagged_count volumes)"
    echo "  balanceadores=$lbs volúmenes=$vols"
    [[ "$lbs" == "0" && "$vols" == "0" ]] && break
    sleep 10
  done
else
  warn "el clúster $CLUSTER no existe: se omiten las capas de plataforma"
fi

# Identidad de CI: lee el repositorio ECR de la capa cluster, se destruye antes
destroy_layer ci-identity
destroy_layer cluster

log "Barrido de recursos residuales (tag $TAG_KEY=$TAG_VALUE)"
residual=0
report() { printf '  %-28s %s\n' "$1" "$2"; [[ "$2" == "0" ]] || residual=$((residual + 1)); }

report "Clúster EKS"               "$(cluster_exists && echo 1 || echo 0)"
report "Volúmenes EBS"             "$(tagged_count volumes)"
report "Balanceadores (NLB/ALB)"   "$(tagged_count loadbalancers)"
report "NAT Gateways"              "$("${AWS[@]}" ec2 describe-nat-gateways --filter "Name=tag:$TAG_KEY,Values=$TAG_VALUE" "Name=state,Values=pending,available" --query 'length(NatGateways)' --output text)"
report "IPs elásticas"             "$("${AWS[@]}" ec2 describe-addresses --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query 'length(Addresses)' --output text)"
report "VPCs"                      "$("${AWS[@]}" ec2 describe-vpcs --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query 'length(Vpcs)' --output text)"
report "Repositorios ECR"          "$("${AWS[@]}" ecr describe-repositories --query "length(repositories[?starts_with(repositoryName, 'bancoplus/')])" --output text 2>/dev/null || echo 0)"

if [[ "$residual" -gt 0 && "$FORCE_ORPHANS" == "true" ]]; then
  log "Eliminando huérfanos con el tag del entorno"
  for v in $("${AWS[@]}" ec2 describe-volumes --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" "Name=status,Values=available" --query 'Volumes[].VolumeId' --output text); do
    "${AWS[@]}" ec2 delete-volume --volume-id "$v" && echo "  volumen $v eliminado"
  done
  for a in $("${AWS[@]}" ec2 describe-addresses --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query 'Addresses[].AllocationId' --output text); do
    "${AWS[@]}" ec2 release-address --allocation-id "$a" && echo "  IP elástica $a liberada"
  done
  arns="$("${AWS[@]}" elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' --output text)"
  for lb in $arns; do
    if [[ "$("${AWS[@]}" elbv2 describe-tags --resource-arns "$lb" --query "length(TagDescriptions[0].Tags[?Key=='$TAG_KEY' && Value=='$TAG_VALUE'])" --output text)" != "0" ]]; then
      "${AWS[@]}" elbv2 delete-load-balancer --load-balancer-arn "$lb" && echo "  balanceador eliminado: $lb"
    fi
  done
fi

kubectl config delete-context "$KUBE_CONTEXT" >/dev/null 2>&1 || true

if [[ "$residual" -eq 0 ]]; then
  log "Teardown completo · costo residual: 0 recursos"
else
  log "Teardown con $residual tipo(s) de recurso residual"
  echo "  Re-ejecutar con --force-orphans, o revisar en la consola los recursos con el tag $TAG_KEY=$TAG_VALUE."
  exit 1
fi
