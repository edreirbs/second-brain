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

# El generador vive aquí. CEREBRO_DIR sigue existiendo para quien tenga la
# carpeta vieja en ~/Documents/cerebro y no la quiera mover.
CEREBRO_DIR="${CEREBRO_DIR:-$REPO/generador}"
FUENTE="${CEREBRO_HTML:-$CEREBRO_DIR/cerebro.html}"
DESTINO="$REPO/sitio/index.html"
HUELLA="$REPO/sitio/.huella"
SERVICIO="cerebro-pages"
CUENTA="${USER:-$(id -un)}"

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

# ¿Hay commits hechos que nunca llegaron al remoto?
pendientes() {
  git -C "$REPO" rev-parse HEAD >/dev/null 2>&1 || return 1
  git -C "$REPO" rev-parse '@{upstream}' >/dev/null 2>&1 || return 0
  [ "$(git -C "$REPO" rev-list --count '@{upstream}..HEAD')" -gt 0 ]
}

empujar() {
  local rama principal
  rama="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
  principal="$(git -C "$REPO" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  principal="${principal#origin/}"
  if [ -n "$principal" ] && [ "$rama" != "$principal" ]; then
    aviso "Ojo: estás en la rama '$rama'; Pages publica desde '$principal'."
  fi

  local espera
  for espera in 2 4 8 16 0; do
    if git -C "$REPO" push -u origin "$rama" 2>&1 | sed 's/^/  /'; then
      return 0
    fi
    if [ "$espera" -eq 0 ]; then
      morir "no pude subir los cambios. Corre ./publicar.sh otra vez cuando haya red."
    fi
    aviso "Falló el push; reintento en ${espera}s…"
    sleep "$espera"
  done
}

liga() {
  local origen ruta
  origen="$(git -C "$REPO" remote get-url origin 2>/dev/null || true)"
  ruta="$(printf '%s' "$origen" | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
  if printf '%s' "$ruta" | grep -Eq '^[^/]+/[^/]+$'; then
    aviso "Publicado: https://${ruta%%/*}.github.io/${ruta#*/}/"
  else
    aviso "Publicado."
  fi
}

# 1. Compilar ------------------------------------------------------------
if [ "$compilar" -eq 1 ] && [ -f "$CEREBRO_DIR/build.py" ]; then
  aviso "Compilando el cerebro…"
  ( cd "$CEREBRO_DIR" && python3 build.py ) || morir "build.py falló."
fi

if [ ! -f "$FUENTE" ]; then
  if [ "$compilar" -eq 0 ]; then
    morir "no encuentro $FUENTE. Corre ./publicar.sh sin --sin-compilar para generarlo."
  fi
  morir "no encuentro $FUENTE (ajusta CEREBRO_DIR o CEREBRO_HTML)."
fi

# 2. ¿Cambió algo? -------------------------------------------------------
nueva="$(shasum -a 256 "$FUENTE" 2>/dev/null || sha256sum "$FUENTE")"
nueva="${nueva%% *}"

if [ "$forzar" -eq 0 ] && [ -f "$HUELLA" ] && [ "$(cat "$HUELLA")" = "$nueva" ]; then
  # La huella se escribe junto al sitio y viaja en el commit, así que puede
  # coincidir aunque la publicada anterior se haya quedado sin subir.
  if [ "$subir" -eq 1 ] && pendientes; then
    aviso "El cerebro no cambió, pero la publicada anterior no llegó al remoto."
    empujar
    liga
    exit 0
  fi
  aviso "El cerebro no ha cambiado desde la última publicada. Nada que hacer."
  exit 0
fi

# 3. Generar sitio/index.html -------------------------------------------
mkdir -p "$REPO/sitio"
sello="$(date '+%d/%m/%Y %H:%M')"

if [ "$cifrado" -eq 1 ]; then
  if [ -z "${CEREBRO_PASS:-}" ]; then
    CEREBRO_PASS="$(security find-generic-password -a "$CUENTA" -s "$SERVICIO" -w 2>/dev/null || true)"
  fi
  if [ -z "${CEREBRO_PASS:-}" ]; then
    [ -t 0 ] || morir "no hay frase. Define CEREBRO_PASS o corre ./publicar.sh una vez a mano para guardarla en el Llavero."
    printf 'Frase para cifrar el cerebro: ' >&2; read -r -s CEREBRO_PASS; printf '\n' >&2
    printf 'Repítela: ' >&2; read -r -s repetida; printf '\n' >&2
    [ -n "$CEREBRO_PASS" ] || morir "la frase viene vacía."
    [ "$CEREBRO_PASS" = "$repetida" ] || morir "las frases no coinciden."
    if command -v security >/dev/null 2>&1 &&
       security add-generic-password -a "$CUENTA" -s "$SERVICIO" -w "$CEREBRO_PASS" -U 2>/dev/null; then
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
git -C "$REPO" add -- sitio
if git -C "$REPO" diff --cached --quiet; then
  aviso "El sitio quedó idéntico. Sin commit."
  exit 0
fi
git -C "$REPO" commit -q -m "Cerebro al $sello"
empujar
liga
