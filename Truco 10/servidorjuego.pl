:- module(servidorjuego, [main/0]).

:- use_module(library(http/websocket)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(lists), [memberchk/2]).
:- use_module(library(thread)).

:- use_module(config, [set_rivales/1]).
:- use_module(motor_juego_ws, [truco//0, set_jugadores_iniciales/1]).
:- use_module(interfaz_ws, [registrar_socket_jugador/2, publicar/1]).

:- dynamic jugadores_conectados/1.
:- dynamic partida_en_curso/0.
:- dynamic juego_terminado/0.

% punto de entrada del servidor
main :-
    retractall(jugadores_conectados(_)),
    assertz(jugadores_conectados([])),
    retractall(partida_en_curso),
    retractall(juego_terminado),
    http_server(http_dispatch, [port(8316)]),
    format('Servidor de Truco escuchando en puerto 8316...~n', []),
    esperar_fin_juego.

% expone el websocket del juego
:- http_handler(root(ws), http_upgrade_to_websocket(procesar_jugador, []), [spawn([])]).

% procesa la conexion de un jugador
procesar_jugador(WebSocket) :-
    ws_receive(WebSocket, Message, [format(prolog)]),
    (   Message.data = join(Nombre) ->
        registrar_jugador(Nombre, WebSocket),
        format(string(Texto), "jugador conectado: ~w", [Nombre]),
        publicar(Texto),
        arrancar_partida_si_corresponde
    ;   catch(ws_send(WebSocket, prolog(error(usa_join))), _, true)
    ),
    mantener_conexion.

% registra el socket de un jugador
registrar_jugador(Nombre, WebSocket) :-
    with_mutex(truco_ws, (
        registrar_socket_jugador(Nombre, WebSocket),
        jugadores_conectados(Previos),
        (   memberchk(Nombre, Previos) ->
            Nuevos = Previos
        ;   append(Previos, [Nombre], Nuevos)
        ),
        retractall(jugadores_conectados(_)),
        assertz(jugadores_conectados(Nuevos))
    )).

% arranca la partida cuando ya hay dos jugadores
arrancar_partida_si_corresponde :-
    with_mutex(truco_ws, (
        jugadores_conectados(Jugadores),
        length(Jugadores, Cantidad),
        (   Cantidad >= 2,
            \+ partida_en_curso ->
            assertz(partida_en_curso),
            set_jugadores_iniciales(Jugadores),
            set_rivales(Jugadores),
            publicar("iniciando partida"),
            thread_create(iniciar_partida, _, [detached(true)])
        ;   true
        )
    )).

% ejecuta la partida en un hilo aparte
iniciar_partida :-
    catch(phrase(motor_juego_ws:truco, [_], [_]), Error, (
        term_string(Error, ErrorTexto),
        format(string(Texto), "error en juego: ~w", [ErrorTexto]),
        publicar(Texto)
    )),
    retractall(juego_terminado),
    assertz(juego_terminado),
    publicar("juego terminado").

% mantiene abierta la conexion mientras dure la partida
mantener_conexion :-
    (   juego_terminado ->
        true
    ;   sleep(1),
        mantener_conexion
    ).

% espera a que termine la partida para cerrar el servidor
esperar_fin_juego :-
    (   juego_terminado ->
        format('Servidor terminando...~n', []),
        halt
    ;   sleep(1),
        esperar_fin_juego
    ).
