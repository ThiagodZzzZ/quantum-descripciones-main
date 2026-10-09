#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rediseño de las fichas mínimas de CATALOGO (cat-<OdooId>.html): bloque negro con los datos clave,
aviso de depósito (tres pasos en escritorio, pie pegado en celular) y ficha técnica en tabla.

    py tools/rediseno-catalogo-minimos.py                 # dry: cuenta y no escribe
    py tools/rediseno-catalogo-minimos.py --muestra 5     # dry + 5 fichas por categoría con lo extraído
    py tools/rediseno-catalogo-minimos.py --apply         # reescribe los .html en el lugar
    py tools/rediseno-catalogo-minimos.py --apply --ids 10494,10495

No cambia rutas ni nombres de archivo: los iframes cargados en Odoo siguen sirviendo.
Sólo usa datos que están en el título / SKU / categoría de la ficha existente; lo que no se
reconoce con certeza no se muestra. Las fichas ya convertidas se pueden volver a generar
(guardan título, SKU, categoría y estado en <meta name="qh-*">).
El diseño vive en /quantum-ficha.css (un solo archivo para todas).
"""
import collections, html, os, random, re, sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSS_VERSION = "20261009"

# ───────────────────────── lectura de la ficha existente ─────────────────────────

def _g(rx, t):
    m = re.search(rx, t, re.S)
    return html.unescape(m.group(1)).strip() if m else ""


def arreglar_mojibake(s):
    """'MultifunciÃ³n' -> 'Multifunción' (texto UTF-8 leído como cp1252 en la generación original)."""
    for _ in range(3):  # hay títulos con dos vueltas de daño
        if not re.search(r"[ÃÂâ]", s):
            break
        try:
            crudo = b"".join(c.encode("cp1252") if c.encode("cp1252", "ignore") else bytes([ord(c)]) for c in s)
            s = crudo.decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError, ValueError):
            break
    return s.replace(" ", " ").replace("”", '"').replace("“", '"')


def leer(path):
    t = open(path, encoding="utf-8", errors="replace").read()
    if 'name="qh-odoo-id"' in t:  # ya convertida
        m = lambda n: _g(r'<meta name="qh-%s" content="(.*?)">' % n, t)  # noqa: E731
        return dict(title=m("title"), sku=m("sku"), categ=m("categ"), estado=m("estado"))
    if "Ficha tecnica minima" not in t:
        return None
    return dict(
        title=arreglar_mojibake(_g(r"<title>(.*?) - Quantum Hardstore</title>", t)),
        sku=arreglar_mojibake(_g(r'SKU</div><div class="spec-value">(.*?)</div>', t)),
        categ=arreglar_mojibake(_g(r'Categoria Odoo</div><div class="spec-value">(.*?)</div>', t)),
        estado=_g(r'Estado</div><div class="spec-value">(.*?)</div>', t) or "Nuevo",
    )

# ───────────────────────── datos clave desde el título ─────────────────────────

RAM_OK = {1, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 96, 128}
DISCO_GB_OK = {120, 128, 240, 250, 256, 480, 500, 512, 960, 1000}


def _num(s):
    return s.replace(",", ".").rstrip("0").rstrip(".") if "." in s.replace(",", ".") else s


def _color(T):
    n = bool(re.search(r"\b(NEGRO|BLACK)\b", T)); b = bool(re.search(r"\b(BLANCO|WHITE)\b", T))
    return "Negro" if n and not b else "Blanco" if b and not n else ""


def _cpu(T):
    m = re.search(r"RYZEN\s+(AI\s+)?([3579])\s+(PRO\s+)?(\d{3,4}[A-Z0-9]{0,4})\b", T)
    if m:
        return "AMD Ryzen %s%s %s%s" % ("AI " if m.group(1) else "", m.group(2), "PRO " if m.group(3) else "", m.group(4))
    m = re.search(r"\bR([3579])[\s-](\d{4}[A-Z]{0,2})\b", T)
    if m:
        return "AMD Ryzen %s %s" % m.groups()
    m = re.search(r"ULTRA\s?-?([579])[\s-]?(\d{3}[A-Z]{0,2})\b", T)
    if m:
        return "Intel Core Ultra %s %s" % m.groups()
    m = re.search(r"\bI([3579])[\s-]?(\d{4,5}[A-Z]{0,2})\b", T)
    if m:
        return "Intel Core i%s-%s" % m.groups()
    m = re.search(r"\b(CELERON|PENTIUM|ATHLON)\s+(?:GOLD\s+|SILVER\s+)?([A-Z]?\d{3,5}[A-Z]{0,2})\b", T)
    if m:
        return "%s %s %s" % ("AMD" if m.group(1) == "ATHLON" else "Intel", m.group(1).capitalize(), m.group(2))
    return ""


def _so(T):
    m = re.search(r"\b(?:WINDOWS|WIN|W)\s?-?(1[01])\s?(PRO|HOME)?\b", T)
    if m:
        return "Windows %s%s" % (m.group(1), " " + m.group(2).capitalize() if m.group(2) else "")
    if re.search(r"SIN (SO|WINDOWS|SISTEMA)|FREE ?DOS", T):
        return "Sin sistema operativo"
    return ""


def ex_memoria(T):
    if not re.search(r"DDR[2345]", T):
        return []
    r = []
    m = re.search(r"(?<![\dX])(\d{1,3})\s?(?:GB|G)(?![A-Z])", T)
    if m and int(m.group(1)) in RAM_OK:
        k = re.search(r"\b([24])\s?X\s?(\d{1,2})\s?GB", T)
        r.append(("Capacidad", "%s GB" % m.group(1) + (" (%s x %s GB)" % k.groups() if k and int(k.group(1)) * int(k.group(2)) == int(m.group(1)) else "")))
    r.append(("Tipo", re.search(r"DDR[2345]", T).group(0)))
    m = re.search(r"(\d{4})\s?MHZ", T) or re.search(r"DDR[45][\s-]+(\d{4})\b", T)
    if m and 1333 <= int(m.group(1)) <= 9000:
        r.append(("Frecuencia", "%s MHz" % m.group(1)))
    if re.search(r"SO-?DIMM", T):
        r.append(("Formato", "SODIMM (notebook)"))
    elif re.search(r"\bUDIMM\b", T):
        r.append(("Formato", "UDIMM (PC de escritorio)"))
    return r


def ex_almacenamiento(T, categ):
    if "NAS" in categ.upper().split(" / ")[-1]:
        return []
    r = []
    if re.search(r"ADAPTADOR|LECTOR|CARRY|GABINETE|CABLE|DOCK", T):
        return []
    S = re.sub(r"\b(SATA|SAS)\s?(III\s)?\d{1,2}\s?GB(/S|PS)?", r"\1", T)  # "SATA 6Gb/s" no es capacidad
    m = re.search(r"(?<![\d.,])(\d{1,4}(?:[.,]\d{1,2})?)\s?(TB|GB)(?![A-Z/])", S)
    if not m:
        return []
    r.append(("Capacidad", "%s %s" % (_num(m.group(1)), m.group(2))))
    if re.search(r"PEN\s?DRIVE", T):
        tipo = "Pendrive"
    elif re.search(r"MICRO\s?SD|TARJETA DE MEMORIA|\bSD[HX]C\b", T):
        tipo = "Tarjeta de memoria"
    elif "EXTERNO" in T or "PORTABLE" in T:
        tipo = "Disco externo"
    elif re.search(r"NVME|\bM\.?2\b", T):
        tipo = "SSD M.2"
    elif re.search(r"\bSSD\b|SOLIDO|SÓLIDO", T):
        tipo = "SSD"
    elif re.search(r"\bHDD\b|DISCO DURO|RPM\b|DISCO R[IÍ]GIDO", T):
        tipo = "Disco rígido (HDD)"
    else:
        tipo = ""
    if tipo:
        r.append(("Tipo", tipo))
    if "NVME" in T:
        m = re.search(r"PCIE\s?(?:GEN\s?)?(\d)(?:\.0)?", T)
        r.append(("Interfaz", "NVMe PCIe %s.0" % m.group(1) if m else "NVMe"))
    elif re.search(r"S-?ATA", T):
        r.append(("Interfaz", "SATA"))
    elif tipo == "Pendrive":
        m = re.search(r"USB\s?(\d\.\d)", T)
        if m:
            r.append(("Interfaz", "USB %s" % m.group(1)))
    m = re.search(r"(\d{4,5})\s?RPM", T)
    if m:
        r.append(("Velocidad", "%s rpm" % m.group(1)))
    return r


def ex_notebook(T):
    if not re.search(r"NOTEBOOK|LAPTOP|ULTRABOOK|MACBOOK", T):
        return []
    r = []
    cpu = _cpu(re.sub(r"\b\d{3}\s+G\d{1,2}\b", " ", T))  # "HP 245 G10" es el modelo del equipo, no el procesador
    # en notebooks un modelo de 4-5 cifras sin letra final (i3-1215, R5-8640) es un título recortado: no se muestra
    if cpu and not re.search(r"[ -]\d{4,5}$", cpu):
        r.append(("Procesador", cpu))
    S = re.sub(r"\b(RTX|GTX|RX|ARC)\s?-?[A-Z]?\d{3,4}\s?(TI|SUPER|XT)?\s+\d{1,2}\s?GB?", " ", T)  # VRAM fuera
    caps = [(int(float(a.replace(",", "."))), u) for a, u in re.findall(r"(?<![\d.,+X])(\d{1,4})\s?(TB|GB|G)(?![A-Z])", S)]
    ram_i = next((i for i, (v, u) in enumerate(caps) if u != "TB" and v in RAM_OK), None)
    if ram_i is not None:
        r.append(("Memoria", "%d GB" % caps[ram_i][0]))
        for v, u in caps[ram_i + 1:]:
            if u == "TB" and v <= 4:
                r.append(("Almacenamiento", "%d TB" % v)); break
            if u != "TB" and v in DISCO_GB_OK:
                r.append(("Almacenamiento", "%d GB" % v)); break
    m = re.search(r"(?<![\d.,])(1[0-8](?:[.,]\d)?)\s?(?:\"|”|''|PULG)", T) or \
        re.search(r"(?<![\d.,])(1[0-8][.,]\d)(?=\s*(?:FHD|HD|WUXGA|OLED|IPS|LED|2K|2\.8K|3K|TOUCH)\b)", T) or \
        re.search(r"(?<![A-Z\d.,-])(1[3-8])(?=\s+(?:FHD|WUXGA|OLED|2K|2\.8K)\b)", T)
    if m:
        r.append(("Pantalla", '%s"' % _num(m.group(1))))
    so = _so(T)
    if so:
        r.append(("Sistema operativo", so))
    return r


def ex_procesador(T):
    if re.search(r"\bPC\b|NOTEBOOK|\bAIO\b|MOTHER|\bKIT\b|COMBO", T):
        return []
    r = []
    m = re.search(r"RYZEN\s+([3579])\s+(PRO\s+)?(\d{4}[A-Z0-9]{0,4})\b", T)
    if m:
        r.append(("Modelo", "AMD Ryzen %s %s%s" % (m.group(1), "PRO " if m.group(2) else "", m.group(3))))
    else:
        m = re.search(r"CORE\s+ULTRA\s+([579])\s+(\d{3}[A-Z]{0,2})\b", T)
        if m:
            r.append(("Modelo", "Intel Core Ultra %s %s" % m.groups()))
        else:
            m = re.search(r"CORE\s+I([3579])[\s-]?(\d{4,5}[A-Z]{0,2})\b", T)
            if m:
                r.append(("Modelo", "Intel Core i%s-%s" % m.groups()))
            else:
                cpu = _cpu(T) if re.search(r"CELERON|PENTIUM|ATHLON", T) else ""
                if cpu:
                    r.append(("Modelo", cpu))
    if not r:
        return []
    m = re.search(r"\b(AM[45])\b", T)
    if m:
        r.append(("Socket", m.group(1)))
    else:
        m = re.search(r"\b(?:LGA\s?|S)(1[1278]\d\d)\b", T)
        if m:
            r.append(("Socket", "LGA %s" % m.group(1)))
    m = re.search(r"\((\d{1,2})\s?CORE\)", T)
    if m:
        r.append(("Núcleos", m.group(1)))
    if re.search(r"\b(SIN|S/)\s?VIDEO", T):
        r.append(("Gráficos integrados", "No"))
    elif re.search(r"\b(CON|C/)\s?VIDEO", T):
        r.append(("Gráficos integrados", "Sí"))
    if re.search(r"\b(SIN|S/)\s?COOLER", T):
        r.append(("Cooler", "No incluido"))
    elif re.search(r"\b(CON|C/)\s?COOLER", T):
        r.append(("Cooler", "Incluido"))
    return r


def ex_monitor(T):
    if "MONITOR" not in T or re.search(r"SOPORTE|BRAZO|CABLE|\bKIT\b|ADAPTADOR", T):
        return []
    r = []
    m = re.search(r"(?<![\d.,])(\d{2}(?:[.,]\d)?)\s?(?:\"|”|''|PULG)", T) or \
        re.search(r"(?<![\w.,/-])(\d{2}(?:[.,]\d)?)(?![\w.,/-])(?!\s?(?:HZ|MS|W|MM|CM|X)\b)", T)
    if m and 17 <= float(m.group(1).replace(",", ".")) <= 57:
        r.append(("Tamaño", '%s"' % _num(m.group(1))))
    if re.search(r"\b(4K|UHD)\b", T):
        r.append(("Resolución", "4K UHD"))
    elif re.search(r"\bUWQHD\b", T):
        r.append(("Resolución", "UWQHD"))
    elif re.search(r"\b(W?QHD|2K)\b", T):
        r.append(("Resolución", "QHD"))
    elif re.search(r"\b(FHD|FULL\s?HD)\b", T):
        r.append(("Resolución", "Full HD"))
    m = re.search(r"(?<!\d)(\d{2,3})\s?HZ\b", T)
    if m and 50 <= int(m.group(1)) <= 600:
        r.append(("Frecuencia", "%s Hz" % m.group(1)))
    m = re.search(r"\b(QD-OLED|OLED|IPS|VA)\b", T)
    if m:
        r.append(("Panel", m.group(1)))
    if re.search(r"\bCURV[OE]D?\b", T):
        r.append(("Formato", "Curvo"))
    return r


def ex_gabinete(T):
    if "GABINETE" not in T or re.search(r"\bKIT\b|COMBO", T):
        return []
    r = []
    m = re.search(r"\b(MID|FULL|MINI|MICRO)[\s-]?TOWER", T)
    if m:
        r.append(("Formato", "%s Tower" % m.group(1).capitalize()))
    if re.search(r"\b(S/|SIN )\s?FUENTE", T):
        r.append(("Fuente", "No incluida"))
    m = re.search(r"\bFAN\s?X\s?(\d)\b", T)
    if m:
        r.append(("Ventiladores incluidos", m.group(1)))
    if re.search(r"\bARGB\b", T):
        r.append(("Iluminación", "ARGB"))
    elif re.search(r"\bRGB\b", T):
        r.append(("Iluminación", "RGB"))
    c = _color(T)
    if c:
        r.append(("Color", c))
    return r


def ex_energia(T):
    if not re.search(r"\bUPS\b|ESTABILIZADOR", T):
        return []
    r = []
    m = re.search(r"(?<!\d)(\d{3,5})\s?VA\b", T)
    if m:
        r.append(("Potencia aparente", "%s VA" % m.group(1)))
    m = re.search(r"(?<!\d)(\d{3,5})\s?W\b", T)
    if m:
        r.append(("Potencia", "%s W" % m.group(1)))
    if "ONLINE" in T or "ON LINE" in T:
        r.append(("Tecnología", "Online"))
    return r


def ex_refrigeracion(T):
    if re.search(r"\bKIT\b.*\+|COMBO|PASTA", T):
        return []
    r = []
    if re.search(r"WATER|LIQUID|\bAIO\b", T):
        r.append(("Tipo", "Refrigeración líquida"))
        m = re.search(r"(?<![\dA-Z])(120|240|280|360|420)(?:\s?MM)?(?![\dW])", T)
        if m:
            r.append(("Radiador", "%s mm" % m.group(1)))
    if re.search(r"\bARGB\b", T):
        r.append(("Iluminación", "ARGB"))
    elif re.search(r"\bRGB\b", T):
        r.append(("Iluminación", "RGB"))
    c = _color(T)
    if c:
        r.append(("Color", c))
    return r


def datos_clave(title, categ):
    T = re.sub(r"\s+", " ", title.upper())
    C = categ.upper()
    if "MEMORIAS" in C:
        return ex_memoria(T)
    if "ALMACENAMIENTO" in C:
        return ex_almacenamiento(T, categ)
    if "NOTEBOOKS" in C:
        return ex_notebook(T)
    if "PROCESADORES" in C:
        return ex_procesador(T)
    if "MONITORES" in C:
        return ex_monitor(T)
    if "GABINETES" in C:
        return ex_gabinete(T)
    if C.startswith("ENERG"):
        return ex_energia(T)
    if "REFRIGERACI" in C:
        return ex_refrigeracion(T)
    return []


CATEG_FIX = {"Wather Cooler": "Water cooler", "SDD": "SSD", "Escáners": "Escáneres"}


def categoria_visible(categ):
    if not categ or re.search(r"sin categor|Pendiente Mapping|^Goods", categ, re.I):
        return ""
    partes = [p.strip() for p in categ.split(" / ")]
    ult = CATEG_FIX.get(partes[-1], partes[-1])
    if ult in ("AMD", "Intel", "NVIDIA", "Otros", "Varios") and len(partes) > 1:
        return "%s %s" % (partes[-2], ult) if ult not in ("Otros", "Varios") else partes[-2]
    return ult

# ───────────────────────── HTML ─────────────────────────

E = lambda s: html.escape(s, quote=True)  # noqa: E731

PLANTILLA = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} - Quantum Hardstore</title>
<meta name="qh-odoo-id" content="{id}">
<meta name="qh-title" content="{title}">
<meta name="qh-sku" content="{sku}">
<meta name="qh-categ" content="{categ}">
<meta name="qh-estado" content="{estado}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@500;600;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../../quantum-ficha.css?v={v}">
</head>
<body>
<div class="qd">
  <div class="qd-key{cls}">
{key}
  </div>
{aviso}{tabla}
  <p class="qd-note">* Datos del título y número de parte. Especificaciones completas: hoja oficial del fabricante.</p>
</div>
</body>
</html>
"""

