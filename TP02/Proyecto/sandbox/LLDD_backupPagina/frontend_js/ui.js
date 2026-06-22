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

    // Controlador del flujo de opciones en el turno
    renderButtons(opcionesStr, onSelect) {
        const container = document.getElementById('zonaAcciones');
        container.innerHTML = '';
        
        // Al recibir nuevas opciones, las cartas empiezan bloqueadas por seguridad
        this.setCartasInteractivas(false);

        const opciones = opcionesStr.split(',').filter(o => o.length > 0);
        
        // Separamos las cartas de las acciones (cantos o respuestas como quiero/no_quiero)
        const cartasOpciones = opciones.filter(o => /^[oebc]-\d+$/.test(o));
        const accionesOpciones = opciones.filter(o => !/^[oebc]-\d+$/.test(o));

        // CASO 1: No hay cartas para jugar (ej: respondiendo a un Envido o Truco del rival)
        // Mostramos las opciones de respuesta directamente
        if (cartasOpciones.length === 0) {
            this.renderBotonesDirectos(accionesOpciones, onSelect);
            return;
        }

        // CASO 2: Turno estándar (Se puede cantar o jugar carta)
        this.mostrarMenuPrincipalTurno(accionesOpciones, cartasOpciones, onSelect);
    },

    mostrarMenuPrincipalTurno(acciones, cartas, onSelect) {
        const container = document.getElementById('zonaAcciones');
        container.innerHTML = '';
        this.setCartasInteractivas(false);
        this.showMessage("Es tu turno. Seleccioná una acción:");

        // Botón de Cantar (solo si hay cantos disponibles como Truco o Envido)
        if (acciones.length > 0) {
            const btnCantar = document.createElement('button');
            btnCantar.textContent = '🗣️ Cantar...';
            btnCantar.onclick = () => this.mostrarMenuCantos(acciones, cartas, onSelect);
            container.appendChild(btnCantar);
        }

        // Botón de Jugar Carta principal
        const btnJugar = document.createElement('button');
        btnJugar.textContent = '🃏 Jugar carta';
        btnJugar.onclick = () => {
            // FLUJO DIRECTO: Desbloqueamos las cartas inmediatamente al hacer clic
            this.setCartasInteractivas(true);
            this.showMessage("Arrastrá una carta de tu mano a la mesa para jugarla...");

            // Limpiamos los botones y solo dejamos un botón de "Volver" por si se arrepiente
            container.innerHTML = '';
            const btnVolver = document.createElement('button');
            btnVolver.textContent = '⬅️ Volver';
            btnVolver.style.backgroundColor = '#555';
            btnVolver.onclick = () => this.mostrarMenuPrincipalTurno(acciones, cartas, onSelect);
            container.appendChild(btnVolver);
        };
        container.appendChild(btnJugar);
    },

    mostrarMenuCantos(acciones, cartas, onSelect) {
        const container = document.getElementById('zonaAcciones');
        container.innerHTML = '';

        acciones.forEach(opcion => {
            const btn = document.createElement('button');
            btn.textContent = this.etiquetaBoton(opcion);
            btn.onclick = () => {
                container.querySelectorAll('button').forEach(b => b.disabled = true);
                onSelect(opcion);
            };
            container.appendChild(btn);
        });

    },

    renderBotonesDirectos(opciones, onSelect) {
        const container = document.getElementById('zonaAcciones');
        container.innerHTML = '';
        opciones.forEach(opcion => {
            const btn = document.createElement('button');
            btn.textContent = this.etiquetaBoton(opcion);
            btn.onclick = () => {
                container.querySelectorAll('button').forEach(b => b.disabled = true);
                onSelect(opcion);
            };
            container.appendChild(btn);
        });
    },

    // Activa o desactiva el arrastre de las cartas (Sin alterar la opacidad visual)
    setCartasInteractivas(activado) {
        document.querySelectorAll('.carta').forEach(carta => {
            if (!carta.classList.contains('jugada')) {
                // Controlamos la interacción puramente con pointer-events
                carta.style.pointerEvents = activado ? 'auto' : 'none';
            }
        });
    },

    showMessage(txt) {
        document.getElementById('zonaMensajes').textContent = txt;
    },

    setAvatares(miNombre) {
        console.log('seteando avatares');
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

    renderizarManoLocal(cartasData) {
        console.log("DEBUG: Renderizando cartas. Datos recibidos:", cartasData);

        // 1. Limpiar mesa de cartas no jugadas
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

        // 2. Dibujar las cartas en la interfaz
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

        // Al repartir la mano, las cartas nacen bloqueadas hasta que el turno requiera lo contrario
        this.setCartasInteractivas(false);
    }
};

window.mostrarMensaje = (texto) => UI.showMessage(texto);