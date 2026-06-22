:- module(clientejuego, [main/0]).

:- use_module(library(http/websocket)).
:- use_module(library(lists), [member/2]).
:- use_module(library(readutil)).

% punto de entrada del cliente
main :-
    pedir_nombre(Nombre),
    format('Conectando a ws://localhost:8316/ws~n', []),
    http_open_websocket('ws://localhost:8316/ws', WebSocket, []),
    ws_send(WebSocket, prolog(join(Nombre))),
    escuchar_mensajes(WebSocket).

% pide el nombre del jugador
pedir_nombre(Nombre) :-
    repeat,
        format('Ingresa tu nombre: '),
        read_line_to_string(user_input, Linea),
        normalize_space(string(Limpio), Linea),
        Limpio \= "",
        atom_string(Nombre, Limpio),
        !.

% recibe mensajes del servidor
escuchar_mensajes(WebSocket) :-
    ws_receive(WebSocket, Message),
    procesar_mensaje(WebSocket, Message).

% interpreta cada mensaje entrante
procesar_mensaje(WebSocket, Message) :-
    (   Message.opcode == close ->
        format('Conexion cerrada por el servidor~n', [])
    ;   es_control(Message.data, Term) ->
        handle_term(WebSocket, Term)
    ;
        format('~w~n', [Message.data]),
        escuchar_mensajes(WebSocket)
    ).

% detecta mensajes de control
es_control(Data, Term) :-
    sub_string(Data, 0, _, _, "prompt("),
    catch(term_string(Term, Data), _, fail).
es_control(Data, Term) :-
    sub_string(Data, 0, _, _, "error("),
    catch(term_string(Term, Data), _, fail).
es_control(Data, juego_terminado) :-
    Data == "juego terminado".

% maneja terminos de control
handle_term(WebSocket, prompt(Mensaje, Opciones)) :-
    format('~w~n', [Mensaje]),
    format('Opciones: ~w~n', [Opciones]),
    pedir_respuesta(WebSocket, Opciones).
handle_term(WebSocket, error(Detalle)) :-
    format('Error del servidor: ~w~n', [Detalle]),
    escuchar_mensajes(WebSocket).
handle_term(WebSocket, juego_terminado) :-
    format('Juego terminado.~n', []),
    ws_close(WebSocket, 1000, 'Cliente terminando').
handle_term(WebSocket, Term) :-
    format('~w~n', [Term]),
    escuchar_mensajes(WebSocket).

% envia la respuesta elegida al servidor
pedir_respuesta(WebSocket, Opciones) :-
    repeat,
        format('Elige una opcion: '),
        read_line_to_string(user_input, Linea),
        catch(term_string(Eleccion, Linea), _, Eleccion = error),
        (   member(Eleccion, Opciones) ->
            ws_send(WebSocket, prolog(Eleccion)),
            escuchar_mensajes(WebSocket)
        ;   format('Opcion no valida.~n', []),
            fail
        ).
