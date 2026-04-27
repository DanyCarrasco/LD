:- use_module(library(random)).
:- use_module(library(clpfd)).


carta(Suite-Number) :-
    member(Suite, [oros, espadas, bastos, copas]),
    member(Number, [rey, caballo, sota,7, 6, 5, 4, 3, 2,as]).


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

state(S), [S] --> [S]. %Lee el estado
state(S0, S), [S] --> [S0]. %lee el estado S0 y lo remplaza por el estado S
jugadores(P0, P), [S] -->
    [S0],
    { select(jugadores(P0), S0, S1), S = [jugadores(P)|S1] }.


carta_alta([Carta1,Carta2],Alta):-
    valor_carta(Carta1, P1),
    valor_carta(Carta2, P2),
    (P1 #> P2 ->
    Alta = Carta1
    ;
    Alta = Carta2).

mezclar([], []).

mezclar(Xs0, [Y|Ys]) :- %la primera lista tiene los elementos sin mezclar, la segunda tiene los elementos mezclados
    length(Xs0, N),
    N1 is N - 1,
    random_between(0, N1, R),
    /**
    *segun la documentacion, en nth0, R es un indice, Xs0 es una lista,
    * Y es el elemento que se encuentra en el indice R 
    * y Xs es la lista Xs0-Y.
    * en este caso, como Y unifica con el Y de la cabecera del predicado, nth0 se utiliza para obtener Y de manera aleatoria
    * ya que R se definio de manera aleatoria
    * Luego Xs es pasado como argumento de vuelta a mezclar
    * de esta manera, se arma Ys de manera recursiva con los elementos de Xs0 pero mezclados
    */
    nth0(R, Xs0, Y, Xs),
    mezclar(Xs, Ys).

start -->
    state(_,[mazo(Cartas)]), %Se inicia un nuevo estado con unicamente el mazo de cartas
    {
        setof(Carta, carta(Carta),Cartas) %guarda en Cartas una lista ordenada de Carta que hacen verdadero al predicado carta
    }.


mezclar_cartas -->
    state(S0, S),
    {
	select(mazo(Cartas), S0, S1), 
    %select le quita el mazo(Cartas) a la lista S0 y devuelve la lista sin el mazo en S1
	mezclar(Cartas, CartasMezcladas),
	S = [mazo(CartasMezcladas)|S1]
    }. 
    %Le saca el mazo al estado viejo y le agrega el mazo de cartas mezcladas al estado nuevo.



crear_jugadores(Nombres)-->
    state(S0,S),
   {
	same_length(Jugadores, Nombres),%crea una lista Jugadores con la misma longitud que nombres

	%jugador(nombres,cartas en mano, puntos, manos ganadas)

    maplist([N,X]>>(X=jugador(N, [], 0,0)), Nombres, Jugadores),

    %Para cada N genera un X que sera X=jugador(Nombre,[],0,0). 
    %Y el X generado lo guarda en Jugadores.

	S = [jugadores(Jugadores)|S0]
    %Le agrega los jugadores al nuevo estado S0.

    }.

repartir_carta_a_cada_jugador-->
    state(S0,S),
    {
        
        select(jugadores(Jugadores),S0,S1), %Le quita jugadores a S0 y guarda la lista restante en S1.

        select(mazo(Cartas),S1,S2), %Le quita el mazo a S1 y guarda la lista restante en S2.

        %le doy una carta a cada jugador

        repartir_carta_a_cada_jugador(Jugadores,Jugadores1,Cartas,Cartas1),

        %guardo el estado
        S=[jugadores(Jugadores1),mazo(Cartas1)|S2] 
    }. %Crea nuevo estado con los jugadores con sus cartas y el nuevo mazo.



%caso base: no hay jugadores para darles una carta
repartir_carta_a_cada_jugador([],[],Mazo,Mazo).

%caso recursivo: a cada jugador le doy una carta

repartir_carta_a_cada_jugador([Jugador|Jugadores],[Jugador1|Jugadores1],[Carta|Mazo],Mazo1):-
    Jugador=jugador(N,Mano,Puntos,Mesa),
    Jugador1=jugador(N,[Carta|Mano],Puntos,Mesa),
    repartir_carta_a_cada_jugador(Jugadores,Jugadores1,Mazo,Mazo1).



jugar_truco-->
       jugadores(P,P), %No genera ningun nuevo estado, solo verifica si algún jugador gano.

        {   
        member(jugador(Nombre, _, Puntos,_), P), 
        Puntos >= 2,
        format("El jugador ~w gano la partida", [Nombre])
        }.

