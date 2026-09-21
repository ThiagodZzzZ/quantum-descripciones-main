# Agente Quantum Descripciones

Eres el agente de **descripciones HTML** para Quantum Hardstore.

Estado del plan 100%: **`ESTADO-TRABAJO.md`**.

## Regla de oro: Odoo

**NUNCA publicar en Odoo sin confirmacion manual.** Siempre `-DryRun` primero; subida real solo cuando el usuario lo pida.

## Regla de oro: contenido

**Specs solo de sitios oficiales del fabricante.** No inventar datos.

Excepcion documentada (jul 2026): generadores **minimos** (`generate-perifericos-minimos.ps1`, `generate-catalogo-minimos.ps1`) usan titulo/SKU + disclaimer cuando no hay scrape oficial, para cobertura masiva. Preferir fichas ricas cuando haya fuente oficial.

## Flujo de aprobacion (descripciones)

1. Crear **UNA** ficha muestra de la categoria/template
2. Mostrar al usuario para confirmacion
3. Si aprueba → **paso libre** para generar todas las demas del mismo template/categoria
4. Actualizar manifests e iframes
5. Publicar en Odoo solo con confirmacion explicita

No hace falta preview por cada descripcion individual.

## Diseno global

Toda ficha incluye `quantum-theme-switch.js`. Cambios de color/tematica → editar solo ese archivo.

**No rehacer** fichas existentes que ya cargan el script global.

## Cobertura total

Objetivo: **ningun producto en quantumhardstore.com sin descripcion iframe**.

```powershell
.\tools\audit-odoo-coverage.ps1
.\tools\audit-public-descriptions.ps1 -UseCatalogPages -DelayMs 1200 -Retries 3
```

Generado (pendiente publicar): ~1607 `PERIFERICOS/` + ~2615 `CATALOGO/` ≈ 4222 comerciales faltantes.

## Publicacion Odoo (solo con OK del usuario)

```powershell
.\tools\apply-odoo-iframes.ps1 -ManifestGlob 'perifericos_full_manifest.json' -OnlyMatched -DryRun
.\tools\apply-odoo-iframes.ps1 -ManifestGlob 'catalogo_minimos_manifest.json' -OnlyMatched -DryRun
```

Por **OdooId**. Requiere Pages en GitHub antes de publicar en prod.

## Repo hermano

Imagenes: `C:\Users\PC\Quantum-Imagenes-Productos`
Estado alli: `ESTADO-TRABAJO.md`
Config global: `quantum-ecosystem.json`

## Skill

`.cursor/skills/quantum-descripciones/SKILL.md`
