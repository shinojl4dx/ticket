#!/bin/bash
# ===============================================================
# Script: build-and-push.sh
# Purpose: Build and push frontend & backend Docker images to Docker Hub
# Triggered inside GitHub Actions (secrets passed as env vars)
# ===============================================================

set -euo pipefail

# ---------- ENV VARIABLES ----------
# These are automatically injected from GitHub Secrets in your workflow
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:?Missing DOCKERHUB_USERNAME secret}"
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:?Missing DOCKERHUB_TOKEN secret}"

# Git commit SHA from GitHub context (fallback to local git)
GIT_SHA="${GITHUB_SHA:-$(git rev-parse --short HEAD)}"

FRONTEND_DIR="./frontend"
BACKEND_DIR="./login-be"

echo "==============================================================="
echo "🚀 Starting CI Build and Push Script"
echo "Git Commit SHA: ${GIT_SHA}"
echo "Docker Hub User: ${DOCKERHUB_USERNAME}"
echo "==============================================================="

# ---------- Step 1: Authenticate to Docker Hub ----------
echo "🔑 Logging in to Docker Hub..."
echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin
echo "✅ Docker login successful."

# ---------- Step 2: Build and Push Frontend ----------
echo
echo "🏗️  Building and pushing Frontend image..."
docker buildx build \
  --platform linux/amd64 \
  -t "${DOCKERHUB_USERNAME}/frontend:latest" \
  -t "${DOCKERHUB_USERNAME}/frontend:${GIT_SHA}" \
  -f "${FRONTEND_DIR}/Dockerfile" "${FRONTEND_DIR}" \
  --push

echo "✅ Frontend image pushed successfully."

# ---------- Step 3: Build and Push Backend ----------
echo
echo "🏗️  Building and pushing Backend image..."
docker buildx build \
  --platform linux/amd64 \
  -t "${DOCKERHUB_USERNAME}/login-be:latest" \
  -t "${DOCKERHUB_USERNAME}/login-be:${GIT_SHA}" \
  -f "${BACKEND_DIR}/Dockerfile" "${BACKEND_DIR}" \
  --push

echo "✅ Backend image pushed successfully."

# ---------- Step 4: Completion ----------
echo
echo "==============================================================="
echo "🎉 All Docker images have been built and pushed successfully!"
echo "Frontend: ${DOCKERHUB_USERNAME}/frontend:{latest,${GIT_SHA}}"
echo "Backend : ${DOCKERHUB_USERNAME}/login-be:{latest,${GIT_SHA}}"
echo "==============================================================="
