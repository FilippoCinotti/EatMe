# Contratti API

Il namespace è `/api/v1`. Le mutazioni PUT /profile, POST /inventory,
PATCH /inventory/{id} e POST /cooking/confirm richiedono `Idempotency-Key: UUID`.
La stessa azione ritentata deve mantenere chiave e contenuto.
Le richieste private usano `Authorization: Bearer …`.

Input FastAPI tipizzati in `eatme/api.py`; con le dipendenze installate:

```bash
python packages/contracts/export_openapi.py
```

Il generatore scrive `openapi.json` senza avviare un database o contattare provider.
L’esportazione non è stata eseguita qui, perché FastAPI non era disponibile.

| Metodo / route | Funzione |
| --- | --- |
| GET /health, /config | Salute del servizio e funzioni attive |
| POST /auth/register, /auth/login | Auth di sviluppo; assenti nella modalità Supabase |
| POST /auth/logout | Revoca token locale; logout live gestito dal client Supabase |
| GET /catalog | Alimenti, diete, allergeni, stato selezionabile |
| GET, PUT /profile | Lettura/salvataggio con versione e consenso |
| DELETE /profile | Solo account locale singolo; conferma esplicita |
| GET, POST /inventory | Lista e aggiunta lotto |
| PATCH /inventory/{id} | Consuma, correggi, sposta, apri, scarta |
| GET /recommendations | Ranking e spiegazioni; parametri mode e food_id |
| GET /recipes/{id} | Ricetta e verifica del profilo corrente |
| GET /foods/{id}/compatibility | Compatibilità deterministica |
| POST /cooking/preview | Allocazione FEFO e quantità mancanti |
| POST /cooking/confirm | Rivalidazione e aggiornamento atomico |
| GET /leftovers | Avanzi e collegamento alla ricetta |
| GET /privacy/export | Dati dell’utente e del suo inventario |
| GET /admin/catalog | Solo operatori nella allowlist server |

Quantità nel protocollo come stringhe decimali; storage in millesimi interi.
Errori di dominio: `{"error":{"code":"…","details":{}}}`.
401 autenticazione, 403 autorizzazione, 404 risorsa non trovata, 409 conflitto,
422 input, 429 rate limit. Gli errori Pydantic della prima versione mantengono
la risposta standard FastAPI e verranno uniformati nel prossimo milestone.
