# Configurazione e rilascio

## Primo passaggio su un ambiente completo

1. Installare Flutter stable, Python 3.12, Node 22 e strumenti PostgreSQL/Docker.
2. Eseguire `python scripts/bootstrap_mobile.py`; quindi formattare e analizzare Dart.
3. Risolvere e committare lockfile Python, npm e pub con versioni verificate.
4. Eseguire tutti i job CI. Non presentare un job non eseguito come superato.
5. Eseguire il flusso su emulatori e dispositivi e verificare UI, accessibilità e temi.

## Database e Supabase

Usare un progetto separato per staging e produzione. Impostare il login owner in
`MIGRATION_DATABASE_URL` ed eseguire `python scripts/migrate.py` con psycopg installato.
Il runner SQL usa lock e checksum; una migrazione già applicata non è modificabile.

Creare separatamente un login applicativo con password generata fuori dal repository
e concedergli il ruolo `eatme_backend`. Il backend assume questo ruolo durante le
transazioni. Non usare il login owner come credenziale applicativa abituale.

Configurare, sul server:

| Variabile | Valore/configurazione |
| --- | --- |
| EATME_ENV | staging oppure production |
| AUTH_MODE | supabase |
| DATABASE_URL | DSN PostgreSQL del login applicativo, con TLS |
| SUPABASE_URL | URL HTTPS del progetto |
| CORS_ORIGINS | Origini esatte della console |
| ADMIN_USER_IDS | UUID dei soli operatori autorizzati |

Configurare signing keys asimmetriche, email verification, SMTP, callback OAuth e
redirect allowlist. I server non development rifiutano SQLite e auth locale.
Non applicare `supabase/tests/bootstrap_ci.sql` a Supabase: serve solo a CI effimera.

## Mobile con auth live

Passare con `--dart-define`:
`AUTH_MODE=supabase`, `API_URL=https://…/api/v1`, `SUPABASE_URL=https://…`,
`SUPABASE_ANON_KEY=…` e, dopo aver configurato i provider, `OAUTH_ENABLED=true`.
La callback è `dev.eatme.app://login-callback`. Scegliere identifier e scheme
definitivi e mantenerli coerenti tra Android, iOS, Supabase, Apple e Google.

Collaudare registrazione con email da confermare, login, private relay Apple,
refresh/rotazione token, recupero password e logout. La revoca lato Supabase
richiede la policy appropriata: la verifica JWT offline non revoca immediatamente
un access token già emesso prima della scadenza.

## Gate prima di beta / store

Non distribuire come prodotto medico/nutrizionale reale il catalogo dimostrativo.
Completare governance, fonti e contenuti, cancellazione account live, gestione
consensi e retention. Verificare API/PostgreSQL con dati reali e controlli di autorizzazione.
Completare privacy notice, manifest, accessibilità, icone/splash, permessi,
monitoraggio, supporto e gestione errori.

Firma Android in keystore protetto; firma iOS con team e provisioning configurati
nel CI autorizzato. Le build della CI iniziale sono debug/simulator, non pacchetti
firmati per gli store. Proseguire con TestFlight e internal Play testing prima
di una distribuzione pubblica. Pubblicazione e deployment non sono stati effettuati.
