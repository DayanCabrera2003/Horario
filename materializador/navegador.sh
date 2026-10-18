# Arranca y cierra el navegador sin pantalla que usan las sondas de la pagina.
#
# Se incluye con "." desde demostrar.sh y demostrar-robustez.sh. Arranca UNA
# sola instancia de Chromium con un perfil temporal, la reutiliza para todas
# las paginas y la cierra al salir, pase lo que pase (trap). Si no hay
# Chromium instalado, las sondas se saltan y se dice.

PUERTO_NAVEGADOR=9339
NAVEGADOR_PID=""
PERFIL_NAVEGADOR=""

cerrar_navegador() {
  if [ -n "$NAVEGADOR_PID" ]; then
    kill "$NAVEGADOR_PID" 2>/dev/null
    wait "$NAVEGADOR_PID" 2>/dev/null
    NAVEGADOR_PID=""
  fi
  if [ -n "$PERFIL_NAVEGADOR" ]; then
    # Los procesos hijos del navegador tardan un momento en salir y siguen
    # escribiendo en el perfil: se espera a que no quede ninguno.
    for i in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -f -- "$PERFIL_NAVEGADOR" > /dev/null 2>&1 || break
      sleep 0.5
    done
    pkill -f -- "$PERFIL_NAVEGADOR" 2>/dev/null
    rm -rf "$PERFIL_NAVEGADOR" 2>/dev/null
    PERFIL_NAVEGADOR=""
  fi
}

# Devuelve 0 si el navegador queda escuchando, 1 si no se pudo arrancar.
arrancar_navegador() {
  binario=""
  for b in chromium-browser chromium google-chrome; do
    if command -v "$b" >/dev/null 2>&1; then binario="$b"; break; fi
  done
  [ -n "$binario" ] || return 1
  PERFIL_NAVEGADOR=$(mktemp -d)
  "$binario" --headless=new --remote-debugging-port="$PUERTO_NAVEGADOR" \
             --user-data-dir="$PERFIL_NAVEGADOR" --no-first-run --disable-gpu \
             about:blank > /dev/null 2>&1 &
  NAVEGADOR_PID=$!
  trap cerrar_navegador EXIT
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -s "127.0.0.1:$PUERTO_NAVEGADOR/json/version" > /dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  cerrar_navegador
  return 1
}
