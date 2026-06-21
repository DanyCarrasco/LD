:- use_module(library(sockets)).
:- use_module(library(iso_ext)).
:- use_module(library(charsio)).
:- use_module(library(random)).
:- use_module(library(pairs)).


main:-
    format("Starting server on port 8316...~n", []),
    socket_server_open('0.0.0.0':8316, ServerSocket),
    socket_server_accept(ServerSocket, _Client, Stream, []),
    format("Client connected~n",[]),
    setup_call_cleanup(
        true,
	phrase(escobas(Stream),[_],[_]),
	(   close(Stream),
	    socket_server_close(ServerSocket)
	)
    ).




% Modeling Cards

card(Number-Suite) :-
    member(Suite, [oros,espadas,bastos,copas]),
    member(Number, [rey,caballo,sota,7,6,5,4,3,2,as]).



% Counting points

points(Cards,P) :-
    (	member(7-oros,Cards) -> O7 = 1 ; O7 = 0 ),
    length(Cards,Cant),
    cant_oros(Cards,Oros),
    (	setenta(Cards,Setenta) -> true ; Setenta = 0),
    P = p(O7,Cant,Oros,Setenta).

cant_oros(Cards,N) :-
    findall(X,member(X-oros,Cards),L),
    length(L,N).
	      
setenta(Cards,N) :-
    max(oros,Cards,O),
    max(bastos,Cards,B),
    max(copas,Cards,C),
    max(espadas,Cards,E),
    N #= O + B + C + E.

max(S,Cards,N) :-
    member(_-S,Cards),!,
    findall(X,member(X-S,Cards),L),
    (	select(sota,L,L1) ->  true ; L1 = L),
    (	select(caballo,L1,L2) -> true ; L2 = L1),
    (	select(rey,L2,L3) ->  true ; L3 = L2),
    (	select(as,L3,L4) -> L5= [1|L4]  ; L5 = L3),
    (	list_max(L5,N) -> true ; N = 0 ). % only figures is 0


% winner of a round
    
points_won(Players,Points,Names) :-
    maplist(\X^N^(X=player(N,_,_,_)),Players,Names),
    maplist(pointwon,Players,NPlayers),
    maplist(calcpoint(NPlayers),NPlayers,Points).

calcpoint(L,Player,SPoints) :-
    select(Player,L,Rest),
    Player = p(O7,Cant,Oros,Setenta)-Escobas,
    compare(2,Cant,Rest,NCant),
    compare(3,Oros,Rest,NOros),
    compare(4,Setenta,Rest,NSetenta),
    Points #= Escobas + O7 + NCant + NOros + NSetenta,
    (	Escobas == 0 -> SEscobas = "" ; phrase(format_("~d escobas ",[Escobas]),SEscobas)),
    (	O7 == 0 -> S07 = "" ; S07 = "one for 7 of oros "),
    (	NCant == 0 -> SNCant = "" ; SNCant = "one for cards "),
    (	NOros == 0 -> SNOros = "" ; SNOros = "one for oros "),
    (	NSetenta == 0 -> SNSetenta = "" ; SNSetenta = "one for setenta "),
    phrase(format_(" got ~d points ~s~s~s~s~s",[Points,SEscobas,S07,SNCant,SNOros,SNSetenta]),SPoints).

    
compare(N,X,L,Resultado) :-
    foldl(may(N,X),L,1,Resultado).

may(N,X,P-_,R,Resultado) :-
    arg(N,P,Arg),
    (	Arg > X -> Resultado = 0 ; Resultado = R ).


pointwon(player(_,_,WonCards,Escobas),N-Escobas) :-
    points(WonCards,N).

    
% Estado

 %[players([player(claudio,[],[oros-7,copas-4,bastos-4,oros-2,bastos-11,bastos-6,espadas-5,bastos-rey],2), player(roberto, [], [espadas-7,bastos-4,copas-4,espadas-2,copas-11,copas-6,oros-5,copas-rey],2), player(luis, [], [oros-rey,espadas-rey,copas-5,bastos-5],2) ]), table([]), deck([])]


% A complete game


state(S), [S] --> [S].
state(S0, S), [S] --> [S0].

reset -->
    state(_,[deck(Cards)]),
    { setof(Card,card(Card),Cards)  }.

shuffle_cards -->
    state(S0,S),
    {
	select(deck(Cards),S0,S1),
	shuffle(Cards,ShuffledCards),
	S = [deck(ShuffledCards) | S1]
    }.

shuffle([],[]).
shuffle(Xs0,[Y|Ys]) :-
    length(Xs0,N),
    random_integer(0,N,R),
    nth0(R,Xs0,Y,Xs),
    shuffle(Xs, Ys).

