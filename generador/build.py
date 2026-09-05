#!/usr/bin/env python3
"""Genera cerebro.html a partir de los dos vaults. Solo biblioteca estándar."""
import os, re, io, json, sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
HOME = Path.home()

VAULTS = {
    'tec': {
        'nombre': 'Grafo — Tec',
        'ruta': Path(os.environ.get('CEREBRO_TEC') or (HOME / 'Library/CloudStorage/OneDrive-InstitutoTecnologicoydeEstudiosSuperioresdeMonterrey/Personal/Second Brain')),
        'grupos': {
            'tecbot-academico': {'v': '--g1', 'n': 'TECbot Académico'},
            'tecgpt':           {'v': '--g2', 'n': 'TECgpt'},
            'ia-en-el-mda':     {'v': '--g3', 'n': 'IA en el MDA'},
            'herramientas-ia-tl': {'v': '--g4', 'n': 'Herramientas T&L'},
        },
    },
    'per': {
        'nombre': 'Grafo — Personal',
        'ruta': Path(os.environ.get('CEREBRO_PER') or (HOME / 'Documents/second-brain-personal')),
        'grupos': {
            'axon-labs':      {'v': '--g1', 'n': 'Axon Labs'},
            'crea':           {'v': '--g2', 'n': 'CREA'},
            'talleres-de-ia': {'v': '--g3', 'n': 'Talleres de IA'},
            'doctorado':      {'v': '--g4', 'n': 'Doctorado'},
        },
    },
}

IGNORA = {'.git', '.claude', '_stale', 'privado', 'clientes', 'node_modules', 'inbox'}
FALSOS = {'así', 'enlace', '...'}
TIPOS = {'extiende': 'extiende', 'contradice': 'contradice', 'depende_de': 'depende'}


def grafo(raiz: Path):
    meta, edges, ids = {}, [], set()
    for dp, dn, fns in os.walk(raiz):
        dn[:] = [d for d in dn if d not in IGNORA]
        for fn in fns:
            if not fn.endswith('.md'):
                continue
            p = Path(dp) / fn
            rel = p.relative_to(raiz)
            carpeta = rel.parts[0] if len(rel.parts) > 1 else 'raiz'
            nid = p.stem
            txt = p.read_text(encoding='utf-8', errors='replace')
            fm = {}
            m = re.match(r'^---\n(.*?)\n---\n', txt, re.S)
            if m:
                for linea in m.group(1).split('\n'):
                    mm = re.match(r'^(\w+):\s*(.*)$', linea)
                    if mm:
                        fm[mm.group(1)] = mm.group(2).strip().strip('"')
            meta[nid] = dict(id=nid, t=fm.get('titulo', nid), f=carpeta,
                             tipo=fm.get('tipo', ''), p=fm.get('proyecto', ''),
                             act=fm.get('actualizado', ''), len=len(txt))
            ids.add(nid)
            for tgt in set(re.findall(r'\[\[([^\]|]+)', txt)):
                edges.append([nid, tgt.strip(), 'ref'])
            for clave, etiqueta in TIPOS.items():
                mm = re.search(r'^\s*' + clave + r':\s*\[(.*?)\]', txt, re.M)
                if mm:
                    for tgt in mm.group(1).split(','):
                        tgt = tgt.strip().strip('"\'')
                        if tgt:
                            edges.append([nid, tgt, etiqueta])
    rotos = sorted({e[1] for e in edges
                    if e[1] not in ids and not e[1].startswith('#') and e[1] not in FALSOS})
    vistos, limpias = set(), []
    for e in edges:
        if e[1] in ids and tuple(e) not in vistos:
            vistos.add(tuple(e)); limpias.append(e)
    return {'nodes': list(meta.values()), 'edges': limpias,
            'rotos': rotos, 'ids': sorted(ids)}


def lee_json(ruta, defecto):
    try:
        return json.loads(Path(ruta).read_text(encoding='utf-8'))
    except Exception:
        return defecto


def main():
    datos, resumen = {}, []
    for clave, cfg in VAULTS.items():
        raiz = cfg['ruta']
        if not raiz.is_dir():
            print(f'  ! no encontré {raiz} — se omite {clave}', file=sys.stderr)
            continue
        g = grafo(raiz)
        (raiz / 'meta').mkdir(exist_ok=True)
        (raiz / 'meta' / 'graph.json').write_text(
            json.dumps(g, ensure_ascii=False), encoding='utf-8')
        panel = lee_json(raiz / 'meta' / 'alertas.json', {})
        datos[clave] = {
            'nombre': cfg['nombre'],
            'grupos': cfg['grupos'],
            'cobertura': panel.get('cobertura', [
                {'id': k, 'h': 0, 't': None} for k in cfg['grupos']]),
            'notaCob': panel.get('notaCob', 'Sin datos de cobertura todavía.'),
            'alertas': panel.get('alertas', [
                ['w', 'sin alertas', 'Corre <b>/compilar</b> para que el barrido escriba aquí lo que pide atención.']]),
            'data': g,
        }
        resumen.append(f"{clave}: {len(g['nodes'])} notas, {len(g['edges'])} relaciones"
                       + (f", {len(g['rotos'])} enlaces rotos" if g['rotos'] else ''))

    if not datos:
        print('No encontré ningún vault. Nada que generar.', file=sys.stderr)
        return 1

    plantilla = (AQUI / 'plantilla.html').read_text(encoding='utf-8')
    salida = plantilla.replace('__DATOS_CEREBROS__',
                               json.dumps(datos, ensure_ascii=False))
    destino = AQUI / 'cerebro.html'
    destino.write_text(salida, encoding='utf-8')
    print('✓ ' + str(destino))
    for r in resumen:
        print('  ' + r)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
