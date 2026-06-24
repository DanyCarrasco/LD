:- module(clienteia, [main/0]).
:- use_module(library(http/http_ssl_plugin)).
:- use_module(library(http/websocket)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(json)).
:- use_module(library(lists), [member/2, memberchk/2]).

:- dynamic historial/1.

% conecta el bot al servidor websocket y entra al bucle de escucha
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

% limpia la memoria de la partida guardando una lista vacia
inicializar_historial :-
    retractall(historial(_)),
    assertz(historial([])).

% comprueba que la variable de la api key exista o frena el programa
verificar_api_key :-
    api_key(_),
    !.
verificar_api_key :-
    throw(error(
        configuracion_faltante('defina GEMINI_API_KEY'),
        main/0
    )).

% obtiene la clave de gemini desde el sistema operativo
api_key(Clave) :-
    ( valor_entorno_como_string('GEMINI_API_KEY', Clave),
      Clave \= ""
    -> true
    ).

% espera un mensaje del websocket y lo envia a procesar
escuchar_mensajes(WebSocket) :-
    ws_receive(WebSocket, Message),
    procesar_mensaje(WebSocket, Message).

% clasifica el mensaje decidiendo si es cierre comando o texto normal
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

% detecta si un texto recibido es un comando especial del juego
es_control(Data, Term) :-
    sub_string(Data, 0, _, _, "prompt("),
    catch(term_string(Term, Data), _, fail).
es_control(Data, Term) :-
    sub_string(Data, 0, _, _, "error("),
    catch(term_string(Term, Data), _, fail).
es_control("juego terminado", juego_terminado).

% ejecuta la accion correspondiente al comando del servidor
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

% intenta decidir usando gemini o usa el respaldo si falla
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

% extrae el primer elemento de la lista para salir del paso
elegir_respaldo([Primera | _], Primera).

% orquesta toda la peticion post al modelo de lenguaje
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
    format('~n>>> ENVIANDO PETICION A GEMINI...~n', []),
    http_post(
        Url,
        json(Payload),
        Respuesta,
        [
            request_header('x-goog-api-key'=ApiKey),
            json_object(dict),
            status_code(-Codigo),
            timeout(10000)
        ]
    ),
    verificar_codigo_http(Codigo, Respuesta),
    extraer_texto_respuesta(Respuesta, TextoJSON),
    texto_a_eleccion(TextoJSON, Eleccion),    
    memberchk(Eleccion, Opciones).

% busca la version de gemini configurada o usa flash por defecto
modelo_configurado(Modelo) :-
    ( valor_entorno_como_string('GEMINI_MODEL', Configurado),
      Configurado \= ""
    -> Modelo = Configurado
    ;  Modelo = 'gemini-3.5-flash'
    ).

% lee una variable de entorno y la formatea como texto
valor_entorno_como_string(Nombre, Texto) :-
    getenv(Nombre, Valor),
    ( string(Valor)
    -> Texto = Valor
    ;  atom_string(Valor, Texto)
    ).

% fabrica el cuerpo del json requerido por la api de google
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
            maxOutputTokens: 800,
            temperature: 0.1
        }
    }.

% define el prompt maestro de una sola linea sin saltos
instrucciones_sistema(
"Sos un jugador experto y calculador de truco argentino. Tu objetivo es elegir la mejor estrategia para ganar analizando tu mano, el historial, las cartas jugadas y el marcador. REGLAS DEL JUEGO: Palos: e=espada, b=basto, o=oro, c=copa. Jerarquía (mayor a menor): e-1, b-1, e-7, o-7, cualquier 3, cualquier 2, c-1 u o-1, 12, 11, 10, c-7 o b-7, 6, 5, 4. Envido: Las figuras valen 0. Dos cartas del mismo palo suman 20 más sus valores nominales. REGLA ESTRICTA DE RESPUESTA (CRÍTICO): Recibirás una lista de 'opciones permitidas'. Tu respuesta debe ser ÚNICA Y EXCLUSIVAMENTE el texto exacto de una de esas opciones. PROHIBIDO: No agregues saludos, explicaciones, ni justificaciones. No uses formato Markdown (ni negritas, ni bloques de código). No uses comillas ni signos de puntuación extra. No pidas opiniones ni hagas preguntas. Ejemplo: Si las opciones son [jugar, cantar] y decides cantar, tu respuesta completa y absoluta debe ser: cantar").

