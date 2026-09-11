# Architettura

L’app Flutter comunica esclusivamente con `/api/v1` per le operazioni di dominio.
In produzione riceve una sessione da Supabase Auth; FastAPI verifica firma,
issuer, audience, scadenza, ruolo e soggetto UUID del JWT usando la JWKS configurata.
L’identità non è letta dal corpo della richiesta.

Il core Python non dipende dal trasporto. FastAPI e l’adattatore HTTP locale
invocano lo stesso Router e lo stesso Service. La seconda implementazione HTTP
serve a sviluppo e test in ambienti senza dipendenze; non è un server di produzione.

`Service` compone storage, policy e ranking. `engine.py` contiene calcoli senza rete:
normalizzazione quantità, disponibilità, verifica ingredienti, selezione delle
versioni, scoring ed esposizione delle componenti che motivano la proposta.

SQLite è un adattatore locale. PostgreSQL è il target applicativo. In PostgreSQL
ogni transazione assume `eatme_backend`; il login database deve avere esplicitamente
il permesso di assumere questo ruolo. Il ruolo ha accesso DML ai soli dati operativi,
lettura sul catalogo e append sull’audit; non può modificare lo schema né pubblicare
regole. RLS protegge gli accessi Supabase diretti. Il backend verifica sempre il
nucleo dell’utente, anche se le policy del ruolo server gli consentono l’accesso ai record operativi per eseguire operazioni atomiche.

Le mutazioni inventario bloccano il nucleo in PostgreSQL. Versioni ottimistiche
impediscono la conferma di anteprime obsolete. Una chiave UUID idempotente è legata
all’utente, alla risorsa e all’hash della richiesta; risposta ed effetti sono
salvati nella stessa transazione. La lock idempotente PostgreSQL serializza le
richieste duplicate. SQLite serializza le scritture con `BEGIN IMMEDIATE`.

Gli ingredienti usano unità canoniche del food (`g`, `ml`, `pcs`). Lo storage usa
millesimi interi; le conversioni per densità o fra dimensioni non sono indovinate.
Il consumo usa prima i lotti con data più vicina, escludendo use-by scaduti.

Il worker futuro resta separato. Nessuna chiamata AI avviene oggi nel percorso
principale. Un provider mancante produce un errore esplicito, mai riconoscimenti finti.

Fonti tecniche consultate:
[FastAPI](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/),
[Supabase JWT](https://supabase.com/docs/guides/auth/jwts),
[Flutter stable](https://docs.flutter.dev/install/archive),
[GoRouter](https://pub.dev/packages/go_router),
[Riverpod](https://pub.dev/packages/flutter_riverpod),
[storage sicuro](https://pub.dev/packages/flutter_secure_storage),
[Next.js](https://nextjs.org/docs/app/getting-started/installation).
