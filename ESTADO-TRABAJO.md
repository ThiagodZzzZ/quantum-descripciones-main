# Estado del trabajo — Quantum Descripciones (jul 2026)

Documento de progreso del plan “Descripciones 100% catálogo”. Complementa `AGENTS.md` y `AUTOMATION.md`.

## Objetivo

Todo producto comercial `sale_ok` con `qh_tn_description_raw` (iframe HTML + `quantum-theme-switch.js`).  
**Nunca publicar en Odoo sin OK explícito.** Siempre `-DryRun` primero.

## Auditoría Odoo (jul 2026)

Tras `tools/audit-odoo-coverage.ps1` / worklists:

| Métrica | Valor aprox. |
|---------|-------------:|
| `sale_ok` activos | ~5848 |
| Con descripción | ~1609 |
| Sin descripción | ~4239 |
| Comerciales faltantes (sin basura) | ~4222 |

Worklists:

- `audits/missing-perifericos.json` (~1607)
- `audits/missing-all-by-categ.json`
- `audits/odoo-coverage.json`

## Enfoque: ficha técnica mínima Quantum

No inventar specs de marketing. Contenido desde título/SKU (+ disclaimer). Layout con theme global:

```text
https://thiagodzzzz.github.io/quantum-descripciones-main/quantum-theme-switch.js?v=20260728quantum
```

## Periféricos

### Scripts / carpetas

| Path | Rol |
|------|-----|
| `tools/generate-perifericos-minimos.ps1` | Genera HTML + manifests |
| `PERIFERICOS/{mouse,teclados,auriculares,...}/perif-{id}.html` | Fichas |
| `perifericos_full_manifest.json` | Manifest global |
| `perifericos_{folder}_manifest.json` | Por subcategoría |

### Estado

- **~1607** HTML generados (Mouse 435 · Auriculares 318 · Teclados 293 · Accesorios · Parlantes · etc.)
- Muestra Mouse: `PERIFERICOS/mouse/perif-1285.html` (ZOWIE GEAR S2)
- Marcas: lista extendida (ZOWIE, etc.) + skip de tokens genéricos (GAMER, MOUSE…)
- Serialización JSON: item-a-item (evita fallo `ConvertTo-Json` en PS 5.1 con listas grandes)

### Preview local

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\serve-descriptions-preview.ps1
# ej. http://127.0.0.1:8796/PERIFERICOS/mouse/perif-1285.html
```

## Resto del catálogo (mínimos)

| Path | Rol |
|------|-----|
| `tools/generate-catalogo-minimos.ps1` | HTML mínimos no-periféricos |
| `CATALOGO/{componentes,redes,oficina,energia,...}/cat-{id}.html` | Fichas |
| `catalogo_minimos_manifest.json` | Manifest |

### Estado

- **~2615** HTML generados (Componentes ~1410 · Redes 514 · Oficina 303 · Energía 136 · Display · Hardware · Audio · sin-categoría)
- Slug de categorías con normalización de acentos (`energia`, no `energ-a`)

## Publicación Odoo

Script: `tools/apply-odoo-iframes.ps1`

- Escribe por **OdooId** (no por título) → evita colisiones de nombres duplicados
- Campo: `qh_tn_description_raw`
- Dry-run verificado OK sobre muestras (periféricos + catálogo + id 1285)
- **Publicación real: pendiente de OK del usuario**
- Requisito previo: push a GitHub Pages para que los iframes resuelvan en producción

Ejemplo dry-run:

```powershell
$env:ODOO_URL='https://odoo.quantumhardstore.com'
$env:ODOO_DB='QuantumHard'
$env:ODOO_USER='...'
$env:ODOO_PASS='...'
.\tools\apply-odoo-iframes.ps1 -ManifestGlob 'perifericos_full_manifest.json' -OnlyMatched -DryRun -Limit 25
.\tools\apply-odoo-iframes.ps1 -ManifestGlob 'catalogo_minimos_manifest.json' -OnlyMatched -DryRun -Limit 25
```

## Fixes técnicos relevantes

1. `ConvertTo-Json` masivo en PS 5.1 → escribir array JSON pieza a pieza
2. Splat `@()` en `Invoke-XmlRpc` aplanaba kwargs → usar `List[object]` (auth/search/write)
3. Encoding UTF-8 sin BOM en HTML (`WriteAllText`)
4. Branding: no tomar “GAMER” como marca

## Lote GPUs nuevas (2026-08-08)

- Auditoría Odoo: **57** en categoría Placas de video sin `qh_tn_description_raw` (12 son junk mal categorizados: fuentes/fans/pasta/E2E).
- **45 placas reales** regeneradas con `generate-gpu-descriptions.ps1` (424/425 del catálogo limpio con specs de chip).
- Corregida ficha rota `gpu-11134` (antes “RTX 8201” incompleta → RTX 5060 Ti WINDFORCE).
- Worklist: `audits/gpus-missing-desc-20260808.json`
- Manifest lote: `audits/gpu_manifest_nuevas_20260808.json`
- Preview local: `http://127.0.0.1:8796/preview-gpus-nuevas-20260808.html`
- **Pendiente:** push GitHub Pages + apply Odoo (DryRun → OK usuario) solo el lote de 45.

