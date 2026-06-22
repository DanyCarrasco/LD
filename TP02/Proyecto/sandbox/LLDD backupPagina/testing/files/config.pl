:- module(config, [
    rival/2, set_rivales/1, puntaje_objetivo/1, estado_envido_inicial/1, estado_cantos_Truco/1
]).

:- dynamic rival/2.

% rival de cada jugador
set_rivales([J1, J2]) :-
    retractall(rival(_, _)),
    assertz(rival(J1, J2)),
    assertz(rival(J2, J1)).

% puntos para ganar la partida
puntaje_objetivo(15).

% estado inicial del envido
estado_envido_inicial(envido(no_cantado, [], none)).

% estado inicial de los cantos de truco
estado_cantos_Truco(trucos([truco])).
