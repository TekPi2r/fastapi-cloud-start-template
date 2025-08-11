# 🚀 FastAPI Cloud Start Template

[![CI](https://github.com/TekPi2r/fastapi-cloud-start-template/actions/workflows/ci.yml/badge.svg)](https://github.com/TekPi2r/fastapi-cloud-start-template/actions) [![Trivy](https://github.com/TekPi2r/fastapi-cloud-start-template/actions/workflows/trivy.yml/badge.svg)](https://github.com/TekPi2r/fastapi-cloud-start-template/actions) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) ![Python](https://img.shields.io/badge/python-3.11-blue.svg) ![FastAPI](https://img.shields.io/badge/FastAPI-0.116.1-green.svg) ![Kubernetes](https://img.shields.io/badge/Kubernetes-local--dev-blueviolet.svg)

A modern production-ready **FastAPI** template with:
- **OAuth2 JWT authentication**
- **MongoDB** persistence
- **Docker** + **Kubernetes (Minikube)** local dev workflow
- **Pytest** for unit & integration tests
- **Trivy** security scanning
- **GitHub Actions** CI/CD

---

## 📦 Features

- **Authentication**: OAuth2 password flow with JWT
- **Database**: MongoDB (Docker/K8s)
- **Containerization**: Alpine-based Dockerfile, non-root user, healthcheck
- **Orchestration**: Kubernetes manifests for API & Mongo
- **Security**: Trivy scan in CI
- **Testing**: pytest with `unit` & `integration` markers
- **Local Dev**: Minikube image loading (no external registry needed)

---

## 🛠️ Architecture

```text
+-------------------+        +-------------------+
| FastAPI (Uvicorn) | <----> |   MongoDB (K8s)   |
|  OAuth2 + JWT     |        | Persistent Store  |
+-------------------+        +-------------------+
        |                             ^
        v                             |
   Pytest / CI/CD                Trivy Security
```

---

## 🚀 Quick Start

### 1️⃣ Local Dev with Kubernetes
```bash
make dev
```
- Builds Docker image
- Loads into Minikube
- Applies K8s manifests
- Restarts deployment & shows service URL

### 2️⃣ View logs
```bash
make logs
```

### 3️⃣ Run tests
```bash
make tests         # all tests
make tests-int     # integration tests only
```

---

## 🧪 Testing

We use **pytest** with markers:
- `unit` → isolated tests (no DB)
- `integration` → DB/API tests

Example:
```bash
pytest -m integration -v
```

---

## 🔐 Secrets Management

- **Local dev** → `.env` file (loaded by `pydantic.BaseSettings`)
- **K8s** → `secret.yaml` & `config.yaml` (env vars in cluster)
- CI → Secrets injected via GitHub Actions environment variables

---

## 📦 Makefile Commands

| Command         | Description                              |
|-----------------|------------------------------------------|
| `make dev`      | Build, load, apply K8s, restart, URL     |
| `make build`    | Build Docker image                       |
| `make load`     | Load image into Minikube                 |
| `make k8s`      | Apply Kubernetes manifests               |
| `make restart`  | Restart API deployment                   |
| `make logs`     | Follow API logs                          |
| `make tests`    | Run all tests                            |
| `make tests-int`| Run integration tests only               |
| `make clean`    | Remove all K8s resources                 |

---

## 🛡️ Security Scanning

Run locally:
```bash
trivy image fastapi-template:latest
```

In CI:
- Scans image
- Outputs SARIF & HTML reports

---

## 📜 License
MIT License. See [LICENSE](LICENSE).
