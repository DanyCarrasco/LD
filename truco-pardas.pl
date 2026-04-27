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

%retorna si una carta es mas alta que otra o si son del mismo valor
carta_alta([Carta1,Carta2],Resultado):-
    valor_carta(Carta1, P1),
    valor_carta(Carta2, P2),
    (
        P1 #> P2 ->
            Resultado = Carta1
    ;   P2 #> P1 ->
            Resultado = Carta2
    ;   P1 #= P2 ->
            Resultado = parda
    ).

%se verifica si alguien se va al mazo
alguien_va_al_mazo([rendirse|_]).
alguien_va_al_mazo([_|R]) :-
    alguien_va_al_mazo(R).
%si alguien se fue al mazo, el jugador que no se fue al mazo va a ser el ganador de la ronda
ganador_por_irse_al_mazo([_, J2],[al_mazo, _],J2).
ganador_por_irse_al_mazo([J1, _],[_, al_mazo],J1).

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
    state(_,[mazo(Cartas),ronda([])]), %Se inicia un nuevo estado con unicamente el mazo de cartas
    {
        setof(Carta, carta(Carta),Cartas) %guarda en Cartas una lista ordenada de Carta que hacen verdadero al predicado carta
    }.

crear_jugadores(Nombres)-->
    state(S0,S),
   {
	same_length(Jugadores, Nombres),%crea una lista Jugadores con la misma longitud que nombres
	%jugador(nombres,cartas en mano, puntos, manos ganadas)
    maplist([N,X]>>(X=jugador(N, [], 0)), Nombres, Jugadores),
	S = [jugadores(Jugadores)|S0]
    }.  

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
    Jugador=jugador(N,Mano,Puntos),
    Jugador1=jugador(N,[Carta|Mano],Puntos),
    repartir_carta_a_cada_jugador(Jugadores,Jugadores1,Mazo,Mazo1).

jugar_truco-->
       jugadores(P,P),
        {   
        member(jugador(Nombre, _, Puntos), P), 
        Puntos >= 2,
        format("El jugador ~w gano la partida", [Nombre])
        }.

jugar_truco-->
    state(S0,S),
    { 
        select(jugadores(P0),S0,S1),
       select(ronda(_),S1,S2),
        maplist(nueva_mesa,P0,P1),
        cambiar_mano(P1,P2),
        S=[ronda([]),jugadores(P2)|S2]
    },
    %doy vuelta los jugadores, el primero en la lista es la mano
   
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    jugar_mesa,
    jugar_truco.

cambiar_mano([J1,J2],[J2,J1]).
nueva_mesa(jugador(N, _, P), jugador(N, [], P)).


%todos los posibles casos de rondas jugadas
obtener_ganador(_,[parda,jugador(_,_,_)|_],jugador(_,_,_)).  
obtener_ganador(_,[jugador(_,_,_),parda|_],jugador(_,_,_)). 
obtener_ganador(_,[parda,parda,jugador(_,_,_)],jugador(_,_,_)).   
obtener_ganador([jugador(_,_,_),_],[parda,parda,parda],jugador(_,_,_)).  
obtener_ganador([P1, P2], Resultados, GanadorFinal) :-
    P1 = jugador(N1, _, _),
    P2 = jugador(N2, _, _),
    contar_victorias(N1, Resultados, V1),
    contar_victorias(N2, Resultados, V2),
    (V1 >= V2 -> GanadorFinal = P1 ; GanadorFinal = P2).


contar_victorias(_, [], 0).

% Caso 1: El primer elemento de la lista es un jugador y su nombre coincide.
contar_victorias(Nombre, [jugador(Nombre, _, _) | Resto], Total) :-
    % Si entra aquí, forzamos a que no intente la regla de abajo.
    contar_victorias(Nombre, Resto, SubTotal),
    Total is SubTotal + 1.

% Caso 2: La cabeza de la lista no coincide (es otro jugador o es 'parda').
contar_victorias(Nombre, [_ | Resto], Total) :-
    contar_victorias(Nombre, Resto, Total).

ronda_terminada(Resultados) :-
    length(Resultados, L),
    (L >= 3 ; alguien_gano_dos(Resultados)).

alguien_gano_dos(Resultados) :-
    member(jugador(Nombre, _, _), Resultados),
    contar_victorias(Nombre, Resultados, V),
    V >= 2, !.
