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

mezclar_cartas -->
    state(S0, S),
    {
	select(mazo(Cartas), S0, S1),
	mezclar(Cartas, CartasMezcladas),
	S = [mazo(CartasMezcladas)|S1]
    }.

start -->
    state(_,[mazo(Cartas)]), %Se inicia un nuevo estado con unicamente el mazo de cartas
    {
        setof(Carta, carta(Carta),Cartas) %guarda en Cartas una lista ordenada de Carta que hacen verdadero al predicado carta
    }.

crear_jugadores(Nombres)-->
    state(S0,S),
   {
	same_length(Jugadores, Nombres),%crea una lista Jugadores con la misma longitud que nombres
	%jugador(nombres,cartas en mano, puntos, manos ganadas)
    maplist([N,X]>>(X=jugador(N, [], 0,0)), Nombres, Jugadores),
	S = [jugadores(Jugadores)|S0]
    },
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador.  

repartir_carta_a_cada_jugador-->
    state(S0,S),
    {
        %tomo los jugadores y el mazo del estado
        select(jugadores(Jugadores),S0,S1),
        select(mazo(Cartas),S1,S2),
        %le doy una carta a cada jugador
        repartir_carta_a_cada_jugador(Jugadores,Jugadores1,Cartas,Cartas1),
        %guardo el estado
        S=[jugadores(Jugadores1),mazo(Cartas1)|S2]
    }.

%caso base: no hay jugadores para darles una carta
repartir_carta_a_cada_jugador([],[],Mazo,Mazo).

%caso recursivo: a cada jugador le doy una carta
repartir_carta_a_cada_jugador([Jugador|Jugadores],[Jugador1|Jugadores1],[Carta|Mazo],Mazo1):-
    Jugador=jugador(N,Mano,Puntos,Mesa),
    Jugador1=jugador(N,[Carta|Mano],Puntos,Mesa),
    repartir_carta_a_cada_jugador(Jugadores,Jugadores1,Mazo,Mazo1).

jugar_truco-->
       jugadores(P,P),
        {   
        member(jugador(Nombre, _, Puntos,_), P), 
        Puntos >= 2,
        format("El jugador ~w gano la partida", [Nombre])
        }.

jugar_truco-->
    jugadores(P0,P1),
    { forall(member(jugador(_, _, Puntos,_), P0), Puntos<2) },
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
   jugadores(P,P1),
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


jugar_mano-->
    jugadores(P0,P2), %selecciono a los jugadores y dejo una variable para unificar luego
    elegir_carta(P0,CartasSeleccionadas),
    {
    carta_alta(CartasSeleccionadas,CartaAlta),
    %lo que hace maplist es aplicar el predicado (1er arg) sobre cada elemento perteneciente a las listas (demas arg)
    maplist(eliminar_carta,P0,CartasSeleccionadas,P1),
    %busco al jugador que gano la mano
    nth0(N, CartasSeleccionadas, CartaAlta), %2do y 3er arg ya estan instanciados, asi que se utiliza nth0 para obtener el indice en el cual aparece la carta dentro de la lista
	nth0(N, P1, JugadorGanador,Resto), %la carta ganadora y el jugador ganador van a estan en el mismo indice, se obtiene el jugador ganador de la lista P1, Resto = P1-jugadorGanador
    JugadorGanador = jugador(Nombre, Mano, Puntos, Manos),
    format("El jugador ~w gano la mano~n",[Nombre]),
    NuevaManos is Manos + 1,
    JN = jugador(Nombre, Mano, Puntos, NuevaManos),
    nth0(N, P2, JN, Resto)%como N,JN y Resto ya estan instanciados, P2 = Resto+JN, y JN va a estar en el indice N
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
    