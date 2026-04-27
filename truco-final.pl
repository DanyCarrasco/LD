:- use_module(library(random)).
:- use_module(library(clpfd)).

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
%
% carta valida del mazo
carta(Suite-Number) :-
    member(Suite, [oros, espadas, bastos, copas]),
    member(Number, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, as]).

valor_carta(espadas-as, 14).
valor_carta(bastos-as, 13).
valor_carta(espadas-7, 12).
valor_carta(oros-7, 11).
valor_carta(_-3, 10).
valor_carta(_-2, 9).
valor_carta(copas-as, 8).
valor_carta(oros-as, 8).
valor_carta(_-rey, 7).
valor_carta(_-caballo, 6).
valor_carta(_-sota, 5).
valor_carta(copas-7, 4).
valor_carta(bastos-7, 4).
valor_carta(_-6, 3).
valor_carta(_-5, 2).
valor_carta(_-4, 1).

es_canto_envido(envido).
es_canto_envido(real_envido).
es_canto_envido(falta_envido).

puntos_por_canto(truco, 2).
puntos_por_canto(retruco, 3).
puntos_por_canto(vale4, 4).

puntos_por_rechazo(truco, 1).
puntos_por_rechazo(retruco, 2).
puntos_por_rechazo(vale4, 3).


es_canto(truco).
es_canto(retruco).
es_canto(vale4).

nivel_canto(ninguno, 0).
nivel_canto(truco, 1).
nivel_canto(retruco, 2).
nivel_canto(vale4, 3).

valor_envido_numero(rey, 0).
valor_envido_numero(caballo, 0).
valor_envido_numero(sota, 0).
valor_envido_numero(as, 1).
valor_envido_numero(2, 2).
valor_envido_numero(3, 3).
valor_envido_numero(4, 4).
valor_envido_numero(5, 5).
valor_envido_numero(6, 6).
valor_envido_numero(7, 7).

% lee el estado sin cambiarlo
state(S), [S] --> [S].

% reemplaza el estado actual
state(S0, S), [S] --> [S0].

% cambia solo la parte de jugadores
jugadores(P0, P), [S] -->
    [S0],
    { select(jugadores(P0), S0, S1), S = [jugadores(P)|S1] }.



% true si nuevo tiene mas nivel que actual
canto_supera(Nuevo, Actual) :-
    nivel_canto(Nuevo, N1),
    nivel_canto(Actual, N2),
    N1 > N2.

% siguiente canto permitido
canto_siguiente_valido(ninguno, truco).
canto_siguiente_valido(truco, retruco).
canto_siguiente_valido(retruco, vale4).

% rival de cada jugador
rival(jugador1, jugador2).
rival(jugador2, jugador1).

% puntos para ganar la partida
puntaje_objetivo(15).

% estado inicial del envido
estado_envido_inicial(envido(no_cantado, [], none)).

% normaliza la estructura de ronda
asegurar_ronda -->
    state(S0, S),
    {
        ( select(ronda(Resultados), S0, S1) ->
            estado_envido_inicial(EstadoEnvido),
            S = [ronda(Resultados, ninguno, none, EstadoEnvido)|S1]
        ; select(ronda(Resultados, C), S0, S1) ->
            estado_envido_inicial(EstadoEnvido),
            S = [ronda(Resultados, C, none, EstadoEnvido)|S1]
        ; select(ronda(Resultados, C, R), S0, S1) ->
            estado_envido_inicial(EstadoEnvido),
            S = [ronda(Resultados, C, R, EstadoEnvido)|S1]
        ; S = S0
        )
    }.

% cambia el canto actual de la ronda
set_ronda_canto(Canto) -->
    state(S0, S),
    { select(ronda(Resultados, _, R, E), S0, S1),
      S = [ronda(Resultados, Canto, R, E)|S1] }.

% marca rechazo en la ronda
set_rechazo(Jug) -->
    state(S0, S),
    { select(ronda(Resultados, C, _, E), S0, S1),
      S = [ronda(Resultados, C, rechazo(Jug), E)|S1] }.