% une el historial las opciones y el pedido en el texto final
construir_consulta(Contexto, Mensaje, OpcionesTexto, Consulta) :-
    format(
        string(Consulta),
        "historial visible de la partida:\n~s\n\npedido actual: ~w\nopciones permitidas: ~w\nelige exactamente una de esas opciones.",
        [Contexto, Mensaje, OpcionesTexto]
    ).

% se asegura de que la api devuelva codigo de exito
verificar_codigo_http(Codigo, _Respuesta) :-
    between(200, 299, Codigo),
    !.
verificar_codigo_http(Codigo, Respuesta) :-
    throw(error(respuesta_http_gemini(Codigo, Respuesta), consultar_llm/3)).

% navega el json de respuesta para sacar el texto limpio
extraer_texto_respuesta(Respuesta, Texto) :-
    get_dict(candidates, Respuesta, Candidatos),
    member(Candidato, Candidatos),
    get_dict(content, Candidato, Contenido),
    get_dict(parts, Contenido, Partes),
    member(Parte, Partes),
    get_dict(text, Parte, Texto),
    !.

% limpia el texto de la ia y lo convierte en un termino valido
texto_a_eleccion(Texto, Eleccion) :-
    limpiar_texto_modelo(Texto, Limpio),
    ( sub_string(Limpio, 0, 1, _, "{") ->
        catch(
            (
                atom_string(Atom, Limpio),
                atom_json_dict(Atom, Dict, []),
                get_dict(eleccion, Dict, EleccionTexto),
                term_string(Eleccion, EleccionTexto)
            ),
            _,
            fail
        )
    ;
        catch(
            term_string(Eleccion, Limpio),
            _,
            fail
        )
    ).

% quita saltos de linea y espacios en blanco de los bordes
limpiar_texto_modelo(Texto, Limpio) :-
    ( string(Texto)
    -> Base = Texto
    ;  term_string(Texto, Base)
    ),
    split_string(Base, "", " \t\n\r", [Limpio]).

% convierte diferentes tipos de datos a un atomo
normalizar_eleccion(Bruto, Eleccion) :-
    ( atom(Bruto)
    -> Eleccion = Bruto
    ; string(Bruto)
    -> atom_string(Eleccion, Bruto)
    ; number(Bruto)
    -> number_string(Bruto, Texto),
       atom_string(Eleccion, Texto)
    ).

% extrae el texto de un termino sin escapar las comillas
termino_como_string(Termino, Texto) :-
    term_string(Termino, Texto, [quoted(false)]).

% guarda una linea nueva en memoria borrando las mas viejas
guardar_en_historial(Dato) :-
    dato_como_string(Dato, Texto),
    historial(Anterior),
    conservar_ultimos(20, [Texto | Anterior], Nuevo),
    retractall(historial(_)),
    assertz(historial(Nuevo)).

% registra en el historial la eleccion que tomo el bot
guardar_decision(Mensaje, Opciones, Eleccion) :-
    format(
        string(Texto),
        'prompt: ~w. opciones: ~w. ia eligio: ~w.',
        [Mensaje, Opciones, Eleccion]
    ),
    guardar_en_historial(Texto).

% asegura que cualquier dato se transforme a string
dato_como_string(Dato, Texto) :-
    ( string(Dato)
    -> Texto = Dato
    ;  term_string(Dato, Texto)
    ).

% devuelve todas las lineas de memoria unidas en un solo texto
historial_como_texto(Texto) :-
    historial(Invertido),
    reverse(Invertido, Ordenado),
    atomics_to_string(Ordenado, "\n", Texto).

% recorta la lista para no exceder el maximo de lineas permitidas
conservar_ultimos(Maximo, Lista, Recortada) :-
    length(Prefijo, Maximo),
    append(Prefijo, _, Lista),
    !,
    Recortada = Prefijo.
conservar_ultimos(_, Lista, Lista).
