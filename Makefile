CLUSTER ?= app-cluster

# INFRA INIT
init-cluster-and-deploy:
	@./script.sh

deployment:
	@kubectl apply -f deployment.yml
get-all:
	@kubectl get all -n demo-app


# NODES


# CLUSTER
cluster-start:
	k3d cluster start $(CLUSTER)
cluster-stop:
	k3d cluster stop $(CLUSTER)