## Lote artículos nuevos (2026-08-18)

Auditoría: productos `sale_ok` creados desde 2026-08-01 sin `qh_tn_description_raw` → **737**.

| Lote | Cant. | Generador |
|------|------:|-----------|
| GPU (chip match) | 43 | `generate-gpu-descriptions.ps1` |
| Motherboards | 58 | `generate-mb-descriptions.ps1` |
| Fuentes | 28 | `generate-psu-descriptions.ps1` |
| PCs armadas | 8 | `generate-pc-gamer-descriptions.ps1` |
| Periféricos mínimos | 226 | `generate-perifericos-minimos.ps1` |
| Catálogo mínimos | 374 | `generate-catalogo-minimos.ps1` |
| **Total** | **737** | |

Manifest combinado: `audits/nuevos_all_manifest_20260818.json`  
Theme: `?v=20260818quantum`

**Pendiente:** push GitHub Pages + `apply-odoo-iframes.ps1 -ManifestGlob 'audits/nuevos_all_manifest_20260818.json' -OnlyMatched` (**solo con OK**).

## Pendiente

1. OK de diseño de muestra Mouse (y/o otras subcategorías) si se quiere formalizar el flujo skill
2. Push GitHub Pages con `PERIFERICOS/` + `CATALOGO/` + **GPUs nuevas 2026-08-08**
3. Publicar iframes en Odoo **solo con confirmación**
4. Re-auditoría: `audit-odoo-coverage.ps1` + `audit-public-descriptions.ps1`
5. Imágenes: trabajo urgente paralelo en repo hermano (ver su `ESTADO-TRABAJO.md`)

## Generadores maduros previos (no reemplazar)

Siguen vigentes para GPU/PSU/MB/PC/WS: `tools/generate-*-descriptions.ps1`. No rehacer fichas que ya tienen `quantum-theme-switch.js`.

## GPUs nuevas (ago 2026)

Generadas **15** fichas con `tools/generate-gpu-descriptions.ps1` (template GPU + `gpu-specs-db.json`).

- Worklist: `audits/gpus-nuevas-worklist.json`
- Manifest lote: `gpu_nuevas_manifest.json` (mergeado en `gpu_manifest.json`)
- Archivos: `GPUS/gpu-{id}.html` (ids 11200, 11265, 11269, 11270, 11271, 11289, 11294, 11439, 11457, 11549, 11557, 11604, 11619, 11621, 11700)
- Chips: RTX 5050/5060/5060 Ti/5070 Ti, RX 9070, RTX 3060 Ti outlet, RTX 3080 12GB, RX 6900 XT
- **Pendiente:** push GitHub Pages + `apply-odoo-iframes.ps1` sin DryRun (OK usuario)


## Lote GPU v2 nuevas (2026-08-24)

Template aprobado: `GPUS/gpu-10215.html` (GIGABYTE RTX 3070 Ti GAMING OC).

- Worklist: `audits/gpus-missing-worklist-20260824.json` (59 en categoria Placas; 7 junk + 5 sin chip omitidos)
- Generadas + publicadas Odoo: **47** fichas v2 (Specs / Comparar / Fuente)
- Manifest: `audits/gpu_v2_nuevas_20260824_manifest.json`
- Theme: `?v=20260824gpuv2`
- Generador: `tools/generate-gpu-v2.ps1`
- Push Pages: commit `0bea7ae`
- Omitidos: RX 9050 (chip inexistente), GT 210, pastas termicas, fans, E2E, workstation HP

## Catalogo completo Placas de video v2 (2026-08-24)

Categoria Odoo/web: Placas de video (~470 productos).

| Resultado | Cant. |
|-----------|------:|
| Generadas + Odoo UPDATED | **451** |
| Junk omitidos | 17 |
| Sin chip (RX 9050, GT 210) | 2 |

- Manifest: `audits/gpu_v2_all_20260824_manifest.json`
- Theme: `?v=20260824gpuvall`
- Push: commit `f758ff7`
- Template: mismo que muestra GIGABYTE RTX 3070 Ti GAMING OC (`gpu-10215`)