%cuando un jugador gana 2 manos, se le suma 1 punto.
finalizar_ronda-->
    state(S0,S),
    { 
        select(ronda(Resultados),S0,S1),
        select(jugadores(P0),S1,S2),
        obtener_ganador(P0,Resultados,Ganador),
	    nth0(N, P0, Ganador,Resto), %la carta ganadora y el jugador ganador van a estan en el mismo indice, se obtiene el jugador ganador de la lista P1, Resto = P1-jugadorGanador
        Ganador = jugador(Nombre, Mano, Puntos),
        format("El jugador ~w gano la Ronda~n",[Nombre]),
        PuntosNuevos is Puntos + 1,
        JN = jugador(Nombre, Mano, PuntosNuevos),
        nth0(N, P1, JN, Resto),
        S=[ronda([]),jugadores(P1)|S2]
    }.
jugar_mesa -->
    jugar_mano,  
    state(S),
    { select(ronda(Resultados), S, _) }, 
    ( { ronda_terminada(Resultados) } -> 
        finalizar_ronda  
    ; 
        jugar_mesa       
    ).
jugar_mesa-->
    jugar_mano,
    jugar_mesa.


jugar_mano-->
    state(S0,S),
    {select(jugadores(P0),S0,S1)},
    elegir_carta(P0,CartasSeleccionadas),
    {
        select(ronda(Resultados),S1,S2),
        
    %verifico con un if si alguien se rendio o en cambio ambos eligieron ana carta
        (
        alguien_va_al_mazo(CartasSeleccionadas) ->
        ganador_por_irse_al_mazo(P0, CartasSeleccionadas, _)
        ;
        carta_alta(CartasSeleccionadas,Resultado),
            %si se empardo, gurado directamente el resultado en la lista
            (
            Resultado=parda->
                format("Se empato la mano~n",[]),
                append([parda],Resultados,Resultados1)
            ;
            %sino busco al jugador y lo guardo en la lista
            nth0(N, CartasSeleccionadas, Resultado), %2do y 3er arg ya estan instanciados, asi que se utiliza nth0 para obtener el indice en el cual aparece la carta dentro de la lista
	        nth0(N, P0, JugadorGanador,_), %la carta ganadora y el jugador ganador van a estan en el mismo indice, se obtiene el jugador ganador de la lista P1, Resto = P1-jugadorGanador
            JugadorGanador = jugador(Nombre, _, _),
            format("El jugador ~w gano la mano~n",[Nombre]),
            append([JugadorGanador],Resultados,Resultados1)
            )
       
        ),
        %lo que hace maplist es aplicar el predicado (1er arg) sobre cada elemento perteneciente a las listas (demas arg)
    maplist(eliminar_carta,P0,CartasSeleccionadas,P1),
    imprimir_lista(Resultados1),
    S=[ronda(Resultados1),jugadores(P1)|S2]
    %busco al jugador que gano la mano
   /* nth0(N, CartasSeleccionadas, CartaAlta), %2do y 3er arg ya estan instanciados, asi que se utiliza nth0 para obtener el indice en el cual aparece la carta dentro de la lista
	nth0(N, P1, JugadorGanador,Resto), %la carta ganadora y el jugador ganador van a estan en el mismo indice, se obtiene el jugador ganador de la lista P1, Resto = P1-jugadorGanador
    JugadorGanador = jugador(Nombre, Mano, Puntos),
    format("El jugador ~w gano la mano~n",[Nombre]),
    NuevaManos is Manos + 1,
    JN = jugador(Nombre, Mano, Puntos, NuevaManos),
    nth0(N, P2, JN, Resto)%como N,JN y Resto ya estan instanciados, P2 = Resto+JN, y JN va a estar en el indice N*/
    }.
%elimina la carta de la mano del jugador
eliminar_carta(Jugador0, Carta, Jugador) :-
    Jugador0 = jugador(Nombre, Mano0, Puntos),
    select(Carta, Mano0, Mano1),
    Jugador = jugador(Nombre, Mano1, Puntos).

%en esta cláusula cada jugador ingresa una carta por consola, y se obtenie las cartas seleccionadas por recursividad
%caso base: no hay jugadores para que selecciones sus cartas
elegir_carta([],[])-->[].
elegir_carta([Jugador|Jugadores],[Carta|CartasSeleccionadas])-->
    {
        Jugador=jugador(Nombre,Mano,_),
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

imprimir_lista(Lista) :-
    writeln(Lista).
    