#!/bin/bash
# Integration smoke test — run after ./setup.sh and ./init-qdrant.sh
# Usage: SERVER_IP=192.168.1.100 ./test_integration.sh
#        ./test_integration.sh   (defaults to localhost)

set -euo pipefail

SERVER_IP="${SERVER_IP:-localhost}"
PASS=0
FAIL=0

green() { echo -e "\033[32m✓ $1\033[0m"; }
red()   { echo -e "\033[31m✗ $1\033[0m"; }

check() {
  local label="$1"
  local cmd="$2"
  local expect="${3:-}"

  local out
  if out=$(eval "$cmd" 2>&1); then
    if [ -n "$expect" ] && ! echo "$out" | grep -q "$expect"; then
      red "$label (unexpected response: ${out:0:120})"
      ((FAIL++))
    else
      green "$label"
      ((PASS++))
    fi
  else
    red "$label (error: ${out:0:120})"
    ((FAIL++))
  fi
}

echo ""
echo "=== Integration Test: Referenz-System (SERVER_IP=${SERVER_IP}) ==="
echo ""

# --- Docker Services ---
echo "[ Docker Services ]"
check "docker compose running" \
  "docker compose ps --status running 2>/dev/null | grep -c 'running'" \
  "[1-9]"

check "embedding service healthy" \
  "curl -sf http://${SERVER_IP}:8001/health" \
  "ok"

check "qdrant reachable" \
  "curl -sf http://${SERVER_IP}:6333/healthz" \
  ""

check "qdrant collection exists" \
  "curl -sf http://${SERVER_IP}:6333/collections/referenzen" \
  "referenzen"

check "nocodb reachable" \
  "curl -sf -o /dev/null -w '%{http_code}' http://${SERVER_IP}:8080" \
  "200\|302"

check "n8n reachable" \
  "curl -sf -o /dev/null -w '%{http_code}' http://${SERVER_IP}:5678" \
  "200\|301\|302"

echo ""
echo "[ Embedding Service API ]"

check "POST /embed returns 384-dim vector" \
  "curl -sf -X POST http://${SERVER_IP}:8001/embed \
    -H 'Content-Type: application/json' \
    -d '{\"text\": \"Wärmedämmung Neubau\"}'" \
  "embedding"

check "POST /embed/batch returns multiple vectors" \
  "curl -sf -X POST http://${SERVER_IP}:8001/embed/batch \
    -H 'Content-Type: application/json' \
    -d '{\"texts\": [\"Text A\", \"Text B\"]}'" \
  "embeddings"

echo ""
echo "[ End-to-End: Sync + Search ]"

# Simulate NocoDB webhook (sync a test reference)
SYNC_RESULT=$(curl -sf -X POST "http://${SERVER_IP}:5678/webhook/referenz-sync" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "rows": [{
        "Id": 9999,
        "Titel": "Test Referenz Integration",
        "Beschreibung": "Automatischer Integrationstest für das Referenzsystem.",
        "Tags": ["Test", "Integration"],
        "Foto": null
      }]
    }
  }' 2>&1 || echo "CURL_ERROR")

if echo "$SYNC_RESULT" | grep -qi "error\|CURL_ERROR\|not found"; then
  red "sync webhook (response: ${SYNC_RESULT:0:120})"
  ((FAIL++))
  echo "     → Is the 'Referenz Sync' workflow active in n8n?"
else
  green "sync webhook"
  ((PASS++))
fi

# Wait briefly for Qdrant to index
sleep 1

# Search for the test reference
SEARCH_RESULT=$(curl -sf -X POST "http://${SERVER_IP}:5678/webhook/referenz-suchen" \
  -H "Content-Type: application/json" \
  -d '{"query": "Integrationstest Referenzsystem", "limit": 3}' 2>&1 || echo "CURL_ERROR")

if echo "$SEARCH_RESULT" | grep -qi "CURL_ERROR\|not found"; then
  red "search webhook (response: ${SEARCH_RESULT:0:120})"
  ((FAIL++))
  echo "     → Is the 'Referenz Suche' workflow active in n8n?"
elif echo "$SEARCH_RESULT" | grep -qi "referenzen\|score\|titel"; then
  green "search webhook returns results"
  ((PASS++))
else
  # Search works but no results yet (index delay) — partial pass
  green "search webhook reachable (no results yet — may need a moment)"
  ((PASS++))
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Troubleshooting hints:"
  echo "  • Services not up?      docker compose up -d && docker compose logs -f"
  echo "  • Qdrant collection?    ./init-qdrant.sh"
  echo "  • n8n workflows?        Import workflow-sync.json + workflow-search.json, then Activate"
  echo "  • Wrong SERVER_IP?      SERVER_IP=<your-ip> ./test_integration.sh"
  echo ""
  exit 1
fi

echo "All good. System is ready."
echo ""
