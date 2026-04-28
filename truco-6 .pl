:- use_module(library(random)).
:- use_module(library(clpfd)).

:- use_module(mazoTruco).

% state(-Estado)//
%
% No terminal DCG que lee el estado actual y lo deja intacto. Se usa cuando
% una regla necesita inspeccionar el estado sin modificarlo.
%
% Como el programa modela la partida con una DCG, el "input" y el "output"
% de la gramatica no son tokens tradicionales sino una lista que contiene un
% unico elemento: el estado completo del juego.
state(S), [S] --> [S].

% state(-EstadoAnterior, +EstadoNuevo)//
%
% No terminal DCG basico para actualizar estado. Toma el estado de entrada,
% lo unifica con EstadoAnterior, y lo reemplaza por EstadoNuevo en la salida.
%
% Casi todas las transformaciones de la partida terminan apoyandose en esta
% regla, ya sea directamente o a traves de predicados auxiliares.
state(S0, S), [S] --> [S0].

% jugadores(-JugadoresAntes, +JugadoresDespues)//
%
% Atajo DCG para reemplazar especificamente el termino jugadores(...)
% dentro del estado global, conservando intacto el resto de los componentes.
%
% Es util cuando una transicion necesita modificar solo las manos o puntajes
% sin reconstruir manualmente mazo(...) o ronda(...).
jugadores(P0, P), [S] -->
    [S0],
    { select(jugadores(P0), S0, S1), S = [jugadores(P)|S1] }.

% puntos_por_canto(+Canto, -Puntos)
%
% Tabla fija del puntaje que vale una ronda cuando el canto fue aceptado y
% luego se resuelve normalmente. truco vale 2, retruco 3 y vale4 4.
puntos_por_canto(truco, 2).
puntos_por_canto(retruco, 3).
puntos_por_canto(vale4, 4).

% puntos_por_rechazo(+Canto, -Puntos)
%
% Tabla fija del puntaje otorgado al jugador que hizo el canto cuando el
% rival no acepta la subida. El premio es menor que el valor del canto
% aceptado porque la ronda se corta antes de jugarse completa.
puntos_por_rechazo(truco, 1).
puntos_por_rechazo(retruco, 2).
puntos_por_rechazo(vale4, 3).

% es_canto(+Canto)
%
% Predicado de pertenencia para los cantos del eje truco-retruco-vale4.
% Se usa para validar entradas del jugador y para distinguir estos cantos
% de los relacionados con el envido.
es_canto(truco).
es_canto(retruco).
es_canto(vale4).

% nivel_canto(+Canto, -Nivel)
%
% Asigna una altura numerica a cada estado del canto para poder comparar si
% una propuesta nueva realmente supera a la actual. El estado ninguno
% representa que aun no se canto nada en la ronda.
nivel_canto(ninguno, 0).
nivel_canto(truco, 1).
nivel_canto(retruco, 2).
nivel_canto(vale4, 3).

% canto_supera(+Nuevo, +Actual)
%
% Tiene exito cuando Nuevo representa una subida valida respecto de Actual.
% La comparacion se hace traduciendo ambos cantos a sus niveles numericos.
canto_supera(Nuevo, Actual) :-
    nivel_canto(Nuevo, N1),
    nivel_canto(Actual, N2),
    N1 > N2.

% rival(+Jugador, -Rival)
%
% Relacion fija entre los dos jugadores del programa. Como el modelo solo
% contempla partidas de a dos, este predicado funciona como un mapeo directo
% entre cada nombre y su oponente.
rival(jugador1, jugador2).
rival(jugador2, jugador1).

% puntaje_objetivo(-Puntaje)
%
% Define cuantos puntos hacen falta para ganar la partida. En este archivo
% esta fijado en 15, que corresponde a una partida corta tradicional.
puntaje_objetivo(15).

% estado_envido_inicial(-EstadoEnvido)
%
% Construye el estado base del subsystema de envido para una ronda nueva.
% Indica que todavia no hubo cantos de envido, no hay secuencia registrada
% y tampoco existe un rechazo pendiente.
estado_envido_inicial(envido(no_cantado, [], none)).

% asegurar_ronda//
%
% Compatibiliza el estado de ronda con la estructura actual de cuatro
% argumentos: ronda(Resultados, CantoActual, Rechazo, EstadoEnvido).
%
% Si el estado contiene una version vieja de ronda/1, ronda/2 o ronda/3,
% esta regla la reemplaza por la forma moderna agregando valores por defecto.
% Si la ronda ya esta normalizada, deja el estado intacto.
asegurar_ronda -->
    state(S0, S),
    {
        ( select(ronda(Resultados), S0, S1) ->
            estado_envido_inicial(EstadoEnvido),
            S = [ronda(Resultados, ninguno, none, EstadoEnvido)|S1]
        ; select(ronda(Resultados, C), S0, S1) ->
            estado_envido_inicial(EstadoEnvido),
            S = [ronda(Resultados, C, none, EstadoEnvido)|S1]
        ; select(ronda(Resultados, C, R), S0, S1) ->
            estado_envido_inicial(EstadoEnvido),
            S = [ronda(Resultados, C, R, EstadoEnvido)|S1]
        ; S = S0
        )
    }.

