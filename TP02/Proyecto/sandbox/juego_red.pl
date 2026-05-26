:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/websocket)).

% Esta sera la base de datos dinamica en memoria
:- dynamic jugador_ws/2.

% Los argumentos son Goal, Option, Request
:- http_handler(root(''), http_upgrade_to_websocket(accept_cliente, []), []).

accept_cliente(WebSocket):-
    % 1. Evaluamos si registramos como Jugador 1 o Jugador 2
    (   not(jugador_ws(j1, _))
    ->  assertz(jugador_ws(j1, WebSocket)),
        ws_send(WebSocket, text('Sos el Jugador 1. Esperando al rival...')),
        MiId = j1
    ;   assertz(jugador_ws(j2, WebSocket)),
        ws_send(WebSocket, text('Sos el Jugador 2. ¡Conectado!')),
        MiId = j2
    ),

    % 2. Pasamos el control al bucle de chat, pasándole su Identificador (j1 o j2)
    bucle_chat(WebSocket, MiId).

bucle_chat(WebSocket, MiId):-
    % 1. Quedarse esperando a que esta ventana mande un mensaje
    ws_receive(WebSocket, MensajeRecibido),

    % 2. Extraer el texto puro del diccionario que ya conocemos
    TextoPuro = MensajeRecibido.data,

    % 3. Lógica relacional: Si yo soy j1, mi rival es j2. Si soy j2, mi rival es j1.
    ( MiId == j1 -> RivalId = j2 ; RivalId = j1 ),

    % 4. Buscar en la memoria si el rival ya está conectado
    (   jugador_ws(RivalId, WebSocketDelRival)
    ->  % Si está conectado, le mandamos el texto directo a su ventana
        ws_send(WebSocketDelRival, text(TextoPuro))
    ;   % Si no está conectado, le avisamos a la ventana actual
        ws_send(WebSocket, text('El rival aún no se ha conectado.'))
    ),

    % 5. Volver a empezar el bucle para seguir escuchando
    bucle_chat(WebSocket, MiId).

servidor_iniciar(Puerto) :-
    http_server(http_dispatch, [port(Puerto)]).

