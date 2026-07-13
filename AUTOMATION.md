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

## Cambio de paleta post Mundial

Todos los HTML cargan:

```html
<script src="https://thiagodzzzz.github.io/quantum-descripciones-main/quantum-theme-switch.js?v=20260713" defer></script>
```

Hasta el `2026-07-20T00:00:00-03:00` mantiene la paleta mundialista celeste/blanco. Desde esa fecha cambia automaticamente variables compartidas a la paleta Quantum clasica rosa/blanco.

## Publicacion en Odoo

El script sube los iframes desde `*_manifest.json` a `product.template`.

Primero probar sin escribir:

```powershell
.\tools\apply-odoo-iframes.ps1 `
  -OdooUrl 'https://odoo.quantumhardstore.com/odoo' `
  -Database 'NOMBRE_DB' `
  -User 'USUARIO' `
  -ApiKey 'API_KEY' `
  -DryRun
```

Luego ejecutar sin `-DryRun`. Por defecto escribe en `website_description`; si la base usa otro campo, pasar `-DescriptionField`.

## Regla de contenido

Las fichas nuevas deben generarse solo con datos de sitios oficiales del fabricante o marca. Si no hay fuente oficial verificable, no publicar specs inventadas.