% set_ronda_canto(+Canto)//
%
% Actualiza el canto vigente de la ronda sin tocar los resultados ya jugados,
% la marca de rechazo ni el estado del envido. Se usa cuando un canto fue
% aceptado y la ronda debe pasar a jugarse por mas puntos.
set_ronda_canto(Canto) -->
    state(S0, S),
    { select(ronda(Resultados, _, R, E), S0, S1),
      S = [ronda(Resultados, Canto, R, E)|S1] }.

% set_rechazo(+Jugador)//
%
% Marca en la ronda que la secuencia de cantos termino por rechazo y guarda
% el nombre del jugador que se beneficia con ese rechazo. El resto de la
% informacion de la ronda permanece igual.
set_rechazo(Jug) -->
    state(S0, S),
    { select(ronda(Resultados, C, _, E), S0, S1),
      S = [ronda(Resultados, C, rechazo(Jug), E)|S1] }.

% set_estado_envido(+EstadoEnvido)//
%
% Reemplaza exclusivamente el cuarto componente de ronda(...), que modela la
% negociacion y resolucion del envido. Se usa al cerrar un envido aceptado o
% rechazado para dejar asentado que ya no puede volver a cantarse.
set_estado_envido(EstadoEnvido) -->
    state(S0, S),
    { select(ronda(Resultados, C, R, _), S0, S1),
      S = [ronda(Resultados, C, R, EstadoEnvido)|S1] }.

% puede_cantar_estado(+NuevoCanto)//
%
% Verifica sobre el estado actual si un canto de truco es legal.
%
% Las condiciones son:
% 1. la ronda todavia no debe estar cerrada por rechazo;
% 2. el termino propuesto debe ser un canto reconocido;
% 3. debe superar al canto vigente y no repetirlo ni bajarlo.
%
% Como DCG de solo lectura, no modifica el estado: simplemente tiene exito
% o falla segun el contenido actual de ronda(...).
puede_cantar_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda(_, CantoActual, none, _), S0, _),
        es_canto(Nuevo),
        canto_supera(Nuevo, CantoActual)
    }.

% es_canto_envido(+Canto)
%
% Catalogo de cantos pertenecientes a la familia del envido. Se usa tanto
% para validar input como para decidir si una accion debe resolverse con la
% logica de envido o con la logica del truco.
es_canto_envido(envido).
es_canto_envido(real_envido).
es_canto_envido(falta_envido).



% puede_cantar_envido_estado(+NuevoCanto)//
%
% Determina si un nuevo canto de envido es valido segun la situacion actual.
%
% Solo habilita el envido cuando:
% 1. aun no se jugo ninguna mano, es decir, Resultados = [];
% 2. la ronda no fue cerrada por rechazo;
% 3. el estado del envido sigue en no_cantado;
% 4. la nueva propuesta encaja en la secuencia de cantos ya realizada.
puede_cantar_envido_estado(Nuevo) -->
    state(S0, S0),
    {
        select(ronda([], _, none, envido(no_cantado, Cantos, none)), S0, _),
        es_canto_envido(Nuevo),
        canto_envido_valido(Cantos, Nuevo)
    }.

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

% canto_envido_valido(+CantosPrevios, +NuevoCanto)
%
% Modela la secuencia permitida de cantos de envido. Cada hecho representa
% una transicion legal desde una historia previa hacia un nuevo canto.
%
% Por ejemplo, desde [] se puede cantar envido, real_envido o falta_envido;
% desde [envido] se puede volver a decir envido o subir a real/falta; y asi
% sucesivamente.
canto_envido_valido([], envido).
canto_envido_valido([], real_envido).
canto_envido_valido([], falta_envido).
canto_envido_valido([envido], envido).
canto_envido_valido([envido], real_envido).
canto_envido_valido([envido], falta_envido).
canto_envido_valido([real_envido], falta_envido).
canto_envido_valido([envido, envido], real_envido).
canto_envido_valido([envido, envido], falta_envido).
canto_envido_valido([envido, real_envido], falta_envido).

% valor_envido_mano(+Mano, -Valor)
%
% Calcula el mejor puntaje de envido para una mano de tres cartas.
%
% Estrategia:
% 1. genera todos los pares de cartas del mismo palo;
% 2. si existe al menos uno, toma el maximo valor de esos pares;
% 3. si no existe ninguno, toma la carta individual de mayor valor_envido.
valor_envido_mano(Mano, Valor) :-
    findall(Puntos, puntos_par_mismo_palo(Mano, Puntos), Pares),
    ( Pares \= [] ->
        max_list(Pares, Valor)
    ; findall(V,
              (member(_Palo-Numero, Mano), valor_envido_numero(Numero, V)),
              Valores),
      max_list(Valores, Valor)
    ).

