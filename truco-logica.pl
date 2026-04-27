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

%Nuevo

% decision del jugador
%    (q) = quiero
%   (nq) = no quiero

%situacion del juego
%   t = truco
%   rt = retruco
%   v4 = vale 4

%   void = significa "vacio"

%creo una estructura para registrar las manos de cada ronda
%estructura de cada ronda:
% ronda(numero de la ronda, Lista de sus manos).
%ej
%ronda(1, Manos); estan en la ronda 1. Despues se explica que es una mano

%Estructura de la mano:
%mano(numero de la mano, jugadorMano (jugador que no repartio), situacion de la mano, decision del jugador, turno del siguiente jugador)
%ej:
%mano(1, jugadorA, rt, void, jugadorB)
%Estan en la mano 1, el jugadorA es el jugadorMano, cantaron retruco(jugadorA suponiendo), void = aun no hay respuesta al canto, le toca jugar al jugadorB

crear_rondas-->
    state(S0, S),
    {
    Ronda = ronda(1, []),
    S = [rondas(Ronda) | S0]
    }.

crear_mano-->
    state(S0, S),
    {
    % Obtener la lista de jugadores SIN modificarla
    member(jugadores(Jugadores), S0),
    Jugadores = [JugadorA, JugadorB],
    %Uso los nombres de los jugadores
    JugadorA = jugador(NombreA, _,_,_),
    JugadorB = jugador(NombreB,_,_,_),

     % Obtener la ronda actual
    select(rondas(Ronda), S0, S1), %Le quita las rondas a S0 y lo vuelve a guardar en S1
    Ronda = ronda(NumRonda, Manos),

    ManoNueva = mano(1, NombreB, void, void, NombreB),
    format("Repartio ~w en esta ronda~n",[NombreA]),
    format("Es 'mano': ~w~n",[NombreB]),

    % Agregar la nueva mano al principio (o al final)
    RondaNueva = ronda(NumRonda, [ManoNueva|Manos])

    % Reconstruir el estado
    S = [rondas(RondaNueva) | S1]
    }

%-----------------------------------------------------------------------------------------------------

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
        Puntos #>= 2,
        format("El jugador ~w gano la partida", [Nombre])
        }.

