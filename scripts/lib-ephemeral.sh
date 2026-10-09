#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumidas por los scripts que cargan esta librería
# Funciones comunes de los scripts del entorno efímero (scripts/up-ephemeral.sh, scripts/teardown-ephemeral.sh).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="$ROOT/stacks/aws-eks-ephemeral"
VARS="$ENV_DIR/terraform.tfvars"
KUBE_CONTEXT="bancoplus-eks"
TAG_KEY="Environment"
TAG_VALUE="ephemeral-poc"

log()  { printf '\n\033[1m[%s] %s\033[0m\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[33m[WARN] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31m[FAIL] %s\033[0m\n' "$*" >&2; exit 1; }

tfvar() {
  # Lee un valor string simple de terraform.tfvars
  awk -F'"' -v key="$1" '$0 ~ "^[[:space:]]*"key"[[:space:]]*=" {print $2; exit}' "$VARS"
}

load_config() {
  [[ -f "$VARS" ]] || die "falta $VARS (copiar terraform.tfvars.example y completarlo)"
  AWS_PROFILE_NAME="$(tfvar aws_profile)"
  ACCOUNT_ID="$(tfvar aws_account_id)"
  REGION="$(tfvar region)"
  CLUSTER="$(tfvar cluster_name)"
  [[ -n "$AWS_PROFILE_NAME" && -n "$ACCOUNT_ID" && -n "$REGION" && -n "$CLUSTER" ]] \
    || die "terraform.tfvars incompleto: aws_profile, aws_account_id, region, cluster_name"
  AWS=(aws --profile "$AWS_PROFILE_NAME" --region "$REGION")
}

require_tools() {
  local t
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || die "herramienta requerida no instalada: $t"; done
}

check_identity() {
  local actual
  actual="$("${AWS[@]}" sts get-caller-identity --query Account --output text 2>/dev/null)" \
    || die "credenciales inválidas para el perfil '$AWS_PROFILE_NAME' (aws configure --profile $AWS_PROFILE_NAME)"
  [[ "$actual" == "$ACCOUNT_ID" ]] || die "el perfil apunta a la cuenta $actual, no a $ACCOUNT_ID (guardia de destino)"
  echo "cuenta $actual · región $REGION · clúster $CLUSTER"
}

confirm() {
  [[ "${ASSUME_YES:-false}" == "true" ]] && return 0
  read -r -p "$1 [y/N] " answer
  [[ "$answer" =~ ^[yY]$ ]] || die "cancelado por el usuario"
}

tf() {
  # tf <capa> <comando> [args]: terraform sobre una capa con las variables del entorno
  local layer="$1"; shift
  terraform -chdir="$ENV_DIR/$layer" "$@"
}

cluster_exists() {
  "${AWS[@]}" eks describe-cluster --name "$CLUSTER" >/dev/null 2>&1
}
