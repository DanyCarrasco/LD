// js/ui.js
export const UI = {
    etiquetas: {
        truco: 'Truco!', retruco: 'Retruco!', vale4: 'Vale 4!',
        envido: 'Envido', real_envido: 'Real Envido', falta_envido: 'Falta Envido',
        quiero: 'Quiero', no_quiero: 'No Quiero', acepta: 'Acepta',
        rechaza: 'Rechaza', jugar: 'Jugar carta', cantar: 'Cantar'
    },

    etiquetaBoton(opcion) {
        return this.etiquetas[opcion] || opcion;
    },

    renderButtons(opcionesStr, onSelect) {
        const container = document.getElementById('zonaAcciones');
        container.innerHTML = '';

        // Por seguridad, bloqueamos las cartas cada vez que cambia el estado
        this.setCartasInteractivas(false);

        const opciones = opcionesStr.split(',').map(o => o.trim()).filter(o => o.length > 0);

        // CASO 1: ¿Prolog nos mandó directamente las cartas permitidas? (Ej: "o-6", "e-1")
        const sonSoloCartas = opciones.length > 0 && opciones.every(o => /^[oebc]-\d+$/.test(o));

        if (sonSoloCartas) {
            // No creamos NINGÚN botón. Directamente habilitamos el drag and drop.
            this.setCartasInteractivas(true);
            this.showMessage("Arrastrá una carta de tu mano a la mesa...");
            return; // El "drop" de la carta llamará a bridge.js automáticamente
        }

        // CASO 2: Prolog envía acciones (jugar, cantar, envido, quiero, etc.)
        opciones.forEach(opcion => {
            const btn = document.createElement('button');
            btn.textContent = this.etiquetaBoton(opcion);

            btn.onclick = () => {
                // Al hacer clic, borramos TODOS los botones para que no haya redundancias
                container.innerHTML = '';

                if (opcion === 'jugar') {
                    // Si eligió jugar carta, habilitamos las cartas y le avisamos a Prolog
                    this.showMessage("Arrastrá tu carta a la mesa...");
                    this.setCartasInteractivas(true);
                }

                // Le enviamos la decisión ('jugar' o 'cantar') a Prolog
                onSelect(opcion);
            };

            container.appendChild(btn);
        });
    },

    setCartasInteractivas(activado) {
        document.querySelectorAll('.carta').forEach(carta => {
            if (!carta.classList.contains('jugada')) {
                carta.style.pointerEvents = activado ? 'auto' : 'none';
            }
        });
    },

    colocarCartaRivalEnMesa(cartaId) {
        // Buscamos los slots correspondientes al rival (y = 0)
        const slotsRivales = Array.from(document.querySelectorAll('.cartas[style*="--y: 0"]'));

        // Buscamos el primero libre
        const slotVacio = slotsRivales.find(slot => !slot.dataset.ocupado);

        if (slotVacio) {
            // Le aplicamos directamente la imagen como fondo
            slotVacio.style.backgroundImage = `url('./Carta/img/${cartaId}.png')`;
            slotVacio.style.backgroundSize = 'cover';
            slotVacio.style.backgroundPosition = 'center';

            // Lo marcamos como ocupado
            slotVacio.dataset.ocupado = "true";
        } else {
            console.warn("La mesa del rival ya está llena.");
        }
    },

    showMessage(txt) {
        document.getElementById('zonaMensajes').textContent = txt;
    },

    setAvatares(miNombre) {
        const yo = document.getElementById('yo');
        const rival = document.getElementById('rival');
        if (!yo || !rival) return;

        if (miNombre === 'jugador1') {
            yo.style.setProperty('--img', "url('./assets/gaucho1.png')");
            rival.style.setProperty('--img', "url('./assets/gaucho2.png')");
        } else {
            yo.style.setProperty('--img', "url('./assets/gaucho2.png')");
            rival.style.setProperty('--img', "url('./assets/gaucho1.png')");
        }
    },

    renderizarJugada(miNombre, cartaId) {
        let slots;
        console.log(miNombre);
        if (miNombre === this.miNombre) {
            slots = document.querySelectorAll('.cartas-yo');
        } else {
            slots = document.querySelectorAll('.cartas-rival');
        }

        for (const slot of slots) {

            if (!slot.dataset.ocupado) {

                slot.style.backgroundImage =
                    `url('./Carta/img/${cartaId}.png')`;

                slot.style.backgroundSize = 'cover';
                slot.style.backgroundPosition = 'center';

                slot.dataset.ocupado = 'true';

                break;
            }
        }
    },

    pintarCarta(x, carta){},

    renderizarManoLocal(cartasData) {
        // Limpiar mesa de cartas no jugadas
        document.querySelectorAll('.carta:not(.jugada)').forEach(c => c.remove());

        let cartas = [];

        if (typeof cartasData === 'string') {
            const ids = cartasData.split(',');
            cartas = ids.map(id => {
                return { id: id.trim() };
            });
        }
        else if (Array.isArray(cartasData)) {
            cartas = cartasData;
        }

        // Dibujar las cartas en la interfaz
        cartas.forEach((datos, index) => {
            if (!datos.id) return;

            const div = document.createElement('div');
            div.className = 'carta';
            div.dataset.valorCarta = datos.id;

            const urlImagen = datos.img ? datos.img : `url('./Carta/img/${datos.id}.png')`;
            div.style.setProperty('--img', urlImagen);

            const left = 60 + (index * 6);
            div.style.left = `${left}%`;
            div.style.top = '65%';

            if (window.Interaccion3D) {
                window.Interaccion3D.configurar(div);
            }

            document.body.appendChild(div);
        });

        // Al repartir, nacen bloqueadas esperando instrucciones de Prolog
        this.setCartasInteractivas(false);
    }
};

window.mostrarMensaje = (texto) => UI.showMessage(texto);
window.inhabilitarCartas = (v) => UI.setCartasInteractivas(v);