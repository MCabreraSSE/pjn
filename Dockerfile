FROM python:3.11-slim as base

# Metadatos de la imagen
LABEL maintainer="MCabreraSSE <martin@empresa.com>"
LABEL version="2.0"
LABEL description="Sistema PJN - Automatización de descarga de expedientes con IA"

# Variables de build
ARG DEBIAN_FRONTEND=noninteractive
ARG PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    # OCR y procesamiento de documentos
    tesseract-ocr tesseract-ocr-spa \
    ghostscript poppler-utils \
    # Playwright dependencies
    libglib2.0-0 libnss3 libatk1.0-0 \
    libatk-bridge2.0-0 libdrm2 libxkbcommon0 \
    libgbm1 libatspi2.0-0 libx11-6 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxrandr2 \
    libasound2 libxss1 libgtk-3-0 \
    # Utilidades del sistema
    curl wget git unzip \
    # Limpieza
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Usuario no root para seguridad
RUN groupadd -r pjnuser && useradd -r -g pjnuser -u 1000 pjnuser \
    && mkdir -p /app /app/logs /app/expedientes /app/config /app/backups \
    && chown -R pjnuser:pjnuser /app

# Cambiar a usuario no privilegiado
USER pjnuser
WORKDIR /app

# Variables de entorno para Python y Playwright
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PLAYWRIGHT_BROWSERS_PATH=/home/pjnuser/ms-playwright

# Copiar requirements y instalar dependencias Python
COPY --chown=pjnuser:pjnuser requirements.txt .
RUN pip install --user --no-warn-script-location -r requirements.txt \
    && echo 'export PATH="/home/pjnuser/.local/bin:$PATH"' >> /home/pjnuser/.bashrc

# Instalar navegadores de Playwright
RUN /home/pjnuser/.local/bin/playwright install chromium \
    && /home/pjnuser/.local/bin/playwright install-deps chromium

# Copiar código fuente
COPY --chown=pjnuser:pjnuser . .

# Crear directorios necesarios
RUN mkdir -p logs expedientes config backups data

# Agregar el directorio local bin al PATH
ENV PATH="/home/pjnuser/.local/bin:$PATH"

# Puerto del web dashboard
EXPOSE 8080

# Volúmenes recomendados
VOLUME ["/app/expedientes", "/app/logs", "/app/config", "/app/backups"]

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -m pjn health --quick || exit 1

# Punto de entrada por defecto
CMD ["python", "-m", "pjn", "web", "--host", "0.0.0.0", "--port", "8080"]
