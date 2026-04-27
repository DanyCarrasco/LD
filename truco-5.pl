:- use_module(library(random)).
:- use_module(library(clpfd)).

% =========================================================
% TRUCO EN PROLOG CON DCG + ESTADO EXPLICITO
% =========================================================
%
% La idea general del programa es modelar una partida de Truco
% usando una DCG como "maquina de estados".
%
% En una DCG normal se transforma una lista de tokens.
% Aca reutilizamos esa tecnica para transformar una lista
% que contiene UN UNICO elemento: el estado completo del juego.
%
% Ejemplo conceptual:
%
%   EstadoAntes  = [mazo(...), jugadores(...), ronda(...)]
%   EstadoDespues = [mazo(...), jugadores(...), ronda(...)]
%
% Entonces un no terminal DCG como:
%
%   algo -->
%       state(S0, S),
%       { ... construir S a partir de S0 ... }.
%
% significa:
%   "leo el estado actual S0 y lo reemplazo por el nuevo estado S".
%
% Cuando solo queremos LEER el estado, sin modificarlo, usamos:
%
%   state(S, S)
%
% o bien el atajo:
%
%   state(S)
%
% Eso fue justamente una de las fuentes del error que aparecia:
% si se usaba state(S0, S) solo para leer, entonces S quedaba libre
% y el estado se corrompia.

% =========================================================
% CARTAS Y JERARQUIA
% =========================================================

% carta(?Carta)
%
% Genera todas las cartas del mazo espanol usado en el juego.
% La representacion elegida es:
%
%   Palo-Numero
%
% por ejemplo:
%   espadas-as
%   oros-7
%   bastos-rey
%
% "Suite" aca funciona como nombre de variable para el palo.
carta(Suite-Number) :-
    member(Suite, [oros, espadas, bastos, copas]),
    member(Number, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, as]).

% valor_carta(+Carta, -Valor)
%
% Define la jerarquia del Truco.
% Cuanto mayor el numero, mas fuerte la carta.
%
% Notar que hay patrones generales como _-3 o _-rey:
% eso significa "cualquier palo con ese numero".
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

% =========================================================
% PRIMITIVAS DE ESTADO PARA LA DCG
% =========================================================

% state(-S)//
%
% Lee el estado actual sin modificarlo.
%
% Ejemplo de uso:
%   state(S)
%
% equivale a decir:
%   "el estado de entrada y el de salida son el mismo".
state(S), [S] --> [S].

% state(-S0, +S)//
%
% Lee el estado actual S0 y lo reemplaza por el nuevo estado S.
%
% Este es el predicado base para cualquier actualizacion.
state(S0, S), [S] --> [S0].

% jugadores(-JugadoresAntes, +JugadoresDespues)//
%
% Atajo para actualizar especificamente la estructura jugadores(...)
% dentro del estado.
%
% Esta regla:
%   1. toma el estado actual S0
%   2. extrae jugadores(P0)
%   3. lo reemplaza por jugadores(P)
%   4. deja el resto del estado intacto
jugadores(P0, P), [S] -->
    [S0],
    { select(jugadores(P0), S0, S1), S = [jugadores(P)|S1] }.

% =========================================================
% TRUCO / RETRUCO / VALE4
% =========================================================

% Puntos cuando un canto es aceptado.
puntos_por_canto(truco, 2).
puntos_por_canto(retruco, 3).
puntos_por_canto(vale4, 4).

% Puntos que gana quien canto cuando el rival rechaza.
puntos_por_rechazo(truco, 1).
puntos_por_rechazo(retruco, 2).
puntos_por_rechazo(vale4, 3).

% Catalogo de cantos validos.
es_canto(truco).
es_canto(retruco).
es_canto(vale4).

% Cada canto tiene un nivel para poder comparar subidas.
nivel_canto(ninguno, 0).
nivel_canto(truco, 1).
nivel_canto(retruco, 2).
nivel_canto(vale4, 3).

