MANIFESTS = 00-namespaces.yaml 10-apps.yaml \
            20-gateway.yaml 30-netpol.yaml
NAMESPACES = shop shop-edge shared monitoring

.PHONY: check up status test down

check: ## Prérequis : GatewayClass traefik acceptée
	@kubectl wait --for=condition=Accepted \
	  gatewayclass/traefik --timeout=30s

up: check ## Déployer la boutique
	@for f in $(MANIFESTS); do \
	  kubectl apply -f $$f; done
	@kubectl wait --for=condition=Available \
	  deploy --all -n shop --timeout=120s
	@kubectl wait --for=condition=Available \
	  deploy --all -n shared --timeout=120s
	@kubectl wait --for=condition=Available \
	  deploy --all -n monitoring --timeout=120s

status: ## Vue d'ensemble
	@kubectl get deploy,svc,netpol -n shop
	@kubectl get gtw -n shop-edge
	@kubectl get httproute -n shop

test: ## Tests de recette
	@./tests.sh

down: ## Tout supprimer
	@kubectl delete ns $(NAMESPACES) \
	  --ignore-not-found
