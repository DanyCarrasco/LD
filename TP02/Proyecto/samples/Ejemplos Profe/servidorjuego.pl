:- module(servidorjuego, [main/0]).

:- use_module(library(http/websocket)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(lists), [member/2]).

:- dynamic(jugadores/1).
:- dynamic(juego/1).

main :-
    http_server(http_dispatch, [port(8316)]),
    format('Servidor genérico escuchando en puerto 8316...~n', []),
    esperar_fin_juego.


esperar_fin_juego :-
    (   juego(terminado) ->
        format("Servidor terminando...~n", []),
        halt
    ;
        esperar_fin_juego
    ).

:- http_handler(root(ws), http_upgrade_to_websocket(procesar_jugador, []), [spawn([])]).

procesar_jugador(WebSocket) :-
    ws_receive(WebSocket, Message, [format(prolog)]),
    format("Recibido: ~w~n", [Message]),
    (   Message.data = join(Nombre) ->
        agregar_jugador(Nombre, WebSocket),
        verificar_inicio
    ;   ws_send(WebSocket, text("Envía join(tu_nombre)"))
    ),
    mantener_activo.

agregar_jugador(Nombre, WebSocket) :-
    (   jugadores(Lista) ->
        retract(jugadores(Lista))
    ;   Lista = []
    ),
    NuevaLista = [jugador(Nombre, WebSocket)|Lista],
    assertz(jugadores(NuevaLista)),
    length(NuevaLista, Cant),
    format("Jugador ~w conectado. Total: ~w~n", [Nombre, Cant]).

verificar_inicio :-
    jugadores(Lista),
    length(Lista, 4), % Solo 2 jugadores para prueba
    !,
    assertz(juego(iniciado)),
    format("Iniciando juego con ~w jugadores~n", [4]),
    iniciar_rondas(Lista).

verificar_inicio :-
    jugadores(Lista),
    forall(member(jugador(_, WS), Lista),
           ws_send(WS, text("Esperando más jugadores..."))).

mantener_activo :-
    (   juego(terminado) ->
        format("Hilo terminando para websocket~n", [])
    ;
	mantener_activo
    ).

iniciar_rondas(Jugadores) :-
    forall(member(jugador(_, WS), Jugadores),
           ws_send(WS, text("¡Juego iniciado!"))),
    jugar_rondas(Jugadores, 1, 2). % 2 rondas

jugar_rondas(Jugadores, Ronda, MaxRondas) :-
    Ronda > MaxRondas,
    !,
    format("Juego terminado~n", []),
    % Notificar a todos los jugadores y cerrar conexiones
    forall(member(jugador(_, WS), Jugadores),
           ws_send(WS, text("¡Juego terminado!"))
            ),
    assertz(juego(terminado)).


jugar_rondas(Jugadores, Ronda, MaxRondas) :-
    format("=== Ronda ~w ===~n", [Ronda]),
    forall(member(jugador(_, WS), Jugadores),
           (atom_concat('Ronda ', Ronda, MsgRonda),
            ws_send(WS, text(MsgRonda)))),


    procesar_turnos(Jugadores, Ronda),



    SigRonda is Ronda + 1,
    jugar_rondas(Jugadores, SigRonda, MaxRondas).

procesar_turnos([], Ronda):-
    format("Todos los jugadores han jugado en ronda ~w~n", [Ronda]).

procesar_turnos([jugador(Nombre, WS)|Resto], Ronda) :-
    format("Turno de ~w en ronda ~w~n", [Nombre, Ronda]),

    % Notificar a todos
    jugadores(TodosJugadores),
    atom_concat('Turno de ', Nombre, MsgTurno),
    forall(member(jugador(_, WSAll), TodosJugadores),
           ws_send(WSAll, text(MsgTurno))),

    % Pedir jugada al jugador actual con múltiples intentos
    ws_send(WS, text("tu_turno")),
    ws_send(WS, prolog([opcion1, opcion2, opcion3])),

    % Recibir respuesta con timeout más corto y reintentos
    ws_receive(WS, Respuesta, [format(prolog)]),
    format("~w jugó: ~w~n", [Nombre, Respuesta.data]),

    % Notificar la jugada a todos con manejo de errores
    format(atom(MsgJugada), '~w eligió ~w', [Nombre, Respuesta.data]),
    forall(member(jugador(_, WSAll), TodosJugadores),
	   catch(ws_send(WSAll, text(MsgJugada)), _, true)),

    procesar_turnos(Resto, Ronda).


