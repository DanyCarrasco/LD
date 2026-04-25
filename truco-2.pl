:- use_module(library(random)).
:- use_module(library(clpfd)).

carta(Suite-Number) :-
    member(Suite, [oros, espadas, bastos, copas]),
    member(Number, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, as]).

orden_truco(espadas-as, 12).
orden_truco(bastos-as, 11).
orden_truco(X-7, 10) :- member(X, [oros, espadas]).
orden_truco(_-3, 9).
orden_truco(_-2, 8).
orden_truco(X-as, 7) :- member(X, [oros, copas]).
orden_truco(_-rey, 6).
orden_truco(_-caballo, 5).
orden_truco(_-sota, 4).
orden_truco(X-7, 3) :- member(X, [copas, bastos]).
orden_truco(_-6, 2).
orden_truco(_-5, 1).
orden_truco(_-4, 0).


cartas_truco_puntaje(Carta, Puntaje) :-
    carta(Carta),
    orden_truco(Carta, Puntaje).

carta_alta_truco(C1, C2, Higher) :-
    cartas_truco_puntaje(C1, P1),
    cartas_truco_puntaje(C2, P2),
    (P1 #> P2 *->
    Higher is C1
    ;
    Higher is C2).

valor_envido(as, 1).
valor_envido(2, 2).
valor_envido(3, 3).
valor_envido(4, 4).
valor_envido(5, 5).
valor_envido(6, 6).
valor_envido(7, 7).
valor_envido(sota, 0).
valor_envido(caballo, 0).
valor_envido(rey, 0).

cartas_envido_puntaje(C1, C2, Puntaje) :-
    carta(C1),
    carta(C2),
    C1 = Palo1-Valor1,
    C2 = Palo2-Valor2,
    (Palo1 = Palo2 *->
    valor_envido(Valor1, Pun1),
	valor_envido(Valor2, Pun2),
	Puntaje is Pun1 + Pun2 + 20
    ;
    Puntaje is 0).

