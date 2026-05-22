# Referenz-System

Self-hosted KI-Suchsystem für Projektreferenzen. Neue Referenzen werden in NocoDB eingetragen und sind sofort über semantische Suche auffindbar — ohne Keywords, nur mit freiem Text.

## Stack

| Komponente | Rolle |
|---|---|
| **NocoDB** | Referenzverwaltung (Weboberfläche) |
| **n8n** | Automatisierung: Sync + Such-API |
| **Qdrant** | Vektordatenbank |
| **Embedding Service** | KI-Modell (all-MiniLM-L6-v2, lokal) |
| **PostgreSQL** | Persistenz für NocoDB |

## Schnellstart

```bash
cp .env.example .env
# SERVER_IP in .env auf die lokale IP setzen
chmod +x setup.sh && ./setup.sh
chmod +x init-qdrant.sh && ./init-qdrant.sh
```

Danach NocoDB (`SERVER_IP:8080`) und n8n (`SERVER_IP:5678`) im Browser öffnen und einrichten — Details in [`ANLEITUNG.md`](ANLEITUNG.md).

## Suche

```bash
curl -X POST http://SERVER_IP:5678/webhook/referenz-suchen \
  -H "Content-Type: application/json" \
  -d '{"query": "Wärmedämmung Neubau", "limit": 5}'
```

## Voraussetzungen

- Docker + Docker Compose
- Ports 5678, 8080, 6333, 8001 frei
- ~2 GB RAM für das Embedding-Modell

## Konfiguration

Alle Secrets und die Server-IP gehen in `.env` (nie committen). Vorlage: `.env.example`.

## Daten

Liegen in Docker Volumes — bleiben bei `docker compose down` erhalten, gehen nur bei `docker compose down -v` verloren.
