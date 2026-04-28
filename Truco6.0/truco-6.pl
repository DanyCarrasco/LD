:- use_module(motor_juego).

% truco
%
% Punto de entrada tradicional para ejecutar la partida sin invocar phrase/3
% manualmente. Arranca con una lista de un solo elemento anonimo y espera
% terminar tambien con una lista de un unico estado final.
truco :-
    write('\33[2J\33[H'),
    phrase(truco, [_], [_]).

