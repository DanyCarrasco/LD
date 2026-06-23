// js/cartas.js

export const CartasUI = {
    // Función para limpiar la mesa y renderizar nuevas cartas
    renderizarMano(listaCartas, contenedorPadre = document.body) {
        // Limpiamos las cartas existentes en el contenedor
        contenedorPadre.querySelectorAll('.carta').forEach(c => c.remove());

        listaCartas.forEach(datos => {
            const div = document.createElement('div');
            div.className = 'carta';

            // Guardamos toda la info técnica en el dataset
            div.dataset.id = datos.id;           // ID interno para Prolog
            div.dataset.valor = datos.valor;     // Valor (ej: 'ancho_espada')

            // Posicionamiento y estilos
            div.style.left = datos.left || '0%';
            div.style.top = datos.top || '0%';
            div.style.setProperty('--img', datos.img);

            // Inyectamos la lógica de drag & drop (la que ya tenías)
            this.configurarEventos(div);

            contenedorPadre.appendChild(div);
        });
    }
};