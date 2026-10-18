// Cliente minimo del protocolo de depuracion de Chromium.
//
// Lo usan las comprobaciones que necesitan ver la pagina dibujada de verdad
// (sonda-foco.js, verificar-dom.js). Abre una pestana en un Chromium que ya
// escucha en PUERTO, carga el archivo y devuelve con que hablarle. Recoge
// las excepciones de JavaScript que salten.

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


module.exports = {abrir};