jugar_truco--> %Si nadie gano, continua por este estado.
    jugadores(P0,P1),
    { forall(member(jugador(_, _, Puntos,_), P0), Puntos<2) },
    {
        maplist(nueva_mesa,P0,P1)
    },
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    cantar_envido,
    jugar_mesa,
    jugar_truco.

nueva_mesa(jugador(N, _, P, _), jugador(N, [], P, 0)).

%cuando un jugador gana 2 manos, se le suma 1 punto.

jugar_mesa-->
   jugadores(P,P1), %P lista de jugadores antes. P1 Lista de jugadores despues.

    { 
    member(jugador(Nombre, Mano, Puntos, Manos), P),
    Manos = 2, 
    nth0(N, P, jugador(Nombre, Mano, Puntos, Manos), Resto),

    NuevoPuntos is Puntos + 1,
    JN = jugador(Nombre, Mano, NuevoPuntos, Manos), 

    nth0(N, P1, JN, Resto),
    format("El jugador ~w gano la mesa~n",[Nombre])
    }.

%mientras ningun jugador haya ganado 2 manos, se sigue jugando.

jugar_mesa-->
    jugadores(P,P),
    { member(jugador(_, _, _,Manos), P), Manos<2 },
    jugar_mano,
    jugar_mesa.


jugar_mano -->
    % Tomo del estado actual la lista de jugadores.
    % P0 = jugadores antes de jugar la mano.
    % P2 = jugadores después de jugar la mano.
    jugadores(P0, P2),

    elegir_carta(P0, CartasSeleccionadas), %Cartas que eligio cada jugador.

    {
        % Busca cuál es la carta mas alta entre las cartas seleccionadas.

        carta_alta(CartasSeleccionadas, CartaAlta),

        % A cada jugador le elimina la carta que jugó.
        %
        % maplist recorre estas listas al mismo tiempo:
        %
        % P0                 CartasSeleccionadas     P1
        % jugador ana   +    carta de ana       ->   ana sin esa carta
        % jugador juan  +    carta de juan      ->   juan sin esa carta
        %
        % P1 queda como la lista de jugadores con sus manos actualizadas.

        maplist(eliminar_carta, P0, CartasSeleccionadas, P1),

        % Busca en qué posición está la carta ganadora.
  

        nth0(N, CartasSeleccionadas, CartaAlta),

        % Usa ese mismo índice N para buscar al jugador ganador.
        % Si la carta ganadora estaba en la posición 1,
        % entonces ganó el jugador que está en la posición 1.
        % Resto queda como la lista P1 sin el jugador ganador.

        nth0(N, P1, JugadorGanador, Resto),

        % Desarma el jugador ganador en sus datos.
        JugadorGanador = jugador(Nombre, Mano, Puntos, Manos),

        % Muestra quién ganó la mano.
        format("El jugador ~w gano la mano~n", [Nombre]),

        % Le suma 1 a la cantidad de manos ganadas.
        NuevaManos is Manos + 1,

        % Crea el jugador ganador actualizado.
        JN = jugador(Nombre, Mano, Puntos, NuevaManos),

        % Reconstruye la lista final P2:
        % pone al jugador actualizado JN en la posición N,
        
        nth0(N, P2, JN, Resto)
    }.

%elimina la carta de la mano del jugador
eliminar_carta(Jugador0, Carta, Jugador) :-
    Jugador0 = jugador(Nombre, Mano0, Puntos,Manos),
    select(Carta, Mano0, Mano1),
    Jugador = jugador(Nombre, Mano1, Puntos,Manos).

%en esta cláusula cada jugador ingresa una carta por consola, y se obtenie las cartas seleccionadas por recursividad
%caso base: no hay jugadores para que selecciones sus cartas

elegir_carta([],[])-->[].
elegir_carta([Jugador|Jugadores],[Carta|CartasSeleccionadas])-->
    {
        Jugador=jugador(Nombre,Mano,_,_),
        format("~w :Elige una carta ~w~n",[Nombre,Mano]),
        read(Carta),
        member(Carta, Mano)
    },
    elegir_carta(Jugadores,CartasSeleccionadas).

truco-->
    start,
    mezclar_cartas,
    crear_jugadores([jugador1,jugador2]),
    jugar_truco.

truco:-phrase(truco,[_],[_]).

% ============================================================
% LOGICA DEL ENVIDO
% ============================================================
 
% ------------------------------------------------------------
% VALORES DE CARTA PARA EL ENVIDO
% valor_envido(+Carta, -Valor):
%   Figuras valen 0, as vale 1, numeros valen su numero.
% ------------------------------------------------------------
 
