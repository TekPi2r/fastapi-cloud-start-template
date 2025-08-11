# -------- Config locale --------
IMG_NAME := fastapi-template
IMG_TAG  := latest
IMG      := $(IMG_NAME):$(IMG_TAG)
K8S_DIR  := k8s
SERVICE  := fastapi-service
NAMESPACE := default

.PHONY: dev build load k8s restart url logs down clean

dev: build load k8s restart url ## Build + load + apply + restart + affiche l'URL

build: ## Build l'image Docker en local
	docker build -t $(IMG) .

load: ## Charge l'image dans Minikube (évite Docker Hub)
	minikube image load $(IMG) --overwrite

k8s: ## (Ré)applique les manifests K8s
	kubectl apply -f $(K8S_DIR)

restart: ## Redémarre le déploiement et attend que ça roule
	kubectl rollout restart deploy/fastapi-deployment
	kubectl rollout status  deploy/fastapi-deployment

url: ## Affiche l'URL du service (sans ouvrir le navigateur)
	@echo "Service URL:"
	@minikube service $(SERVICE) --namespace $(NAMESPACE) --url

logs: ## Suivre les logs de l'API
	kubectl logs -f deploy/fastapi-deployment -c fastapi-container

down: ## Stoppe tout (conserve images)
	kubectl delete -f $(K8S_DIR) --ignore-not-found=true

clean: down ## Tout propre
	@echo "Rien d'autre à nettoyer."
