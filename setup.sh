#!/bin/bash
set -e

if [ ! -f .env ]; then
  echo "FEHLER: .env fehlt. Bitte .env.example kopieren und anpassen."
  exit 1
fi

echo "Baue Embedding-Service (einmalig, lädt ~90 MB Modell)..."
docker compose build embeddings

echo "Starte alle Dienste..."
docker compose up -d

echo ""
echo "Fertig! Dienste erreichbar unter:"
source .env
echo "  NocoDB (Referenzverwaltung): http://${SERVER_IP:-localhost}:8080"
echo "  n8n (Workflows):             http://${SERVER_IP:-localhost}:5678"
