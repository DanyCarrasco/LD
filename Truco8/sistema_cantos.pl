:- module(sistema_cantos, [
    es_canto/1,
    nivel_canto/2,
    canto_supera/2,
    puntos_por_canto/2,
    puntos_por_rechazo/2,
    es_canto_envido/1,
    canto_envido_valido/2,
    puntos_envido_aceptado/3,
    puntos_envido_rechazado/3,
    puntos_falta_envido/2
    ]).

:- use_module(config, [puntaje_objetivo/1]).

% cantos validos de truco
es_canto(truco).
es_canto(retruco).
es_canto(vale4).

% nivel de cada canto
nivel_canto(ninguno, 0).
nivel_canto(truco, 1).
nivel_canto(retruco, 2).
nivel_canto(vale4, 3).


% true si nuevo tiene mas nivel que actual
canto_supera(Nuevo, Actual) :-
    nivel_canto(Nuevo, N1),
    nivel_canto(Actual, N2),
    N1 > N2.


% puntos por canto aceptado
puntos_por_canto(truco, 2).
puntos_por_canto(retruco, 3).
puntos_por_canto(vale4, 4).

% puntos por canto rechazado
puntos_por_rechazo(truco, 1).
puntos_por_rechazo(retruco, 2).
puntos_por_rechazo(vale4, 3).



% cantos validos de envido
es_canto_envido(envido).
es_canto_envido(real_envido).
es_canto_envido(falta_envido).


% secuencias validas de envido
canto_envido_valido([], envido).
canto_envido_valido([], real_envido).
canto_envido_valido([], falta_envido).
canto_envido_valido([envido], envido).
canto_envido_valido([envido], real_envido).
canto_envido_valido([envido], falta_envido).
canto_envido_valido([real_envido], falta_envido).
canto_envido_valido([envido, envido], real_envido).
canto_envido_valido([envido, envido], falta_envido).
canto_envido_valido([envido, real_envido], falta_envido).



% puntos de falta envido
puntos_falta_envido([jugador(_, _, P1), jugador(_, _, P2)], Puntos) :-
    puntaje_objetivo(Objetivo),
    Lider is max(P1, P2),
    Puntos is Objetivo - Lider.

% puntos de envido aceptado
puntos_envido_aceptado(Cantos, Jugadores, Puntos) :-
    last(Cantos, falta_envido),
    !,
    puntos_falta_envido(Jugadores, Puntos).


puntos_envido_aceptado([envido], _, 2).
puntos_envido_aceptado([real_envido], _, 3).
puntos_envido_aceptado([envido, envido], _, 4).
puntos_envido_aceptado([envido, real_envido], _, 5).
puntos_envido_aceptado([envido, envido, real_envido], _, 7).

% puntos de envido rechazado
puntos_envido_rechazado([_], _, 1) :- !.
puntos_envido_rechazado(Cantos, Jugadores, Puntos) :-
    append(Previos, [_], Cantos),
    puntos_envido_aceptado(Previos, Jugadores, Puntos).
