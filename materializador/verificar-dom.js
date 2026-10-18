// Comprueba lo que la pagina DIBUJA contra los oraculos.
//
// EL PROBLEMA QUE RESUELVE
//
// verificar-web.js ejecuta el calculo de la pagina y lo compara con el
// evaluador, pero no dibuja nada: una tabla que no se dibujara, una vista
// que se perdiera o una celda que ensenara otra cosa pasaban sin que nadie
// lo viera. Dos vistas de lista sobre la misma coleccion salian como una
// sola tabla y todo daba verde.
//
// Esta comprobacion abre la pagina en Chromium y lee lo que se ve:
//
//   - cada tabla de lista del oraculo de vistas, por su titulo: sus filas en
//     orden, sus cabeceras de grupo y cada celda (el valor de un control, o
//     el texto), escrita con la regla de presentacion del evaluador, mas la
//     columna de estado;
//   - cada rejilla del oraculo de cruces, por su titulo: cada casilla;
//   - el indice de navegacion: un enlace por vista, a una seccion que existe.
//
// Uso:
//   node verificar-dom.js <puerto> <pagina.html> <esperado.json> <vistas.json> <cruces.json>

const fs = require('fs');
const path = require('path');
const {abrir} = require('./cdp.js');

// VALOR escrito como lo escribe la pagina (funcion T): hasta 10 cifras
// significativas, sin espacios a los lados.
// Un numero con exactamente N decimales, con el empate alejandose de cero
// sobre su escritura decimal: la misma regla que NUCLEO:TEXTO-CON-DECIMALES
// y que la funcion NUMDEC de la pagina, escrita aparte para no fiarse de
// ella (fase 2, hueco C6).
function conDecimales(v, n) {
  if (typeof v !== 'number' || !isFinite(v)) return texto(v);
  const s = Math.sign(v);
  const [m, e] = Math.abs(Number(v.toPrecision(15))).toExponential().split('e');
  const r = s * Number(Math.floor(Number(m + 'e' + (Number(e) + n)) + 0.5) + 'e' + (-n));
  return (r === 0 ? 0 : r).toFixed(n);
}

// Lo que tiene que verse en una celda: con los decimales del campo, salvo en
// un control de entrada, que ensena lo que hay escrito.
function textoDeCelda(v, decimales, esControl) {
  return (decimales === undefined || esControl) ? texto(v) : conDecimales(v, decimales);
}

function texto(v) {
  if (v === null || v === undefined || v === false) return '';
  if (v === true) return 'si';
  if (typeof v === 'number') {
    if (Number.isInteger(v)) return String(v);
    return String(Number(v.toPrecision(10)));
  }
  return String(v).trim();
}

// Lo que se ve en la pagina: por cada seccion, su titulo y sus tablas, con
// cada fila como lista de celdas (el valor de un control o el texto).
const LEER = `(() => {
  const celda = td => {
    const c = td.querySelector('input,select');
    return (c ? c.value : td.textContent.replace(/no está en la lista$/, '')).trim();
  };
  const tabla = t => Array.from(t.querySelectorAll('tbody tr')).map(tr => ({
    grupo: !!tr.querySelector('td.grupo'),
    celdas: Array.from(tr.children).map(celda),
    clases: Array.from(tr.children).map(td =>
      ['problema', 'advertencia', 'informativa'].find(c => td.classList.contains(c)) || ''),
    controles: Array.from(tr.children).map(td => !!td.querySelector('input,select'))
  }));
  const titulos = {};
  for (const h of document.querySelectorAll('h2, h3')) {
    let t = null, n = h.nextElementSibling;
    while (n && !t) {
      if (n.matches('h2, h3')) break;
      t = n.matches('table') ? n : n.querySelector('table');
      n = n.nextElementSibling;
    }
    if (t && !(h.textContent in titulos)) {
      titulos[h.textContent] = {nivel: h.tagName, cabecera: Array.from(t.querySelectorAll('thead th')).map(x => x.textContent.trim()), filas: tabla(t)};
    }
  }
  const enlaces = Array.from(document.querySelectorAll('nav#indice a')).map(a => ({texto: a.textContent, destino: a.getAttribute('href'), existe: !!document.getElementById(a.getAttribute('href').slice(1))}));
  return {titulos, enlaces};
})()`;

