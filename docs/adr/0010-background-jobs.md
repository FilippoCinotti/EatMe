# ADR 0010-background-jobs: Jobs asincroni e pipeline inventario

Stato: decisione della foundation; vedere implementation-status per la verifica.

## Decisione

Rimandare la coda finché non esiste la prima scansione reale; conservare l’interfaccia provider.

## Conseguenze

Il worker non è ancora un processo eseguibile. Il milestone AI Inventory introdurrà stato job, retry, cancellazione, limiti e retention.

## Alternative

Non bloccare il caricamento della home in attesa di lavori costosi.