% puntos_par_mismo_palo(+Mano, -Puntos)
%
% Genera posibles puntajes de envido formados por dos cartas del mismo palo.
% El valor se calcula como 20 + valor de la primera carta + valor de la
% segunda, segun la regla habitual del envido.
puntos_par_mismo_palo(Mano, Puntos) :-
    select(Palo-N1, Mano, Resto),
    member(Palo-N2, Resto),
    valor_envido_numero(N1, V1),
    valor_envido_numero(N2, V2),
    Puntos is 20 + V1 + V2.

% puntos_falta_envido(+Jugadores, -Puntos)
%
% Calcula cuantos puntos otorga una falta envido aceptada. En este modelo se
% toma la distancia entre el lider actual de la partida y el puntaje objetivo.
puntos_falta_envido([jugador(_, _, P1), jugador(_, _, P2)], Puntos) :-
    puntaje_objetivo(Objetivo),
    Lider is max(P1, P2),
    Puntos is Objetivo - Lider.

% puntos_envido_aceptado(+Cantos, +Jugadores, -Puntos)
%
% Devuelve el premio correspondiente a una secuencia de envido que fue
% aceptada. Si el ultimo canto es falta_envido, el puntaje depende del estado
% de la partida; en los demas casos se usa una tabla fija.
puntos_envido_aceptado(Cantos, Jugadores, Puntos) :-
    last(Cantos, falta_envido),
    !,
    puntos_falta_envido(Jugadores, Puntos).
puntos_envido_aceptado([envido], _, 2).
puntos_envido_aceptado([real_envido], _, 3).
puntos_envido_aceptado([envido, envido], _, 4).
puntos_envido_aceptado([envido, real_envido], _, 5).
puntos_envido_aceptado([envido, envido, real_envido], _, 7).

% puntos_envido_rechazado(+Cantos, +Jugadores, -Puntos)
%
% Calcula el premio cuando la secuencia de envido es rechazada.
%
% Si solo hubo un canto, el premio es 1. Si hubo una cadena mas larga, el
% premio equivale al valor que tendria aceptada la secuencia previa al ultimo
% canto, que es exactamente el que quedo "ganado" por no querer.
puntos_envido_rechazado([_], _, 1) :- !.
puntos_envido_rechazado(Cantos, Jugadores, Puntos) :-
    append(Previos, [_], Cantos),
    puntos_envido_aceptado(Previos, Jugadores, Puntos).

% resolver_envido_en_turno(+Jugador, +Canto)//
%
% Procesa el momento en que un jugador inicia o continua una secuencia de
% envido durante su turno.
%
% Flujo:
% 1. usa puede_cantar_envido_estado//1 para validar el canto leyendo el
%    estado actual sin modificarlo;
% 2. si el canto es valido, relee el estado para recuperar la secuencia de
%    cantos ya hecha y construir la nueva lista;
% 3. determina quien es el rival que debe responder;
% 4. pide la respuesta y delega la resolucion completa a
%    resolver_respuesta_envido//4.
%
% Si el canto es invalido, solo informa el error y no altera el estado.
resolver_envido_en_turno(J, Canto) -->
    ( puede_cantar_envido_estado(Canto) ->
        state(S, S),
        {
            select(ronda(_, _, _, envido(_, CantosPrevios, _)), S, _),
            append(CantosPrevios, [Canto], CantosNuevos),
            format("~w canta ~w~n", [J, Canto]),
            rival(J, R)
        },
        pedir_respuesta_envido(R, Resp),
        resolver_respuesta_envido(J, R, CantosNuevos, Resp)
    ;
        { writeln("Envido invalido o no permitido.") }
    ).

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
        format("Respuesta (quiero/no_quiero/envido/real_envido/falta_envido):~n", []),
        read(Resp)
    }.

% resolver_respuesta_envido(+Cantor, +Rival, +Cantos, +Respuesta)//
%
% Resuelve la respuesta dada a una secuencia de envido.
%
% Casos:
% 1. quiero: calcula el ganador del envido y suma los puntos;
% 2. no_quiero: premia al cantor segun el rechazo;
% 3. resubida valida: invierte los roles y vuelve a pedir respuesta;
% 4. respuesta invalida: se toma como no_quiero por defecto.
resolver_respuesta_envido(Cantor, Rival, Cantos, Resp) -->
    ( { Resp == quiero } ->
        premiar_envido_aceptado(Cantos),
        set_estado_envido(envido(resuelto, Cantos, none))
    ; { Resp == no_quiero } ->
        premiar_envido_rechazado(Cantor, Cantos),
        set_estado_envido(envido(resuelto, Cantos, none)),
        { format("~w no quiso el envido.~n", [Rival]) }
    ; { es_canto_envido(Resp), canto_envido_valido(Cantos, Resp) } ->
        { format("~w resube a ~w~n", [Rival, Resp]),
          append(Cantos, [Resp], CantosNuevos),
          true },
        pedir_respuesta_envido(Cantor, Resp2),
        resolver_respuesta_envido(Rival, Cantor, CantosNuevos, Resp2)
    ; { writeln("Respuesta invalida: no_quiero por defecto.") },
      premiar_envido_rechazado(Cantor, Cantos),
      set_estado_envido(envido(resuelto, Cantos, none))
    ).

