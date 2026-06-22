:- use_module(config).
:- use_module(mazoTruco).
:- use_module(gestor_estado).
:- use_module(sistema_cantos).

% ============================================================
%  test_bug2.pl
%  Simula el flujo COMPLETO de turno_jugador -> resolver canto
%  de envido -> premiar_envido_aceptado, usando respuestas
%  PROGRAMADAS (no entrada_web), para reproducir el bug real
%  sin depender de WASM ni del navegador.
%
%  Reimplementa localmente las mismas reglas de motor_juego_web.pl
%  pero con un "entrada_test/3" que devuelve respuestas fijas
%  de una lista, simulando la secuencia real del log:
%    jugador2: cantar -> falta_envido
%    jugador1: quiero
%
%  Corre con:
%    swipl test_bug2.pl
%    ?- test2.
% ============================================================

:- dynamic respuestas_programadas/1.

% configura la secuencia de respuestas que se van a usar,
% en orden, cada vez que se llame a entrada_test/3
programar_respuestas(Lista) :-
    retractall(respuestas_programadas(_)),
    assertz(respuestas_programadas(Lista)).

% extrae la proxima respuesta programada (simula al usuario)
entrada_test(Mensaje, _Opciones, Resultado) :-
    retract(respuestas_programadas([Resultado|Resto])),
    assertz(respuestas_programadas(Resto)),
    format("[entrada_test] ~w -> ~w~n", [Mensaje, Resultado]).

% --- copias EXACTAS de los predicados relevantes de
%     motor_juego_web.pl, sustituyendo entrada_web por entrada_test ---

turno_jugador_test(Nombre, CartaJugada, TerminaRonda) -->
    state(S0, S0),
    {
        member(jugadores(P0), S0),
        member(jugador(Nombre, Mano, _), P0),
        format("~w turno.\nMano: ~w~n", [Nombre, Mano]),
        entrada_test("Elegi accion", [jugar, cantar], Accion)
    },
    ({ Accion == jugar } ->
        {
          entrada_test("elegi carta", Mano, Carta),
          CartaJugada = Carta,
          TerminaRonda = no
        }
    ;
        { Opciones = [envido, real_envido, falta_envido, truco] },
        {
          entrada_test("canta", Opciones, Canto)
        },
        resolver_canto_o_envido_en_turno_test(Nombre, Canto, TerminaRonda),
        { CartaJugada = sin_carta }
    ).

resolver_canto_o_envido_en_turno_test(Nombre, Canto, TerminaRonda) -->
    ( { es_canto_envido(Canto) } ->
        ( envido_habilitado_test ->
            resolver_envido_en_turno_test(Nombre, Canto),
            { TerminaRonda = no }
        ;
            { TerminaRonda = no }
        )
    ;
        { TerminaRonda = no }
    ).

envido_habilitado_test -->
    state(S0, S0),
    { select(ronda([], _, none, envido(no_cantado, _, none), _, _), S0, _) }.

resolver_envido_en_turno_test(J, Canto) -->
    state(S, S),
    {
        select(ronda(_, _, _, envido(_, CantosPrevios, _), _, _), S, _),
        append(CantosPrevios, [Canto], CantosNuevos),
        format("~w canta ~w~n", [J, Canto]),
        rival(J, R)
    },
    { entrada_test("Respuesta", [quiero, no_quiero], Resp) },
    resolver_respuesta_envido_test(J, R, CantosNuevos, Resp).

resolver_respuesta_envido_test(Cantor, Rival, Cantos, Resp) -->
    ( { Resp == quiero } ->
        premiar_envido_aceptado_test(Cantos),
        set_estado_envido(envido(resuelto, Cantos, none))
    ;
        { format("~w no quiso.~n", [Rival]) }
    ).

premiar_envido_aceptado_test(Cantos) -->
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

% test2: replica EXACTA del log real:
%   jugador2 turno -> cantar -> falta_envido
%   jugador1 responde -> quiero
test2 :-
    estado_inicial(S0),
    set_rivales([jugador1, jugador2]),
    format("=== ESTADO INICIAL ===~n"),
    imprimir_jugadores(S0),

    % jugador2 es quien arranca el turno en este escenario
    programar_respuestas([cantar, falta_envido, quiero]),

    phrase(turno_jugador_test(jugador2, _Carta, _Termina), [S0], [S1]),

    format("~n=== ESTADO DESPUES del turno completo de jugador2 ===~n"),
    imprimir_jugadores(S1).

imprimir_jugadores(S) :-
    member(jugadores(Js), S),
    forall(member(jugador(N, _, P), Js),
           format("  ~w: ~w puntos~n", [N, P])).