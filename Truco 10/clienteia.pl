:- module(clienteia_gemini, [main/0]).

:- use_module(library(http/websocket)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).
:- use_module(library(lists), [member/2, memberchk/2]).

:- dynamic historial/1.

% ------------------------------------------------------------------
% inicio del cliente ia
% ------------------------------------------------------------------

main :-
    inicializar_historial,
    verificar_api_key,
    Nombre = ia_llm,
    format('Conectando la ia a ws://localhost:8316/ws~n', []),
    http_open_websocket(
        'ws://localhost:8316/ws',
        WebSocket,
        []
    ),
    ws_send(WebSocket, prolog(join(Nombre))),
    escuchar_mensajes(WebSocket).

inicializar_historial :-
    retractall(historial(_)),
    assertz(historial([])).

verificar_api_key :-
    api_key(_),
    !.
verificar_api_key :-
    throw(error(
        configuracion_faltante('defina GEMINI_API_KEY'),
        main/0
    )).

api_key(Clave) :-
    ( valor_entorno_como_string('GEMINI_API_KEY', Clave),
      Clave \= ""
    -> true
    ).

% ------------------------------------------------------------------
% recepcion de mensajes del servidor
% ------------------------------------------------------------------

escuchar_mensajes(WebSocket) :-
    ws_receive(WebSocket, Message),
    procesar_mensaje(WebSocket, Message).

procesar_mensaje(_WebSocket, Message) :-
    Message.opcode == close,
    !,
    format('conexion cerrada por el servidor.~n', []).

procesar_mensaje(WebSocket, Message) :-
    es_control(Message.data, Term),
    !,
    manejar_control(WebSocket, Term).

procesar_mensaje(WebSocket, Message) :-
    format('~w~n', [Message.data]),
    guardar_en_historial(Message.data),
    escuchar_mensajes(WebSocket).

es_control(Data, Term) :-
    sub_string(Data, 0, _, _, "prompt("),
    catch(term_string(Term, Data), _, fail).

es_control(Data, Term) :-
    sub_string(Data, 0, _, _, "error("),
    catch(term_string(Term, Data), _, fail).

es_control("juego terminado", juego_terminado).

% ------------------------------------------------------------------
% respuesta automatica de la ia
% ------------------------------------------------------------------

manejar_control(WebSocket, prompt(Mensaje, Opciones)) :-
    !,
    format('prompt recibido: ~w~n', [Mensaje]),
    format('opciones validas: ~w~n', [Opciones]),
    elegir_opcion(Mensaje, Opciones, Eleccion),
    format('la ia eligio: ~w~n', [Eleccion]),
    guardar_decision(Mensaje, Opciones, Eleccion),
    ws_send(WebSocket, prolog(Eleccion)),
    escuchar_mensajes(WebSocket).

manejar_control(WebSocket, error(Detalle)) :-
    !,
    format('error del servidor: ~w~n', [Detalle]),
    escuchar_mensajes(WebSocket).

manejar_control(WebSocket, juego_terminado) :-
    !,
    format('juego terminado.~n', []),
    ws_close(WebSocket, 1000, 'cliente ia terminando').

manejar_control(WebSocket, Otro) :-
    format('mensaje de control: ~w~n', [Otro]),
    escuchar_mensajes(WebSocket).

% consulta al modelo. si falla o responde algo invalido, usa respaldo.
elegir_opcion(Mensaje, Opciones, Eleccion) :-
    catch(
        consultar_llm(Mensaje, Opciones, Propuesta),
        Error,
        (
            print_message(error, Error),
            fail
        )
    ),
    memberchk(Propuesta, Opciones),
    !,
    Eleccion = Propuesta.

elegir_opcion(_Mensaje, Opciones, Eleccion) :-
    elegir_respaldo(Opciones, Eleccion),
    format('se utilizo una decision de respaldo.~n', []).

% nunca envia una respuesta que el servidor vaya a rechazar.
elegir_respaldo([Primera | _], Primera).

% ------------------------------------------------------------------
% llamada a gemini
% ------------------------------------------------------------------

consultar_llm(Mensaje, Opciones, Eleccion) :-
    api_key(ApiKey),
    modelo_configurado(Modelo),
    historial_como_texto(Contexto),
    maplist(termino_como_string, Opciones, OpcionesTexto),
    instrucciones_sistema(Instrucciones),
    construir_consulta(Contexto, Mensaje, OpcionesTexto, Consulta),
    construir_payload(
        Modelo,
        Instrucciones,
        Consulta,
        Payload
    ),
    format(string(Url), 'https://generativelanguage.googleapis.com/v1beta/models/~w:generateContent', [Modelo]),
    http_post(
        Url,
        json(Payload),
        Respuesta,
        [
            request_header('x-goog-api-key'=ApiKey),
            json_object(dict),
            status_code(Codigo),
            timeout(40)
        ]
    ),
    verificar_codigo_http(Codigo, Respuesta),
    extraer_texto_respuesta(Respuesta, TextoJSON),
    format('respuesta cruda de gemini: ~q~n', [TextoJSON]),
    texto_a_eleccion(TextoJSON, EleccionTexto),
    term_string(Eleccion, EleccionTexto),
    memberchk(Eleccion, Opciones).

