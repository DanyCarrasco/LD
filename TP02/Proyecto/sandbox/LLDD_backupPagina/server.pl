:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_files)).
:- use_module(library(filesex)).

% Servir la raíz del proyecto
:- http_handler(
       root(.),
       http_reply_from_files('.', [indexes(true)]),
       [prefix]
   ).

server(Port) :-
    http_server(http_dispatch, [port(Port)]).

inicio_server :-
    working_directory(CWD, CWD),
    format("Directorio: ~w~n", [CWD]),
    server(8288).

:- initialization(inicio_server).