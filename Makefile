# VARIABLES
CLUSTER ?= app-cluster
MANIFEST ?= deployment.yaml
NAMESPACE ?= demo-app
SERVER ?= 1
AGENTS ?= 2

# INFRA INIT
init-cluster-and-deploy:
	@./script.sh

deploy:
	@kubectl apply -f namespace.yaml
	@kubectl apply -f network-policy.yaml
	@kubectl apply -f roles-config.yaml
	@kubectl apply -f app-config.yaml
	@kubectl apply -f secret-stringdata.yaml
	@kubectl apply -f deployment.yaml
get-all:
	@kubectl get all -n $(NAMESPACE)

# NODES


# CLUSTER
cluster-create:
	@k3d cluster create $(CLUSTER) --servers=$(SERVER) --agents=$(AGENTS)
cluster-start:
	k3d cluster start $(CLUSTER)
cluster-stop:
	k3d cluster stop $(CLUSTER)
cluster-delete:
	k3d cluster delete $(CLUSTER)				
