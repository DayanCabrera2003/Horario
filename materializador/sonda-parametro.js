// Comprueba en un navegador de verdad que un parametro de entrada se edita.
//
// EL PROBLEMA QUE RESUELVE
//
// Hasta el 2026-10-21 la pagina copiaba el valor de todo parametro en el
// codigo, y el tope diario del Saul no se podia cambiar en ella aunque la
// descripcion lo declarara de entrada. Ahora la pagina tiene una seccion de
// parametros. Esta sonda escribe un valor en el control de un parametro, con
// eventos de teclado reales, y comprueba que lo que depende de el cambia en
// la pagina y que no salta ninguna excepcion de JavaScript.
//
// Uso:
//   node sonda-parametro.js <puerto> <pagina.html> <parametro> <valor> <texto-que-debe-aparecer>
//
// <parametro> es el nombre del parametro en la descripcion (tope-diario).
// Chromium tiene que estar ya escuchando en ese puerto, como para
// sonda-foco.js.

const path = require('path');
const {abrir} = require('./cdp.js');

async function main(argv) {
  if (argv.length < 7) {
    console.log('Uso: node sonda-parametro.js <puerto> <pagina.html> <parametro> <valor> <texto>');
    return 2;
  }
  const [, , puerto, archivo, parametro, valor, debeAparecer] = argv;
  const nombre = path.basename(archivo);
  const p = await abrir(puerto, archivo);
  const fallos = [];
  try {
    const hay = await p.evaluar(`(() => {
      const c = Array.from(document.querySelectorAll('input'))
                     .find(x => x.dataset.ref === ${JSON.stringify('parametro.' + parametro)});
      if (!c) return false;
      c.focus(); c.value = '';
      return true;
    })()`);
    if (!hay) {
      fallos.push(`no hay control para el parametro ${parametro}`);
    } else {
      for (const ch of valor) {
        await p.enviar('Input.insertText', {text: ch});
        await new Promise(r => setTimeout(r, 60));
      }
      await new Promise(r => setTimeout(r, 200));
      const cuerpo = await p.evaluar('document.body.innerText');
      if (!cuerpo.includes(debeAparecer)) {
        fallos.push(`con ${parametro} = ${valor} la pagina no dice ${JSON.stringify(debeAparecer)}`);
      }
    }
    for (const e of p.excepciones) fallos.push('excepcion de JavaScript: ' + e);
  } finally {
    await p.cerrar();
  }
  if (fallos.length) {
    console.log(`FALLA  ${nombre}: ${fallos.join('; ')}`);
    return 1;
  }
  console.log(`  ok   ${nombre}: con ${parametro} = ${valor} la pagina dice ${JSON.stringify(debeAparecer)}`);
  return 0;
}

main(process.argv).then(c => process.exit(c), e => { console.error(e); process.exit(1); });
