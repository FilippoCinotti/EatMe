# Dati del primo milestone

| Dominio | Tabelle | Invarianti |
| --- | --- | --- |
| Identità | profiles, households, household_members | UUID esterni; nucleo separato dall’utente |
| Consenso | consents | Tipo, versione, accettazione, ritiro |
| Diete | diet_definitions, diet_versions | Slug canonico; versioni pubblicate e intervalli efficaci |
| Catalogo | foods, recipes | Ingredienti canonici, unità, provenienza, flag demo |
| Inventario | inventory_batches, inventory_events | Quantità non negative; scadenze separate per lotto |
| Cucina | cooking_sessions, leftovers | Consumo transazionale e collegamento alla ricetta |
| Tracciabilità | recommendation_traces, operations | Snapshot e regole, retry idempotenti |
| Amministrazione | audit_events | Schema append-only per il ruolo applicativo |
| Sviluppo | dev_accounts, dev_sessions | Hash password/token; nessun grant di produzione |

Le migrazioni 0001 e 0002 creano schema e policy; lo schema SQLite replica la
prima migrazione per i test locali. La Knowledge Base estesa della specifica
non è ridotta a queste sole tabelle: normalizzazione e domini successivi sono
esplicitamente ancora da implementare.

Il core non conserva immagini, dati sanitari dedotti, documenti clinici o
informazioni di pagamento. Le raccomandazioni memorizzano dati sensibili del
profilo nelle motivazioni e sono accessibili solo all’utente, non all’intero household.
