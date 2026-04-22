# ── Imagen base ───────────────────────────────
FROM python:3.9-slim

# ── Variables de entorno ──────────────────────
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ── Directorio de trabajo ─────────────────────
WORKDIR /app

# ── Dependencias del sistema ──────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        default-libmysqlclient-dev gcc \
    && rm -rf /var/lib/apt/lists/*

# ── Dependencias Python ───────────────────────
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Código de la aplicación ───────────────────
COPY app.py .

# ── Puerto expuesto ───────────────────────────
EXPOSE 8080

# ── Arranque ──────────────────────────────────
CMD ["python", "app.py"]
