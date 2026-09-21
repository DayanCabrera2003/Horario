;;;; Recursos fijos de la pagina: estilos y biblioteca de apoyo.
;;;;
;;;; Se separan en su propio archivo porque no dependen de la descripcion:
;;;; son iguales para toda situacion. Lo que varia -los datos, las
;;;; derivaciones, las marcas- se genera en emision.lisp.
;;;;
;;;; Las funciones de apoyo de JavaScript son la contraparte exacta de las
;;;; coerciones del evaluador de referencia: un campo sin rellenar vale cero
;;;; en aritmetica, dos vacios son iguales entre si, y comparar numeros
;;;; escritos como texto no puede dar que "10" sea menor que "9". Que las dos
;;;; implementaciones coincidan es lo que comprueba la suite de conformidad.

(in-package #:situacion.web)

(defparameter +estilos+ "
:root { --tinta:#1a1a1a; --suave:#666; --borde:#d8d8d8; --fondo:#fbfbfa; }
* { box-sizing: border-box; }
body { margin:0; padding:24px 16px 64px; background:var(--fondo); color:var(--tinta);
       font:15px/1.5 system-ui, -apple-system, 'Segoe UI', sans-serif; }
h1 { font-size:22px; margin:0 0 4px; }
h2 { font-size:17px; margin:28px 0 8px; font-weight:600; }
.nota { color:var(--suave); margin:0 0 16px; font-size:13px; }
.envoltura { overflow-x:auto; }
table { border-collapse:collapse; background:#fff; font-size:14px; min-width:100%; }
th, td { border:1px solid var(--borde); padding:6px 10px; text-align:left;
         white-space:nowrap; }
th { background:#f0f0ee; font-weight:600; }
td.derivado { background:#fafafa; color:#333; }
td.fijo { color:#333; }
input, select { font:inherit; border:1px solid #bbb; border-radius:3px;
                padding:3px 6px; width:100%; min-width:90px; background:#fff; }
input:focus, select:focus { outline:2px solid #4472c4; outline-offset:-1px; }
.problema { background:#ffc7ce !important; }
.advertencia { background:#ffeb9c !important; }
.informativa { background:#ddebf7 !important; }
.estado { color:var(--suave); font-size:13px; white-space:normal; }
.leyenda { margin:10px 0 0; font-size:13px; color:var(--suave); }
.leyenda span { display:inline-block; padding:2px 8px; border:1px solid var(--borde);
                margin-right:8px; border-radius:3px; }
button { font:inherit; padding:5px 12px; margin-top:8px; cursor:pointer;
         border:1px solid #bbb; border-radius:3px; background:#fff; }
button:hover { background:#f0f0ee; }
.aviso { color:#a5402a; font-size:12px; }
@media (max-width:520px) { th, td { padding:5px 7px; } }
"
  "Estilos de la pagina. El color de cada severidad sale de aqui, no del
   lenguaje.")

(defparameter +ayudas-js+ "
// --- Coercion, identica a la del evaluador de referencia del nucleo ---
function VACIO(x){ return x === null || x === undefined || x === ''; }
function N(x){ if (typeof x === 'number') return x;
               if (VACIO(x)) return 0;
               const n = parseFloat(x); return isNaN(n) ? 0 : n; }
function T(x){ if (x === null || x === undefined) return '';
               if (x === true) return 'si';
               return String(x); }
function IG(a,b){ if (VACIO(a) && VACIO(b)) return true;
                  if (VACIO(a) || VACIO(b)) return false;
                  if (typeof a === 'number' || typeof b === 'number') return N(a) === N(b);
                  return String(a) === String(b); }
function V(x){ return x === undefined ? '' : x; }

// --- Busqueda por clave con su valor por defecto ---
function PROY(fila, campo, pordefecto){
  if (!fila) return pordefecto;
  const v = fila[campo];
  return VACIO(v) ? pordefecto : v;
}

// --- Dos filas comparten algun valor en esos campos ---
function COMPARTEN(a, b, campos){
  const va = campos.map(c => a[c]).filter(x => !VACIO(x));
  const vb = campos.map(c => b[c]).filter(x => !VACIO(x));
  return va.some(x => vb.some(y => IG(x,y)));
}

// --- La fila contigua segun el orden declarado ---
function VECINO(coleccion, fila, paso){
  const i = coleccion.indexOf(fila);
  const j = i + paso;
  return (j >= 0 && j < coleccion.length) ? coleccion[j] : null;
}

// --- Calcula los derivados de una fila y los deja puestos ---
function calcular(nombre, fila){
  const d = DERIV[nombre];
  if (!d) return fila;
  for (const campo in d) {
    try { fila[campo] = d[campo](fila); }
    catch (e) { fila[campo] = ''; }
  }
  return fila;
}

// Recalcula hasta punto fijo, no una sola pasada.
//
// POR QUE. Un campo derivado puede depender de OTRA fila de su misma
// coleccion -el ganador de un partido pasa al siguiente, el saldo de un
// renglon se arrastra del anterior-. Con una sola pasada en el orden del
// arreglo, cada render hace converger exactamente un nivel de esa cadena, y
// la pagina ensena valores incompletos sin avisar de nada.
//
// Lo encontro un experimento de alcance con un cuadro de eliminatorias, y es
// la clase de fallo que este trabajo le reprocha a la tesis de 2026: la
// arquitectura declaraba cumplir la derivacion viva y no la cumplia.
//
// El tope existe para que una dependencia circular no cuelgue el navegador.
// Si se alcanza, RECALCULO_INCOMPLETO queda en true y la pagina lo dice, que
// es lo unico honesto que se puede hacer: callar seria volver al verde falso.
const TOPE_DE_PASADAS = 32;
let RECALCULO_INCOMPLETO = false;

function huellaDe(){
  const partes = [];
  for (const nombre in D) for (const f of D[nombre]) partes.push(JSON.stringify(f));
  return partes.join('|');
}

function recalcularTodo(){
  let antes = huellaDe();
  for (let pasada = 0; pasada < TOPE_DE_PASADAS; pasada++) {
    for (const nombre in D) D[nombre].forEach(f => calcular(nombre, f));
    const despues = huellaDe();
    if (despues === antes) { RECALCULO_INCOMPLETO = false; return pasada + 1; }
    antes = despues;
  }
  RECALCULO_INCOMPLETO = true;
  return TOPE_DE_PASADAS;
}
"
  "Biblioteca de apoyo. Es la contraparte de las coerciones del nucleo, y la
   suite de conformidad comprueba que las dos dan el mismo resultado.")

(defparameter +render-js+ "
function marcasDe(nombreColeccion, fila){
  return MARCAS.filter(m => m.coleccion === nombreColeccion)
               .filter(m => { try { return !!m.cond(fila); } catch(e){ return false; } });
}

// --- Tabla cruzada: los valores de un campo van en el eje de columnas ---
//
// El numero de columnas sale de los DATOS, no de la declaracion. En una
// pagina eso no cuesta nada: se recalcula al dibujar, y si aparece un valor
// nuevo aparece una columna nueva. En una hoja de calculo, lo mismo mueve el
// direccionamiento entero, y por eso alli es una emulacion con coste.
function distintosDe(filas, campo){
  const vistos = [];
  for (const f of filas) {
    const v = f[campo];
    if (!VACIO(v) && !vistos.some(x => IG(x, v))) vistos.push(v);
  }
  return vistos;
}

// Una vista partida es la misma tabla repetida, una vez por valor. Los
// valores salen de los DATOS al dibujar: si manana aparece un grupo nuevo,
// aparece una tabla nueva sin volver a generar nada. Es la misma propiedad
// que hace que aqui las columnas de un cruce sean gratis, y es justo lo que
// a una hoja de calculo le cuesta una emulacion.
function dibujarCruce(cruce, app){
  const todas = D[cruce.coleccion] || [];
  const secciones = cruce.secciones ? distintosDe(todas, cruce.secciones) : [null];
  for (const s of secciones) {
    const filas = s === null ? todas
                             : todas.filter(f => IG(f[cruce.secciones], s));
    dibujarUnaTabla(cruce, filas, s, app);
  }
}

function dibujarUnaTabla(cruce, filas, valorDeSeccion, app){
  const ejeF = distintosDe(filas, cruce.ejeFilas);
  const ejeC = distintosDe(filas, cruce.ejeColumnas);

  const seccion = document.createElement('section');
  const titulo = document.createElement('h2');
  titulo.textContent = valorDeSeccion === null
    ? cruce.titulo
    : cruce.titulo + ' - ' + T(valorDeSeccion);
  seccion.appendChild(titulo);

  const envoltura = document.createElement('div');
  envoltura.className = 'envoltura';
  const t = document.createElement('table');

  const trh = document.createElement('tr');
  const esquina = document.createElement('th');
  esquina.textContent = cruce.ejeFilas;
  trh.appendChild(esquina);
  for (const c of ejeC) {
    const th = document.createElement('th');
    th.textContent = T(c);
    trh.appendChild(th);
  }
  const thead = document.createElement('thead');
  thead.appendChild(trh);
  t.appendChild(thead);

  const tbody = document.createElement('tbody');
  for (const vf of ejeF) {
    const tr = document.createElement('tr');
    const th = document.createElement('th');
    th.textContent = T(vf);
    tr.appendChild(th);
    for (const vc of ejeC) {
      const fila = filas.find(f => IG(f[cruce.ejeFilas], vf) &&
                                   IG(f[cruce.ejeColumnas], vc));
      const td = document.createElement('td');
      td.textContent = fila ? T(fila[cruce.celda]) : '';
      // Las marcas de la fila que cae en el cruce tinen la celda.
      if (fila) {
        const suyas = marcasDe(cruce.coleccion, fila);
        if (suyas.length) td.classList.add(suyas[0].clase);
      }
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  }
  t.appendChild(tbody);
  envoltura.appendChild(t);
  seccion.appendChild(envoltura);
  app.appendChild(seccion);
}

function render(){
  recalcularTodo();
  const app = document.getElementById('app');
  app.innerHTML = '';

  if (typeof CRUCES !== 'undefined') for (const c of CRUCES) dibujarCruce(c, app);

  if (RECALCULO_INCOMPLETO) {
    const aviso = document.createElement('p');
    aviso.className = 'aviso';
    aviso.textContent = 'Los valores calculados no acabaron de estabilizarse. ' +
      'Puede haber una dependencia circular entre filas.';
    app.appendChild(aviso);
  }

  for (const tabla of ESQUEMA) {
    const seccion = document.createElement('section');
    const titulo = document.createElement('h2');
    titulo.textContent = tabla.etiqueta;
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
    thEstado.textContent = 'Estado';
    trh.appendChild(thEstado);
    thead.appendChild(trh);
    t.appendChild(thead);

    const tbody = document.createElement('tbody');
    D[tabla.nombre].forEach((fila, indice) => {
      const disparadas = marcasDe(tabla.nombre, fila);
      const tr = document.createElement('tr');

      for (const c of tabla.campos) {
        const td = document.createElement('td');
        td.className = c.rol;
        // El rol decide que se dibuja. Es el mismo hecho del dominio que en
        // la hoja de calculo decide el bloqueo y el color de la pestana.
        if (c.rol === 'entrada') {
          const clave = tabla.nombre + '.' + c.n;
          const dominio = DOMINIOS[clave];
          let control;
          if (dominio) {
            const valores = dominio.valores();
            if (dominio.bloquea) {
              control = document.createElement('select');
              const vacia = document.createElement('option');
              vacia.value = ''; vacia.textContent = '';
              control.appendChild(vacia);
              for (const v of valores) {
                const o = document.createElement('option');
                o.value = v; o.textContent = v;
                control.appendChild(o);
              }
            } else {
              // Avisa sin bloquear, como los desplegables del corpus.
              control = document.createElement('input');
              const lista = document.createElement('datalist');
              lista.id = 'dl_' + tabla.nombre + '_' + c.n + '_' + indice;
              for (const v of valores) {
                const o = document.createElement('option');
                o.value = v;
                lista.appendChild(o);
              }
              control.setAttribute('list', lista.id);
              td.appendChild(lista);
              if (!VACIO(fila[c.n]) && !valores.some(v => IG(v, fila[c.n]))) {
                const aviso = document.createElement('div');
                aviso.className = 'aviso';
                aviso.textContent = 'no esta en la lista';
                td.appendChild(aviso);
              }
            }
          } else {
            control = document.createElement('input');
            if (c.tipo === 'entero' || c.tipo === 'numero') control.type = 'number';
          }
          control.value = fila[c.n] ?? '';
          control.addEventListener('input', e => {
            const v = e.target.value;
            fila[c.n] = (c.tipo === 'entero' || c.tipo === 'numero')
                        ? (v === '' ? '' : Number(v)) : v;
            render();
          });
          td.insertBefore(control, td.firstChild);
        } else {
          td.textContent = T(fila[c.n]);
        }
        // La marca senala los campos que declara su alcance.
        const suyas = disparadas.filter(m => m.campos.includes(c.n));
        if (suyas.length) td.classList.add(suyas[0].clase);
        tr.appendChild(td);
      }

      const tdEstado = document.createElement('td');
      tdEstado.className = 'estado';
      tdEstado.textContent = disparadas.map(m => {
        try { return m.explica ? m.explica(fila) : m.nombre.replace(/-/g, ' '); }
        catch(e){ return m.nombre.replace(/-/g, ' '); }
      }).join('; ');
      tr.appendChild(tdEstado);
      tbody.appendChild(tr);
    });
    t.appendChild(tbody);
    envoltura.appendChild(t);
    seccion.appendChild(envoltura);

    // Crecer es nativo aqui: un boton. En la hoja de calculo hace falta
    // reservar filas y definir un rango que se dimensione con lo escrito.
    if (tabla.crece) {
      const boton = document.createElement('button');
      boton.textContent = '+ Anadir fila';
      boton.addEventListener('click', () => {
        const nueva = {};
        for (const c of tabla.campos) if (c.rol !== 'derivado') nueva[c.n] = '';
        D[tabla.nombre].push(nueva);
        render();
      });
      seccion.appendChild(boton);
    }

    const leyenda = MARCAS.filter(m => m.coleccion === tabla.nombre);
    if (leyenda.length) {
      const p = document.createElement('p');
      p.className = 'leyenda';
      for (const m of leyenda) {
        const s = document.createElement('span');
        s.className = m.clase;
        s.textContent = m.nombre.replace(/-/g, ' ');
        p.appendChild(s);
      }
      seccion.appendChild(p);
    }
    app.appendChild(seccion);
  }
}
"
  "El dibujo de la tabla y sus controles.")
