:- use_module(config).
:- use_module(mazoTruco).
:- use_module(gestor_estado).
:- use_module(sistema_cantos).

% ============================================================
%  test_bug.pl
%  Aisla el bug de los puntos de falta_envido que no persisten,
%  reimplementando SOLO premiar_envido_aceptado//1 (copiada tal
%  cual de motor_juego_web.pl) para no depender de interfaz_web
%  (que requiere library(wasm), no disponible en SWI de consola).
%
%  Corre con:
%    swipl test_bug.pl -g test1 -t halt
% ============================================================

% --- copia exacta de premiar_envido_aceptado//1 ---
premiar_envido_aceptado(Cantos) -->
    state(S, S),
    {
        select(jugadores([J1, J2]), S, _),
        J1 = jugador(N1, Mano1, _),
        J2 = jugador(N2, Mano2, _),
        valor_envido_mano(Mano1, P1),
        valor_envido_mano(Mano2, P2),
        puntos_envido_aceptado(Cantos, [J1, J2], Pts),
        ( P1 >= P2 -> Ganador = N1 ; Ganador = N2 ),
        format("~w tiene ~w de envido.~n", [N1, P1]),
        format("~w tiene ~w de envido.~n", [N2, P2]),
        format("~w gana el envido y suma ~w puntos.~n", [Ganador, Pts])
    },
    sumar_puntos_a_jugador(Ganador, Pts).


estado_inicial(S) :-
    S = [
        jugadores([
            jugador(jugador1, [c-4, o-11, e-2], 5),
            jugador(jugador2, [c-11, b-5, b-7], 4)
        ]),
        ronda([], ninguno, none, envido(no_cantado, [], none), trucos([truco]), none)
    ].

test1 :-
    estado_inicial(S0),
    format("=== ESTADO INICIAL ===~n"),
    imprimir_jugadores(S0),

    set_rivales([jugador1, jugador2]),

    phrase(premiar_envido_aceptado([falta_envido]), [S0], [S1]),

    format("~n=== ESTADO DESPUES de premiar_envido_aceptado ===~n"),
    imprimir_jugadores(S1).

imprimir_jugadores(S) :-
    member(jugadores(Js), S),
    forall(member(jugador(N, _, P), Js),
           format("  ~w: ~w puntos~n", [N, P])).
