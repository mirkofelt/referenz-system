# Referenz-System

Self-hosted semantic search for project references. Add references in NocoDB — they're automatically embedded and searchable with plain-text queries, no keywords needed.

## Architecture

```
NocoDB  ──webhook──▶  n8n (Sync)  ──▶  Embedding Service  ──▶  Qdrant
                          │
Browser/Tool  ──────▶  n8n (Search)  ──▶  Embedding Service  ──▶  Qdrant
```

| Service | Port | Role |
|---|---|---|
| NocoDB | 8080 | Reference management UI |
| n8n | 5678 | Automation: sync + search API |
| Qdrant | 6333 | Vector database |
| Embedding Service | 8001 | all-MiniLM-L6-v2 (local, no GPU) |
| PostgreSQL | — | NocoDB backend (internal) |

## Quickstart

**Requirements:** Docker + Docker Compose, ~2 GB RAM, ports 5678 / 8080 / 6333 / 8001 free.

```bash
# 1. Configure
cp .env.example .env
# Edit .env: set SERVER_IP to your machine's local IP

# 2. Start (builds embedding service, downloads ~90 MB model once)
chmod +x setup.sh && ./setup.sh

# 3. Create Qdrant collection (run once after first start)
chmod +x init-qdrant.sh && ./init-qdrant.sh
```

## NocoDB Setup (once)

1. Open `http://SERVER_IP:8080`, create an account
2. New Base → New Table: **Referenzen**
3. Add columns:

| Column | Type |
|---|---|
| Titel | Text |
| Beschreibung | Long Text |
| Tags | Multi Select |
| Foto | Attachment |

4. In the table → **Details** → **Webhooks** → New webhook:
   - Event: After Insert + After Update
   - URL: `http://n8n:5678/webhook/referenz-sync`
   - Method: POST

## n8n Setup (once)

1. Open `http://SERVER_IP:5678`, create an account
2. Import `workflow-sync.json` → Activate
3. Import `workflow-search.json` → Activate

## Usage

**Add a reference:** Enter it in NocoDB → saved and indexed automatically.

**Search:**

```bash
curl -X POST http://SERVER_IP:5678/webhook/referenz-suchen \
  -H "Content-Type: application/json" \
  -d '{"query": "Wärmedämmung Wohngebäude Neubau", "limit": 5}'
```

Response:

```json
{
  "referenzen": [
    {
      "score": 0.91,
      "titel": "Neubau EFH Potsdam",
      "beschreibung": "Energieberatung und Baubegleitung...",
      "tags": "Neubau, EFH, KfW55",
      "foto_url": null
    }
  ],
  "count": 1
}
```

`score` ranges 0–1. Above 0.7 is a strong match.

## Tests

**Unit tests** (no Docker required — tests the embedding service in isolation):

```bash
cd embedding-service
pip install -r requirements.txt
pytest tests/ -v
```

**Integration test** (requires the full stack to be running):

```bash
chmod +x test_integration.sh
SERVER_IP=192.168.1.100 ./test_integration.sh
```

Checks all services, the embedding API, the sync webhook, and an end-to-end search. Prints clear pass/fail with troubleshooting hints on failure.

## Operations

```bash
# Stop (data preserved in volumes)
docker compose down

# Start
docker compose up -d

# Logs
docker compose logs -f

# Destroy including data
docker compose down -v
```

**Data lives in Docker volumes** (`postgres_data`, `qdrant_data`, `n8n_data`) — survives restarts, only lost with `down -v`.

## Troubleshooting

**Reference added but not findable:** Check n8n → Executions for errors on the Sync workflow.

**Embedding service slow on first query:** Model is cached at build time — if you're seeing slow responses, the image needs a rebuild: `docker compose build embeddings`.