modelo_configurado(Modelo) :-
    ( valor_entorno_como_string('GEMINI_MODEL', Configurado),
      Configurado \= ""
    -> Modelo = Configurado
    ;  Modelo = 'gemini-3.5-flash'
    ).

valor_entorno_como_string(Nombre, Texto) :-
    getenv(Nombre, Valor),
    ( string(Valor)
    -> Texto = Valor
    ;  atom_string(Valor, Texto)
    ).

construir_payload(Modelo, Instrucciones, Consulta, Payload) :-
    Payload = _{
        model: Modelo,
        contents: [
            _{
                parts: [
                    _{text: Instrucciones},
                    _{text: Consulta}
                ]
            }
        ],
        generationConfig: _{
            maxOutputTokens: 16,
            temperature: 0.1
        }
    }.

instrucciones_sistema(
"sos un jugador experto de truco argentino. debes elegir una sola opcion valida para intentar ganar la partida. analiza la mano propia, los cantos, las cartas ya jugadas y el marcador que aparezcan en el historial. no inventes opciones. los palos se codifican como e=espada, b=basto, o=oro y c=copa. la fuerza de mayor a menor es: e-1, b-1, e-7, o-7, cualquier 3, cualquier 2, c-1 u o-1, 12, 11, 10, c-7 o b-7, 6, 5 y 4. para el envido, las figuras valen cero y dos cartas del mismo palo suman 20 mas sus valores. responde solo con una opcion valida, sin texto extra."
).

construir_consulta(Contexto, Mensaje, OpcionesTexto, Consulta) :-
    format(
        string(Consulta),
        "historial visible de la partida:\n~s\n\npedido actual: ~w\nopciones permitidas: ~w\nelige exactamente una de esas opciones.",
        [Contexto, Mensaje, OpcionesTexto]
    ).

verificar_codigo_http(Codigo, _Respuesta) :-
    between(200, 299, Codigo),
    !.
verificar_codigo_http(Codigo, Respuesta) :-
    throw(error(respuesta_http_gemini(Codigo, Respuesta), consultar_llm/3)).

% la respuesta REST trae candidates; buscamos el texto del primer part.
extraer_texto_respuesta(Respuesta, Texto) :-
    get_dict(candidates, Respuesta, Candidatos),
    member(Candidato, Candidatos),
    get_dict(content, Candidato, Contenido),
    get_dict(parts, Contenido, Partes),
    member(Parte, Partes),
    get_dict(text, Parte, Texto),
    !.

texto_a_eleccion(Texto, Eleccion) :-
    limpiar_texto_modelo(Texto, Limpio),
    ( sub_string(Limpio, 0, 1, _, "{") ->
        catch(
            (
                atom_string(Atom, Limpio),
                atom_json_dict(Atom, Dict, []),
                get_dict(eleccion, Dict, EleccionTexto),
                normalizar_eleccion(EleccionTexto, Eleccion)
            ),
            _,
            fail
        )
    ;
        catch(
            term_string(Bruto, Limpio),
            _,
            fail
        ),
        normalizar_eleccion(Bruto, Eleccion)
    ).

limpiar_texto_modelo(Texto, Limpio) :-
    ( string(Texto)
    -> Base = Texto
    ;  term_string(Texto, Base)
    ),
    string_trim(Base, Limpio).

normalizar_eleccion(Bruto, Eleccion) :-
    ( atom(Bruto)
    -> Eleccion = Bruto
    ; string(Bruto)
    -> atom_string(Eleccion, Bruto)
    ; number(Bruto)
    -> number_string(Bruto, Texto),
       atom_string(Eleccion, Texto)
    ).

termino_como_string(Termino, Texto) :-
    term_string(Termino, Texto, [quoted(false)]).

% ------------------------------------------------------------------
% historial local
% ------------------------------------------------------------------

% el motor envia la mano en un mensaje normal y luego envia prompt/2.
% por eso la ia necesita conservar los mensajes anteriores.
guardar_en_historial(Dato) :-
    dato_como_string(Dato, Texto),
    historial(Anterior),
    conservar_ultimos(20, [Texto | Anterior], Nuevo),
    retractall(historial(_)),
    assertz(historial(Nuevo)).

guardar_decision(Mensaje, Opciones, Eleccion) :-
    format(
        string(Texto),
        'prompt: ~w. opciones: ~w. ia eligio: ~w.',
        [Mensaje, Opciones, Eleccion]
    ),
    guardar_en_historial(Texto).

dato_como_string(Dato, Texto) :-
    ( string(Dato)
    -> Texto = Dato
    ;  term_string(Dato, Texto)
    ).

historial_como_texto(Texto) :-
    historial(Invertido),
    reverse(Invertido, Ordenado),
    atomics_to_string(Ordenado, "\n", Texto).

conservar_ultimos(Maximo, Lista, Recortada) :-
    length(Prefijo, Maximo),
    append(Prefijo, _, Lista),
    !,
    Recortada = Prefijo.
conservar_ultimos(_, Lista, Lista).
