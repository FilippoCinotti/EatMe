# ADR 0002-postgres: PostgreSQL con adattatore SQLite locale

Stato: decisione della foundation; vedere implementation-status per la verifica.

## Decisione

PostgreSQL/Supabase è il target; SQLite esegue i test e lo sviluppo senza servizi.

## Conseguenze

SQL comune e transazioni esplicite minimizzano la divergenza. RLS, lock e grant vanno verificati nel job PostgreSQL: i test SQLite non li certificano.

## Alternative

Usare SQLite in produzione o richiedere sempre un cluster esterno non soddisfa il prodotto o la portabilità dello sviluppo.
