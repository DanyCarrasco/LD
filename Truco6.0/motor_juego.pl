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


% truco//
%
% Regla DCG principal de alto nivel. Encadena la inicializacion completa de
% la partida y luego entrega el control al bucle jugar_truco//0.
truco -->
    start,
    mezclar_cartas,
    crear_jugadores([jugador2, jugador1]),
    jugar_truco.


% start//
%
% Construye el estado inicial minimo para arrancar una partida.
%
% El estado resultante contiene:
% 1. un mazo completo generado con carta/1 y ordenado por setof/3;
% 2. una ronda vacia, sin canto, sin rechazo y con envido inicial.
start -->
    state(_, [mazo(Cartas), ronda([], ninguno, none, EstadoEnvido)]),
    {
        setof(Carta, carta(Carta), Cartas),
        estado_envido_inicial(EstadoEnvido)
    }.

% jugar_truco//
%
% Bucle principal de la partida expresado como DCG.
%
% Primera clausula:
% si fin_partida//0 tiene exito sobre el estado actual, la partida termina
% y la gramatica corta con ! para no seguir generando rondas nuevas.
jugar_truco -->
    fin_partida,
    !.


% jugar_truco//
%
% Segunda clausula del bucle principal. Se ejecuta cuando la partida aun no
% termino.
%
% Flujo:
% 1. toma los jugadores actuales;
% 2. reinicia sus manos con nueva_mesa/2;
% 3. cambia quien es mano con cambiar_mano/2;
% 4. reinicia la ronda y el envido;
% 5. reparte tres cartas a cada jugador;
% 6. juega la mesa completa;
% 7. vuelve recursivamente al inicio del ciclo.
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


% jugadores(-JugadoresAntes, +JugadoresDespues)//
%
% Atajo DCG para reemplazar especificamente el termino jugadores(...)
% dentro del estado global, conservando intacto el resto de los componentes.
%
% Es util cuando una transicion necesita modificar solo las manos o puntajes
% sin reconstruir manualmente mazo(...) o ronda(...).
jugadores(P0, P), [S] -->
    [S0],
    { select(jugadores(P0), S0, S1), S = [jugadores(P)|S1] }.


% crear_jugadores(+Nombres)//
%
% Recibe una lista de nombres y crea para cada uno una estructura
% jugador(Nombre, ManoVacia, PuntajeInicialCero). Luego inserta la lista
% completa dentro del estado.
crear_jugadores(Nombres) -->
    state(S0, S),
    {
        same_length(Jugadores, Nombres),
        maplist([N, X]>>(X = jugador(N, [], 0)), Nombres, Jugadores),
        S = [jugadores(Jugadores)|S0]
    }.






% jugar_mesa//
%
% Controla la secuencia de manos dentro de una ronda.
%
% Primero juega una mano. Despues revisa el estado resultante:
% 1. si hay_ganador_partida_estado//0 detecta fin de partida, se detiene;
% 2. si la ronda termino, llama a finalizar_ronda//0;
% 3. en otro caso, vuelve a jugar otra mano.
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


% jugar_mano//
%
% Ejecuta una mano individual de Truco.
%
% El flujo supone dos jugadores:
% 1. normaliza la estructura de ronda por compatibilidad;
% 2. identifica a los dos jugadores que deben actuar;
% 3. procesa el turno del primero;
% 4. si la ronda no termino, procesa el turno del segundo;
% 5. si ambos jugaron carta, resuelve el ganador de la mano.
%
% Un turno puede terminar sin carta jugada si el jugador solo canto algo; en
% ese caso entra en juego jugar_si_falta_carta//4.
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

% turno_jugador(+Nombre, -CartaJugada, -TerminaRonda)//
%
% Ejecuta la interaccion de un jugador durante su turno.
%
% El jugador puede:
% 1. jugar una carta de su mano;
% 2. cantar truco o envido;
% 3. ingresar una accion invalida, en cuyo caso el programa fuerza el juego
%    de la primera carta disponible.
%
% CartaJugada vale sin_carta cuando el turno se consumio en un canto y la
% ronda sigue abierta. TerminaRonda vale si si algun rechazo o un puntaje de
% envido cerraron inmediatamente la ronda o incluso la partida.
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


% jugar_si_falta_carta(+Nombre, +Carta, +TerminoRonda, -CartaFinal)//
%
% Maneja el caso en que un jugador uso su turno solo para cantar, sin jugar
% todavia una carta.
%
% Si la ronda sigue abierta y Carta = sin_carta, se vuelve a invocar
% turno_jugador//3 para que ese mismo jugador ahora juegue una carta.
% En cualquier otro caso, CartaFinal coincide con la carta ya obtenida.
jugar_si_falta_carta(Nombre, Carta, Termino, CartaFinal) -->
    ( { Termino == no, Carta == sin_carta } ->
        turno_jugador(Nombre, CartaFinal, _)
    ;
        { CartaFinal = Carta }
    ).



