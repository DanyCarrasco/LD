:- use_module(library(random)).

%representacion de las cartas; los suites son los palos y number los numeros.
card(Suite-Number) :-
    member(Suite, [oros, espadas, bastos, copas]),
    member(Number, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, as]).

%as=1, sota = 10, caballo = 11 rey=12,


%representacion de la categoria de las cartas, una por una.

 %desde la carta que mas vale hasta la q menos vale.

card_score(X, N) :-
    card(X),
    card_score_(X, N).

card_score_(espadas-as, 12).

card_score_(bastos-as, 11).

card_score_(X-7, 10) :- member(X, [oros, espadas]).

card_score_(_-3, 9).
card_score_(_-2, 8).
card_score_(X-as, 7) :- member(X, [oros, copas]).
card_score_(_-rey, 6).
card_score_(_-caballo, 5).
card_score_(_-sota, 4).
card_score_(X-7, 3) :- member(X, [copas, bastos]).

card_score_(_-6, 2).
card_score_(_-5, 1).
card_score_(_-4, 0).


%Lista que representa la puntuacion de las cartas en el mazo
cards_score(Cards, Score) :-
    phrase(cards_score_(Score), Cards).

cards_score_(0) --> [].

cards_score_(X) -->
    [Card],
    { card_score(Card, X0), X #= X0 + X1 },
    cards_score_(X1).

%permite cambiar el estados
state(S), [S] --> [S].
state(S0, S), [S] --> [S0].

%baraja las cartas
shuffle([], []).

shuffle(Xs0, [Y|Ys]) :-
    length(Xs0, N),
    N1 is N - 1,
    random_between(0, N1, R),
    nth0(R, Xs0, Y, Xs),
    shuffle(Xs, Ys).
