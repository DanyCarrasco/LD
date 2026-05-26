:- module(motor_juego, [
    truco//0,
    start//0,
    crear_jugadores//1,
    jugar_truco//0,
    jugar_mesa//0,
    jugar_mano//0,
    turno_jugador//3,
    jugar_si_falta_carta//4,
    resolver_canto_o_envido_en_turno//3,
    resolver_envido_en_turno//2,
    resolver_canto_en_turno//2,
    resolver_respuesta_envido//4,
    resolver_respuesta_canto//4,
    premiar_envido_aceptado//1,
    premiar_envido_rechazado//2,
    resolver_mano_cartas//2,
    finalizar_ronda//0,
    fin_partida//0,
    hay_ganador_partida_estado//0,
    puede_cantar_estado//1,
    puede_cantar_envido_estado//1,
    ronda_terminada/2,
    alguien_gano_dos/1,
    contar_victorias/3,
    obtener_ganador/3,
    nueva_mesa/2,
    cambiar_mano/2
]).

:- use_module(config).
:- use_module(mazoTruco).
:- use_module(gestor_estado).
:- use_module(interfaz).
:- use_module(sistema_cantos).

% estructuras usadas
%
% carta:
%   palo-numero
%
% jugador:
%   jugador(nombre, mano, puntos)
%
% ronda:
%   ronda(resultados, canto_actual, rechazo, estado_envido)
%
% estado_envido:
%   envido(estado, cantos, rechazo)
%
% estado del juego:
%   [
%       mazo(cartas),
%       jugadores(lista_de_jugadores),
%       ronda(resultados, canto_actual, rechazo, estado_envido)
%   ]
%
% resultados puede contener:
%   jugador(nombre, mano, puntos)
%   parda

% inicia la partida completa
truco -->
    start,
    mezclar_cartas,
    crear_jugadores([jugador2, jugador1]),
    jugar_truco.


% crea el estado inicial
start -->
    state(_, [mazo(Cartas), ronda([], ninguno, none, EstadoEnvido)]),
    {
        setof(Carta, carta(Carta), Cartas),
        estado_envido_inicial(EstadoEnvido)
    }.

% corta si la partida ya termino
jugar_truco -->
    fin_partida,
    !.


% juega rondas hasta terminar la partida
jugar_truco -->
    state(S0, S),
    {
        select(jugadores(P0), S0, S1),
        select(ronda(_, _, _, _), S1, S2),
        maplist(nueva_mesa, P0, P1),
        cambiar_mano(P1, P2),
        imprimir_puntajes_inicio_mesa(P2),
        estado_envido_inicial(EstadoEnvido),
        S = [ronda([], ninguno, none, EstadoEnvido), jugadores(P2)|S2]
    },
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    jugar_mesa,
    jugar_truco.


% cambia solo la parte de jugadores
jugadores(P0, P), [S] -->
    [S0],
    { select(jugadores(P0), S0, S1), S = [jugadores(P)|S1] }.


% crea los jugadores iniciales
crear_jugadores(Nombres) -->
    state(S0, S),
    {
        same_length(Jugadores, Nombres),
        maplist([N, X]>>(X = jugador(N, [], 0)), Nombres, Jugadores),
        S = [jugadores(Jugadores)|S0]
    }.






% juega manos hasta cerrar la ronda
jugar_mesa -->
    jugar_mano,
    state(S, S),
    { select(ronda(Resultados, _, Rech, _), S, _) },
    ( hay_ganador_partida_estado ->
        []
    ; { ronda_terminada(Resultados, Rech) } ->
        finalizar_ronda
    ;
        jugar_mesa
    ).


