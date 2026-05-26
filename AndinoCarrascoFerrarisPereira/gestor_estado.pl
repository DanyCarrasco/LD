:- module(gestor_estado, [
    state//1,
    state//2,
    asegurar_ronda//0,
    set_ronda_canto//1,
    set_rechazo//1,
    set_estado_envido//1,
    mezclar_cartas//0,
    repartir_carta_a_cada_jugador//0,
    sumar_puntos_a_jugador//2,
    sumar_si_corresponde/4,
    eliminar_carta/3
]).

:- use_module(config, [estado_envido_inicial/1]).
:- use_module(mazoTruco, [mezclar/2]).


% lee el estado sin cambiarlo
state(S), [S] --> [S].

% reemplaza el estado actual
state(S0, S), [S] --> [S0].

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

% mezcla el mazo del estado
mezclar_cartas -->
    state(S0, S),
    {
        select(mazo(Cartas), S0, S1),
        mezclar(Cartas, CartasMezcladas),
        S = [mazo(CartasMezcladas)|S1]
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


% saca una carta de la mano del jugador
eliminar_carta(Jugador0, Carta, Jugador) :-
    Jugador0 = jugador(Nombre, Mano0, Puntos),
    select(Carta, Mano0, Mano1),
    Jugador = jugador(Nombre, Mano1, Puntos).