valor_envido(_-rey,    0).
valor_envido(_-caballo, 0).
valor_envido(_-sota,   0).
valor_envido(_-as,     1).
valor_envido(_-N,      N) :- integer(N).
 
% ------------------------------------------------------------
% PUNTOS DE UN PAR DE CARTAS
% puntos_par_envido(+C1, +C2, -Puntos):
%   Si son del mismo palo: 20 + valor1 + valor2.
%   Si son de distinto palo: 0.
% ------------------------------------------------------------
 
puntos_par_envido(Palo-N1, Palo-N2, Puntos) :-
    valor_envido(Palo-N1, V1),
    valor_envido(Palo-N2, V2),
    Puntos is 20 + V1 + V2.
 
puntos_par_envido(Palo1-_, Palo2-_, 0) :-
    Palo1 \= Palo2.
 
% ------------------------------------------------------------
% PUNTOS TOTALES DE ENVIDO DE UNA MANO
% puntos_envido(+[C1,C2,C3], -Puntos):
%   Calcula el maximo entre todos los pares y cartas individuales.
% ------------------------------------------------------------
 
puntos_envido([C1, C2, C3], Puntos) :-
    puntos_par_envido(C1, C2, P12),
    puntos_par_envido(C1, C3, P13),
    puntos_par_envido(C2, C3, P23),
    valor_envido(C1, V1),
    valor_envido(C2, V2),
    valor_envido(C3, V3),
    max_list([P12, P13, P23, V1, V2, V3], Puntos).
 
% ------------------------------------------------------------
% PUNTOS AL CANTAR QUIERO
% puntos_envido_cantado(+Cantos, -Puntos):
%   Cantos es una lista con la historia de cantos (el ultimo
%   canto esta en la cabeza). Puntos puede ser un numero o
%   el atomo 'falta' (indica falta envido).
% ------------------------------------------------------------
 
puntos_envido_cantado([e],       2).
puntos_envido_cantado([r],       3).
puntos_envido_cantado([f],       falta).
puntos_envido_cantado([e,e],     4).
puntos_envido_cantado([r,e],     5).
puntos_envido_cantado([f,e],     falta).
puntos_envido_cantado([r,e,e],   7).
puntos_envido_cantado([f,e,e],   falta).
puntos_envido_cantado([f,r,e],   falta).
puntos_envido_cantado([f,r,e,e], falta).
 
% ------------------------------------------------------------
% PUNTOS AL CANTAR NO QUIERO
% puntos_no_querido(+Cantos, -Puntos):
%   Puntos que gana quien canto (el que propuso) si el otro
%   no quiere.
% ------------------------------------------------------------
 
puntos_no_querido([e],       1).
puntos_no_querido([r],       1).
puntos_no_querido([f],       1).
puntos_no_querido([e,e],     2).
puntos_no_querido([r,e],     2).
puntos_no_querido([f,e],     2).
puntos_no_querido([r,e,e],   4).
puntos_no_querido([f,e,e],   4).
puntos_no_querido([f,r,e],   5).
puntos_no_querido([f,r,e,e], 7).
 
% ------------------------------------------------------------
% CANTOS VALIDOS SEGUN HISTORIAL
% puede_responder(+CantosAnteriores, +NuevoCanto):
%   Define que cantos son validos segun lo que ya se canto.
% ------------------------------------------------------------
 
% Primer canto: cualquiera de los tres.
puede_responder([], e).
puede_responder([], r).
puede_responder([], f).
 
% Despues de un solo envido: se puede responder envido, real o falta.
% Solo se permite e-e una vez: si ya hay mas cantos antes del e no se puede cantar e de nuevo.
puede_responder([e], e).
puede_responder([e|_], r).
puede_responder([e|_], f).
 
% Despues de real envido: solo se puede subir con falta.
puede_responder([r|_], f).
 
% Despues de falta envido: no se puede subir mas.
 
 
% ------------------------------------------------------------
% SUMAR PUNTOS AL GANADOR EN EL ESTADO
% sumar_puntos_envido(+NombreGanador, +Puntos, +Jugadores0, -Jugadores1):
%   Recorre la lista de jugadores y le suma Puntos al jugador
%   cuyo nombre es NombreGanador.
% ------------------------------------------------------------
 
sumar_puntos_envido(_, _, [], []).
sumar_puntos_envido(Nombre, Puntos,
        [jugador(Nombre, Mano, P, M)|Resto],
        [jugador(Nombre, Mano, P1, M)|Resto]) :-
    P1 is P + Puntos.
