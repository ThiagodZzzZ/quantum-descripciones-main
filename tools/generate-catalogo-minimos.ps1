#Requires -Version 5.1
<#
.SYNOPSIS
  Fichas tecnicas minimas para el resto del catalogo (no Perifericos).
  Lee audits/missing-all-by-categ.json y genera HTML + manifests por categoria top.
#>
param(
  [string]$Worklist = '.\audits\missing-all-by-categ.json',
  [string]$OutRoot = '.\CATALOGO',
  [string]$Category = 'all',     # nombre top exacto o 'all' (excluye Perifericos)
  [switch]$SampleOnly,
  [string]$ManifestPath = '',    # si se setea, no pisa catalogo_minimos_manifest.json
  [string]$ThemeVersion = '20260818quantum',
  [string]$ThemeBase = 'https://thiagodzzzz.github.io/quantum-descripciones-main',
  [int]$Limit = 0,
  [int[]]$OnlyIds = @()
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
function HE([string]$s){ [System.Web.HttpUtility]::HtmlEncode($s) }

$BRANDS = @(
  'INTEL','AMD','ASUS','MSI','GIGABYTE','ASROCK','CORSAIR','KINGSTON','CRUCIAL','SAMSUNG','WD','WESTERN DIGITAL',
  'SEAGATE','ADATA','XPG','TEAMGROUP','PATRIOT','COOLER MASTER','DEEPCOOL','THERMALTAKE','NZXT','LIAN LI',
  'FRACTAL','PHANTEKS','AEROCOOL','REDRAGON','LOGITECH','TP-LINK','TPLINK','MERCUSYS','UBIQUITI','MIKROTIK',
  'CISCO','HP','DELL','LENOVO','EPSON','BROTHER','CANON','XEROX','APC','EATON','LYONN','NOGA','GENIUS'
)

function Get-Brand([string]$t){
  foreach($b in $BRANDS){ if($t -match ('(?i)\b'+[regex]::Escape($b)+'\b')){ return $b.ToUpper() } }
  $tok = ($t -split '\s+' | Where-Object { $_.Length -ge 3 } | Select-Object -First 1)
  if($tok){ return $tok.ToUpper() }
  return 'QUANTUM'
}
function Get-Kind([string]$categ, [string]$title){
  $c = "$categ $title"
  if($c -match '(?i)memoria|ram|ddr'){ return 'Memoria RAM' }
  if($c -match '(?i)procesador|cpu|ryzen|core i'){ return 'Procesador' }
  if($c -match '(?i)gabinete|cabinet|case'){ return 'Gabinete' }
  if($c -match '(?i)refriger|cooler|water|aio'){ return 'Refrigeracion' }
  if($c -match '(?i)almacen|ssd|hdd|m\.2|nvme'){ return 'Almacenamiento' }
  if($c -match '(?i)notebook|laptop'){ return 'Notebook' }
  if($c -match '(?i)monitor'){ return 'Monitor' }
  if($c -match '(?i)red|router|switch|access point|placa de red'){ return 'Redes' }
  if($c -match '(?i)ups|estabiliz'){ return 'Energia / UPS' }
  if($c -match '(?i)impresora|scanner|escaner'){ return 'Oficina' }
  if($c -match '(?i)fuente|psu'){ return 'Fuente' }
  if($c -match '(?i)placa de video|geforce|radeon|rtx|gtx|rx\s*\d'){ return 'Placa de video' }
  if($c -match '(?i)\bpc\b|workstation|gamer'){ return 'PC' }
  return 'Producto'
}
function Fix-CatLabel([string]$cat){
  if ($cat -match '(?i)^perif') { return 'Perifericos' }
  if ($cat -match '(?i)^energ') { return 'Energia' }
  if ($cat -match '(?i)sin\s*categoria') { return 'Sin categoria' }
  return $cat
}
function Slug-Cat([string]$cat){
  $x = (Fix-CatLabel $cat).ToLowerInvariant()
  $map = @{
    [char]0x00E1='a'; [char]0x00E9='e'; [char]0x00ED='i'; [char]0x00F3='o'; [char]0x00FA='u'
    [char]0x00F1='n'; [char]0x00FC='u'
  }
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $x.ToCharArray()) {
    if ($map.ContainsKey($ch)) { [void]$sb.Append($map[$ch]) }
    else { [void]$sb.Append($ch) }
  }
  $x = $sb.ToString()
  $x = [regex]::Replace($x, '[^a-z0-9]+', '-')
  return $x.Trim('-')
}
function Test-Outlet([string]$t){ $t -match '(?i)OUTLET|OPENBOX|USADO' }

$template = @'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{TITLE}} - Quantum Hardstore</title>
  <link rel="stylesheet" href="../../quantum-products-theme.css">
  <script src="{{THEME_BASE}}/quantum-theme-switch.js?v={{THEME_VERSION}}" defer></script>
</head>
<body>
<div class="container">
  <header class="qh-header">
    <div class="brand">Quantum Hardstore</div>
    <div class="maker">{{MAKER}}</div>
    <h1>{{H1}}</h1>
    <div class="subtitle">{{SUBTITLE}}</div>
  </header>
  <div class="badge-row">{{BADGES}}</div>
  <section class="hero-metric"><div class="metric-box"><div class="metric-label">Categoria</div><div class="metric-value">{{KIND}}</div><div class="metric-desc">{{HERO_DESC}}</div></div></section>
  <section class="section"><h2 class="section-title">Especificaciones clave</h2><p class="section-sub">Ficha tecnica minima desde el listado. Sin inventar valores no declarados.</p><div class="spec-grid">{{SPECS}}</div></section>
  {{STATUS_BOX}}
  <div class="note">{{NOTE}}</div>
