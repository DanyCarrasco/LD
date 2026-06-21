:- use_module(library(sockets)).
:- use_module(library(iso_ext)).
:- use_module(library(charsio)).
:- use_module(library(pairs)).




main :-
    format("Connecting to localhostw:8316~n", []),
    socket_client_open('localhost':8316, Stream, []),
    setup_call_cleanup(
        true,
        interface(Stream),
        close(Stream)
    ).


interface(Stream) :-
    get_line_to_chars(Stream,SName,""),
    (	SName == " points for each player: \n" ->
	format("~s~n", [SName]),
	show_scores(Stream)
    ;
    append(SName,".",SSName),
    read_from_chars(SSName,Name), 
    format("It's ~a's turn!~n", [Name]),
    get_line_to_chars(Stream,SSelectableCards,""),   
    format("Selectable cards: ~s~n", [SSelectableCards]),
    get_line_to_chars(Stream,STable,""),   
    format("Cards on table: ~s~n",[STable]),
    menuescoba(d(M,SelTable,C)),
    write_term_to_chars(M,[],SM),
    write_term_to_chars(SelTable,[],SSelTable),
    write_term_to_chars(C,[],SC),
    format(Stream,"~s.~n",[SM]),flush_output(Stream),
    format(Stream,"~s.~n",[SC]),flush_output(Stream),
    format(Stream,"~s.~n",[SSelTable]),flush_output(Stream),
    interface(Stream)
    ).

     
show_scores(Stream) :-
	get_line_to_chars(Stream,Text,""),
	(   Text == "----------\n" -> format("~s~n",[Text])
	;
	format("~s~n",[Text]),
	show_scores(Stream)
	).

	     


handle(discard,d(d,[],C)) :- 
	   format("Select Card?~n", []),
	   read(C).
handle(escoba,d(e,Sel,C)) :-
	   format("Select Card?~n", []),
	   read(C),
	   format("Select Cards?~n", []),
	   read(Sel).
handle(table,d(t,Sel,C)) :-
	   format("Select Cards?~n", []),
	   read(Sel),
	   format("which one discard?~n", []),
	   read(C).


menuescoba(d(M,SelTable,C)) :-
    	format("discard (d)   getup (e)   table (t)~n",[]),
	read(M),
    	(   M = d -> handle(discard,d(d,SelTable,C))
	;
	(   M = e -> handle(escoba,d(e,SelTable,C))
	;
	(   M = t -> handle(table,d(t,SelTable,C))
	;
	menuescoba(d(M,SelTable,C))))),
	test15(d(M,SelTable,C)).

menuescoba(d(M,SelTable,C)) :-
    format("it doesn't add up to 15, try again~n",[]),
    menuescoba(d(M,SelTable,C)). 

test15(d(M,SelTable,C)) :-
    (   M = d -> true
    ;
    (	M = t -> test15l(SelTable)
    ;
    (	M = e -> test15l([C|SelTable])
    ;	false ))).

test15l(L) :-
    pairs_keys_values(L,V,_),
    fourselect(caballo,V,V1,N1), addn(N1,9,V1,C), % C = [9|V1], 
    fourselect(rey,C,C1,N2), addn(N2,10,C1,R), % R = [10|C1] ,
    fourselect(sota,R,R1,N3), addn(N3,8,R1,S), % S = [8|R1] ,
    fourselect(as,S,S1,N4) , addn(N4,1,S1,A), % A = [1|S1] ,
    sum_list(A,15).


addn(0,_,L,L).
addn(1,E,L,[E|L]).
addn(2,E,L,[E,E|L]).
addn(3,E,L,[E,E,E|L]).
addn(4,E,L,[E,E,E,E|L]).
    
fourselect(E,S,R,C) :-
    (	select(E,S,S1) ->
	(   select(E,S1,S2) ->
	    (	select(E,S2,S3) ->
		(   select(E,S3,R) -> C = 4
		;   R = S3 ,C = 3)
	    ;	R = S2 , C = 2 )
	;   R = S1 , C = 1 )
    ;	R = S , C = 0 ).

			   