function compararTabla(vista, esperado, tabla, fallos) {
  let comprobadas = 0;
  const filas = esperado[tabla.coleccion] || [];
  const cabeceras = new Map((tabla.cabeceras || []).map(([p, v]) => [p, v]));
  const campos = tabla.campos || [];
  const vistas = vista.filas.slice();
  (tabla.filas || []).forEach((indice, posicion) => {
    if (cabeceras.has(posicion)) {
      const g = vistas.shift();
      if (!g || !g.grupo || g.celdas[0] !== texto(cabeceras.get(posicion))) {
        fallos.push(`${tabla.titulo}: falta la cabecera de grupo ${JSON.stringify(cabeceras.get(posicion))}`);
      }
    }
    const fila = vistas.shift();
    if (!fila) { fallos.push(`${tabla.titulo}: faltan filas`); return; }
    const [valores, , estado, marcados] = filas[indice];
    campos.forEach((campo, k) => {
      // El color de la celda: el de la primera marca, en el orden en que se
      // declararon, que pinta este campo; ninguno si no lo pinta ninguna
      // (fase 2, hueco C7: antes no se comprobaba en ningun sitio).
      comprobadas++;
      const pintada = Object.entries(marcados || {})
        .find(([, [, suyos]]) => suyos.includes(campo.campo));
      const claseEsperada = pintada ? pintada[1][0] : '';
      if ((fila.clases[k] || '') !== claseEsperada) {
        fallos.push(`${tabla.titulo} fila ${posicion + 1}: ${campo.campo} tiene que estar ${claseEsperada ? 'pintado de ' + claseEsperada : 'sin pintar'} y esta ${fila.clases[k] ? 'pintado de ' + fila.clases[k] : 'sin pintar'}`);
      }
      comprobadas++;
      const real = fila.celdas[k] ?? '';
      const esp = valores[campo.campo];
      if (campo.relacion) {
        const cuantas = real === '' ? 0 : real.split(', ').length;
        if (cuantas !== Number(esp || 0)) {
          fallos.push(`${tabla.titulo} fila ${posicion + 1}: ${campo.campo} trae ${cuantas} relacionadas y el oraculo ${esp}`);
        }
      } else if (real !== textoDeCelda(esp, campo.decimales, fila.controles[k])) {
        fallos.push(`${tabla.titulo} fila ${posicion + 1}: ${campo.campo} esperado ${JSON.stringify(textoDeCelda(esp, campo.decimales, fila.controles[k]))} obtenido ${JSON.stringify(real)}`);
      }
    });
    comprobadas++;
    const realEstado = fila.celdas[campos.length] ?? '';
    if (realEstado !== texto(estado)) {
      fallos.push(`${tabla.titulo} fila ${posicion + 1}: estado esperado ${JSON.stringify(texto(estado))} obtenido ${JSON.stringify(realEstado)}`);
    }
  });
  if (vistas.length) fallos.push(`${tabla.titulo}: la pagina tiene ${vistas.length} filas de mas`);
  return comprobadas;
}

