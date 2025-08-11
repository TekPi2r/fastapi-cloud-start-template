# Dockerfile
FROM python:3.11-slim

# OS updates (limités) + nettoyage
RUN apt-get update \
 && apt-get -y upgrade --no-install-recommends \
 && rm -rf /var/lib/apt/lists/*

# Corrige pip/setuptools/wheel (évite CVE setuptools < 78.1.1)
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
