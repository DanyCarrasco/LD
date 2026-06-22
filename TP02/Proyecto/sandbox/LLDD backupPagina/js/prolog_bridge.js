// =========================================================================
//  PrologBridge: El Corazón del Sistema
// =========================================================================

window.PrologBridge = {
    resolverLocalPendiente: null,
    resolverRemotoPendiente: null,
    resolverJugadaCartas: null, // Para la promesa de las cartas 3D

    // 1. Renderizado de cartas (Llamado desde interfaz_web.pl)
    renderizarManoLocal: function(manoStr) {
        console.log("Renderizando mano:", manoStr);
        const ids = manoStr.split(',');

        // Calculamos posiciones dinámicas según la cantidad de cartas
        const data = ids.map((id, index) => ({
            id: id,
            left: `${40 + (index * 8)}%`,
            top: '70%',
            img: `url('./Carta/img/${id}.png')`
        }));

        // Delegamos al "Artista" (ui_cartas.js)
        window.UIManejador.renderizarMano(data);
    },

    // 2. Gestión de Promesas para Prolog (await/2)
    pedirJugadaAlUsuario: function() {
        return new Promise((resolve) => {
            this.resolverJugadaCartas = resolve;
        });
    },

    // 3. Notificación interna desde Interaccion3D
    notificarJugada: function(idCarta) {
        if (this.resolverJugadaCartas) {
            this.resolverJugadaCartas(idCarta);
            this.resolverJugadaCartas = null;
        }
    },

    // ---------------------------------------------------------------------
    // Mantenemos las funciones originales de tu bridge para no romper nada:
    // ---------------------------------------------------------------------
    mostrarOpciones: function(mensaje, opcionesStr) {
        return new Promise((resolve) => {
            this.resolverLocalPendiente = resolve;
            // Aquí llamarías a tu lógica de mostrar botones
            console.log("Mostrando opciones:", opcionesStr);
        });
    },

    esperarJugadaRemota: function(jugador, mensaje, opcionesStr) {
        return new Promise((resolve) => {
            this.resolverRemotoPendiente = resolve;
        });
    }
};

// =========================================================================
//  Helpers Globales (Que el motor de juego espera encontrar)
// =========================================================================
window.mostrarMensaje = function(texto) {
    const zonaMensajes = document.getElementById('zonaMensajes');
    if (zonaMensajes) zonaMensajes.textContent = texto;
    console.log("Mensaje:", texto);
};

window.intentarIniciarPartida = function() {
    // Tu lógica original de inicio de partida (chequeo de anfitrión, etc)
    if (window.partidaIniciada) return;
    if (!window.prologCargado) return;
    // ... resto de tu lógica original ...
    console.log("Iniciando motor de juego...");
    window.arrancarPartidaReal();
};