function compararRejilla(vista, cuadrante, fallos, decimales) {
  let comprobadas = 0;
  const casillas = new Map();
  for (const c of cuadrante.casillas || []) {
    casillas.set(texto(c.fila) + '\u0001' + texto(c.columna),
                 c.valores.map(v => textoDeCelda(v, decimales, false)).join(' / '));
  }
  const columnas = vista.cabecera.slice(1);
  const vistas = new Set();
  for (const fila of vista.filas) {
    columnas.forEach((col, k) => {
      const clave = fila.celdas[0] + '\u0001' + col;
      vistas.add(clave);
      comprobadas++;
      const real = fila.celdas[k + 1] ?? '';
      const esp = casillas.get(clave) || '';
      if (real !== esp) {
        fallos.push(`${cuadrante.titulo} (${fila.celdas[0]}, ${col}): esperado ${JSON.stringify(esp)} obtenido ${JSON.stringify(real)}`);
      }
    });
  }
  for (const clave of casillas.keys()) {
    if (!vistas.has(clave)) fallos.push(`${cuadrante.titulo}: la casilla ${clave.replace('\u0001', ', ')} no esta en la rejilla`);
  }
  // Los ejes, en su orden: con un dominio declarado hay filas y columnas sin
  // ninguna casilla ocupada, y solo asi se comprueba que estan.
  if (cuadrante.filas) {
    const filasLeidas = JSON.stringify(vista.filas.map(f => f.celdas[0]));
    const filasEsperadas = JSON.stringify(cuadrante.filas.map(texto));
    comprobadas++;
    if (filasLeidas !== filasEsperadas) {
      fallos.push(`${cuadrante.titulo}: las filas son ${filasLeidas} y el oraculo dice ${filasEsperadas}`);
    }
    const columnasEsperadas = JSON.stringify((cuadrante.columnas || []).map(texto));
    comprobadas++;
    if (JSON.stringify(columnas) !== columnasEsperadas) {
      fallos.push(`${cuadrante.titulo}: las columnas son ${JSON.stringify(columnas)} y el oraculo dice ${columnasEsperadas}`);
    }
  }
  return comprobadas;
}

async function main(argv) {
  if (argv.length !== 7) {
    console.log('Uso: node verificar-dom.js <puerto> <pagina.html> <esperado.json> <vistas.json> <cruces.json>');
    return 2;
  }
  const [, , puerto, archivo, fEsperado, fVistas, fCruces] = argv;
  const esperado = JSON.parse(fs.readFileSync(fEsperado, 'utf8'));
  const tablas = JSON.parse(fs.readFileSync(fVistas, 'utf8'));
  const cruces = JSON.parse(fs.readFileSync(fCruces, 'utf8'));
  const p = await abrir(puerto, archivo);
  let pagina;
  try { pagina = await p.evaluar(LEER); } finally { await p.cerrar(); }

  const fallos = [];
  let comprobadas = 0;
  for (const tabla of tablas) {
    const vista = pagina.titulos[tabla.titulo];
    if (!vista) { fallos.push(`la pagina no dibuja la tabla ${JSON.stringify(tabla.titulo)}`); continue; }
    comprobadas += compararTabla(vista, esperado, tabla, fallos);
  }
  for (const v of cruces) {
    for (const cuadrante of v.cuadrantes) {
      const vista = pagina.titulos[cuadrante.titulo];
      if (!vista) { fallos.push(`la pagina no dibuja la rejilla ${JSON.stringify(cuadrante.titulo)}`); continue; }
      comprobadas += compararRejilla(vista, cuadrante, fallos, v.decimales);
    }
  }
  // La navegacion: un enlace por tabla de lista y por vista cruzada, a una
  // seccion que existe.
  for (const e of pagina.enlaces) {
    comprobadas++;
    if (!e.existe) fallos.push(`el enlace ${JSON.stringify(e.texto)} del indice no lleva a ninguna seccion`);
  }
  if (pagina.enlaces.length < tablas.length + cruces.length) {
    fallos.push(`el indice tiene ${pagina.enlaces.length} enlaces y hay ${tablas.length + cruces.length} vistas y tablas`);
  }
  for (const e of p.excepciones) fallos.push('excepcion de JavaScript: ' + e);
  if (comprobadas === 0 && tablas.length) fallos.push('no se comparo ninguna celda');

  const nombre = path.basename(archivo);
  if (fallos.length) {
    console.log(`FALLA  ${nombre}: ${comprobadas} celdas dibujadas comprobadas, ${fallos.length} discrepancias`);
    fallos.slice(0, 25).forEach(f => console.log('   ' + f));
    return 1;
  }
  console.log(`  ok   ${nombre}: ${comprobadas} celdas dibujadas coinciden con el evaluador de referencia`);
  return 0;
}

main(process.argv).then(c => process.exit(c), e => { console.error(e); process.exit(1); });
