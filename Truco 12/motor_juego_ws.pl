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
    puede_cantar_estado//2,
    puede_cantar_envido_estado//1,
    ronda_terminada/2,
    alguien_gano_dos/1,
    contar_victorias/3,
    obtener_ganador/3,
    nueva_mesa/2,
    cambiar_mano/2,
    set_jugadores_iniciales/1
]).

:- use_module(config, [
    estado_envido_inicial/1,
    estado_cantos_Truco/1,
    rival/2,
    puntaje_objetivo/1
]).
:- use_module(mazoTruco).
:- use_module(gestor_estado).
:- use_module(interfaz_ws, [
    socket_jugador/2,
    enviar_socket/2,
    esperar_seleccion_socket/4,
    publicar/1
]).
:- use_module(sistema_cantos).
:- use_module(library(lists), [append/3, member/2, nth0/3, same_length/2, select/3]).
:- use_module(library(readutil), [read_line_to_string/2]).

% Guarda los nombres reales de los jugadores conectados.
set_jugadores_iniciales(Nombres) :-
    retractall(jugadores_iniciales(_)),
    assertz(jugadores_iniciales(Nombres)).

% obtiene el websocket de un jugador
socket_de_jugador(Jugador, WebSocket) :-
    socket_jugador(Jugador, WebSocket).

% guarda el jugador que esta atendiendo la entrada
set_jugador_actual(Jugador) :-
    retractall(jugador_actual(_)),
    assertz(jugador_actual(Jugador)).

% guarda quien puede subir el canto
set_jugador_habilitado_canto(Jugador) :-
    retractall(jugador_habilitado_canto(_)),
    assertz(jugador_habilitado_canto(Jugador)).

% limpia la habilitacion de canto
limpiar_jugador_habilitado_canto :-
    retractall(jugador_habilitado_canto(_)).

% habilita o deshabilita el envido para la mano actual
set_envido_disponible(Estado) :-
    retractall(envido_disponible(_)),
    assertz(envido_disponible(Estado)).

% envia un mensaje a un jugador
publicar_a_jugador(Jugador, Mensaje) :-
    (   socket_de_jugador(Jugador, WebSocket)
    ->  enviar_socket(WebSocket, Mensaje)
    ;   writeln(Mensaje)
    ).

% publica un mensaje general
publicar_texto(Texto) :-
    (   socket_jugador(_, _)
    ->  publicar(Texto)
    ;   writeln(Texto)
    ).

% convierte terminos a texto
texto_a_cadena(Termino, Cadena) :-
    string(Termino),
    !,
    Cadena = Termino.
texto_a_cadena(Termino, Cadena) :-
    atom(Termino),
    !,
    atom_string(Termino, Cadena).
texto_a_cadena(Termino, Cadena) :-
    term_string(Termino, Cadena).

% lee una opcion desde socket o consola
entrada_teclado(Mensaje, Opciones, Resultado) :-
    Opciones \= [],
    repeat,
        (   jugador_actual(Jugador),
            socket_de_jugador(Jugador, WebSocket)
        ->  esperar_seleccion_socket(WebSocket, Mensaje, Opciones, Resultado)
        ;   format('~w (~w)\n', [Mensaje, Opciones]),
            read_line_to_string(user_input, Linea),
            catch(term_string(Entrada, Linea), _, Entrada = error),
            (   member(Entrada, Opciones)
            ->  Resultado = Entrada, !
            ;   write('Opcion no valida!\n'),
                fail
            )
        ).

% pide la respuesta al envido (solo opciones válidas)
pedir_respuesta_envido(Rival, Resp) -->
    state(S, S),
    {
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        select(ronda(_, _, _, envido(_, Cantos, _), _, _), S, _),
        format(string(Texto), "~w responde.~nMano: ~w", [Rival, Mano]),
        publicar_a_jugador(Rival, Texto),
        set_jugador_actual(Rival),
        % opciones siempre incluyen quiero/no_quiero
        OpcionesBase = [quiero, no_quiero],
        % agregar envidos válidos según los cantos actuales
        findall(E, (member(E, [envido, real_envido, falta_envido]), canto_envido_valido(Cantos, E)), EnvidosValidos),
        append(OpcionesBase, EnvidosValidos, Opciones)
    },
    { entrada_teclado("Respuesta", Opciones, Resp) }.

