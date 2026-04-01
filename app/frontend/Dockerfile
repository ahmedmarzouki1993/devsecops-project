# ── Stage 1: build React app ──────────────────────────────────────────────────
# node:20-alpine — tiny base, node LTS, Alpine for minimal attack surface
FROM node:20-alpine AS builder

WORKDIR /build

# Copy package files first for layer caching (npm install only re-runs when they change)
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# Copy source and build
COPY public/ ./public/
COPY src/ ./src/
RUN npm run build


# ── Stage 2: serve with Nginx ─────────────────────────────────────────────────
# nginx:1.27-alpine — pinned version, no Node.js, much smaller image
FROM nginx:1.27-alpine AS runtime

# Upgrade all Alpine packages to patch OS-level CVEs (e.g. libxml2, openssl).
# Alpine packages are separate from the nginx version — this keeps nginx pinned
# while pulling the latest security patches for system libraries.
RUN apk upgrade --no-cache

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy our custom config
COPY nginx.conf /etc/nginx/conf.d/app.conf

# Copy built React assets from builder
COPY --from=builder /build/build /usr/share/nginx/html

# Non-root: nginx master runs as root briefly to bind port, workers drop to nginx user.
# We use port 8080 (unprivileged) to match non-root container requirements.
# Update nginx.pid path so the nginx user can write it
RUN sed -i 's|/var/run/nginx.pid|/tmp/nginx.pid|g' /etc/nginx/nginx.conf && \
    chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/log/nginx

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
