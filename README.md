# 🚀 fastapi-cloud-start-template

Un template FastAPI moderne avec MongoDB, Docker, CI/CD et infrastructure multi-cloud (AWS & Azure), prêt à l'emploi pour projets DevSecOps.

## ✨ Features

- ⚙️ **FastAPI** backend prêt à l'emploi
- 🗄️ **MongoDB** comme base de données NoSQL
- 🐳 **Docker & Docker Compose** pour l'environnement de développement et de production
- 🔁 **CI/CD avec GitHub Actions**
- ☁️ **Prêt pour déploiement sur AWS (EC2/S3) & Azure (App Service/Storage)**
- 📦 **Infrastructure as Code (Terraform)** pour provisioning cloud
- 🔐 **Sécurité : Scans de vulnérabilités (Trivy ou Snyk)**
- 📊 **Monitoring (Grafana + Prometheus)** [optionnel]
- 📄 Code bien structuré et réutilisable

## 📁 Structure du projet

```
fastapi-cloud-start-template/
├── app/                    # Code source FastAPI
├── docker/                 # Fichiers liés à Docker et docker-compose
├── .github/workflows/      # Pipelines GitHub Actions CI/CD
├── infra/                  # Fichiers Terraform pour AWS & Azure
├── tests/                  # Tests unitaires
├── .env.example            # Variables d'environnement
├── Dockerfile              # Image de l’application FastAPI
├── docker-compose.yml      # Orchestration locale
└── README.md
```

## 🚀 Lancer le projet en local

1. Copier le fichier `.env.example` en `.env` et compléter les variables.
2. Lancer l’environnement via Docker Compose :

```bash
docker-compose up --build
```

3. L’API sera disponible sur `http://localhost:8000/docs`

## 🧪 Exécuter les tests

```bash
docker-compose exec app pytest
```

## 🔐 Scans de sécurité (optionnel)

```bash
trivy image fastapi-app
# ou
snyk test --docker fastapi-app
```

## ☁️ Déploiement Cloud (à venir)

- AWS (EC2 / ECS / S3)
- Azure App Services
- Terraform pour provisioning

## 🤝 Contribuer

1. Fork le repo
2. Crée une branche : `git checkout -b feature/ma-feature`
3. Commit : `git commit -am 'Ajout nouvelle feature'`
4. Push : `git push origin feature/ma-feature`
5. Pull Request !

## 🧑‍💻 Auteur

Pierre Dallara – [LinkedIn](https://www.linkedin.com/in/pierre-dallara/)

---

> Ce projet est en cours de construction et évoluera vers un modèle de template open-source complet, incluant CI/CD, sécurité et cloud.
