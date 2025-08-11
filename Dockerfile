# syntax=docker/dockerfile:1
FROM python:3.11.9-alpine3.20

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Libs runtime + deps de build (supprimés ensuite)
RUN apk add --no-cache ca-certificates libstdc++ libffi openssl \
 && apk add --no-cache --virtual .build-deps \
      build-base libffi-dev openssl-dev

# User non-root
RUN adduser -D -H appuser
WORKDIR /app

# Pip outillé et paquets Python
COPY requirements.txt .
RUN python -m pip install --upgrade pip==25.0 setuptools==78.1.1 wheel \
 && pip install --no-cache-dir -r requirements.txt \
 && apk del .build-deps

# Code
COPY . .
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Healthcheck simple TCP (évite de frapper /health pendant le boot)
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD python -c "import socket,sys;s=socket.socket();s.settimeout(2);s.connect(('127.0.0.1',8000));s.close()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