% juega una mano entre dos jugadores
jugar_mano -->
    asegurar_ronda,
    state(S0, S0),
    {
        member(jugadores([J1, J2]), S0),
        J1 = jugador(N1, _, _),
        J2 = jugador(N2, _, _)
    },
    turno_jugador(N1, Carta1, Termino1),
    jugar_si_falta_carta(N1, Carta1, Termino1, Carta1b),
    (
      { Termino1 == si } ->
        []
    ;
      turno_jugador(N2, Carta2, Termino2),
      jugar_si_falta_carta(N2, Carta2, Termino2, Carta2b),
      (
        { Termino2 == si } ->
          []
      ;
        resolver_mano_cartas([J1, J2], [Carta1b, Carta2b])
      )
    ).

% turno de un jugador
turno_jugador(Nombre, CartaJugada, TerminaRonda) -->
    state(S0, S0),
    {
        member(jugadores(P0), S0),
        member(jugador(Nombre, Mano, _), P0),
        format("~w turno.\nMano: ~w~n", [Nombre, Mano])
        % format("Elegi accion (jugar/cantar):~n", [])
    },
    {
        entrada_teclado("Elegi accion",[jugar, cantar],Accion)
    },
    (
      { Accion == jugar } ->
        {
          format("~w: ", [Nombre]),
          entrada_teclado("elegi carta",Mano,Carta),
          ( member(Carta, Mano) ->
              CartaJugada = Carta,
              TerminaRonda = no
          ; writeln("Carta invalida, se juega la primera."),
            Mano = [CartaJugada|_],
            TerminaRonda = no
          )
        }
    ;
      { Accion == cantar } ->
        % mensaje_cantos_disponibles(Nombre),
        opciones_cantos_disponibles(Opciones),
        {
          entrada_teclado("canta", Opciones,Canto)
        %   read(Canto)
        },
        resolver_canto_o_envido_en_turno(Nombre, Canto, TerminaRonda),
        { CartaJugada = sin_carta }
    ;
      {
        writeln("Accion invalida, se toma jugar."),
        Mano = [CartaJugada|_],
        TerminaRonda = no
      }
    ).


% si solo canto, vuelve a pedir carta
jugar_si_falta_carta(Nombre, Carta, Termino, CartaFinal) -->
    ( { Termino == no, Carta == sin_carta } ->
        turno_jugador(Nombre, CartaFinal, _)
    ;
        { CartaFinal = Carta }
    ).



% decide si resolver truco o envido
resolver_canto_o_envido_en_turno(Nombre, Canto, TerminaRonda) -->
    ( { es_canto_envido(Canto) },
      envido_habilitado ->
        resolver_envido_en_turno(Nombre, Canto),
        ( hay_ganador_partida_estado ->
            { TerminaRonda = si }
        ;
            { TerminaRonda = no }
        )
    ; { es_canto_envido(Canto) } ->
        { writeln("El envido solo puede cantarse en la primera mano antes de que avance la ronda."),
          TerminaRonda = no }
    ;
      resolver_canto_en_turno(Nombre, Canto),
      state(S1, S1),
      {
        ( select(ronda(_, _, rechazo(_), _), S1, _) ->
              TerminaRonda = si
        ;     TerminaRonda = no
        )
      }
    ).




% procesa un canto de envido
resolver_envido_en_turno(J, Canto) -->
    ( puede_cantar_envido_estado(Canto) ->
        state(S, S),
        {
            select(ronda(_, _, _, envido(_, CantosPrevios, _)), S, _),
            append(CantosPrevios, [Canto], CantosNuevos),
            format("~w canta ~w~n", [J, Canto]),
            rival(J, R)
        },
        pedir_respuesta_envido(R, Resp),
        resolver_respuesta_envido(J, R, CantosNuevos, Resp)
    ;
        { writeln("Envido invalido o no permitido.") }
    ).

% procesa un canto de truco
resolver_canto_en_turno(J, Canto) -->
    ( { es_canto(Canto) },
      puede_cantar_estado(Canto) ->
        { format("~w canta ~w~n", [J, Canto]),
          rival(J, R)
        },
        pedir_respuesta(R, Resp),
        resolver_respuesta_canto(J, R, Canto, Resp)
    ;
        { writeln("Canto invalido o no permitido.") }
    ).


