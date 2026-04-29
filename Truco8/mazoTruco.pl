:- module(mazoTruco, [
    carta/1,
    valor_carta/2,
    valor_envido_numero/2,
    valor_envido_mano/2,
    puntos_par_mismo_palo/2,
    mezclar/2,
    carta_alta/2
]).

:- use_module(library(random)).
:- use_module(library(clpfd)).

% carta valida del mazo
carta(Suite-Number) :-
    member(Suite, [c, o, b, e]),
    member(Number, [12, 11, 10, 7, 6, 5, 4, 3, 2, 1]).

% fuerza de cada carta en truco
valor_carta(e-1, 14).
valor_carta(b-1, 13).
valor_carta(e-7, 12).
valor_carta(o-7, 11).
valor_carta(_-3, 10).
valor_carta(_-2, 9).
valor_carta(c-1, 8).
valor_carta(o-1, 8).
valor_carta(_-12, 7).
valor_carta(_-11, 6).
valor_carta(_-10, 5).
valor_carta(c-7, 4).
valor_carta(b-7, 4).
valor_carta(_-6, 3).
valor_carta(_-5, 2).
valor_carta(_-4, 1).


% valor de una carta para envido
valor_envido_numero(12, 0).
valor_envido_numero(11, 0).
valor_envido_numero(10, 0).
valor_envido_numero(1, 1).
valor_envido_numero(2, 2).
valor_envido_numero(3, 3).
valor_envido_numero(4, 4).
valor_envido_numero(5, 5).
valor_envido_numero(6, 6).
valor_envido_numero(7, 7).


% mejor valor de envido de una mano
valor_envido_mano(Mano, Valor) :-
    findall(Puntos, puntos_par_mismo_palo(Mano, Puntos), Pares),
    ( Pares \= [] ->
        max_list(Pares, Valor)
    ; findall(V,
              (member(_Palo-Numero, Mano), valor_envido_numero(Numero, V)),
              Valores),
      max_list(Valores, Valor)
    ).


% puntos de un par del mismo palo
puntos_par_mismo_palo(Mano, Puntos) :-
    select(Palo-N1, Mano, Resto),
    member(Palo-N2, Resto),
    valor_envido_numero(N1, V1),
    valor_envido_numero(N2, V2),
    Puntos is 20 + V1 + V2.

% mezcla una lista
mezclar([], []).
mezclar(Xs0, [Y|Ys]) :-
    length(Xs0, N),
    N1 is N - 1,
    random_between(0, N1, R),
    nth0(R, Xs0, Y, Xs),
    mezclar(Xs, Ys).


% compara dos cartas jugadas
carta_alta([Carta1, Carta2], Resultado) :-
    valor_carta(Carta1, P1),
    valor_carta(Carta2, P2),
    (
        P1 #> P2 -> Resultado = Carta1
    ;   P2 #> P1 -> Resultado = Carta2
    ;   P1 #= P2 -> Resultado = parda
    ).
