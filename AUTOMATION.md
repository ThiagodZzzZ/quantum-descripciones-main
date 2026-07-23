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

Todos los HTML cargan:

```html
<script src="https://thiagodzzzz.github.io/quantum-descripciones-main/quantum-theme-switch.js?v=20260722quantum" defer></script>
```

El Mundial ya termino. El switch global fuerza la paleta Quantum clasica rosa/blanco e inyecta overrides para templates antiguos que todavia tienen estilos inline celestes o amarillos.

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

## Aprobacion por muestra

1. Generar **una** ficha de referencia del template/categoria.
2. El usuario la revisa y confirma.
3. Con OK, generar el resto del lote sin pedir confirmacion individual.
4. Publicar en Odoo solo cuando el usuario lo pida (siempre `-DryRun` primero).

## Cobertura

Meta: ningun producto en quantumhardstore.com sin descripcion iframe. No rehacer fichas que ya cargan `quantum-theme-switch.js`.
