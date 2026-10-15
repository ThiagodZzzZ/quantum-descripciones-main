#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Recupera el diseño aprobado sobre la versión del 14/10 (97d9be4 / 7208a21), sin perder lo bueno de esa tanda.

    py tools/recuperar-diseno-1510.py            # dry: cuenta y no escribe
    py tools/recuperar-diseno-1510.py --apply    # reescribe los .html en el lugar

- CATALOGO/**/cat-<id>.html: vuelve el bloque negro + aviso de depósito (tools/rediseno-catalogo-minimos.py).
  Toma de la versión del 14/10 el título, SKU, categoría y estado (salen del catálogo actual y corrigen fichas que
  tenían el producto equivocado) y suma la marca. Lo que falte sale de la ficha anterior (BASE). Suma el alto real.
- GPUS/ y GPUS_OUTLET/: las fichas ricas de BASE (pestañas, comparador, fuente sugerida) vuelven tal cual, con
  dos datos de chip de la versión del 14/10 que no tenían (Proceso y núcleos) y el «·» de las salidas arreglado.
  Las que en BASE no eran ricas quedan como están y sólo se les suma el alto real si les falta.
- El resto (periféricos, mothers, fuentes, PCs) no se toca.
"""
import html, importlib.util, os, re, subprocess, sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = "27c4e978"  # main antes del 14/10: PR #2 (bloque negro) + PR #1 (alto real)
RICA_BYTES = 15000

spec = importlib.util.spec_from_file_location("gen", os.path.join(REPO, "tools", "rediseno-catalogo-minimos.py"))
gen = importlib.util.module_from_spec(spec); spec.loader.exec_module(gen)

# Mismas marcas que tools/restyle-all-fichas.ps1 (más largas primero para que gane "COOLER MASTER" sobre "MASTER").
MARCAS = sorted("""ASUS|ROG|MSI|GIGABYTE|AORUS|ASROCK|SAPPHIRE|POWERCOLOR|ZOTAC|PALIT|EVGA|XFX|PNY|GAINWARD|HYPERX|LOGITECH|RAZER|
REDRAGON|CORSAIR|STEELSERIES|KINGSTON|CRUCIAL|SAMSUNG|ADATA|XPG|PATRIOT|TEAMGROUP|TEAM GROUP|G.SKILL|GSKILL|ZOWIE|BENQ|
COOLER MASTER|INTEL|AMD|DEEPCOOL|THERMALTAKE|NZXT|LIAN LI|FRACTAL|PHANTEKS|AEROCOOL|SEASONIC|BE QUIET|ANTEC|TP-LINK|TPLINK|
MERCUSYS|UBIQUITI|MIKROTIK|CISCO|HP|DELL|LENOVO|EPSON|BROTHER|CANON|WESTERN DIGITAL|WD|SEAGATE|TOSHIBA|NOGA|GENIUS|PHILIPS|
JBL|SONY|ELGATO|KEYCHRON|DUCKY|PULSAR|GLORIOUS|COUGAR|HALION|ARKTEK|GAMEMAX|SENTEY|KOLINK|APC|EATON""".replace("\n", "").split("|"),
                key=len, reverse=True)
NOMBRE_MARCA = {"TPLINK": "TP-LINK", "GSKILL": "G.SKILL", "TEAM GROUP": "TEAMGROUP"}


class Base:
    """Lee blobs de BASE con un solo `git cat-file --batch` (bytes exactos, sin conversión de fin de línea)."""
    def __init__(self):
        self.p = subprocess.Popen(["git", "-C", REPO, "cat-file", "--batch"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    def leer(self, ruta):
        self.p.stdin.write(("%s:%s\n" % (BASE, ruta)).encode()); self.p.stdin.flush()
        cab = self.p.stdout.readline().split()
        if cab[-1] == b"missing":
            return None
        b = self.p.stdout.read(int(cab[2])); self.p.stdout.read(1)
        return b


def texto(s):
    """La versión del 14/10 trae acentos con doble escape ('c&amp;#195;&amp;#161;mara')."""
    for _ in range(3):
        s = html.unescape(s)
    return gen.arreglar_mojibake(s).replace(" ", " ").strip()


def marca_de(titulo, categ=""):
    """AMD e Intel sólo cuentan como marca en procesadores: en notebooks y PCs nombran el procesador, no al fabricante."""
    palabras = titulo.upper().split()[:5]
    inicio = " ".join(palabras)
    mejor = None
    for m in MARCAS:
        x = re.search(r"(?<![A-Z0-9])%s(?![A-Z0-9])" % re.escape(m), inicio)
        if x and (mejor is None or x.start() < mejor[0]):
            mejor = (x.start(), m)
    if not mejor or (mejor[1] in ("AMD", "INTEL") and "PROCESADOR" not in categ.upper()):
        return ""
    return NOMBRE_MARCA.get(mejor[1], mejor[1])


def datos_thiago(t):
    sv = lambda n: (lambda m: texto(m.group(1)) if m else "")(  # noqa: E731
        re.search(r'spec-name">%s</div><div class="spec-value">(.*?)</div>' % re.escape(n), t, re.S))
    tit = re.search(r"<title>(.*?) - Quantum Hardstore</title>", t, re.S)
    sub = re.search(r'class="subtitle">(.*?)</div>', t, re.S)
    est = texto(sub.group(1)).split(" / ")[-1] if sub else ""
    return dict(title=texto(tit.group(1)) if tit else "", sku=sv("SKU"), categ=sv("Categoria Odoo"),
                estado=est if est in ("Nuevo", "Outlet") else "")


def catalogo(base, apply):
    n = cambia_titulo = con_marca = 0
    for d_, _, fs in os.walk(os.path.join(REPO, "CATALOGO")):
        for f in sorted(fs):
            m = re.match(r"cat-(\d+)\.html$", f)
            if not m:
                continue
            p = os.path.join(d_, f); rel = os.path.relpath(p, REPO).replace(os.sep, "/")
            actual = open(p, encoding="utf-8", errors="replace").read()
            if 'name="qh-odoo-id"' in actual:  # quedó con el bloque negro
                d = gen.leer(p)
            else:
                b = base.leer(rel)
                viejo = b.decode("utf-8", "replace") if b else ""
                g = lambda k: gen._g(r'<meta name="qh-%s" content="(.*?)">' % k, viejo)  # noqa: E731
                nuevo = datos_thiago(actual)
                d = dict(title=nuevo["title"] or g("title"), sku=nuevo["sku"] or g("sku"),
                         categ=nuevo["categ"] or g("categ"), estado=nuevo["estado"] or g("estado") or "Nuevo")
                cambia_titulo += d["title"] != g("title")
            if not d or not d["title"]:
                continue
            d["marca"] = d.get("marca") or marca_de(d["title"], d["categ"])
            con_marca += bool(d["marca"])
            out, _ = gen.render(int(m.group(1)), d)
            n += 1
            if apply:
                with open(p, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(out)
    print("CATALOGO: %d fichas con bloque negro · %d con el título del 14/10 · %d con marca%s"
          % (n, cambia_titulo, con_marca, "" if apply else " (dry)"))


def filas_chip(actual):
    """Proceso y núcleos de la versión del 14/10, como filas de la ficha rica."""
    r = []
    for n in ("Proceso", "CUDA Cores", "Stream Processors", "Núcleos", "Nucleos"):
        m = re.search(r'spec-name">%s</div><div class="spec-value">(.*?)</div>' % n, actual)
        if m:
            r.append(("Núcleos" if n != "Proceso" else "Proceso", texto(m.group(1))))
    return r


def gpus(base, apply):
    ricas = sumadas = alto = 0
    for carpeta in ("GPUS", "GPUS_OUTLET"):
        for f in sorted(os.listdir(os.path.join(REPO, carpeta))):
            if not f.endswith(".html"):
                continue
            p = os.path.join(REPO, carpeta, f); rel = "%s/%s" % (carpeta, f)
            actual = open(p, encoding="utf-8", errors="replace").read()
            b = base.leer(rel)
            if b and len(b) > RICA_BYTES:
                out = b.decode("utf-8")
                out = out.replace("&#194;&#183;", "·")
                filas = [(k, v) for k, v in filas_chip(actual) if '<span class="n">%s</span>' % k not in out]
                ancla = re.search(r'( *)<div class="spec-row"><span class="n">Arquitectura</span>.*?</div>\n', out)
                if filas and ancla:
                    extra = "".join('%s<div class="spec-row"><span class="n">%s</span><span class="x">%s</span></div>\n'
                                    % (ancla.group(1), html.escape(k), html.escape(v)) for k, v in filas)
                    out = out[:ancla.end()] + extra + out[ancla.end():]
                    sumadas += 1
                ricas += 1
            elif 'data-qh="alto-real"' not in actual:
                out = actual.replace("</body>", gen.ALTO_REAL + "\n</body>", 1); alto += 1
            else:
                continue
            if apply:
                with open(p, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(out)
    print("GPUS: %d fichas ricas recuperadas (%d con Proceso/Núcleos sumados) · %d no ricas con alto real sumado%s"
          % (ricas, sumadas, alto, "" if "--apply" in sys.argv else " (dry)"))


if __name__ == "__main__":
    apply = "--apply" in sys.argv
    base = Base()
    catalogo(base, apply)
    gpus(base, apply)
