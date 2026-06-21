:- use_module(motor_juego).

% punto de entrada normal
truco :-
    write('\33[2J\33[H'),
    phrase(truco, [_], [_]).