% resolver_canto_o_envido_en_turno(+Nombre, +Canto, -TerminaRonda)//
%
% Decide a que subsystema debe enviarse un canto ingresado por el jugador.
%
% Reglas:
% 1. si es un canto de envido y envido_habilitado//0 tiene exito, lo resuelve
%    por la rama de envido;
% 2. si es un canto de envido pero ya no corresponde, informa el error;
% 3. en cualquier otro caso, lo trata como canto de truco.
%
% Despues de resolver, informa mediante TerminaRonda si la ronda quedo cerrada
% por rechazo o si hay_ganador_partida_estado//0 detecta fin de partida por
% puntaje.
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




% resolver_envido_en_turno(+Jugador, +Canto)//
%
% Procesa el momento en que un jugador inicia o continua una secuencia de
% envido durante su turno.
%
% Flujo:
% 1. usa puede_cantar_envido_estado//1 para validar el canto leyendo el
%    estado actual sin modificarlo;
% 2. si el canto es valido, relee el estado para recuperar la secuencia de
%    cantos ya hecha y construir la nueva lista;
% 3. determina quien es el rival que debe responder;
% 4. pide la respuesta y delega la resolucion completa a
%    resolver_respuesta_envido//4.
%
% Si el canto es invalido, solo informa el error y no altera el estado.
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

% resolver_canto_en_turno(+Jugador, +Canto)//
%
% Procesa un canto del eje truco/retruco/vale4 realizado durante un turno.
%
% La validacion se hace con puede_cantar_estado//1, que inspecciona la ronda
% actual sin modificarla. Si el canto es legal, identifica al rival y abre
% la secuencia de respuesta. Si no lo es, informa el error y deja el estado
% sin cambios.
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


% resolver_respuesta_envido(+Cantor, +Rival, +Cantos, +Respuesta)//
%
% Resuelve la respuesta dada a una secuencia de envido.
%
% Casos:
% 1. quiero: calcula el ganador del envido y suma los puntos;
% 2. no_quiero: premia al cantor segun el rechazo;
% 3. resubida valida: invierte los roles y vuelve a pedir respuesta;
% 4. respuesta invalida: se toma como no_quiero por defecto.
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

% resolver_respuesta_canto(+Cantor, +Rival, +Canto, +Respuesta)//
%
% Resuelve la respuesta del rival a un canto de truco.
%
% Casos:
% 1. acepta: la ronda pasa a jugarse por el valor del canto;
% 2. rechaza: el cantor gana puntos por rechazo y la ronda se cierra;
% 3. resube: el rival hace una subida valida y se invierten los roles;
% 4. invalida: se interpreta como rechazo por defecto.
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


% premiar_envido_aceptado(+Cantos)//
%
% Evalua las manos de ambos jugadores, determina quien gana el envido y suma
% el puntaje correspondiente a la secuencia de cantos aceptada.
%
% En caso de empate, gana el primer jugador de la lista, porque la condicion
% usada es P1 >= P2.
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

% premiar_envido_rechazado(+Cantor, +Cantos)//
%
% Otorga al cantor los puntos que corresponden cuando el rival no quiere el
% envido. El valor depende de la secuencia de cantos acumulada hasta el
% momento del rechazo.
premiar_envido_rechazado(Cantor, Cantos) -->
    state(S, S),
    {
        select(jugadores([J1, J2]), S, _),
        puntos_envido_rechazado(Cantos, [J1, J2], Pts),
        format("~w gana ~w puntos por el envido no querido.~n", [Cantor, Pts])
    },
    sumar_puntos_a_jugador(Cantor, Pts).


% resolver_mano_cartas(+JugadoresAntes, +CartasSeleccionadas)//
%
% Resuelve una mano una vez que ya se conocen las dos cartas jugadas.
%
% Tareas realizadas:
% 1. compara las cartas con carta_alta/2;
% 2. registra en ronda(...) si la mano fue parda o quien la gano;
% 3. elimina de cada mano la carta efectivamente utilizada;
% 4. actualiza el estado con los nuevos jugadores y los nuevos resultados.
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

% finalizar_ronda//
%
% Cierra formalmente la ronda y deja preparado el estado para la siguiente.
%
% Si la ronda habia terminado por rechazo, no suma puntos adicionales porque
% ya fueron otorgados al momento de procesar la respuesta al canto.
%
% Si la ronda termino por juego normal:
% 1. obtiene el ganador con obtener_ganador/3;
% 2. calcula cuantos puntos vale la ronda segun el canto vigente;
% 3. actualiza el puntaje del ganador;
% 4. reinicia la estructura ronda(...) con estado_envido_inicial/1.
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


