#!/usr/bin/env bash
# Aprovisiona el entorno efímero (TTL 72 h) de punta a punta:
#   cluster → imágenes a ECR → 00 → 10 → 20 → URL de Grafana → smoke tests
#
#   scripts/up-ephemeral.sh [--yes] [--skip-smoke]
set -euo pipefail
# shellcheck source=scripts/lib-ephemeral.sh
source "$(dirname "$0")/lib-ephemeral.sh"

SKIP_SMOKE=false
for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=true ;;
    --skip-smoke) SKIP_SMOKE=true ;;
    *) die "argumento desconocido: $arg" ;;
  esac
done

GENERATOR_SRC="${GENERATOR_SRC:-$ROOT/../sre-finops-otel-collector/traffic-generator}"
START=$SECONDS

log "Preflight"
require_tools terraform kubectl aws docker make python3
load_config
check_identity
docker info >/dev/null 2>&1 || die "Docker no está corriendo (necesario para construir las imágenes)"
confirm "Se creará infraestructura con costo (≈ US\$0,30/h) en la cuenta $ACCOUNT_ID. ¿Continuar?"

log "1/6 · Capa cluster (VPC, EKS, ECR, Budget) · ~15-20 min"
tf cluster init -input=false >/dev/null
tf cluster apply -input=false -auto-approve -var-file="$VARS"
"${AWS[@]}" eks update-kubeconfig --name "$CLUSTER" --alias "$KUBE_CONTEXT" >/dev/null
kubectl --context "$KUBE_CONTEXT" wait --for=condition=Ready nodes --all --timeout=300s

log "2/6 · Imágenes a ECR (arm64, nodos Graviton)"
REGISTRY="$(tf cluster output -raw ecr_registry)"
"${AWS[@]}" ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY" >/dev/null

push_image() {
  # Tags inmutables en ECR: si el tag ya existe (re-ejecución del script), no se reconstruye
  local repo="$1" tag="$2" src="$3"
  if "${AWS[@]}" ecr describe-images --repository-name "$repo" --image-ids "imageTag=$tag" >/dev/null 2>&1; then
    echo "  $repo:$tag ya existe en ECR"
    return 0
  fi
  docker build --platform linux/arm64 -t "$REGISTRY/$repo:$tag" "$src"
  docker push "$REGISTRY/$repo:$tag"
}

push_image bancoplus/payments-qr 1.0.0 "$ROOT/sample-apps/payments-qr-java"
if [[ -d "$GENERATOR_SRC" ]]; then
  push_image bancoplus/traffic-generator poc "$GENERATOR_SRC"
else
  warn "generador no encontrado en $GENERATOR_SRC: se omite su imagen"
fi

step=3
for layer in 00-platform-base 10-telemetry 20-onboarding; do
  log "$step/6 · Capa $layer"
  tf "$layer" init -input=false >/dev/null
  tf "$layer" apply -input=false -auto-approve -var-file="$VARS"
  step=$((step + 1))
done

log "6/6 · Grafana (NLB) y smoke tests"
for _ in $(seq 1 40); do
  host="$(kubectl --context "$KUBE_CONTEXT" -n observability get svc kube-prometheus-stack-grafana \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  [[ -n "$host" ]] && break
  sleep 15
done
[[ -n "${host:-}" ]] || die "el NLB de Grafana no obtuvo hostname en 10 minutos"
for _ in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$host/api/health" || true)"
  [[ "$code" == "200" ]] && break
  sleep 10
done
[[ "${code:-}" == "200" ]] || warn "Grafana aún no responde en http://$host (propagación DNS del NLB)"

if [[ "$SKIP_SMOKE" == "false" ]]; then
  make -C "$ROOT" smoke-onboarding ENV=aws-eks-ephemeral PROFILE="$KUBE_CONTEXT"
  make -C "$ROOT" smoke-slo ENV=aws-eks-ephemeral PROFILE="$KUBE_CONTEXT"
fi

log "Entorno efímero listo en $(( (SECONDS - START) / 60 )) min"
cat <<EOF
  Grafana     http://$host   (usuario admin)
  Contraseña  terraform -chdir=stacks/aws-eks-ephemeral/10-telemetry output -raw grafana_admin_password | pbcopy
  kubectl     kubectl --context $KUBE_CONTEXT get pods -A
  TTL         destruir antes de $(date -v+72H '+%Y-%m-%d %H:%M'): scripts/teardown-ephemeral.sh
EOF
