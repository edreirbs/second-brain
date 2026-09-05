#!/usr/bin/env python3
"""Envuelve un HTML en una página con candado (AES-256-CBC + PBKDF2-SHA256).

El HTML entero se cifra y se incrusta en base64 dentro de una página mínima
que pide la frase y lo descifra en el navegador con WebCrypto. Nada del
contenido viaja en claro al repositorio ni a GitHub Pages.

Solo usa la librería estándar de Python más el binario `openssl`, que ya viene
en macOS. La derivación de la llave se hace en Python (hashlib), así que no
depende de que openssl soporte `-pbkdf2`.

    cifrar.py <entrada.html> <salida.html> [--sello "5 sep 2026, 18:04"]

La frase se lee de la variable de entorno CEREBRO_PASS.
"""

import argparse
import base64
import hashlib
import os
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

ITERACIONES = 250_000
PLANTILLA = Path(__file__).with_name("candado.html")


def morir(mensaje):
    print(f"cifrar.py: {mensaje}", file=sys.stderr)
    raise SystemExit(1)


def cifrar(claro: bytes, frase: str):
    """Devuelve (sal, cifrado). key||iv salen de PBKDF2-SHA256 sobre la frase."""
    sal = os.urandom(16)
    derivada = hashlib.pbkdf2_hmac("sha256", frase.encode("utf-8"), sal, ITERACIONES, 48)
    llave, iv = derivada[:32], derivada[32:48]

    with tempfile.TemporaryDirectory() as tmp:
        entrada = Path(tmp, "claro.bin")
        salida = Path(tmp, "cifrado.bin")
        entrada.write_bytes(claro)
        cmd = [
            "openssl", "enc", "-aes-256-cbc",
            "-K", llave.hex(), "-iv", iv.hex(),
            "-in", str(entrada), "-out", str(salida),
        ]
        try:
            proc = subprocess.run(cmd, capture_output=True)
        except FileNotFoundError:
            morir("no encontré el comando `openssl`.")
        if proc.returncode != 0:
            morir("openssl falló: " + proc.stderr.decode("utf-8", "replace").strip())
        return sal, salida.read_bytes()


def main(argv):
    parser = argparse.ArgumentParser(
        prog="cifrar.py",
        description="Envuelve un HTML en una página con candado.",
        add_help=True,
    )
    parser.add_argument("entrada", type=Path, help="el HTML a cifrar")
    parser.add_argument("salida", type=Path, help="dónde dejar la página con candado")
    parser.add_argument("--sello", default="", help="fecha visible al pie del candado")
    opciones = parser.parse_args(argv[1:])

    entrada, salida = opciones.entrada, opciones.salida
    if not entrada.is_file():
        morir(f"no existe el archivo de entrada: {entrada}")
    if not PLANTILLA.is_file():
        morir(f"falta la plantilla del candado: {PLANTILLA}")

    frase = os.environ.get("CEREBRO_PASS", "")
    if not frase:
        morir("falta la variable de entorno CEREBRO_PASS.")

    sello = opciones.sello or datetime.now().strftime("%d/%m/%Y %H:%M")

    claro = entrada.read_bytes()
    sal, cifrado = cifrar(claro, frase)

    pagina = PLANTILLA.read_text(encoding="utf-8")
    for marca, valor in (
        ("__SAL__", base64.b64encode(sal).decode()),
        ("__ITER__", str(ITERACIONES)),
        ("__HUELLA__", hashlib.sha256(claro).hexdigest()),
        ("__SELLO__", sello),
        ("__DATOS__", base64.b64encode(cifrado).decode()),
    ):
        if marca not in pagina:
            morir(f"la plantilla no tiene la marca {marca}")
        pagina = pagina.replace(marca, valor)

    salida.parent.mkdir(parents=True, exist_ok=True)
    salida.write_text(pagina, encoding="utf-8")
    print(f"cifrado: {len(claro):,} B → {salida} ({salida.stat().st_size:,} B)")


if __name__ == "__main__":
    main(sys.argv)
