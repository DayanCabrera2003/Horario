;;;; El dibujo de la pagina: tablas, rejillas y controles.
;;;;
;;;; Es JavaScript fijo, igual para toda situacion; lo que varia (datos,
;;;; derivaciones, marcas, esquema) lo genera emision.lisp.
;;;;
;;;; DIBUJAR NO ES ACTUALIZAR
;;;;
;;;; Hasta el 2026-10-17 habia una sola funcion, render(), que vaciaba la
;;;; pagina y la volvia a crear entera, y la llamaba cada pulsacion de
;;;; tecla. El control donde se estaba escribiendo desaparecia con ella: no
;;;; se podia teclear mas de un caracter seguido.
;;;;
;;;; Ahora son dos:
;;;;
;;;;   construir()   crea las secciones, las tablas y los controles. Se llama
;;;;                 al abrir la pagina y cuando cambia la FORMA: se anade una
;;;;                 fila, aparece una seccion o un valor de eje nuevo, o una
;;;;                 fila cambia de grupo. Al terminar devuelve el foco al
;;;;                 control que lo tenia.
;;;;   actualizar()  recalcula y cambia EN SITIO lo que depende de los datos:
;;;;                 el texto de las celdas calculadas, las marcas, el estado y
;;;;                 las casillas de las rejillas. Es lo que hace cada tecla.
;;;;
;;;; Cada celda que depende de los datos se registra al construirla con la
;;;; funcion que la pone al dia; actualizar() las recorre.
;;;;
;;;; Nota para quien edite este archivo: el JavaScript va dentro de una
;;;; cadena de Lisp, asi que en el no puede haber comillas dobles ni barras
;;;; invertidas. Se usan comillas simples.

