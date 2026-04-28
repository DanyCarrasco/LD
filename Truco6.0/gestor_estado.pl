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


% state(-Estado)//
%
% No terminal DCG que lee el estado actual y lo deja intacto. Se usa cuando
% una regla necesita inspeccionar el estado sin modificarlo.
%
% Como el programa modela la partida con una DCG, el "input" y el "output"
% de la gramatica no son tokens tradicionales sino una lista que contiene un
% unico elemento: el estado completo del juego.
state(S), [S] --> [S].

% state(-EstadoAnterior, +EstadoNuevo)//
%
% No terminal DCG basico para actualizar estado. Toma el estado de entrada,
% lo unifica con EstadoAnterior, y lo reemplaza por EstadoNuevo en la salida.
%
% Casi todas las transformaciones de la partida terminan apoyandose en esta
% regla, ya sea directamente o a traves de predicados auxiliares.
state(S0, S), [S] --> [S0].

% asegurar_ronda//
%
% Compatibiliza el estado de ronda con la estructura actual de cuatro
% argumentos: ronda(Resultados, CantoActual, Rechazo, EstadoEnvido).
%
% Si el estado contiene una version vieja de ronda/1, ronda/2 o ronda/3,
% esta regla la reemplaza por la forma moderna agregando valores por defecto.
% Si la ronda ya esta normalizada, deja el estado intacto.
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

% set_ronda_canto(+Canto)//
%
% Actualiza el canto vigente de la ronda sin tocar los resultados ya jugados,
% la marca de rechazo ni el estado del envido. Se usa cuando un canto fue
% aceptado y la ronda debe pasar a jugarse por mas puntos.
set_ronda_canto(Canto) -->
    state(S0, S),
    { select(ronda(Resultados, _, R, E), S0, S1),
      S = [ronda(Resultados, Canto, R, E)|S1] }.

% set_rechazo(+Jugador)//
%
% Marca en la ronda que la secuencia de cantos termino por rechazo y guarda
% el nombre del jugador que se beneficia con ese rechazo. El resto de la
% informacion de la ronda permanece igual.
set_rechazo(Jug) -->
    state(S0, S),
    { select(ronda(Resultados, C, _, E), S0, S1),
      S = [ronda(Resultados, C, rechazo(Jug), E)|S1] }.

% set_estado_envido(+EstadoEnvido)//
%
% Reemplaza exclusivamente el cuarto componente de ronda(...), que modela la
% negociacion y resolucion del envido. Se usa al cerrar un envido aceptado o
% rechazado para dejar asentado que ya no puede volver a cantarse.
set_estado_envido(EstadoEnvido) -->
    state(S0, S),
    { select(ronda(Resultados, C, R, _), S0, S1),
      S = [ronda(Resultados, C, R, EstadoEnvido)|S1] }.

% mezclar_cartas//
%
% Toma el mazo actual del estado, lo mezcla con mezclar/2 y vuelve a guardar
% la version mezclada en el mismo lugar.
mezclar_cartas -->
    state(S0, S),
    {
        select(mazo(Cartas), S0, S1),
        mezclar(Cartas, CartasMezcladas),
        S = [mazo(CartasMezcladas)|S1]
    }.

% repartir_carta_a_cada_jugador//
%
% Extrae del estado la lista de jugadores y el mazo actual, reparte una carta
% a cada jugador en orden y deja el mazo reducido con las cartas restantes.
repartir_carta_a_cada_jugador -->
    state(S0, S),
    {
        select(jugadores(Jugadores), S0, S1),
        select(mazo(Cartas), S1, S2),
        repartir_carta_a_cada_jugador(Jugadores, Jugadores1, Cartas, Cartas1),
        S = [jugadores(Jugadores1), mazo(Cartas1)|S2]
    }.

% repartir_carta_a_cada_jugador(+JugadoresAntes, -JugadoresDespues, +MazoAntes, -MazoDespues)
%
% Version logica auxiliar del reparto. Recorre ambas listas en paralelo:
% consume una carta del mazo y la agrega al frente de la mano de cada jugador.
repartir_carta_a_cada_jugador([], [], Mazo, Mazo).
repartir_carta_a_cada_jugador([Jugador|Jugadores], [Jugador1|Jugadores1], [Carta|Mazo], Mazo1) :-
    Jugador = jugador(N, Mano, Puntos),
    Jugador1 = jugador(N, [Carta|Mano], Puntos),
    repartir_carta_a_cada_jugador(Jugadores, Jugadores1, Mazo, Mazo1).


% sumar_puntos_a_jugador(+Jugador, +Puntos)//
%
% Recorre la lista de jugadores del estado y suma Puntos unicamente al
% jugador cuyo nombre coincide con Jugador. El resto queda sin cambios.
sumar_puntos_a_jugador(Jug, Pts) -->
    state(S0, S),
    { select(jugadores(P0), S0, S1),
      maplist(sumar_si_corresponde(Jug, Pts), P0, P1),
      S = [jugadores(P1)|S1] }.

% sumar_si_corresponde(+NombreObjetivo, +Puntos, +JugadorAntes, -JugadorDespues)
%
% Predicado auxiliar usado por maplist/3 para actualizar puntajes.
%
% Si el jugador inspeccionado coincide con NombreObjetivo, incrementa su
% marcador. Si no coincide, deja el termino jugador(...) intacto.
sumar_si_corresponde(Jug, Pts, jugador(Jug, Mano, Puntos0), jugador(Jug, Mano, Puntos)) :-
    Puntos is Puntos0 + Pts.
sumar_si_corresponde(Jug, _Pts, jugador(N, Mano, Puntos), jugador(N, Mano, Puntos)) :-
    N \= Jug.


% eliminar_carta(+JugadorAntes, +CartaJugada, -JugadorDespues)
%
% Quita de la mano de un jugador la carta que acaban de jugar en la mano
% actual, conservando nombre y puntaje sin cambios.
eliminar_carta(Jugador0, Carta, Jugador) :-
    Jugador0 = jugador(Nombre, Mano0, Puntos),
    select(Carta, Mano0, Mano1),
    Jugador = jugador(Nombre, Mano1, Puntos).