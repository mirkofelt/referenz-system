# Referenzsystem – Einrichtung & Bedienung

## Was ist das?

Ein selbstgehostetes System zur Verwaltung und intelligenten Suche von Projektrefenzen für das Ingenieurbüro. Neue Referenzen werden in NocoDB eingetragen (wie eine Tabelle), und das System macht sie automatisch über KI-Suche findbar.

---

## Einmalige Einrichtung (für den Entwickler)

### Voraussetzungen
- Docker + Docker Compose installiert
- Ports 5678, 8080, 6333 und 8000 erreichbar

### 1. Umgebung vorbereiten

```bash
cp .env.example .env
# .env öffnen und SERVER_IP auf die echte IP setzen
```

### 2. System starten

```bash
chmod +x setup.sh
./setup.sh
```

Das dauert beim ersten Mal ~5 Minuten (lädt KI-Modell herunter).

### 3. Qdrant-Collection anlegen

```bash
chmod +x init-qdrant.sh
./init-qdrant.sh
```

Einmal ausführen, danach nie wieder nötig.

### 4. NocoDB einrichten

1. Browser öffnen: `http://SERVER_IP:8080`
2. Account anlegen (nur einmalig)
3. Neue Datenbank → Neue Tabelle: **Referenzen**
4. Spalten anlegen:

| Spaltenname   | Typ         |
|--------------|-------------|
| Titel        | Text        |
| Beschreibung | Long Text   |
| Tags         | Multi Select|
| Foto         | Attachment  |

### 5. Webhook in NocoDB konfigurieren

1. In der Tabelle „Referenzen" → oben rechts: **Details** → **Webhooks**
2. Neuen Webhook erstellen:
   - **Ereignis:** After Insert + After Update
   - **URL:** `http://n8n:5678/webhook/referenz-sync`
   - **Methode:** POST
3. Speichern

### 6. n8n-Workflows importieren

1. Browser öffnen: `http://SERVER_IP:5678`
2. Account anlegen
3. **Workflow 1 (Sync):** Neuer Workflow → Import → `workflow-sync.json` hochladen → Aktivieren
4. **Workflow 2 (Suche):** Neuer Workflow → Import → `workflow-search.json` hochladen → Aktivieren

---

## Bedienung (für Büro-Mitarbeiter)

### Referenz eintragen

1. `http://SERVER_IP:8080` öffnen
2. In der Tabelle **Referenzen** eine neue Zeile anlegen
3. Titel, Beschreibung, Tags und optional ein Foto eintragen
4. Speichern → fertig, die Referenz ist automatisch im Suchindex

### Referenzen suchen

Per HTTP-Anfrage (z.B. aus einem anderen Tool oder Browser-Erweiterung):

```bash
curl -X POST http://SERVER_IP:5678/webhook/referenz-suchen \
  -H "Content-Type: application/json" \
  -d '{"query": "Wärmedämmung Wohngebäude Neubau", "limit": 5}'
```

Antwort (Beispiel):
```json
{
  "referenzen": [
    {
      "score": 0.91,
      "titel": "Neubau Einfamilienhaus Potsdam",
      "beschreibung": "Energieberatung und Baubegleitung...",
      "tags": "Neubau, EFH, KfW55",
      "foto_url": null
    }
  ],
  "count": 1
}
```

`score` geht von 0 bis 1 — alles über 0.7 ist eine gute Übereinstimmung.

---

## Dienste im Überblick

| Dienst      | Adresse                    | Zweck                        |
|-------------|----------------------------|------------------------------|
| NocoDB      | `http://SERVER_IP:8080`    | Referenzen verwalten         |
| n8n         | `http://SERVER_IP:5678`    | Automatisierung & Suche      |
| Qdrant      | `http://SERVER_IP:6333`    | Vektordatenbank (intern)     |
| Embeddings  | `http://SERVER_IP:8000`    | KI-Modell Service (intern)   |

---

## Häufige Fragen

**Referenz wurde eingetragen, ist aber nicht auffindbar?**
→ Prüfen ob der n8n-Workflow „Referenz Sync" aktiv ist. In n8n unter Executions nachschauen ob Fehler aufgetreten sind.

**System neu gestartet, alles weg?**
→ Daten liegen in Docker Volumes (`postgres_data`, `qdrant_data`, `n8n_data`). Solange die Volumes nicht gelöscht werden, bleiben alle Daten erhalten.

**Neues Büro-Mitglied braucht Zugang?**
→ In NocoDB unter Team einen neuen Benutzer einladen.

---

## System stoppen / starten

```bash
# Stoppen (Daten bleiben erhalten)
docker compose down

# Starten
docker compose up -d

# Logs anschauen
docker compose logs -f
```
