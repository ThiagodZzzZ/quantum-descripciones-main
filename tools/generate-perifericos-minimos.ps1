#Requires -Version 5.1
<#
.SYNOPSIS
  Genera fichas HTML tecnicas minimas para Perifericos (y opcional SampleOnly).
  Specs solo desde titulo/SKU; no inventa numeros de marketing.
#>
param(
  [string]$Worklist = '.\audits\missing-perifericos.json',
  [string]$OutRoot = '.\PERIFERICOS',
  [string]$Folder = 'all',           # mouse|teclados|...|all
  [switch]$SampleOnly,               # solo 1 producto (muestra)
  [int]$SampleId = 0,                # forzar odooId de muestra
  [string]$ManifestPath = '',        # si se setea, no pisa perifericos_full_manifest.json
  [string]$ThemeVersion = '20260818quantum',
  [string]$ThemeBase = 'https://thiagodzzzz.github.io/quantum-descripciones-main'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
function HE([string]$s){ [System.Web.HttpUtility]::HtmlEncode($s) }

$BRANDS = @(
  'HYPERX','LOGITECH','RAZER','REDRAGON','CORSAIR','STEELSERIES','GENIUS','TRUST','NOGA','NOGANET',
  'PHILIPS','SAMSUNG','LENOVO','MICROSOFT','HP','DELL','APPLE','JBL','SONY','XBOX','PLAYSTATION',
  'DUCKY','KEYCHRON','COOLER MASTER','ASUS','ROG','MSI','GIGABYTE','AEROCOOL','HALION','NISUTA',
  'KANJI','TALIUS','CROM','CROMMAX','RAPTOR','THERMALTAKE','DEEPCOOL','FIFINE','BOYA','STREAMPLIFY',
  'ELGATO','BLUE','RODE','ANTRYX','XPG','ADATA','RAPOO','BLOODY','FANTECH','ONIKUMA','ZOWIE','BENQ',
  'PULSAR','VAXEE','LAMZU','ENDGAME','GLORIOUS','FINALMOUSE','XTRFY','COUGAR','MARVO','HAVIT'
)
$SKIP_BRAND = @('MOUSE','TECLADO','AURICULAR','AURICULARES','GAMER','GAMING','KIT','ACCESORIOS','OUTLET','NUEVO','NUEVA','PARLANTE','WEBCAM','MICROFONO','SILLA','JOYSTICK')

function Get-Brand([string]$t){
  foreach($b in $BRANDS){ if($t -match ('(?i)\b'+[regex]::Escape($b)+'\b')){ return $b.ToUpper() } }
  $tok = ($t -split '\s+' | Where-Object {
    $_.Length -ge 3 -and ($SKIP_BRAND -notcontains $_.ToUpperInvariant()) -and $_ -notmatch '^\d'
  } | Select-Object -First 1)
  if($tok){ return $tok.ToUpper() }
  return 'QUANTUM'
}
function Get-TypeLabel([string]$folder){
  switch($folder){
    'mouse' { 'Mouse' }
    'teclados' { 'Teclado' }
    'auriculares' { 'Auriculares' }
    'parlantes' { 'Parlantes' }
    'webcams' { 'Webcam' }
    'microfonos' { 'Microfono' }
    'sillas' { 'Silla gamer' }
    'gaming' { 'Gaming / control' }
    'monitores' { 'Monitor' }
    default { 'Accesorio' }
  }
}
function Get-Connectivity([string]$t){
  $bits=@()
  if($t -match '(?i)inalambr|wireless|2\.4|bluetooth|\bbt\b'){ $bits+='Inalambrico' }
  if($t -match '(?i)\busb\b|cable|wired'){ $bits+='USB / cableado' }
  if($t -match '(?i)type-?c|usb-?c'){ $bits+='USB-C' }
  if($t -match '(?i)3\.5\s*mm|jack|plug'){ $bits+='Jack 3.5mm' }
  if($t -match '(?i)ps5|playstation'){ $bits+='PS5' }
  if($t -match '(?i)\bxbox\b'){ $bits+='Xbox' }
  if($t -match '(?i)\bpc\b|\bnotebook\b|\blaptop\b'){ $bits+='PC' }
  if($bits.Count -eq 0){ return 'Segun ficha del modelo' }
  return ($bits | Select-Object -Unique) -join ' · '
}
function Get-Features([string]$t, [string]$folder){
  $f=@()
  if($t -match '(?i)\brgb\b|argb|chroma|ilumin'){ $f+='RGB / iluminacion' }
  if($t -match '(?i)mecanico|mechanical|switch|kailh|gateron|red switch|blue switch'){ $f+='Mecanico' }
  if($t -match '(?i)membrane|membrana'){ $f+='Membrana' }
  if($t -match '(?i)optic|laser|sensor'){ $f+='Sensor optico/laser' }
  if($t -match '(?i)\b\d{3,5}\s*dpi\b'){ $m=[regex]::Match($t,'(?i)(\d{3,5})\s*dpi'); if($m.Success){ $f+="$($m.Groups[1].Value) DPI" } }
  if($t -match '(?i)7\.1|surround|espacial'){ $f+='Audio 7.1 / surround' }
  if($t -match '(?i)noise|cancel|anc'){ $f+='Cancelacion de ruido' }
  if($t -match '(?i)mic|microfono'){ $f+='Con microfono' }
  if($t -match '(?i)full.?hd|1080|720p|4k'){ $f+='Resolucion de video (segun titulo)' }
  if($t -match '(?i)wireless|inalambr'){ $f+='Inalambrico' }
  if($t -match '(?i)ergonom'){ $f+='Ergonomico' }
  if($folder -eq 'sillas' -and $t -match '(?i)reclin|lumbar|4d|3d'){ $f+='Ajustes declarados en titulo' }
  if($f.Count -eq 0){ return @('Datos segun denominacion del producto') }
  return @($f | Select-Object -Unique | Select-Object -First 6)
}
function Test-Outlet([string]$t){ $t -match '(?i)OUTLET|OPENBOX|USADO|OPEN BOX' }

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
  <div class="badge-row" aria-label="Caracteristicas principales">{{BADGES}}</div>
  <section class="hero-metric">
    <div class="metric-box">
      <div class="metric-label">Tipo</div>
      <div class="metric-value">{{TYPE}}</div>
      <div class="metric-desc">{{HERO_DESC}}</div>
    </div>
  </section>
  <section class="card-grid" aria-label="Resumen">
    <article class="info-card"><div class="label">Marca</div><div class="value">{{BRAND}}</div><div class="desc">Identificacion comercial.</div></article>
    <article class="info-card"><div class="label">Conectividad</div><div class="value">{{CONN}}</div><div class="desc">Segun denominacion del producto.</div></article>
    <article class="info-card"><div class="label">Estado</div><div class="value">{{COND}}</div><div class="desc">Condicion de venta.</div></article>
  </section>
  <section class="section">
    <h2 class="section-title">Especificaciones clave</h2>
    <p class="section-sub">Ficha tecnica minima armada con datos del titulo/SKU del listado. No se inventan valores que no figuren en la denominacion.</p>
    <div class="spec-grid">{{SPECS}}</div>
  </section>
  <section class="section dark">
    <h2 class="section-title">Para que sirve</h2>
    <p class="section-sub">Uso tipico segun la categoria del periferico.</p>
    <div class="conn-grid">{{USES}}</div>
  </section>
  {{STATUS_BOX}}
  <div class="note">{{NOTE}}</div>
</div>
</body>
</html>
'@

$wl = Get-Content -LiteralPath $Worklist -Raw | ConvertFrom-Json
$items = @($wl.items)
if ($Folder -ne 'all') {
  $items = @($items | Where-Object { $_.folder -eq $Folder })
}
if ($SampleOnly) {
  if ($SampleId -gt 0) {
    $items = @($items | Where-Object { [int]$_.id -eq $SampleId } | Select-Object -First 1)
  } else {
    $items = @($items | Select-Object -First 1)
  }
  if ($items.Count -eq 0) { throw "No hay item de muestra para Folder=$Folder SampleId=$SampleId" }
}

$manifestAll = New-Object System.Collections.Generic.List[object]
$gen = 0
$byFolderCount = @{}

foreach ($it in $items) {
  $id = [int]$it.id
  $title = [string]$it.title
  $sku = [string]$it.sku
  $folder = [string]$it.folder
  if (-not $folder) { $folder = 'accesorios' }
  $type = Get-TypeLabel $folder
  $brand = Get-Brand $title
  $conn = Get-Connectivity $title
  $feats = @(Get-Features $title $folder)
  $outlet = Test-Outlet $title
  $cond = if ($outlet) { 'Outlet' } else { 'Nuevo' }
  $titleClean = ($title -replace '(?i)\s*\((OUTLET|OPENBOX|NUEVA|NUEVO)\)\s*', ' ').Trim()

  $badges = @($type, $brand)
  if ($conn -and $conn -ne 'Segun ficha del modelo') { $badges += ($conn -split ' · ' | Select-Object -First 2) }
  $badges += $cond
  $badgeHtml = ($badges | Select-Object -Unique | ForEach-Object { "<span class=`"badge`">$(HE $_)</span>" }) -join "`n    "

  $specs = New-Object System.Collections.Generic.List[string]
  $specs.Add("<article class=`"spec-card`"><div class=`"spec-name`">Marca / modelo</div><div class=`"spec-value`">$(HE "$brand - $titleClean")</div><div class=`"spec-note`">Denominacion del listado Quantum Hardstore.</div></article>")
  $specs.Add("<article class=`"spec-card`"><div class=`"spec-name`">Tipo</div><div class=`"spec-value`">$(HE $type)</div><div class=`"spec-note`">Categoria de periferico.</div></article>")
  $specs.Add("<article class=`"spec-card`"><div class=`"spec-name`">Conectividad</div><div class=`"spec-value`">$(HE $conn)</div><div class=`"spec-note`">Detectada en el titulo cuando esta declarada.</div></article>")
  if ($sku) {
    $specs.Add("<article class=`"spec-card`"><div class=`"spec-name`">SKU</div><div class=`"spec-value`">$(HE $sku)</div><div class=`"spec-note`">Codigo interno / referencia.</div></article>")
  }
  foreach ($f in $feats) {
    $specs.Add("<article class=`"spec-card`"><div class=`"spec-name`">Dato del listado</div><div class=`"spec-value`">$(HE $f)</div><div class=`"spec-note`">Extraido del titulo; validar en hoja del fabricante si necesitas detalle exacto.</div></article>")
  }
  $specs.Add("<article class=`"spec-card`"><div class=`"spec-name`">Estado</div><div class=`"spec-value`">$(HE $cond)</div><div class=`"spec-note`">Condicion comercial.</div></article>")

  $usesMap = @{
    mouse = @(@('PC / notebook','Uso diario y gaming liviano'),@('Sensor','Precision segun modelo'),@('Setup','USB o receptor inalambrico'))
    teclados = @(@('Escritura','Oficina y estudio'),@('Gaming','Si es mecanico/RGB'),@('Conexion','USB o wireless'))
    auriculares = @(@('Audio','Juegos, calls, musica'),@('Mic','Si el titulo lo declara'),@('Jack/USB','Segun modelo'))
    parlantes = @(@('Escritorio','PC o consola'),@('Potencia','Segun ficha oficial'),@('Entradas','Aux/USB/BT si aplica'))
    webcams = @(@('Video calls','Meet/Zoom/Teams'),@('Montaje','Monitor o escritorio'),@('Resolucion','Segun titulo'))
    microfonos = @(@('Streaming','Contenido y calls'),@('Patron','Segun ficha oficial'),@('Interfaz','USB o XLR'))
    sillas = @(@('Postura','Uso prolongado'),@('Ajustes','Segun titulo'),@('Base','Verificar espacio'))
    gaming = @(@('Consola/PC','Compatibilidad del titulo'),@('Control','Juegos y sim'),@('Extras','Vibracion/RGB si aplica'))
    monitores = @(@('Pantalla','Trabajo y gaming'),@('Panel','Segun ficha oficial'),@('Cables','HDMI/DP segun modelo'))
    accesorios = @(@('Complemento','Setup gamer/oficina'),@('Compatibilidad','Segun titulo'),@('Uso','Accesorio de periferico'))
  }
  $useRows = $usesMap[$folder]
  if (-not $useRows) { $useRows = $usesMap['accesorios'] }
  $usesHtml = ($useRows | ForEach-Object {
    "<article class=`"conn-card`"><div class=`"conn-count`">$(HE $_[0])</div><div class=`"conn-name`">Uso</div><div class=`"conn-desc`">$(HE $_[1])</div></article>"
  }) -join "`n      "

  $heroDesc = "$type $brand. Ficha tecnica minima para publicacion web; detalle fino segun fabricante."
  $subtitle = (@($type, $conn, $cond) | Where-Object { $_ -and $_ -ne 'Segun ficha del modelo' }) -join ' / '
  $statusBox = ''
  if ($outlet) {
    $statusBox = '<div class="status-box"><div class="status-title">Producto outlet</div><div class="status-text">Unidad outlet revisada por Quantum Hardstore. Estado y stock sujetos a confirmacion.</div></div>'
  }
  $note = "* Descripcion tecnica minima a partir del titulo/SKU. Dimensiones exactas, peso, switches, DPI maximo, autonomia y demas valores no declarados en el listado: consultar hoja oficial del fabricante $brand."

  $dir = Join-Path $OutRoot $folder
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $file = "perif-$id.html"
  $html = $template
  $repl = @{
    '{{TITLE}}' = (HE $title)
    '{{MAKER}}' = (HE "$brand Perifericos")
    '{{H1}}' = (HE $titleClean)
    '{{SUBTITLE}}' = (HE $subtitle)
    '{{BADGES}}' = $badgeHtml
    '{{TYPE}}' = (HE $type)
    '{{HERO_DESC}}' = (HE $heroDesc)
    '{{BRAND}}' = (HE $brand)
    '{{CONN}}' = (HE $conn)
    '{{COND}}' = (HE $cond)
    '{{SPECS}}' = ($specs -join "`n      ")
    '{{USES}}' = $usesHtml
    '{{STATUS_BOX}}' = $statusBox
    '{{NOTE}}' = (HE $note)
    '{{THEME_BASE}}' = $ThemeBase
    '{{THEME_VERSION}}' = $ThemeVersion
  }
  foreach ($k in $repl.Keys) { $html = $html.Replace($k, [string]$repl[$k]) }
  $outPath = Join-Path $dir $file
  [System.IO.File]::WriteAllText($outPath, $html, (New-Object System.Text.UTF8Encoding $false))

  $iframe = "<iframe src=`"${ThemeBase}/PERIFERICOS/${folder}/${file}?v=${ThemeVersion}`" style=`"width:100%;height:2200px;border:0;`" loading=`"lazy`"></iframe>"
  $manifestAll.Add([pscustomobject]@{
    OdooId = $id
    Title = $title
    Sku = $sku
    Folder = $folder
    File = "$folder/$file"
    Type = $type
    Brand = $brand
    Outlet = [bool]$outlet
    Matched = $true
    iframe = $iframe
  })
  $gen++
  if (-not $byFolderCount.ContainsKey($folder)) { $byFolderCount[$folder] = 0 }
  $byFolderCount[$folder]++
}

# manifests por carpeta + global (serializar item a item; ConvertTo-Json masivo falla en PS 5.1)
function Write-JsonArrayFile([string]$Path, $Items) {
  $list = New-Object System.Collections.Generic.List[object]
  if ($Items -is [System.Collections.IEnumerable] -and -not ($Items -is [string])) {
    foreach ($x in $Items) { if ($null -ne $x) { [void]$list.Add($x) } }
  }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('[')
  for ($i = 0; $i -lt $list.Count; $i++) {
    $piece = ($list[$i] | ConvertTo-Json -Depth 5 -Compress)
    if ($i -lt $list.Count - 1) { [void]$sb.AppendLine($piece + ',') } else { [void]$sb.AppendLine($piece) }
  }
  [void]$sb.AppendLine(']')
  [System.IO.File]::WriteAllText($Path, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
}
$repoRoot = (Resolve-Path '.').Path
if ($ManifestPath) {
  Write-JsonArrayFile $ManifestPath $manifestAll
  $allPath = $ManifestPath
} else {
  $groups = @($manifestAll | Group-Object Folder)
  foreach ($g in $groups) {
    $manPath = Join-Path $repoRoot ("perifericos_{0}_manifest.json" -f $g.Name)
    Write-JsonArrayFile $manPath $g.Group
  }
  $allPath = Join-Path $repoRoot 'perifericos_full_manifest.json'
  Write-JsonArrayFile $allPath $manifestAll
}
Write-Host ("Generadas: {0}" -f $gen)
$byFolderCount.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host ("  {0}: {1}" -f $_.Key, $_.Value) }
Write-Host ("Manifest: {0}" -f $allPath)
if ($SampleOnly -and $manifestAll.Count -gt 0) {
  $s = $manifestAll[0]
  Write-Host ("MUESTRA: {0} | Odoo {1} | {2}" -f $s.File, $s.OdooId, $s.Title)
  Write-Host ("Preview local: {0}" -f (Join-Path $OutRoot $s.File))
}