AVISO_DEPOSITO = """  <div class="qd-pie"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 8l9-5 9 5v8l-9 5-9-5z"/><path d="M3 8l9 5 9-5M12 13v8"/></svg><p><b>En depósito.</b> Llega al local 48 a 72 horas hábiles después del pago; ahí coordinamos envío o retiro.</p></div>
  <div class="qd-pasos"><div><b>Pagás</b><span>Lo pedimos al depósito</span></div><div><b>Llega al local</b><span>48 a 72 horas hábiles</span></div><div><b>Envío o retiro</b><span>Lo coordinamos con vos</span></div></div>
"""
AVISO_OUTLET = """  <div class="qd-pie qd-pie--fijo"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3l8 4v5c0 4.5-3.2 8-8 9-4.8-1-8-4.5-8-9V7z"/><path d="M9 12l2 2 4-4"/></svg><p><b>Producto outlet.</b> Unidad outlet revisada. Consultá stock antes de abonar.</p></div>
"""


def render(odoo_id, d):
    outlet = d["estado"].lower() == "outlet"
    clave = datos_clave(d["title"], d["categ"])
    cat = categoria_visible(d["categ"])
    base = ([("Categoría", cat)] if cat else []) + ([("Número de parte", d["sku"])] if d["sku"] else [])
    cond = [("Condición", "Outlet" if outlet else "Nuevo")]
    if len(clave) >= 2:
        key, tabla_filas = clave[:4], base + clave + cond
    else:
        clave = []  # un dato suelto no alcanza: no se muestra
        key = (base + cond) if base else ([("Producto", d["title"])] + cond)
        tabla_filas = []
    key_html = "\n".join("    <div><span>%s</span><b>%s</b></div>" % (E(k), E(v)) for k, v in key)
    tabla = ""
    if tabla_filas:
        tabla = '\n  <h2 class="qd-h">Ficha técnica</h2>\n  <table class="qd-t">\n%s\n  </table>\n' % "\n".join(
            "    <tr><th>%s</th><td>%s</td></tr>" % (E(k), E(v)) for k, v in tabla_filas)
    return PLANTILLA.format(id=odoo_id, title=E(d["title"]), sku=E(d["sku"]), categ=E(d["categ"]), estado=E(d["estado"]),
                            v=CSS_VERSION, cls=" qd-key--outlet" if outlet else "", key=key_html,
                            aviso=AVISO_OUTLET if outlet else AVISO_DEPOSITO, tabla=tabla), clave


