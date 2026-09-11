# EatMe · Foundation 0.1.0

Eat what you have. Eat what is good for you. Waste less.

Questo repository avvia l’implementazione della [specifica completa](docs/product/specification.md).
Contiene il primo flusso applicativo, il progetto Flutter, il backend FastAPI,
le migrazioni PostgreSQL/Supabase e una console amministrativa di consultazione.

**È un primo milestone di sviluppo, non una release pronta per gli store.**
Il motore Python e il percorso HTTP locale sono stati eseguiti e testati.
Flutter, FastAPI, PostgreSQL e Next.js richiedono ancora le rispettive verifiche
di integrazione/build: SDK e dipendenze non erano disponibili nell’ambiente
di creazione. Il repository di sviluppo è
[FilippoCinotti/EatMe](https://github.com/FilippoCinotti/EatMe).
Nessuna versione dell’app è stata distribuita online o sugli store.

## Prova subito il backend, senza installare pacchetti

Serve Python 3.12 o successivo. Dalla cartella del progetto:

```bash
cd services/api
python -m unittest discover -s tests -v
python -m eatme.local_server
```

La API risponde su `http://127.0.0.1:8000/api/v1/health`.
Il database locale `eatme-dev.sqlite3` viene creato automaticamente e mantiene
le modifiche tra gli avvii. Non viene incluso nei commit.
I test usano database temporanei separati e dati inventati.

Il server HTTP della libreria standard è un **adattatore di sviluppo**, utile
anche in ambienti senza accesso ai pacchetti. Condivide routing e dominio con
FastAPI; non sostituisce il server di produzione.

## Avvia la app iOS / Android

Installa Flutter stable, Android Studio per Android e Xcode su macOS per iOS.
Versione Flutter di riferimento per la prima CI: 3.47.2. Poi, dalla root:

```bash
python scripts/bootstrap_mobile.py
cd apps/mobile
dart format lib test
flutter analyze
flutter test
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1
```

L’indirizzo qui sopra è quello dell’host visto dall’emulatore Android.
Per il simulatore iOS sullo stesso Mac usa invece
`--dart-define=API_URL=http://127.0.0.1:8000/api/v1`.
Per un dispositivo fisico configura un endpoint HTTPS raggiungibile.

Lo script genera **solo le cartelle native mancanti** in una directory temporanea,
poi le copia nel progetto. Non sovrascrive Dart, pubspec o runner già presenti.
Configura la callback OAuth `dev.eatme.app://login-callback`, accesso a Internet,
storage sicuro e HTTP per il solo debug Android. Non richiede la fotocamera.
Identificatore provvisorio generato: `dev.eatme.eatme`; scegline uno definitivo
prima della distribuzione e aggiorna le configurazioni OAuth.

Al primo avvio scegli **Crea account** con un’email fittizia e una password
di almeno 12 caratteri. In sviluppo le email non vengono inviate né verificate.
Scegli nome, numero di persone, dieta e restrizioni facoltative.

Per provare la bowl per due persone aggiungi:

| Alimento | Quantità |
| --- | ---: |
| Ceci cotti | 300 g |
| Pomodori | 300 g |
| Olio di oliva | 20 ml |

In ChefTable seleziona **Senza fare la spesa**, apri la bowl e segui i passaggi.
La conferma scala 300 g di ceci, 200 g di pomodori e 20 ml di olio.
Rimangono 100 g di pomodori. Puoi registrare e consultare eventuali avanzi.
Il test HTTP automatizzato verifica questo percorso, incluso il retry della conferma.

## Esegui FastAPI

```bash
python -m venv .venv
```

Attiva l’ambiente virtuale secondo il tuo sistema operativo, quindi:

```bash
python -m pip install -e 'services/api[dev]'
python -m uvicorn eatme.api:create_app --factory --host 127.0.0.1 --port 8000 --no-access-log
```

In sviluppo la documentazione OpenAPI è su `http://127.0.0.1:8000/docs`.
Alternativa con Docker: `docker compose up --build` dalla root.
Il compose fornito avvia solo l’ambiente locale; non è una configurazione di produzione.

## Console amministrativa

```bash
cd apps/admin
npm install
npm run typecheck
npm run build
npm run dev
```

In `apps/admin/.env.local` imposta
`EATME_API_URL=http://127.0.0.1:8000/api/v1`.
Avvia il backend con `ADMIN_USER_IDS` contenente gli UUID autorizzati, separati
da virgole. La console richiede il token di sessione di uno di questi utenti.
Puoi ottenerlo dalla risposta del login locale. La console non memorizza il token
nel browser e verifica il ruolo tramite l’API. Mostra catalogo e stato delle diete;
il flusso di editing/revisione/pubblicazione non è ancora implementato.

## Collegamenti esterni e produzione

Leggi [configurazione e rilascio](docs/releases/release-process.md) prima di
attivare Supabase o costruire una release. Le variabili sono elencate in
[.env.example](.env.example), senza credenziali. Non caricare `.env` reali nel repository.

Il client include l’integrazione Supabase per email, recupero password,
refresh di sessione, Google e Apple. Google/Apple compaiono solo con
`OAUTH_ENABLED=true` e richiedono configurazione nei rispettivi provider e callback
native. Questi collegamenti live **non sono stati testati**.
Le build release rifiutano auth locale e URL API non HTTPS.

Il catalogo iniziale è esplicitamente dimostrativo, senza valori nutrizionali
inventati o fonti scientifiche simulate. RAD esiste come `REQUIRES_REVIEW` e non
influenza le raccomandazioni iniziali. La selezione di un profilo medico richiede
regole pubblicate, riferimenti e data di revisione e consenso dedicato.
Il test di attivazione RAD usa unicamente fixture sintetiche, non regole cliniche reali.

## Struttura

| Percorso | Responsabilità |
| --- | --- |
| `apps/mobile` | Flutter, Riverpod, GoRouter, temi, localizzazione IT/EN |
| `apps/admin` | Next.js / TypeScript, console di consultazione |
| `services/api/eatme` | Identità, inventario, regole, ranking, consumi |
| `services/worker` | Interfacce per provider AI e barcode futuri |
| `supabase/migrations` | Schema e policy di accesso PostgreSQL |
| `supabase/tests` | Test SQL delle policy |
| `packages/contracts` | Documentazione dei contratti e generatori OpenAPI |
| `packages/design_tokens` | Palette, spaziatura e raggi condivisi |
| `.github` | CI, scansione, aggiornamenti dipendenze e template |
| `docs` | Specifica, stato, architettura, ADR, privacy e rilascio |

## Sviluppo e integrazione su GitHub

Il bootstrap del progetto è nel branch `feat/eatme-foundation`, con una PR verso
`main`. Le verifiche remote sono consultabili nella scheda
[Actions](https://github.com/FilippoCinotti/EatMe/actions).
Esegui il bootstrap Flutter, la formattazione e le build prima di integrare la PR.
Aggiungi i runner nativi generati, `pubspec.lock` e
`package-lock.json`; risolvi e blocca anche le dipendenze Python.
La CI usa oggi `npm install` per questa prima risoluzione: passa a `npm ci`
quando il lockfile verificato viene committato.

Completa i ruoli di revisione in CODEOWNERS, proteggi `main`, richiedi i controlli
CI e crea i milestone descritti nella roadmap. Queste impostazioni GitHub
non vengono attivate da un semplice file nel repository.

Consulta [stato di implementazione](docs/product/implementation-status.md),
[verifiche](docs/product/verification.md) e [prossime attività](docs/product/backlog.md)
per distinguere ciò che è implementato, testato o ancora da sviluppare.
