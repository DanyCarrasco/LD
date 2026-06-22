:- module(estado_jugador, [
    asignar_mi_jugador/1,
    mi_jugador/1,
    es_jugador_local/1
]).

% ============================================================
%  estado_jugador.pl
%
%  Cada pestana corre su PROPIA instancia de Prolog WASM, que
%  no sabe nada de la otra pestana. Este modulo guarda un unico
%  hecho dinamico: "quien soy yo" (jugador1 o jugador2).
%
%  JS llama a asignar_mi_jugador/1 una sola vez, apenas el relay
%  le confirma el rol (anfitrion=jugador1, invitado=jugador2).
% ============================================================

:- dynamic mi_jugador/1.

% reemplaza el hecho anterior (si lo hubiera) por el nuevo nombre
asignar_mi_jugador(Nombre) :-
    retractall(mi_jugador(_)),
    assertz(mi_jugador(Nombre)).

% true si Nombre es el jugador que corre EN ESTA pestaña
es_jugador_local(Nombre) :-
    mi_jugador(Mio),
    Mio == Nombre.