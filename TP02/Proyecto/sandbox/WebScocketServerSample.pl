:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/websocket)).

% 1. Define the HTTP route for the websocket
:- http_handler(root(ws), http_upgrade_to_websocket(echo_handler, []), []).

% 2. Start the server on port 8080
server(Port) :-
    http_server(http_dispatch, [port(Port)]).

% 3. Define the handler for the upgraded connection
echo_handler(WebSocket) :-
    ws_receive(WebSocket, Message),
    (   Message.opcode == close
    ->  true
    ;   % Send the message back to the client
        ws_send(WebSocket, text(Message.data)),
        echo_handler(WebSocket)
    ).