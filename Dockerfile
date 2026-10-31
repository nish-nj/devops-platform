# syntax=docker/dockerfile:1

# ---- Stage 1: generate build metadata (status.json) ----
FROM alpine:3.20 AS meta
ARG APP_VERSION=dev
ARG GIT_SHA=local
ARG BUILD_TIME=unknown
ARG DEPLOY_ENV=local
RUN printf '{"version":"%s","commit":"%s","built_at":"%s","environment":"%s"}\n' \
    "$APP_VERSION" "$GIT_SHA" "$BUILD_TIME" "$DEPLOY_ENV" > /status.json

# ---- Stage 2: runtime (non-root, port 8080) ----
FROM nginxinc/nginx-unprivileged:stable-alpine
LABEL org.opencontainers.image.title="devops-platform" \
      org.opencontainers.image.description="Cloud-Native DevOps Deployment & Monitoring Platform dashboard"

# Install the latest security patches for OS packages, then drop back to non-root.
USER root
RUN apk upgrade --no-cache
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY app/ /usr/share/nginx/html/
COPY --from=meta /status.json /usr/share/nginx/html/status.json
USER 101

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8080/healthz || exit 1