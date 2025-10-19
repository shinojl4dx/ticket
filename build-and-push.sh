#!/bin/bash
# ===============================================================
# Script: build-and-push.sh
# Purpose: Build & Push Docker images, then update ArgoCD manifest repo
# ===============================================================

set -euo pipefail

# ---------- ENV VARIABLES ----------
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:?Missing DOCKERHUB_USERNAME secret}"
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:?Missing DOCKERHUB_TOKEN secret}"
GITOPS_REPO="${GITOPS_REPO:?Missing GITOPS_REPO URL}"
GITOPS_REPO_TOKEN="${GITOPS_REPO_TOKEN:?Missing GITOPS_REPO_TOKEN secret}"
GITOPS_REPO_BRANCH="${GITOPS_REPO_BRANCH:-main}"

GIT_SHA="${GITHUB_SHA:-$(git rev-parse --short HEAD)}"

FRONTEND_DIR="./frontend"
BACKEND_DIR="./login-be"

echo "==============================================================="
echo "🚀 Starting CI Build and Deploy Script"
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

# ---------- Step 3: Build and Push Backend ----------
echo
echo "🏗️  Building and pushing Backend image..."
docker buildx build \
  --platform linux/amd64 \
  -t "${DOCKERHUB_USERNAME}/login-be:latest" \
  -t "${DOCKERHUB_USERNAME}/login-be:${GIT_SHA}" \
  -f "${BACKEND_DIR}/Dockerfile" "${BACKEND_DIR}" \
  --push

echo "✅ Both images pushed successfully."

# ---------- Step 4: Update ArgoCD GitOps Repo ----------
echo
echo "🔄 Updating ArgoCD GitOps manifests with new image tags..."

# Clone the GitOps (CD) repository
WORK_DIR=$(mktemp -d)
git clone --depth=1 --branch "${GITOPS_REPO_BRANCH}" \
  "https://x-access-token:${GITOPS_REPO_TOKEN}@github.com/shinojl4dx/ticket-CD.git" \
  "${WORK_DIR}"

cd "${WORK_DIR}/apps/ticket-app"

# Ensure yq is installed (lightweight YAML editor)
if ! command -v yq &> /dev/null; then
  echo "⚙️  Installing yq..."
  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  sudo chmod +x /usr/local/bin/yq
fi

# Update the image fields in your manifests
FRONTEND_IMAGE="${DOCKERHUB_USERNAME}/frontend:${GIT_SHA}"
BACKEND_IMAGE="${DOCKERHUB_USERNAME}/login-be:${GIT_SHA}"

echo "🔧 Updating manifests in apps/ticket-app/"
for file in $(grep -rl "image:" . | grep -E 'frontend|backend'); do
  if grep -q "frontend" "$file"; then
    echo "Updating Frontend image in $file"
    yq e -i ".spec.template.spec.containers[] |= (select(.name == \"frontend\").image = \"${FRONTEND_IMAGE}\")" "$file" || true
  fi
  if grep -q "backend" "$file"; then
    echo "Updating Backend image in $file"
    yq e -i ".spec.template.spec.containers[] |= (select(.name == \"backend\").image = \"${BACKEND_IMAGE}\")" "$file" || true
  fi
done

git config user.email "github-actions@github.com"
git config user.name "GitHub Actions CI"

git add .
git commit -m "ci: update images to ${GIT_SHA}"
git push origin "${GITOPS_REPO_BRANCH}"

echo "✅ GitOps repo updated. ArgoCD will detect changes and deploy automatically."

# ---------- Step 5: Completion ----------
echo
echo "==============================================================="
echo "🎉 Deployment pipeline complete!"
echo "Images pushed:"
echo "  - ${FRONTEND_IMAGE}"
echo "  - ${BACKEND_IMAGE}"
echo
echo "ArgoCD repo updated at: ${GITOPS_REPO} (${GITOPS_REPO_BRANCH})"
echo "ArgoCD app 'my-app' will auto-sync and deploy."
echo "==============================================================="
