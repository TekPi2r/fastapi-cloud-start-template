# Dockerfile (extrait)
FROM python:3.11-slim

# (optionnel) OS updates minimaux
RUN apt-get update && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/*

# 🔧 Corrige les CVE Python en upgradeant pip/setuptools/wheel
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
