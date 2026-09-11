# ADR 0003-fastapi: FastAPI e dominio indipendente

Stato: decisione della foundation; vedere implementation-status per la verifica.

## Decisione

Separare Router e Service da FastAPI/Pydantic.

## Conseguenze

Un adattatore HTTP standard permette di provare lo stesso flusso quando i pacchetti non sono disponibili. FastAPI è il trasporto principale da verificare in CI.

## Alternative

Logica solo nel client esporrebbe regole e credenziali; duplicare il dominio nei due trasporti creerebbe incoerenze.
