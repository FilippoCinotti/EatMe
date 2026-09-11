# ADR 0004-riverpod: Riverpod e GoRouter

Stato: decisione della foundation; vedere implementation-status per la verifica.

## Decisione

Usare NotifierProvider per lo stato condiviso e GoRouter per shell e deep link.

## Conseguenze

I widget consumano lo stato e il client API tramite provider. La navigazione osserva i cambi di fase auth senza ricreare il router a ogni aggiornamento inventario.

## Alternative

Non si mescolano Bloc, Redux e altri gestori di stato.
