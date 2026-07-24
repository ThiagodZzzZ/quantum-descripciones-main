#Requires -Version 5.1
# Genera descripciones de MOTHERBOARDS a partir del catalogo Odoo.
# Specs derivadas del titulo oficial + tabla de chipsets (socket/DDR). No inventa cantidades exactas de puertos.
param(
  [string]$OdooJson = 'C:\Users\PC\Quantum-Imagenes-Productos\inventario\odoo-mb.json',
  [string]$OutDir   = 'C:\Users\PC\Quantum-Descripciones-Nuevas-MAIN\MOTHERBOARDS',
  [string]$ManifestPath = 'C:\Users\PC\Quantum-Descripciones-Nuevas-MAIN\mb_full_manifest.json',
  [string]$ThemeVersion = '20260723quantum',
  [string]$ThemeBase = 'https://thiagodzzzz.github.io/quantum-descripciones-main'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
function HE([string]$s){ [System.Web.HttpUtility]::HtmlEncode($s) }

# Tabla de chipsets -> vendor / socket / ddr por defecto
$CHIPSETS = @{}
foreach($c in 'A320','B350','X370','A520','B450','X470','B550','X570'){ $CHIPSETS[$c]=@{v='AMD';s='AM4';ddr='DDR4'} }
foreach($c in 'A620','B650','X670','B840','B850','X870'){ $CHIPSETS[$c]=@{v='AMD';s='AM5';ddr='DDR5'} }
foreach($c in 'H310','B360','H370','Z370','B365','Z390','H110','B150','B250','Z170','Z270'){ $CHIPSETS[$c]=@{v='Intel';s='LGA1151';ddr='DDR4'} }
foreach($c in 'H410','B460','H470','Z490','H510','B560','H570','Z590'){ $CHIPSETS[$c]=@{v='Intel';s='LGA1200';ddr='DDR4'} }
foreach($c in 'H610','B660','H670','Z690','H770','B760','Z790'){ $CHIPSETS[$c]=@{v='Intel';s='LGA1700';ddr=''} }  # DDR4/DDR5 segun modelo
foreach($c in 'H810','B860','Z890','W880'){ $CHIPSETS[$c]=@{v='Intel';s='LGA1851';ddr='DDR5'} }

$BRANDS='ASUS','MSI','GIGABYTE','AORUS','ASROCK','BIOSTAR','COLORFUL','NZXT'

function Get-Brand([string]$t){ foreach($b in $BRANDS){ if($t -match ('(?i)\b'+[regex]::Escape($b)+'\b')){ return $b.ToUpper() } }; return 'QUANTUM HARDSTORE' }
function Test-Outlet([string]$t){ $t -match '(?i)OUTLET|OPENBOX|USADO|OPEN BOX|MINERIA' }
function Is-NotMb([string]$t){ return [bool]($t -match '(?i)\bPROCESADOR\b|\bRYZEN\b\s*\d|\bMODULO\b|BLUETHOOT|BLUETOOTH|\bCOOLER\b|\bDISIPADOR\b') }

function Get-Chipset([string]$t){
  $up=$t.ToUpper()
  # el chipset puede venir pegado a la letra de formato (B850M) o variante (B650E); no exigir boundary final
  foreach($m in [regex]::Matches($up,'\b([ABHXZW]\d{3})(E)?')){
    $base=$m.Groups[1].Value
    $withE=$base + $m.Groups[2].Value
    if($CHIPSETS.ContainsKey($withE)){ return $withE }
    if($CHIPSETS.ContainsKey($base)){ return $base }
  }
  return ''
}
function Get-Socket([string]$t){
  if($t -match '(?i)\bAM5\b'){ return 'AM5' }
  if($t -match '(?i)\bAM4\b'){ return 'AM4' }
  $m=[regex]::Match($t,'(?i)LGA\s*(\d{4})'); if($m.Success){ return 'LGA'+$m.Groups[1].Value }
  if($t -match '(?i)\b(\d{4})\b\s*(?:\(|DDR|$)' ){ } # fallback abajo
  return ''
}
function Get-Ddr([string]$t){ $m=[regex]::Match($t,'(?i)\bDDR([45])\b'); if($m.Success){ return 'DDR'+$m.Groups[1].Value }; return '' }
function Get-Form([string]$t){
  $up=$t.ToUpper()
  if($up -match '\bE-?ATX\b'){ return 'E-ATX' }
  if($up -match '\b[ABHXZW]\d{3}E?I\b' -or $up -match '\bMINI-?ITX\b' -or $up -match '\bITX\b'){ return 'Mini-ITX' }
  if($up -match '\b[ABHXZW]\d{3}E?M\b' -or $up -match 'MICRO-?ATX|\bMATX\b|\bM-ATX\b'){ return 'Micro-ATX' }
  return 'ATX'
}
function Has-Wifi([string]$t){ return [bool]($t -match '(?i)\bWIFI\b|\bWI-FI\b|WIFI6E|WIFI6|WIFI7|\bAX\b|\bAC\b') }
function Platform-Text([string]$socket){
  switch -Regex ($socket){
    'AM5'      { return 'AMD Ryzen Serie 7000/8000/9000 (AM5)' }
    'AM4'      { return 'AMD Ryzen (AM4)' }
    'LGA1851'  { return 'Intel Core Ultra Serie 2 (LGA1851)' }
    'LGA1700'  { return 'Intel Core 12/13/14 gen (LGA1700)' }
    'LGA1200'  { return 'Intel Core 10/11 gen (LGA1200)' }
    'LGA1151'  { return 'Intel Core 8/9 gen (LGA1151)' }
    default    { return 'Segun socket del modelo' }
  }
}

$template = @'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{TITLE}} - Quantum Hardstore</title>
  <link rel="stylesheet" href="../quantum-products-theme.css">
  <script src="{{THEME_BASE}}/quantum-theme-switch.js?v={{THEME_VERSION}}" defer></script>
</head>
<body>
<div class="container">
  <header class="qh-header"><div class="brand">Quantum Hardstore</div><div class="maker">{{MAKER}}</div><h1>{{H1}}</h1><div class="subtitle">{{SUBTITLE}}</div></header>
  <div class="badge-row" aria-label="Caracteristicas principales">
    {{BADGES}}
  </div>
  <section class="hero-metric"><div class="metric-box"><div class="metric-label">Plataforma</div><div class="metric-value">{{CHIPSET}}</div><div class="metric-desc">{{HERO_DESC}}</div></div></section>
  <section class="card-grid" aria-label="Resumen"><article class="info-card"><div class="label">CPU</div><div class="value">{{SOCKET}}</div><div class="desc">{{CPUPLAT}}. Revisar BIOS y lista oficial de soporte.</div></article><article class="info-card"><div class="label">Memoria</div><div class="value">{{MEM}}</div><div class="desc">Tipo de RAM compatible declarado para este modelo.</div></article><article class="info-card"><div class="label">Formato</div><div class="value">{{FORM}}</div><div class="desc">Verificar gabinete, cooler y distribucion interna.</div></article></section>
  <section class="section"><h2 class="section-title">Especificaciones clave</h2><p class="section-sub">Resumen oficial enfocado en compatibilidad real: procesador, memoria, formato y conectividad.</p><div class="spec-grid">
      <article class="spec-card"><div class="spec-name">Chipset</div><div class="spec-value">{{CHIPSET}}</div><div class="spec-note">Plataforma principal de la motherboard.</div></article>
      <article class="spec-card"><div class="spec-name">Socket</div><div class="spec-value">{{SOCKET}}</div><div class="spec-note">Compatibilidad fisica del procesador.</div></article>
      <article class="spec-card"><div class="spec-name">Procesadores</div><div class="spec-value">{{CPUPLAT}}</div><div class="spec-note">Verificar lista oficial de CPU y BIOS.</div></article>
      <article class="spec-card"><div class="spec-name">Memoria</div><div class="spec-value">{{MEM}}</div><div class="spec-note">Tipo de RAM soportada por el modelo.</div></article>
      <article class="spec-card"><div class="spec-name">Formato</div><div class="spec-value">{{FORM}}</div><div class="spec-note">Verificar espacio y soportes del gabinete.</div></article>
      <article class="spec-card"><div class="spec-name">Conectividad</div><div class="spec-value">{{WIFI}}</div><div class="spec-note">WiFi solo si el modelo lo declara.</div></article>
      <article class="spec-card"><div class="spec-name">Expansion</div><div class="spec-value">PCIe segun chipset/modelo</div><div class="spec-note">Ranuras PCIe segun chipset y modelo.</div></article>
      <article class="spec-card"><div class="spec-name">Storage</div><div class="spec-value">M.2 / SATA segun modelo</div><div class="spec-note">Cantidad exacta segun revision/ficha del fabricante.</div></article>
    </div></section>
  <section class="section dark"><h2 class="section-title">Compatibilidad y conectores</h2><p class="section-sub">Datos principales para validar armado antes de comprar. Las cantidades exactas pueden variar por revision.</p><div class="conn-grid">
      <article class="conn-card"><div class="conn-count">1</div><div class="conn-name">CPU / Socket</div><div class="conn-desc">{{SOCKET}}</div></article>
      <article class="conn-card"><div class="conn-count">segun modelo</div><div class="conn-name">Memoria</div><div class="conn-desc">{{MEM}}</div></article>
      <article class="conn-card"><div class="conn-count">segun modelo</div><div class="conn-name">M.2 / SATA</div><div class="conn-desc">Almacenamiento interno</div></article>
      <article class="conn-card"><div class="conn-count">segun modelo</div><div class="conn-name">PCIe</div><div class="conn-desc">Placa de video y expansion</div></article>
      <article class="conn-card"><div class="conn-count">segun modelo</div><div class="conn-name">USB / Red</div><div class="conn-desc">{{WIFI}}</div></article>
      <article class="conn-card"><div class="conn-count">{{FORM}}</div><div class="conn-name">Formato</div><div class="conn-desc">Compatibilidad de gabinete</div></article>
    </div></section>
  {{STATUS_BOX}}
  <div class="note">{{NOTE}}</div>
</div>
</body>
</html>
'@

$odoo = Get-Content $OdooJson -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$manifest=@(); $gen=0; $noChip=@(); $skip=@()
foreach($p in @($odoo.products)){
  $title=[string]$p.title; $id=[int]$p.id
  if(Is-NotMb $title){ $skip += "$id | $title"; continue }
  $outlet=Test-Outlet $title
  $brand=Get-Brand $title
  $chip=Get-Chipset $title
  $socket=Get-Socket $title
  $ddr=Get-Ddr $title
  $form=Get-Form $title
  $wifi= if(Has-Wifi $title){'WiFi integrado (segun modelo)'}else{'Sin WiFi declarado'}

  # completar socket/ddr desde chipset
  if($chip -and $CHIPSETS.ContainsKey($chip)){
    if(-not $socket){ $socket=$CHIPSETS[$chip].s }
    if(-not $ddr -and $CHIPSETS[$chip].ddr){ $ddr=$CHIPSETS[$chip].ddr }
  }
  if(-not $chip){ $noChip += "$id | $title" }
  if(-not $ddr){
    if($socket -eq 'LGA1700'){ $ddr='DDR4/DDR5 segun modelo' }
    elseif($socket){ $ddr='Segun modelo' } else { $ddr='Segun modelo' }
  }
  $chipShow= if($chip){$chip}else{'Segun modelo'}
  $socketShow= if($socket){$socket}else{'Segun modelo'}
  $plat=Platform-Text $socket
  $cond= if($outlet){'Outlet'}else{'Nuevo'}

  $badges=@()
  if($chip){$badges+=$chip}
  if($socket){$badges+=$socket}
  if($ddr -and $ddr -notmatch 'Segun'){$badges+=$ddr}
  if($form){$badges+=$form}
  if(Has-Wifi $title){$badges+='WiFi'}
  $badges+=$cond
  $badgeHtml=($badges | ForEach-Object { "<span class=`"badge`">$(HE $_)</span>" }) -join "`n    "

  $heroDesc="Motherboard $form" + $(if($socket){" para $plat"}else{''}) + $(if($ddr -notmatch 'Segun'){", memoria $ddr"}else{''}) + ", con conectividad segun ficha oficial del modelo."
  $titleClean=($title -replace '(?i)\s*\((OUTLET|OPENBOX|Caja Original|NUEVA|NUEVO)\)\s*',' ').Trim()
  $titleClean=($titleClean -replace '(?i)^\s*OUTLET\s+','').Trim()
  $subParts=@()
  if($chip){$subParts+=$chip}
  if($socket){$subParts+=$socket}
  if($ddr -notmatch 'Segun'){$subParts+=$ddr}
  $subParts+=$form
  if($outlet){$subParts+='OUTLET'}
  $subtitle=($subParts -join ' / ')

  if($outlet){
    $statusBox='<div class="status-box"><div class="status-title">Producto outlet</div><div class="status-text">Unidad outlet revisada por Quantum Hardstore. Estado y stock sujetos a confirmacion. Consultar disponibilidad antes de abonar.</div></div>'
  } else { $statusBox='' }  # deposito lo inyecta el theme-switch global
  $note="* Specs derivadas de la denominacion oficial del modelo $brand y del chipset declarado. Cantidades exactas de puertos, M.2/SATA y VRM segun hoja tecnica del fabricante. Verificar revision, BIOS y lista oficial de CPU/memoria antes de instalar."
  $maker="$brand Motherboards"

  $file="mb-$('{0:D5}' -f $id).html"
  $html=$template
  $repl=@{
    '{{TITLE}}'=(HE $title);'{{MAKER}}'=(HE $maker);'{{H1}}'=(HE $titleClean);'{{SUBTITLE}}'=(HE $subtitle)
    '{{BADGES}}'=$badgeHtml;'{{CHIPSET}}'=(HE $chipShow);'{{HERO_DESC}}'=(HE $heroDesc)
    '{{SOCKET}}'=(HE $socketShow);'{{CPUPLAT}}'=(HE $plat);'{{MEM}}'=(HE $ddr);'{{FORM}}'=(HE $form);'{{WIFI}}'=(HE $wifi)
    '{{STATUS_BOX}}'=$statusBox;'{{NOTE}}'=(HE $note)
    '{{THEME_BASE}}'=$ThemeBase;'{{THEME_VERSION}}'=$ThemeVersion
  }
  foreach($k in $repl.Keys){ $html=$html.Replace($k,[string]$repl[$k]) }
  Set-Content -LiteralPath (Join-Path $OutDir $file) -Value $html -Encoding UTF8

  $iframe="<iframe src=`"$ThemeBase/MOTHERBOARDS/${file}?v=$ThemeVersion`" style=`"width:100%;height:2400px;border:0;`" loading=`"lazy`"></iframe>"
  $manifest += [pscustomobject]@{
    OdooId=$id; Title=$title; Sku=[string]$p.internalReference; File=$file
    Chipset=$chip; Socket=$socket; Ddr=$ddr; Form=$form; Outlet=$outlet
    Matched=$true; iframe=$iframe
  }
  $gen++
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$noChip | Set-Content -LiteralPath (Join-Path (Split-Path $ManifestPath -Parent) 'mb_sin_chipset.txt') -Encoding UTF8
$skip | Set-Content -LiteralPath (Join-Path (Split-Path $ManifestPath -Parent) 'mb_no_mother.txt') -Encoding UTF8
Write-Host ("Generadas: {0} | Sin chipset: {1} | No-mother salteadas: {2}" -f $gen, @($noChip).Count, @($skip).Count)
Write-Host ("Manifest: {0}" -f $ManifestPath)
