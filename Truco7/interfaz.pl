:- module(interfaz, [
    entrada_teclado/3,
    imprimir_lista/1,
    pedir_respuesta//2,
    pedir_respuesta_envido//2,
    opciones_cantos_disponibles//1,
    mensaje_cantos_disponibles//1,
    envido_habilitado//0
]).

:- use_module(gestor_estado, [state//1, state//2]).


% pide una opcion valida
entrada_teclado(Mensaje, Opciones, Resultado):-
    format('~w (~w)\n', [Mensaje, Opciones]),
    catch(read(Entrada),_, Entrada = error),
    (member(Entrada, Opciones) ->
    Resultado = Entrada, !;
    write('Opcion no valida!\n'),
entrada_teclado(Mensaje, Opciones, Resultado)
).

% imprime una lista
imprimir_lista(Lista) :-
    writeln(Lista).

% pide respuesta al envido
pedir_respuesta_envido(Rival, Resp) -->
    state(S, S),
    {
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format("~w responde.\nMano: ~w~n", [Rival, Mano]),
        % format("Respuesta (quiero/no_quiero/envido/real_envido/falta_envido):~n", []),
        entrada_teclado("Respuesta",[quiero, no_quiero, envido, real_envido, falta_envido],Resp)
    }.

% devuelve los cantos disponibles
opciones_cantos_disponibles(Opciones) -->
    ( envido_habilitado ->
        { Opciones = [truco, retruco, vale4, envido, real_envido, falta_envido] }
    ;
        { Opciones = [truco, retruco, vale4] }
    ).


% true si el envido todavia puede jugarse
envido_habilitado -->
    state(S0, S0),
    {
        select(ronda([], _, none, envido(no_cantado, _, none)), S0, _)
    }.


% muestra los cantos posibles
mensaje_cantos_disponibles(Nombre) -->
    ( envido_habilitado ->
        { format("~w canta (truco/retruco/vale4/envido/real_envido/falta_envido):~n", [Nombre]) }
    ;
        { format("~w canta (truco/retruco/vale4):~n", [Nombre]) }
    ).

% pide respuesta a un canto de truco
pedir_respuesta(Rival, Resp) -->
    state(S, S),
    {
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format("~w responde. Mano: ~w~n", [Rival, Mano]),
        % format("Respuesta (acepta/rechaza/truco/retruco/vale4):~n", []),
        entrada_teclado("Respuesta",[acepta, rechaza, truco, retruco, vale4],Resp)
    }.