% premiar_envido_aceptado(+Cantos)//
%
% Evalua las manos de ambos jugadores, determina quien gana el envido y suma
% el puntaje correspondiente a la secuencia de cantos aceptada.
%
% En caso de empate, gana el primer jugador de la lista, porque la condicion
% usada es P1 >= P2.
premiar_envido_aceptado(Cantos) -->
    state(S, S),
    {
        select(jugadores([J1, J2]), S, _),
        J1 = jugador(N1, Mano1, _),
        J2 = jugador(N2, Mano2, _),
        valor_envido_mano(Mano1, P1),
        valor_envido_mano(Mano2, P2),
        puntos_envido_aceptado(Cantos, [J1, J2], Pts),
        ( P1 >= P2 -> Ganador = N1 ; Ganador = N2 ),
        format("~w tiene ~w de envido.~n", [N1, P1]),
        format("~w tiene ~w de envido.~n", [N2, P2]),
        format("~w gana el envido y suma ~w puntos.~n", [Ganador, Pts])
    },
    sumar_puntos_a_jugador(Ganador, Pts).

% premiar_envido_rechazado(+Cantor, +Cantos)//
%
% Otorga al cantor los puntos que corresponden cuando el rival no quiere el
% envido. El valor depende de la secuencia de cantos acumulada hasta el
% momento del rechazo.
premiar_envido_rechazado(Cantor, Cantos) -->
    state(S, S),
    {
        select(jugadores([J1, J2]), S, _),
        puntos_envido_rechazado(Cantos, [J1, J2], Pts),
        format("~w gana ~w puntos por el envido no querido.~n", [Cantor, Pts])
    },
    sumar_puntos_a_jugador(Cantor, Pts).

% resolver_canto_en_turno(+Jugador, +Canto)//
%
% Procesa un canto del eje truco/retruco/vale4 realizado durante un turno.
%
% La validacion se hace con puede_cantar_estado//1, que inspecciona la ronda
% actual sin modificarla. Si el canto es legal, identifica al rival y abre
% la secuencia de respuesta. Si no lo es, informa el error y deja el estado
% sin cambios.
resolver_canto_en_turno(J, Canto) -->
    ( { es_canto(Canto) },
      puede_cantar_estado(Canto) ->
        { format("~w canta ~w~n", [J, Canto]),
          rival(J, R)
        },
        pedir_respuesta(R, Resp),
        resolver_respuesta_canto(J, R, Canto, Resp)
    ;
        { writeln("Canto invalido o no permitido.") }
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
        format("Respuesta (acepta/rechaza/truco/retruco/vale4):~n", []),
        read(Resp)
    }.

% resolver_respuesta_canto(+Cantor, +Rival, +Canto, +Respuesta)//
%
% Resuelve la respuesta del rival a un canto de truco.
%
% Casos:
% 1. acepta: la ronda pasa a jugarse por el valor del canto;
% 2. rechaza: el cantor gana puntos por rechazo y la ronda se cierra;
% 3. resube: el rival hace una subida valida y se invierten los roles;
% 4. invalida: se interpreta como rechazo por defecto.
resolver_respuesta_canto(Cantor, Rival, Canto, Resp) -->
    ( { Resp == acepta } ->
        set_ronda_canto(Canto),
        { puntos_por_canto(Canto, P),
          format("Se juega a ~w puntos.~n", [P]) }
    ; { Resp == rechaza } ->
        { puntos_por_rechazo(Canto, Pts) },
        sumar_puntos_a_jugador(Cantor, Pts),
        set_rechazo(Cantor),
        { format("~w rechazo. ~w gana ~w puntos.~n", [Rival, Cantor, Pts]) }
    ; { es_canto(Resp), canto_supera(Resp, Canto) } ->
        { format("~w resube a ~w~n", [Rival, Resp]) },
        pedir_respuesta(Cantor, Resp2),
        resolver_respuesta_canto(Rival, Cantor, Resp, Resp2)
    ; { writeln("Respuesta invalida: rechazo por defecto."),
        puntos_por_rechazo(Canto, Pts) },
      sumar_puntos_a_jugador(Cantor, Pts),
      set_rechazo(Cantor)
    ).

% sumar_puntos_a_jugador(+Jugador, +Puntos)//
%
% Recorre la lista de jugadores del estado y suma Puntos unicamente al
% jugador cuyo nombre coincide con Jugador. El resto queda sin cambios.
sumar_puntos_a_jugador(Jug, Pts) -->
    state(S0, S),
    { select(jugadores(P0), S0, S1),
      maplist(sumar_si_corresponde(Jug, Pts), P0, P1),
      S = [jugadores(P1)|S1] }.

