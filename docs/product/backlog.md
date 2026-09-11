# Roadmap ed issue iniziali

I milestone seguenti sono preparati come piano; non sono stati creati su GitHub.

| Milestone | Prima issue concreta | Criterio di uscita |
| --- | --- | --- |
| Foundation | Convalidare build e lockfile del monorepo | CI verde su repo scelto, Android e iOS simulator |
| Core MVP | E2E mobile con auth live e cancellazione account | Flusso completo su dispositivi, policy testate |
| AI Inventory | Barcode → provider prodotti → conferma → inventario | Fallimento lookup e correzioni gestiti senza dati finti |
| HealthyFood | Fonti nutrizionali con provenienza e unità coerenti | Valori tracciabili, dati mancanti espliciti |
| Scientific Evidence | Admin reviewer, versioni, audit e fonti curate | Nessun contenuto non revisionato pubblicabile |
| Meal Planning | Piano → aggregazione fabbisogni → lista spesa | Quantità al netto del Fridge, profili rispettati |
| Household | Inviti e partecipanti a ogni ricetta | Unione allergie, realtime e conflitti testati |
| Beta | Offline, retention, accessibilità, telemetria minima | Scenari reali, errore/offline, privacy collaudati |
| 1.0 | Firma, store, supporto e rollout | Checklist di rilascio soddisfatta e approvazione proprietario |

## Prossima sessione di sviluppo

1. Controllare il repository di destinazione e riusare eventuale codice preesistente.
2. Preparare `feat/eatme-foundation`; portare questa source tree senza sovrascritture indiscriminate.
3. Installare toolchain; formattare Python/Dart; risolvere dipendenze e aggiungere lockfile.
4. Eseguire tutta la CI, correggere gli errori reali e aggiungere un E2E mobile.
5. Preparare una PR con esiti e schermate ottenute dall’app eseguita.

Non iniziare scansioni, planner e abbonamenti prima che il primo percorso sia
verificato anche sul client mobile e sull’autenticazione effettiva.
