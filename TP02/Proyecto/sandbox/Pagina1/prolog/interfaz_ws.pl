:- module(interfaz_ws, [
    entrada_teclado/3,
    registrar_socket_jugador/2,
    socket_jugador/2,
    enviar_socket/2,
    esperar_seleccion_socket/4,
    publicar/1
]).

:- use_module(library(http/websocket)).
:- use_module(library(readutil)).
:- use_module(library(lists), [member/2]).

:- dynamic socket_jugador/2.

% registra el socket de un jugador
registrar_socket_jugador(Nombre, WebSocket) :-
    retractall(socket_jugador(Nombre, _)),
    assertz(socket_jugador(Nombre, WebSocket)).

% publica un mensaje a todos los sockets
publicar(Mensaje) :-
    forall(socket_jugador(_, WebSocket),
           catch(ws_send(WebSocket, string(Mensaje)), _, true)).

% envia un mensaje a un socket
enviar_socket(WebSocket, Mensaje) :-
    catch(ws_send(WebSocket, string(Mensaje)), _, true).

% espera una seleccion valida en un socket
esperar_seleccion_socket(WebSocket, Mensaje, Opciones, Resultado) :-
    Opciones \= [],
    repeat,
        catch(ws_send(WebSocket, prolog(prompt(Mensaje, Opciones))), _, true),
        ws_receive(WebSocket, Reply, [format(prolog)]),
        ( Reply.data = respuesta(Entrada) ->
            true
        ; Reply.data = Entrada
        ),
        ( member(Entrada, Opciones) ->
            Resultado = Entrada, !
        ;
            catch(ws_send(WebSocket, prolog(error(opcion_no_valida))), _, true),
            fail
        ).

% pide una opcion por consola
entrada_teclado(Mensaje, Opciones, Resultado) :-
    Opciones \= [],
    repeat,
        format('~w (~w)\n', [Mensaje, Opciones]),
        read_line_to_string(user_input, Linea),
        catch(term_string(Entrada, Linea), _, Entrada = error),
        ( member(Entrada, Opciones) ->
            Resultado = Entrada, !
        ;
            write('Opcion no valida!\n'),
            fail
        ).
