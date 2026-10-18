// Comprueba en un navegador de verdad que la pagina reordena una coleccion
// cuando el usuario le anade una fila.
//
// EL PROBLEMA QUE RESUELVE
//
// El evaluador ve las filas en el orden que declara la coleccion, y la fila
// anterior de (anterior fila ...) es la anterior en ese orden. Hasta la fase
// 2 (hueco C3) la pagina dejaba la fila anadida al final del arreglo, asi
// que su "anterior" era otra y el acumulado salia distinto del evaluador.
//
// Esta sonda abre la pagina en Chromium, pulsa "+ Anadir fila" en la tabla
// de la coleccion, escribe la fila nueva como lo haria el usuario (cada
// campo con sus eventos 'input' y 'change'; los del orden al final) y
// compara la coleccion entera, fila por fila y en orden, con lo que dice el
// evaluador de referencia para los mismos datos mas esa fila.
//
// Uso:
//   node sonda-orden.js <puerto> <pagina.html> <fila-nueva.json>
//
// El JSON lo escribe la demostracion (ESCRIBIR-FILA-NUEVA): la coleccion,
// los valores de la fila, los campos del orden y las filas esperadas.

const fs = require('fs');
const path = require('path');
const {abrir} = require('./cdp.js');

async function main(argv) {
  if (argv.length !== 5) {
    console.log('Uso: node sonda-orden.js <puerto> <pagina.html> <fila-nueva.json>');
    return 2;
  }
  const [, , puerto, archivo, fOraculo] = argv;
  const nombre = path.basename(archivo);
  const oraculo = JSON.parse(fs.readFileSync(fOraculo, 'utf8'));
  const p = await abrir(puerto, archivo);
  let resultado;
  try {
    // Todo ocurre dentro de la pagina: el script recibe el oraculo como
    // literal y devuelve lo que encontro.
    resultado = await p.evaluar(`(() => {
      const o = ${JSON.stringify(oraculo)};
      const tabla = TABLAS.find(t => t.coleccion === o.coleccion);
      if (!tabla) return {error: 'la pagina no tiene tabla de ' + o.coleccion};
      const seccion = document.getElementById(tabla.id);
      const boton = seccion && Array.from(seccion.querySelectorAll('button'))
                                    .find(b => b.textContent.includes('Añadir fila'));
      if (!boton) return {error: 'la tabla de ' + o.coleccion + ' no tiene boton de anadir'};
      boton.click();
      const nueva = D[o.coleccion].find(f => f.__nueva);
      // Primero los campos que no son del orden y despues los del orden: la
      // fila solo se reordena cuando el ultimo de ellos se confirma.
      const campos = Object.keys(o.valores);
      campos.sort((a, b) => o.orden.includes(a) - o.orden.includes(b));
      for (const campo of campos) {
        const indice = D[o.coleccion].indexOf(nueva);
        const ref = 't|' + tabla.vista + '|' + indice + '|' + campo;
        const control = Array.from(document.querySelectorAll('[data-ref]'))
                             .find(x => x.dataset.ref === ref);
        if (!control) return {error: 'no hay control para ' + campo + ' en la fila nueva'};
        control.value = String(o.valores[campo]);
        control.dispatchEvent(new Event('input', {bubbles: true}));
        control.dispatchEvent(new Event('change', {bubbles: true}));
      }
      return {filas: D[o.coleccion].map(f => {
        const copia = {};
        for (const k in f) if (k !== '__nueva') copia[k] = f[k];
        return copia;
      })};
    })()`);
  } finally {
    await p.cerrar();
  }
  const fallos = [];
  if (p.excepciones.length) fallos.push(...p.excepciones.map(e => 'excepcion: ' + e));
  if (!resultado || resultado.error) {
    fallos.push(resultado ? resultado.error : 'la sonda no devolvio nada');
  } else {
    const esperado = oraculo.esperado;
    if (resultado.filas.length !== esperado.length) {
      fallos.push(`la pagina tiene ${resultado.filas.length} filas y el evaluador ${esperado.length}`);
    }
    let comprobadas = 0;
    esperado.forEach((fila, i) => {
      for (const [campo, valor] of Object.entries(fila)) {
        comprobadas++;
        const real = resultado.filas[i] ? resultado.filas[i][campo] : undefined;
        const igual = (real === '' || real === null || real === undefined)
          ? (valor === '' || valor === null)
          : String(real) === String(valor);
        if (!igual) fallos.push(`fila ${i + 1}, ${campo}: esperado ${JSON.stringify(valor)} obtenido ${JSON.stringify(real)}`);
      }
    });
    if (!fallos.length) {
      console.log(`  ok   ${nombre}: la fila anadida se reordena y ${comprobadas} valores coinciden con el evaluador`);
      return 0;
    }
  }
  console.log(`FALLA  ${nombre}: la fila anadida no deja la coleccion como el evaluador`);
  fallos.slice(0, 20).forEach(f => console.log('   ' + f));
  return 1;
}

main(process.argv).then(c => process.exit(c), e => { console.log('FALLA  ' + e); process.exit(1); });
