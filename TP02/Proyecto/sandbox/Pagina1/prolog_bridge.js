// ============================================================
//  prolog_bridge.js
//  Puente entre Prolog (WASM), el DOM, y el WebSocket (relay.js).
//
//  Implementa las funciones JS que interfaz_web.pl invoca via
//  ":=/2" y "await/2":
//
//      mostrarOpciones(mensaje, opcionesStr)              -> Promise<string>
//      esperarJugadaRemota(jugador, mensaje, opcionesStr) -> Promise<string>
//      alertaOpcionInvalida(valor)                        -> void
//
//  El motor de juego real corre SOLO en la pestana anfitriona
//  (jugador1). Cuando le toca jugar al rival, esa pestana NO
//  muestra botones (espera via esperarJugadaRemota), sino que
//  manda un mensaje "tu_turno" por WebSocket. La pestana del
//  rival lo recibe (ver ws.onmessage) y ahi SI muestra botones
//  reales (mostrarBotonesParaTurnoRemoto), que al clickear
//  mandan "jugada_remota" de vuelta, resolviendo la Promise
//  pendiente del lado del anfitrion.
// ============================================================

const zonaAcciones = document.getElementById('zonaAcciones');
const zonaMensajes = document.getElementById('zonaMensajes');

// Se completa cuando el relay nos confirma quienes somos
let miNombre = null;   // "jugador1" o "jugador2"

// Promise pendiente de una respuesta LOCAL (click en boton propio)
let resolverLocalPendiente = null;

// Promise pendiente de una respuesta REMOTA (mensaje WS del rival)
let resolverRemotoPendiente = null;


// ============================================================
//  CONEXION WEBSOCKET
// ============================================================

const ws = new WebSocket('ws://localhost:8080');

ws.onopen = () => {
    console.log('Conectado al relay, pidiendo unirme...');
    // Por ahora pedimos el nombre por prompt; lo vamos a prolijar
    // despues (el relay podria asignarlo solo, por orden de llegada)
    const nombre = prompt('¿Sos jugador1 o jugador2?', 'jugador1');
    miNombre = nombre;
    ws.send(JSON.stringify({ tipo: 'unirse', jugador: nombre }));
};

let ambosListos = false;   // true cuando el relay confirmo 2 jugadores

ws.onmessage = async (event) => {
    const msg = JSON.parse(event.data);
    console.log('Mensaje recibido del relay:', msg);

    if (msg.tipo === 'unido') {
        mostrarMensaje(`Conectado como ${msg.jugador}. Avisale a Prolog...`);
        await avisarMiJugadorAProlog(msg.jugador);
    }
    else if (msg.tipo === 'listos') {
        mostrarMensaje(`Listos: ${msg.jugadores.join(' y ')}.`);
        ambosListos = true;
        if (window.intentarIniciarPartida) {
            window.intentarIniciarPartida();
        }
    }
    else if (msg.tipo === 'jugada_remota') {
        // El rival jugo algo (click en su pestaña). Si tenemos una
        // Promise remota pendiente esperando justo esto, la resolvemos.
        if (resolverRemotoPendiente) {
            resolverRemotoPendiente(msg.valor);
            resolverRemotoPendiente = null;
        } else {
            console.warn('Llego jugada_remota pero no habia nadie esperando:', msg);
        }
    }
    else if (msg.tipo === 'tu_turno') {
        // El motor (corriendo en la OTRA pestaña) dice que ahora
        // me toca jugar a MI. Si el mensaje es para mi nombre,
        // muestro botones reales y, al clickear, mando mi jugada
        // de vuelta por WebSocket.
        if (msg.jugador === miNombre) {
            mostrarBotonesParaTurnoRemoto(msg.mensaje, msg.opciones);
        }
    }
    else if (msg.tipo === 'rival_desconectado') {
        mostrarMensaje('El rival se desconecto.');
    }
};

ws.onerror = (e) => console.error('Error de WebSocket:', e);


