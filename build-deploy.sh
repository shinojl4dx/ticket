#!/bin/bash
set -e

echo "🔧 Starting CI/CD build and deployment..."

# Variables
DOCKERHUB_USER="${DOCKERHUB_USERNAME}"
DOCKERHUB_PASS="${DOCKERHUB_TOKEN}"
GITOPS_REPO="https://github.com/${GITHUB_ACTOR}/ticket-CD.git"
GITOPS_DIR="/tmp/gitops"

if [ -z "$GITOPS_REPO_TOKEN" ]; then
  echo "❌ GITOPS_REPO_TOKEN not set. Exiting."
  exit 1
fi

# Docker login
echo "🔑 Logging in to Docker Hub..."
echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin

# Build and push backend
echo "🐳 Building backend image..."
docker build -t $DOCKERHUB_USER/login-be:latest ./login-be
docker push $DOCKERHUB_USER/login-be:latest

# Build and push frontend
echo "🐳 Building frontend image..."
docker build -t $DOCKERHUB_USER/frontend:latest ./frontend
docker push $DOCKERHUB_USER/frontend:latest

echo "✅ Docker images pushed successfully."

# ==========================================================
# UPDATE MANIFEST FILES WITH LATEST DIGESTS
# ==========================================================
echo "🔄 Updating CD manifests with image SHAs..."

BACKEND_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $DOCKERHUB_USER/login-be:latest | cut -d'@' -f2)
FRONTEND_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $DOCKERHUB_USER/frontend:latest | cut -d'@' -f2)

sed -i "s|$DOCKERHUB_USER/login-be:.*|$DOCKERHUB_USER/login-be@$BACKEND_DIGEST|g" k86/backend.yaml
sed -i "s|$DOCKERHUB_USER/frontend:.*|$DOCKERHUB_USER/frontend@$FRONTEND_DIGEST|g" k86/frontend.yaml

echo "✅ Updated manifests:"
grep "image:" k86/*.yaml

# ==========================================================
# PUSH UPDATED MANIFESTS TO CD REPOSITORY
# ==========================================================
echo "🚀 Pushing manifests to GitOps/CD repository..."

rm -rf $GITOPS_DIR
git clone "https://${GITOPS_REPO_TOKEN}@github.com/${GITHUB_ACTOR}/ticket-CD.git" $GITOPS_DIR

cp -r k86/* $GITOPS_DIR/

cd $GITOPS_DIR
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

git add .
git commit -m "Update manifests with new image SHAs on $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit"
git push origin main

echo "✅ CD manifests pushed successfully."
echo "🎯 ArgoCD will detect the new commit and redeploy automatically if auto-sync is enabled."
