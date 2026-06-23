// js/network.js
export const Network = {
    ws: null,

    // Cuando se conecta al websocket el jugador
    connect(url, onMessage) {
        this.ws = new WebSocket(url);

        // 1. CUANDO SE ABRE LA CONEXIÓN MANDAMOS 'unirse'
        this.ws.onopen = () => {
            console.log('Conexión abierta. Solicitando unirse...');
            this.send('unirse'); 
        };

        // 2. CUANDO LLEGAN MENSAJES SE LOS PASAMOS AL BRIDGE
        this.ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            console.log('Mensaje recibido:', msg); // Chivato util para ver qué llega
            onMessage(msg);
        };

        this.ws.onerror = (error) => {
            console.error('Error en WebSocket:', error);
        };
    },

    // Auxiliar para mandar mensajes al bridge
    send(tipo, data = {}) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ tipo, ...data }));
        }
    }
};