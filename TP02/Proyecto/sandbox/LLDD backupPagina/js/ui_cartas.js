window.UIManejador = {
    renderizarMano: function(cartasData) {
        // Limpiar cartas previas
        document.querySelectorAll('.carta').forEach(c => c.remove());

        const contenedor = document.body;
        cartasData.forEach(datos => {
            const div = document.createElement('div');
            div.className = 'carta';
            div.dataset.valorCarta = datos.id;
            div.style.left = datos.left;
            div.style.top = datos.top;
            div.style.setProperty('--img', datos.img);

            window.Interaccion3D.configurar(div);

            contenedor.appendChild(div);
        });
    }
};