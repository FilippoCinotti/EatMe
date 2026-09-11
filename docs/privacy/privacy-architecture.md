# Privacy del primo milestone

Sono registrati nome, identificatore, composizione numerica del nucleo, scelte
esplicite, alimenti e relativi eventi. Non si deducono condizioni di salute da
ricette aperte o preferenze. Nessun dato viene inviato ad advertising o analytics.

Allergie e intolleranze richiedono consenso esplicito versionato. Le opzioni
mediche richiedono un consenso separato. La rimozione dal profilo cancella le
restrizioni correnti e registra il ritiro dei consensi precedenti. Le copie
storiche presenti nelle tracce richiedono una policy di retention/purge prima
della beta: non si dichiara già soddisfatta una cancellazione granulare completa.

La cache mobile salva solo l’ultimo inventario nello storage sicuro della
piattaforma, associato all’UUID della sessione. Non conserva localmente un profilo
medico per avviare valutazioni offline. Logout e cancellazione eliminano la cache
e la sessione locale. In produzione la sessione Supabase è persistita mediante
un’implementazione di LocalStorage basata sullo stesso storage sicuro.

L’export comprende profilo, consensi, inventario, eventi, cucina e avanzi.
La cancellazione locale elimina il nucleo se ha un solo membro. Le operazioni
con gruppi condivisi si arrestano per richiedere una gestione della proprietà.
La cancellazione Supabase/Auth/storage e la riautenticazione non sono ancora
implementate: sono requisiti bloccanti per il rilascio.

La versione iniziale non riceve immagini o scontrini. Retention delle immagini,
regioni di trattamento, titolare/responsabili, informativa definitiva e procedure
per l’esercizio dei diritti devono essere definiti con le integrazioni effettive.
Questo documento descrive l’architettura, non certifica conformità normativa.