players(P0,P), [S] -->
    [S0],
    { select(players(P0),S0,S1), S = [players(P)|S1] }.




escobas(S) -->
    reset,
    shuffle_cards,
    set_table,
    create_players([pablo,abuela,angel,norma]),
    play_rounds(S),
    show_scores(S).


set_table -->
    state(S0,S),
    {
	select(deck([C1,C2,C3,C4 | Rest]),S0,S1),
	S = [deck(Rest),table([C1,C2,C3,C4])| S1]
    }.


create_players(Names) -->
    state(S0,S),
    {
	same_length(Players,Names),
	maplist(\N^X^(X=player(N,[],[],0)),Names,Players),
	S = [players(Players) | S0]
    },
    deal_one_card_per_player,
    deal_one_card_per_player,
    deal_one_card_per_player.

deal_one_card_per_player -->
    state(S0,S),
    {
	select(players(Players),S0,S1),
	select(deck(Cards),S1,S2),
	deal_one_card_per_player(Players,Players1,Cards,Cards1),
	S = [players(Players1),deck(Cards1)|S2]
    }.

deal_one_card_per_player([],[],Cs,Cs).
deal_one_card_per_player(Ps,Ps,[],[]).
deal_one_card_per_player([P|Ps],[P1|Ps1],[C|Cs],Cs1) :-
     P  = player(N,A0,B0,E),
     P1 = player(N,[C|A0],B0,E),
     deal_one_card_per_player(Ps,Ps1,Cs,Cs1).


play_rounds(Stream) -->
    state(S),
    { member(deck(Cards),S), length(Cards,0) },
    play_3rounds(Stream).

play_rounds(Stream) -->
    state(S),
    { member(deck(Cards),S), length(Cards,N) , N > 0 },
    play_3rounds(Stream),
    deal_one_card_per_player,
    deal_one_card_per_player,
    deal_one_card_per_player,
    play_rounds(Stream).


play_3rounds(_) -->
    players(P,P),
    { P = [player(_,[],_,_)|_]  }.
play_3rounds(Stream) -->
    players(P,P),
    { P = [player(_,X,_,_)|_],length(X,N) , N >0 ,length(P,CantPl)  },
    play_players(0,CantPl,Stream),
    play_3rounds(Stream).



play_players(N,N,_) -->
     [].
play_players(N,CantN,Stream) -->
    state(S0,S),
    {
	select(table(Table),S0,S1),
	select(players(P0),S1,S2),
	length(L,N),append(L,[P|R],P0),
	P = player(Name,SelectableCards,WinnerCard,E),

	interface(Stream,i(Name,SelectableCards,Table,M,C,SelTable)),
	

	select(C,SelectableCards,NewSelectableCards),
	selectall(SelTable,Table,NTable),
	(   M = d ->
	    (	
		NWinner = WinnerCard,
		SNTable = [C|NTable]
	    )
	;   M = e ->
	    (
		append([C|SelTable],WinnerCard,NWinner),
		SNTable = NTable
	    )
	;   M = t ->
	    (
		append(SelTable,WinnerCard,NWinner),
		SNTable = [C|NTable]
	    )
	),
	(
	    SNTable = [] -> E1 #= E + 1 ; E1 = E
	),
	

	P1 = player(Name,NewSelectableCards,NWinner,E1),
	append(L,[P1|R],NP),
	S3 = [players(NP)|S2],
	S = [table(SNTable)|S3],
	format("~w~n",[S]),
	N1 #= N + 1
    },
    play_players(N1,CantN,Stream).

selectall([],L,L).
selectall([X|Y],L,R) :-
    select(X,L,NL),
    selectall(Y,NL,R).

    

show_scores(S) -->
    players(P,P),
    {
	points_won(P,Points,Names),
	format(S," points for each player: ~n",[]),
	formatear(Names,Points,S)
    }.

formatear([],[],Stream) :-
    format(Stream,"----------~n",[]).
formatear([N|Ns],[P|Ps],Stream) :-
    format(Stream," ~a ~s ~n",[N,P]),
    formatear(Ns,Ps,Stream).




interface(S,i(Name,SelectableCards,Table,M,C,SelTable)) :-
    write_term_to_chars(Name,[],SName),
    write_term_to_chars(SelectableCards,[],SSelectableCards),
    write_term_to_chars(Table,[],STable),
    format(S,"~s~n",[SName]),flush_output(S),
    format(S,"~s.~n",[SSelectableCards]),flush_output(S),
    format(S,"~s.~n",[STable]),flush_output(S),
    get_line_to_chars(S,SM,""),
    get_line_to_chars(S,SC,""),
    get_line_to_chars(S,SSelTable,""),
    read_from_chars(SM,M),
    read_from_chars(SC,C),
    read_from_chars(SSelTable,SelTable).