% canto_supera(+Nuevo, +Actual)
%
% Es cierto si Nuevo representa una subida valida sobre Actual.
canto_supera(Nuevo, Actual) :-
    nivel_canto(Nuevo, N1),
    nivel_canto(Actual, N2),
    N1 > N2.

% Relacion fija entre ambos jugadores.
rival(jugador1, jugador2).
rival(jugador2, jugador1).

% =========================================================
% ESTADO DE RONDA
% =========================================================
%
% La ronda se representa como:
%
%   ronda(Resultados, CantoActual, Rechazo)
%
% donde:
%   Resultados = lista de resultados de las manos jugadas
%   CantoActual = ninguno | truco | retruco | vale4
%   Rechazo = none | rechazo(jugadorX)

% asegurar_ronda(+S0, -S)
%
% Version logica normal: adapta estados viejos que por alguna razon
% tuvieran una ronda de 1 o 2 argumentos a la forma nueva de 3.
asegurar_ronda(S0, S) :-
    ( select(ronda(Resultados), S0, S1) ->
        S = [ronda(Resultados, ninguno, none)|S1]
    ; select(ronda(Resultados, C), S0, S1) ->
        S = [ronda(Resultados, C, none)|S1]
    ; S = S0
    ).

% Version DCG de asegurar_ronda/2.
asegurar_ronda -->
    state(S0, S),
    { asegurar_ronda(S0, S) }.

% set_ronda_canto(+Canto)//
%
% Cambia el canto actual de la ronda manteniendo resultados y rechazo.
set_ronda_canto(Canto) -->
    state(S0, S),
    { select(ronda(Resultados, _, R), S0, S1),
      S = [ronda(Resultados, Canto, R)|S1] }.

% set_rechazo(+Jugador)//
%
% Marca que la ronda termino por rechazo del rival.
set_rechazo(Jug) -->
    state(S0, S),
    { select(ronda(Resultados, C, _), S0, S1),
      S = [ronda(Resultados, C, rechazo(Jug))|S1] }.

% puede_cantar(+NuevoCanto)//
%
% Solo se puede cantar si:
%   1. la ronda no fue rechazada aun
%   2. el canto pedido es valido
%   3. el nuevo canto supera al actual
puede_cantar(Nuevo) -->
    state(S, S),
    { select(ronda(_, CantoActual, none), S, _),
      es_canto(Nuevo),
      canto_supera(Nuevo, CantoActual) }.

% =========================================================
% RESOLVER CANTO
% =========================================================

% resolver_canto_en_turno(+Jugador, +Canto)//
%
% Este no terminal procesa el momento en que un jugador decide cantar.
%
% Punto importante:
%   aca SOLO queremos LEER el estado antes de validar el canto,
%   por eso usamos state(S, S).
%
% Ese detalle corrige el bug original de stack overflow.
resolver_canto_en_turno(J, Canto) -->
    (   { es_canto(Canto) },
        puede_cantar(Canto)
    ->  { format("~w canta ~w~n", [J, Canto]),
          rival(J, R) },
        pedir_respuesta(R, Resp),
        resolver_respuesta_canto(J, R, Canto, Resp)
    ;   { writeln("Canto invalido o no permitido.") }
    ).

% pedir_respuesta(+Rival, -Respuesta)//
%
% Lee desde consola la respuesta del rival al canto.
pedir_respuesta(Rival, Resp) -->
    { format("~w responde (acepta/rechaza/truco/retruco/vale4):~n", [Rival]),
      read(Resp) }.

% resolver_respuesta_canto(+Cantor, +Rival, +Canto, +Respuesta)//
%
% Casos:
%   acepta  -> se actualiza el canto actual
%   rechaza -> se suman puntos al cantor y se marca rechazo
%   resube  -> el rival sube el canto y se vuelve a preguntar
%   invalida -> se toma como rechazo por defecto
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