## Auditoría completa y lote nuevo (2026-09-03)

- Auditoría Odoo: **6.834** productos `sale_ok`; **5.095** sin `qh_tn_description_raw`.
- Ya había HTML local para **4.685** de esos faltantes; se preservaron y no se regeneraron.
- Se crearon **396** fichas nuevas y se validaron sus IDs, rutas HTML y `quantum-theme-switch.js`.
- Manifest combinado: `audits/missing-20260903-all-manifest.json`.
- Desglose: GPU 13, motherboards 14, fuentes 18, PCs 46, periféricos 130 y catálogo 175.
- Excluidos de publicación automática: 9 registros internos `Goods / Pendiente Mapping Supplier Sync`, 4 entradas basura en placas de video y 1 GPU RX 9050 sin chip verificable en la base oficial.
- Pendiente: push a GitHub Pages y dry-run de Odoo; publicar solo con confirmación manual.

## Cierre de cobertura local (2026-09-08)

- Auditoría Odoo: **7.034** productos `sale_ok`; **5.295** sin iframe en Odoo.
- Comparación final contra los HTML locales: **0** productos faltantes.
- Lote nuevo: **214** fichas; GPU 24, motherboards 26, fuentes 4, periféricos 63 y catálogo 97.
- Las 21 GPU sin chip en la base y registros internos también recibieron ficha mínima desde título/SKU.
- Manifest combinado: `audits/missing-20260908-all-manifest.json`.
- No se publicó en Odoo. Pendiente: GitHub Pages, dry-run y confirmación manual para aplicar los iframes.

## Lote GPU públicas (2026-09-21)

- Categoría [Placas de video](https://quantumhardstore.com/componentes/placas-de-video/): 16 placas reales sin iframe publicadas (Pages + Odoo + Tiendanube).
- Commit: `047d8af`.
- Reauditoría pública: 28/29 con iframe; el único restante es un adaptador VGA/DVI mal categorizado.
- Comparador animado: **solo placas de video**.

## Cobertura total catálogo (2026-09-21)

- Auditoría Odoo: **7.437** `sale_ok`; **1.812** con desc; **5.625** sin `qh_tn_description_raw`.
- HTML local previo: **5.246**. Altas nuevas generadas: **373** (GPU 18 ricas + 2 fallback, MB 4 + 1 cable fallback, PSU 14, periféricos 143, catálogo 188, skip mapping 3).
- Plantilla GPU v2 (Specs / Comparar / Fuente) solo para placas reales. Resto: ficha Quantum mínima (título/SKU + disclaimer).
- Muestra no-GPU aprobada: `CATALOGO/componentes/cat-12933.html` (XPG SPECTRIX D35G).
- Manifest altas nuevas: `audits/missing-20260921/all-new-manifest.json`.
- Manifest cobertura Odoo: `missing_all_20260921_manifest.json` (**5.625**).
- GitHub Pages: commits `794d698` + `8bbb4ef`.
- Apply Odoo: **5.625/5.625** UPDATED (`qh_tn_description_raw`).
- Tiendanube: **5.625/5.625** PUSH (`publish-tn-descriptions.ps1`).
- Cola residual post-lote: 13 altas nuevas (7 GPU v2 + 5 periféricos + 1 catálogo). Manifest `missing_tail_20260921_manifest.json`. Commit Pages `086ea15`. Odoo 13/13 + TN 13/13.
- Cierre Odoo: **7.468 / 7.468** `sale_ok` con `qh_tn_description_raw` (`audits/odoo-coverage-20260921-final.json`).
- Storefront: 12/12 placas vivas de [Placas de video](https://quantumhardstore.com/componentes/placas-de-video/) con iframe (RX 9050 en ficha mínima). Muestras no-GPU (ZOWIE S2, XPG D35G, RAM) también con iframe. URLs del sitemap sin iframe eran 404 stale, no faltantes reales.

## Lote GPU nuevas (2026-09-23)

- Auditoría Odoo: **7.474** `sale_ok`; **8** sin desc, de las cuales **1 GPU**: EVGA 1660 SUPER outlet (`13438`).
- Categoría pública: 12 placas vivas con HTML Odoo pero sin iframe en Tiendanube (3080/6700 XT/Lenovo 3080/MSI 50-series/GT 710/3060/1030/Red Devil/Zotac 3070).
- Nueva ficha v2: `GPUS/gpu-13438.html`. Manifest apply `missing_gpu_20260923_manifest.json`. Push TN `audits/gpu-public-missing-tn-20260923.json`.