% cambia el estado del envido
set_estado_envido(EstadoEnvido) -->
    state(S0, S),
    { select(ronda(Resultados, C, R, _), S0, S1),
      S = [ronda(Resultados, C, R, EstadoEnvido)|S1] }.

% valida un canto de truco segun el estado actual
puede_cantar_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda(_, CantoActual, none, _), S0, _),
        es_canto(Nuevo),
        canto_siguiente_valido(CantoActual, Nuevo)
    }.


% valida un canto de envido segun el estado actual
puede_cantar_envido_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda([], _, none, envido(no_cantado, Cantos, none)), S0, _),
        es_canto_envido(Nuevo),
        canto_envido_valido(Cantos, Nuevo)
    }.

% true si el envido todavia puede jugarse
envido_habilitado -->
    state(S0, S0),
    {
        select(ronda([], _, none, envido(no_cantado, _, none)), S0, _)
    }.

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

% mejor valor de envido de una mano
valor_envido_mano(Mano, Valor) :-
    findall(Puntos, puntos_par_mismo_palo(Mano, Puntos), Pares),
    ( Pares \= [] ->
        max_list(Pares, Valor)
    ; findall(V,
              (member(_Palo-Numero, Mano), valor_envido_numero(Numero, V)),
              Valores),
      max_list(Valores, Valor)
    ).

% puntos de un par del mismo palo
puntos_par_mismo_palo(Mano, Puntos) :-
    select(Palo-N1, Mano, Resto),
    member(Palo-N2, Resto),
    valor_envido_numero(N1, V1),
    valor_envido_numero(N2, V2),
    Puntos is 20 + V1 + V2.

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

% pide respuesta al envido
pedir_respuesta_envido(Rival, Resp) -->
    state(S, S),
    {
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format("~w responde. Mano: ~w~n", [Rival, Mano]),
        format("Respuesta (quiero/no_quiero/envido/real_envido/falta_envido):~n", []),
        read(Resp)
    }.

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

% pide respuesta a un canto de truco
pedir_respuesta(Rival, Resp) -->
    state(S, S),
    {
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format("~w responde. Mano: ~w~n", [Rival, Mano]),
        format("Respuesta (acepta/rechaza/truco/retruco/vale4):~n", []),
        read(Resp)
    }.

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

% suma puntos a un jugador
sumar_puntos_a_jugador(Jug, Pts) -->
    state(S0, S),
    { select(jugadores(P0), S0, S1),
      maplist(sumar_si_corresponde(Jug, Pts), P0, P1),
      S = [jugadores(P1)|S1] }.

% auxiliar para sumar puntos
sumar_si_corresponde(Jug, Pts, jugador(Jug, Mano, Puntos0), jugador(Jug, Mano, Puntos)) :-
    Puntos is Puntos0 + Pts.
sumar_si_corresponde(Jug, _Pts, jugador(N, Mano, Puntos), jugador(N, Mano, Puntos)) :-
    N \= Jug.

% true si alguien ya gano la partida
hay_ganador_partida_estado -->
    state(S, S),
    {
        select(jugadores([jugador(_, _, P1), jugador(_, _, P2)]), S, _),
        puntaje_objetivo(Objetivo),
        (P1 >= Objetivo ; P2 >= Objetivo)
    }.

% compara dos cartas jugadas
carta_alta([Carta1, Carta2], Resultado) :-
    valor_carta(Carta1, P1),
    valor_carta(Carta2, P2),
    (
        P1 #> P2 -> Resultado = Carta1
    ;   P2 #> P1 -> Resultado = Carta2
    ;   P1 #= P2 -> Resultado = parda
    ).

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

% mezcla una lista
mezclar([], []).
mezclar(Xs0, [Y|Ys]) :-
    length(Xs0, N),
    N1 is N - 1,
    random_between(0, N1, R),
    nth0(R, Xs0, Y, Xs),
    mezclar(Xs, Ys).

