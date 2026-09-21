---
name: quantum-descripciones
description: Crea descripciones HTML Quantum Hardstore con aprobacion de una muestra antes del lote, specs oficiales o minimos documentados, diseno global via quantum-theme-switch.js, y publicacion Odoo solo con confirmacion manual. Usar para fichas, perifericos, catalogo minimos, auditar faltantes o publicar iframes.
---

# Quantum Descripciones

Estado: `ESTADO-TRABAJO.md`. Automatizacion: `AUTOMATION.md`.

## Aprobacion por muestra (obligatorio)

1. Crear **1 ficha muestra** del template/categoria
2. Mostrar al usuario (HTML local o GitHub Pages)
3. Usuario confirma → generar **todas las demas** del mismo patron
4. No pedir confirmacion individual por cada ficha restante

## Contenido

- Specs **solo** de sitio oficial del fabricante (fichas ricas)
- Minimos masivos: `tools/generate-perifericos-minimos.ps1`, `tools/generate-catalogo-minimos.ps1` (titulo/SKU + disclaimer)
- Incluir siempre `quantum-theme-switch.js` (ver version en `ESTADO-TRABAJO.md` / HTML reciente)

## Diseno global

Cambio de color/tematica → editar solo `quantum-theme-switch.js`. No tocar cada HTML.

No rehacer fichas que ya tienen el script conectado.

## Odoo — PROHIBIDO automatico

```powershell
.\tools\apply-odoo-iframes.ps1 -ManifestGlob 'perifericos_full_manifest.json' -OnlyMatched -DryRun
.\tools\apply-odoo-iframes.ps1 -ManifestGlob 'catalogo_minimos_manifest.json' -OnlyMatched -DryRun
```

Subida real **solo** cuando el usuario lo pida. Match por **OdooId**.

## Cobertura

```powershell
.\tools\audit-odoo-coverage.ps1
.\tools\audit-public-descriptions.ps1 -UseCatalogPages -DelayMs 1200 -Retries 3
```

Meta: 100% productos con iframe de descripcion.

## Checklist muestra

```
- [ ] Specs verificadas (o minimo documentado aprobado)
- [ ] quantum-theme-switch.js incluido
- [ ] Responsive desktop + mobile
- [ ] Usuario aprobo la muestra
- [ ] Manifest actualizado
- [ ] Dry-run Odoo OK antes de publicar
```
