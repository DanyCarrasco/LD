:- module(config, [
    rival/2, puntaje_objetivo/1, estado_envido_inicial/1
]).
% rival(+Jugador, -Rival)
%
% Relacion fija entre los dos jugadores del programa. Como el modelo solo
% contempla partidas de a dos, este predicado funciona como un mapeo directo
% entre cada nombre y su oponente.
rival(jugador1, jugador2).
rival(jugador2, jugador1).

% puntaje_objetivo(-Puntaje)
%
% Define cuantos puntos hacen falta para ganar la partida. En este archivo
% esta fijado en 15, que corresponde a una partida corta tradicional.
puntaje_objetivo(15).

% estado_envido_inicial(-EstadoEnvido)
%
% Construye el estado base del subsystema de envido para una ronda nueva.
% Indica que todavia no hubo cantos de envido, no hay secuencia registrada
% y tampoco existe un rechazo pendiente.
estado_envido_inicial(envido(no_cantado, [], none)).