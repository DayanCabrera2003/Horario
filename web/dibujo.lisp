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
  td.appendChild(control);
  const aviso = document.createElement('div');
  aviso.className = 'aviso';
  td.appendChild(aviso);
  registrar(() => {
    if (document.activeElement !== control) control.value = T(fila[campo.n]);
    // Avisa sin bloquear, como los desplegables del corpus.
    const fuera = dominio && !dominio.bloquea && !VACIO(fila[campo.n]) &&
                  !dominio.valores().some(v => IG(v, fila[campo.n]));
    aviso.textContent = fuera ? 'no está en la lista' : '';
  });
  return td;
}

// --- Tabla cruzada ---
//
// Los dos ejes y las secciones salen de los DATOS: si aparece un valor
// nuevo, cambia la forma y construir() lo dibuja. Todas las secciones de una
// vista comparten los mismos ejes, para que se lean igual.
function filasDelCruce(cruce){
  const todas = D[cruce.coleccion] || [];
  // El filtro esconde filas de la PRESENTACION y no toca D: los agregados y
  // las marcas siguen viendo la coleccion entera.
  return cruce.filtro ? todas.filter(f => VERDAD(cruce.filtro(f))) : todas;
}

function seccionesDe(cruce, filas){
  if (!cruce.secciones) return [null];
  return distintosDe(filas, cruce.secciones).sort(compararSecciones);
}

function compararSecciones(a, b){
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  return T(a).localeCompare(T(b), 'es');
}

function ejesDe(cruce, filas){
  return {filas: ordenarEje(distintosDe(filas, cruce.ejeFilas), cruce.ejeFilas, cruce),
          columnas: ordenarEje(distintosDe(filas, cruce.ejeColumnas), cruce.ejeColumnas, cruce)};
}

// Si el eje es el campo por el que la coleccion declara orden, sus valores
// van en ese orden; si no, en el de primera aparicion.
function ordenarEje(valores, campo, cruce){
  if (cruce.orden !== campo) return valores;
  return valores.slice().sort((a, b) => N(a) - N(b) || T(a).localeCompare(T(b)));
}

function dibujarCruce(cruce, indiceCruce, app){
  const filas = filasDelCruce(cruce);
  const ejes = ejesDe(cruce, filas);
  for (const s of seccionesDe(cruce, filas)) {
    const suyas = s === null ? filas : filas.filter(f => IG(f[cruce.secciones], s));
    dibujarUnaRejilla(cruce, indiceCruce, suyas, ejes, s, app);
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
          celda.textContent = enLaCasilla.map(f => T(f[cruce.celda])).join(' / ');
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
  const seccion = document.createElement('section');
  const titulo = document.createElement('h3');
  titulo.textContent = tabla.titulo;
  seccion.appendChild(titulo);

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
            : T(fila[c.n]);
        });
      }
      const marcada = td;
      registrar(() => {
        // La marca senala los campos que declara su alcance.
        marcada.classList.remove('problema', 'advertencia', 'informativa');
        const suyas = marcasDe(tabla.coleccion, fila).filter(m => m.campos.includes(c.n));
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
  contenedor.appendChild(seccion);
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

function dibujarVistas(app){
  CRUCES.forEach((c, i) => dibujarCruce(c, i, app));
  for (const t of TABLAS) dibujarTabla(t, app);
}
"
  "El dibujo de la pagina: construir y actualizar.")
