# ADR 0005-offline: Cache iniziale e futuro outbox Drift

Stato: decisione della foundation; vedere implementation-status per la verifica.

## Decisione

Nel primo flusso conservare solo l’ultimo inventario nello storage sicuro, senza scritture offline.

## Conseguenze

Riduce il rischio di consumi duplicati e valutazioni su profili obsoleti. Avvio offline completo, Drift e outbox restano in backlog; serviranno cifratura e politica di conflitto.

## Alternative

Non rimuovere né consumare alimenti sulla base di una previsione o di una copia non sincronizzata.
