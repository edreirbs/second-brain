#!/usr/bin/env bash
#
# Publica el cerebro en GitHub Pages.
#
#   ./publicar.sh                 compila, cifra y publica
#   ./publicar.sh --sin-compilar  usa el cerebro.html que ya existe
#   ./publicar.sh --forzar        publica aunque no haya cambiado nada
#   ./publicar.sh --publico       SIN cifrar (queda legible en internet)
#   ./publicar.sh --local         genera sitio/index.html y no hace commit
#
# De dónde sale la frase para cifrar, en este orden:
#   1. la variable de entorno CEREBRO_PASS
#   2. el Llavero de macOS (servicio "cerebro-pages")
#   3. te la pregunta, y la guarda en el Llavero para las siguientes veces
#
# Dónde busca los archivos: CEREBRO_DIR, por omisión ~/Documents/cerebro

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CEREBRO_DIR="${CEREBRO_DIR:-$HOME/Documents/cerebro}"
FUENTE="${CEREBRO_HTML:-$CEREBRO_DIR/cerebro.html}"
DESTINO="$REPO/sitio/index.html"
HUELLA="$REPO/sitio/.huella"
SERVICIO="cerebro-pages"

compilar=1; forzar=0; cifrado=1; subir=1
for arg in "$@"; do
  case "$arg" in
    --sin-compilar) compilar=0 ;;
    --forzar)       forzar=1 ;;
    --publico)      cifrado=0 ;;
    --local)        subir=0 ;;
    -h|--help)      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "publicar: opción desconocida: $arg" >&2; exit 2 ;;
  esac
done

aviso() { printf '  %s\n' "$*"; }
morir() { printf 'publicar: %s\n' "$*" >&2; exit 1; }

# 1. Compilar ------------------------------------------------------------
if [ "$compilar" -eq 1 ] && [ -f "$CEREBRO_DIR/build.py" ]; then
  aviso "Compilando el cerebro…"
  ( cd "$CEREBRO_DIR" && python3 build.py ) || morir "build.py falló."
fi

[ -f "$FUENTE" ] || morir "no encuentro $FUENTE (ajusta CEREBRO_DIR o CEREBRO_HTML)."

# 2. ¿Cambió algo? -------------------------------------------------------
nueva="$(shasum -a 256 "$FUENTE" 2>/dev/null || sha256sum "$FUENTE")"
nueva="${nueva%% *}"
if [ "$forzar" -eq 0 ] && [ -f "$HUELLA" ] && [ "$(cat "$HUELLA")" = "$nueva" ]; then
  aviso "El cerebro no ha cambiado desde la última publicada. Nada que hacer."
  exit 0
fi

# 3. Generar sitio/index.html -------------------------------------------
mkdir -p "$REPO/sitio"
sello="$(date '+%d/%m/%Y %H:%M')"

if [ "$cifrado" -eq 1 ]; then
  if [ -z "${CEREBRO_PASS:-}" ]; then
    CEREBRO_PASS="$(security find-generic-password -a "${USER:-$(id -un)}" -s "$SERVICIO" -w 2>/dev/null || true)"
  fi
  if [ -z "${CEREBRO_PASS:-}" ]; then
    [ -t 0 ] || morir "no hay frase. Define CEREBRO_PASS o corre ./publicar.sh una vez a mano para guardarla en el Llavero."
    printf 'Frase para cifrar el cerebro: ' >&2; read -r -s CEREBRO_PASS; printf '\n' >&2
    printf 'Repítela: ' >&2; read -r -s repetida; printf '\n' >&2
    [ -n "$CEREBRO_PASS" ] || morir "la frase viene vacía."
    [ "$CEREBRO_PASS" = "$repetida" ] || morir "las frases no coinciden."
    if command -v security >/dev/null 2>&1 &&
       security add-generic-password -a "${USER:-$(id -un)}" -s "$SERVICIO" -w "$CEREBRO_PASS" -U 2>/dev/null; then
      aviso "Frase guardada en el Llavero; ya no te la vuelvo a pedir."
    fi
  fi
  export CEREBRO_PASS
  python3 "$REPO/herramientas/cifrar.py" "$FUENTE" "$DESTINO" --sello "$sello" | sed 's/^/  /'
else
  aviso "PUBLICANDO SIN CIFRAR: cualquiera con la liga podrá leer tus notas."
  cp "$FUENTE" "$DESTINO"
fi

printf '%s\n' "$nueva" > "$HUELLA"
touch "$REPO/sitio/.nojekyll"

if [ "$subir" -eq 0 ]; then
  aviso "Listo (modo --local, sin commit): $DESTINO"
  exit 0
fi

# 4. Commit y push -------------------------------------------------------
cd "$REPO"
rama="$(git rev-parse --abbrev-ref HEAD)"
[ "$rama" = "main" ] || aviso "Ojo: estás en la rama '$rama'; Pages publica desde 'main'."

git add -- sitio
if git diff --cached --quiet; then
  aviso "El sitio quedó idéntico. Sin commit."
  exit 0
fi
git commit -q -m "Cerebro al $sello"

for intento in 2 4 8 16 0; do
  if git push -u origin "$rama" 2>&1 | sed 's/^/  /'; then
    break
  fi
  [ "$intento" -eq 0 ] && morir "no pude subir los cambios."
  aviso "Falló el push; reintento en ${intento}s…"
  sleep "$intento"
done

origen="$(git remote get-url origin 2>/dev/null || true)"
ruta="$(printf '%s' "$origen" | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
if printf '%s' "$ruta" | grep -Eq '^[^/]+/[^/]+$'; then
  aviso "Publicado: https://${ruta%%/*}.github.io/${ruta#*/}/"
else
  aviso "Publicado."
fi
