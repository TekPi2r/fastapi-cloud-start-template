# fastapi-cloud-start-template

A production-ready and extensible FastAPI template designed for cloud deployment. This project integrates key DevOps practices with a modern microservice backend architecture using Docker, MongoDB, and CI/CD pipelines, and is built for seamless deployment on both AWS and Azure.

## 🚀 Features

- ⚡ FastAPI backend (async Python web framework)
- 🐳 Docker & Docker Compose
- 🗄️ MongoDB integration (with Docker)
- 🔁 GitHub Actions CI/CD pipeline
- ☁️ Dual cloud deployment support:
  - AWS EC2 or ECS
  - Azure App Service or Azure Container Instances
- 🔐 Security Scanning (Trivy or Snyk) [optional]
- 📈 Monitoring & Logging with Prometheus + Grafana [optional]
- ⚙️ Infrastructure as Code with Terraform [optional]
- 🧪 Unit & Integration testing (pytest) [coming soon]

## 📦 Stack

| Category           | Technology               |
|--------------------|---------------------------|
| Backend API        | FastAPI (Python)         |
| Database           | MongoDB                  |
| Containerization   | Docker                   |
| Orchestration      | Kubernetes (optional)    |
| CI/CD              | GitHub Actions (+ Jenkins optional) |
| Cloud Providers    | AWS (EC2, S3) + Azure (App Service, Storage) |
| IaC                | Terraform (optional)     |
| Security           | Trivy or Snyk (optional) |
| Monitoring         | Prometheus + Grafana (optional) |

## 🧰 Getting Started

### Prerequisites

- Docker & Docker Compose
- Python 3.10+
- GitHub account for CI/CD
- (Optional) AWS CLI or Azure CLI installed & configured

### Installation

```bash
git clone https://github.com/your-username/fastapi-cloud-start-template.git
cd fastapi-cloud-start-template
cp .env.example .env
docker-compose up --build
```

### Running the app

By default, the API will run on `http://localhost:8000`.

### Documentation

Visit Swagger UI: `http://localhost:8000/docs`

## 🚧 Work in Progress

This template is under active development. Future plans include:

- Helm charts for Kubernetes
- More Terraform modules
- Advanced logging and alerting setup
- Advanced test coverage and GitHub badges

## 🤝 Contributing

Contributions are welcome! Fork the repo, create a feature branch and submit a pull request.

## 📄 License

This project is licensed under the MIT License.