// ------------------------------------------------------------
//  avisarMiJugadorAProlog(nombre)
//  Le dice a Prolog "yo soy este jugador", usando el predicado
//  asignar_mi_jugador/1 de estado_jugador.pl.
//  Se llama una sola vez, recien conectado.
// ------------------------------------------------------------
async function avisarMiJugadorAProlog(nombre) {
    // Prolog todavia no termino de cargar TODOS los modulos
    // (no alcanza con que window.swipl exista: puede existir la
    // instancia pero faltar consultar estado_jugador.pl todavia).
    if (!window.prologListo) {
        console.log('Prolog aun no esta listo, guardando para mas tarde...');
        window.miNombrePendiente = nombre;
        return;
    }
    try {
        const resultado = await window.swipl.prolog.query(
            `estado_jugador:asignar_mi_jugador(${nombre})`
        ).once();
        if (resultado === null) {
            console.error('asignar_mi_jugador fallo (query devolvio null)');
            return;
        }
        console.log(`✅ Prolog ya sabe que mi_jugador = ${nombre}`);
    } catch (err) {
        console.error('Error asignando mi_jugador en Prolog:', err);
    }
}


// ============================================================
//  mostrarBotonesParaTurnoRemoto(mensaje, opcionesStr)
//
//  Se llama cuando llega el mensaje "tu_turno" por WebSocket:
//  el motor de juego (corriendo en la OTRA pestaña) dice que
//  ahora me toca jugar a MI. A diferencia de mostrarOpciones,
//  ESTA funcion no la llama Prolog local (no hay ningun await
//  esperandola aca) - simplemente renderiza botones, y al
//  clickear manda la respuesta por WebSocket para que la
//  Promise remota del lado del motor se resuelva alla.
// ============================================================
function mostrarBotonesParaTurnoRemoto(mensaje, opcionesStr) {
    zonaMensajes.textContent = mensaje;
    zonaAcciones.innerHTML = '';

    const opciones = opcionesStr.split(',').filter(o => o.length > 0);

    opciones.forEach(opcion => {
        const boton = document.createElement('button');
        boton.textContent = etiquetaBoton(opcion);
        boton.dataset.valor = opcion;

        boton.addEventListener('click', () => {
            ws.send(JSON.stringify({
                tipo: 'jugada_remota',
                jugador: miNombre,
                valor: opcion
            }));
            deshabilitarBotones();
            zonaMensajes.textContent = `Jugaste: ${etiquetaBoton(opcion)}. Esperando al rival...`;
        });

        zonaAcciones.appendChild(boton);
    });
}


// ============================================================
//  mostrarOpciones(mensaje, opcionesStr)
//
//  CASO LOCAL: el turno de responder es MIO, y es PROLOG LOCAL
//  quien esta pidiendo esto (hay un await esperando la Promise
//  que devolvemos). Muestra botones reales y espera un click
//  humano. Cuando el usuario clickea, ademas de resolver la
//  Promise local, le avisamos al rival por WebSocket cual fue
//  la jugada (por si el rival tiene logica que dependa de verla,
//  aunque en el diseño actual el motor real solo corre del lado
//  del anfitrion).
// ============================================================
function mostrarOpciones(mensaje, opcionesStr) {
    return new Promise((resolve) => {
        resolverLocalPendiente = resolve;

        zonaMensajes.textContent = mensaje;
        zonaAcciones.innerHTML = '';

        const opciones = opcionesStr.split(',').filter(o => o.length > 0);

        opciones.forEach(opcion => {
            const boton = document.createElement('button');
            boton.textContent = etiquetaBoton(opcion);
            boton.dataset.valor = opcion;

            boton.addEventListener('click', () => {
                if (resolverLocalPendiente) {
                    // Resolvemos nuestra propia Promise (Prolog local sigue).
                    // No hace falta avisar al rival por WS aca: el motor
                    // solo corre en la pestana anfitriona, asi que este
                    // caso (jugada LOCAL del anfitrion) no tiene ninguna
                    // Promise remota esperando del otro lado.
                    resolverLocalPendiente(opcion);
                    resolverLocalPendiente = null;
                    deshabilitarBotones();
                }
            });

            zonaAcciones.appendChild(boton);
        });
    });
}


