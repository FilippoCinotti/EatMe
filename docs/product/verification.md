# Verifiche — 11 settembre 2026

## Risultati effettivi

| Verifica | Esito |
| --- | --- |
| Test dominio/storage/auth/trasporto locale | 34 superati |
| Test wrapper FastAPI locali | 2 saltati: FastAPI e httpx non installati localmente |
| Totale unittest discovery locale | 36 individuati, 34 pass, 2 skip, 0 errori |
| Test backend in GitHub Actions, con FastAPI | 36 superati, nessuno skip |
| Parsing sorgenti Python | Superato |
| Risorse IT/EN | 228 chiavi, stessi nomi e parametri di interpolazione |
| File JSON e schema base SQLite/PostgreSQL | Controllati staticamente |
| Flutter format / analyze / test widget | Superati sui runner Linux e macOS in GitHub Actions |
| Build Android debug | Superata sul runner Linux in GitHub Actions |
| Build iOS simulatore debug | Superata sul runner macOS in GitHub Actions |
| PostgreSQL/RLS | Superati in GitHub Actions con PostgreSQL 17 |
| Next.js typecheck / build / audit | Superati in GitHub Actions |
| Lint Python / audit dipendenze / Docker | Superati in GitHub Actions |
| CodeQL | Bloccato: Code scanning non attivato nelle impostazioni del repository |
| OAuth/Supabase live | Non eseguito: configurazione e credenziali mancanti |
| Screenshot e golden da app eseguita | Non prodotti: nessun rendering mobile verificabile |

## Comandi eseguiti

Da `services/api`:

```bash
python -m unittest discover -s tests -v
```

Risultato finale: `Ran 36 tests ... OK (skipped=2)`.
I due skip locali sono indicati per nome nella suite FastAPI: non vengono
conteggiati come test locali superati. GitHub Actions ha installato le dipendenze
ed eseguito anche questi due test: `Ran 36 tests ... OK`.

Le prime verifiche remote di backend, database e console sono documentate nel
[workflow EatMe CI](https://github.com/FilippoCinotti/EatMe/actions/runs/34562182870).
Il codice dei componenti verificati non è cambiato nelle correzioni mobile successive.

Il [workflow completo successivo](https://github.com/FilippoCinotti/EatMe/actions/runs/34562989945)
ha concluso con successo tutti e cinque i job sul commit
`e5bdb7b6557794cf327c8e0f3d3c783c2a61a870`: backend, PostgreSQL/RLS, console,
mobile Linux e mobile macOS. I tre test widget passano su entrambi i runner.
Le build producono un APK Android debug e `Runner.app` per il simulatore iOS.
Non sono pacchetti firmati per distribuzione né prove su dispositivi fisici.

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

La suite locale da sola non prova la compilabilità del client o le policy
PostgreSQL; queste ultime sono state eseguite nel workflow remoto autorizzato.
Le verifiche automatiche non convalidano la configurazione OAuth/Supabase live,
la revisione scientifica di dati reali o il funzionamento su dispositivi fisici.
CodeQL non può pubblicare i risultati finché Code scanning non viene attivato
nelle impostazioni GitHub. La PR rimane in bozza durante il completamento
delle verifiche e delle attività descritte nello stato di implementazione.
