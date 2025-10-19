#!/bin/bash
set -euo pipefail

# ---------------- ENV ----------------
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:?Missing DOCKERHUB_USERNAME}"
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:?Missing DOCKERHUB_TOKEN}"
GIT_SHA="${GITHUB_SHA:-$(git rev-parse --short HEAD)}"

# ---------------- LOGIN ----------------
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

# ---------------- BUILD & PUSH ----------------
docker build -t "$DOCKERHUB_USERNAME/frontend:latest" -t "$DOCKERHUB_USERNAME/frontend:$GIT_SHA" ./frontend
docker push "$DOCKERHUB_USERNAME/frontend:latest"
docker push "$DOCKERHUB_USERNAME/frontend:$GIT_SHA"

docker build -t "$DOCKERHUB_USERNAME/login-be:latest" -t "$DOCKERHUB_USERNAME/login-be:$GIT_SHA" ./login-be
docker push "$DOCKERHUB_USERNAME/login-be:latest"
docker push "$DOCKERHUB_USERNAME/login-be:$GIT_SHA"

echo "✅ Docker images pushed: frontend & login-be"