% sumar_puntos_a_jugador(+NombreJugador, +Puntos)//
%
% Busca la lista de jugadores dentro del estado y suma puntos
% solamente al jugador cuyo nombre coincide.
sumar_puntos_a_jugador(Jug, Pts) -->
    state(S0, S),
    { select(jugadores(P0), S0, S1),
      maplist(sumar_si_corresponde(Jug, Pts), P0, P1),
      S = [jugadores(P1)|S1] }.

% sumar_si_corresponde(+Nombre, +Pts, +JugadorAntes, -JugadorDespues)
%
% Si el jugador coincide, suma puntos.
% Si no coincide, lo deja igual.
sumar_si_corresponde(Jug, Pts, jugador(Jug, Mano, Puntos0), jugador(Jug, Mano, Puntos)) :-
    Puntos is Puntos0 + Pts.
sumar_si_corresponde(Jug, _Pts, jugador(N, Mano, Puntos), jugador(N, Mano, Puntos)) :-
    N \= Jug.

% =========================================================
% RONDA Y MANOS
% =========================================================

% carta_alta(+Cartas, -Resultado)
%
% Compara las dos cartas jugadas en una mano.
% Resultado puede ser:
%   la carta ganadora
%   parda, si empatan
carta_alta([Carta1, Carta2], Resultado) :-
    valor_carta(Carta1, P1),
    valor_carta(Carta2, P2),
    (
        P1 #> P2 -> Resultado = Carta1
    ;   P2 #> P1 -> Resultado = Carta2
    ;   P1 #= P2 -> Resultado = parda
    ).

% ronda_terminada(+Resultados, +Rechazo)
%
% La ronda termina:
%   1. si alguien rechazo un canto
%   2. si ya se jugaron 3 manos
%   3. si alguien ya gano 2 manos
ronda_terminada(_Resultados, rechazo(_)) :- !.
ronda_terminada(Resultados, none) :-
    length(Resultados, L),
    (L >= 3 ; alguien_gano_dos(Resultados)).

% alguien_gano_dos(+Resultados)
%
% Recorre los resultados de las manos y verifica si algun jugador
% ya acumulo al menos dos victorias.
alguien_gano_dos(Resultados) :-
    member(jugador(Nombre, _, _), Resultados),
    contar_victorias(Nombre, Resultados, V),
    V >= 2,
    !.

% contar_victorias(+Nombre, +Resultados, -Total)
%
% Cuenta cuantas veces aparece como ganador un jugador dentro de la
% lista de resultados de manos.
contar_victorias(_, [], 0).
contar_victorias(Nombre, [jugador(Nombre, _, _) | Resto], Total) :-
    contar_victorias(Nombre, Resto, SubTotal),
    Total is SubTotal + 1.
contar_victorias(Nombre, [_ | Resto], Total) :-
    contar_victorias(Nombre, Resto, Total).

% obtener_ganador(+Jugadores, +Resultados, -GanadorFinal)
%
% Version corregida:
%   ya no devuelve jugadores anonimos inventados.
%   siempre devuelve uno de los jugadores reales de la mesa.
%
% Regla implementada:
%   si nadie rechazo, gana quien tenga mas victorias;
%   si hay empate en victorias, gana la mano el primero
%   (eso replica la logica que ya tenias con V1 >= V2).
obtener_ganador([P1, P2], Resultados, GanadorFinal) :-
    P1 = jugador(N1, _, _),
    P2 = jugador(N2, _, _),
    contar_victorias(N1, Resultados, V1),
    contar_victorias(N2, Resultados, V2),
    (V1 >= V2 -> GanadorFinal = P1 ; GanadorFinal = P2).

% =========================================================
% MAZO Y REPARTO
% =========================================================

% mezclar(+Lista, -ListaMezclada)
%
% Implementa una mezcla simple:
%   toma un elemento al azar
%   lo quita de la lista
%   repite recursivamente
mezclar([], []).
mezclar(Xs0, [Y|Ys]) :-
    length(Xs0, N),
    N1 is N - 1,
    random_between(0, N1, R),
    nth0(R, Xs0, Y, Xs),
    mezclar(Xs, Ys).

