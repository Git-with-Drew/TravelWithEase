#!/bin/bash
set -e

echo "🚀 Packaging Lambda function..."

# Clean up
echo "🧹 Cleaning old artifacts..."
rm -f contact_form_lambda.zip
rm -rf node_modules

# Install dependencies
echo "📦 Installing dependencies..."
npm install --production --silent

if [ ! -d "node_modules" ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed"

# Create zip (GitBash/WSL compatible)
echo "📦 Creating deployment package..."
zip -r contact_form_lambda.zip . \
    -x "*.sh" \
    -x "*.bat" \
    -x "*.md" \
    -x "README*" \
    -x "package-lock.json" \
    -x ".git*" \
    -x "*.log" \
    -q

if [ ! -f "contact_form_lambda.zip" ]; then
    echo "❌ Failed to create package"
    exit 1
fi

echo "✅ Package created: contact_form_lambda.zip"
echo "📊 Size: $(du -h contact_form_lambda.zip | cut -f1)"
echo "🎉 Ready for deployment!"