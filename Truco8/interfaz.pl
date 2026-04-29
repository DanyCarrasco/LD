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
    Opciones \= [],
    repeat,
        format('~w (~w)\n', [Mensaje, Opciones]),
        read_line_to_string(user_input, Linea),
        catch(term_string(Entrada, Linea),_, Entrada = error),
        (member(Entrada, Opciones) ->
            Resultado = Entrada, !
        ;
            write('Opcion no valida!\n'),
            fail
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
        entrada_teclado("Respuesta",[quiero, no_quiero, envido, real_envido, falta_envido],Resp)
    }.

% devuelve los cantos disponibles
opciones_cantos_disponibles(Opciones) -->
    state(S0,S0),
    {
        %obtenemos el canto disponible de truco X
        member(ronda(_,_,_,_,trucos(X)),S0)
    },
    ( envido_habilitado ->
        { Opciones = [envido, real_envido, falta_envido | X ] }
    ;
        { Opciones = X }
    ).



% true si el envido todavia puede jugarse
envido_habilitado -->
    state(S0, S0),
    {
        select(ronda([], _, none, envido(no_cantado, _, none),_), S0, _)
    }.


% muestra los cantos posibles
mensaje_cantos_disponibles(Nombre) -->
    ( envido_habilitado ->
        { format("~w canta (truco/retruco/vale4/envido/real_envido/falta_envido):~n", [Nombre]) }
    ;
        { format("~w canta (truco/retruco/vale4):~n", [Nombre]) }
    ).


pedir_respuesta(Rival, Resp) -->
    state(S, S),
    {
        member(ronda(_, _, _, _, trucos(X)), S),
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format("~w responde. Mano: ~w~n", [Rival, Mano]),

        % Preparamos las opciones combinando las listas
        % Esto crea una lista como [acepta, rechaza, retruco]
        append([acepta, rechaza], X, OpcionesBasicas),
        append([acepta, rechaza, envido, real_envido, falta_envido], X, OpcionesConEnvido)
    },
    ( envido_habilitado ->
        { entrada_teclado("Respuesta", OpcionesConEnvido, Resp) }
    ;
        { entrada_teclado("Respuesta", OpcionesBasicas, Resp) }
    ).