% mezclar_cartas//
%
% Reemplaza el mazo original por una version mezclada.
mezclar_cartas -->
    state(S0, S),
    {
        select(mazo(Cartas), S0, S1),
        mezclar(Cartas, CartasMezcladas),
        S = [mazo(CartasMezcladas)|S1]
    }.

% start//
%
% Construye el estado inicial con:
%   1. mazo completo
%   2. ronda vacia
start -->
    state(_, [mazo(Cartas), ronda([], ninguno, none)]),
    { setof(Carta, carta(Carta), Cartas) }.

% crear_jugadores(+Nombres)//
%
% A partir de una lista de nombres crea la estructura jugador/3:
%   jugador(Nombre, ManoInicialVacia, PuntajeInicial)
crear_jugadores(Nombres) -->
    state(S0, S),
    {
        same_length(Jugadores, Nombres),
        maplist([N, X]>>(X = jugador(N, [], 0)), Nombres, Jugadores),
        S = [jugadores(Jugadores)|S0]
    }.

% repartir_carta_a_cada_jugador//
%
% Toma la primera carta del mazo para cada jugador y la agrega a su mano.
repartir_carta_a_cada_jugador -->
    state(S0, S),
    {
        select(jugadores(Jugadores), S0, S1),
        select(mazo(Cartas), S1, S2),
        repartir_carta_a_cada_jugador(Jugadores, Jugadores1, Cartas, Cartas1),
        S = [jugadores(Jugadores1), mazo(Cartas1)|S2]
    }.

% Version auxiliar normal del reparto.
repartir_carta_a_cada_jugador([], [], Mazo, Mazo).
repartir_carta_a_cada_jugador([Jugador|Jugadores], [Jugador1|Jugadores1], [Carta|Mazo], Mazo1) :-
    Jugador = jugador(N, Mano, Puntos),
    Jugador1 = jugador(N, [Carta|Mano], Puntos),
    repartir_carta_a_cada_jugador(Jugadores, Jugadores1, Mazo, Mazo1).

% =========================================================
% JUEGO COMPLETO
% =========================================================

% fin_partida//
%
% Predicado DCG: lee el estado y verifica si alguno de los jugadores
% alcanzo el puntaje objetivo, imprimiendo al ganador si es asi.
fin_partida -->
    state(S, S),
    {
        select(jugadores([jugador(N1, _, P1), jugador(N2, _, P2)]), S, _),
        number(P1),
        number(P2),
        (
            P1 >= 2 ->
            format("El jugador ~w gano la partida~n", [N1])
        ;
            P2 >= 2 ->
            format("El jugador ~w gano la partida~n", [N2])
        )
    }.

% jugar_truco//
%
% Primera clausula:
%   si la partida ya termino, corta aca.
jugar_truco -->
    fin_partida,
    !.

% Segunda clausula:
%   si no termino la partida, prepara una nueva ronda,
%   reparte tres cartas a cada jugador, juega la mesa completa
%   y luego vuelve a llamar recursivamente a jugar_truco//0.
jugar_truco -->
    state(S0, S),
    {
        select(jugadores(P0), S0, S1),
        select(ronda(_, _, _), S1, S2),
        maplist(nueva_mesa, P0, P1),
        cambiar_mano(P1, P2),
        S = [ronda([], ninguno, none), jugadores(P2)|S2]
    },
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    jugar_mesa,
    jugar_truco.

% cambiar_mano(+JugadoresAntes, -JugadoresDespues)
%
% Con dos jugadores, cambiar la mano equivale a rotarlos.
cambiar_mano([J1, J2], [J2, J1]).

% nueva_mesa(+JugadorAntes, -JugadorDespues)
%
% Conserva nombre y puntaje, pero reinicia la mano.
nueva_mesa(jugador(N, _, P), jugador(N, [], P)).

% jugar_mesa//
%
% Juega manos sucesivas hasta que la ronda termina.
jugar_mesa -->
    jugar_mano,
    state(S, S),
    { select(ronda(Resultados, _, Rech), S, _) },
    ( { ronda_terminada(Resultados, Rech) } ->
        finalizar_ronda
    ;
        jugar_mesa
    ).

