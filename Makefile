init-cluster-and-deploy:
	@./script.sh

deployment:
	@kubectl apply -f deployment.yml
get-all:
	@kubectl get all -n demo-app
