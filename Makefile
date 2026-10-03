cat > Makefile <<'EOF'
# VARIABLES
CLUSTER   ?= app-cluster
SERVER    ?= 1
AGENTS    ?= 2
ENV       ?= dev
NAMESPACE  = my-app-$(ENV)
OVERLAY    = overlays/$(ENV)

.PHONY: ns render diff deploy destroy get-all cluster-create cluster-start cluster-stop cluster-delete

# KUSTOMIZE
ns:
    @kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
render:
    @kubectl kustomize $(OVERLAY)
diff: ns
    @kubectl diff -k $(OVERLAY) || true
deploy: ns
    @kubectl apply -k $(OVERLAY)
destroy:
    @kubectl delete -k $(OVERLAY)
get-all:
    @kubectl get all -n $(NAMESPACE)

# CLUSTER
cluster-create:
    @k3d cluster create $(CLUSTER) --servers=$(SERVER) --agents=$(AGENTS)
cluster-start:
    k3d cluster start $(CLUSTER)
cluster-stop:
    k3d cluster stop $(CLUSTER)
cluster-delete:
    k3d cluster delete $(CLUSTER)
EOF

# Make exige des TABULATIONS devant les commandes : on convertit les 4 espaces
sed -i 's/^    /\t/' Makefile