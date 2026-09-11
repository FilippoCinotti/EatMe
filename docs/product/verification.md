# Verifiche — 11 settembre 2026

## Risultati effettivi

| Verifica | Esito |
| --- | --- |
| Test dominio/storage/auth/trasporto locale | 34 superati |
| Test wrapper FastAPI | 2 saltati: FastAPI e httpx non installati |
| Totale unittest discovery | 36 individuati, 34 pass, 2 skip, 0 errori |
| Parsing sorgenti Python | Superato |
| Risorse IT/EN | 228 chiavi, stessi nomi e parametri di interpolazione |
| File JSON e schema base SQLite/PostgreSQL | Controllati staticamente |
| Flutter analyze / widget / Android / iOS | Non eseguiti: SDK assente |
| PostgreSQL/RLS | Test forniti, non eseguiti: runtime assente |
| Next.js typecheck / build | Non eseguiti: dipendenze non installabili |
| Docker e scansioni dipendenze/CodeQL | Workflow forniti, non eseguiti |
| OAuth/Supabase live | Non eseguito: configurazione e credenziali mancanti |
| Screenshot e golden da app eseguita | Non prodotti: nessun rendering mobile verificabile |

## Comandi eseguiti

Da `services/api`:

```bash
python -m unittest discover -s tests -v
```

Risultato finale: `Ran 36 tests ... OK (skipped=2)`.
I due skip sono indicati per nome nella suite FastAPI: non vengono conteggiati
come test superati. La CI installa le dipendenze e deve eseguirli effettivamente.

Dalla root:

```bash
python scripts/check_repository.py
```

È stato eseguito anche uno smoke test locale di profilo → alimento →
raccomandazione → anteprima. Il test HTTP usa un server su porta loopback
temporanea, non un mock della risposta del Service.

## Copertura dei rischi principali

- Allergie e may-contain esclusi prima dello scoring; ingredienti sconosciuti non compatibili.
- Intolleranze separate, consenso obbligatorio, revoca del profilo corrente.
- Rigidezza flessibile non indebolisce hard constraint.
- Versioni future/deprecate non applicate; regole non valutabili bloccanti.
- RAD inizialmente inattivo e test di pubblicazione sintetica con consenso dedicato.
- Date use-by distinte da best-before; lotti separati e uso FEFO.
- Nessuna quantità negativa con consumi simultanei; atomicità quando un lotto è cambiato.
- Retry identico senza doppio consumo; payload modificato con la stessa chiave rifiutato.
- Isolamento fra account, accesso admin negato, export e cancellazione locale.
- Registrazione → profilo → inventario → ricetta → cottura → avanzi → logout via HTTP.

## Limite della verifica

La suite locale non prova la compilabilità del client, la correttezza delle policy
PostgreSQL, la configurazione OAuth o la revisione scientifica di dati reali.
Il download dei pacchetti è stato interrotto dai controlli di rete dell’ambiente.
Non è stata richiesta o dichiarata una deroga, né usato un canale alternativo
per recuperare dipendenze bloccate. Servono gli ambienti elencati per completare
la verifica del milestone e la Definition of Done.