% sumar_si_corresponde(+NombreObjetivo, +Puntos, +JugadorAntes, -JugadorDespues)
%
% Predicado auxiliar usado por maplist/3 para actualizar puntajes.
%
% Si el jugador inspeccionado coincide con NombreObjetivo, incrementa su
% marcador. Si no coincide, deja el termino jugador(...) intacto.
sumar_si_corresponde(Jug, Pts, jugador(Jug, Mano, Puntos0), jugador(Jug, Mano, Puntos)) :-
    Puntos is Puntos0 + Pts.
sumar_si_corresponde(Jug, _Pts, jugador(N, Mano, Puntos), jugador(N, Mano, Puntos)) :-
    N \= Jug.

% hay_ganador_partida_estado//
%
% Comprueba sobre el estado actual si alguno de los dos jugadores ya alcanzo
% o supero el puntaje objetivo. No informa quien fue: solo responde verdadero
% o falso para cortar o continuar el flujo del juego.
hay_ganador_partida_estado -->
    state(S, S),
    {
        select(jugadores([jugador(_, _, P1), jugador(_, _, P2)]), S, _),
        puntaje_objetivo(Objetivo),
        (P1 >= Objetivo ; P2 >= Objetivo)
    }.

% carta_alta(+Cartas, -Resultado)
%
% Compara exactamente dos cartas jugadas en una mano.
%
% Si una carta supera a la otra, Resultado se unifica con la carta ganadora.
% Si ambas tienen la misma jerarquia de truco, Resultado es el atomo parda.
%
% La comparacion numerica se hace con operadores de CLPFD.
carta_alta([Carta1, Carta2], Resultado) :-
    valor_carta(Carta1, P1),
    valor_carta(Carta2, P2),
    (
        P1 #> P2 -> Resultado = Carta1
    ;   P2 #> P1 -> Resultado = Carta2
    ;   P1 #= P2 -> Resultado = parda
    ).

% ronda_terminada(+Resultados, +Rechazo)
%
% Determina si la ronda debe considerarse cerrada.
%
% La ronda termina en cualquiera de estos casos:
% 1. hubo rechazo de un canto;
% 2. ya se jugaron tres manos;
% 3. alguno de los jugadores acumulo dos victorias.
ronda_terminada(_Resultados, rechazo(_)) :- !.
ronda_terminada(Resultados, none) :-
    length(Resultados, L),
    (L >= 3 ; alguien_gano_dos(Resultados)).

% alguien_gano_dos(+Resultados)
%
% Revisa la lista de resultados de manos y verifica si algun jugador aparece
% como ganador al menos dos veces. Usa contar_victorias/3 para el conteo.
alguien_gano_dos(Resultados) :-
    member(jugador(Nombre, _, _), Resultados),
    contar_victorias(Nombre, Resultados, V),
    V >= 2,
    !.

% contar_victorias(+Nombre, +Resultados, -Total)
%
% Cuenta cuantas manos gano un jugador dentro de la lista Resultados.
% Solo suma aquellos elementos que sean exactamente jugador(Nombre, _, _);
% cualquier otro termino, como parda, se ignora.
contar_victorias(_, [], 0).
contar_victorias(Nombre, [jugador(Nombre, _, _) | Resto], Total) :-
    contar_victorias(Nombre, Resto, SubTotal),
    Total is SubTotal + 1.
contar_victorias(Nombre, [_ | Resto], Total) :-
    contar_victorias(Nombre, Resto, Total).

% obtener_ganador(+Jugadores, +Resultados, -Ganador)
%
% Decide quien gana la ronda una vez terminadas las manos.
%
% Toma siempre uno de los jugadores reales presentes en la mesa. Cuenta las
% victorias de cada uno y devuelve al que tenga mas. Si hay empate, gana el
% primer jugador de la lista por la condicion V1 >= V2.
obtener_ganador([P1, P2], Resultados, GanadorFinal) :-
    P1 = jugador(N1, _, _),
    P2 = jugador(N2, _, _),
    contar_victorias(N1, Resultados, V1),
    contar_victorias(N2, Resultados, V2),
    (V1 >= V2 -> GanadorFinal = P1 ; GanadorFinal = P2).

% mezclar(+Lista, -ListaMezclada)
%
% Implementa una mezcla recursiva sencilla. En cada paso:responde.
% 1. calcula la longitud de la lista restante;
% 2. elige un indice aleatorio;
% 3. extrae el elemento de ese indice;
% 4. lo coloca al frente del resultado;
% 5. repite con el resto.
mezclar([], []).
mezclar(Xs0, [Y|Ys]) :-
    length(Xs0, N),
    N1 is N - 1,
    random_between(0, N1, R),
    nth0(R, Xs0, Y, Xs),
    mezclar(Xs, Ys).

% mezclar_cartas//
%
% Toma el mazo actual del estado, lo mezcla con mezclar/2 y vuelve a guardar
% la version mezclada en el mismo lugar.
mezclar_cartas -->
    state(S0, S),
    {
        select(mazo(Cartas), S0, S1),
        mezclar(Cartas, CartasMezcladas),
        S = [mazo(CartasMezcladas)|S1]
    }.

