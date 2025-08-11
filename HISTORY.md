# Project History

## 1️⃣ Version 1.0.0 - Initial Setup (2025-08-08)

### ✅ Backend Features
- Initialized project with **FastAPI**
- Created basic endpoints:
  - `GET /health` – Health check
  - `POST /items` & `GET /items` – Simple CRUD
- Used **Pydantic v2** for request/response models

### 🧪 Testing
- Integrated **pytest**
- Wrote unit tests for:
  - Health check endpoint
  - Item creation and retrieval
- MongoDB mocked for local tests
- Tests run successfully both locally and in CI

### 🧹 Code Quality
- Configured **ruff** for linting
- Enabled **auto-fix** with `ruff --fix`
- Added linting to GitHub Actions (CI fails on lint errors)

### ⚙️ DevOps & Tooling
- Added `Dockerfile` for containerized deployment
- Created `docker-compose.yml` with:
  - FastAPI app
  - MongoDB service
- Environment managed via `.env` and `python-dotenv`
- Set up Python virtual environment `.venv`

### 🔄 CI/CD
- Added **GitHub Actions workflow** with:
  - Service container for MongoDB
  - Test job using `pytest`
  - Lint job using `ruff`
  - MongoDB health check before running tests

---

## Next Steps (planned)
- Add **Trivy** to scan Docker images
- Possibly integrate **type checking** (`mypy` or `pyright`)
- Prepare for deployment (Azure, AWS, or other)
- Write full `README.md`




## 2️⃣ Version 2.0.0 - Kubernetes and CI overhaul (2025-08-11)

- Switched to Alpine Docker image, non-root user, and healthcheck.
- Added Kubernetes manifests (API + Mongo, ConfigMap/Secret, probes).
- Introduced Makefile with handy targets: `dev`, `tests`, `tests-integration`, `logs`, `clean`.
- Split pytest into unit vs integration with markers and `pytest.ini` env.
- Added GitHub Actions pipeline: unit & integration jobs; Mongo as a service for integration.
- Wired secrets/config: `.env` (optional), `pytest.ini` (CI), `k8s/secret.yaml` + `k8s/config.yaml` (cluster).
- Documented Trivy usage for image scanning.
