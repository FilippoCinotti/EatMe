# ADR 0001-flutter: Flutter per iOS e Android

Stato: decisione della foundation; vedere implementation-status per la verifica.

## Decisione

Adottare Flutter stable per una sola UI nativa multipiattaforma.

## Conseguenze

Rispetta lo stack richiesto e permette parità dei temi. Lo SDK è assente in questo ambiente: la decisione è implementata nei sorgenti ma le build non sono verificate.

## Alternative

React Native o due app native richiederebbero cambiare la specifica e aumenterebbero lo scope.
