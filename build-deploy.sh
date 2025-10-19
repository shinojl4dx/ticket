#!/bin/bash
set -euo pipefail

# ---------------- CONFIG ----------------
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:?Set this env variable}"
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:?Set this env variable}"
CI_DIR=$(pwd)
CD_REPO="https://github.com/shinojl4dx/ticket-CD.git"
CD_DIR="/tmp/gitops"
GIT_SHA=$(git rev-parse --short HEAD)

# ---------------- DOCKER LOGIN ----------------
echo "🔐 Logging into Docker Hub..."
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

# ---------------- BUILD & PUSH FRONTEND ----------------
echo "📦 Building and pushing frontend..."
docker build -t "$DOCKERHUB_USERNAME/frontend:latest" ./frontend
docker push "$DOCKERHUB_USERNAME/frontend:latest"
docker tag "$DOCKERHUB_USERNAME/frontend:latest" "$DOCKERHUB_USERNAME/frontend:$GIT_SHA"
docker push "$DOCKERHUB_USERNAME/frontend:$GIT_SHA"

# ---------------- BUILD & PUSH BACKEND ----------------
echo "📦 Building and pushing backend..."
docker build -t "$DOCKERHUB_USERNAME/login-be:latest" ./login-be
docker push "$DOCKERHUB_USERNAME/login-be:latest"
docker tag "$DOCKERHUB_USERNAME/login-be:latest" "$DOCKERHUB_USERNAME/login-be:$GIT_SHA"
docker push "$DOCKERHUB_USERNAME/login-be:$GIT_SHA"

echo "✅ Docker images pushed successfully."

# ---------------- UPDATE CD MANIFESTS ----------------
echo "🔄 Updating CD manifests with latest SHA..."
rm -rf "$CD_DIR"
git clone "$CD_REPO" "$CD_DIR"
cd "$CD_DIR"

# Copy k86 deployment YAMLs from CI repo
cp -r "$CI_DIR/k86/"* "$CD_DIR/"

# Replace image tags in backend.yaml
sed -i "s#image: .*login-be:.*#image: docker.io/$DOCKERHUB_USERNAME/login-be:$GIT_SHA#g" backend.yaml

# Replace image tags in frontend.yaml
sed -i "s#image: .*frontend:.*#image: docker.io/$DOCKERHUB_USERNAME/frontend:$GIT_SHA#g" frontend.yaml

# Commit & push changes to CD repo
git config user.email "ci@example.com"
git config user.name "ci-bot"
git add .
git commit -m "Update Docker images to $GIT_SHA" || echo "No changes to commit"
git push "$CD_REPO"

echo "🎉 CD manifests updated. ArgoCD will deploy automatically."
