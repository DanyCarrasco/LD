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

%Logica del envido.
    %Le asignamos los valores a las cartas.

valor_envido(_-rey, 0).
valor_envido(_-caballo, 0).
valor_envido(_-sota, 0).
valor_envido(_-as, 1).
valor_envido(_-N, N) :-
    integer(N).

%Calculamos los puntos si son del mismo palo.
puntos_par_envido(Palo-N1, Palo-N2, Puntos) :-
    valor_envido(Palo-N1, V1),
    valor_envido(Palo-N2, V2),
    Puntos is 20 + V1 + V2.

%Vemos si son del mismo palo.
puntos_par_envido(Palo1-_, Palo2-_, 0) :-
    Palo1 \= Palo2.

%Agarramos el puntaje maximo según el envido y las cartas que tenemos.
puntos_envido([C1, C2, C3], Puntos) :-
    puntos_par_envido(C1, C2, P12),
    puntos_par_envido(C1, C3, P13),
    puntos_par_envido(C2, C3, P23),
    valor_envido(C1, V1),
    valor_envido(C2, V2),
    valor_envido(C3, V3),
    max_list([P12, P13, P23, V1, V2, V3], Puntos).


%Vemos cual seria el ganador segun el puntaje.
ganador_envido(
    jugador(Nombre1, Mano1, _, _),
    jugador(Nombre2, Mano2, _, _),
    Ganador
) :-
    puntos_envido(Mano1, P1),
    puntos_envido(Mano2, P2),
    format("~w tiene ~w puntos de envido~n", [Nombre1, P1]),
    format("~w tiene ~w puntos de envido~n", [Nombre2, P2]),
    (
        P1 >= P2 ->
        Ganador = Nombre1
    ;
        Ganador = Nombre2
    ).


%envido

    %---------------- CADENA DE ENVIDO ----------------%

cantar_envido -->
    jugadores(Jugadores, Jugadores),
    {
        format("Desean cantar envido? si/no~n"),
        read(Respuesta),
        (
            Respuesta = si ->
                jugar_cadena_envido(Jugadores, [])
        ;
            format("No se canto envido~n")
        )
    }.


% Si todavia no se canto nada, solo puede cantar e/r/f.
jugar_cadena_envido(Jugadores, []) :-
    format("Ingrese: e = envido / r = real_envido / f = falta_envido~n"),
    read(Accion),
    eleccion_envido(Accion, Jugadores, []).

% Si ya hubo un canto, puede querer, no querer o subir.
jugar_cadena_envido(Jugadores, Cantos) :-
    Cantos \= [],
    format("Cantos actuales: ~w~n", [Cantos]),
    format("Ingrese: e = envido / r = real_envido / f = falta_envido / q = quiero / n = no_quiero~n"),
    read(Accion),
    eleccion_envido(Accion, Jugadores, Cantos).


% El jugador canta e/r/f.
% La ultima respuesta se guarda en la cabeza de la lista.

eleccion_envido(Canto, Jugadores, Cantos) :-
    member(Canto, [e, r, f]),
    puede_responder(Cantos, Canto),
    Cantos1 = [Canto | Cantos],
    jugar_cadena_envido(Jugadores, Cantos1).

% El jugador dice quiero.
eleccion_envido(q, Jugadores, Cantos) :-
    Cantos \= [],
    puntos_envido_cantado(Cantos, Puntos),
    resolver_envido_querido(Jugadores, Puntos).

% El jugador dice no quiero.
eleccion_envido(n, _Jugadores, Cantos) :-
    Cantos \= [],
    puntos_no_querido(Cantos, Puntos),
    format("No querido. Se ganan ~w puntos.~n", [Puntos]).

% Accion invalida.
eleccion_envido(_, Jugadores, Cantos) :-
    format("Accion invalida para esta cadena de envido.~n"),
    jugar_cadena_envido(Jugadores, Cantos).


% Cantos guarda la ultima respuesta en la cabeza.
%
% Ejemplos:
% [e]       = se canto envido
% [e,e]     = se canto envido + envido
% [r,e]     = se canto envido + real envido
% [f,r,e]   = se canto envido + real envido + falta envido

% Primer canto posible.
puede_responder([], e).
puede_responder([], r).
puede_responder([], f).

% Si lo ultimo fue envido, se puede responder envido, real o falta.
puede_responder([e | _], e).
puede_responder([e | _], r).
puede_responder([e | _], f).

% Si lo ultimo fue real envido, solo se puede responder falta.
puede_responder([r | _], f).

% Si lo ultimo fue falta envido, no se puede cantar nada mas.



puntos_envido_cantado([e], 2).
puntos_envido_cantado([r], 3).
puntos_envido_cantado([f], falta).

puntos_envido_cantado([e,e], 4).
puntos_envido_cantado([r,e], 5).
puntos_envido_cantado([f,e], falta).

puntos_envido_cantado([r,e,e], 7).
puntos_envido_cantado([f,e,e], falta).
puntos_envido_cantado([f,r,e], falta).
puntos_envido_cantado([f,r,e,e], falta).



puntos_no_querido([e], 1).
puntos_no_querido([r], 1).
puntos_no_querido([f], 1).

puntos_no_querido([e,e], 2).
puntos_no_querido([r,e], 2).
puntos_no_querido([f,e], 2).

puntos_no_querido([r,e,e], 4).
puntos_no_querido([f,e,e], 4).
puntos_no_querido([f,r,e], 5).
puntos_no_querido([f,r,e,e], 7).


%---------------- RESOLVER ENVIDO USANDO TUS PREDICADOS ----------------%

resolver_envido_querido([J0, J1], Puntos) :-
    ganador_envido(J0, J1, Ganador),
    format("El ganador del envido es ~w~n", [Ganador]),
    format("Se ganan ~w puntos.~n", [Puntos]).





    



