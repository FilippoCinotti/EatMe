# Modello di sicurezza

- Il backend deriva `user_id` dal token verificato. Richieste con un altro user_id
  non attribuiscono identità o privilegi.
- Le mutazioni operano sul household dell’utente; un membro viewer non può scrivere.
- JWT live: issuer/audience/exp/iat/sub/role verificati, algoritmi ES256 o RS256.
  Non è abilitata la modalità legacy HS256. Configurare signing keys asimmetriche in Supabase.
- Segreti AI e database rimangono server-side. Il publishable/anon key Supabase non
  sostituisce l’autorizzazione; nessun service-role key è ammesso nel bundle.
- `eatme_backend` ha grant limitati e non può aggiornare le definizioni delle diete.
  Il login di migrazione è separato. RLS protegge le letture client e proibisce
  scritture dirette alle tabelle operative.
- Il locale usa scrypt con salt casuale e token casuali salvati come hash, con
  scadenza di 12 ore. Non è un provider di autenticazione da esporre al pubblico.
- Chiavi idempotenti, hash del payload, lock per nucleo e versioni ottimistiche
  impediscono doppi consumi e quantità negative.
- Corpo richieste limitato; CORS ha origini esplicite; risposte private no-store;
  log HTTP disabilitati nei comandi di avvio. Nessun token viene loggato dal codice.
- La allowlist admin è configurata sul backend. Il testo inviato dal client non
  concede ruoli. La console è di consultazione; i ruoli editoriali completi sono futuri.

Restano da verificare: JWT/JWKS live e rotazione, isolamento PostgreSQL reale,
limiter condiviso, hardening gateway, retention, crash reporting con redazione,
revoca/reauthentication per azioni sensibili, scansione delle dipendenze risolte.
Nessuna build o esecuzione locale implica automaticamente sicurezza di produzione.
