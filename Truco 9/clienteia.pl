:- module(clienteia, [main/0]).

:- use_module(library(http/websocket)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).
:- use_module(library(lists), [member/2, memberchk/2]).

:- dynamic historial/1.


main :-
    inicializar_historial,
    verificar_api_key,
    Nombre = ia_llm,
    format('Conectando la IA a ws://localhost:8316/ws~n', []),
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
    ( valor_entorno_como_string('OPENAI_API_KEY', Clave),
      Clave \= ""
    -> true
    ;  throw(error(
           configuracion_faltante('Defina la variable OPENAI_API_KEY'),
           main/0
       ))
    ).

esccuchar_mensajes(WebSocket) :-
    ws_receive(WebSocket, Message),
    procesar_mensaje(WebSocket, Message).

procesar_mensaje(_WebSocket, Message) :-
    Message.opcode == close,
    !,
    format('Conexión cerrada por el servidor.~n', []).

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

%Respuesta de la IA

manejar_control(WebSocket, prompt(Mensaje, Opciones)) :-
    !,
    format('Prompt recibido: ~w~n', [Mensaje]),
    format('Opciones validas: ~w~n', [Opciones]),
    elegir_opcion(Mensaje, Opciones, Eleccion),
    format('La IA eligio: ~w~n', [Eleccion]),
    guardar_decision(Mensaje, Opciones, Eleccion),
    ws_send(WebSocket, prolog(Eleccion)),
    escuchar_mensajes(WebSocket).

manejar_control(WebSocket, error(Detalle)) :-
    !,
    format('Error del servidor: ~w~n', [Detalle]),
    escuchar_mensajes(WebSocket).

manejar_control(WebSocket, juego_terminado) :-
    !,
    format('Juego terminado.~n', []),
    ws_close(WebSocket, 1000, 'Cliente IA terminando').

manejar_control(WebSocket, Otro) :-
    format('Mensaje de control: ~w~n', [Otro]),
    escuchar_mensajes(WebSocket).

% Consulta al modelo. Si la llamada falla o el modelo devuelve algo
% invalido, se usa una opcion valida de respaldo para no bloquear la partida.
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
    format('Se utilizo una decision de respaldo.~n', []).

% Nunca envia una respuesta que el servidor vaya a rechazar.
elegir_respaldo([Primera | _], Primera).

% ------------------------------------------------------------------
% LLAMADA A OPENAI
% ------------------------------------------------------------------

consultar_llm(Mensaje, Opciones, Eleccion) :-
    valor_entorno_como_string('OPENAI_API_KEY', ApiKey),
    modelo_configurado(Modelo),
    historial_como_texto(Contexto),
    maplist(termino_como_string, Opciones, OpcionesTexto),
    instrucciones_sistema(Instrucciones),
    construir_consulta(Contexto, Mensaje, OpcionesTexto, Consulta),
    construir_payload(
        Modelo,
        Instrucciones,
        Consulta,
        OpcionesTexto,
        Payload
    ),
    format(string(Autorizacion), 'Bearer ~s', [ApiKey]),
    http_post(
        'https://api.openai.com/v1/responses',
        json(Payload),
        Respuesta,
        [
            request_header('Authorization'=Autorizacion),
            json_object(dict),
            status_code(Codigo),
            timeout(40)
        ]
    ),
    verificar_codigo_http(Codigo, Respuesta),
    extraer_texto_respuesta(Respuesta, TextoJSON),
    texto_json_a_dict(TextoJSON, DecisionJSON),
    get_dict(eleccion, DecisionJSON, EleccionTexto),
    term_string(Eleccion, EleccionTexto),
    memberchk(Eleccion, Opciones).

modelo_configurado(Modelo) :-
    ( valor_entorno_como_string('OPENAI_MODEL', Configurado),
      Configurado \= ""
    -> Modelo = Configurado
    ;  Modelo = "gpt-5.4-mini"
    ).

valor_entorno_como_string(Nombre, Texto) :-
    getenv(Nombre, Valor),
    ( string(Valor)
    -> Texto = Valor
    ;  atom_string(Valor, Texto)
    ).

construir_payload(Modelo, Instrucciones, Consulta, OpcionesTexto, Payload) :-
    Payload = _{
        model: Modelo,
        input: [
            _{role: "system", content: Instrucciones},
            _{role: "user", content: Consulta}
        ],
        reasoning: _{effort: "low"},
        max_output_tokens: 80,
        text: _{
            format: _{
                type: "json_schema",
                name: "decision_truco",
                strict: true,
                schema: _{
                    type: "object",
                    properties: _{
                        eleccion: _{
                            type: "string",
                            enum: OpcionesTexto
                        }
                    },
                    required: ["eleccion"],
                    additionalProperties: false
                }
            }
        }
    }.

instrucciones_sistema(
"Sos un jugador experto de Truco argentino. Debes elegir una sola opcion valida para intentar ganar la partida. Analiza la mano propia, los cantos, las cartas ya jugadas y el marcador que aparezcan en el historial. No inventes opciones. Los palos se codifican como e=espada, b=basto, o=oro y c=copa. La fuerza de mayor a menor es: e-1, b-1, e-7, o-7, cualquier 3, cualquier 2, c-1 u o-1, 12, 11, 10, c-7 o b-7, 6, 5 y 4. Para el envido, las figuras valen cero y dos cartas del mismo palo suman 20 mas sus valores. Devuelve solamente el objeto JSON solicitado."
).

construir_consulta(Contexto, Mensaje, OpcionesTexto, Consulta) :-
    format(
        string(Consulta),
        "Historial visible de la partida:\n~s\n\nPedido actual: ~w\nOpciones permitidas: ~w\nElegí exactamente una de esas opciones.",
        [Contexto, Mensaje, OpcionesTexto]
    ).

verificar_codigo_http(Codigo, _Respuesta) :-
    between(200, 299, Codigo),
    !.
verificar_codigo_http(Codigo, Respuesta) :-
    throw(error(respuesta_http_openai(Codigo, Respuesta), consultar_llm/3)).

% La respuesta REST contiene una lista output; buscamos el contenido
% cuyo tipo sea output_text.
extraer_texto_respuesta(Respuesta, Texto) :-
    get_dict(output, Respuesta, Salidas),
    member(Salida, Salidas),
    get_dict(content, Salida, Contenidos),
    member(Contenido, Contenidos),
    get_dict(type, Contenido, "output_text"),
    get_dict(text, Contenido, Texto),
    !.


texto_json_a_dict(Texto, Dict) :-
    ( string(Texto)
    -> atom_string(Atom, Texto)
    ;  Atom = Texto
    ),
    atom_json_dict(Atom, Dict, []).

termino_como_string(Termino, Texto) :-
    term_string(Termino, Texto, [quoted(false)]).


% El motor envia la mano en un mensaje normal y luego envia prompt/2.
% Por eso la IA necesita conservar los mensajes anteriores.
guardar_en_historial(Dato) :-
    dato_como_string(Dato, Texto),
    historial(Anterior),
    conservar_ultimos(20, [Texto | Anterior], Nuevo),
    retractall(historial(_)),
    assertz(historial(Nuevo)).

guardar_decision(Mensaje, Opciones, Eleccion) :-
    format(
        string(Texto),
        'Prompt: ~w. Opciones: ~w. IA eligio: ~w.',
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
