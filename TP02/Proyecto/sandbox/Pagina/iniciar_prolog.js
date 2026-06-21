// ============================================================
//  iniciar_prolog.js
//  Carga todos los modulos Prolog en el WASM, incluyendo el
//  motor de juego completo, y arranca la partida.
//
//  IMPORTANTE: la partida (phrase(motor_juego_web:truco,...))
//  solo se ejecuta en la pestana de jugador1 (el "anfitrion").
//  La pestana de jugador2 carga el mismo Prolog (para poder
//  resolver entrada_web localmente cuando le toca), pero NO
//  corre su propia copia de la partida.
// ============================================================

const ARCHIVOS_PROLOG = [
    'config.pl',
    'mazoTruco.pl',
    'gestor_estado.pl',
    'sistema_cantos.pl',
    'estado_jugador.pl',
    'interfaz_web.pl',
    'motor_juego_web.pl'
];

let swipl = null;
window.prologListo = false;   // true solo cuando TODOS los .pl cargaron

async function iniciarProlog() {
    mostrarMensaje('Cargando motor de juego...');

    swipl = await SWIPL({ arguments: ["-q"] });
    window.swipl = swipl;

    for (const nombre of ARCHIVOS_PROLOG) {
        const resp = await fetch(`prolog/${nombre}`);
        if (!resp.ok) throw new Error(`No se pudo descargar ${nombre}`);
        const texto = await resp.text();
        swipl.FS.writeFile(`/${nombre}`, texto);
        await swipl.prolog.query(`consult('/${nombre}')`).once();
        console.log(`✅ ${nombre} cargado`);
    }

    window.prologListo = true;
    console.log('🟢 Todos los modulos Prolog cargados, listo para usarse');

    // Si JS ya estaba esperando para avisarle a Prolog quien soy yo
    // (porque el WebSocket conecto antes de que termine de cargar),
    // lo procesamos ahora que es seguro.
    if (window.miNombrePendiente) {
        avisarMiJugadorAProlog(window.miNombrePendiente);
        window.miNombrePendiente = null;
    }

    mostrarMensaje('Motor cargado. Esperando al rival para arrancar...');

    // window.iniciarPartidaSiSoyAnfitrion (definida en prolog_bridge.js)
    // se llama cuando llega el mensaje "listos" del relay. Desde aca
    // solo dejamos la funcion disponible para que la dispare ese evento.
    window.prologCargado = true;
    if (window.intentarIniciarPartida) {
        window.intentarIniciarPartida();
    }
}

// ------------------------------------------------------------
//  arrancarPartidaReal()
//  Ejecuta el motor de juego completo. Solo debe llamarse UNA
//  vez, y solo desde la pestana de jugador1 (el anfitrion).
// ------------------------------------------------------------
async function arrancarPartidaReal() {
    mostrarMensaje('¡Arrancando la partida!');
    console.log('🎮 Iniciando motor_juego_web:truco...');

    try {
        await swipl.prolog.forEach(
            "phrase(motor_juego_web:truco, [_], [_])",
            (resultado) => {
                console.log('Paso de partida resuelto:', resultado);
            }
        );
        console.log('🏁 Partida finalizada.');
        mostrarMensaje('¡Partida finalizada!');
    } catch (err) {
        console.error('Error ejecutando la partida:', err);
        mostrarMensaje(`Error en la partida: ${err.message}`);
    }
}
window.arrancarPartidaReal = arrancarPartidaReal;

iniciarProlog().catch(err => {
    console.error(err);
    mostrarMensaje(`Error: ${err.message}`);
});