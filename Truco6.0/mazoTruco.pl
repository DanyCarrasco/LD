:- module(mazoTruco, [
    carta/1,
    valor_carta/2,
    valor_envido_numero/2,
    valor_envido_mano/2,
    puntos_par_mismo_palo/2,
    mezclar/2,
    carta_alta/2
]).

:- use_module(library(random)).
:- use_module(library(clpfd)).
% carta(?Carta)
%
% Predicado generador y verificador de las cartas validas del mazo espanol
% usado por este programa. La representacion elegida para cada carta es
% Palo-Numero, por ejemplo e-as u o-7.
%
% Si Carta viene libre, el predicado enumera todas las combinaciones posibles
% entre los cuatro palos y los valores admitidos. Si Carta viene instanciada,
% comprueba que pertenezca a ese universo.
carta(Suite-Number) :-
    member(Suite, [c, o, b, e]),
    member(Number, [12, 11, 10, 7, 6, 5, 4, 3, 2, 1]).

% valor_carta(+Carta, -Valor)
%
% Define la jerarquia de cartas del Truco. Un valor numerico mayor significa
% una carta mas fuerte. Los hechos estan escritos de mayor a menor prioridad
% para reflejar directamente el orden del juego.
%
% Algunas reglas usan el patron _-Numero o _-Figura para indicar "cualquier
% palo con ese numero". Las cartas especiales, como e-as u o-7,
% aparecen con hechos especificos porque rompen la jerarquia generica.
valor_carta(e-1, 14).
valor_carta(b-1, 13).
valor_carta(e-7, 12).
valor_carta(o-7, 11).
valor_carta(_-3, 10).
valor_carta(_-2, 9).
valor_carta(c-1, 8).
valor_carta(o-1, 8).
valor_carta(_-12, 7).
valor_carta(_-11, 6).
valor_carta(_-10, 5).
valor_carta(c-7, 4).
valor_carta(b-7, 4).
valor_carta(_-6, 3).
valor_carta(_-5, 2).
valor_carta(_-4, 1).


% valor_envido_numero(+Numero, -Valor)
%
% Traduce el numero o figura de una carta al valor que aporta al envido.
% Las figuras valen 0, el as vale 1 y las cartas numericas mantienen su
% propio valor dentro del rango permitido por las reglas.
valor_envido_numero(12, 0).
valor_envido_numero(11, 0).
valor_envido_numero(10, 0).
valor_envido_numero(1, 1).
valor_envido_numero(2, 2).
valor_envido_numero(3, 3).
valor_envido_numero(4, 4).
valor_envido_numero(5, 5).
valor_envido_numero(6, 6).
valor_envido_numero(7, 7).


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