% jugar_mano//
%
% Una mano de Truco implica que ambos jugadores jueguen una carta,
% salvo que la ronda se termine antes por un rechazo.
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

% jugar_si_falta_carta(+Nombre, +Carta, +TerminoRonda, -CartaFinal)//
%
% Si el jugador solo canto y la ronda no termino, todavia le falta jugar
% la carta. Entonces se le vuelve a pedir el turno.
jugar_si_falta_carta(Nombre, Carta, Termino, CartaFinal) -->
    ( { Termino == no, Carta == sin_carta } ->
        turno_jugador(Nombre, CartaFinal, _)
    ;
        { CartaFinal = Carta }
    ).

% turno_jugador(+Nombre, -CartaJugada, -TerminaRonda)//
%
% Le ofrece al jugador dos acciones:
%   jugar  -> elige una carta
%   cantar -> hace un canto
%
% Si canta y el rival rechaza, TerminaRonda = si.
% Si canta y la ronda sigue, CartaJugada = sin_carta para que luego
% jugar_si_falta_carta//4 vuelva a pedir la carta.
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
        {
          format("~w canta (truco/retruco/vale4):~n", [Nombre]),
          read(Canto)
        },
        resolver_canto_en_turno(Nombre, Canto),
        state(S1, S1),
        {
          ( select(ronda(_, _, rechazo(_)), S1, _) ->
                TerminaRonda = si
          ;     TerminaRonda = no
          ),
          CartaJugada = sin_carta
        }
    ;
      {
        writeln("Accion invalida, se toma jugar."),
        Mano = [CartaJugada|_],
        TerminaRonda = no
      }
    ).

% resolver_mano_cartas(+JugadoresAntes, +CartasSeleccionadas)//
%
% Decide el ganador de la mano, registra el resultado en ronda(...)
% y quita de la mano de cada jugador la carta efectivamente jugada.
resolver_mano_cartas(P0, CartasSeleccionadas) -->
    state(S0, S),
    {
        select(jugadores(P0), S0, S1),
        select(ronda(Resultados, CantoActual, Rech), S1, S2),
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
        S = [ronda(Resultados1, CantoActual, Rech), jugadores(P1)|S2]
    }.

% finalizar_ronda//
%
% Si la ronda termino por rechazo, los puntos ya fueron otorgados
% en resolver_respuesta_canto//4, asi que no se suman de nuevo.
%
% Si no hubo rechazo:
%   1. se obtiene ganador de la ronda
%   2. se calcula cuantos puntos vale
%   3. se actualiza su puntaje
%   4. se resetea la ronda para la siguiente
finalizar_ronda -->
    state(S0, S),
    {
        select(ronda(Resultados, Canto, Rech), S0, S1),
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
        S = [ronda([], ninguno, none), jugadores(P1)|S2]
    }.

% eliminar_carta(+JugadorAntes, +CartaJugaga, -JugadorDespues)
%
% Quita de la mano la carta efectivamente usada en esa mano.
eliminar_carta(Jugador0, Carta, Jugador) :-
    Jugador0 = jugador(Nombre, Mano0, Puntos),
    select(Carta, Mano0, Mano1),
    Jugador = jugador(Nombre, Mano1, Puntos).

% truco//
%
% Regla principal en formato DCG.
truco -->
    start,
    mezclar_cartas,
    crear_jugadores([jugador1, jugador2]),
    jugar_truco.

% truco/0
%
% Punto de entrada "normal" para ejecutar la DCG completa.
% Se arranca con una lista de entrada de un elemento anonimo
% y se espera terminar tambien con una lista de un elemento,
% que es el estado final.
truco :-
    phrase(truco, [_], [_]).

% imprimir_lista(+Lista)
%
% Utilidad minima para mostrar resultados acumulados de manos.
imprimir_lista(Lista) :-
    writeln(Lista).