sumar_puntos_envido(Nombre, Puntos,
        [jugador(Otro, Mano, P, M)|Resto],
        [jugador(Otro, Mano, P, M)|Resto1]) :-
    Otro \= Nombre,
    sumar_puntos_envido(Nombre, Puntos, Resto, Resto1).
 
 
% ------------------------------------------------------------
% RESOLVER ENVIDO QUERIDO
% resolver_envido_querido(+J0, +J1, +Cantos, +Jugadores, -Jugadores1):
%   Compara los puntos de envido de ambos jugadores,
%   determina el ganador y le suma los puntos al estado.
%   Si los cantos dicen 'falta', el ganador gana los puntos
%   que le faltan al perdedor para llegar a 15.
% ------------------------------------------------------------
 
resolver_envido_querido(J0, J1, Cantos, Jugadores, Jugadores1) :-
    J0 = jugador(Nombre0, Mano0, PuntosActuales0, _),
    J1 = jugador(Nombre1, Mano1, PuntosActuales1, _),
    puntos_envido(Mano0, PE0),
    puntos_envido(Mano1, PE1),
    format("~w tiene ~w puntos de envido~n", [Nombre0, PE0]),
    format("~w tiene ~w puntos de envido~n", [Nombre1, PE1]),
    % Determina ganador: quien tiene mas puntos de envido.
    % En caso de empate gana J0 (mano).
    % PuntosPerdedor: puntos acumulados del perdedor (para calcular falta envido).
    ( PE0 >= PE1
    -> Ganador = Nombre0, PuntosPerdedor = PuntosActuales1
    ;  Ganador = Nombre1, PuntosPerdedor = PuntosActuales0
    ),
    puntos_envido_cantado(Cantos, PuntosBase),
    % Si es falta envido, el ganador recibe los puntos que le
    % faltan al perdedor para llegar a 15 (minimo 1 punto).
    ( PuntosBase = falta
    -> PuntosFinales is max(1, 15 - PuntosPerdedor),
       format("Falta envido! ~w gana ~w puntos~n", [Ganador, PuntosFinales])
    ;  PuntosFinales = PuntosBase,
       format("~w gana el envido (~w puntos)~n", [Ganador, PuntosFinales])
    ),
    sumar_puntos_envido(Ganador, PuntosFinales, Jugadores, Jugadores1).
 
 
% ------------------------------------------------------------
% CADENA DE ENVIDO (predicado auxiliar, no DCG)
% jugar_cadena_envido(
%       +JugadorQueResponde, +JugadorQuePropu,
%       +Cantos, +Jugadores, -Jugadores1):
%   Maneja el dialogo de cantos de envido entre dos jugadores.
%   JugadorQueResponde: el que tiene el turno ahora.
%   JugadorQuePropu:    el que hizo el ultimo canto.
%   Cantos:             historial de cantos (el mas reciente primero).
%   Jugadores:          lista completa de jugadores para actualizar puntos.
%   Jugadores1:         lista actualizada despues de resolver el envido.
% ------------------------------------------------------------
 
% Primer turno: le toca al Proponente hacer el primer canto.
% Solo puede cantar e/r/f (no puede querer ni no querer todavia).
jugar_cadena_envido(Respondedor, Proponente, [], Jugadores, Jugadores1) :-
    Proponente = jugador(NombreP, Mano, _, _),

    format("~w: Ingrese su canto: e=envido / r=real_envido / f=falta_envido~n", [NombreP]),
    read(Accion),
    % En este turno quien actua es el Proponente.
    procesar_envido(Accion, Proponente, Respondedor, [], Jugadores, Jugadores1).
 
% Turnos siguientes: le toca al Respondedor (puede subir, querer o no querer).
jugar_cadena_envido(Respondedor, Proponente, Cantos, Jugadores, Jugadores1) :-
    Cantos \= [],
    Respondedor = jugador(NombreR, Mano, _, _),
    format("Cantos hasta ahora: ~w~n", [Cantos]),
        format("Mano de ~w: ~w~n", [NombreR, Mano]),

    format("~w: e=envido / r=real_envido / f=falta_envido / qu=quiero / n=no_quiero~n", [NombreR]),
    read(Accion),
    procesar_envido(Accion, Respondedor, Proponente, Cantos, Jugadores, Jugadores1).
 
 
% ------------------------------------------------------------
% PROCESAR ACCION DE ENVIDO
% procesar_envido(+Accion, +Respondedor, +Proponente,
%                 +Cantos, +Jugadores, -Jugadores1):
%   Ejecuta la accion elegida por el jugador en su turno.
% ------------------------------------------------------------
 
