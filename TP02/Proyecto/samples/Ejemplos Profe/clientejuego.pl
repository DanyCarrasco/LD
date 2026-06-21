:- module(clientejuego, [main/0]).

:- use_module(library(http/websocket)).

main :-
    format("Ingresa tu nombre: "),
    read(Nombre),
    format("Conectando a ws://localhost:8316/ws~n", []),
    http_open_websocket('ws://localhost:8316/ws', WebSocket, []),
    ws_send(WebSocket, prolog(join(Nombre))),
    escuchar_mensajes(WebSocket).

escuchar_mensajes(Stream) :-
    format("Esperando mensajes...~n", []),
    ws_receive(Stream, Message, []),
    procesar_mensaje(Stream, Message).

procesar_mensaje(Stream, Message) :-
    (   Message.data == "tu_turno" ->
        manejar_turno(Stream)
    ;   Message.data == "¡Juego terminado!" ->
        format("~w~n", [Message.data]),
        format("Desconectando...~n", []),
        ws_close(Stream, 1000, "Cliente terminando")
    ;   Message.opcode == close ->
        format("Conexión cerrada por el servidor~n", [])
    ;
        format("Mensaje: ~w~n", [Message]),
        escuchar_mensajes(Stream)
    ).

manejar_turno(Stream) :-
    format("¡Es tu turno!~n", []),
    ws_receive(Stream, Opciones, [format(prolog)]),
    format("Opciones disponibles: ~w~n", [Opciones.data]),
    format("Elige una opción: "),
    read(Eleccion),
    ws_send(Stream, prolog(Eleccion)),
    format("Jugada enviada: ~w~n", [Eleccion]),
    escuchar_mensajes(Stream).