% calcula las opciones de canto disponibles
opciones_cantos_disponibles(Nombre, Opciones) -->
    state(S0, S0),
    {
        member(ronda(_, CantoActual, _, _, trucos(X), _), S0),
        ( CantoActual == ninguno ->
            XTruco = [truco]
        ; jugador_habilitado_canto(Habilitado),
          Habilitado == Nombre ->
            XTruco = X
        ;
            XTruco = []
        )
    },
    ( envido_habilitado ->
        { Opciones = [envido, real_envido, falta_envido | XTruco ] }
    ;
        { Opciones = XTruco }
    ).

% calcula las acciones disponibles
opciones_accion(Nombre, Acciones) -->
    opciones_cantos_disponibles(Nombre, OpcionesCanto),
    {
        ( OpcionesCanto == [] ->
            Acciones = [jugar]
        ;
            Acciones = [jugar, cantar]
        )
    }.

% anuncia los cantos posibles
mensaje_cantos_disponibles(Nombre) -->
    ( envido_habilitado ->
        { format("~w canta (truco/retruco/vale4/envido/real_envido/falta_envido):~n", [Nombre]) }
    ;
        { format("~w canta (truco/retruco/vale4):~n", [Nombre]) }
    ).

% true si el envido sigue habilitado
envido_habilitado -->
    state(S0, S0),
    {
        select(ronda([], ninguno, none, envido(no_cantado, _, none), _, _), S0, _)
    }.

