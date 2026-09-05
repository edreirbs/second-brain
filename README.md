# Cerebro

El tablero de tus dos vaults, servido en GitHub Pages para que lo abras desde
donde estés, y cifrado para que solo lo abras tú.

**Liga:** https://edreirbs.github.io/second-brain/ *(vive después de encender Pages; ver abajo)*

## Cómo funciona

El generador sigue viviendo en tu Mac, en `~/Documents/cerebro/`: `build.py`
recorre los dos vaults y escribe `cerebro.html`. Este repo no toca los vaults
ni los contiene. Lo único que hace es tomar ese `cerebro.html` ya generado,
cifrarlo y publicarlo.

```
tu Mac                                    este repo                GitHub Pages
~/Documents/cerebro/
  build.py  ──> cerebro.html  ──cifrar──> sitio/index.html  ──push──> tu liga
```

`sitio/index.html` es un candado: una página mínima que pide una frase y
descifra el tablero en tu navegador. Lo que se sube a GitHub es puro texto
cifrado — ni los títulos de tus notas ni las relaciones viajan en claro.

Cifrado: AES-256-CBC con llave derivada por PBKDF2-SHA256 (250 000 vueltas) y
sal nueva en cada publicada. El descifrado usa WebCrypto, sin librerías.

## Publicar

Desde tu Mac, dentro de la carpeta de este repo:

```sh
./publicar.sh
```

Compila, cifra, hace commit y sube. La primera vez te pide la frase dos veces
y la guarda en el Llavero de macOS; después ya no vuelve a preguntar, lo que
permite correrlo sin que estés presente.

| Opción | Qué hace |
| --- | --- |
| `--sin-compilar` | No corre `build.py`; usa el `cerebro.html` que ya existe |
| `--forzar` | Publica aunque el cerebro no haya cambiado |
| `--local` | Genera `sitio/index.html` y ahí se queda: sin commit ni push |
| `--publico` | **Sin cifrar.** Deja tus notas legibles para cualquiera con la liga |

Si el `cerebro.html` no cambió desde la última vez, el script no hace nada:
así el historial no se llena de commits iguales.

### Si moviste las carpetas

`CEREBRO_DIR` apunta a la carpeta del generador (por omisión
`~/Documents/cerebro`) y `CEREBRO_HTML` al archivo directo:

```sh
CEREBRO_DIR=~/otra/ruta ./publicar.sh
```

## Que se actualice solo

El paso 4 de `/compilar` ya corre `build.py`. Agrégale un paso 5 que corra
esto, y cada compilada deja la liga al día sin que hagas nada:

```sh
~/ruta/a/second-brain/publicar.sh --sin-compilar
```

Va `--sin-compilar` porque `/compilar` ya generó el HTML en el paso anterior.

## Encender Pages (una sola vez)

1. En este repo: **Settings → Pages**.
2. En *Source* elige **GitHub Actions**.
3. Listo. Cada push a `main` que toque `sitio/` republica la liga.

Puedes republicar a mano desde **Actions → Publicar el cerebro → Run workflow**.

## Sobre la privacidad

Un sitio de GitHub Pages **es público en internet aunque el repo sea privado**
(la excepción es GitHub Enterprise). Por eso el contenido se publica cifrado:
la liga la puede abrir cualquiera, pero sin la frase solo ve el candado.

Esto protege el contenido, no el hecho de que el sitio existe. Y la frase es
lo único que separa tus notas del mundo: que sea larga, y que no sea la de
otro lado. `--publico` quita el candado y sube el tablero en claro; úsalo solo
si de verdad no te importa que se lea.

La página lleva `noindex`, así que los buscadores no deberían listarla.

Frontera entre vaults: igual que antes, este repo no guarda notas de ninguno
de los dos. Guarda una vista combinada y cifrada, generada en tu Mac.

### Si se te olvida la frase

No hay manera de recuperarla: no está guardada en ningún lado más que en tu
Llavero. Corre `./publicar.sh --forzar` con una frase nueva y listo — el
tablero se regenera completo en cada publicada, no se pierde nada.

Para cambiarla, borra la vieja del Llavero y vuelve a publicar:

```sh
security delete-generic-password -s cerebro-pages
./publicar.sh --forzar
```

## Qué hay aquí

| Archivo | Para qué |
| --- | --- |
| `publicar.sh` | El único comando que corres |
| `herramientas/cifrar.py` | Envuelve el HTML en el candado |
| `herramientas/candado.html` | El diseño de la pantalla de la frase |
| `sitio/index.html` | Lo que sirve Pages: tu cerebro cifrado |
| `.github/workflows/paginas.yml` | Despliega `sitio/` en cada push a `main` |
