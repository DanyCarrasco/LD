// relay.js
// Servidor de RELAY puro: no sabe nada de truco, solo reenvia mensajes.
// Toda la logica del juego corre en el navegador (Prolog WASM).
//
// Instalar dependencia:   npm install ws
// Correr:                 node relay.js

const WebSocket = require('ws');

const PORT = 8080;
const wss = new WebSocket.Server({ port: PORT });

// Guardamos las conexiones de los 2 jugadores
let jugadores = []; // [{ ws, nombre }]

console.log(`Relay escuchando en ws://localhost:${PORT}`);

wss.on('connection', (ws) => {
    console.log('Nueva conexion entrante');

    let nombreAsignado = null;

    ws.on('message', (raw) => {
        let msg;
        try {
            msg = JSON.parse(raw);
        } catch (e) {
            console.error('JSON invalido:', raw.toString());
            return;
        }

        // Primer mensaje esperado: { tipo: "unirse", jugador: "jugador1" }
        if (msg.tipo === 'unirse' && !nombreAsignado) {
            nombreAsignado = msg.jugador;
            jugadores.push({ ws, nombre: nombreAsignado });
            console.log(`${nombreAsignado} se unio. Total: ${jugadores.length}`);

            // Avisar a este jugador que se unio bien
            ws.send(JSON.stringify({ tipo: 'unido', jugador: nombreAsignado }));

            // Si ya estan los 2, avisar a ambos que el juego puede arrancar
            if (jugadores.length === 2) {
                broadcast({ tipo: 'listos', jugadores: jugadores.map(j => j.nombre) });
            }
            return;
        }

        // Cualquier otro mensaje: reenviar al RIVAL (no al que lo mando)
        console.log(`Reenviando de ${nombreAsignado}:`, msg);
        reenviarAlRival(ws, msg);
    });

    ws.on('close', () => {
        jugadores = jugadores.filter(j => j.ws !== ws);
        console.log(`${nombreAsignado || 'cliente'} desconectado. Total: ${jugadores.length}`);
        broadcast({ tipo: 'rival_desconectado', jugador: nombreAsignado });
    });
});

// Envia un mensaje a todos los jugadores conectados
function broadcast(obj) {
    const data = JSON.stringify(obj);
    jugadores.forEach(j => j.ws.send(data));
}

// Envia un mensaje a todos MENOS al que lo origino
function reenviarAlRival(wsOrigen, obj) {
    const data = JSON.stringify(obj);
    jugadores.forEach(j => {
        if (j.ws !== wsOrigen) j.ws.send(data);
    });
}