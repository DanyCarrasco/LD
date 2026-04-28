:- module( mazoTruco,[
		carta/1,
		valor_carta/2
]).

carta(Palo-Valor) :-
	member(Palo, [c,o,b,e]),
	% c: copa   %
	% o: oro    %
	% b: basto  %
	% e: espada %

	member(Valor, [1,2,3,4,5,6,7,10,11,12]).	% exluir 8's y 9's


%	JERARQUIAS	%
valor_carta(e-1, 14).	% 1 de espada
valor_carta(b-1, 13).	% 1 de basto
valor_carta(e-7, 12).	% 7 de espada
valor_carta(o-7, 11).	% 7 de oro
valor_carta(_-3, 10).	% Los 3's
valor_carta(_-2, 9).	% Los 2's
valor_carta(c-1, 8).	% 1 de Copa
valor_carta(o-1, 8).	% 1 de Oro
valor_carta(_-12, 7).	% Los 12's
valor_carta(_-11, 6).	% Los 11's
valor_carta(_-10, 5).	% Los 10's
valor_carta(c-7, 4).	% 7 de copa
valor_carta(b-7, 4).	% 7 de basto
valor_carta(_-6, 3).	% Los 6's
valor_carta(_-5, 2).	% Los 5's
valor_carta(_-4, 1).	% Los 4's


% PUNTAJES ENVIDO %
%  Meter todas las funciones que hizo marisol