% start//
%
% Construye el estado inicial minimo para arrancar una partida.
%
% El estado resultante contiene:
% 1. un mazo completo generado con carta/1 y ordenado por setof/3;
% 2. una ronda vacia, sin canto, sin rechazo y con envido inicial.
start -->
    state(_, [mazo(Cartas), ronda([], ninguno, none, EstadoEnvido)]),
    {
        setof(Carta, carta(Carta), Cartas),
        estado_envido_inicial(EstadoEnvido)
    }.

% crear_jugadores(+Nombres)//
%
% Recibe una lista de nombres y crea para cada uno una estructura
% jugador(Nombre, ManoVacia, PuntajeInicialCero). Luego inserta la lista
% completa dentro del estado.
crear_jugadores(Nombres) -->
    state(S0, S),
    {
        same_length(Jugadores, Nombres),
        maplist([N, X]>>(X = jugador(N, [], 0)), Nombres, Jugadores),
        S = [jugadores(Jugadores)|S0]
    }.

% repartir_carta_a_cada_jugador//
%
% Extrae del estado la lista de jugadores y el mazo actual, reparte una carta
% a cada jugador en orden y deja el mazo reducido con las cartas restantes.
repartir_carta_a_cada_jugador -->
    state(S0, S),
    {
        select(jugadores(Jugadores), S0, S1),
        select(mazo(Cartas), S1, S2),
        repartir_carta_a_cada_jugador(Jugadores, Jugadores1, Cartas, Cartas1),
        S = [jugadores(Jugadores1), mazo(Cartas1)|S2]
    }.

% repartir_carta_a_cada_jugador(+JugadoresAntes, -JugadoresDespues, +MazoAntes, -MazoDespues)
%
% Version logica auxiliar del reparto. Recorre ambas listas en paralelo:
% consume una carta del mazo y la agrega al frente de la mano de cada jugador.
repartir_carta_a_cada_jugador([], [], Mazo, Mazo).
repartir_carta_a_cada_jugador([Jugador|Jugadores], [Jugador1|Jugadores1], [Carta|Mazo], Mazo1) :-
    Jugador = jugador(N, Mano, Puntos),
    Jugador1 = jugador(N, [Carta|Mano], Puntos),
    repartir_carta_a_cada_jugador(Jugadores, Jugadores1, Mazo, Mazo1).

% fin_partida//
%
% Inspecciona el estado actual y detecta si alguno de los jugadores ya gano
% la partida. Si eso ocurre, imprime por consola el nombre del ganador.
%
% Es una DCG de solo lectura usada como chequeo previo dentro del bucle
% principal de jugar_truco//0.
fin_partida -->
    state(S, S),
    {
        select(jugadores([jugador(N1, _, P1), jugador(N2, _, P2)]), S, _),
        number(P1),
        number(P2),
        puntaje_objetivo(Objetivo),
        (
            P1 >= Objetivo ->
            format("El jugador ~w gano la partida~n", [N1])
        ;
            P2 >= Objetivo ->
            format("El jugador ~w gano la partida~n", [N2])
        )
    }.

% jugar_truco//
%
% Bucle principal de la partida expresado como DCG.
%
% Primera clausula:
% si fin_partida//0 tiene exito sobre el estado actual, la partida termina
% y la gramatica corta con ! para no seguir generando rondas nuevas.
jugar_truco -->
    fin_partida,
    !.

% jugar_truco//
%
% Segunda clausula del bucle principal. Se ejecuta cuando la partida aun no
% termino.
%
% Flujo:
% 1. toma los jugadores actuales;
% 2. reinicia sus manos con nueva_mesa/2;
% 3. cambia quien es mano con cambiar_mano/2;
% 4. reinicia la ronda y el envido;
% 5. reparte tres cartas a cada jugador;
% 6. juega la mesa completa;
% 7. vuelve recursivamente al inicio del ciclo.
jugar_truco -->
    state(S0, S),
    {
        select(jugadores(P0), S0, S1),
        select(ronda(_, _, _, _), S1, S2),
        maplist(nueva_mesa, P0, P1),
        cambiar_mano(P1, P2),
        estado_envido_inicial(EstadoEnvido),
        S = [ronda([], ninguno, none, EstadoEnvido), jugadores(P2)|S2]
    },
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    repartir_carta_a_cada_jugador,
    jugar_mesa,
    jugar_truco.

% cambiar_mano(+JugadoresAntes, -JugadoresDespues)
%
% Alterna quien empieza la ronda. Como este programa modela solo dos
% jugadores, cambiar la mano consiste simplemente en rotar la lista.
cambiar_mano([J1, J2], [J2, J1]).

% nueva_mesa(+JugadorAntes, -JugadorDespues)
%
% Construye la version de un jugador lista para una ronda nueva:
% conserva nombre y puntaje acumulado, pero vacia la mano.
nueva_mesa(jugador(N, _, P), jugador(N, [], P)).

