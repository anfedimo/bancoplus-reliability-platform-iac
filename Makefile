.PHONY: cluster-up cluster-down fmt validate test plan-% apply-% destroy-% status

PROFILE ?= bancoplus
STACKS  := stacks/local-minikube
MODULES := otel-gateway

cluster-up:          ## Clúster local (fuera de Terraform: ciclo de vida independiente)
	minikube start -p $(PROFILE) --driver=docker --cpus=4 --memory=6g --addons=metrics-server

cluster-down:
	minikube delete -p $(PROFILE)

fmt:
	terraform fmt -recursive

validate:            ## validate de todos los módulos y stacks
	@for d in modules/*/ $(STACKS)/*/; do \
	  ls $$d*.tf >/dev/null 2>&1 || continue; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate -no-color || exit 1; \
	done

test:                ## terraform test de los módulos
	@for m in $(MODULES); do \
	  terraform -chdir=modules/$$m init -backend=false -input=false >/dev/null && terraform -chdir=modules/$$m test || exit 1; \
	done

plan-%:              ## make plan-00-platform-base
	terraform -chdir=$(STACKS)/$* init -input=false >/dev/null
	terraform -chdir=$(STACKS)/$* plan -out=tfplan

apply-%:             ## make apply-00-platform-base (aplica el último plan)
	terraform -chdir=$(STACKS)/$* apply tfplan && rm -f $(STACKS)/$*/tfplan

destroy-%:
	terraform -chdir=$(STACKS)/$* destroy

status:
	kubectl --context $(PROFILE) get pods -A -l 'app.kubernetes.io/part-of in (opentelemetry,reliability-platform)' 2>/dev/null; \
	kubectl --context $(PROFILE) get pods -n cert-manager; kubectl --context $(PROFILE) get pods -n opentelemetry-operator-system