def main():
    apply = "--apply" in sys.argv
    muestra = int(sys.argv[sys.argv.index("--muestra") + 1]) if "--muestra" in sys.argv else 0
    ids = set(int(x) for x in sys.argv[sys.argv.index("--ids") + 1].split(",")) if "--ids" in sys.argv else None
    n = esc = 0
    con_clave = collections.Counter(); total = collections.Counter(); ejemplos = collections.defaultdict(list)
    for d_, _, fs in os.walk(os.path.join(REPO, "CATALOGO")):
        for f in sorted(fs):
            m = re.match(r"cat-(\d+)\.html$", f)
            if not m or (ids and int(m.group(1)) not in ids):
                continue
            p = os.path.join(d_, f)
            d = leer(p)
            if not d or not d["title"]:
                continue
            out, clave = render(int(m.group(1)), d)
            n += 1; total[d["categ"]] += 1; con_clave[d["categ"]] += len(clave) >= 2
            ejemplos[d["categ"]].append((d["title"], clave))
            if apply:
                with open(p, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(out)
                esc += 1
    print("fichas mínimas: %d · escritas: %d%s" % (n, esc, "" if apply else " (dry)"))
    print("con datos clave extraídos (>=2):", sum(con_clave.values()))
    for c, t in total.most_common():
        print("  %4d/%-4d %s" % (con_clave[c], t, c))
    if muestra:
        random.seed(11)
        for c, _ in total.most_common():
            print("##", c)
            for t, k in random.sample(ejemplos[c], min(muestra, len(ejemplos[c]))):
                print("   ", t[:110]); print("       ->", " | ".join("%s: %s" % kv for kv in k) or "(sin extracción)")


if __name__ == "__main__":
    main()