% El jugador activo sube el canto (e/r/f) si es un canto valido.
% Jugador activo: quien tiene el turno en este momento.
% Despues de cantar, los roles se invierten para el siguiente turno.
procesar_envido(Canto, JugadorActivo, OtroJugador, Cantos, Jugadores, Jugadores1) :-
    member(Canto, [e, r, f]),
    puede_responder(Cantos, Canto),
    !,
    JugadorActivo = jugador(NombreActivo, _, _, _),
    format("~w canta: ~w~n", [NombreActivo, Canto]),
    Cantos1 = [Canto|Cantos],
    % Ahora le toca responder al OtroJugador.
    % OtroJugador pasa a ser el nuevo Respondedor,
    % JugadorActivo pasa a ser el nuevo Proponente (el que hizo el ultimo canto).
    jugar_cadena_envido(OtroJugador, JugadorActivo, Cantos1, Jugadores, Jugadores1).
 
% El jugador activo dice quiero: se comparan manos y se resuelve.
procesar_envido(qu, JugadorActivo, _OtroJugador, Cantos, Jugadores, Jugadores1) :-
    Cantos \= [],
    !,
    JugadorActivo = jugador(NombreActivo, _, _, _),
    format("~w dice: QUIERO~n", [NombreActivo]),
    Jugadores = [J0, J1],
    resolver_envido_querido(J0, J1, Cantos, Jugadores, Jugadores1).
 
% El jugador activo dice no quiero: gana el OtroJugador (quien hizo el ultimo canto).
procesar_envido(n, JugadorActivo, OtroJugador, Cantos, Jugadores, Jugadores1) :-
    Cantos \= [],
    !,
    JugadorActivo = jugador(NombreActivo, _, _, _),
    OtroJugador   = jugador(NombreOtro, _, _, _),
    puntos_no_querido(Cantos, Puntos),
    format("~w dice: NO QUIERO~n", [NombreActivo]),
    format("~w gana el envido (~w puntos)~n", [NombreOtro, Puntos]),
    sumar_puntos_envido(NombreOtro, Puntos, Jugadores, Jugadores1).
 
% Accion invalida: se repite el turno del mismo jugador activo.
% Si Cantos esta vacio es el primer turno (JugadorActivo es el proponente),
% por eso se llama con Cantos=[] y el JugadorActivo como proponente de nuevo.
% Si Cantos no esta vacio es un turno de respuesta normal.
procesar_envido(_, JugadorActivo, OtroJugador, [], Jugadores, Jugadores1) :-
    !,
    format("Accion invalida. Intente de nuevo.~n"),
    jugar_cadena_envido(OtroJugador, JugadorActivo, [], Jugadores, Jugadores1).
procesar_envido(_, JugadorActivo, OtroJugador, Cantos, Jugadores, Jugadores1) :-
    Cantos \= [],
    format("Accion invalida. Intente de nuevo.~n"),
    jugar_cadena_envido(JugadorActivo, OtroJugador, Cantos, Jugadores, Jugadores1).
 
 
% ------------------------------------------------------------
% CANTAR ENVIDO (DCG)
% cantar_envido: punto de entrada para el envido desde el flujo
%   principal del juego. Lee el estado, le pregunta al jugador1
%   si quiere cantar, y si acepta inicia la cadena de envido.
%   Actualiza los puntos en el estado al terminar.
% ------------------------------------------------------------
 
% cantar_envido: le pregunta primero a jugador1 si desea cantar.
% Si jugador1 no quiere, le pregunta a jugador2.
% El que decide cantar primero es el Proponente.
% El otro jugador es el Respondedor (debera querer, no querer o subir).
cantar_envido -->
    jugadores(P0, P1),
    {
        P0 = [J0, J1],
        J0 = jugador(Nombre0, Mano0, _, _),
        J1 = jugador(Nombre1, Mano1, _, _),
        format("Mano de ~w: ~w~n", [Nombre0, Mano0]),
        format("~w, deseas cantar envido? si/no~n", [Nombre0]),
        read(Respuesta0),
        ( Respuesta0 = si
        ->  jugar_cadena_envido(J1, J0, [], P0, P1)
        ;   format("Mano de ~w: ~w~n", [Nombre1, Mano1]),
            format("~w, deseas cantar envido? si/no~n", [Nombre1]),
            read(Respuesta1),
            ( Respuesta1 = si
            ->  jugar_cadena_envido(J0, J1, [], P0, P1)
            ;   format("No se canto envido.~n"),
                P1 = P0
            )
        )
    }.




    