% jugar_mesa//
%
% Controla la secuencia de manos dentro de una ronda.
%
% Primero juega una mano. Despues revisa el estado resultante:
% 1. si hay_ganador_partida_estado//0 detecta fin de partida, se detiene;
% 2. si la ronda termino, llama a finalizar_ronda//0;
% 3. en otro caso, vuelve a jugar otra mano.
jugar_mesa -->
    jugar_mano,
    state(S, S),
    { select(ronda(Resultados, _, Rech, _), S, _) },
    ( hay_ganador_partida_estado ->
        []
    ; { ronda_terminada(Resultados, Rech) } ->
        finalizar_ronda
    ;
        jugar_mesa
    ).

% jugar_mano//
%
% Ejecuta una mano individual de Truco.
%
% El flujo supone dos jugadores:
% 1. normaliza la estructura de ronda por compatibilidad;
% 2. identifica a los dos jugadores que deben actuar;
% 3. procesa el turno del primero;
% 4. si la ronda no termino, procesa el turno del segundo;
% 5. si ambos jugaron carta, resuelve el ganador de la mano.
%
% Un turno puede terminar sin carta jugada si el jugador solo canto algo; en
% ese caso entra en juego jugar_si_falta_carta//4.
jugar_mano -->
    asegurar_ronda,
    state(S0, S0),
    {
        member(jugadores([J1, J2]), S0),
        J1 = jugador(N1, _, _),
        J2 = jugador(N2, _, _)
    },
    turno_jugador(N1, Carta1, Termino1),
    jugar_si_falta_carta(N1, Carta1, Termino1, Carta1b),
    (
      { Termino1 == si } ->
        []
    ;
      turno_jugador(N2, Carta2, Termino2),
      jugar_si_falta_carta(N2, Carta2, Termino2, Carta2b),
      (
        { Termino2 == si } ->
          []
      ;
        resolver_mano_cartas([J1, J2], [Carta1b, Carta2b])
      )
    ).

% jugar_si_falta_carta(+Nombre, +Carta, +TerminoRonda, -CartaFinal)//
%
% Maneja el caso en que un jugador uso su turno solo para cantar, sin jugar
% todavia una carta.
%
% Si la ronda sigue abierta y Carta = sin_carta, se vuelve a invocar
% turno_jugador//3 para que ese mismo jugador ahora juegue una carta.
% En cualquier otro caso, CartaFinal coincide con la carta ya obtenida.
jugar_si_falta_carta(Nombre, Carta, Termino, CartaFinal) -->
    ( { Termino == no, Carta == sin_carta } ->
        turno_jugador(Nombre, CartaFinal, _)
    ;
        { CartaFinal = Carta }
    ).

% turno_jugador(+Nombre, -CartaJugada, -TerminaRonda)//
%
% Ejecuta la interaccion de un jugador durante su turno.
%
% El jugador puede:
% 1. jugar una carta de su mano;
% 2. cantar truco o envido;
% 3. ingresar una accion invalida, en cuyo caso el programa fuerza el juego
%    de la primera carta disponible.
%
% CartaJugada vale sin_carta cuando el turno se consumio en un canto y la
% ronda sigue abierta. TerminaRonda vale si si algun rechazo o un puntaje de
% envido cerraron inmediatamente la ronda o incluso la partida.
turno_jugador(Nombre, CartaJugada, TerminaRonda) -->
    state(S0, S0),
    {
        member(jugadores(P0), S0),
        member(jugador(Nombre, Mano, _), P0),
        format("~w turno.\nMano: ~w~n", [Nombre, Mano]),
        format("Elegi accion (jugar/cantar):~n", [])
    },
    {
        read(Accion)
    },
    (
      { Accion == jugar } ->
        {
          format("~w: elegi carta:~n", [Nombre]),
          read(Carta),
          ( member(Carta, Mano) ->
              CartaJugada = Carta,
              TerminaRonda = no
          ; writeln("Carta invalida, se juega la primera."),
            Mano = [CartaJugada|_],
            TerminaRonda = no
          )
        }
    ;
      { Accion == cantar } ->
        mensaje_cantos_disponibles(Nombre),
        {
          read(Canto)
        },
        resolver_canto_o_envido_en_turno(Nombre, Canto, TerminaRonda),
        { CartaJugada = sin_carta }
    ;
      {
        writeln("Accion invalida, se toma jugar."),
        Mano = [CartaJugada|_],
        TerminaRonda = no
      }
    ).

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

% resolver_canto_o_envido_en_turno(+Nombre, +Canto, -TerminaRonda)//
%
% Decide a que subsystema debe enviarse un canto ingresado por el jugador.
%
% Reglas:
% 1. si es un canto de envido y envido_habilitado//0 tiene exito, lo resuelve
%    por la rama de envido;
% 2. si es un canto de envido pero ya no corresponde, informa el error;
% 3. en cualquier otro caso, lo trata como canto de truco.
%
% Despues de resolver, informa mediante TerminaRonda si la ronda quedo cerrada
% por rechazo o si hay_ganador_partida_estado//0 detecta fin de partida por
% puntaje.
resolver_canto_o_envido_en_turno(Nombre, Canto, TerminaRonda) -->
    ( { es_canto_envido(Canto) },
      envido_habilitado ->
        resolver_envido_en_turno(Nombre, Canto),
        ( hay_ganador_partida_estado ->
            { TerminaRonda = si }
        ;
            { TerminaRonda = no }
        )
    ; { es_canto_envido(Canto) } ->
        { writeln("El envido solo puede cantarse en la primera mano antes de que avance la ronda."),
          TerminaRonda = no }
    ;
      resolver_canto_en_turno(Nombre, Canto),
      state(S1, S1),
      {
        ( select(ronda(_, _, rechazo(_), _), S1, _) ->
              TerminaRonda = si
        ;     TerminaRonda = no
        )
      }
    ).

