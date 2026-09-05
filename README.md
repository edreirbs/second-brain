# Cerebro

El tablero de tus dos vaults, servido en GitHub Pages para que lo abras desde
donde estés, y cifrado para que solo lo abras tú.

**Liga:** https://edreirbs.github.io/second-brain/

## Cómo funciona

`generador/build.py` recorre los dos vaults, arma los grafos, reescribe
`meta/graph.json` en cada uno y llena `generador/plantilla.html` con los datos.
`publicar.sh` toma ese HTML, lo cifra y lo deja en `sitio/`, que es lo que
sirve Pages.

```
tus vaults ──build.py──> generador/cerebro.html ──cifrar──> sitio/index.html ──push──> tu liga
              (fuera del repo)      (nunca se commitea)         (cifrado)
```

`sitio/index.html` es un candado: una página mínima que pide una frase y
descifra el tablero en tu navegador. Lo que llega a GitHub es puro texto
cifrado — ni los títulos de tus notas, ni los nombres de la carpeta
`personas`, ni las relaciones viajan en claro.

Cifrado: AES-256-CBC con llave derivada por PBKDF2-SHA256 (250 000 vueltas) y
sal nueva en cada publicada. El navegador descifra con WebCrypto y verifica la
huella del contenido antes de pintarlo.

Los vaults no están aquí y no se copian aquí. `generador/cerebro.html` es lo
único que combina los dos, y está en `.gitignore`: se queda en tu Mac.

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

Si el `cerebro.html` no cambió desde la última vez, el script no hace nada, así
el historial no se llena de commits iguales. Si el push se cae, la siguiente
corrida lo detecta y solo sube lo que faltaba.

### Si moviste las carpetas

`build.py` acepta `CEREBRO_TEC` y `CEREBRO_PER` para apuntar a otros vaults.
`publicar.sh` acepta `CEREBRO_DIR` (dónde vive el generador, por omisión
`generador/` aquí mismo) y `CEREBRO_HTML` (el archivo directo):

```sh
CEREBRO_TEC=~/otra/ruta ./publicar.sh
```

## Que se actualice solo

El paso 4 de `/compilar` corría `build.py` en `~/Documents/cerebro`. Cámbialo
por esto y cada compilada deja la liga al día sin que hagas nada:

```sh
~/ruta/a/second-brain/publicar.sh
```

Ya no hace falta llamar a `build.py` por separado: `publicar.sh` lo corre.

## Encender Pages (una sola vez)

1. En este repo: **Settings → Pages**.
2. En *Source* elige **GitHub Actions**.
3. Listo. Cada push a la rama principal que toque `sitio/` republica la liga.

El repo se creó vacío, así que GitHub tomó la primera rama que subió como
principal. Si prefieres que se llame `main`, renómbrala en **Settings →
Branches**; el workflow lee cuál es la principal en cada corrida, así que
sigue funcionando con el nombre que le pongas.

Puedes republicar a mano desde **Actions → Publicar el cerebro → Run workflow**.

## Sobre la privacidad

Este repo es público y un sitio de GitHub Pages siempre lo es. Por eso el
tablero se publica cifrado: la liga la puede abrir cualquiera, pero sin la
frase solo ve el candado.

Lo que el tablero muestra no son tus notas completas — son títulos, carpetas,
proyectos, fechas, tamaños y el mapa de relaciones, más la carpeta `personas`
con nombres. Suficiente para no quererlo suelto.

El candado protege el contenido, no el hecho de que el sitio existe. Y la
frase es lo único que separa tus notas del mundo: que sea larga, y que no sea
la de otro lado. La página lleva `noindex`, así que los buscadores no deberían
listarla.

`--publico` quita el candado y sube el tablero en claro. Como el repo es
público, eso deja todo lo de arriba a la vista de cualquiera, para siempre y
en los mirrors de GitHub. Úsalo solo si de verdad no te importa.

### Si se te olvida la frase

No hay manera de recuperarla: no está guardada en ningún lado más que en tu
Llavero. Corre `./publicar.sh --forzar` con una frase nueva y listo — el
tablero se regenera completo en cada publicada, no se pierde nada.

Para cambiarla:

```sh
security delete-generic-password -s cerebro-pages
./publicar.sh --forzar
```

## Qué hay aquí

| Archivo | Para qué |
| --- | --- |
| `publicar.sh` | El único comando que corres |
| `generador/build.py` | Recorre los vaults y arma los grafos |
| `generador/plantilla.html` | El diseño del tablero |
| `herramientas/cifrar.py` | Envuelve el HTML en el candado |
| `herramientas/candado.html` | El diseño de la pantalla de la frase |
| `sitio/index.html` | Lo que sirve Pages: tu cerebro cifrado |
| `.github/workflows/paginas.yml` | Despliega `sitio/` en cada push a la rama principal |
