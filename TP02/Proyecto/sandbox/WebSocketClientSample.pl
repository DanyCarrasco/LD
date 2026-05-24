:- use_module(library(http/websocket)).

connect_and_send(URL) :-
    % Open the connection
    http_open_websocket(URL, WS, []),

    % Send a text message
    ws_send(WS, text("Hello from Prolog!")),

    % Wait for a response
    ws_receive(WS, Reply),
    format('Server said: ~w~n', [Reply.data]),

    % Close the connection
    ws_close(WS, 1000, "Finished").
