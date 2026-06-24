window.Interaccion3D = {
    // 1. ESTADO GLOBAL DEL DRAG & DROP
    cartaActiva: null,
    offsetX: 0,
    offsetY: 0,
    posicionAnteriorX: 0,
    posicionAnteriorY: 0,
    posicionInicialLeft: "",
    posicionInicialTop: "",

    // 2. CONFIGURAR CADA CARTA (Se llama desde ui.js al crearlas)
    configurar: function(nuevaCarta) {
        nuevaCarta.addEventListener('mousedown', (e) => {
            if (e.button !== 0) return; // Solo click izquierdo

            nuevaCarta.classList.remove('regresando');

            // Si la carta ya estaba jugada, la regresamos al body temporalmente
            if (nuevaCarta.classList.contains('jugada')) {
                nuevaCarta.classList.remove('jugada');
                const rect = nuevaCarta.getBoundingClientRect();
                nuevaCarta.style.left = `${rect.left}px`;
                nuevaCarta.style.top = `${rect.top}px`;
                document.body.appendChild(nuevaCarta);
            }

            this.cartaActiva = nuevaCarta;
            this.posicionInicialLeft = nuevaCarta.style.left;
            this.posicionInicialTop = nuevaCarta.style.top;

            this.offsetX = e.clientX - nuevaCarta.getBoundingClientRect().left;
            this.offsetY = e.clientY - nuevaCarta.getBoundingClientRect().top;

            this.posicionAnteriorX = e.clientX;
            this.posicionAnteriorY = e.clientY;
        });
    },

    // 3. EVENTOS GLOBALES (Movimiento, Drop y Cancelaciones)
    initGlobalListeners: function() {

        // MOVIMIENTO 3D
        document.addEventListener('mousemove', (e) => {
            if (!this.cartaActiva) return;

            // Actualizar posición
            let nuevaX = e.clientX - this.offsetX;
            let nuevaY = e.clientY - this.offsetY;
            this.cartaActiva.style.left = `${nuevaX}px`;
            this.cartaActiva.style.top = `${nuevaY}px`;

            // Calcular rotación en base a la velocidad
            let velocidadX = e.clientX - this.posicionAnteriorX;
            let velocidadY = e.clientY - this.posicionAnteriorY;

            let maximaInclinacion = 25;
            let rotacionY = Math.max(Math.min(velocidadX * 2, maximaInclinacion), -maximaInclinacion);
            let rotacionX = Math.max(Math.min(-velocidadY * 2, maximaInclinacion), -maximaInclinacion);

            this.cartaActiva.style.setProperty('--rotX', `${rotacionX}deg`);
            this.cartaActiva.style.setProperty('--rotY', `${rotacionY}deg`);

            this.posicionAnteriorX = e.clientX;
            this.posicionAnteriorY = e.clientY;
        });

        // SOLTAR LA CARTA (DROP)
        document.addEventListener('mouseup', (e) => {
            if (e.button !== 0 || !this.cartaActiva) return;

            const carta = this.cartaActiva;
            const zonaDrop = document.getElementById('zonaDrop');

            // Detectar qué hay debajo
            carta.style.visibility = 'hidden';
            let elementoAbajo = document.elementFromPoint(e.clientX, e.clientY);
            carta.style.visibility = 'visible';

            // Al soltar las carta en la zona drop
            if (elementoAbajo && (elementoAbajo === zonaDrop || zonaDrop.contains(elementoAbajo))) {
                carta.style.display = 'none';
                carta.classList.add('jugada');

                const cartaJugada = carta.dataset.valorCarta;

                console.log("Jugando carta:", cartaJugada);

                if (window.PrologBridge && window.PrologBridge.notificarJugada) {
                    window.PrologBridge.notificarJugada(cartaJugada);
                } else if (window.PrologBridge.resolverJugada) {
                    window.PrologBridge.resolverJugada(cartaJugada);
                }

                this.cartaActiva = null;
            } else {
                this.regresarAlSitio(carta);
                this.cartaActiva = null;
            }
});

        // CANCELACIÓN CON CLICK DERECHO
        document.addEventListener('mousedown', (e) => {
            if (e.button === 2 && this.cartaActiva) {
                const cartaALimpiar = this.cartaActiva;
                this.regresarAlSitio(cartaALimpiar);
                setTimeout(() => { this.cartaActiva = null; }, 10);
            }
        });

        // PREVENIR MENÚ CONTEXTUAL AL ARRASTRAR O HACER CLICK DERECHO EN LA CARTA
        document.addEventListener('contextmenu', (e) => {
            if (this.cartaActiva || e.target.classList.contains('carta')) {
                e.preventDefault();
            }
        });
    },

    // 4. FUNCIÓN AUXILIAR: RETORNO SUAVE
    regresarAlSitio: function(elemento) {
        elemento.classList.add('regresando');
        elemento.style.left = this.posicionInicialLeft;
        elemento.style.top = this.posicionInicialTop;
        elemento.style.setProperty('--rotX', '0deg');
        elemento.style.setProperty('--rotY', '0deg');

        setTimeout(() => {
            elemento.classList.remove('regresando');
        }, 400);
    }
};

// 5. ENCENDIDO INICIAL DE LOS EVENTOS GLOBALES
window.Interaccion3D.initGlobalListeners();