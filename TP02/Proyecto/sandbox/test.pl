:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/websocket)).

% =============================================================================
% SERVER SIDE
% =============================================================================

% Route /ws requests to the websocket handler
:- http_handler(root(ws), http_upgrade_to_websocket(echo_handler, []), []).

% Start the server on port 8080
start_server :-
    http_server(http_dispatch, [port(8080)]),
    format('Server started on port 8080.~n', []).

% Loop to receive messages and echo them back
echo_handler(WebSocket) :-
    ws_receive(WebSocket, Message),
    (   Message.opcode == close
    ->  format('Server: Client closed connection.~n', []),
        true
    ;   format('Server received: ~w~n', [Message.data]),
        % Echo back prefixed with "Echo: "
        atom_concat('Echo: ', Message.data, ReplyData),
        ws_send(WebSocket, text(ReplyData)),
        echo_handler(WebSocket)
    ).

% =============================================================================
% CLIENT SIDE
% =============================================================================

% Connect, send a message, read the response, and close
run_client :-
    format('Client: Connecting to server...~n', []),
    http_open_websocket('ws://localhost:8080/ws', WS, []),

    format('Client: Sending message...~n', []),
    ws_send(WS, text('Hello Prolog WebSocket!')),

    format('Client: Waiting for reply...~n', []),
    ws_receive(WS, Reply),
    format('Client received from server: "~w"~n', [Reply.data]),

    format('Client: Closing connection.~n', []),
    ws_close(WS, 1000, "Done testing").

% =============================================================================
% AUTOMATED TEST RUNNER
% =============================================================================

% One command to launch server, run client, and clean up
test :-
    start_server,
    sleep(1), % Give the server a second to boot up
    run_client.
