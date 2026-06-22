:- module(motor_juego_ws, [
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
    cambiar_mano/2,
    set_jugadores_iniciales/1
]).

:- use_module(config).
:- use_module(mazoTruco).
:- use_module(gestor_estado).
:- use_module(interfaz_ws, [
    registrar_socket_jugador/2,
    socket_jugador/2,
    enviar_socket/2,
    esperar_seleccion_socket/4,
    publicar/1
]).
:- use_module(sistema_cantos).

:- dynamic jugadores_iniciales/1.
:- dynamic orden_inicio_ronda/1.
:- dynamic jugador_actual/1.

% mismas reglas que el motor base, pero usando la interfaz websocket

% guarda los nombres reales de los jugadores
set_jugadores_iniciales(Nombres) :-
    retractall(jugadores_iniciales(_)),
    assertz(jugadores_iniciales(Nombres)).

% busca el socket de un jugador
socket_de_jugador(Jugador, WebSocket) :-
    socket_jugador(Jugador, WebSocket).

% envia un mensaje a un jugador o a la consola
publicar_a_jugador(Jugador, Mensaje) :-
    ( socket_de_jugador(Jugador, WebSocket) ->
        enviar_socket(WebSocket, Mensaje)
    ;
        publicar(Mensaje)
    ).

% recuerda el jugador al que le toca responder
set_jugador_actual(Jugador) :-
    retractall(jugador_actual(_)),
    assertz(jugador_actual(Jugador)).

% pide una seleccion como en el motor base
entrada_teclado(Mensaje, Opciones, Resultado) :-
    jugador_actual(Jugador),
    ( socket_de_jugador(Jugador, WebSocket) ->
        esperar_seleccion_socket(WebSocket, Mensaje, Opciones, Resultado)
    ;
        interfaz_ws:entrada_teclado(Mensaje, Opciones, Resultado)
    ).

% resume una lista de resultado de mano
imprimir_lista(Lista) :-
    salida_compuesta(Lista, Texto),
    publicar(Texto).

% arma el texto de una lista de resultados
salida_compuesta([parda], "Se empato la mano.").
salida_compuesta(Lista, Texto) :-
    findall(Nombre, member(jugador(Nombre, _, _), Lista), Nombres),
    Nombres \= [],
    atomic_list_concat(Nombres, ', ', NombresTexto),
    format(string(Texto), "resultado de la mano: ~w", [NombresTexto]).
salida_compuesta(_, "resultado de la mano calculado.").

% arma los cantos de truco disponibles
% devuelve los cantos disponibles
    opciones_cantos_disponibles(Opciones) -->
    state(S0,S0),
    {
        member(ronda(_,_,_,_,trucos(X),_),S0)
    },
    ( envido_habilitado ->
        { Opciones = [envido, real_envido, falta_envido | X ] }
    ;
        { Opciones = X }
    ).

% true si el envido todavia puede jugarse
envido_habilitado -->
    state(S0, S0),
    {
        select(ronda([], ninguno, none, envido(no_cantado, _, none), _, none), S0, _)
    }.

% muestra los cantos posibles
mensaje_cantos_disponibles(Nombre) -->
    ( envido_habilitado ->
        { format("~w canta (truco/retruco/vale4/envido/real_envido/falta_envido):~n", [Nombre]) }
    ;
        { format("~w canta (truco/retruco/vale4):~n", [Nombre]) }
    ).

% pide respuesta al envido al rival
pedir_respuesta_envido(Rival, Resp) -->
    state(S, S),
    {
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format(string(Texto), "~w responde.~nMano: ~w", [Rival, Mano]),
        publicar_a_jugador(Rival, Texto),
        member(jugador(Rival, _, _), P0),
        set_jugador_actual(Rival),
        entrada_teclado("Respuesta", [quiero, no_quiero, envido, real_envido, falta_envido], Resp)
    }.

