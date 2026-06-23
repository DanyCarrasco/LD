// fosforos.js
// Dibuja el puntaje del Truco usando tranqueras de fósforos.
// Version corta: solo "malas" (objetivo 15 puntos).

function crearTranquera(cantidad) {
    const orden = ['lado-izq', 'lado-arriba', 'lado-der', 'lado-abajo', 'diagonal'];
    const div = document.createElement('div');
    div.className = 'tranquera';

    for (let i = 0; i < Math.min(cantidad, 5); i++) {
        const palito = document.createElement('div');
        palito.className = `fosforo ${orden[i]}`;
        div.appendChild(palito);
    }
    return div;
}

function pintarFosforos(idContenedor, puntos) {
    const contenedor = document.getElementById(idContenedor);
    if (!contenedor) {
        console.warn(`pintarFosforos: no encontré #${idContenedor}`);
        return;
    }
    contenedor.innerHTML = '';
    const grupos = Math.floor(puntos / 5);
    const resto  = puntos % 5;
    for (let i = 0; i < grupos; i++) contenedor.appendChild(crearTranquera(5));
    if (resto > 0) contenedor.appendChild(crearTranquera(resto));
}

// Llamada principal desde bridge.js cuando Prolog suma puntos.
// jugador: 'jugador1' o 'jugador2'
// puntos: puntaje TOTAL actual (no el delta)
function actualizarPuntaje(jugador, puntos) {
    const miNombre = window.PrologBridge.miNombre;
    const prefijo  = (jugador === miNombre) ? 'yo' : 'rival';
    pintarFosforos(`malas-${prefijo}`, puntos);
}

// Estado inicial en cero
document.addEventListener('DOMContentLoaded', () => {
    pintarFosforos('malas-yo',    0);
    pintarFosforos('malas-rival', 0);
});

window.pintarFosforos    = pintarFosforos;
window.actualizarPuntaje = actualizarPuntaje;