% pide la respuesta al canto de truco
pedir_respuesta(Rival, Resp) -->
    state(S, S),
    {
        member(ronda(_, _, _, _, trucos(X), _), S),
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format(string(Texto), "~w responde. Mano: ~w", [Rival, Mano]),
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

% muestra el turno actual
mostrar(turno(Nombre, Mano)) :-
    format(string(Texto), "~w turno.~nMano: ~w", [Nombre, Mano]),
    publicar_a_jugador(Nombre, Texto).
% muestra la carta de un jugador
mostrar(elige_carta(Nombre)) :-
    format(string(Texto), "~w: ", [Nombre]),
    publicar_a_jugador(Nombre, Texto).
% muestra texto general
mostrar(mensaje(Texto)) :-
    publicar_texto(Texto).
% muestra un canto
mostrar(canta(J, Canto)) :-
    format(string(Texto), "~w canta ~w", [J, Canto]),
    publicar_texto(Texto).
% muestra rechazo de envido
mostrar(no_quiso_envido(Rival)) :-
    format(string(Texto), "~w no quiso el envido.", [Rival]),
    publicar_texto(Texto).
% muestra una resubida
mostrar(resube(Rival, Resp)) :-
    format(string(Texto), "~w resube a ~w", [Rival, Resp]),
    publicar_texto(Texto).
% muestra el puntaje objetivo del canto
mostrar(se_juega_a(P)) :-
    format(string(Texto), "Se juega a ~w puntos.", [P]),
    publicar_texto(Texto).
% muestra el resultado de un rechazo
mostrar(rechaza(Cantor, Rival, Pts)) :-
    format(string(Texto), "~w rechazo. ~w gana ~w puntos.", [Rival, Cantor, Pts]),
    publicar_texto(Texto).
% muestra el envido de un jugador
mostrar(envido(Nombre, Puntos)) :-
    format(string(Texto), "~w tiene ~w de envido.", [Nombre, Puntos]),
    publicar_texto(Texto).
% muestra el premio del envido
mostrar(gana_envido(Ganador, Pts)) :-
    format(string(Texto), "~w gana el envido y suma ~w puntos.", [Ganador, Pts]),
    publicar_texto(Texto).
% muestra el premio por envido rechazado
mostrar(gana_envido_rechazado(Cantor, Pts)) :-
    format(string(Texto), "~w gana ~w puntos por el envido no querido.", [Cantor, Pts]),
    publicar_texto(Texto).
% muestra estado de resolucion de cartas
mostrar(resolviendo_cartas) :-
    publicar_texto("resolviendo cartas!!").
% muestra una mano empatada
mostrar(mano_empatada) :-
    publicar_texto("Se empato la mano").
% muestra quien gano la mano
mostrar(gana_mano(Nombre)) :-
    format(string(Texto), "El jugador ~w gano la mano", [Nombre]),
    publicar_texto(Texto).
% muestra quien gano la ronda
mostrar(gana_ronda(Nombre)) :-
    format(string(Texto), "El jugador ~w gano la ronda", [Nombre]),
    publicar_texto(Texto).
% muestra quien gano la partida
mostrar(gana_partida(Nombre)) :-
    format(string(Texto), "El jugador ~w gano la partida", [Nombre]),
    publicar_texto(Texto).
% muestra puntajes de un jugador
mostrar(puntos(Nombre, Puntos)) :-
    format(string(Texto), "~w tiene ~w punto(s).", [Nombre, Puntos]),
    publicar_a_jugador(Nombre, Texto).
mostrar(Otro) :-
    texto_a_cadena(Otro, Texto),
    publicar_texto(Texto).

% inicia la partida completa
truco -->
    start,
    mezclar_cartas,
    {
        (   jugadores_iniciales(Nombres)
        ->  true
        ;   Nombres = [jugador2, jugador1]
        )
    },
    crear_jugadores(Nombres),
    jugar_truco.

% crea el estado inicial
start -->
    state(_, [mazo(Cartas), ronda([], ninguno, none, EstadoEnvido, EstadoTruco, none)]),
    {
        limpiar_jugador_habilitado_canto,
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
        P2 = [jugador(PrimerNombre, _, _) | _],
        imprimir_puntajes_inicio_mesa(P2),
        estado_envido_inicial(EstadoEnvido),
        estado_cantos_Truco(EstadoTruco),
        S = [ronda([], ninguno, none, EstadoEnvido, EstadoTruco, PrimerNombre), jugadores(P2)|S2]
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
    { limpiar_jugador_habilitado_canto },
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
        set_jugador_actual(Nombre)
    },
    opciones_accion(Nombre, Acciones),
    {
        entrada_teclado("Elegi accion", Acciones, Accion)
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
        opciones_cantos_disponibles(Nombre, Opciones),
        {
          set_jugador_actual(Nombre),
          entrada_teclado("canta", Opciones, Canto)
        },
        resolver_canto_o_envido_en_turno(Nombre, Canto, TerminaRonda),
        % Si no termina ronda pero se cantó algo, se debe jugar carta en este turno
        ( { TerminaRonda == no } ->
            state(S1, S1),
            {
                member(jugadores(P1), S1),
                member(jugador(Nombre, Mano1, _), P1),
                mostrar(elige_carta(Nombre)),
                set_jugador_actual(Nombre),
                entrada_teclado("elegi carta", Mano1, CartaJugada)
            }
        ;
            { CartaJugada = sin_carta }
        )
    ).

% si solo canto, vuelve a pedir carta
% Nota: Ahora turno_jugador maneja automáticamente pedir carta después de cantar,
% así que este predicado solo valida que la carta fue jugada
jugar_si_falta_carta(_Nombre, Carta, Termino, CartaFinal) -->
    ( { Termino == no, Carta == sin_carta } ->
        % Este caso ya NO debería ocurrir porque turno_jugador lo maneja
        { mostrar(mensaje("Error interno: carta no jugada después de canto.")) },
        { CartaFinal = Carta }
    ;
        { CartaFinal = Carta }
    ).

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
            { mostrar(mensaje("El envido solo puede cantarse en la primera mano antes de que avance la ronda.")),
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
        resolver_respuesta_envido(J, R, CantosNuevos, Resp),
        !
    ;
        { mostrar(mensaje("Envido invalido o no permitido.")) }
    ).

% procesa un canto de truco
resolver_canto_en_turno(J, Canto) -->
    ( { es_canto(Canto) }, puede_cantar_estado(J, Canto) ->
        step_estado_truco,
        { mostrar(canta(J, Canto)),
          rival(J, R)
        },
        pedir_respuesta(R, Resp),
        resolver_respuesta_canto(J, R, Canto, Resp),
        !
    ;
        { mostrar(mensaje("Canto invalido o no permitido.")) }
    ).

% resuelve la respuesta al envido
resolver_respuesta_envido(Cantor, Rival, Cantos, Resp) -->
    ( { Resp == quiero } ->
        premiar_envido_aceptado(Cantos),
        set_estado_envido(envido(resuelto, Cantos, none)),
        { set_jugador_actual(Cantor) },
        !
    ; { Resp == no_quiero } ->
        premiar_envido_rechazado(Cantor, Cantos),
        set_estado_envido(envido(resuelto, Cantos, none)),
        { mostrar(no_quiso_envido(Rival)),
          set_jugador_actual(Cantor)
        },
        !
    ; { es_canto_envido(Resp), canto_envido_valido(Cantos, Resp) } ->
        { mostrar(resube(Rival, Resp)),
          append(Cantos, [Resp], CantosNuevos) },
        set_estado_envido(envido(no_cantado, CantosNuevos, none)),
        pedir_respuesta_envido(Cantor, Resp2),
        resolver_respuesta_envido(Rival, Cantor, CantosNuevos, Resp2),
        !
    ;
        { mostrar(mensaje("Respuesta de envido invalida. Intente de nuevo.")) },
        pedir_respuesta_envido(Rival, RespNueva),
        resolver_respuesta_envido(Cantor, Rival, Cantos, RespNueva)
    ).

% resuelve la respuesta a un canto
resolver_respuesta_canto(Cantor, Rival, Canto, Resp) -->
    ( { Resp == acepta } ->
        set_ronda_canto(Canto),
        { set_jugador_actual(Cantor),
          set_jugador_habilitado_canto(Rival)
        },
        { puntos_por_canto(Canto, P),
          mostrar(se_juega_a(P)) },
        !

    ; { Resp == rechaza } ->
        { puntos_por_rechazo(Canto, Pts) },
        sumar_puntos_a_jugador(Cantor, Pts),
        set_rechazo(Cantor),
        { limpiar_jugador_habilitado_canto },
        { mostrar(rechaza(Cantor, Rival, Pts)) },
        !

    ; { es_canto_envido(Resp) } ->
        state(S, S),
        {
            select(ronda(_, _, _, envido(_, Cantos, _), _, _), S, _),
            canto_envido_valido(Cantos, Resp),
            mostrar(canta(Rival, Resp)),
            append(Cantos, [Resp], CantosNuevos)
        },
        pedir_respuesta_envido(Cantor, Resp2),
        resolver_respuesta_envido(Rival, Cantor, CantosNuevos, Resp2),
        !

    ; { es_canto(Resp), canto_supera(Resp, Canto) } ->
        { mostrar(resube(Rival, Resp)) },
        step_estado_truco,
        pedir_respuesta(Cantor, Resp2),
        resolver_respuesta_canto(Rival, Cantor, Resp, Resp2),
        !
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
resolver_mano_cartas(_P_obsoleto, CartasSeleccionadas) -->
    state(S0, S),
    {
        mostrar(resolviendo_cartas),
        % Extraemos los jugadores actualizados del estado global
        select(jugadores(PActual), S0, S1),
        select(ronda(Resultados, CantoActual, Rech, EstadoEnvido, EstadoTruco, Pendiente), S1, S2),
        carta_alta(CartasSeleccionadas, Resultado),
        (
          Resultado = parda ->
            mostrar(mano_empatada),
            append([parda], Resultados, Resultados1)
        ;
          nth0(N, CartasSeleccionadas, Resultado),
          % Usamos PActual para encontrar al ganador
          nth0(N, PActual, JugadorGanador, _),
          JugadorGanador = jugador(Nombre, _, _),
          mostrar(gana_mano(Nombre)),
          append([JugadorGanador], Resultados, Resultados1)
        ),
        % Usamos PActual para eliminar la carta jugada de las manos
        maplist(eliminar_carta, PActual, CartasSeleccionadas, P1),
        ( Resultado = parda ->
            P2 = P1
        ;
            JugadorGanador = jugador(NombreGanador, _, _),
            reordenar_para_siguiente_mano(NombreGanador, P1, P2)
        ),
        limpiar_jugador_habilitado_canto,
        S = [ronda(Resultados1, CantoActual, Rech, EstadoEnvido, EstadoTruco, Pendiente), jugadores(P2)|S2],
        !
    }.
% deja primero al ganador de la mano siguiente
reordenar_para_siguiente_mano(NombreGanador, [jugador(NombreGanador, Mano1, Puntos1), jugador(OtroNombre, Mano2, Puntos2)], [jugador(NombreGanador, Mano1, Puntos1), jugador(OtroNombre, Mano2, Puntos2)]).
reordenar_para_siguiente_mano(NombreGanador, [jugador(OtroNombre, Mano2, Puntos2), jugador(NombreGanador, Mano1, Puntos1)], [jugador(NombreGanador, Mano1, Puntos1), jugador(OtroNombre, Mano2, Puntos2)]).

% deja primero al jugador que arranco la ronda anterior
reordenar_para_siguiente_ronda(NombreInicio, [jugador(NombreInicio, Mano1, Puntos1), jugador(OtroNombre, Mano2, Puntos2)], [jugador(NombreInicio, Mano1, Puntos1), jugador(OtroNombre, Mano2, Puntos2)]).
reordenar_para_siguiente_ronda(NombreInicio, [jugador(OtroNombre, Mano2, Puntos2), jugador(NombreInicio, Mano1, Puntos1)], [jugador(NombreInicio, Mano1, Puntos1), jugador(OtroNombre, Mano2, Puntos2)]).

% cierra la ronda y prepara la siguiente
finalizar_ronda -->
    state(S0, S),
    {
        select(ronda(Resultados, Canto, Rech, envido(_Estado, _Cantos, _PremioEnvido),_, Pendiente), S0, S1),
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
        reordenar_para_siguiente_ronda(Pendiente, P1, P2),
        estado_envido_inicial(EstadoEnvidoNuevo),
        estado_cantos_Truco(EstadoTruco),
        S = [ronda([], ninguno, none, EstadoEnvidoNuevo, EstadoTruco, Pendiente), jugadores(P2)|S2],
        !
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
        ),
        !
    }.

% true si alguien ya gano la partida
hay_ganador_partida_estado -->
    state(S, S),
    {
        select(jugadores([jugador(_, _, P1), jugador(_, _, P2)]), S, _),
        puntaje_objetivo(Objetivo),
        (P1 >= Objetivo ; P2 >= Objetivo)
    }.

% valida un canto de truco segun el estado actual y la habilitacion de turno
puede_cantar_estado(Jugador, Nuevo) -->
    state(S0, S0),
    {
        select(ronda(_, CantoActual, none, _, _, _), S0, _),
        es_canto(Nuevo),
        ( CantoActual == ninguno ->
            Nuevo == truco
        ;
            canto_supera(Nuevo, CantoActual),
            jugador_habilitado_canto(Jugador)
        )
    }.

% valida un canto de envido segun el estado actual
puede_cantar_envido_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda([], ninguno, none, envido(no_cantado, Cantos, none), _, _), S0, _),
        es_canto_envido(Nuevo),
        canto_envido_valido(Cantos, Nuevo)
    }.

% true si la ronda ya termino
ronda_terminada(_Resultados, rechazo(_)) :- !.
ronda_terminada(Resultados, none) :-
    length(Resultados, L),
    (L >= 3 ; alguien_gano_dos(Resultados)).

% true si un jugador gano dos manos
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