% pide respuesta al canto de truco al rival
pedir_respuesta(Rival, Resp) -->
    state(S, S),
    {
        member(ronda(_, _, _, _, trucos(X), _), S),
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format(string(Texto), "~w responde.~nMano: ~w", [Rival, Mano]),
        publicar_a_jugador(Rival, Texto),
        append([acepta, rechaza], X, OpcionesBasicas),
        append([acepta, rechaza, envido, real_envido, falta_envido], X, OpcionesConEnvido)
    },
    ( envido_habilitado ->
        { set_jugador_actual(Rival),
          entrada_teclado("Respuesta", OpcionesConEnvido, Resp) }
    ;
        { set_jugador_actual(Rival),
          entrada_teclado("Respuesta", OpcionesBasicas, Resp) }
    ).

% muestra mensajes de juego
% publica un mensaje de juego
mostrar(turno(Nombre, Mano)) :-
    format(string(Texto), "~w turno.~nMano: ~w", [Nombre, Mano]),
    publicar_a_jugador(Nombre, Texto).
mostrar(elige_carta(Nombre)) :-
    format(string(Texto), "~w: ", [Nombre]),
    publicar_a_jugador(Nombre, Texto).
mostrar(mensaje(Texto)) :-
    publicar(Texto).
mostrar(canta(J, Canto)) :-
    format(string(Texto), "~w canta ~w", [J, Canto]),
    publicar(Texto).
mostrar(no_quiso_envido(Rival)) :-
    format(string(Texto), "~w no quiso el envido.", [Rival]),
    publicar(Texto).
mostrar(resube(Rival, Resp)) :-
    format(string(Texto), "~w resube a ~w", [Rival, Resp]),
    publicar(Texto).
mostrar(se_juega_a(P)) :-
    format(string(Texto), "Se juega a ~w puntos.", [P]),
    publicar(Texto).
mostrar(rechaza(Cantor, Rival, Pts)) :-
    format(string(Texto), "~w rechazo. ~w gana ~w puntos.", [Rival, Cantor, Pts]),
    publicar(Texto).
mostrar(envido(Nombre, Puntos)) :-
    format(string(Texto), "~w tiene ~w de envido.", [Nombre, Puntos]),
    publicar(Texto).
mostrar(gana_envido(Ganador, Pts)) :-
    format(string(Texto), "~w gana el envido y suma ~w puntos.", [Ganador, Pts]),
    publicar(Texto).
mostrar(gana_envido_rechazado(Cantor, Pts)) :-
    format(string(Texto), "~w gana ~w puntos por el envido no querido.", [Cantor, Pts]),
    publicar(Texto).
mostrar(resolviendo_cartas) :-
    publicar("resolviendo cartas").
mostrar(mano_empatada) :-
    publicar("Se empato la mano").
mostrar(gana_mano(Nombre)) :-
    format(string(Texto), "El jugador ~w gano la mano", [Nombre]),
    publicar(Texto).
mostrar(gana_ronda(Nombre)) :-
    format(string(Texto), "El jugador ~w gano la ronda", [Nombre]),
    publicar(Texto).
mostrar(gana_partida(Nombre)) :-
    format(string(Texto), "El jugador ~w gano la partida", [Nombre]),
    publicar(Texto).
mostrar(puntos(Nombre, Puntos)) :-
    format(string(Texto), "~w tiene ~w punto(s).", [Nombre, Puntos]),
    publicar_a_jugador(Nombre, Texto).
mostrar(Otro) :-
    term_string(Otro, Texto),
    publicar(Texto).

% inicia la partida completa
truco -->
    start,
    mezclar_cartas,
    { jugadores_iniciales(Nombres) },
    crear_jugadores(Nombres),
    jugar_truco.