% mezcla el mazo del estado
mezclar_cartas -->
    state(S0, S),
    {
        select(mazo(Cartas), S0, S1),
        mezclar(Cartas, CartasMezcladas),
        S = [mazo(CartasMezcladas)|S1]
    }.

% crea el estado inicial
start -->
    state(_, [mazo(Cartas), ronda([], ninguno, none, EstadoEnvido)]),
    {
        setof(Carta, carta(Carta), Cartas),
        estado_envido_inicial(EstadoEnvido)
    }.

% crea los jugadores iniciales
crear_jugadores(Nombres) -->
    state(S0, S),
    {
        same_length(Jugadores, Nombres),
        maplist([N, X]>>(X = jugador(N, [], 0)), Nombres, Jugadores),
        S = [jugadores(Jugadores)|S0]
    }.

% reparte una carta a cada jugador
repartir_carta_a_cada_jugador -->
    state(S0, S),
    {
        select(jugadores(Jugadores), S0, S1),
        select(mazo(Cartas), S1, S2),
        repartir_carta_a_cada_jugador(Jugadores, Jugadores1, Cartas, Cartas1),
        S = [jugadores(Jugadores1), mazo(Cartas1)|S2]
    }.

% auxiliar del reparto
repartir_carta_a_cada_jugador([], [], Mazo, Mazo).
repartir_carta_a_cada_jugador([Jugador|Jugadores], [Jugador1|Jugadores1], [Carta|Mazo], Mazo1) :-
    Jugador = jugador(N, Mano, Puntos),
    Jugador1 = jugador(N, [Carta|Mano], Puntos),
    repartir_carta_a_cada_jugador(Jugadores, Jugadores1, Mazo, Mazo1).

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
        estado_envido_inicial(EstadoEnvido),
        S = [ronda([], ninguno, none, EstadoEnvido), jugadores(P2)|S2]
    },
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    jugar_mesa,
    jugar_truco.

% cambia quien es mano
cambiar_mano([J1, J2], [J2, J1]).

% reinicia la mano del jugador
nueva_mesa(jugador(N, _, P), jugador(N, [], P)).

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

% si solo canto, vuelve a pedir carta
jugar_si_falta_carta(Nombre, Carta, Termino, CartaFinal) -->
    ( { Termino == no, Carta == sin_carta } ->
        turno_jugador(Nombre, CartaFinal, _)
    ;
        { CartaFinal = Carta }
    ).

% turno de un jugador
turno_jugador(Nombre, CartaJugada, TerminaRonda) -->
    state(S0, S0),
    {
        member(jugadores(P0), S0),
        member(jugador(Nombre, Mano, _), P0),
        format("~w turno. Mano: ~w~n", [Nombre, Mano]),
        format("Elegi accion (jugar/cantar):~n", [])
    },
    {
        read(Accion)
    },
    (
      { Accion == jugar } ->
        {
          format("~w: elegi carta:~n", [Nombre]),
          read(Carta),
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
        mensaje_cantos_disponibles(Nombre),
        {
          read(Canto)
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

% muestra los cantos posibles
mensaje_cantos_disponibles(Nombre) -->
    ( envido_habilitado ->
        { format("~w canta (truco/retruco/vale4/envido/real_envido/falta_envido):~n", [Nombre]) }
    ;
        { format("~w canta (truco/retruco/vale4):~n", [Nombre]) }
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

% saca una carta de la mano del jugador
eliminar_carta(Jugador0, Carta, Jugador) :-
    Jugador0 = jugador(Nombre, Mano0, Puntos),
    select(Carta, Mano0, Mano1),
    Jugador = jugador(Nombre, Mano1, Puntos).

% inicia la partida completa
truco -->
    start,
    mezclar_cartas,
    crear_jugadores([jugador1, jugador2]),
    jugar_truco.

% punto de entrada normal
truco :-
    phrase(truco, [_], [_]).

% imprime una lista
imprimir_lista(Lista) :-
    writeln(Lista).