% resolver_mano_cartas(+JugadoresAntes, +CartasSeleccionadas)//
%
% Resuelve una mano una vez que ya se conocen las dos cartas jugadas.
%
% Tareas realizadas:
% 1. compara las cartas con carta_alta/2;
% 2. registra en ronda(...) si la mano fue parda o quien la gano;
% 3. elimina de cada mano la carta efectivamente utilizada;
% 4. actualiza el estado con los nuevos jugadores y los nuevos resultados.
resolver_mano_cartas(P0, CartasSeleccionadas) -->
    state(S0, S),
    {
        select(jugadores(P0), S0, S1),
        select(ronda(Resultados, CantoActual, Rech, EstadoEnvido), S1, S2),
        carta_alta(CartasSeleccionadas, Resultado),
        (
          Resultado = parda ->
            format("Se empato la mano~n", []),
            append([parda], Resultados, Resultados1)
        ;
          nth0(N, CartasSeleccionadas, Resultado),
          nth0(N, P0, JugadorGanador, _),
          JugadorGanador = jugador(Nombre, _, _),
          format("El jugador ~w gano la mano~n", [Nombre]),
          append([JugadorGanador], Resultados, Resultados1)
        ),
        maplist(eliminar_carta, P0, CartasSeleccionadas, P1),
        imprimir_lista(Resultados1),
        S = [ronda(Resultados1, CantoActual, Rech, EstadoEnvido), jugadores(P1)|S2]
    }.

% finalizar_ronda//
%
% Cierra formalmente la ronda y deja preparado el estado para la siguiente.
%
% Si la ronda habia terminado por rechazo, no suma puntos adicionales porque
% ya fueron otorgados al momento de procesar la respuesta al canto.
%
% Si la ronda termino por juego normal:
% 1. obtiene el ganador con obtener_ganador/3;
% 2. calcula cuantos puntos vale la ronda segun el canto vigente;
% 3. actualiza el puntaje del ganador;
% 4. reinicia la estructura ronda(...) con estado_envido_inicial/1.
finalizar_ronda -->
    state(S0, S),
    {
        select(ronda(Resultados, Canto, Rech, envido(_Estado, _Cantos, _PremioEnvido)), S0, S1),
        select(jugadores(P0), S1, S2),
        ( Rech = rechazo(_) ->
            P1 = P0
        ;
            obtener_ganador(P0, Resultados, Ganador),
            nth0(N, P0, Ganador, Resto),
            Ganador = jugador(Nombre, Mano, Puntos),
            format("El jugador ~w gano la ronda~n", [Nombre]),
            ( Canto == ninguno -> Suma = 1 ; puntos_por_canto(Canto, Suma) ),
            PuntosNuevos is Puntos + Suma,
            JN = jugador(Nombre, Mano, PuntosNuevos),
            nth0(N, P1, JN, Resto)
        ),
        estado_envido_inicial(EstadoEnvidoNuevo),
        S = [ronda([], ninguno, none, EstadoEnvidoNuevo), jugadores(P1)|S2]
    }.

% eliminar_carta(+JugadorAntes, +CartaJugada, -JugadorDespues)
%
% Quita de la mano de un jugador la carta que acaban de jugar en la mano
% actual, conservando nombre y puntaje sin cambios.
eliminar_carta(Jugador0, Carta, Jugador) :-
    Jugador0 = jugador(Nombre, Mano0, Puntos),
    select(Carta, Mano0, Mano1),
    Jugador = jugador(Nombre, Mano1, Puntos).

% truco//
%
% Regla DCG principal de alto nivel. Encadena la inicializacion completa de
% la partida y luego entrega el control al bucle jugar_truco//0.
truco -->
    start,
    mezclar_cartas,
    crear_jugadores([jugador2, jugador1]),
    jugar_truco.

% truco
%
% Punto de entrada tradicional para ejecutar la partida sin invocar phrase/3
% manualmente. Arranca con una lista de un solo elemento anonimo y espera
% terminar tambien con una lista de un unico estado final.
truco :-
    write('\33[2J\33[H'),
    phrase(truco, [_], [_]).

% imprimir_lista(+Lista)
%
% Utilidad minima de depuracion e interfaz: imprime por consola la lista
% recibida. En este programa se usa para mostrar el historial acumulado de
% resultados de manos.
imprimir_lista(Lista) :-
    writeln(Lista).