% resuelve la respuesta al envido
resolver_respuesta_envido(Cantor, Rival, Cantos, Resp) -->
    ( { Resp == quiero } ->
        premiar_envido_aceptado(Cantos),
        set_estado_envido(envido(resuelto, Cantos, none))
    ; { Resp == no_quiero } ->
        premiar_envido_rechazado(Cantor, Cantos),
        set_estado_envido(envido(resuelto, Cantos, none)),
        { format("~w no quiso el envido.~n", [Rival]) }
    ; { es_canto_envido(Resp), canto_envido_valido(Cantos, Resp) } ->
        { format("~w resube a ~w~n", [Rival, Resp]),
          append(Cantos, [Resp], CantosNuevos),
          true },
        pedir_respuesta_envido(Cantor, Resp2),
        resolver_respuesta_envido(Rival, Cantor, CantosNuevos, Resp2)
    ; { writeln("Respuesta invalida: no_quiero por defecto.") },
      premiar_envido_rechazado(Cantor, Cantos),
      set_estado_envido(envido(resuelto, Cantos, none))
    ).

% resuelve la respuesta a un canto
resolver_respuesta_canto(Cantor, Rival, Canto, Resp) -->
    ( { Resp == acepta } ->
        set_ronda_canto(Canto),
        { puntos_por_canto(Canto, P),
          format("Se juega a ~w puntos.~n", [P]) }
    ; { Resp == rechaza } ->
        { puntos_por_rechazo(Canto, Pts) },
        sumar_puntos_a_jugador(Cantor, Pts),
        set_rechazo(Cantor),
        { format("~w rechazo. ~w gana ~w puntos.~n", [Rival, Cantor, Pts]) }
    ; { es_canto(Resp), canto_supera(Resp, Canto) } ->
        { format("~w resube a ~w~n", [Rival, Resp]) },
        pedir_respuesta(Cantor, Resp2),
        resolver_respuesta_canto(Rival, Cantor, Resp, Resp2)
    ; { writeln("Respuesta invalida: rechazo por defecto."),
        puntos_por_rechazo(Canto, Pts) },
      sumar_puntos_a_jugador(Cantor, Pts),
      set_rechazo(Cantor)
    ).


% suma puntos por envido aceptado
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

% suma puntos por envido rechazado
premiar_envido_rechazado(Cantor, Cantos) -->
    state(S, S),
    {
        select(jugadores([J1, J2]), S, _),
        puntos_envido_rechazado(Cantos, [J1, J2], Pts),
        format("~w gana ~w puntos por el envido no querido.~n", [Cantor, Pts])
    },
    sumar_puntos_a_jugador(Cantor, Pts).


% resuelve las cartas jugadas en la mano
resolver_mano_cartas(P0, CartasSeleccionadas) -->
    state(S0, S),
    {
        select(jugadores(P0), S0, S1),
        select(ronda(Resultados, CantoActual, Rech, EstadoEnvido), S1, S2),
        carta_alta(CartasSeleccionadas, Resultado),
        (
          Resultado = parda ->
            format("Se empato la mano~n", []),
            append([parda], Resultados, Resultados1)
        ;
          nth0(N, CartasSeleccionadas, Resultado),
          nth0(N, P0, JugadorGanador, _),
          JugadorGanador = jugador(Nombre, _, _),
          format("El jugador ~w gano la mano~n", [Nombre]),
          append([JugadorGanador], Resultados, Resultados1)
        ),
        maplist(eliminar_carta, P0, CartasSeleccionadas, P1),
        imprimir_lista(Resultados1),
        S = [ronda(Resultados1, CantoActual, Rech, EstadoEnvido), jugadores(P1)|S2]
    }.

