// Comprueba que la pagina generada calcula lo mismo que el evaluador de
// referencia del nucleo.
//
// Es la contraparte del round-trip por LibreOffice. Alli el programa de hojas
// de calculo evalua las formulas y se comparan los valores; aqui se ejecuta el
// JavaScript que la arquitectura web emitio y se comparan los suyos.
//
// Con las dos, la afirmacion "las tres arquitecturas coinciden con la
// semantica del lenguaje" deja de ser un argumento de diseno y pasa a ser un
// resultado medido en dos destinos que no comparten absolutamente nada: uno
// evalua formulas A1 dentro de una rejilla, el otro ejecuta funciones sobre
// arreglos.
//
// No se carga el navegador: se ejecuta solo la parte de calculo. El dibujo de
// la tabla no se comprueba aqui, y eso se dice en el informe para no dar por
// verificado mas de lo que se verifica.
//
// Uso:
//   node verificar-web.js <pagina.html> <esperado.json>

const fs = require('fs');
const vm = require('vm');

function extraerScript(html) {
  const inicio = html.indexOf('<script>');
  const fin = html.lastIndexOf('</script>');
  if (inicio < 0 || fin < 0) throw new Error('la pagina no trae script');
  return html.slice(inicio + '<script>'.length, fin);
}

function quitarLaParteDeDibujo(js) {
  // El script termina llamando a render(), que toca el DOM. Se corta ahi: lo
  // que interesa son los datos, las derivaciones, las marcas y los dominios.
  const marca = '\nfunction marcasDe(';
  const corte = js.indexOf(marca);
  return corte > 0 ? js.slice(0, corte) : js;
}

function normalizar(v) {
  if (v === null || v === undefined || v === '') return '';
  if (typeof v === 'number') return v;
  const n = Number(v);
  return Number.isNaN(n) ? String(v) : n;
}

function main(argv) {
  if (argv.length !== 4) {
    console.log('Uso: node verificar-web.js <pagina.html> <esperado.json>');
    return 2;
  }
  const html = fs.readFileSync(argv[2], 'utf8');
  const esperado = JSON.parse(fs.readFileSync(argv[3], 'utf8'));

  const contexto = { console };
  vm.createContext(contexto);
  vm.runInContext(quitarLaParteDeDibujo(extraerScript(html)), contexto);

  // Se recalcula todo, igual que hace la pagina al abrirse.
  vm.runInContext('recalcularTodo();', contexto);

  // `const` en el script crea ligaduras de ambito, no propiedades del objeto
  // global, asi que los valores se recogen evaluando su nombre en el contexto.
  const D = vm.runInContext('D', contexto);
  const MARCAS = vm.runInContext('MARCAS', contexto);

  let comprobadas = 0;
  const fallos = [];

  for (const [coleccion, filasEsperadas] of Object.entries(esperado)) {
    const filas = D[coleccion];
    if (!filas) { fallos.push(`la pagina no trae la coleccion ${coleccion}`); continue; }
    filasEsperadas.forEach((envoltura, i) => {
      const valores = Array.isArray(envoltura) ? envoltura[0] : envoltura;
      const fila = filas[i];
      if (!fila) { fallos.push(`${coleccion}[${i}] no existe en la pagina`); return; }
      for (const [campo, valor] of Object.entries(valores)) {
        const real = normalizar(fila[campo]);
        const esp = normalizar(valor);
        comprobadas++;
        if (real !== esp) {
          fallos.push(`${coleccion}[${i}].${campo}  esperado ${JSON.stringify(esp)}` +
                      `  obtenido ${JSON.stringify(real)}`);
        }
      }
    });
  }

  // Y las marcas: tienen que disparar en las mismas filas.
  for (const m of MARCAS) {
    const filas = D[m.coleccion] || [];
    filas.forEach((fila, i) => {
      comprobadas++;
      try { m.cond(fila); }
      catch (e) { fallos.push(`la marca ${m.nombre} revienta en ${m.coleccion}[${i}]: ${e.message}`); }
    });
  }

  const nombre = argv[2].split('/').pop();
  if (fallos.length) {
    console.log(`FALLA  ${nombre}: ${comprobadas} comprobaciones, ${fallos.length} discrepancias`);
    fallos.slice(0, 20).forEach(f => console.log('   ' + f));
    return 1;
  }
  console.log(`  ok   ${nombre}: ${comprobadas} valores calculados por el JavaScript ` +
              `emitido coinciden con el evaluador de referencia`);
  return 0;
}

process.exit(main(process.argv));
