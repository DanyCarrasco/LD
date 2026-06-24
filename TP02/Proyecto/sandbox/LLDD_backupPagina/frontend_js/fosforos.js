import { Bridge } from "./bridge.js";


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

  if (puntos >= 15) {
    contenedor.classList.add('ganador');
  } else {
    contenedor.classList.remove('ganador');
  }
}

// --- Estado inicial ---
// Arranca todo en 0 (partida nueva, hasta 15 puntos, sin flor).
document.addEventListener('DOMContentLoaded', () => {
  pintarFosforos('fosforos-yo', 0);
  pintarFosforos('fosforos-rival', 0);
});

/**
 * Punto de entrada llamado DESDE PROLOG (interfaz_web.pl, vía
 * library(wasm): "_ := actualizarPuntaje(NombreStr, Puntos)")
 * cada vez que gestor_estado.pl suma puntos a un jugador
 * (truco/retruco/vale4 rechazado, envido ganado, ronda ganada, etc).
 *
 * Cada pestaña sabe quién es ella misma (jugador1 o jugador2) a
 * través de window.PrologBridge.miNombre, así que acá sólo hace
 * falta decidir si el aviso es "mío" o del "rival" y pintar la
 * zona de fósforos correspondiente.
 *
 * @param {string} nombreJugador - 'jugador1' o 'jugador2'
 * @param {number} puntos - puntaje TOTAL actual de ese jugador
 */
function actualizarPuntaje(nombreJugador, puntos) {
  console.log('Actualizando puntajes');
  console.log(nombreJugador + "  " + Bridge.miNombre);

  const miNombre = window.PrologBridge ? window.PrologBridge.miNombre : null;

  if (nombreJugador === Bridge.miNombre) {
    pintarFosforos('fosforos-yo', puntos);
  } else {
    pintarFosforos('fosforos-rival', puntos);
  }
}

window.actualizarPuntaje = actualizarPuntaje;
window.pintarFosforos = pintarFosforos;

