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
td.grupo { background:#eef2f8; font-weight:600; }
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
// Una fecha AAAA-MM-DD vale su dia juliano y una hora HH:MM sus minutos desde
// medianoche, exactamente como en nucleo/evaluador.lisp (FECHA-COMO-NUMERO y
// HORA-COMO-NUMERO). Antes se usaba parseFloat, y '2026-10-12' y '2026-10-10'
// valian los dos 2026: comparar dos fechas del mismo ano daba siempre falso.
function FECHANUM(s){
  const m = /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/.exec(s);
  if (!m) return null;
  const anio = +m[1], mes = +m[2], dia = +m[3];
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
  const a = Math.floor((14 - mes) / 12), y = anio + 4800 - a, mm = mes + 12 * a - 3;
  return dia + Math.floor((153 * mm + 2) / 5) + 365 * y + Math.floor(y / 4)
         - Math.floor(y / 100) + Math.floor(y / 400) - 32045;
}
function HORANUM(s){
  const m = /^([0-9]{2}):([0-9]{2})$/.exec(s);
  if (!m) return null;
  const h = +m[1], mi = +m[2];
  return (h <= 23 && mi <= 59) ? 60 * h + mi : null;
}
function ESFECHA(s){ return FECHANUM(s) !== null; }
function ESHORA(s){ return HORANUM(s) !== null; }
// Un texto vale su numero si lo es entero (Number, no parseFloat: '12abc' no
// es 12 para el evaluador), o su fecha o su hora; si no, 0.
function N(x){ if (typeof x === 'number') return x;
               if (VACIO(x) || x === false) return 0;
               if (x === true) return 0;
               const s = String(x);
               const f = FECHANUM(s); if (f !== null) return f;
               const h = HORANUM(s); if (h !== null) return h;
               const n = Number(s.trim()); return isNaN(n) ? 0 : n; }
// Un numero se ensena con hasta 10 cifras significativas, sin ceros a la
// derecha: la misma regla que nucleo/numeros.lisp (TEXTO-DE-NUMERO).
function NUMTXT(x){ if (Number.isInteger(x)) return String(x);
                    if (!isFinite(x)) return '';
                    return String(Number(x.toPrecision(10))); }
function T(x){ if (x === null || x === undefined || x === false) return '';
               if (x === true) return 'si';
               if (typeof x === 'number') return NUMTXT(x);
               return String(x); }
// Un booleano del lenguaje es la cadena 'si' o 'no' (nucleo/booleanos.lisp).
// VERDAD dice si un valor cuenta como verdadero en una condicion; BOOL lo
// convierte en 'si' o 'no'.
function VERDAD(x){ return x === true || x === 'si' || (typeof x === 'number' && x !== 0); }
function BOOL(x){ return VERDAD(x) ? 'si' : 'no'; }
// Dividir por cero da vacio, como en el evaluador.
function DIV(a, b){ const d = N(b); return d === 0 ? '' : N(a) / d; }
function IG(a,b){ if (a === true) a = 'si'; if (b === true) b = 'si';
                  if (a === false) a = ''; if (b === false) b = '';
                  if (VACIO(a) && VACIO(b)) return true;
                  if (VACIO(a) || VACIO(b)) return false;
                  if (typeof a === 'number' || typeof b === 'number') return N(a) === N(b);
                  return String(a) === String(b); }
function V(x){ return x === undefined ? '' : x; }

// --- Busqueda por clave con su valor por defecto ---
// El valor por defecto es para cuando la fila no existe. Si existe y su campo
// esta vacio, el resultado es vacio: es lo que dice el evaluador de
// referencia, y lo que hace la hoja de calculo. Antes se devolvia el valor
// por defecto tambien en ese caso, y la pagina discrepaba de las otras dos.
function PROY(fila, campo, pordefecto){
  if (!fila) return pordefecto;
  return V(fila[campo]);
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
  const filasDelDato = D[cruce.coleccion] || [];
  // El filtro esconde filas de la PRESENTACION y no toca D: los agregados y
  // las marcas siguen viendo la coleccion entera. Se evalua en cada render,
  // asi que una fila que deja de cumplirlo desaparece sola.
  const todas = cruce.filtro ? filasDelDato.filter(f => !!cruce.filtro(f))
                             : filasDelDato;
  const secciones = cruce.secciones ? distintosDe(todas, cruce.secciones) : [null];
  for (const s of secciones) {
    const filas = s === null ? todas
                             : todas.filter(f => IG(f[cruce.secciones], s));
    dibujarUnaTabla(cruce, filas, s, app);
  }
}

// Las filas en el orden en que se van a MOSTRAR, cada una con el indice que
// ocupa en D y, si empieza un grupo, la cabecera que va encima. Sin campo de
// agrupacion es la identidad: mismas filas, mismo orden, sin cabeceras.
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
      // TODAS las que caen ahi, no la primera. Normalmente es una, porque
      // los ejes determinan la fila y el analisis lo exige. Son varias
      // cuando la vista declaro unica-salvo: entonces el choque existe y hay
      // que ensenarlo en vez de elegir uno y callarse.
      const enLaCasilla = filas.filter(f => IG(f[cruce.ejeFilas], vf) &&
                                            IG(f[cruce.ejeColumnas], vc));
      const td = document.createElement('td');
      td.textContent = enLaCasilla.map(f => T(f[cruce.celda])).join(' / ');
      // Las marcas de las filas que caen en el cruce tinen la celda.
      for (const fila of enLaCasilla) {
        const suyas = marcasDe(cruce.coleccion, fila);
        if (suyas.length) { td.classList.add(suyas[0].clase); break; }
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
    // Agrupar es SOLO de presentacion: el arreglo D no se toca. Sus indices
    // siguen siendo los mismos, que es lo que usan los controles de entrada
    // para escribir de vuelta, y lo que hace que la fila anterior siga
    // significando lo mismo. En una hoja de calculo no se puede separar las
    // dos cosas, porque alli la posicion de la fila ES el dato.
    ordenarParaMostrar(D[tabla.nombre], tabla.agrupa).forEach(par => {
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
            // Plan aprobado de tipos, seccion 4.1: un selector de verdad.
            if (c.tipo === 'fecha') control.type = 'date';
            if (c.tipo === 'hora') control.type = 'time';
          }
          control.value = fila[c.n] ?? '';
          control.addEventListener('input', e => {
            const v = e.target.value;
            fila[c.n] = (c.tipo === 'entero' || c.tipo === 'numero')
                        ? (v === '' ? '' : Number(v)) : v;
            render();
          });
          td.insertBefore(control, td.firstChild);
        } else if (c.clave) {
          // Relacion uno a muchos: cada fila relacionada por su clave.
          td.textContent = (fila[c.n] || [])
            .map(r => c.clave.map(k => T(r[k])).join(' ')).join(', ');
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