% fin_partida//
%
% Inspecciona el estado actual y detecta si alguno de los jugadores ya gano
% la partida. Si eso ocurre, imprime por consola el nombre del ganador.
%
% Es una DCG de solo lectura usada como chequeo previo dentro del bucle
% principal de jugar_truco//0.
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


% hay_ganador_partida_estado//
%
% Comprueba sobre el estado actual si alguno de los dos jugadores ya alcanzo
% o supero el puntaje objetivo. No informa quien fue: solo responde verdadero
% o falso para cortar o continuar el flujo del juego.
hay_ganador_partida_estado -->
    state(S, S),
    {
        select(jugadores([jugador(_, _, P1), jugador(_, _, P2)]), S, _),
        puntaje_objetivo(Objetivo),
        (P1 >= Objetivo ; P2 >= Objetivo)
    }.





% puede_cantar_estado(+NuevoCanto)//
%
% Verifica sobre el estado actual si un canto de truco es legal.
%
% Las condiciones son:
% 1. la ronda todavia no debe estar cerrada por rechazo;
% 2. el termino propuesto debe ser un canto reconocido;
% 3. debe superar al canto vigente y no repetirlo ni bajarlo.
%
% Como DCG de solo lectura, no modifica el estado: simplemente tiene exito
% o falla segun el contenido actual de ronda(...).
puede_cantar_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda(_, CantoActual, none, _), S0, _),
        es_canto(Nuevo),
        canto_supera(Nuevo, CantoActual)
    }.

% puede_cantar_envido_estado(+NuevoCanto)//
%
% Determina si un nuevo canto de envido es valido segun la situacion actual.
%
% Solo habilita el envido cuando:
% 1. aun no se jugo ninguna mano, es decir, Resultados = [];
% 2. la ronda no fue cerrada por rechazo;
% 3. el estado del envido sigue en no_cantado;
% 4. la nueva propuesta encaja en la secuencia de cantos ya realizada.
puede_cantar_envido_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda([], _, none, envido(no_cantado, Cantos, none)), S0, _),
        es_canto_envido(Nuevo),
        canto_envido_valido(Cantos, Nuevo)
    }.


% ronda_terminada(+Resultados, +Rechazo)
%
% Determina si la ronda debe considerarse cerrada.
%
% La ronda termina en cualquiera de estos casos:
% 1. hubo rechazo de un canto;
% 2. ya se jugaron tres manos;
% 3. alguno de los jugadores acumulo dos victorias.
ronda_terminada(_Resultados, rechazo(_)) :- !.
ronda_terminada(Resultados, none) :-
    length(Resultados, L),
    (L >= 3 ; alguien_gano_dos(Resultados)).

% alguien_gano_dos(+Resultados)
%
% Revisa la lista de resultados de manos y verifica si algun jugador aparece
% como ganador al menos dos veces. Usa contar_victorias/3 para el conteo.
alguien_gano_dos(Resultados) :-
    member(jugador(Nombre, _, _), Resultados),
    contar_victorias(Nombre, Resultados, V),
    V >= 2,
    !.

% contar_victorias(+Nombre, +Resultados, -Total)
%
% Cuenta cuantas manos gano un jugador dentro de la lista Resultados.
% Solo suma aquellos elementos que sean exactamente jugador(Nombre, _, _);
% cualquier otro termino, como parda, se ignora.
contar_victorias(_, [], 0).
contar_victorias(Nombre, [jugador(Nombre, _, _) | Resto], Total) :-
    contar_victorias(Nombre, Resto, SubTotal),
    Total is SubTotal + 1.
contar_victorias(Nombre, [_ | Resto], Total) :-
    contar_victorias(Nombre, Resto, Total).

% obtener_ganador(+Jugadores, +Resultados, -Ganador)
%
% Decide quien gana la ronda una vez terminadas las manos.
%
% Toma siempre uno de los jugadores reales presentes en la mesa. Cuenta las
% victorias de cada uno y devuelve al que tenga mas. Si hay empate, gana el
% primer jugador de la lista por la condicion V1 >= V2.
obtener_ganador([P1, P2], Resultados, GanadorFinal) :-
    P1 = jugador(N1, _, _),
    P2 = jugador(N2, _, _),
    contar_victorias(N1, Resultados, V1),
    contar_victorias(N2, Resultados, V2),
    (V1 >= V2 -> GanadorFinal = P1 ; GanadorFinal = P2).


% nueva_mesa(+JugadorAntes, -JugadorDespues)
%
% Construye la version de un jugador lista para una ronda nueva:
% conserva nombre y puntaje acumulado, pero vacia la mano.
nueva_mesa(jugador(N, _, P), jugador(N, [], P)).


% cambiar_mano(+JugadoresAntes, -JugadoresDespues)
%
% Alterna quien empieza la ronda. Como este programa modela solo dos
% jugadores, cambiar la mano consiste simplemente en rotar la lista.
cambiar_mano([J1, J2], [J2, J1]).