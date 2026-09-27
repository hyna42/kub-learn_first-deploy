CLUSTER ?= app-cluster
MANIFEST ?= deployment.yml

# INFRA INIT
init-cluster-and-deploy:
	@./script.sh

deployment:
	@kubectl apply -f deployment.yml
get-all:
	@kubectl get all -n demo-app

apply:
	@kubectl apply -f $(MANIFEST)

# NODES


# CLUSTER
cluster-start:
	k3d cluster start $(CLUSTER)
cluster-stop:
	k3d cluster stop $(CLUSTER)		