jugar_truco--> %Si nadie gano, continua por este estado.
    jugadores(P0,P1),
    { forall(member(jugador(_, _, Puntos,_), P0), Puntos #< 2) },
    {
        maplist(nueva_mesa,P0,P1)
    },
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
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

%nuevo
cantar_truco-->
    %actualiza estado.
    state(S0,S),
    {
    member(jugadores(Jugadores), S0),
    Jugadores = [JugadorA, JugadorB],
    JugadorA = jugador(NombreA, ManoA, _, _),
    JugadorB = jugador(NombreB, ManoB, _, _),

    % Obtener la mano de la ronda actual
    select(rondas(Ronda), S0, S1),
    Ronda = ronda(NumRonda, Manos)
    Manos = [Mano | RestoManos],
    Mano = mano(NumMano, JugadorMano, Situacion, Decision, JugadorTurno),

    (Situacion == void->
        %reconocer cual mano de jugadorTurno se debe mostrar
            (JugadorTurno == NombreA ->
            ManoMostrar = ManoA;
            ManoMostrar = ManoB),

        format("Mano del jugador ~w: ~w",[JugadorTurno, ManoMostrar])
        format("~w ¿Quiere cantar truco? s/n~n", [JugadorTurno]),
        read(Respuesta),
        member(Respuesta, [s, n]),
        (Respuesta == s->
            SituacionN = t;
            SituacionN = void)
    ),

    (JugadorTurno == NombreA ->
        JugadorTurnoN = NombreB;
        JugadorTurnoN = NombreA),

    ManoN = mano(NumMano, JugadorMano, SituacionN, Desicion, JugadorTurnoN),
    RondaN = ronda(NumRonda, [ManoN | Manos]),

    %Reconstruir estado
    S = [rondas(RondaN) | S1]
    }
    respuesta_truco.

respuesta_vale_4-->
    %actualiza estado.
    state(S0,S),
    {
    member(jugadores(Jugadores), S0),
    Jugadores = [JugadorA, JugadorB],
    JugadorA = jugador(NombreA, ManoA, _, _),
    JugadorB = jugador(NombreB, ManoB, _, _),

    % Obtener la mano de la ronda actual
    select(rondas(Ronda), S0, S1),
    Ronda = ronda(NumRonda, Manos)
    Manos = [Mano | RestoManos],
    Mano = mano(NumMano, JugadorMano, Situacion, Decision, JugadorTurno),

    (Situacion == v4->
        %reconocer cual mano de jugadorTurno se debe mostrar
            (JugadorTurno == NombreA ->
            ManoMostrar = ManoA;
            ManoMostrar = ManoB),

        format("Mano del jugador ~w: ~w",[JugadorTurno, ManoMostrar])
        format("~w ¿Acepta el vale 4 s/n~n", [JugadorTurno]),
        read(Respuesta),
        member(Respuesta, [s, n]),
        (Respuesta == s->
            DesicionN = (q);
            DesicionN = (nq))
    ),

    (JugadorTurno == NombreA ->
        JugadorTurnoN = NombreB;
        JugadorTurnoN = NombreA),

    ManoN = mano(NumMano, JugadorMano, Situacion, DecisionN, JugadorTurnoN),
    RondaN = ronda(NumRonda, [ManoN | Manos]),

    %Reconstruir estado
    S = [rondas(RondaN) | S1]
    }.

cantar_vale_4-->
    %actualiza estado.
    state(S0,S)
    {
    member(jugadores(Jugadores), S0),
    Jugadores = [JugadorA, JugadorB],
    JugadorA = jugador(NombreA, ManoA, _, _),
    JugadorB = jugador(NombreB, ManoB, _, _),

    % Obtener la mano de la ronda actual
    select(rondas(Ronda), S0, S1),
    Ronda = ronda(NumRonda, Manos)
    Manos = [Mano | RestoManos],
    Mano = mano(NumMano, JugadorMano, Situacion, Decision, JugadorTurno),

    (Situacion == rt->
        %reconocer cual mano de jugadorTurno se debe mostrar
            (JugadorTurno == NombreA ->
            ManoMostrar = ManoA;
            ManoMostrar = ManoB),

        format("Mano del jugador ~w: ~w",[JugadorTurno, ManoMostrar])
        format("~w ¿Quiere cantar vale 4? s/n~n", [JugadorTurno]),
        read(Respuesta),
        member(Respuesta, [s, n]),
        (Respuesta == s->
            SituacionN = v4;
            SituacionN = rt)
    ),

    (JugadorTurno == NombreA ->
        JugadorTurnoN = NombreB;
        JugadorTurnoN = NombreA),

    ManoN = mano(NumMano, JugadorMano, SituacionN, Desicion, JugadorTurnoN),
    RondaN = ronda(NumRonda, [ManoN | Manos]),

    %Reconstruir estado
    S = [rondas(RondaN) | S1]
    }
    respuesta_vale_4.

respuesta_retruco-->
    %actualiza estado.
    cantar_vale_4,
    state(S0,S),
    {
    member(jugadores(Jugadores), S0),
    Jugadores = [JugadorA, JugadorB],
    JugadorA = jugador(NombreA, ManoA, _, _),
    JugadorB = jugador(NombreB, ManoB, _, _),

    % Obtener la mano de la ronda actual
    select(rondas(Ronda), S0, S1),
    Ronda = ronda(NumRonda, Manos)
    Manos = [Mano | RestoManos],
    Mano = mano(NumMano, JugadorMano, Situacion, Decision, JugadorTurno),

    (Situacion == rt->
        %reconocer cual mano de jugadorTurno se debe mostrar
            (JugadorTurno == NombreA ->
            ManoMostrar = ManoA;
            ManoMostrar = ManoB),

        format("Mano del jugador ~w: ~w",[JugadorTurno, ManoMostrar])
        format("~w ¿Acepta el retruco s/n~n", [JugadorTurno]),
        read(Respuesta),
        member(Respuesta, [s, n]),
        (Respuesta == s->
            DesicionN = (q);
            DesicionN = (nq))
    ),

    (JugadorTurno == NombreA ->
        JugadorTurnoN = NombreB;
        JugadorTurnoN = NombreA),

    ManoN = mano(NumMano, JugadorMano, Situacion, DecisionN, JugadorTurnoN),
    RondaN = ronda(NumRonda, [ManoN | Manos]),

    %Reconstruir estado
    S = [rondas(RondaN) | S1]
    }.

cantar_retruco-->
    %actualiza estado.
    state(S0,S)
    {
    member(jugadores(Jugadores), S0),
    Jugadores = [JugadorA, JugadorB],
    JugadorA = jugador(NombreA, ManoA, _, _),
    JugadorB = jugador(NombreB, ManoB, _, _),

    % Obtener la mano de la ronda actual
    select(rondas(Ronda), S0, S1),
    Ronda = ronda(NumRonda, Manos)
    Manos = [Mano | RestoManos],
    Mano = mano(NumMano, JugadorMano, Situacion, Decision, JugadorTurno),

    (Situacion == t->
        %reconocer cual mano de jugadorTurno se debe mostrar
            (JugadorTurno == NombreA ->
            ManoMostrar = ManoA;
            ManoMostrar = ManoB),

        format("Mano del jugador ~w: ~w",[JugadorTurno, ManoMostrar])
        format("~w ¿Quiere cantar retruco? s/n~n", [JugadorTurno]),
        read(Respuesta),
        member(Respuesta, [s, n]),
        (Respuesta == s->
            SituacionN = rt;
            SituacionN = t)
    ),

    (JugadorTurno == NombreA ->
        JugadorTurnoN = NombreB;
        JugadorTurnoN = NombreA),

    ManoN = mano(NumMano, JugadorMano, SituacionN, Desicion, JugadorTurnoN),
    RondaN = ronda(NumRonda, [ManoN | Manos]),

    %Reconstruir estado
    S = [rondas(RondaN) | S1]
    }
    respuesta_retruco.


respuesta_truco-->
    %actualiza estado.
    cantar_retruco,
    state(S0,S),
    {
    member(jugadores(Jugadores), S0),
    Jugadores = [JugadorA, JugadorB],
    JugadorA = jugador(NombreA, ManoA, _, _),
    JugadorB = jugador(NombreB, ManoB, _, _),

    % Obtener la mano de la ronda actual
    select(rondas(Ronda), S0, S1),
    Ronda = ronda(NumRonda, Manos)
    Manos = [Mano | RestoManos],
    Mano = mano(NumMano, JugadorMano, Situacion, Decision, JugadorTurno),

    (Situacion == t->
        %reconocer cual mano de jugadorTurno se debe mostrar
            (JugadorTurno == NombreA ->
            ManoMostrar = ManoA;
            ManoMostrar = ManoB),

        format("Mano del jugador ~w: ~w",[JugadorTurno, ManoMostrar])
        format("~w ¿Acepta el truco s/n~n", [JugadorTurno]),
        read(Respuesta),
        member(Respuesta, [s, n]),
        (Respuesta == s->
            DesicionN = (q);
            DesicionN = (nq))
    ),

    (JugadorTurno == NombreA ->
        JugadorTurnoN = NombreB;
        JugadorTurnoN = NombreA),

    ManoN = mano(NumMano, JugadorMano, Situacion, DecisionN, JugadorTurnoN),
    RondaN = ronda(NumRonda, [ManoN | Manos]),

    %Reconstruir estado
    S = [rondas(RondaN) | S1]
    }.


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
        cantar_truco,
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
    %nuevo
    crear_rondas,
    crear_mano,
    %-----------
    jugar_truco.

truco:-phrase(truco,[_],[_]).
    
