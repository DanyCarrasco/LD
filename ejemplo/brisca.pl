:- use_module(library(random)).


card(Suite-Number) :-
    member(Suite, [oros, espadas, bastos, copas]),
    member(Number, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, as]).



card_score(X, N) :-
    card(X),
    card_score_(X, N).
card_score_(_-as, 11).
card_score_(_-3, 10).
card_score_(_-rey, 4).
card_score_(_-caballo, 3).
card_score_(_-sota, 2).
card_score_(_-X, 0) :- member(X, [7, 6, 5, 4, 2]).



cards_score(Cards, Score) :-
    phrase(cards_score_(Score), Cards).

cards_score_(0) --> [].
cards_score_(X) -->
    [Card],
    { card_score(Card, X0), X #= X0 + X1 },
    cards_score_(X1).


card_higher_n(N0, N1) :-
    Order = [as, 3, rey, caballo, sota, 7, 6, 5, 4, 2],
    append(Highers, [N0|_], Order),
    member(N1, Highers).

card_higher(Trump, Card, Higher) :-
    card(Card),
    card(Higher),
    Card = S0-N0,
    Higher = S1-N1,
    (S0 = S1 *->
	 card_higher_n(N0, N1)
    ;
	S1 = Trump
       ).

round_winner(Cards, Trump, WinnerCard) :-
    reverse(Cards, [FirstCard|RestCards]),
    foldl({Trump}/[X,Y,Z]>>(card_higher(Trump, X, Y) *-> Y = Z; X = Z), RestCards, FirstCard, WinnerCard).



state(S), [S] --> [S].
state(S0, S), [S] --> [S0].


shuffle([], []).
shuffle(Xs0, [Y|Ys]) :-
    length(Xs0, N),
    N1 is N - 1,
    random_between(0, N1, R),
    nth0(R, Xs0, Y, Xs),
    shuffle(Xs, Ys).



players(P0, P), [S] -->
    [S0],
    { select(players(P0), S0, S1), S = [players(P)|S1] }.


brisca :-
    phrase(brisca, [_], [_]).

brisca -->
    reset,
    shuffle_cards,
    set_trump,
    create_players([aarroyoc, xijinping, donalddtrump, vonderleyen]),
    play_rounds,
    show_scores.

reset -->
    state(_, [stock(Cards)]),
    {
	setof(Card, card(Card), Cards)
    }.
shuffle_cards -->
    state(S0, S),
    {
	select(stock(Cards), S0, S1),
	shuffle(Cards, ShuffledCards),
	S = [stock(ShuffledCards)|S1]
    }.
set_trump -->
    state(S0, S),
    {
	member(stock(Cards), S0),
	length(Cards, N),
	nth1(N, Cards, LastCard),
	LastCard = Trump-_,
	S = [trump(Trump)|S0]
    }.

create_players(Names) -->
    state(S0, S),
    {
	same_length(Players, Names),
	maplist([N,X]>>(X=player(N, [], [])), Names, Players),
	S = [players(Players)|S0]
    },
    deal_one_card_per_player,
    deal_one_card_per_player,
    deal_one_card_per_player.

deal_one_card_per_player -->
    state(S0, S),
    {
	select(players(Players), S0, S1),
	select(stock(Cards), S1, S2),
	deal_one_card_per_player(Players, Players1, Cards, Cards1),
	S = [players(Players1), stock(Cards1)|S2]
    }.

deal_one_card_per_player([], [], Cs, Cs).
deal_one_card_per_player(Ps, Ps, [], []).
deal_one_card_per_player([P|Ps], [P1|Ps1], [C|Cs], Cs1) :-
    P = player(N, A0, B0),
    P1 = player(N, [C|A0], B0),
    deal_one_card_per_player(Ps, Ps1, Cs, Cs1).

play_rounds -->
    players(P, P),
    { P = [player(_, X, _)|_], length(X, 0) }.
play_rounds -->
    players(P, P),
    { P = [player(_, X, _)|_], length(X, N), N > 0 },
    play_round,
    play_rounds.

play_round -->
    state(S),
    players(P0, P2),
    {
	member(trump(Trump), S),
	format("Brisca round~nTrump is: ~a~n~n", [Trump])
    },
    play_players(P0, Cards),
    {
	round_winner(Cards, Trump, WinnerCard),
	maplist(remove_card, P0, Cards, P1),
	nth0(N, Cards, WinnerCard),
	nth0(N, P1, WinnerPlayer0),
	append(PBefore, [WinnerPlayer0|PAfter], P1),
	WinnerPlayer0 = player(WinnerName, C, W0),
	format("Winner card is ~w from ~w~n", [WinnerCard, WinnerName]),
	append(W0, Cards, W1),
	append([player(WinnerName, C, W1)|PAfter], PBefore, P2)
    },
    deal_one_card_per_player.

remove_card(P0, C, P) :-
    P0 = player(N, C0, W),
    select(C, C0, C1),
    P = player(N, C1, W).

play_players([], []) --> [].
play_players([P|Ps], [C|Cs]) -->
    {
	P = player(Name, SelectableCards, _),
	format("It's ~a's turn!~n", [Name]),
	format("Selectable cards: ~w~n", [SelectableCards]),
	read(C),
	member(C, SelectableCards)
    },
    play_players(Ps, Cs).
play_players(Ps, Cs) --> play_players(Ps, Cs).

show_scores -->
    players(P, P),
    {
	maplist([X]>>(
		    X=player(N,_,Z),
		    cards_score(Z, Y),
		    format("Score of ~w is ~d~n", [N, Y])), P)
    }.
