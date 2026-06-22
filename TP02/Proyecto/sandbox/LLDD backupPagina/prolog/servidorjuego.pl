:- module(servidorjuego, [main/0]).

% Bibliotecas para servidor HTTP y WebSocket.
:- use_module(library(http/websocket)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).

% Utilidades.
:- use_module(library(lists), [memberchk/2]).
:- use_module(library(thread)).

% Módulos propios del proyecto.
:- use_module(config, [set_rivales/1]).
:- use_module(motor_juego_ws, [truco//0, set_jugadores_iniciales/1]).
:- use_module(interfaz_ws, [
    registrar_socket_jugador/2,
    publicar/1
]).

% Predicados modificables durante la ejecución.
:- dynamic jugadores_conectados/1.
:- dynamic partida_en_curso/0.
:- dynamic juego_terminado/0.



% INICIO DEL SERVIDOR

% main/0
%
% Inicializa los datos del servidor, abre el puerto 8316
% y espera hasta que finalice la partida.
main :-
    % Borra posibles datos de una ejecución anterior.
    retractall(jugadores_conectados(_)),
    retractall(partida_en_curso),
    retractall(juego_terminado),

    % Inicialmente no hay jugadores conectados.
    assertz(jugadores_conectados([])),

    % Inicia el servidor HTTP.
    http_server(http_dispatch, [port(8316)]),

    format(
        'Servidor de Truco escuchando en puerto 8316...~n',
        []
    ),

    % Mantiene vivo el proceso principal.
    esperar_fin_juego.


% RUTA WEBSOCKET

% Cuando un cliente se conecta a:
%
%   ws://localhost:8316/ws
%
% se convierte la conexión HTTP en WebSocket
% y se ejecuta procesar_jugador/1.
%
% spawn([]) crea un hilo separado para cada cliente.

:- http_handler(
    root(ws),
    http_upgrade_to_websocket(procesar_jugador, []),
    [spawn([])]
).


% CONEXIÓN DE UN JUGADOR


% procesar_jugador(+WebSocket)
%
% Espera que el primer mensaje del cliente sea:
%
%   join(Nombre)
%
% Si es correcto, registra al jugador.
procesar_jugador(WebSocket) :-
    ws_receive(
        WebSocket,
        Message,
        [format(prolog)]
    ),

    (
        Message.data = join(Nombre)
    ->
        registrar_jugador(Nombre, WebSocket),

        format(
            string(Texto),
            "jugador conectado: ~w",
            [Nombre]
        ),

        publicar(Texto),

        arrancar_partida_si_corresponde
    ;
        % Si el cliente no envió join(Nombre),
        % se le informa el error.
        catch(
            ws_send(
                WebSocket,
                prolog(error(usa_join))
            ),
            _,
            true
        )
    ),

    % Mantiene abierta la conexión.
    mantener_conexion.


% 
% REGISTRO DE JUGADORES

% registrar_jugador(+Nombre, +WebSocket)
%
% Asocia el jugador con su socket
% y lo agrega a jugadores_conectados/1.
registrar_jugador(Nombre, WebSocket) :-
    with_mutex(
        truco_ws,
        (
            % Guarda qué socket pertenece al jugador.
            registrar_socket_jugador(
                Nombre,
                WebSocket
            ),

            % Obtiene la lista actual.
            jugadores_conectados(Previos),

            (
                memberchk(Nombre, Previos)
            ->
                % Si ya estaba registrado, no lo agrega otra vez.
                Nuevos = Previos
            ;
                % Si es nuevo, lo agrega al principio.
                Nuevos = [Nombre | Previos]
            ),

            % Reemplaza la lista anterior.
            retractall(jugadores_conectados(_)),
            assertz(jugadores_conectados(Nuevos))
        )
    ).


% INICIO DE LA PARTIDA

% arrancar_partida_si_corresponde/0
%
% Si hay al menos dos jugadores y todavía no empezó
% la partida, configura el motor e inicia el juego.
arrancar_partida_si_corresponde :-
    with_mutex(
        truco_ws,
        (
            jugadores_conectados(Jugadores),
            length(Jugadores, Cantidad),

            (
                Cantidad >= 2,
                \+ partida_en_curso
            ->
                % Evita iniciar dos partidas.
                assertz(partida_en_curso),

                % Los jugadores se guardan al principio de la lista,
                % por eso se invierte el orden.
                reverse(
                    Jugadores,
                    JugadoresOrden
                ),

                % Configura los nombres en el motor.
                set_jugadores_iniciales(
                    JugadoresOrden
                ),

                % Configura quién es rival de quién.
                set_rivales(
                    JugadoresOrden
                ),

                publicar("iniciando partida"),

                % Ejecuta la partida en otro hilo.
                thread_create(
                    iniciar_partida,
                    _,
                    [detached(true)]
                )
            ;
                true
            )
        )
    ).


% EJECUCIÓN DEL JUEGO

% iniciar_partida/0
%
% Ejecuta la DCG principal del Truco.
% Si ocurre un error, lo captura y lo informa.
iniciar_partida :-
    catch(
        phrase(
            motor_juego_ws:truco,
            [_],
            [_]
        ),

        Error,

        (
            term_string(
                Error,
                ErrorTexto
            ),

            format(
                string(Texto),
                "error en juego: ~w",
                [ErrorTexto]
            ),

            publicar(Texto)
        )
    ),

    % Marca que el juego terminó.
    retractall(juego_terminado),
    assertz(juego_terminado),

    publicar("juego terminado").


% MANTENER ABIERTAS LAS CONEXIONES

% mantener_conexion/0
%
% Mantiene abierto el hilo del cliente
% hasta que finalice el juego.

mantener_conexion :-
    (
        juego_terminado
    ->
        true
    ;
        sleep(1),
        mantener_conexion
    ).


% esperar_fin_juego/0
%
% Mantiene vivo el servidor principal.
% Cuando termina la partida, cierra SWI-Prolog.
esperar_fin_juego :-
    (
        juego_terminado
    ->
        format(
            'Servidor terminando...~n',
            []
        ),

        halt
    ;
        sleep(1),
        esperar_fin_juego
    ).