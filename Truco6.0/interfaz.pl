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


%  obliga a que la entrada sea correcta para continuar
entrada_teclado(Mensaje, Opciones, Resultado):-
    format('~w (~w)\n', [Mensaje, Opciones]),
    catch(read(Entrada),_, Entrada = error),
    (member(Entrada, Opciones) ->
    Resultado = Entrada, !;
    write('Opcion no valida!\n'),
entrada_teclado(Mensaje, Opciones, Resultado)
).

% imprimir_lista(+Lista)
%
% Utilidad minima de depuracion e interfaz: imprime por consola la lista
% recibida. En este programa se usa para mostrar el historial acumulado de
% resultados de manos.
imprimir_lista(Lista) :-
    writeln(Lista).

% pedir_respuesta_envido(+Rival, -Respuesta)//
%
% Muestra la mano del rival por consola, solicita una respuesta al envido y
% unifica Respuesta con el termino ingresado por el usuario.
%
% Las respuestas esperadas son quiero, no_quiero o una resubida de envido.
pedir_respuesta_envido(Rival, Resp) -->
    state(S, S),
    {
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format("~w responde.\nMano: ~w~n", [Rival, Mano]),
        % format("Respuesta (quiero/no_quiero/envido/real_envido/falta_envido):~n", []),
        entrada_teclado("Respuesta",[quiero, no_quiero, envido, real_envido, falta_envido],Resp)
    }.


opciones_cantos_disponibles(Opciones) -->
    ( envido_habilitado ->
        { Opciones = [truco, retruco, vale4, envido, real_envido, falta_envido] }
    ;
        { Opciones = [truco, retruco, vale4] }
    ).


% envido_habilitado//
%
% Predicado auxiliar de solo lectura que resume la condicion principal para
% habilitar el envido: seguir en la primera mano, sin rechazo y sin un
% envido ya resuelto.
envido_habilitado -->
    state(S0, S0),
    {
        select(ronda([], _, none, envido(no_cantado, _, none)), S0, _)
    }.


% mensaje_cantos_disponibles(+Nombre)//
%
% Imprime por consola la lista de cantos que el jugador puede intentar.
% La decision se toma con envido_habilitado//0, que consulta el estado
% actual. Si el envido esta habilitado, muestra tambien sus variantes; de lo
% contrario, solo ofrece truco/retruco/vale4.
mensaje_cantos_disponibles(Nombre) -->
    ( envido_habilitado ->
        { format("~w canta (truco/retruco/vale4/envido/real_envido/falta_envido):~n", [Nombre]) }
    ;
        { format("~w canta (truco/retruco/vale4):~n", [Nombre]) }
    ).

% pedir_respuesta(+Rival, -Respuesta)//
%
% Solicita al rival su reaccion ante un canto de truco. Muestra su mano,
% imprime las opciones disponibles y lee desde consola la respuesta elegida.
pedir_respuesta(Rival, Resp) -->
    state(S, S),
    {
        member(jugadores(P0), S),
        member(jugador(Rival, Mano, _), P0),
        format("~w responde. Mano: ~w~n", [Rival, Mano]),
        % format("Respuesta (acepta/rechaza/truco/retruco/vale4):~n", []),
        entrada_teclado("Respuesta",[acepta, rechaza, truco, retruco, vale4],Resp)
    }.