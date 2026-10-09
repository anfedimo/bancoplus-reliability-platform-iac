.PHONY: cluster-up cluster-down fmt validate test plan-% apply-% destroy-% status smoke smoke-onboarding smoke-slo app-image ephemeral-up ephemeral-down

PROFILE ?= bancoplus
GENERATOR_SRC ?= ../sre-finops-otel-collector/traffic-generator
APP_SRC       ?= ../bancoplus-payments-qr
# Smoke tests de la plataforma en ejecución: viven en el repositorio GitOps
TESTS         ?= ../bancoplus-platform-gitops/tests
ENV     ?= local-minikube
STACKS  := stacks/$(ENV)
# Backend remoto (aws-eks-*): configuración parcial y variables comunes del entorno
BACKEND_CFG := $(if $(wildcard $(STACKS)/backend.hcl),-backend-config=../backend.hcl,)
VAR_FILE    := $(if $(wildcard $(STACKS)/terraform.tfvars),-var-file=../terraform.tfvars,)
MODULES := otel-gateway java-autoinstrumentation slo-burn-rate-alerts observability-backends github-ci-ecr-role

cluster-up:          ## Clúster local (fuera de Terraform: ciclo de vida independiente)
	minikube start -p $(PROFILE) --driver=docker --cpus=6 --memory=6g --addons=metrics-server

cluster-down:
	minikube delete -p $(PROFILE)

fmt:
	terraform fmt -recursive

validate:            ## validate de todos los módulos y stacks (todos los entornos)
	@for d in modules/*/ stacks/*/*/; do \
	  ls $$d*.tf >/dev/null 2>&1 || continue; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate -no-color || exit 1; \
	done

test:                ## terraform test de los módulos
	@for m in $(MODULES); do \
	  terraform -chdir=modules/$$m init -backend=false -input=false >/dev/null && terraform -chdir=modules/$$m test || exit 1; \
	done

plan-%:              ## make plan-00-platform-base [ENV=aws-eks-dev]
	terraform -chdir=$(STACKS)/$* init -input=false $(BACKEND_CFG) >/dev/null
	terraform -chdir=$(STACKS)/$* plan $(VAR_FILE) -out=tfplan

apply-%:             ## make apply-00-platform-base (aplica el último plan)
	terraform -chdir=$(STACKS)/$* apply tfplan && rm -f $(STACKS)/$*/tfplan

destroy-%:
	terraform -chdir=$(STACKS)/$* destroy $(VAR_FILE)

smoke:               ## Smoke test de la capa 10: tráfico sintético → agente → Gateway → backends
	minikube -p $(PROFILE) image build -t bancoplus/traffic-generator:poc $(GENERATOR_SRC)
	kubectl --context $(PROFILE) apply -f $(TESTS)/traffic-generator.yaml
	kubectl --context $(PROFILE) -n smoke-test rollout status deploy/traffic-generator --timeout=120s
	@echo "esperando flush de span_metrics (15s) y scrape de Prometheus (30s)…" && sleep 60
	KUBE_CONTEXT=$(PROFILE) python3 $(TESTS)/smoke_telemetry.py

app-image:           ## Imagen de la aplicación de referencia (sin dependencias OTel)
	minikube -p $(PROFILE) image build -t bancoplus/payments-qr:1.0.0 $(APP_SRC)

smoke-onboarding:    ## Smoke test de la capa 20 como Job dentro del clúster
	kubectl --context $(PROFILE) create namespace smoke-test --dry-run=client -o yaml | kubectl --context $(PROFILE) apply -f -
	kubectl --context $(PROFILE) -n smoke-test create configmap smoke-onboarding --from-file=$(TESTS)/smoke_onboarding.py --dry-run=client -o yaml | kubectl --context $(PROFILE) apply -f -
	kubectl --context $(PROFILE) -n smoke-test create secret generic grafana-admin \
	  --from-literal=password="$$(terraform -chdir=$(STACKS)/10-telemetry output -raw grafana_admin_password)" --dry-run=client -o yaml | kubectl --context $(PROFILE) apply -f -
	kubectl --context $(PROFILE) -n smoke-test delete job smoke-onboarding --ignore-not-found
	kubectl --context $(PROFILE) apply -f $(TESTS)/smoke-onboarding-job.yaml
	$(TESTS)/run-job.sh $(PROFILE) smoke-test smoke-onboarding 300

smoke-slo:           ## Smoke test del SLO: dispara SLOFastBurn con tráfico real (≈6 min)
	kubectl --context $(PROFILE) create namespace smoke-test --dry-run=client -o yaml | kubectl --context $(PROFILE) apply -f -
	kubectl --context $(PROFILE) -n smoke-test create configmap smoke-slo --from-file=$(TESTS)/smoke_slo.py --dry-run=client -o yaml | kubectl --context $(PROFILE) apply -f -
	kubectl --context $(PROFILE) -n smoke-test create secret generic grafana-admin \
	  --from-literal=password="$$(terraform -chdir=$(STACKS)/10-telemetry output -raw grafana_admin_password)" --dry-run=client -o yaml | kubectl --context $(PROFILE) apply -f -
	kubectl --context $(PROFILE) -n smoke-test delete job smoke-slo --ignore-not-found
	kubectl --context $(PROFILE) apply -f $(TESTS)/smoke-slo-job.yaml
	$(TESTS)/run-job.sh $(PROFILE) smoke-test smoke-slo 600

ephemeral-up:        ## Entorno efímero en EKS (TTL 72 h): cluster → imágenes → 00 → 10 → 20 → smoke
	scripts/up-ephemeral.sh

ephemeral-down:      ## Destruye el entorno efímero y verifica costo residual cero
	scripts/teardown-ephemeral.sh

status:
	kubectl --context $(PROFILE) get pods -A -l 'app.kubernetes.io/part-of in (opentelemetry,reliability-platform)' 2>/dev/null; \
	kubectl --context $(PROFILE) get pods -n cert-manager; kubectl --context $(PROFILE) get pods -n opentelemetry-operator-system
