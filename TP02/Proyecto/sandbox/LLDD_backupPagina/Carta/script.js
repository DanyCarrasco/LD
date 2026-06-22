// 1. Datos de las cartas (puedes añadir o quitar las que quieras desde aquí)
const dataCartas = [
  { left: '60%', top: '70%', img: "url('./Carta/img/b-1.png')" },
  { left: '65%', top: '70%', img: "url('./Carta/img/e-1.png')" },
  { left: '70%', top: '70%', img: "url('./Carta/img/c-1.png')" }
];

// 2. Estado global del Drag & Drop
let cartaActiva = null;
let offsetX = 0, offsetY = 0;
let posicionAnteriorX = 0;
let posicionAnteriorY = 0;
let posicionInicialLeft = "";
let posicionInicialTop = "";

const zonaDrop = document.getElementById('zonaDrop');

// 3. Función para renderizar y configurar las cartas dinámicamente
function inicializarCartas() {
  dataCartas.forEach(datos => {
    // Crear el elemento div de la carta
    const nuevaCarta = document.createElement('div');
    nuevaCarta.classList.add('carta');

    // Aplicar estilos iniciales mediante propiedades CSS personalizadas e inline
    nuevaCarta.style.left = datos.left;
    nuevaCarta.style.top = datos.top;
    nuevaCarta.style.setProperty('--img', datos.img);

    // Añadir evento Mousedown a cada carta generada
    nuevaCarta.addEventListener('mousedown', (e) => {
      if (e.button !== 0) return; // Solo click izquierdo

      nuevaCarta.classList.remove('regresando');

      // Si la carta ya estaba jugada, la regresamos al body temporalmente para arrastrarla
      if (nuevaCarta.classList.contains('jugada')) {
        nuevaCarta.classList.remove('jugada');
        const rect = nuevaCarta.getBoundingClientRect();
        nuevaCarta.style.left = `${rect.left}px`;
        nuevaCarta.style.top = `${rect.top}px`;
        document.body.appendChild(nuevaCarta);
      }

      cartaActiva = nuevaCarta;

      posicionInicialLeft = cartaActiva.style.left;
      posicionInicialTop = cartaActiva.style.top;

      offsetX = e.clientX - cartaActiva.getBoundingClientRect().left;
      offsetY = e.clientY - cartaActiva.getBoundingClientRect().top;

      posicionAnteriorX = e.clientX;
      posicionAnteriorY = e.clientY;
    });

    // Inyectar la carta en el body al inicio
    document.body.appendChild(nuevaCarta);
  });
}

// 4. Listeners globales del documento (Manejo del movimiento y soltado)

document.addEventListener('mousemove', (e) => {
  if (!cartaActiva) return;

  let nuevaX = e.clientX - offsetX;
  let nuevaY = e.clientY - offsetY;
  cartaActiva.style.left = `${nuevaX}px`;
  cartaActiva.style.top = `${nuevaY}px`;

  let velocidadX = e.clientX - posicionAnteriorX;
  let velocidadY = e.clientY - posicionAnteriorY;

  let maximaInclinacion = 25;
  let rotacionY = Math.max(Math.min(velocidadX * 2, maximaInclinacion), -maximaInclinacion);
  let rotacionX = Math.max(Math.min(-velocidadY * 2, maximaInclinacion), -maximaInclinacion);

  cartaActiva.style.setProperty('--rotX', `${rotacionX}deg`);
  cartaActiva.style.setProperty('--rotY', `${rotacionY}deg`);

  posicionAnteriorX = e.clientX;
  posicionAnteriorY = e.clientY;
});

// Cancelación con Click Derecho
document.addEventListener('mousedown', (e) => {
  if (e.button === 2 && cartaActiva) {
    const cartaALimpiar = cartaActiva;
    regresarASitioOriginal(cartaALimpiar);

    setTimeout(() => { cartaActiva = null; }, 10);
  }
});

document.addEventListener('contextmenu', (e) => {
  if (cartaActiva || e.target.classList.contains('carta')) {
    e.preventDefault();
  }
});

// Soltar la carta
document.addEventListener('mouseup', (e) => {
  if (e.button !== 0 || !cartaActiva) return;

  cartaActiva.style.visibility = 'hidden';
  let elementoAbajo = document.elementFromPoint(e.clientX, e.clientY);
  cartaActiva.style.visibility = 'visible';

  if (elementoAbajo && (elementoAbajo === zonaDrop || zonaDrop.contains(elementoAbajo))) {
    cartaActiva.style.setProperty('--rotX', '0deg');
    cartaActiva.style.setProperty('--rotY', '0deg');
    cartaActiva.classList.add('jugada');

    // --- ESTO ES LO NUEVO ---
    const cartaJugada = cartaActiva.dataset.valorCarta;
    console.log("Jugando carta:", cartaJugada);

    // Asumiendo que guardaste la referencia a la promesa en tu bridge
    if (window.resolverJugada) {
        window.resolverJugada(cartaJugada);
    }
    // ------------------------

    zonaDrop.appendChild(cartaActiva);
    cartaActiva = null;
  } else {
    regresarASitioOriginal(cartaActiva);
    cartaActiva = null;
  }
});

// Función auxiliar para el retorno suave
function regresarASitioOriginal(elemento) {
  elemento.classList.add('regresando');
  elemento.style.left = posicionInicialLeft;
  elemento.style.top = posicionInicialTop;
  elemento.style.setProperty('--rotX', '0deg');
  elemento.style.setProperty('--rotY', '0deg');

  setTimeout(() => {
    elemento.classList.remove('regresando');
  }, 400);
}

// 5. Encender el motor e inicializar las cartas creadas por JS
inicializarCartas();