% crea el estado inicial
start -->
    state(_, [mazo(Cartas), ronda([], ninguno, none, EstadoEnvido, EstadoTruco, none)]),
    {
        setof(Carta, carta(Carta), Cartas),
        estado_envido_inicial(EstadoEnvido),
        estado_cantos_Truco(EstadoTruco)
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
        select(ronda(_, _, _, _, _, _), S1, S2),
        maplist(nueva_mesa, P0, P1),
        cambiar_mano(P1, P2),
        set_orden_inicio_ronda(P2),
        imprimir_puntajes_inicio_mesa(P2),
        estado_envido_inicial(EstadoEnvido),
        estado_cantos_Truco(EstadoTruco),
        S = [ronda([], ninguno, none, EstadoEnvido, EstadoTruco, none), jugadores(P2)|S2]
    },
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    jugar_mesa,
    jugar_truco.

% reinicia la mano del jugador
nueva_mesa(jugador(N, _, P), jugador(N, [], P)).

% cambia quien es mano
cambiar_mano([J1, J2], [J2, J1]).

% guarda el orden con el que arranco la ronda
set_orden_inicio_ronda(Jugadores) :-
    retractall(orden_inicio_ronda(_)),
    assertz(orden_inicio_ronda(Jugadores)).

% reordena los jugadores segun los nombres indicados
reordenar_jugadores_por_nombres(Activos, [jugador(N1, _, _), jugador(N2, _, _)], [J1, J2]) :-
    jugador_por_nombre(N1, Activos, J1),
    jugador_por_nombre(N2, Activos, J2).

% busca un jugador por nombre
jugador_por_nombre(Nombre, [jugador(Nombre, Mano, Puntos) | _], jugador(Nombre, Mano, Puntos)).
jugador_por_nombre(Nombre, [_ | Resto], Jugador) :-
    jugador_por_nombre(Nombre, Resto, Jugador).

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
    { select(ronda(Resultados, _, Rech, _, _, _), S, _) },
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
        mostrar(turno(Nombre, Mano)),
        set_jugador_actual(Nombre),
        entrada_teclado("Elegi accion", [jugar, cantar], Accion)
    },
    ({ Accion == jugar } ->
        {
          mostrar(elige_carta(Nombre)),
          set_jugador_actual(Nombre),
          entrada_teclado("elegi carta", Mano, Carta),
          CartaJugada = Carta,
          TerminaRonda = no
        }
    ;
        opciones_cantos_disponibles(Opciones),
        {
          set_jugador_actual(Nombre),
          entrada_teclado("canta", Opciones, Canto)
        },
        resolver_canto_o_envido_en_turno(Nombre, Canto, TerminaRonda),
        { CartaJugada = sin_carta }
    ).

% si solo canto, vuelve a pedir carta
    jugar_si_falta_carta(Nombre, Carta, Termino, CartaFinal) -->
    ( { Termino == no, Carta == sin_carta } ->
        state(S, S),
        {
            ( select(ronda(_, _, _, _, _, Pendiente), S, _),
              Pendiente \== none ->
                JugadorCarta = Pendiente
            ;
                JugadorCarta = Nombre
            )
        },
        pedir_carta_pendiente(JugadorCarta, CartaFinal),
        set_pendiente(none)
    ;
        { CartaFinal = Carta }
    ).

% pide solo la carta pendiente despues de un canto aceptado
pedir_carta_pendiente(Nombre, CartaFinal) -->
    state(S0, S0),
    {
        member(jugadores(P0), S0),
        member(jugador(Nombre, Mano, _), P0),
        mostrar(elige_carta(Nombre)),
        set_jugador_actual(Nombre),
        entrada_teclado("elegi carta", Mano, CartaFinal)
    }.

% decide si resolver truco o envido
resolver_canto_o_envido_en_turno(Nombre, Canto, TerminaRonda) -->
    ( { es_canto_envido(Canto) } ->
        ( envido_habilitado ->
            resolver_envido_en_turno(Nombre, Canto),
            ( hay_ganador_partida_estado ->
                { TerminaRonda = si }
            ;
                { TerminaRonda = no }
            )
        ;
            { mostrar(mensaje('el envido solo puede cantarse en la primera mano antes de que avance la ronda')),
              TerminaRonda = no }
        )
    ;
        resolver_canto_en_turno(Nombre, Canto),
        state(S1, S1),
        { ( select(ronda(_, _, rechazo(_), _, _, _), S1, _) ->
            TerminaRonda = si
        ;
            TerminaRonda = no
        ) }
    ).

