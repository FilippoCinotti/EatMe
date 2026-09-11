# AI — stato e percorso previsto

In questo milestone le funzioni AI non sono attive. `services/worker/providers.py`
definisce interfacce e risultati con provenienza, confidenza e conferma obbligatoria.
`UnconfiguredAIProvider` segnala l’assenza di configurazione, senza dati simulati.

Prossimo percorso: upload validato → job → provider → parsing strutturato →
riconciliazione canonica → conferma/correzione utente → commit idempotente.
Non inviare credenziali o profili medici non necessari al provider.
Barcodes e scontrini richiedono provider distinti e provenienza per campo.
Le chiavi, i modelli e le valutazioni dovranno essere configurati prima dell’attivazione.
