:- module(config, [
    rival/2, puntaje_objetivo/1, estado_envido_inicial/1, estado_cantos_Truco/1
]).

% rival de cada jugador
rival(jugador1, jugador2).
rival(jugador2, jugador1).

% puntos para ganar la partida
puntaje_objetivo(15).

% estado inicial del envido
estado_envido_inicial(envido(no_cantado, [], none)).
estado_cantos_Truco(trucos([truco])).
