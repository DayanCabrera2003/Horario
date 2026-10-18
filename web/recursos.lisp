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
.aviso-de-dominio { margin:10px 0 0; padding:6px 10px; font-size:13px; color:#7a4a00;
                     background:#fff4d6; border-left:3px solid #e0a800; }
.indice { display:flex; flex-wrap:wrap; gap:6px 14px; margin:0 0 20px; font-size:14px; }
.indice a, a.arriba { color:#2f5597; }
a.arriba { display:inline-block; margin-top:8px; font-size:12px; }
h3 { font-size:15px; margin:18px 0 6px; font-weight:600; }
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
// Redondeo a N decimales con el empate alejandose de cero, sobre la
// escritura decimal del numero y no sobre el doble binario: 2.675 da 2.68,
// como NUCLEO:REDONDEAR-A-DECIMALES y como ROUND de la hoja de calculo
// (fase 2, hueco C6). Se lleva el numero a 15 cifras, se mueve la coma con
// la notacion exponencial (que JavaScript lee en decimal) y se redondea.
function REDONDEO(x, n){
  const s = Math.sign(x);
  const [m, e] = Math.abs(Number(x.toPrecision(15))).toExponential().split('e');
  const r = Math.floor(Number(m + 'e' + (Number(e) + n)) + 0.5);
  return s * Number(r + 'e' + (-n));
}
function REDONDEAR(x, n){
  if (VACIO(x)) return '';
  const r = REDONDEO(N(x), n);
  return r === 0 ? 0 : r;
}
// Un numero con exactamente N decimales; lo que no es numero, como siempre.
function NUMDEC(x, n){
  if (typeof x !== 'number' || !isFinite(x)) return T(x);
  const r = REDONDEO(x, n);
  return (r === 0 ? 0 : r).toFixed(n);
}
// Como se escribe un valor en la celda de su campo: con sus decimales.
function TC(x, campo){
  return (campo && campo.dec !== undefined) ? NUMDEC(x, campo.dec) : T(x);
}
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
// Con MISMOS (los campos de :MISMO), la contigua solo cuenta si tiene los
// mismos valores en ellos; si no, no hay fila (fase 2, hueco C3).
function VECINO(coleccion, fila, paso, mismos){
  const i = coleccion.indexOf(fila);
  const j = i + paso;
  if (j < 0 || j >= coleccion.length) return null;
  const contigua = coleccion[j];
  return (mismos || []).every(c => IG(contigua[c], fila[c])) ? contigua : null;
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

// --- Marcas y estado de una fila ---
function marcasDe(nombreColeccion, fila){
  return MARCAS.filter(m => m.coleccion === nombreColeccion)
               .filter(m => { try { return VERDAD(m.cond(fila)); } catch(e){ return false; } });
}

function explicacionDe(m, fila){
  try { return m.explica ? T(m.explica(fila)) : m.leyenda; }
  catch(e){ return m.leyenda; }
}

// El estado de una fila en palabras: el mismo texto que escriben el texto
// plano y la hoja de calculo (NUCLEO:TEXTO-DE-ESTADO).
function estadoDe(nombreColeccion, fila){
  return marcasDe(nombreColeccion, fila).map(m => explicacionDe(m, fila)).join('; ');
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
