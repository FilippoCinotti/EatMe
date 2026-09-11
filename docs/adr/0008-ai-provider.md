# ADR 0008-ai-provider: Provider AI separati

Stato: decisione della foundation; vedere implementation-status per la verifica.

## Decisione

Definire interfacce; tenere scansioni disattivate finché non esiste un provider collaudato.

## Conseguenze

Un servizio non configurato produce un errore esplicito. Il flusso manuale non dipende da AI. I riconoscimenti futuri richiederanno conferma prima del commit.

## Alternative

Non usare risposte simulate come se provenissero da un servizio live.
