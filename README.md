# Quantum Descripciones Nuevas MAIN

Repositorio de descripciones HTML (iframe) para Quantum Hardstore.

## Estado actual

Ver **`ESTADO-TRABAJO.md`** (auditoria, perifericos, catalogo minimos, dry-run Odoo, pendientes).

Automatizacion operativa: **`AUTOMATION.md`**.

## Carpetas principales

- `PERIFERICOS/` — ~1607 fichas minimas (mouse, teclados, auriculares, …)
- `CATALOGO/` — ~2615 fichas minimas (componentes, redes, oficina, …)
- Generadores maduros previos: GPU/PSU/MB/PC/WS (no rehacer si ya tienen theme)
- `tools/` — auditoria, generadores, apply Odoo, preview local
- `audits/` — coverage Odoo y faltantes
- `*_manifest.json` — mapeo OdooId → HTML / URL Pages

## Reglas

- Specs oficiales cuando existan; minimos documentados para cobertura.
- Siempre incluir `quantum-theme-switch.js`.
- No publicar Odoo sin OK; dry-run primero.
- Validar desktop/mobile en muestras antes del lote.

## Publicacion (resumen)

1. Push a GitHub Pages
2. Dry-run `apply-odoo-iframes.ps1`
3. OK del usuario → escritura real a `qh_tn_description_raw`

## Repo hermano

Imagenes: `C:\Users\PC\Quantum-Imagenes-Productos`
