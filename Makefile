# VARIABLES
CLUSTER ?= app-cluster
NAMESPACE ?= demo-app
SERVER ?= 1
AGENTS ?= 2

MANIFESTS = namespace.yaml network-policy.yaml deployment.yaml
FILES     = $(addprefix -f ,$(MANIFESTS))

.PHONY: ns validate-client validate-server diff check deploy get-all cluster-create cluster-start cluster-stop cluster-delete

# CLUSTER
cluster-create:
	@k3d cluster create $(CLUSTER) --servers=$(SERVER) --agents=$(AGENTS)
cluster-start:
	k3d cluster start $(CLUSTER)
cluster-stop:
	k3d cluster stop $(CLUSTER)
cluster-delete:
	k3d cluster delete $(CLUSTER)	
# ***********************************************************************

# BOOTSTRAP
ns:
	@kubectl apply -f namespace.yaml

# VALIDATION
validate-client:
	@kubectl apply --dry-run=client $(FILES)

validate-server: ns
	@kubectl apply --dry-run=server $(FILES)

diff: ns
	@kubectl diff $(FILES) || true

check: validate-client validate-server diff

# DEPLOYMENT
deploy: check
	@kubectl apply $(FILES)	
get-all:
	@kubectl get all -n $(NAMESPACE)
# ***********************************************************************
