# Automatizacion Quantum Descripciones

## Auditoria publica

Detecta productos publicados en `quantumhardstore.com` que no tienen iframe de GitHub Pages en la descripcion larga. Por defecto toma URLs desde `sitemap.xml`; para auditar solo paginas de catalogo activo, usar `-UseCatalogPages`.

```powershell
.\tools\audit-public-descriptions.ps1 -DelayMs 1200 -Retries 3
```

```powershell
.\tools\audit-public-descriptions.ps1 -UseCatalogPages -DelayMs 1200 -Retries 3
```

Salidas:

- `audits/product_links.txt`
- `audits/description_audit.csv`
- `audits/missing_github_iframe.csv`

Usar pausas conservadoras: la tienda devuelve `429 Too Many Requests` si se audita demasiado rapido.

## Paleta Quantum clasica

Todos los HTML cargan (usar la version del HTML mas reciente; ejemplo jul 2026):

```html
<script src="https://thiagodzzzz.github.io/quantum-descripciones-main/quantum-theme-switch.js?v=20260728quantum" defer></script>
```

El switch global fuerza la paleta Quantum clasica rosa/blanco e inyecta overrides para templates antiguos.

## Generadores minimos (cobertura 100%)

Ver detalle en `ESTADO-TRABAJO.md`.

```powershell
.\tools\audit-odoo-coverage.ps1
.\tools\generate-perifericos-minimos.ps1   # → PERIFERICOS/ + perifericos_full_manifest.json
.\tools\generate-catalogo-minimos.ps1      # → CATALOGO/ + catalogo_minimos_manifest.json
.\tools\serve-descriptions-preview.ps1
```

Match Odoo por **OdooId**. JSON grande: escribir item-a-item (PS 5.1).

## Publicacion en Odoo

El script sube iframes desde `*_manifest.json` a `product.template`.

Campo usado en QuantumHard: **`qh_tn_description_raw`** (pasar `-DescriptionField` si hace falta).

Primero dry-run:

```powershell
.\tools\apply-odoo-iframes.ps1 `
  -ManifestGlob 'perifericos_full_manifest.json' `
  -OnlyMatched -DryRun

.\tools\apply-odoo-iframes.ps1 `
  -ManifestGlob 'catalogo_minimos_manifest.json' `
  -OnlyMatched -DryRun
```

Luego ejecutar **sin** `-DryRun` solo con OK del usuario. Requiere push a GitHub Pages antes.

## Regla de contenido

Fichas ricas: solo datos de sitios oficiales.  
Minimos de cobertura: titulo/SKU + disclaimer (documentado); no inventar specs de marketing.

## Aprobacion por muestra

1. Generar **una** ficha de referencia del template/categoria.
2. El usuario la revisa y confirma.
3. Con OK, generar el resto del lote sin pedir confirmacion individual.
4. Publicar en Odoo solo cuando el usuario lo pida (siempre `-DryRun` primero).

## Cobertura

Meta: ningun producto en quantumhardstore.com sin descripcion iframe. No rehacer fichas que ya cargan `quantum-theme-switch.js`.