// ============================================================
//  esperarJugadaRemota(jugador, mensaje, opcionesStr)
//
//  CASO REMOTO: el turno de responder es del RIVAL.
//  No mostramos botones ACA; en cambio, le avisamos al RIVAL
//  por WebSocket que le toca jugar (mensaje "tu_turno"), para
//  que SU pestana muestre los botones reales. Nuestra Promise
//  se resuelve cuando llega su respuesta ("jugada_remota").
// ============================================================
function esperarJugadaRemota(jugador, mensaje, opcionesStr) {
    return new Promise((resolve) => {
        resolverRemotoPendiente = resolve;

        zonaAcciones.innerHTML = '';
        zonaMensajes.textContent = `Esperando a ${jugador}...`;

        // Le avisamos a la otra pestaña que es su turno, y con
        // que mensaje/opciones tiene que mostrar sus botones.
        ws.send(JSON.stringify({
            tipo: 'tu_turno',
            jugador: jugador,
            mensaje: mensaje,
            opciones: opcionesStr
        }));
    });
}


// Traduce los atomos de Prolog a textos mas lindos para el boton.
function etiquetaBoton(opcion) {
    const etiquetas = {
        truco: 'Truco!',
        retruco: 'Retruco!',
        vale4: 'Vale 4!',
        envido: 'Envido',
        real_envido: 'Real Envido',
        falta_envido: 'Falta Envido',
        quiero: 'Quiero',
        no_quiero: 'No Quiero',
        acepta: 'Acepta',
        rechaza: 'Rechaza',
        jugar: 'Jugar carta',
        cantar: 'Cantar'
    };
    return etiquetas[opcion] || opcion;
}

function deshabilitarBotones() {
    zonaAcciones.querySelectorAll('button').forEach(b => b.disabled = true);
}


// ------------------------------------------------------------
//  alertaOpcionInvalida(valor)
// ------------------------------------------------------------
function alertaOpcionInvalida(valor) {
    console.warn('Opcion invalida recibida:', valor);
    zonaMensajes.textContent = `Opción inválida: "${valor}", intentá de nuevo.`;
}

// ============================================================
//  actualizarPuntaje(nombreJugador, puntos)
//
//  La llama Prolog (gestor_estado.pl, notificar_puntajes/1)
//  cada vez que a un jugador se le suman puntos. Traduce el
//  puntaje total a malas/buenas y redibuja las tranqueras de
//  fosforos correspondientes (definidas en fosforos.js).
// ============================================================
function actualizarPuntaje(nombreJugador, puntos) {
    const malas = Math.min(puntos, 15);
    const buenas = Math.max(puntos - 15, 0);

    pintarFosforos(`malas-${nombreJugador === 'jugador1' ? 'j1' : 'j2'}`, malas);
    pintarFosforos(`buenas-${nombreJugador === 'jugador1' ? 'j1' : 'j2'}`, buenas);
}
window.actualizarPuntaje = actualizarPuntaje;


// Exponemos las funciones globalmente para que Prolog las encuentre
window.mostrarOpciones = mostrarOpciones;
window.esperarJugadaRemota = esperarJugadaRemota;
window.alertaOpcionInvalida = alertaOpcionInvalida;


// ============================================================
//  Helper para mostrar mensajes simples (sin pedir respuesta)
// ============================================================
function mostrarMensaje(texto) {
    zonaMensajes.textContent = texto;
}
window.mostrarMensaje = mostrarMensaje;


// ============================================================
//  intentarIniciarPartida()
//
//  Arranca el motor de juego UNA SOLA VEZ, y SOLO en la pestana
//  de jugador1 (el anfitrion). Se llama desde dos lugares
//  distintos (cuando Prolog termina de cargar, y cuando llega
//  "listos" del relay), porque no sabemos cual de los dos pasa
//  primero - por eso chequea AMBAS condiciones antes de arrancar.
// ============================================================
let partidaIniciada = false;

function intentarIniciarPartida() {
    if (partidaIniciada) return;
    if (!window.prologCargado) return;
    if (!ambosListos) return;
    if (miNombre !== 'jugador1') {
        // jugador2 no arranca su propia partida: solo espera a
        // que jugador1 (el anfitrion) le pida respuestas via
        // entrada_web cuando le corresponda jugar.
        mostrarMensaje('Esperando que jugador1 arranque la partida...');
        return;
    }

    partidaIniciada = true;
    window.arrancarPartidaReal();
}
window.intentarIniciarPartida = intentarIniciarPartida;