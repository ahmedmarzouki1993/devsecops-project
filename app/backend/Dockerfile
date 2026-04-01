# ── Stage 1: build dependencies ───────────────────────────────────────────────
# Use slim (not alpine) — musl libc breaks some Python C extensions.
# Pin exact version; never use 'latest' (breaks reproducibility + security scans).
FROM python:3.12-slim AS builder

WORKDIR /build

# Copy requirements first so Docker caches this layer.
# Only re-runs pip install when requirements.txt changes, not on every code change.
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: runtime image ────────────────────────────────────────────────────
# Fresh base — no build tools, no pip, smaller attack surface.
FROM python:3.12-slim AS runtime

# Non-root user (UID 1001) — if an attacker escapes the app, they don't get root.
RUN groupadd --gid 1001 appuser && \
    useradd --uid 1001 --gid 1001 --no-create-home appuser

WORKDIR /app

# Copy only the installed packages from the builder stage (not pip itself)
COPY --from=builder /install /usr/local

# Copy application source
COPY app/ ./app/

# Drop to non-root before the process starts
USER appuser

EXPOSE 8000

# Health check — Docker and K8s can both use this
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"]
