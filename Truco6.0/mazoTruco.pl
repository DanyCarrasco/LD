:-module(mazoTruco,[carta/1, valor_carta/2, valor_envido_numero/2]).
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