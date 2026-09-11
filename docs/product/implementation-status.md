# Stato di implementazione — 0.1.0

Data: 11 settembre 2026. Perimetro: foundation e sorgenti del primo flusso.
La Definition of Done completa della specifica non è ancora soddisfatta per il mobile.
Repository: [FilippoCinotti/EatMe](https://github.com/FilippoCinotti/EatMe), privato.
Branch di sviluppo: `feat/eatme-foundation`.

## Done

Verificato localmente e in GitHub Actions:

- Identità UUID, registrazione/login di sviluppo con hash scrypt, sessioni revocabili.
- Profilo adulto, dimensione del nucleo, fuso orario, diete multiple e livelli di rigidità.
- Allergie e intolleranze separate; consenso versionato e rimozione dei dati dal profilo.
- Catalogo canonico dimostrativo con 12 alimenti e quattro ricette originali.
- Mediterranea, equilibrata, vegetariana e vegana; profili non curati non selezionabili.
- RAD non pubblicato e inattivo; test sintetico di attivazione dopo pubblicazione,
  revisione e consenso, senza logica RAD nel client.
- Inventario per household e lotti distinti, quantità esatte, date con significato,
  eventi di consumo/correzione/apertura/spostamento/scarto.
- Filtri deterministici prima del ranking, gestione ingredienti sconosciuti,
  possibili allergeni, intolleranze e regole non valutabili.
- Ranking configurabile, modalità, disponibilità per quantità, traccia delle decisioni.
- Anteprima dei consumi, quantità correggibili, FEFO, conferma atomica,
  protezione da retry e versioni obsolete; avanzi salvati senza scadenze inventate.
- Separazione degli account, esportazione dati e cancellazione locale del singolo nucleo.
- Flusso HTTP completo verificato senza servizi esterni.
- Wrapper FastAPI: due test aggiuntivi eseguiti in GitHub Actions, 36 test backend totali superati.
- PostgreSQL 17/RLS: migrazioni e test SQL eseguiti in GitHub Actions.
- Console Next.js: typecheck, build e audit eseguiti in GitHub Actions.
- Lint Python, audit dipendenze e build Docker superati nel workflow remoto.
- Flutter: formattazione, analisi e tre test widget superati su Linux e macOS.
- Build Android debug e iOS simulatore debug superate in GitHub Actions.

## In progress

Sorgenti scritti, ma verifiche di ambiente ancora necessarie:

- App Flutter con quattro destinazioni, IT/EN, chiaro/scuro/sistema, onboarding,
  inserimento manuale, ricette, modalità cucina e privacy.
- Cache cifrata dell’inventario: consultazione durante interruzioni nella sessione
  corrente; le modifiche offline e il pieno avvio offline non sono implementati.
- Contratto OpenAPI da completare con modelli di risposta dedicati.
- Supabase email/OAuth/recupero password e storage sicuro delle sessioni.
- Collaudo live di migrazioni PostgreSQL, RLS e ruolo backend a privilegi separati su Supabase.
- Console amministrativa di sola consultazione: editing e revisione da implementare.
- Collaudo end-to-end su emulatori/dispositivi e configurazione Code scanning per CodeQL.
- Runner nativi generati e compilati in CI; ancora da versionare insieme ai lockfile.

## Next

1. Installare SDK/dipendenze; formattare, risolvere versioni e commit dei lockfile.
2. Attivare Code scanning su GitHub e completare le configurazioni di rilascio.
3. Verificare il flusso mobile su emulatori e dispositivi, inclusi testo grande e screen reader.
4. Configurare e collaudare Supabase e callback OAuth; completare la cancellazione live.
5. Introdurre dati reali con licenze/provenienza, revisione scientifica e admin con ruoli e audit.
6. Implementare barcode, provider prodotti e conferma, prima di scansioni AI e scontrini.

## Blocked

- Ambiente locale privo di Flutter/Dart e PostgreSQL/Docker; le verifiche che li richiedono avvengono in CI.
- CodeQL: GitHub segnala che Code scanning non è attivato nel repository.
- Credenziali OAuth/Supabase, firma iOS/Android e servizi AI non fornite.
- Regole mediche e scientifiche reali non curate: nessuna regola clinica di produzione pubblicata.

## Known technical debt

- Dipendenze espresse come intervalli: lockfile ancora da generare e verificare.
- Formattazione SDK eseguita; verifiche mobile aggiornate nel rapporto delle verifiche.
- Schema minimo con JSON per configurazioni e catalogo; normalizzazione del knowledge base
  completo, governance di pubblicazione, operatori nutrizionali e risoluzione dei conflitti da estendere.
- Gli operatori di regola non implementati bloccano la compatibilità, senza ignorarli.
- Ruoli admin per support/editor/reviewer e revisioni a quattro occhi non ancora implementati.
- Cache limitata all’inventario durante una sessione; Drift e outbox offline rimandati.
- Avanzi registrabili e consultabili; consumo/trasformazione/ranking degli avanzi da completare.
- Quick-use sulla home apre il dettaglio alimento; filtro ricette per alimento disponibile via API,
  ma il collegamento specifico della UI resta da completare.
- Nessuna telemetria remota, scansione, piano pasti, lista spesa, invito household,
  preferenza comportamentale, abbonamento, notifica o richiamo alimentare attivo.
- Dati demo visibili come tali; HealthyFood mostra conflitti, senza score nutrizionali o RAG.
- Inventario senza paginazione e tracce senza retention automatica; da adeguare prima della beta.
- Cancellazione account live, richiesta di riautenticazione e gestione gruppi condivisi mancanti.
- Il rate limiter è locale al processo: serve un gateway/limiter condiviso per il deploy multiistanza.
- Contratti OpenAPI: gli input sono tipizzati, gli output restano da completare con schemi dedicati.
- Archiviazione applicativa in text JSON con UUID validati nel dominio; chiavi catalogo e record
  privati da rafforzare con vincoli UUID/JSONB nativi nelle migrazioni successive.

## Funzioni successive

Le fasi 2–8 della specifica rimangono in backlog. Le interfacce provider sono presenti;
non sono implementazioni finte di AI, barcode, ricerca scientifica o fatturazione.