</div>
</body>
</html>
'@

$wl = Get-Content -LiteralPath $Worklist -Raw | ConvertFrom-Json
$cats = @($wl.byCategory)
if ($Category -ne 'all') {
  $cats = @($cats | Where-Object { $_.category -eq $Category })
} else {
  $cats = @($cats | Where-Object { $_.category -notmatch '(?i)^Perif' })
}

$manifest = New-Object System.Collections.Generic.List[object]
$gen = 0
foreach ($catBlock in $cats) {
  $top = Fix-CatLabel ([string]$catBlock.category)
  $slug = Slug-Cat $top
  $dir = Join-Path $OutRoot $slug
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $list = @($catBlock.items)
  if ($SampleOnly) { $list = @($list | Select-Object -First 1) }
  if ($Limit -gt 0) { $list = @($list | Select-Object -First $Limit) }

  foreach ($it in $list) {
    $id = [int]$it.id
    if ($OnlyIds.Count -gt 0 -and $OnlyIds -notcontains $id) { continue }
    $title = [string]$it.title
    $sku = [string]$it.sku
    $categ = [string]$it.categ
    $brand = Get-Brand $title
    $kind = Get-Kind $categ $title
    $outlet = Test-Outlet $title
    $cond = if ($outlet) { 'Outlet' } else { 'Nuevo' }
    $titleClean = ($title -replace '(?i)\s*\((OUTLET|OPENBOX|NUEVA|NUEVO)\)\s*', ' ').Trim()

    $badges = @($kind, $brand, $cond) | ForEach-Object { "<span class=`"badge`">$(HE $_)</span>" }
    $specs = @(
      "<article class=`"spec-card`"><div class=`"spec-name`">Marca / modelo</div><div class=`"spec-value`">$(HE "$brand - $titleClean")</div><div class=`"spec-note`">Denominacion del listado.</div></article>",
      "<article class=`"spec-card`"><div class=`"spec-name`">Tipo</div><div class=`"spec-value`">$(HE $kind)</div><div class=`"spec-note`">Clasificacion comercial.</div></article>",
      "<article class=`"spec-card`"><div class=`"spec-name`">Categoria Odoo</div><div class=`"spec-value`">$(HE $categ)</div><div class=`"spec-note`">Rubro interno.</div></article>"
    )
    if ($sku) {
      $specs += "<article class=`"spec-card`"><div class=`"spec-name`">SKU</div><div class=`"spec-value`">$(HE $sku)</div><div class=`"spec-note`">Referencia.</div></article>"
    }
    $specs += "<article class=`"spec-card`"><div class=`"spec-name`">Estado</div><div class=`"spec-value`">$(HE $cond)</div><div class=`"spec-note`">Condicion de venta.</div></article>"

    $statusBox = ''
    if ($outlet) {
      $statusBox = '<div class="status-box"><div class="status-title">Producto outlet</div><div class="status-text">Unidad outlet revisada. Consultar stock antes de abonar.</div></div>'
    }

    $file = "cat-$id.html"
    $html = $template
    $repl = @{
      '{{TITLE}}'=(HE $title); '{{MAKER}}'=(HE "$brand / $kind"); '{{H1}}'=(HE $titleClean)
      '{{SUBTITLE}}'=(HE "$kind / $cond"); '{{BADGES}}'=($badges -join "`n    ")
      '{{KIND}}'=(HE $kind); '{{HERO_DESC}}'=(HE "Ficha tecnica minima para $kind $brand.")
      '{{SPECS}}'=($specs -join "`n      "); '{{STATUS_BOX}}'=$statusBox
      '{{NOTE}}'=(HE "* Datos del titulo/SKU. Specs exactas: hoja oficial del fabricante $brand.")
      '{{THEME_BASE}}'=$ThemeBase; '{{THEME_VERSION}}'=$ThemeVersion
    }
    foreach ($k in $repl.Keys) { $html = $html.Replace($k, [string]$repl[$k]) }
    $outHtml = Join-Path $dir $file
    [System.IO.File]::WriteAllText($outHtml, $html, (New-Object System.Text.UTF8Encoding $false))

    $iframe = "<iframe src=`"${ThemeBase}/CATALOGO/${slug}/${file}?v=${ThemeVersion}`" style=`"width:100%;height:2000px;border:0;`" loading=`"lazy`"></iframe>"
    $manifest.Add([pscustomobject]@{
      OdooId=$id; Title=$title; Sku=$sku; Category=$top; File="$slug/$file"
      Kind=$kind; Brand=$brand; Outlet=[bool]$outlet; Matched=$true; iframe=$iframe
    })
    $gen++
  }
}

$repo = (Resolve-Path '.').Path
$manPath = if ($ManifestPath) { $ManifestPath } else { Join-Path $repo 'catalogo_minimos_manifest.json' }
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('[')
for ($i = 0; $i -lt $manifest.Count; $i++) {
  $piece = ($manifest[$i] | ConvertTo-Json -Depth 5 -Compress)
  if ($i -lt $manifest.Count - 1) { [void]$sb.AppendLine($piece + ',') } else { [void]$sb.AppendLine($piece) }
}
[void]$sb.AppendLine(']')
[System.IO.File]::WriteAllText($manPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
Write-Host ("Generadas catalogo: {0}" -f $gen)
Write-Host ("Manifest: {0}" -f $manPath)
