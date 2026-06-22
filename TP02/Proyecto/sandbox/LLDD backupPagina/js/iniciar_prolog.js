// js/iniciar_prolog.js
import { UI } from './ui.js';

const ARCHIVOS_PROLOG = [
    'config.pl', 'mazoTruco.pl', 'gestor_estado.pl',
    'sistema_cantos.pl', 'estado_jugador.pl', 'interfaz_web.pl', 'motor_juego_web.pl'
];

let swipl = null;
window.prologListo = false;

async function iniciarProlog() {
    // 1. Mostrar mensaje inicial (verificando que UI esté listo)
    if (window.mostrarMensaje) {
        window.mostrarMensaje("Iniciando motor Prolog...");
    }

    // 2. Inicializar SWI-Prolog
    swipl = await SWIPL({ arguments: ["-q"] });
    window.swipl = swipl;

    // 3. Cargar archivos
    for (const nombre of ARCHIVOS_PROLOG) {
        const resp = await fetch(`prolog/${nombre}?v=${Date.now()}`);
        if (!resp.ok) throw new Error(`No se pudo descargar ${nombre}`);
        const texto = await resp.text();
        swipl.FS.writeFile(`/${nombre}`, texto);
        await swipl.prolog.query(`consult('/${nombre}')`).once();
        console.log(`✅ ${nombre} cargado`);
    }

    window.prologListo = true;
    console.log('🟢 Motor listo.');

    // 4. Lógica de reanudación
    if (window.miNombrePendiente) {
        // Apotamos correctamente al método dentro de window.PrologBridge
        if (window.PrologBridge && typeof window.PrologBridge.avisarMiJugadorAProlog === 'function') {
            window.PrologBridge.avisarMiJugadorAProlog(window.miNombrePendiente);
        } else {
            console.error('❌ No se pudo asignar el jugador en Prolog: window.PrologBridge no está disponible.');
        }
        window.miNombrePendiente = null;
    }

    if (window.mostrarMensaje) {
        window.mostrarMensaje('Motor cargado. Esperando al rival...');
    }

    // 5. Intentar arrancar
    window.prologCargado = true;
    if (window.intentarIniciarPartida) {
        window.intentarIniciarPartida();
    }
}

async function arrancarPartidaReal() {
    if (window.mostrarMensaje) window.mostrarMensaje('¡Arrancando la partida!');

    try {
        await swipl.prolog.forEach(
            "phrase(motor_juego_web:truco, [_], [_])",
            (resultado) => { console.log('Paso resuelto:', resultado); }
        );
        if (window.mostrarMensaje) window.mostrarMensaje('¡Partida finalizada!');
    } catch (err) {
        console.error('Error:', err);
        if (window.mostrarMensaje) window.mostrarMensaje(`Error: ${err.message}`);
    }
}
window.arrancarPartidaReal = arrancarPartidaReal;

// EJECUCIÓN: Simplemente llamamos a la función.
// Como es un módulo, esto se ejecutará una vez que el DOM esté listo.
iniciarProlog().catch(err => {
    console.error(err);
    if (window.mostrarMensaje) window.mostrarMensaje(`Error fatal: ${err.message}`);
});