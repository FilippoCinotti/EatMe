# Diete e compatibilità

Ordine implementato: identificazione canonica, allergie, may-contain,
intolleranze, esclusioni esplicite, regole pubblicate, ranking delle sole ricette
ammesse. Disponibilità, urgenza e preferenze non possono superare un rifiuto.

`EXCLUDE`, `PREFER` e `ALLOW` sono i primi operatori supportati.
`EXCLUDE` con hard_constraint è sempre applicato; per una semplice preferenza
flessibile può diventare una penalità con avviso. Operatorì non supportati
producono `rule_not_evaluable`: nessuna dichiarazione di compatibilità.

Ogni richiesta risolve le versioni con stato PUBLISHED e intervallo di validità
attivo. Se una dieta assegnata non ha più regole attive, la raccomandazione si
interrompe con un messaggio: non elimina silenziosamente il vincolo.
Il profilo può associare più diete. Il primo elemento selezionato rappresenta
il profilo primario; tutti gli hard constraint partecipano alla verifica.

RAD è solo un identificatore canonico di un profilo da curare. Non si presume
qui il suo significato clinico né si deducono categorie alimentari o target.
Nessun alimento è vietato in produzione sulla base di una regola RAD inventata.
I test sintetici dimostrano il meccanismo di pubblicazione/consenso, non un protocollo.

Per attivare un profilo medico servono riferimenti, data di revisione, una versione
pubblicata e il consenso `medical-nutrition-1`. Il percorso di amministrazione che
garantisce revisione dei contenuti, autorizzazioni e audit deve essere completato
prima di usare questa capacità con contenuti reali.

Il catalogo demo non rappresenta le etichette dei prodotti acquistati. La UI
espone questa limitazione e non dichiara un prodotto reale sicuro per un’allergia.
Non è implementato un motore nutrizionale clinico: target di macro/micronutrienti,
algoritmi FODMAP, stadi renali e conflitti quantitativi sono futuri.
