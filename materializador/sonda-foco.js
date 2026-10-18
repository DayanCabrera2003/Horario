// Comprueba en un navegador de verdad que la pagina deja escribir.
//
// EL PROBLEMA QUE RESUELVE
//
// Hasta el 2026-10-17 cada pulsacion de tecla volvia a dibujar la pagina
// entera, y el control donde se escribia desaparecia con ella: solo se podia
// teclear un caracter seguido. verificar-web.js no lo podia ver, porque
// ejecuta el calculo sin dibujar nada.
//
// Esta sonda abre la pagina en Chromium (por el protocolo de depuracion, en
// el puerto que se le diga), teclea un texto con eventos de teclado reales en
// el primer control de texto de la pagina y comprueba tres cosas: que el
// control tiene todo el texto, que el foco sigue en el mismo control y que no
// salto ninguna excepcion de JavaScript. Si no hay ningun control de texto,
// se usa el primero numerico. Opcionalmente, que tras escribir una
// celda concreta aparece un texto en la pagina.
//
// Uso:
//   node sonda-foco.js <puerto> <pagina.html> [<texto-que-debe-aparecer>]
//
// Chromium tiene que estar ya escuchando en ese puerto (lo arrancan
// demostrar.sh y demostrar-robustez.sh, una sola instancia, y la cierran al
// terminar).

const path = require('path');

async function abrir(puerto, archivo) {
  const t = await (await fetch(`http://127.0.0.1:${puerto}/json/new?about:blank`,
                               {method: 'PUT'})).json();
  const ws = new WebSocket(t.webSocketDebuggerUrl);
  let id = 0;
  const pendientes = {};
  const excepciones = [];
  ws.onmessage = e => {
    const m = JSON.parse(e.data);
    if (m.id && pendientes[m.id]) { pendientes[m.id](m); delete pendientes[m.id]; }
    if (m.method === 'Runtime.exceptionThrown') {
      const d = m.params.exceptionDetails;
      excepciones.push((d.exception && d.exception.description) || d.text);
    }
  };
  await new Promise(r => { ws.onopen = r; });
  const enviar = (method, params = {}) => new Promise(r => {
    const i = ++id; pendientes[i] = r; ws.send(JSON.stringify({id: i, method, params}));
  });
  const evaluar = async expr => {
    const r = await enviar('Runtime.evaluate', {expression: expr, returnByValue: true,
                                                awaitPromise: true});
    return r.result.result.value;
  };
  await enviar('Runtime.enable');
  await enviar('Page.enable');
  await enviar('Page.navigate', {url: 'file://' + path.resolve(archivo)});
  await new Promise(r => setTimeout(r, 1500));
  const cerrar = async () => {
    await fetch(`http://127.0.0.1:${puerto}/json/close/${t.id}`);
    ws.close();
  };
  return {enviar, evaluar, excepciones, cerrar};
}

async function main(argv) {
  if (argv.length < 4) {
    console.log('Uso: node sonda-foco.js <puerto> <pagina.html> [<texto-que-debe-aparecer>]');
    return 2;
  }
  const [, , puerto, archivo, debeAparecer] = argv;
  const nombre = path.basename(archivo);
  const p = await abrir(puerto, archivo);
  const fallos = [];
  let hay = null;
  try {
    hay = await p.evaluar(`(() => {
      const todos = Array.from(document.querySelectorAll('input'))
                         .filter(x => x.dataset.ref);
      const c = todos.find(x => x.type === 'text' || x.type === '') ||
                todos.find(x => x.type === 'number');
      if (!c) return null;
      c.focus(); if (c.type !== 'number') c.select(); else c.value = '';
      return c.dataset.ref + '|' + c.type;
    })()`);
    if (hay === null) {
      console.log(`  --   ${nombre}: la pagina no tiene ningun control donde escribir`);
    } else {
      const numerico = hay.endsWith('|number');
      hay = hay.replace(/[|][a-z]*$/, '');
      const texto = numerico ? '125' : 'Abc-1';
      for (const ch of texto) {
        await p.enviar('Input.insertText', {text: ch});
        await new Promise(r => setTimeout(r, 60));
      }
      await new Promise(r => setTimeout(r, 200));
      const estado = await p.evaluar(`(() => {
        const a = document.activeElement;
        return {ref: a && a.dataset ? a.dataset.ref : null, valor: a ? a.value : null,
                cuerpo: document.body.innerText};
      })()`);
      if (estado.ref !== hay) fallos.push(`el foco paso de ${hay} a ${estado.ref}`);
      if (estado.valor !== texto) fallos.push(`el control tiene ${JSON.stringify(estado.valor)} y no ${JSON.stringify(texto)}`);
      if (debeAparecer && !estado.cuerpo.includes(debeAparecer)) {
        fallos.push(`la pagina no dice ${JSON.stringify(debeAparecer)} despues de escribir`);
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
  if (hay !== null) {
    console.log(`  ok   ${nombre}: se escribe un texto entero sin perder el foco`);
  }
  return 0;
}

main(process.argv).then(c => process.exit(c), e => { console.error(e); process.exit(1); });
