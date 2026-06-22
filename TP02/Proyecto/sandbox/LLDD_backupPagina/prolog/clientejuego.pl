% Declara el modulo clientejuego.
% Exporta main/0, que es el predicado principal del cliente.

:- module(clientejuego, [main/0]).

% Biblioteca para conectarse y comunicarse mediante WebSockets.
:- use_module(library(http/websocket)).

% Importa member/2 para verificar si una opción pertenece a una lista.
:- use_module(library(lists), [member/2]).

% Biblioteca para leer líneas completas desde la terminal.
:- use_module(library(readutil)).


% INICIO DEL CLIENTE

% main/0
%
% Pide el nombre del jugador, se conecta al servidor,
% envía el nombre y comienza a escuchar mensajes.
main :-
    pedir_nombre(Nombre),

    format('Conectando a ws://localhost:8316/ws~n', []),

    % Abre una conexión WebSocket con el servidor.
    http_open_websocket(
        'ws://localhost:8316/ws',
        WebSocket,
        []
    ),

    % Le avisa al servidor que quiere unirse con ese nombre.
    ws_send(
        WebSocket,
        prolog(join(Nombre))
    ),

    % Queda esperando mensajes del servidor.
    escuchar_mensajes(WebSocket).



% PEDIR NOMBRE


% pedir_nombre(-Nombre)
%
% Pide un nombre por teclado.
% Si está vacío, vuelve a pedirlo.
pedir_nombre(Nombre) :-
    repeat,

        format('Ingresa tu nombre: '),

        % Lee una línea completa como string.
        read_line_to_string(
            user_input,
            Linea
        ),

        % Elimina espacios sobrantes.
        normalize_space(
            string(Limpio),
            Linea
        ),

        % Comprueba que no esté vacío.
        Limpio \= "",

        % Convierte el string a átomo.
        atom_string(
            Nombre,
            Limpio
        ),

        % Cuando consigue un nombre válido, corta el repeat.
        !.


% --------------------------------------------------
% RECIBIR MENSAJES
% --------------------------------------------------

% escuchar_mensajes(+WebSocket)
%
% Espera un mensaje del servidor y luego lo procesa.
escuchar_mensajes(WebSocket) :-
    ws_receive(
        WebSocket,
        Message
    ),

    procesar_mensaje(
        WebSocket,
        Message
    ).


% --------------------------------------------------
% PROCESAR MENSAJES
% --------------------------------------------------

% procesar_mensaje(+WebSocket, +Message)
%
% Decide qué hacer según el tipo de mensaje recibido.
procesar_mensaje(WebSocket, Message) :-
    (
        % Si el servidor cerró la conexión.
        Message.opcode == close
    ->
        format(
            'Conexion cerrada por el servidor~n',
            []
        )

    ;
        % Si es un mensaje especial como prompt(...) o error(...).
        es_control(Message.data, Term)
    ->
        handle_term(
            WebSocket,
            Term
        )

    ;
        % Si es un mensaje normal, lo muestra.
        format(
            '~w~n',
            [Message.data]
        ),

        % Luego sigue escuchando.
        escuchar_mensajes(WebSocket)
    ).


% --------------------------------------------------
% DETECTAR MENSAJES DE CONTROL
% --------------------------------------------------

% Detecta mensajes que empiezan con prompt(...).
es_control(Data, Term) :-
    sub_string(
        Data,
        0,
        _,
        _,
        "prompt("
    ),

    % Convierte el string recibido en un término Prolog.
    catch(
        term_string(Term, Data),
        _,
        fail
    ).


% Detecta mensajes que empiezan con error(...).
es_control(Data, Term) :-
    sub_string(
        Data,
        0,
        _,
        _,
        "error("
    ),

    catch(
        term_string(Term, Data),
        _,
        fail
    ).


% Detecta el mensaje que indica que terminó el juego.
es_control(Data, juego_terminado) :-
    Data == "juego terminado".


% --------------------------------------------------
% MANEJAR MENSAJES DE CONTROL
% --------------------------------------------------

% Si el servidor envía:
%
% prompt(Mensaje, Opciones)
%
% muestra el mensaje y pide una respuesta al jugador.
handle_term(
    WebSocket,
    prompt(Mensaje, Opciones)
) :-
    format(
        '~w~n',
        [Mensaje]
    ),

    format(
        'Opciones: ~w~n',
        [Opciones]
    ),

    pedir_respuesta(
        WebSocket,
        Opciones
    ).


% Si el servidor envía un error, lo muestra
% y sigue escuchando mensajes.
handle_term(
    WebSocket,
    error(Detalle)
) :-
    format(
        'Error del servidor: ~w~n',
        [Detalle]
    ),

    escuchar_mensajes(WebSocket).


% Si terminó el juego, informa y cierra el WebSocket.
handle_term(
    WebSocket,
    juego_terminado
) :-
    format(
        'Juego terminado.~n',
        []
    ),

    ws_close(
        WebSocket,
        1000,
        'Cliente terminando'
    ).


% Si llega otro término de control,
% simplemente lo muestra y sigue escuchando.
handle_term(
    WebSocket,
    Term
) :-
    format(
        '~w~n',
        [Term]
    ),

    escuchar_mensajes(WebSocket).


% --------------------------------------------------
% PEDIR Y ENVIAR RESPUESTA
% --------------------------------------------------

% pedir_respuesta(+WebSocket, +Opciones)
%
% Pide una opción por teclado.
% Solo la envía si pertenece a la lista de opciones válidas.
pedir_respuesta(WebSocket, Opciones) :-
    repeat,

        format('Elige una opcion: '),

        % Lee la entrada como string.
        read_line_to_string(
            user_input,
            Linea
        ),

        % Intenta convertirla en término Prolog.
        % Si falla, Eleccion queda como error.
        catch(
            term_string(Eleccion, Linea),
            _,
            Eleccion = error
        ),

        (
            % Comprueba que la elección sea válida.
            member(Eleccion, Opciones)
        ->
            % Envía la elección al servidor.
            ws_send(
                WebSocket,
                prolog(Eleccion)
            ),

            % Después sigue escuchando mensajes.
            escuchar_mensajes(WebSocket)

        ;
            % Si no es válida, informa y vuelve a pedir.
            format(
                'Opcion no valida.~n',
                []
            ),

            fail
        ).