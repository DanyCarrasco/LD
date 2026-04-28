:- module(sistema_cantos, [
    es_canto/1,
    nivel_canto/2,
    canto_supera/2,
    puntos_por_canto/2,
    puntos_por_rechazo/2,
    es_canto_envido/1,
    canto_envido_valido/2,
    puntos_envido_aceptado/3,
    puntos_envido_rechazado/3,
    puntos_falta_envido/2
    ]).

:- use_module(config, [puntaje_objetivo/1]).

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



% es_canto_envido(+Canto)
%
% Catalogo de cantos pertenecientes a la familia del envido. Se usa tanto
% para validar input como para decidir si una accion debe resolverse con la
% logica de envido o con la logica del truco.
es_canto_envido(envido).
es_canto_envido(real_envido).
es_canto_envido(falta_envido).


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