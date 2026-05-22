#!/bin/bash
# Qdrant-Collection einmalig anlegen (nach docker compose up ausführen)

SERVER_IP="${SERVER_IP:-localhost}"

curl -s -X PUT "http://${SERVER_IP}:6333/collections/referenzen" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }' | python3 -m json.tool

echo ""
echo "Collection 'referenzen' bereit."