% procesa un canto de envido
resolver_envido_en_turno(J, Canto) -->
    ( puede_cantar_envido_estado(Canto) ->
        state(S, S),
        {
            select(ronda(_, _, _, envido(_, CantosPrevios, _), _, _), S, _),
            append(CantosPrevios, [Canto], CantosNuevos),
            mostrar(canta(J, Canto)),
            rival(J, R)
        },
        pedir_respuesta_envido(R, Resp),
        resolver_respuesta_envido(J, R, CantosNuevos, Resp)
    ;
        { mostrar(mensaje('envido invalido o no permitido')) }
    ).

% procesa un canto de truco
resolver_canto_en_turno(J, Canto) -->
    ( { es_canto(Canto) }, puede_cantar_estado(Canto) ->
        set_pendiente(J),
        step_estado_truco,
        { mostrar(canta(J, Canto)),
          rival(J, R)
        },
        pedir_respuesta(R, Resp),
        resolver_respuesta_canto(J, R, Canto, Resp)
    ;
        { mostrar(mensaje('canto invalido o no permitido')) }
    ).

% resuelve la respuesta al envido
resolver_respuesta_envido(Cantor, Rival, Cantos, Resp) -->
    ( { Resp == quiero } ->
        premiar_envido_aceptado(Cantos),
        set_pendiente(Rival),
        set_estado_envido(envido(resuelto, Cantos, none))
    ; { Resp == no_quiero } ->
        premiar_envido_rechazado(Cantor, Cantos),
        set_estado_envido(envido(resuelto, Cantos, none)),
        { mostrar(no_quiso_envido(Rival)) }
    ; { es_canto_envido(Resp), canto_envido_valido(Cantos, Resp) } ->
        { mostrar(resube(Rival, Resp)),
          append(Cantos, [Resp], CantosNuevos),
          true },
        pedir_respuesta_envido(Cantor, Resp2),
        resolver_respuesta_envido(Rival, Cantor, CantosNuevos, Resp2)
    ).

% resuelve la respuesta a un canto
resolver_respuesta_canto(Cantor, Rival, Canto, Resp) -->
    ( { Resp == acepta } ->
        set_ronda_canto(Canto),
        { puntos_por_canto(Canto, P),
          mostrar(se_juega_a(P)) }
    ; { Resp == rechaza } ->
        { puntos_por_rechazo(Canto, Pts) },
        sumar_puntos_a_jugador(Cantor, Pts),
        set_rechazo(Cantor),
        { mostrar(rechaza(Cantor, Rival, Pts)) }
    ; { es_canto_envido(Resp) } ->
        state(S, S),
        {
            select(ronda(_, _, _, envido(_, Cantos, _), _, _), S, _),
            canto_envido_valido(Cantos, Resp),
            mostrar(canta(Rival, Resp)),
            append(Cantos, [Resp], CantosNuevos)
        },
        pedir_respuesta_envido(Cantor, Resp2),
        resolver_respuesta_envido(Rival, Cantor, CantosNuevos, Resp2)
    ; { es_canto(Resp), canto_supera(Resp, Canto) } ->
        { mostrar(resube(Rival, Resp)) },
        step_estado_truco,
        pedir_respuesta(Cantor, Resp2),
        resolver_respuesta_canto(Rival, Cantor, Resp, Resp2)
    ; { Resp == retruco } ->
        set_ronda_canto(retruco),
        { mostrar(se_juega_a(3)) }
    ; { Resp == vale4 } ->
        set_ronda_canto(vale4),
        { mostrar(se_juega_a(4)) }
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
        mostrar(envido(N1, P1)),
        mostrar(envido(N2, P2)),
        mostrar(gana_envido(Ganador, Pts))
    },
    sumar_puntos_a_jugador(Ganador, Pts).

