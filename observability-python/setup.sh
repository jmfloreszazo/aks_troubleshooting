#!/bin/bash

# AI-Powered Observability Setup Script
# =====================================

set -e

echo "🚀 Setting up AI-Powered Observability Analysis..."

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

# Create virtual environment
echo "📦 Creating Python virtual environment..."
python3 -m venv observability-env

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source observability-env/bin/activate

# Upgrade pip
echo "📈 Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "📚 Installing Python dependencies..."
pip install -r requirements.txt

echo "✅ Setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Copy .env.example to .env and configure your endpoints"
echo "2. Activate the environment: source observability-env/bin/activate"
echo "3. Run the analyzer: python ai_observability_analyzer.py"
echo ""
echo "🔧 Configuration needed in .env:"
echo "- AZURE_OPENAI_ENDPOINT"
echo "- AZURE_OPENAI_API_KEY"  
echo "- LOKI_ENDPOINT"
echo "- PROMETHEUS_ENDPOINT"
