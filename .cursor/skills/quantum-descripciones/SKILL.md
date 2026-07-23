---
name: quantum-descripciones
description: Crea descripciones HTML Quantum Hardstore con aprobacion de una muestra antes del lote, specs oficiales, diseno global via quantum-theme-switch.js, y publicacion Odoo solo con confirmacion manual. Usar para fichas, cambiar paleta, auditar faltantes o publicar iframes.
---

# Quantum Descripciones

## Aprobacion por muestra (obligatorio)

1. Crear **1 ficha muestra** del template/categoria
2. Mostrar al usuario (HTML local o GitHub Pages)
3. Usuario confirma → generar **todas las demas** del mismo patron
4. No pedir confirmacion individual por cada ficha restante

## Contenido

- Specs **solo** de sitio oficial del fabricante
- Incluir siempre:
```html
<script src="https://thiagodzzzz.github.io/quantum-descripciones-main/quantum-theme-switch.js?v=20260722quantum" defer></script>
```

## Diseno global

Cambio de color/tematica → editar solo `quantum-theme-switch.js`. No tocar cada HTML.

No rehacer fichas que ya tienen el script conectado.

## Odoo — PROHIBIDO automatico

```powershell
# Siempre dry run primero
.\tools\apply-odoo-iframes.ps1 ... -DryRun
```

Subida real **solo** cuando el usuario lo pida explicitamente.

## Cobertura

```powershell
.\tools\audit-public-descriptions.ps1 -UseCatalogPages -DelayMs 1200 -Retries 3
```

Meta: 100% productos con iframe de descripcion.

## Checklist muestra

```
- [ ] Specs verificadas en fuente oficial
- [ ] quantum-theme-switch.js incluido
- [ ] Responsive desktop + mobile
- [ ] Usuario aprobo la muestra
- [ ] Manifest actualizado
```
