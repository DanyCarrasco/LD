:- use_module(library(random)).
:- use_module(library(clpfd)).

carta(Suite-Number) :-
    member(Suite, [oros, espadas, bastos, copas]),
    member(Number, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, as]).
    %Cartas validas.

orden_truco(espadas-as, 12).
orden_truco(bastos-as, 11).
orden_truco(X-7, 10) :- member(X, [oros, espadas]).
orden_truco(_-3, 9).
orden_truco(_-2, 8).
orden_truco(X-as, 7) :- member(X, [oros, copas]).
orden_truco(_-rey, 6).
orden_truco(_-caballo, 5).
orden_truco(_-sota, 4).
orden_truco(X-7, 3) :- member(X, [copas, bastos]).
orden_truco(_-6, 2).
orden_truco(_-5, 1).
orden_truco(_-4, 0).
%De mejor a peor carta.


cartas_truco_puntaje(Carta, Puntaje) :-
    carta(Carta),
    orden_truco(Carta, Puntaje).
    %Le damos el puntaje a cada carta.

carta_alta_truco(C1, C2, Higher) :-
    cartas_truco_puntaje(C1, P1),
    cartas_truco_puntaje(C2, P2),
    (P1 #> P2 *->
    Higher = C1
    ;
    Higher = C2).
%Vemos que carta es mas alta en el truco.




valor_envido(as, 1).
valor_envido(2, 2).
valor_envido(3, 3).
valor_envido(4, 4).
valor_envido(5, 5).
valor_envido(6, 6).
valor_envido(7, 7).
valor_envido(sota, 0).
valor_envido(caballo, 0).
valor_envido(rey, 0).




cartas_envido_puntaje(C1, C2, Puntaje) :-
    carta(C1),
    carta(C2),
    C1 = Palo1-Valor1,
    C2 = Palo2-Valor2,
    (Palo1 = Palo2 *-> %Vemos si los palos son iguales.
    valor_envido(Valor1, Pun1), %Le asignamos el valor del envido.
	valor_envido(Valor2, Pun2),
	Puntaje is Pun1 + Pun2 + 20 %Le sumamos 20.
    ;
    Puntaje is 0). %Si no, le asigna 0.


%Primero debemos mezclar las cartas.


% Lee el estado actual.
state(S), [S] --> [S].

% Cambia de un estado viejo a un estado nuevo.
state(S0, S), [S] --> [S0].


% Genera el mazo completo de 40 cartas.
mazo(Mazo) :-
    findall(Carta, carta(Carta), Mazo).


% Mezcla una lista de cartas.
mezclar([], []).

mezclar(Cartas, [CartaElegida | RestoMezclado]) :-
    length(Cartas, Cantidad),
    Cantidad1 is Cantidad - 1,
    random_between(0, Cantidad1, Posicion),
    nth0(Posicion, Cartas, CartaElegida, CartasRestantes),
    mezclar(CartasRestantes, RestoMezclado).


% Reparte 3 cartas a cada jugador y deja el resto del mazo.
repartir([C1, C2, C3, C4, C5, C6 | Resto], Mano0, Mano1, Resto) :-
    Mano0 = [C1, C2, C3],
    Mano1 = [C4, C5, C6].



juego --> inicializar_juego,turno0, turno1, resolver_mano.

% Inicializa el juego:
% genera el mazo, lo mezcla, reparte cartas y crea el estado inicial.

inicializar_juego -->
    {
        mazo(Mazo),
        format("Se generó el mazo",[]),

        mezclar(Mazo, MazoMezclado),
        format("Se mezcló el mazo.",[]),
        
        repartir(MazoMezclado, Mano0, Mano1, RestoMazo),

        format("Se repartieron las cartas.~n", []),
        format("Cartas del jugador 0: ~w~n", [Mano0]),
        format("Cartas del jugador 1: ~w~n", [Mano1])
    },
    state(sin_estado, estado(0, Mano0, Mano1, RestoMazo, 0, 0,Mesa)).

turno0 -->
    state(estado(0, Mano0, Mano1, Mazo, P0, P1, Mesa),
          estado(1, Mano0Nueva, Mano1, Mazo, P0, P1, [jugada(0, Carta)|Mesa])), %En mesa el jugador deja la carta que jugó.
    {
        format("Turno jugador 0~n", []),
        format("Cartas: ~w~n", [Mano0]),
        read(Carta),
        member(Carta, Mano0),
        select(Carta, Mano0, Mano0Nueva),
        format("Jugador 0 jugó: ~w~n", [Carta])
    }.

turno1 -->
    state(estado(1, Mano0, Mano1, Mazo, P0, P1, Mesa),
          estado(0, Mano0, Mano1Nueva, Mazo, P0, P1, [jugada(1, Carta)|Mesa])),
    {
        format("Turno jugador 1~n", []),
        format("Cartas: ~w~n", [Mano1]),
        read(Carta),
        member(Carta, Mano1),
        select(Carta, Mano1, Mano1Nueva),
        format("Jugador 1 jugó: ~w~n", [Carta])
    }.



ganador_mano(jugada(0, Carta0), jugada(1, Carta1), Ganador) :- %Vemos quien gano en esta mano.

    carta_alta_truco(Carta0, Carta1, CartaGanadora),
    ( CartaGanadora = Carta0 ->
        Ganador = 0
    ;
        Ganador = 1
    ).

resolver_mano -->
    state(estado(Turno, Mano0, Mano1, Mazo, P0, P1, [Jugada1, Jugada0]),
          estado(Turno, Mano0, Mano1, Mazo, P0Nuevo, P1Nuevo, [])),
    {
        ganador_mano(Jugada0, Jugada1, Ganador),

        format("Ganó la mano el jugador ~w~n", [Ganador]),

        ( Ganador = 0 ->
            P0Nuevo is P0 + 1,
            P1Nuevo is P1
        ;
            P0Nuevo is P0,
            P1Nuevo is P1 + 1
        )
    }.















