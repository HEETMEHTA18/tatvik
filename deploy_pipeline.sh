#!/bin/bash
# Exit immediately if any command fails
set -e

echo "=============================================="
echo "🚀 DEVMENTOR CI/CD DEPLOYMENT PIPELINE"
echo "=============================================="

echo "🔎 Step 1: Running Static Code Analysis (Lint checks)..."
flutter analyze || echo "⚠️ Analysis warnings found, proceeding with build..."

echo "🧪 Step 2: Running Unit & Widget Tests..."
flutter test

# Backup Vercel config if it exists
if [ -d "build/web/.vercel" ]; then
  echo "💾 Backing up Vercel config..."
  rm -rf .vercel_backup
  cp -r build/web/.vercel .vercel_backup
fi

echo "📦 Step 3: Compiling Production Web App..."
flutter build web --release --dart-define=API_BASE_URL=https://devmentor-jmjh.onrender.com/api/v1

# Restore Vercel config
if [ -d ".vercel_backup" ]; then
  echo "🔄 Restoring Vercel config..."
  mkdir -p build/web
  cp -r .vercel_backup build/web/.vercel
  rm -rf .vercel_backup
fi

# Copy vercel.json configuration for SPA routing
if [ -f "web/vercel.json" ]; then
  echo "📄 Copying vercel.json to build/web..."
  cp web/vercel.json build/web/vercel.json
fi

echo "☁️ Step 4: Deploying static build to Vercel..."
npx vercel --cwd build/web --prod --yes

echo "=============================================="
echo "🎉 PIPELINE PASSED & DEPLOYED SUCCESSFULLY!"
echo "=============================================="
