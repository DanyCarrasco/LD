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

        const opciones = opcionesStr.split(',').filter(o => o.length > 0);

        opciones.forEach(opcion => {
            const btn = document.createElement('button');
            btn.textContent = this.etiquetaBoton(opcion);
            btn.dataset.valor = opcion;

            btn.onclick = () => {
                // Deshabilitar todos los botones al clickear uno
                container.querySelectorAll('button').forEach(b => b.disabled = true);
                onSelect(opcion);
            };
            container.appendChild(btn);
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

    // Lógica para dibujar cartas en pantalla
renderizarManoLocal(cartasData) {
        console.log("DEBUG: Renderizando cartas. Datos recibidos:", cartasData);

        // 1. Limpiar mesa
        document.querySelectorAll('.carta:not(.jugada)').forEach(c => c.remove());

        let cartas = [];

        // CASO A: Viene del WebSocket (Jugador 2) -> Es un String ("o-1,e-6,c-10")
        if (typeof cartasData === 'string') {
            const ids = cartasData.split(',');
            cartas = ids.map(id => {
                return { id: id.trim() }; // Convertimos a objeto para igualarlo a Prolog
            });
        }
        // CASO B: Viene directo de Prolog (Jugador 1) -> Ya es un Array de objetos
        else if (Array.isArray(cartasData)) {
            cartas = cartasData;
        }

        // 2. Dibujar las cartas
        cartas.forEach((datos, index) => {
            if (!datos.id) return;

            const div = document.createElement('div');
            div.className = 'carta';
            div.dataset.valorCarta = datos.id;

            // Si Prolog manda la propiedad img la usamos, sino la construimos con el ID
            const urlImagen = datos.img ? datos.img : `url('./Carta/img/${datos.id}.png')`;
            div.style.setProperty('--img', urlImagen);

            // Posicionamiento calculado
            const left = 60 + (index * 6);
            div.style.left = `${left}%`;
            div.style.top = '65%';

            // Conectar el Drag & Drop
            if (window.Interaccion3D) {
                window.Interaccion3D.configurar(div);
            }

            document.body.appendChild(div);
        });
    }
};




window.mostrarMensaje = (texto) => UI.showMessage(texto);