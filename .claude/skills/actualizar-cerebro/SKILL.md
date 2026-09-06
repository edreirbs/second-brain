---
name: actualizar-cerebro
description: Recompila el cerebro desde los dos vaults y publica la versión cifrada en GitHub Pages. Úsala cuando el usuario diga "actualiza el cerebro", "publica el cerebro", "sube el tablero", "republica el grafo" o invoque /actualizar-cerebro. No la uses para editar notas ni para generar el HTML sin publicarlo.
---

# Actualizar el cerebro

Corre el script de publicación y reporta el resultado en dos o tres líneas.

## Qué hacer

Corre esto, probando las rutas en orden hasta que una exista:

```sh
~/Documents/cerebro/publicar.sh
```

Si no está ahí, busca `publicar.sh` con:

```sh
ls ~/Documents/cerebro/publicar.sh ~/cerebro-pages/publicar.sh ~/second-brain/publicar.sh 2>/dev/null
```

El script compila los dos vaults, cifra el tablero, hace commit y lo sube.
Tarda menos de un minuto. No le pases opciones salvo que el usuario pida algo
concreto:

- `--forzar` si pide republicar aunque no haya cambiado nada
- `--sin-compilar` si pide subir el HTML que ya existe, sin recorrer los vaults

## Cómo reportar

Sé breve. Al usuario le interesa qué cambió, no el log.

- Si publicó: di cuántas notas y relaciones salieron de cada vault (el script
  las imprime) y deja la liga:
  https://edreirbs.github.io/second-brain/
- Si dice "El cerebro no ha cambiado": dilo en una línea y ya. No es un error.
- Si falla: di en qué paso murió y qué dice el error. No lo arregles por tu
  cuenta salvo que sea obvio.

## Cosas que importan

La contraseña vive en el Llavero de macOS, no en el repo. El script la saca de
ahí solo. Si la pide, es que no está guardada: pásale la petición al usuario,
nunca inventes una.

El despliegue a GitHub Pages tarda ~30 segundos más después del push. Si el
usuario abre la liga de inmediato y ve la versión vieja, que recargue.