% suma puntos por envido rechazado
premiar_envido_rechazado(Cantor, Cantos) -->
    state(S, S),
    {
        select(jugadores([J1, J2]), S, _),
        puntos_envido_rechazado(Cantos, [J1, J2], Pts),
        mostrar(gana_envido_rechazado(Cantor, Pts))
    },
    sumar_puntos_a_jugador(Cantor, Pts).

% resuelve las cartas jugadas en la mano
resolver_mano_cartas(P0, CartasSeleccionadas) -->
    state(S0, S),
    {
        mostrar(resolviendo_cartas),
        select(jugadores(P0), S0, S1),
        select(ronda(Resultados, CantoActual, Rech, EstadoEnvido, EstadoTruco, Pendiente), S1, S2),
        carta_alta(CartasSeleccionadas, Resultado),
        (
          Resultado = parda ->
            mostrar(mano_empatada),
            append([parda], Resultados, Resultados1),
            maplist(eliminar_carta, P0, CartasSeleccionadas, CartasRestantes),
            JugadoresSiguiente = CartasRestantes
        ;
          nth0(N, CartasSeleccionadas, Resultado),
          nth0(N, P0, JugadorGanador, _),
          JugadorGanador = jugador(Nombre, _, _),
          mostrar(gana_mano(Nombre)),
          append([JugadorGanador], Resultados, Resultados1),
          maplist(eliminar_carta, P0, CartasSeleccionadas, CartasRestantes),
          ( N =:= 0 ->
              JugadoresSiguiente = CartasRestantes
          ;
              CartasRestantes = [J1Rest, J2Rest],
              JugadoresSiguiente = [J2Rest, J1Rest]
          )
        ),
        imprimir_lista(Resultados1),
        S = [ronda(Resultados1, CantoActual, Rech, EstadoEnvido, EstadoTruco, Pendiente), jugadores(JugadoresSiguiente)|S2]
    }.

% cierra la ronda y prepara la siguiente
finalizar_ronda -->
    state(S0, S),
    {
        select(ronda(Resultados, Canto, Rech, envido(_Estado, _Cantos, _PremioEnvido),_, _), S0, S1),
        select(jugadores(P0), S1, S2),
        ( Rech = rechazo(_) ->
            P1 = P0
        ;
            obtener_ganador(P0, Resultados, Ganador),
            nth0(N, P0, Ganador, Resto),
            Ganador = jugador(Nombre, Mano, Puntos),
            mostrar(gana_ronda(Nombre)),
            ( Canto == ninguno -> Suma = 1 ; puntos_por_canto(Canto, Suma) ),
            PuntosNuevos is Puntos + Suma,
            JN = jugador(Nombre, Mano, PuntosNuevos),
            nth0(N, P1, JN, Resto)
        ),
        estado_envido_inicial(EstadoEnvidoNuevo),
        estado_cantos_Truco(EstadoTruco),
        ( orden_inicio_ronda(PInicio) ->
            cambiar_mano(PInicio, POrdenSiguiente),
            reordenar_jugadores_por_nombres(P1, POrdenSiguiente, PJugadoresFinal)
        ;
            PJugadoresFinal = P1
        ),
        S = [ronda([], ninguno, none, EstadoEnvidoNuevo, EstadoTruco, none), jugadores(PJugadoresFinal)|S2]
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
            mostrar(gana_partida(N1))
        ;
            P2 >= Objetivo ->
            mostrar(gana_partida(N2))
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
        select(ronda(_, CantoActual, none, _, _, _), S0, _),
        es_canto(Nuevo),
        canto_supera(Nuevo, CantoActual)
    }.

% valida un canto de envido segun el estado actual
puede_cantar_envido_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda([], ninguno, none, envido(no_cantado, Cantos, none), _, none), S0, _),
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

% muestra los puntajes al empezar una mesa
imprimir_puntajes_inicio_mesa([]).
imprimir_puntajes_inicio_mesa([jugador(Nombre, _, Puntos)|Resto]) :-
    mostrar(puntos(Nombre, Puntos)),
    imprimir_puntajes_inicio_mesa(Resto).