(in-package #:situacion.web)

(defparameter +render-js+ "
// === Dibujo de la pagina ===
// (materializador/verificar-web.js corta el programa aqui: lo de arriba es el
// calculo, que se compara con el evaluador; lo de abajo toca el DOM.)

// Las celdas que dependen de los datos, cada una con su funcion de puesta al
// dia. Se rellena en construir() y se recorre en actualizar().
let ACTUALIZADORES = [];
let FIRMA = null;

function registrar(f){ ACTUALIZADORES.push(f); f(); }

// Los valores distintos de un campo, en orden de primera aparicion.
function distintosDe(filas, campo){
  const vistos = [];
  for (const f of filas) {
    const v = f[campo];
    if (!VACIO(v) && !vistos.some(x => IG(x, v))) vistos.push(v);
  }
  return vistos;
}

// --- Controles de entrada ---
//
// Un control se crea una vez y escribe en la fila que le toca. Si el mismo
// dato se ve en otro sitio (una rejilla y su tabla), el otro control se pone
// al dia en actualizar(), salvo el que tiene el foco: a ese no se le toca.
let SECUENCIA = 0;
function controlDe(nombreColeccion, campo, fila, ref){
  const td = document.createElement('td');
  td.className = 'entrada';
  const clave = nombreColeccion + '.' + campo.n;
  const dominio = DOMINIOS[clave];
  let control;
  if (dominio && dominio.bloquea) {
    control = document.createElement('select');
    const vacia = document.createElement('option');
    vacia.value = ''; vacia.textContent = '';
    control.appendChild(vacia);
    for (const v of dominio.valores()) {
      const o = document.createElement('option');
      o.value = T(v); o.textContent = T(v);
      control.appendChild(o);
    }
  } else {
    control = document.createElement('input');
    if (campo.tipo === 'entero' || campo.tipo === 'numero') control.type = 'number';
    // Plan aprobado de tipos, seccion 4.1: un selector de verdad.
    if (campo.tipo === 'fecha') control.type = 'date';
    if (campo.tipo === 'hora') control.type = 'time';
    if (dominio) {
      const lista = document.createElement('datalist');
      lista.id = 'lista_' + (++SECUENCIA);
      for (const v of dominio.valores()) {
        const o = document.createElement('option');
        o.value = T(v);
        lista.appendChild(o);
      }
      control.setAttribute('list', lista.id);
      td.appendChild(lista);
    }
  }
  control.dataset.ref = ref;
  control.setAttribute('aria-label', campo.e);
  control.addEventListener('input', e => {
    const v = e.target.value;
    fila[campo.n] = (campo.tipo === 'entero' || campo.tipo === 'numero')
                    ? (v === '' ? '' : Number(v)) : v;
    actualizar();
  });
  // Un campo del orden se reordena al confirmarlo ('change': al salir del
  // control o pulsar Intro), no a cada tecla: reordenar vuelve a construir
  // la pagina, y hacerlo mientras se escribe se llevaria el foco.
  if ((ORDENES[nombreColeccion] || []).includes(campo.n)) {
    control.addEventListener('change', () => {
      if (reordenar(nombreColeccion)) actualizar();
    });
  }
  td.appendChild(control);
  const aviso = document.createElement('div');
  aviso.className = 'aviso';
  td.appendChild(aviso);
  registrar(() => {
    const actual = T(fila[campo.n]);
    const fuera = dominio && !VACIO(fila[campo.n]) &&
                  !dominio.valores().some(v => IG(v, fila[campo.n]));
    // Un desplegable que bloquea no puede ensenar un valor que no esta entre
    // sus opciones: el que ya venia en los datos se veria vacio. Se le anade
    // como opcion, para que se vea y se pueda corregir.
    if (control.tagName === 'SELECT' && fuera &&
        !Array.from(control.options).some(o => o.value === actual)) {
      const o = document.createElement('option');
      o.value = actual; o.textContent = actual;
      control.appendChild(o);
    }
    if (document.activeElement !== control) control.value = actual;
    aviso.textContent = fuera ? 'no está en la lista' : '';
  });
  return td;
}

// --- Tabla cruzada ---
//
// Los dos ejes y las secciones salen de los DATOS: si aparece un valor
// nuevo, cambia la forma y construir() lo dibuja. Todas las secciones de una
// vista comparten los mismos ejes, para que se lean igual.
//
// Si la vista declara el dominio de un eje (fase 2, hueco C1), sus valores
// son los del dominio, en su orden, haya datos o no; los de los datos que no
// esten en el van al final y se avisa debajo de la vista. Es la regla de
// NUCLEO/EJES.LISP, con el mismo texto de aviso.
function filasDelCruce(cruce){
  const todas = D[cruce.coleccion] || [];
  // El filtro esconde filas de la PRESENTACION y no toca D: los agregados y
  // las marcas siguen viendo la coleccion entera.
  return cruce.filtro ? todas.filter(f => VERDAD(cruce.filtro(f))) : todas;
}

function seccionesDe(cruce, filas){
  if (!cruce.secciones) return [null];
  return conDominio(seccionesSegunLosDatos(cruce, filas), cruce.dominioSecciones);
}

function seccionesSegunLosDatos(cruce, filas){
  return distintosDe(filas, cruce.secciones).sort(compararSecciones);
}

// Los valores de un dominio declarado, sin repetir y en su orden.
function valoresDelDominio(dominio){
  const unicos = [];
  for (const v of dominio()) {
    if (!VACIO(v) && !unicos.some(u => IG(u, v))) unicos.push(v);
  }
  return unicos;
}

// Los de VALORES que no estan en DECLARADOS, en su orden.
function ajenosAlDominio(valores, declarados){
  return valores.filter(v => !declarados.some(d => IG(d, v)));
}

// Sin dominio, los valores de los datos; con el, los del dominio y despues
// los de los datos que no esten en el.
function conDominio(valores, dominio){
  if (!dominio) return valores;
  const declarados = valoresDelDominio(dominio);
  return declarados.concat(ajenosAlDominio(valores, declarados));
}

// El aviso de los valores fuera del dominio, o '' si no hay ninguno. El
// mismo texto que NUCLEO:AVISO-FUERA-DE-DOMINIO.
function avisoFueraDeDominio(cruce, filas){
  const partes = [];
  const eje = (dominio, etiqueta, valores) => {
    if (!dominio) return;
    const fuera = ajenosAlDominio(valores, valoresDelDominio(dominio));
    if (fuera.length) partes.push(etiqueta + ': ' + fuera.map(T).join(', '));
  };
  eje(cruce.dominioFilas, cruce.etiquetaFilas, ejeSegunLosDatos(filas, cruce.ejeFilas, cruce));
  eje(cruce.dominioColumnas, cruce.etiquetaColumnas,
      ejeSegunLosDatos(filas, cruce.ejeColumnas, cruce));
  if (cruce.secciones)
    eje(cruce.dominioSecciones, cruce.etiquetaSecciones, seccionesSegunLosDatos(cruce, filas));
  return partes.length
    ? 'Valores fuera del dominio declarado en ' + cruce.titulo + ': ' + partes.join('; ') + '.'
    : '';
}

// La misma comparacion que NUCLEO::MENOR-P: numeros por su valor, fechas y
// horas por su valor, textos por sus caracteres.
function compararSecciones(a, b){
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  if (typeof a === 'string' && typeof b === 'string') {
    const fa = FECHANUM(a), fb = FECHANUM(b);
    if (fa !== null && fb !== null) return fa - fb;
    const ha = HORANUM(a), hb = HORANUM(b);
    if (ha !== null && hb !== null) return ha - hb;
    return a < b ? -1 : (a > b ? 1 : 0);
  }
  return 0;
}

function ejesDe(cruce, filas){
  return {filas: conDominio(ejeSegunLosDatos(filas, cruce.ejeFilas, cruce), cruce.dominioFilas),
          columnas: conDominio(ejeSegunLosDatos(filas, cruce.ejeColumnas, cruce),
                               cruce.dominioColumnas)};
}

function ejeSegunLosDatos(filas, campo, cruce){
  return ordenarEje(distintosDe(filas, campo), campo, cruce);
}

// Si el eje es uno de los campos por los que la coleccion declara orden,
// sus valores van ordenados; si no, en el de primera aparicion.
function ordenarEje(valores, campo, cruce){
  if (!(cruce.orden || []).includes(campo)) return valores;
  return valores.slice().sort(compararSecciones);
}

function dibujarCruce(cruce, indiceCruce, app){
  const filas = filasDelCruce(cruce);
  const ejes = ejesDe(cruce, filas);
  for (const s of seccionesDe(cruce, filas)) {
    const suyas = s === null ? filas : filas.filter(f => IG(f[cruce.secciones], s));
    dibujarUnaRejilla(cruce, indiceCruce, suyas, ejes, s, app);
  }
  const aviso = avisoFueraDeDominio(cruce, filas);
  if (aviso) {
    const p = document.createElement('p');
    p.className = 'aviso-de-dominio';
    p.textContent = 'Aviso: ' + aviso;
    app.appendChild(p);
  }
}

function dibujarUnaRejilla(cruce, indiceCruce, filas, ejes, valorDeSeccion, contenedor){
  const seccion = document.createElement('section');
  const titulo = document.createElement('h3');
  titulo.textContent = valorDeSeccion === null
    ? cruce.titulo
    : cruce.titulo + ' - ' + T(valorDeSeccion);
  seccion.appendChild(titulo);

  const envoltura = document.createElement('div');
  envoltura.className = 'envoltura';
  const t = document.createElement('table');
  const thead = document.createElement('thead');
  const trh = document.createElement('tr');
  const esquina = document.createElement('th');
  esquina.textContent = cruce.etiquetaFilas;
  trh.appendChild(esquina);
  for (const c of ejes.columnas) {
    const th = document.createElement('th');
    th.textContent = T(c);
    trh.appendChild(th);
  }
  thead.appendChild(trh);
  t.appendChild(thead);

  const campoCelda = cruce.campoCelda;
  const tbody = document.createElement('tbody');
  for (const vf of ejes.filas) {
    const tr = document.createElement('tr');
    const th = document.createElement('th');
    th.textContent = T(vf);
    tr.appendChild(th);
    for (const vc of ejes.columnas) {
      // TODAS las que caen ahi, no la primera. Son varias cuando la vista
      // declaro unica-salvo: entonces el choque existe y hay que ensenarlo.
      const enLaCasilla = filas.filter(f => IG(f[cruce.ejeFilas], vf) &&
                                            IG(f[cruce.ejeColumnas], vc));
      let td;
      if (cruce.entrada && campoCelda && campoCelda.rol === 'entrada' &&
          enLaCasilla.length === 1) {
        // Una vista de entrada deja escribir en la casilla, si la casilla
        // es de una sola fila.
        td = controlDe(cruce.coleccion, campoCelda, enLaCasilla[0],
                       'c|' + indiceCruce + '|' + T(valorDeSeccion) + '|' + T(vf) + '|' + T(vc));
      } else {
        td = document.createElement('td');
        const celda = td;
        registrar(() => {
          celda.textContent = enLaCasilla.map(f => TC(f[cruce.celda], cruce.campoCelda)).join(' / ');
        });
      }
      const marcada = td;
      registrar(() => {
        // Las marcas de las filas que caen en la casilla la tinen.
        marcada.classList.remove('problema', 'advertencia', 'informativa');
        for (const fila of enLaCasilla) {
          const suyas = marcasDe(cruce.coleccion, fila);
          if (suyas.length) { marcada.classList.add(suyas[0].clase); break; }
        }
      });
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  }
  t.appendChild(tbody);
  envoltura.appendChild(t);
  seccion.appendChild(envoltura);
  contenedor.appendChild(seccion);
}

// --- Tabla de una coleccion ---

// Las filas en el orden en que se van a MOSTRAR, cada una con el indice que
// ocupa en D y, si empieza un grupo, la cabecera que va encima. Agrupar es
// solo de presentacion: D no se toca, y la fila anterior sigue significando
// lo mismo. En una hoja de calculo no se puede separar las dos cosas.
function ordenarParaMostrar(filas, campo){
  const pares = filas.map((fila, indice) => ({fila, indice, cabecera: null}));
  if (!campo) return pares;
  const grupos = [];
  for (const par of pares) {
    let g = grupos.find(x => IG(x.valor, par.fila[campo]));
    if (!g) { g = {valor: par.fila[campo], pares: []}; grupos.push(g); }
    g.pares.push(par);
  }
  const salida = [];
  for (const g of grupos) {
    g.pares.forEach((par, i) => {
      salida.push({fila: par.fila, indice: par.indice,
                   cabecera: i === 0 ? g.valor : null});
    });
  }
  return salida;
}

function dibujarTabla(tabla, contenedor){
  const seccion = contenedor;

  const envoltura = document.createElement('div');
  envoltura.className = 'envoltura';
  const t = document.createElement('table');
  const thead = document.createElement('thead');
  const trh = document.createElement('tr');
  for (const c of tabla.campos) {
    const th = document.createElement('th');
    th.textContent = c.e;
    trh.appendChild(th);
  }
  const thEstado = document.createElement('th');
  thEstado.textContent = tabla.columnaEstado;
  trh.appendChild(thEstado);
  thead.appendChild(trh);
  t.appendChild(thead);

  const tbody = document.createElement('tbody');
  ordenarParaMostrar(D[tabla.coleccion], tabla.agrupa).forEach(par => {
    const fila = par.fila, indice = par.indice;
    if (par.cabecera !== null) {
      const trg = document.createElement('tr');
      const tdg = document.createElement('td');
      tdg.className = 'grupo';
      tdg.colSpan = tabla.campos.length + 1;
      tdg.textContent = T(par.cabecera);
      trg.appendChild(tdg);
      tbody.appendChild(trg);
    }
    const tr = document.createElement('tr');
    for (const c of tabla.campos) {
      // El rol decide que se dibuja: de entrada es un control; fijo, texto,
      // salvo en una fila que el usuario anadio, donde lo escribe el; y
      // derivado, texto que se pone al dia.
      const escribible = c.rol === 'entrada' || (c.rol === 'fijo' && fila.__nueva);
      let td;
      if (escribible) {
        td = controlDe(tabla.coleccion, c, fila,
                       't|' + tabla.vista + '|' + indice + '|' + c.n);
      } else {
        td = document.createElement('td');
        td.className = c.rol;
        const celda = td;
        registrar(() => {
          celda.textContent = c.clave
            // Relacion uno a muchos: cada fila relacionada por su clave.
            ? (fila[c.n] || []).map(r => c.clave.map(k => T(r[k])).join(' ')).join(', ')
            : TC(fila[c.n], c);
        });
      }
      const marcada = td;
      registrar(() => {
        // La marca senala los campos que declara su alcance.
        marcada.classList.remove('problema', 'advertencia', 'informativa');
        const suyas = marcasDe(tabla.coleccion, fila)
                        .filter(m => camposMarcados(m, fila).includes(c.n));
        if (suyas.length) marcada.classList.add(suyas[0].clase);
      });
      tr.appendChild(td);
    }
    const tdEstado = document.createElement('td');
    tdEstado.className = 'estado';
    registrar(() => { tdEstado.textContent = estadoDe(tabla.coleccion, fila); });
    tr.appendChild(tdEstado);
    tbody.appendChild(tr);
  });
  t.appendChild(tbody);
  envoltura.appendChild(t);
  seccion.appendChild(envoltura);

  // Crecer es nativo aqui: un boton. La fila nueva lleva controles para sus
  // campos fijos y de entrada: en una coleccion que crece, fijo quiere decir
  // que lo escribe quien crea la fila.
  if (tabla.crece) {
    const boton = document.createElement('button');
    boton.textContent = '+ Añadir fila';
    boton.addEventListener('click', () => {
      const nueva = {__nueva: true};
      for (const c of tabla.campos) if (c.rol !== 'derivado') nueva[c.n] = '';
      D[tabla.coleccion].push(nueva);
      reordenar(tabla.coleccion);
      const primero = tabla.campos.find(c => c.rol !== 'derivado');
      FOCO = primero ? 't|' + tabla.vista + '|' + (D[tabla.coleccion].length - 1) +
                       '|' + primero.n : null;
      construir();
    });
    seccion.appendChild(boton);
  }

  const leyenda = MARCAS.filter(m => m.coleccion === tabla.coleccion);
  if (leyenda.length) {
    const p = document.createElement('p');
    p.className = 'leyenda';
    for (const m of leyenda) {
      const s = document.createElement('span');
      s.className = m.clase;
      s.textContent = m.leyenda;
      p.appendChild(s);
    }
    seccion.appendChild(p);
  }
}

// --- El orden declarado de una coleccion ---
//
// El evaluador ve las filas en el orden que declara la coleccion, y VECINO
// toma la fila anterior del arreglo: si el usuario anade una fila o cambia
// un campo del orden, el arreglo se vuelve a ordenar con la misma
// comparacion que NUCLEO::ORDENAR-FILAS (por el primer campo y, a igualdad,
// por el siguiente; estable). Una fila con algun campo del orden vacio va al
// final: es una fila que se esta escribiendo. Devuelve si cambio el orden.
function reordenar(nombre){
  const campos = ORDENES[nombre];
  const filas = D[nombre];
  if (!campos || !filas) return false;
  const antes = filas.slice();
  const incompleta = f => campos.some(c => VACIO(f[c]));
  const ordenadas = filas.map((f, i) => ({f, i})).sort((a, b) => {
    const ia = incompleta(a.f), ib = incompleta(b.f);
    if (ia !== ib) return ia ? 1 : -1;
    if (!ia) {
      for (const c of campos) {
        const r = compararSecciones(a.f[c], b.f[c]);
        if (r !== 0) return r;
      }
    }
    return a.i - b.i;
  }).map(p => p.f);
  filas.splice(0, filas.length, ...ordenadas);
  return filas.some((f, i) => f !== antes[i]);
}

// --- La forma de la pagina ---
//
// Todo lo que, si cambia, obliga a construir de nuevo: las secciones y los
// ejes de cada rejilla, cuantas filas hay y en que orden se muestran.
function firma(){
  const partes = [];
  for (const c of CRUCES) {
    const filas = filasDelCruce(c);
    const ejes = ejesDe(c, filas);
    partes.push(JSON.stringify([seccionesDe(c, filas), ejes.filas, ejes.columnas,
                                filas.length]));
  }
  for (const t of TABLAS) {
    partes.push(JSON.stringify(ordenarParaMostrar(D[t.coleccion], t.agrupa)
                               .map(p => [p.indice, p.cabecera])));
  }
  return partes.join('|');
}

let FOCO = null;

function construir(){
  recalcularTodo();
  const activo = document.activeElement;
  const ref = FOCO || (activo && activo.dataset ? activo.dataset.ref : null);
  const seleccion = (activo && typeof activo.selectionStart === 'number')
    ? [activo.selectionStart, activo.selectionEnd] : null;
  FOCO = null;
  ACTUALIZADORES = [];
  const app = document.getElementById('app');
  app.textContent = '';
  dibujarVistas(app);
  if (RECALCULO_INCOMPLETO) avisarRecalculoIncompleto(app);
  FIRMA = firma();
  if (ref) {
    const vuelta = Array.from(app.querySelectorAll('[data-ref]'))
                        .find(x => x.dataset.ref === ref);
    if (vuelta) {
      vuelta.focus();
      if (seleccion && typeof vuelta.setSelectionRange === 'function') {
        try { vuelta.setSelectionRange(seleccion[0], seleccion[1]); } catch(e) {}
      }
    }
  }
}

function avisarRecalculoIncompleto(app){
  const aviso = document.createElement('p');
  aviso.className = 'aviso';
  aviso.textContent = 'Los valores calculados no acabaron de estabilizarse. ' +
    'Puede haber una dependencia circular entre filas.';
  app.insertBefore(aviso, app.firstChild);
}

function actualizar(){
  recalcularTodo();
  if (firma() !== FIRMA) { construir(); return; }
  for (const f of ACTUALIZADORES) f();
}

// Cada vista es una seccion con su titulo, un ancla para el indice y un
// enlace para volver arriba. El indice de la pagina es la navegacion: un
// enlace por vista, en el orden en que se declararon.
function dibujarVistas(app){
  const indice = document.getElementById('indice');
  if (indice) {
    indice.textContent = '';
    for (const o of ORDEN) {
      const v = o.tipo === 'cruce' ? CRUCES[o.indice] : TABLAS[o.indice];
      const a = document.createElement('a');
      a.href = '#' + v.id;
      a.textContent = v.titulo;
      indice.appendChild(a);
    }
  }
  for (const o of ORDEN) {
    const v = o.tipo === 'cruce' ? CRUCES[o.indice] : TABLAS[o.indice];
    const seccion = document.createElement('section');
    seccion.id = v.id;
    const titulo = document.createElement('h2');
    titulo.textContent = v.titulo;
    seccion.appendChild(titulo);
    if (o.tipo === 'cruce') dibujarCruce(v, o.indice, seccion);
    else dibujarTabla(v, seccion);
    const arriba = document.createElement('a');
    arriba.href = '#arriba';
    arriba.className = 'arriba';
    arriba.textContent = 'volver arriba';
    seccion.appendChild(arriba);
    app.appendChild(seccion);
  }
}
"
  "El dibujo de la pagina: construir y actualizar.")