% cierra la ronda y prepara la siguiente
finalizar_ronda -->
    state(S0, S),
    {
        select(ronda(Resultados, Canto, Rech, envido(_Estado, _Cantos, _PremioEnvido)), S0, S1),
        select(jugadores(P0), S1, S2),
        ( Rech = rechazo(_) ->
            P1 = P0
        ;
            obtener_ganador(P0, Resultados, Ganador),
            nth0(N, P0, Ganador, Resto),
            Ganador = jugador(Nombre, Mano, Puntos),
            format("El jugador ~w gano la ronda~n", [Nombre]),
            ( Canto == ninguno -> Suma = 1 ; puntos_por_canto(Canto, Suma) ),
            PuntosNuevos is Puntos + Suma,
            JN = jugador(Nombre, Mano, PuntosNuevos),
            nth0(N, P1, JN, Resto)
        ),
        estado_envido_inicial(EstadoEnvidoNuevo),
        S = [ronda([], ninguno, none, EstadoEnvidoNuevo), jugadores(P1)|S2]
    }.


% informa si la partida ya termino
fin_partida -->
    state(S, S),
    {
        select(jugadores([jugador(N1, _, P1), jugador(N2, _, P2)]), S, _),
        number(P1),
        number(P2),
        puntaje_objetivo(Objetivo),
        (
            P1 >= Objetivo ->
            format("El jugador ~w gano la partida~n", [N1])
        ;
            P2 >= Objetivo ->
            format("El jugador ~w gano la partida~n", [N2])
        )
    }.


% true si alguien ya gano la partida
hay_ganador_partida_estado -->
    state(S, S),
    {
        select(jugadores([jugador(_, _, P1), jugador(_, _, P2)]), S, _),
        puntaje_objetivo(Objetivo),
        (P1 >= Objetivo ; P2 >= Objetivo)
    }.





% valida un canto de truco segun el estado actual
puede_cantar_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda(_, CantoActual, none, _), S0, _),
        es_canto(Nuevo),
        canto_supera(Nuevo, CantoActual)
    }.

% valida un canto de envido segun el estado actual
puede_cantar_envido_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda([], _, none, envido(no_cantado, Cantos, none)), S0, _),
        es_canto_envido(Nuevo),
        canto_envido_valido(Cantos, Nuevo)
    }.


% true si la ronda ya termino
ronda_terminada(_Resultados, rechazo(_)) :- !.
ronda_terminada(Resultados, none) :-
    length(Resultados, L),
    (L >= 3 ; alguien_gano_dos(Resultados)).

% true si alguien gano dos manos
alguien_gano_dos(Resultados) :-
    member(jugador(Nombre, _, _), Resultados),
    contar_victorias(Nombre, Resultados, V),
    V >= 2,
    !.

% cuenta victorias de un jugador
contar_victorias(_, [], 0).
contar_victorias(Nombre, [jugador(Nombre, _, _) | Resto], Total) :-
    contar_victorias(Nombre, Resto, SubTotal),
    Total is SubTotal + 1.
contar_victorias(Nombre, [_ | Resto], Total) :-
    contar_victorias(Nombre, Resto, Total).

% obtiene el ganador de la ronda
obtener_ganador([P1, P2], Resultados, GanadorFinal) :-
    P1 = jugador(N1, _, _),
    P2 = jugador(N2, _, _),
    contar_victorias(N1, Resultados, V1),
    contar_victorias(N2, Resultados, V2),
    (V1 >= V2 -> GanadorFinal = P1 ; GanadorFinal = P2).


% reinicia la mano del jugador
nueva_mesa(jugador(N, _, P), jugador(N, [], P)).

% muestra los puntajes al empezar una mesa
imprimir_puntajes_inicio_mesa([]).
imprimir_puntajes_inicio_mesa([jugador(Nombre, _, Puntos)|Resto]) :-
    format("~w tiene ~w punto(s).~n", [Nombre, Puntos]),
    imprimir_puntajes_inicio_mesa(Resto).


% cambia quien es mano
cambiar_mano([J1, J2], [J2, J1]).
