% Mueve el cursor a la posición X (Fila) e Y (Columna)
shPointer(X, Y) :-
    format('\33[~w;~wH', [X, Y]).

% Dibuja la estructura fija
dibujar_interfaz :-
    write('\33[2J'),        % Limpia pantalla
    write('\33[H'),         % Cursor al inicio (1,1)
    write('<--- Truco --->\n'), % Fila 1
    write('P1: \n'),           % Fila 2
    write('P2: \n'),           % Fila 3
    write('----------------\n'). % Fila 4

% Definimos coordenadas fijas (Fila, Columna)
% P1 está en la fila 2, justo después de "P1: " (columna 5)
pos_puntos(p1, 2, 5).
pos_puntos(p2, 3, 5).
% El área de texto de juego empezará en la fila 6
pos_puntos(log, 6, 1).

% Predicado para setear puntos
set_pts(Jugador, Puntos) :-
    pos_puntos(Jugador, F, C),
    shPointer(F, C),
    format('~w pts  ', [Puntos]). % El espacio extra borra números viejos largos

% Ejemplo de uso corregido
juego :-
    dibujar_interfaz,
    set_pts(p1, 15),
    set_pts(p2, 12),
    
    % Volvemos al área de log para escribir mensajes
    pos_puntos(log, F, C),
    shPointer(F, C),
    write('Canto: ¡Truco!'), nl,
    write('¿Qué quieres hacer?'), nl.
