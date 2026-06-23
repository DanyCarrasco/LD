// js/bridge.js
import { Network } from './network.js';
import { UI } from './ui.js';

export const Bridge = {
    miNombre: null,
    resolverLocalPendiente: null,
    resolverRemotoPendiente: null,
    ambosListos: false,
    partidaIniciada: false,

    // Network es quien envia los mensajes que el bridge debe resolver
    init() {
        console.log('Iniciando Bridge...');
        // Puerto 8080 es del relay donde network recibira los mensajes
        Network.connect('ws://localhost:8080', (msg) => this.handleMessage(msg));
    },

    // Network ejecuta handleMessage, y el bridge resuelve de acuerdo al tipo de mensaje
    handleMessage(msg) {
        switch(msg.tipo) {
            //  Relacionado a conexion
            case 'unido':
                console.log('llamando a UI');
                this.miNombre = msg.jugador;
                UI.showMessage(`Conectado como ${msg.jugador}. Avisale a Prolog...`);
                UI.setAvatares(this.miNombre);
                this.avisarMiJugadorAProlog(msg.jugador);
                break;

            case 'listos':
                UI.showMessage(`Listos: ${msg.jugadores.join(' y ')}.`);
                this.ambosListos = true;
                this.intentarIniciarPartida();
                break;

            case 'rival_desconectado':
                UI.showMessage('El rival se desconectó.');
                break;

            //  Relacionado a los turnos
            case 'jugada_remota':
                // Promesa remota (respuesta del rival)
                if (this.resolverRemotoPendiente) {
                    this.resolverRemotoPendiente(msg.valor);
                    this.resolverRemotoPendiente = null;
                }
                break;

            case 'tu_turno':
                // Turno remoto (me toca a mi)
                if (msg.jugador === this.miNombre) {
                    this.mostrarBotonesParaTurnoRemoto(msg.mensaje, msg.opciones);
                }
                break;

            // Relacionado a estados del juego
            case 'repartir_mano':
                if (msg.jugador === this.miNombre) {
                    UI.renderizarManoLocal(msg.mano);
                }
                break;

            case 'puntaje_actualizado':
                if (window.actualizarPuntaje) {
                    window.actualizarPuntaje(msg.jugador, msg.puntos);
                }
                break;


            // Relacionado a lo visual
            case 'carta_jugada_visual':

            if (msg.mano !== UI.numeroMano) {
                console.log(
                    "Descartando visual vieja",
                    msg.carta,
                    "mano",
                    msg.mano,
                    "actual",
                    UI.numeroMano
                );
                return;
            }

            UI.renderizarJugada(msg.jugador, msg.carta);
            break;

        }
    },

    // ------------------------------------------------------------
    // LOGICA DE PROLOG Y PARTIDA
    // ------------------------------------------------------------
    async avisarMiJugadorAProlog(nombre) {
        if (!window.prologListo || !window.swipl) {
            console.log('Prolog aun no esta listo, guardando para mas tarde...');
            window.miNombrePendiente = nombre;
            return;
        }
        try {
            await window.swipl.prolog.query(`estado_jugador:asignar_mi_jugador(${nombre})`).once();
            console.log(`✅ Prolog ya sabe que mi_jugador = ${nombre}`);
        } catch (err) {
            console.error('Error asignando mi_jugador en Prolog:', err);
        }
    },

    intentarIniciarPartida() {
        if (this.partidaIniciada || !window.prologCargado || !this.ambosListos) return;

        if (this.miNombre !== 'jugador1') {
            UI.showMessage('Esperando que jugador1 arranque la partida...');
            return;
        }

        this.partidaIniciada = true;
        if (window.arrancarPartidaReal) {
            window.arrancarPartidaReal();
        }
    },

    // ------------------------------------------------------------
    // MANEJO DE TURNOS Y OPCIONES (Llamados por Prolog o Network)
    // ------------------------------------------------------------
    mostrarBotonesParaTurnoRemoto(mensaje, opcionesStr) {
        UI.showMessage(mensaje);
        UI.renderButtons(opcionesStr, (opcionSeleccionada) => {
            Network.send('jugada_remota', {
                jugador: this.miNombre,
                valor: opcionSeleccionada
            });
            UI.showMessage(`Jugaste: ${UI.etiquetaBoton(opcionSeleccionada)}. Esperando al rival...`);
        });
    },

    mostrarOpciones(mensaje, opcionesStr) {
        return new Promise((resolve) => {
            this.resolverLocalPendiente = resolve;
            UI.showMessage(mensaje);
            UI.renderButtons(opcionesStr, (opcionSeleccionada) => {
                if (this.resolverLocalPendiente) {
                    this.resolverLocalPendiente(opcionSeleccionada);
                    this.resolverLocalPendiente = null;
                }
            });
        });
    },

    esperarJugadaRemota(jugador, mensaje, opcionesStr) {
        return new Promise((resolve) => {
            this.resolverRemotoPendiente = resolve;
            UI.showMessage(`Esperando a ${jugador}...`);
            Network.send('tu_turno', {
                jugador: jugador,
                mensaje: mensaje,
                opciones: opcionesStr
            });
        });
    },

    notificarJugada(valorCarta) {
        window.inhabilitarCartas(false);
        console.log("Carta notificada al Bridge:", valorCarta);

        // CASO A: Soy el anfitrión y Prolog está esperando que resuelva mi turno localmente
        if (this.resolverLocalPendiente) {
            this.resolverLocalPendiente(valorCarta);
            this.resolverLocalPendiente = null;
        }
        // CASO B: Soy el invitado y debo mandarle mi jugada al anfitrión
        else {
            Network.send('jugada_remota', {
                jugador: this.miNombre,
                valor: valorCarta
            });
        }

        if (UI.renderizarJugada) {
            UI.renderizarJugada(this.miNombre, valorCarta);
        }

       Network.send('carta_jugada_visual', {
            jugador: this.miNombre,
            carta: valorCarta,
            mano: UI.numeroMano
        });
    }

};

window.PrologBridge = Bridge;

// ============================================================
// EXPOSICIONES GLOBALES PARA PROLOG Y OTROS SCRIPTS
// ============================================================

window.mostrarOpciones = (m, o) => Bridge.mostrarOpciones(m, o);
window.esperarJugadaRemota = (j, m, o) => Bridge.esperarJugadaRemota(j, m, o);
window.alertaOpcionInvalida = (valor) => {
    console.warn('Opcion invalida:', valor);
    UI.showMessage(`Opción inválida: "${valor}", intentá de nuevo.`);
};
window.intentarIniciarPartida = () => Bridge.intentarIniciarPartida();

// Cartas
window.renderizarMano = (cartasData) => UI.renderizarManoLocal(cartasData);
window.enviarManoRival = (jugador, manoStr) => {
    Network.send('repartir_mano', { jugador: jugador, mano: manoStr });
};
window.pedirJugadaAlUsuario = () => new Promise(resolve => window.resolverJugada = resolve);

window.notificarPuntaje = function(jugador, puntos) {
    if (window.actualizarPuntaje) window.actualizarPuntaje(jugador, puntos);
    Network.send('puntaje_actualizado', { jugador, puntos });
};

Bridge.init();

