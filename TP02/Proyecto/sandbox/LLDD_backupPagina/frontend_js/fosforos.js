// fosforos.js
// Dibuja el puntaje del Truco usando "tranqueras" de fósforos
// (grupos de 5: 4 lados de un cuadrado + 1 diagonal), igual a
// como se marca tradicionalmente con tiza.

/**
 * Crea el HTML de una tranquera (grupo de hasta 5 fósforos).
 * @param {number} cantidad - cuántos lados dibujar (0 a 5).
 */
function crearTranquera(cantidad) {
  const orden = ['lado-izq', 'lado-arriba', 'lado-der', 'lado-abajo', 'diagonal'];
  const div = document.createElement('div');
  div.className = 'tranquera';

  for (let i = 0; i < cantidad; i++) {
    const palito = document.createElement('div');
    palito.className = `fosforo ${orden[i]}`;
    div.appendChild(palito);
  }
  return div;
}

/**
 * Pinta el puntaje completo dentro de un contenedor.
 * @param {string} idContenedor - id del div ".zona-fosforos".
 * @param {number} puntos - puntaje a representar.
 */
function pintarFosforos(idContenedor, puntos) {
  const contenedor = document.getElementById(idContenedor);
  if (!contenedor) return;

  contenedor.innerHTML = '';

  const grupos = Math.floor(puntos / 5);
  const resto = puntos % 5;

  for (let i = 0; i < grupos; i++) {
    contenedor.appendChild(crearTranquera(5));
  }
  if (resto > 0) {
    contenedor.appendChild(crearTranquera(resto));
  }
}

// --- Estado inicial ---
// Las actualizaciones reales llegan desde Prolog via
// window.actualizarPuntaje (ver prolog_bridge.js), que se invoca
// cada vez que gestor_estado.pl suma puntos a un jugador.
document.addEventListener('DOMContentLoaded', () => {
  pintarFosforos('malas-j1', 0);
  pintarFosforos('buenas-j1', 0);
  pintarFosforos('malas-j2', 0);
  pintarFosforos('buenas-j2', 0);
});

window.pintarFosforos = pintarFosforos;

