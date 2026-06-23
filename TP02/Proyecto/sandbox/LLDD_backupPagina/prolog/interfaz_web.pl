:- module(interfaz_web, [
    entrada_web/4,
    pedir_respuesta//2,
    pedir_respuesta_envido//2,
    opciones_cantos_disponibles//1,
    mensaje_cantos_disponibles//1,
    envido_habilitado//0,
    imprimir_lista/1,
    notificar_manos_web//0,
    notificar_puntaje//0
]).

:- use_module(library(wasm)).
:- use_module(gestor_estado, [state//1, state//2]).
:- use_module(estado_jugador, [es_jugador_local/1]).

% ============================================================
%  entrada_web/4
%  Equivalente web de entrada_teclado/3, consciente de DOS
%  pestanas distintas (cada una con su propio Prolog WASM).
%
%  Jugador  -> de quien es el turno de responder (jugador1/jugador2)
%  Mensaje  -> texto a mostrar
%  Opciones -> lista de TERMINOS validos. Pueden ser atomos simples
%              (truco, acepta) o compuestos (cartas como e-1)
%  Resultado -> la opcion elegida, ya validada y con su tipo original
%
%  Decision clave:
%    - si Jugador ES el que corre en ESTA pestana (es_jugador_local),
%      mostramos botones reales y esperamos un click humano.
%    - si Jugador es el RIVAL, no mostramos botones: esperamos un
%      mensaje que llegue por WebSocket, via esperarJugadaRemota().
% ============================================================

entrada_web(Jugador, Mensaje, Opciones, Resultado) :-
    Opciones \= [],
    % term_to_atom/2 funciona tanto para atomos simples (truco)
    % como para terminos compuestos (cartas: e-1, b-7).
    % atomic_list_concat/3 directo NO serviria con cartas, porque
    % exige elementos atomicos puros.
    maplist(termino_a_atomo, Opciones, OpcionesAtomos),
    atomic_list_concat(OpcionesAtomos, ',', OpcionesAtomo),
    atom_string(OpcionesAtomo, OpcionesStr),
    ( string(Mensaje) -> MensajeStr = Mensaje ; atom_string(Mensaje, MensajeStr) ),
    atom_string(Jugador, JugadorStr),
    ( es_jugador_local(Jugador) ->
        Promise := mostrarOpciones(MensajeStr, OpcionesStr)
    ;
        Promise := esperarJugadaRemota(JugadorStr, MensajeStr, OpcionesStr)
    ),
    await(Promise, RespuestaJS),
    % Reconstruimos el termino original (atomo o compuesto) a partir
    % del texto recibido de JS.
    atom_string(RespuestaTexto, RespuestaJS),
    term_to_atom(RespuestaTermino, RespuestaTexto),
    (   member(RespuestaTermino, Opciones)
    ->  Resultado = RespuestaTermino
    ;   _ := alertaOpcionInvalida(RespuestaJS),
        entrada_web(Jugador, Mensaje, Opciones, Resultado)
    ).


% imprime una lista (queda igual; loguea a consola del navegador)
imprimir_lista(Lista) :-
    writeln(Lista).


% convierte CUALQUIER termino Prolog (atomo simple o compuesto)
% a un atomo de texto, para poder mandarlo a JS.
termino_a_atomo(Termino, Atomo) :-
    term_to_atom(Termino, Atomo).


% ============================================================
%  pedir_respuesta_envido//2
% ============================================================
pedir_respuesta_envido(Rival, Resp) -->
    state(S, S),
    {
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format("~w responde.\nMano: ~w~n", [Rival, Mano]),
        entrada_web(Rival, "Respuesta", [quiero, no_quiero, envido, real_envido, falta_envido], Resp)
    }.


% ============================================================
%  opciones_cantos_disponibles//1
%  Usa el estado dinamico de trucos(X): a medida que se canta
%  truco/retruco/vale4, X se va reduciendo (step_estado_truco
%  en gestor_estado.pl).
% ============================================================
opciones_cantos_disponibles(Opciones) -->
    state(S0, S0),
    {
        member(ronda(_, _, _, _, trucos(X), _), S0)
    },
    ( envido_habilitado ->
        { Opciones = [envido, real_envido, falta_envido | X] }
    ;
        { Opciones = X }
    ).


envido_habilitado -->
    state(S0, S0),
    {
        select(ronda([], _, none, envido(no_cantado, _, none), _, _), S0, _)
    }.


mensaje_cantos_disponibles(Nombre) -->
    ( envido_habilitado ->
        { format("~w canta (truco/retruco/vale4/envido/real_envido/falta_envido):~n", [Nombre]) }
    ;
        { format("~w canta (truco/retruco/vale4):~n", [Nombre]) }
    ).


% ============================================================
%  pedir_respuesta//2
%  Las opciones de respuesta a un canto incluyen "subir la
%  apuesta" segun lo que quede disponible en trucos(X).
% ============================================================
pedir_respuesta(Rival, Resp) -->
    state(S, S),
    {
        member(ronda(_, _, _, _, trucos(X), _), S),
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format("~w responde. Mano: ~w~n", [Rival, Mano]),
        append([acepta, rechaza], X, OpcionesBasicas),
        append([acepta, rechaza, envido, real_envido, falta_envido], X, OpcionesConEnvido)
    },
    ( envido_habilitado ->
        { entrada_web(Rival, "Respuesta", OpcionesConEnvido, Resp) }
    ;
        { entrada_web(Rival, "Respuesta", OpcionesBasicas, Resp) }
    ).


% Exporta este predicado al principio del archivo
% en la directiva :- module(interfaz_web, [..., notificar_manos_web//0]).

% ============================================================
%  notificar_manos_web//0
%  Avisa al frontend qué cartas le tocaron a cada jugador.
% ============================================================
notificar_manos_web -->
    state(S, S),
    {
        member(jugadores(P0), S),
        maplist(notificar_mano, P0)
    }.

notificar_mano(jugador(Nombre, Mano, _)) :-
    maplist(termino_a_atomo, Mano, ManoAtomos),
    atomic_list_concat(ManoAtomos, ',', ManoAtomo),

    atom_string(ManoAtomo, ManoStr),
    atom_string(Nombre, NombreStr),

    ( es_jugador_local(Nombre) ->
        _ := renderizarMano(ManoStr) 
    ;
        _ := enviarManoRival(NombreStr, ManoStr)
    ).


% ============================================================
%  notificar_puntaje//0
%  Avisa al frontend el puntaje ACTUAL de cada jugador, para que
%  fosforos.js redibuje las "tranqueras". Se llama cada vez que
%  gestor_estado.pl modifica los puntos (canto rechazado, envido
%  resuelto, ronda ganada, etc).
% ============================================================
notificar_puntaje -->
    state(S, S),
    {
        member(jugadores(P0), S),
        maplist(notificar_puntaje_jugador, P0)
    }.

notificar_puntaje_jugador(jugador(Nombre, _Mano, Puntos)) :-
    atom_string(Nombre, NombreStr),
    _ := actualizarPuntaje(NombreStr, Puntos).