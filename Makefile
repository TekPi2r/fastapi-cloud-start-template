# -------- Config locale --------
IMG_NAME := fastapi-template
IMG_TAG  := latest
IMG      := $(IMG_NAME):$(IMG_TAG)
K8S_DIR  := k8s
SERVICE  := fastapi-service
NAMESPACE := default

# -------- Python / venv --------
VENV    := .venv
PYTHON  := $(VENV)/bin/python
PYTEST  := $(VENV)/bin/pytest

# Si le binaire pytest n'existe pas dans le venv, on crée le venv + on installe les deps
$(PYTEST):
	python3 -m venv $(VENV)
	$(PYTHON) -m pip install -U pip
	$(PYTHON) -m pip install -r requirements.txt

.PHONY: dev build load k8s restart url logs down clean tests tests-integration venv

# -------- Dev K8s end-to-end --------
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

# -------- Tests --------
tests: $(PYTEST) ## Lance tous les tests avec le venv (sans l'activer)
	PYTHONPATH=. $(PYTEST) -v

tests-integration: $(PYTEST) ## Lance seulement les tests marqués "integration"
	PYTHONPATH=. $(PYTEST) -m integration -v

# Optionnel: pour forcer la (ré)création du venv à la main
venv: $(PYTEST)
	@echo "venv prêt: $(VENV)"
