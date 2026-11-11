# =============================================================================
# Multi-Stage Dockerfile — atlas-platform-app
# =============================================================================
# Stage 1 (builder): Install dependencies in a fat image
# Stage 2 (runtime): Copy only what's needed into slim image
#
# Security: runs as non-root user (UID 1000)
# Size: under 100MB final image
# P4 retro fix: CMD path is app.main:app (not main:app)
# =============================================================================

# --------------- Stage 1: Builder ---------------
FROM python:3.12-slim AS builder

WORKDIR /build

# Install dependencies first (layer caching — deps change less than code)
COPY atlas-platform-app/requirements.txt .
RUN pip install --no-cache-dir --timeout=120 --retries=10 \
    -r requirements.txt \
    --target=/build/deps

# Copy application source
COPY atlas-platform-app/ ./app/

# --------------- Stage 2: Runtime ---------------
FROM python:3.12-slim

# Security: non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /build/deps /usr/local/lib/python3.12/site-packages/

# Copy application code
COPY --from=builder /build/app ./app/

# Own the workdir
RUN chown -R appuser:appgroup /app

# Switch to non-root
USER appuser

# Expose port
EXPOSE 8000

# Health check — uses the /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Run the app
# Path: app.main:app because source is at /app/app/main.py
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]