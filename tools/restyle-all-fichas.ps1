#Requires -Version 5.1
<#
.SYNOPSIS
  Reescribe fichas al diseno Quantum products (RAM Kingston / quantum-products-theme.css)
  con specs oficiales o derivadas del titulo/SKU. Excluye PCs armadas y workstations.
#>
param(
  [string]$Root = '',
  [string]$Coverage = '.\audits\odoo-coverage-20260923.json',
  [string]$SpecsDb = '.\tools\gpu-specs-db.json',
  [string]$ThemeVersion = '20261014ficha',
  [string]$ThemeBase = 'https://thiagodzzzz.github.io/quantum-descripciones-main',
  [string]$ManifestPath = '.\audits\restyle-20261014-manifest.json',
  [int]$Limit = 0,
  [int[]]$OnlyIds = @(),
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
Set-Location $Root
$utf8 = New-Object System.Text.UTF8Encoding $false
function HE([string]$s) { if ($null -eq $s) { return '' }; [System.Web.HttpUtility]::HtmlEncode($s) }

$BRANDS = @(
  'ASUS','ROG','MSI','GIGABYTE','AORUS','ASROCK','SAPPHIRE','POWERCOLOR','ZOTAC','PALIT','EVGA','XFX','PNY','GAINWARD',
  'HYPERX','LOGITECH','RAZER','REDRAGON','CORSAIR','STEELSERIES','KINGSTON','CRUCIAL','SAMSUNG','ADATA','XPG',
  'PATRIOT','TEAMGROUP','TEAM GROUP','G.SKILL','GSKILL','ZOWIE','BENQ','COOLER MASTER','INTEL','AMD',
  'DEEPCOOL','THERMALTAKE','NZXT','LIAN LI','FRACTAL','PHANTEKS','AEROCOOL','SEASONIC','BE QUIET','ANTEC',
  'TP-LINK','TPLINK','MERCUSYS','UBIQUITI','MIKROTIK','CISCO','HP','DELL','LENOVO','EPSON','BROTHER','CANON',
  'WESTERN DIGITAL','WD','SEAGATE','TOSHIBA','KINGSTON FURY','NOGA','GENIUS','PHILIPS','JBL','SONY','ELGATO',
  'KEYCHRON','DUCKY','PULSAR','GLORIOUS','COUGAR','HALION','ARKTEK','GAMEMAX','SENTEY','KOLINK','APC','EATON'
)
$SKIP_BRAND = @('MOUSE','TECLADO','AURICULAR','GAMER','GAMING','KIT','OUTLET','NUEVO','NUEVA','MEMORIA','RAM','PLACA','MOTHER','FUENTE','GPU','PC')

function Get-Brand([string]$t) {
  foreach ($b in $BRANDS) {
    if ($t -match ('(?i)\b' + [regex]::Escape($b) + '\b')) { return $b.ToUpper() }
  }
  $tok = ($t -split '\s+' | Where-Object { $_.Length -ge 3 -and ($SKIP_BRAND -notcontains $_.ToUpperInvariant()) -and $_ -notmatch '^\d' } | Select-Object -First 1)
  if ($tok) { return $tok.ToUpper() }
  return 'QUANTUM'
}
function Test-Outlet([string]$t) { $t -match '(?i)OUTLET|OPENBOX|USADO|OPEN BOX' }
function Test-JunkGpu([string]$t) {
  $t -match '(?i)Pasta\s*T|Fan\s*Cooler|E2E\s*T66|Notebook|iCUE\s*LINK|^\s*Fuente\b|\bFUENTE\b|WATER\s*COOLER|KIT WATER|adaptador VGA|DVI'
}
function Test-AssembledPc([string]$categ, [string]$title, [string]$rel) {
  if ($rel -match '(?i)PCS-GAMER|WORKSTATIONS|pc-gamer-|[/\\]ws-\d') { return $true }
  if ($categ -match '(?i)Hardware\s*/\s*PCs|PCs?\s*Armad|Workstation') { return $true }
  if ($title -match '(?i)^\s*(PC|WS)\s+(GAMER|ARMAD|WORK)') { return $true }
  return $false
}
function Get-CssHref([string]$FilePath) {
  $dir = [IO.Path]::GetDirectoryName($FilePath)
  $rel = $dir.Substring($Root.Length).TrimStart('\','/')
  if (-not $rel) { return 'quantum-products-theme.css' }
  $n = @($rel -split '[\\/]' | Where-Object { $_ }).Count
  return (('../' * $n) + 'quantum-products-theme.css')
}
function Get-PagesRel([string]$FilePath) {
  $rel = $FilePath.Substring($Root.Length).TrimStart('\','/')
  return ($rel -replace '\\','/')
}
function Get-OdooId([string]$name) {
  $m = [regex]::Match($name, '(?i)^(gpu|cat|perif|mb|psu)-0*(\d+)\.html$')
  if ($m.Success) { return [int]$m.Groups[2].Value }
  return 0
}
function SpecHtml($name, $value, $note) {
  return "<article class=`"spec-card`"><div class=`"spec-name`">$(HE $name)</div><div class=`"spec-value`">$(HE $value)</div><div class=`"spec-note`">$(HE $note)</div></article>"
}
function InfoHtml($label, $value, $desc) {
  return "<article class=`"info-card`"><div class=`"label`">$(HE $label)</div><div class=`"value`">$(HE $value)</div><div class=`"desc`">$(HE $desc)</div></article>"
}
function ConnHtml($count, $name, $desc) {
  return "<article class=`"conn-card`"><div class=`"conn-count`">$(HE $count)</div><div class=`"conn-name`">$(HE $name)</div><div class=`"conn-desc`">$(HE $desc)</div></article>"
}
function BadgeHtml([string[]]$items) {
  $seen = @{}
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($x in $items) {
    if ([string]::IsNullOrWhiteSpace($x)) { continue }
    $k = $x.ToUpperInvariant()
    if ($seen.ContainsKey($k)) { continue }
    $seen[$k] = $true
    $out.Add("<span class=`"badge`">$(HE $x)</span>")
  }
  return ($out -join "`n    ")
}

$CHIPSETS = @{}
foreach ($c in 'A320','B350','X370','A520','B450','X470','B550','X570') { $CHIPSETS[$c] = @{ v='AMD'; s='AM4'; ddr='DDR4' } }
foreach ($c in 'A620','B650','X670','B840','B850','X870') { $CHIPSETS[$c] = @{ v='AMD'; s='AM5'; ddr='DDR5' } }
foreach ($c in 'H310','B360','H370','Z370','B365','Z390','H110','B150','B250','Z170','Z270') { $CHIPSETS[$c] = @{ v='Intel'; s='LGA1151'; ddr='DDR4' } }
foreach ($c in 'H410','B460','H470','Z490','H510','B560','H570','Z590') { $CHIPSETS[$c] = @{ v='Intel'; s='LGA1200'; ddr='DDR4' } }
foreach ($c in 'H610','B660','H670','Z690','W680','H770','B760','Z790') { $CHIPSETS[$c] = @{ v='Intel'; s='LGA1700'; ddr='' } }
foreach ($c in 'H810','B860','Z890','W880') { $CHIPSETS[$c] = @{ v='Intel'; s='LGA1851'; ddr='DDR5' } }

function Get-MbChipset([string]$t) {
  $up = $t.ToUpper()
  foreach ($m in [regex]::Matches($up, '\b([ABHXZW]\d{3})(E)?')) {
    $base = $m.Groups[1].Value; $withE = $base + $m.Groups[2].Value
    if ($CHIPSETS.ContainsKey($withE)) { return $withE }
    if ($CHIPSETS.ContainsKey($base)) { return $base }
  }
  return ''
}
function Get-MbSocket([string]$t) {
  if ($t -match '(?i)\bAM5\b') { return 'AM5' }
  if ($t -match '(?i)\bAM4\b') { return 'AM4' }
  $m = [regex]::Match($t, '(?i)LGA\s*(\d{4})'); if ($m.Success) { return 'LGA' + $m.Groups[1].Value }
  return ''
}
function Get-MbForm([string]$t) {
  $up = $t.ToUpper()
  if ($up -match '\bE-?ATX\b') { return 'E-ATX' }
  if ($up -match '\bMINI-?ITX\b|\bITX\b|\b[ABHXZW]\d{3}E?I\b') { return 'Mini-ITX' }
  if ($up -match 'MICRO-?ATX|\bMATX\b|\bM-ATX\b|\b[ABHXZW]\d{3}E?M\b') { return 'Micro-ATX' }
  return 'ATX'
}
function Get-Platform([string]$socket) {
  switch -Regex ($socket) {
    'AM5'     { return 'AMD Ryzen Serie 7000/8000/9000 (AM5)' }
    'AM4'     { return 'AMD Ryzen (AM4)' }
    'LGA1851' { return 'Intel Core Ultra Serie 2 (LGA1851)' }
    'LGA1700' { return 'Intel Core 12/13/14 gen (LGA1700)' }
    'LGA1200' { return 'Intel Core 10/11 gen (LGA1200)' }
    'LGA1151' { return 'Intel Core 8/9 gen (LGA1151)' }
    default   { return 'Segun socket del modelo' }
  }
}

function Get-PsuWatt([string]$t) {
  $m = [regex]::Match($t, '(?i)(\d{3,4})\s*(?:WATT|WATTS)\b'); if ($m.Success) { return [int]$m.Groups[1].Value }
  $m = [regex]::Match($t, '(?i)(\d{3,4})\s*W(?![A-Z0-9]{3,})'); if ($m.Success) { return [int]$m.Groups[1].Value }
  $cands = @()
  foreach ($mm in [regex]::Matches($t, '\d{3,4}')) {
    $v = [int]$mm.Value
    if ($v -ge 250 -and $v -le 2000 -and ($v % 50 -eq 0)) { $cands += $v }
  }
  if ($cands.Count) { return ($cands | Sort-Object -Descending)[0] }
  return 0
}
function Get-PsuEff([string]$t) {
  if ($t -match '(?i)TITANIUM') { return '80 PLUS Titanium' }
  if ($t -match '(?i)PLATINUM') { return '80 PLUS Platinum' }
  if ($t -match '(?i)\bGOLD\b') { return '80 PLUS Gold' }
  if ($t -match '(?i)\bSILVER\b') { return '80 PLUS Silver' }
  if ($t -match '(?i)\bBRONZE\b') { return '80 PLUS Bronze' }
  if ($t -match '(?i)\bWHITE\b|80\s*PLUS') { return '80 PLUS' }
  return ''
}

function Resolve-Chip([string]$Title, $Chips) {
  $names = @($Chips.PSObject.Properties.Name)
  $raw = $Title.ToUpper() -replace '\(TM\)|\(R\)|\(C\)',' '
  $raw = $raw -replace 'GEFORCERTX','GEFORCE RTX' -replace 'GEFORCEGTX','GEFORCE GTX'
  $t = ' ' + (($raw -replace '[^A-Z0-9]', ' ') -replace '\s+', ' ') + ' '
  $preferAmd = (($Title -match '(?i)\b(XFX|Sapphire|PowerColor)\b') -or ($Title -match '(?i)Radeon|\bRX\b')) -and ($Title -notmatch '(?i)\bRTX\b|\bGTX\b|\bGeForce\b')
  $m = [regex]::Match($t, '\bRTX\s*PRO\s*(\d{4})\b'); if ($m.Success) { $k = "RTX PRO $($m.Groups[1].Value)"; if ($names -contains $k) { return $k } }
  $m = [regex]::Match($t, '\b(?:QUADRO\s+)?RTX\s*A(\d{3,4})\b'); if ($m.Success) { $k = "RTX A$($m.Groups[1].Value)"; if ($names -contains $k) { return $k } }
  $m = [regex]::Match($t, '\b(RTX|GTX|GT)\s*(\d{3,4})\s*(TI)?\s*(SUPER)?\b')
  if ($m.Success -and -not $preferAmd) {
    $fam=$m.Groups[1].Value; $num=$m.Groups[2].Value; $ti=[bool]$m.Groups[3].Value; $su=[bool]$m.Groups[4].Value
    $key="$fam $num"; if ($ti -and $su) { $key="$fam $num Ti Super" } elseif ($ti) { $key="$fam $num Ti" } elseif ($su) { $key="$fam $num Super" }
    if ($names -contains $key) { return $key }
  }
  $m = [regex]::Match($t, '\b(RTX|GTX|GT)(\d{3,4})(TI)?(SUPER)?\b')
  if ($m.Success -and -not $preferAmd) {
    $fam=$m.Groups[1].Value; $num=$m.Groups[2].Value; $ti=[bool]$m.Groups[3].Value; $su=[bool]$m.Groups[4].Value
    $key="$fam $num"; if ($ti -and $su) { $key="$fam $num Ti Super" } elseif ($ti) { $key="$fam $num Ti" } elseif ($su) { $key="$fam $num Super" }
    if ($names -contains $key) { return $key }
  }
  $m = [regex]::Match($t, '\bRX\s*(\d{3,4})\s*(XTX|XT|GRE)?\b')
  if ($m.Success) {
    $num=$m.Groups[1].Value; $suf=$m.Groups[2].Value.Trim(); $key="RX $num"
    if ($suf -eq 'XTX') { $key="RX $num XTX" } elseif ($suf -eq 'XT') { $key="RX $num XT" }
    if ($names -contains $key) { return $key }
    if ($names -contains "RX $num") { return "RX $num" }
  }
  if ($Title -match '(?i)\b6900\s*XT\b') { if ($names -contains 'RX 6900 XT') { return 'RX 6900 XT' } }
  $m = [regex]::Match($t, '\b(\d{3,4})\s*(TI\s*SUPER|TI|SUPER|XTX|XT)?\b')
  while ($m.Success) {
    $num=$m.Groups[1].Value; $suf=($m.Groups[2].Value -replace '\s+',' ').Trim(); $cands=@()
    if ($suf -match 'XT') { if ($suf -eq 'XTX') { $cands += "RX $num XTX" }; $cands += "RX $num XT"; $cands += "RX $num" }
    elseif ($suf -match 'TI|SUPER') {
      foreach ($fam in 'RTX','GTX') {
        if ($suf -match 'TI SUPER') { $cands += "$fam $num Ti Super" }
        elseif ($suf -eq 'TI') { $cands += "$fam $num Ti" }
        else { $cands += "$fam $num Super" }
      }
    } else { foreach ($fam in 'RTX','GTX','GT') { $cands += "$fam $num" }; $cands += "RX $num" }
    foreach ($c in $cands) { if ($names -contains $c) { return $c } }
    $m = $m.NextMatch()
  }
  return $null
}

function Parse-Ram([string]$title, [string]$sku) {
  $r = @{ gen=''; cap=''; speed=''; cl=''; volt=''; form=''; profile=''; color=''; model=$sku }
  $blob = "$title $sku"
  $m = [regex]::Match($blob, '(?i)\bDDR\s*([45])\b'); if ($m.Success) { $r.gen = 'DDR' + $m.Groups[1].Value }
  $m = [regex]::Match($blob, '(?i)\b(8|16|24|32|48|64|96|128)\s*GB\b'); if ($m.Success) { $r.cap = $m.Groups[1].Value + 'GB' }
  $m = [regex]::Match($blob, '(?i)\b(2400|2666|3000|3200|3600|4000|4800|5200|5600|6000|6400|6800|7200|7600|8000|8400)\s*(MHZ|MT/?S|MTS)?\b')
  if ($m.Success) { $r.speed = $m.Groups[1].Value + 'MT/s' }
  $m = [regex]::Match($blob, '(?i)\bCL\s*(\d{2})\b'); if ($m.Success) { $r.cl = 'CL' + $m.Groups[1].Value }
  $m = [regex]::Match($sku, '(?i)^KF([45])(\d{2})C(\d{2})([A-Z]*)-?(\d{1,2})$')
  if ($m.Success) {
    $r.gen = 'DDR' + $m.Groups[1].Value
    $spd = [int]$m.Groups[2].Value; if ($spd -lt 100) { $spd = $spd * 100 }
    $r.speed = "$spd" + 'MT/s'
    $r.cl = 'CL' + $m.Groups[3].Value
    $code = $m.Groups[4].Value.ToUpper()
    $capn = $m.Groups[5].Value
    if (-not $r.cap) { $r.cap = $capn + 'GB' }
    $r.model = $sku
    if ($code -match 'S') { $r.form = 'SODIMM notebook' } else { $r.form = '288-pin DIMM' }
    if ($code -match 'E') { $r.profile = 'Intel XMP 3.0 / AMD EXPO' } elseif ($r.gen -eq 'DDR5') { $r.profile = 'Intel XMP 3.0' } else { $r.profile = 'XMP' }
    if ($code -match 'R') { $r.color = 'RGB' } else { $r.color = 'Black' }
    if ($r.gen -eq 'DDR5' -and $spd -ge 4800 -and $spd -le 6000) { $r.volt = '1.25V' }
    elseif ($r.gen -eq 'DDR4') { $r.volt = '1.35V' }
  }
  if (-not $r.form) {
    if ($blob -match '(?i)SODIMM|SO-DIMM|NOTEBOOK') { $r.form = 'SODIMM notebook' }
    elseif ($blob -match '(?i)UDIMM|DIMM|DESKTOP|ESCRITORIO|FURY BEAST|RENEGADE') { $r.form = 'DIMM desktop' }
  }
  if (-not $r.profile) {
    if ($blob -match '(?i)EXPO') { $r.profile = 'AMD EXPO' }
    elseif ($blob -match '(?i)XMP') { $r.profile = 'XMP' }
  }
  if ($blob -match '(?i)\bRGB\b') { $r.color = 'RGB' }
  elseif ($blob -match '(?i)BLACK|NEGRO') { $r.color = 'Black' }
  $m = [regex]::Match($blob, '(?i)(1\.[1235]5?)\s*V'); if ($m.Success) { $r.volt = $m.Groups[1].Value + 'V' }
  return $r
}

function Get-Kind([string]$categ, [string]$title, [string]$rel) {
  $c = "$categ $title $rel"
  if ($rel -match '(?i)[/\\]GPUS' -and -not (Test-JunkGpu $title)) { return 'gpu' }
  if ($rel -match '(?i)MOTHERBOARDS' -or $c -match '(?i)motherboard|mother\b') { return 'mb' }
  if ($rel -match '(?i)FUENTES' -or ($c -match '(?i)\bfuente\b|\bpsu\b' -and $c -notmatch '(?i)cable fuente')) { return 'psu' }
  if ($rel -match '(?i)PERIFERICOS' -or $categ -match '(?i)^Perif') { return 'perif' }
  if ($c -match '(?i)memoria|ram|ddr[45]') { return 'ram' }
  if ($c -match '(?i)placa de video|geforce|radeon|\brtx\b|\bgtx\b|\brx\s*\d' -and -not (Test-JunkGpu $title)) { return 'gpu' }
  if ($c -match '(?i)procesador|\bcpu\b|ryzen|core i\d|core ultra') { return 'cpu' }
  if ($c -match '(?i)almacen|ssd|hdd|nvme|m\.2') { return 'storage' }
  if ($c -match '(?i)gabinete|cabinet|\bcase\b') { return 'case' }
  if ($c -match '(?i)refriger|cooler|water cooling|aio') { return 'cooler' }
  if ($c -match '(?i)monitor') { return 'monitor' }
  if ($c -match '(?i)red|router|switch|access point') { return 'redes' }
  return 'generic'
}

$TEMPLATE = @'
<!DOCTYPE html>
<html lang="es"{{OUTLET_ATTR}}>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{TITLE}} - Quantum Hardstore</title>
  <link rel="stylesheet" href="{{CSS_HREF}}">
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
  <div class="badge-row" aria-label="Caracteristicas principales">
    {{BADGES}}
  </div>
  <section class="hero-metric">
    <div class="metric-box">
      <div class="metric-label">{{HERO_LABEL}}</div>
      <div class="metric-value">{{HERO_VALUE}}</div>
      <div class="metric-desc">{{HERO_DESC}}</div>
    </div>
  </section>
  <section class="card-grid" aria-label="Resumen">{{INFO}}</section>
  <section class="section">
    <h2 class="section-title">Especificaciones clave</h2>
    <p class="section-sub">{{SPEC_SUB}}</p>
    <div class="spec-grid">{{SPECS}}</div>
  </section>
  <section class="section dark">
    <h2 class="section-title">{{CONN_TITLE}}</h2>
    <p class="section-sub">{{CONN_SUB}}</p>
    <div class="conn-grid">{{CONNS}}</div>
  </section>
  {{STATUS_BOX}}
  <div class="note">{{NOTE}}</div>
</div>
</body>
</html>
'@

function New-FichaHtml($d) {
  $html = $TEMPLATE
  foreach ($k in $d.Keys) { $html = $html.Replace('{{' + $k + '}}', [string]$d[$k]) }
  return $html
}

function Build-Ficha($meta) {
  $title = [string]$meta.title
  $sku = [string]$meta.sku
  $categ = [string]$meta.categ
  $kind = [string]$meta.kind
  $brand = Get-Brand $title
  $outlet = Test-Outlet $title
  $cond = if ($outlet) { 'Outlet' } else { 'Nuevo' }
  $titleClean = ($title -replace '(?i)\s*\((OUTLET|OPENBOX|NUEVA|NUEVO|Caja Original)\)\s*', ' ').Trim()
  $titleClean = ($titleClean -replace '(?i)^\s*OUTLET\s+', '').Trim()
  $status = if ($outlet) {
    '<div class="status-box"><div class="status-title">Producto outlet</div><div class="status-text">Unidad outlet revisada por Quantum Hardstore. Estado y stock sujetos a confirmacion. Consultar disponibilidad antes de abonar.</div></div>'
  } else { '' }
  $d = @{
    OUTLET_ATTR = $(if ($outlet) { ' data-outlet="1"' } else { '' })
    TITLE = HE $title
    CSS_HREF = $meta.css
    THEME_BASE = $ThemeBase
    THEME_VERSION = $ThemeVersion
    H1 = HE $titleClean
    STATUS_BOX = $status
  }

  switch ($kind) {
    'gpu' {
      $chip = Resolve-Chip $title $script:chips
      $s = $null; if ($chip) { $s = $script:chips.$chip }
      $vram = $null
      $m = [regex]::Match($title.ToUpper(), '(\d{1,2})\s*GB\b'); if ($m.Success) { $vram = $m.Groups[1].Value + ' GB' }
      if (-not $vram -and $s) { $vram = [string]$s.vram }
      if (-not $vram) { $vram = 'Segun modelo' }
      $badges = @()
      if ($chip) { $badges += $chip }
      $badges += $vram, $brand, $cond
      if ($s -and $chip -like 'RTX *') { $badges += 'Ray Tracing'; if ($chip -match 'RTX 50') { $badges += 'DLSS 4' } elseif ($chip -match 'RTX 40') { $badges += 'DLSS 3' } else { $badges += 'DLSS' } }
      if ($s -and $chip -like 'RX *' -and $s.arch -match 'RDNA') { $badges += 'Ray Tracing' }
      $d.MAKER = HE ("$brand / " + $(if ($s) { $s.brandChip } else { 'Placa de video' }))
      $d.SUBTITLE = HE ((($chip, $vram, $(if ($s) { $s.arch }), $cond) | Where-Object { $_ }) -join ' / ')
      $d.BADGES = BadgeHtml $badges
      $d.HERO_LABEL = 'Memoria de video'
      $d.HERO_VALUE = HE $vram
      $d.HERO_DESC = HE $(if ($chip -and $s) { "$chip de $($s.brandChip). Specs de chip segun ficha oficial; el modelo AIB puede variar clocks y disipacion." } else { "Placa de video $brand. Specs de chip no identificadas en la base oficial; datos del listado." })
      $d.INFO = (InfoHtml 'Chip' $(if ($chip) { $chip } else { 'A confirmar' }) 'GPU de referencia.') + (InfoHtml 'VRAM' $vram 'Capacidad de memoria de video.') + (InfoHtml 'TDP' $(if ($s) { [string]$s.tdp } else { 'Segun modelo' }) 'Consumo declarado del chip.')
      $d.SPEC_SUB = 'Datos segun ficha oficial del fabricante del chip. Clocks de fabrica del modelo AIB pueden diferir.'
      $specs = @(
        (SpecHtml 'Arquitectura' $(if ($s) { [string]$s.arch } else { 'Segun ficha del modelo' }) 'Generacion del GPU.'),
        (SpecHtml 'Proceso' $(if ($s) { [string]$s.process } else { 'Segun ficha del modelo' }) 'Nodo de fabricacion.'),
        (SpecHtml $(if ($s) { [string]$s.coreLabel } else { 'Nucleos' }) $(if ($s) { [string]$s.cores } else { 'Segun ficha del modelo' }) 'Nucleos de sombreado.'),
        (SpecHtml 'Memoria' ($vram + ' ' + $(if ($s) { [string]$s.memType } else { '' })).Trim() 'Capacidad y tipo de VRAM.'),
        (SpecHtml 'Bus de memoria' $(if ($s) { [string]$s.bus } else { 'Segun ficha del modelo' }) 'Ancho del bus.'),
        (SpecHtml 'Boost clock' $(if ($s) { [string]$s.boost } else { 'Segun ficha del modelo' }) 'Frecuencia de referencia del chip.'),
        (SpecHtml 'Consumo (TDP)' $(if ($s) { [string]$s.tdp } else { 'Segun ficha del modelo' }) 'Potencia declarada del chip.'),
        (SpecHtml 'Interfaz' $(if ($s) { [string]$s.pcie } else { 'PCIe' }) 'Version de PCI Express.')
      )
      if ($sku) { $specs += SpecHtml 'SKU' $sku 'Referencia Quantum / fabricante.' }
      $d.SPECS = ($specs -join "`n      ")
      $d.CONN_TITLE = 'Requisitos y armado'
      $d.CONN_SUB = 'Lo necesario para instalarla en el equipo.'
      $d.CONNS = (ConnHtml $(if ($s) { [string]$s.psu } else { 'Segun GPU' }) 'Fuente recomendada' 'Potencia de PSU sugerida por el fabricante para el sistema.') +
        (ConnHtml 'Power' 'Alimentacion' $(if ($s) { [string]$s.power } else { 'Conectores segun modelo AIB.' })) +
        (ConnHtml 'Video' 'Salidas' $(if ($s) { [string]$s.outputs } else { 'DP / HDMI segun modelo.' }))
      $d.NOTE = HE $(if ($s) { "* Specs de chip desde ficha oficial $($s.brandChip) $chip. El modelo $brand puede variar boost y conectores. Compatibilidad final segun fuente, gabinete y monitor." } else { "* Datos del listado $brand. Completar con hoja oficial del fabricante si el chip no esta en la base." })
    }
    'mb' {
      $chip = Get-MbChipset $title
      $socket = Get-MbSocket $title
      $ddr = ''
      $m = [regex]::Match($title, '(?i)\bDDR([45])\b'); if ($m.Success) { $ddr = 'DDR' + $m.Groups[1].Value }
      if ($chip -and $CHIPSETS.ContainsKey($chip)) {
        if (-not $socket) { $socket = $CHIPSETS[$chip].s }
        if (-not $ddr -and $CHIPSETS[$chip].ddr) { $ddr = $CHIPSETS[$chip].ddr }
      }
      if (-not $ddr -and $socket -eq 'LGA1700') { $ddr = 'DDR4/DDR5 segun modelo' }
      if (-not $ddr) { $ddr = 'Segun modelo' }
      if (-not $socket) { $socket = 'Segun modelo' }
      $form = Get-MbForm $title
      $wifi = $title -match '(?i)\bWIFI\b|WI-FI|WIFI6|WIFI7'
      $plat = Get-Platform $socket
      $chipShow = if ($chip) { $chip } else { 'Segun modelo' }
      $d.MAKER = HE "$brand Motherboards"
      $d.SUBTITLE = HE ((($chip, $socket, $ddr, $form, $cond) | Where-Object { $_ -and $_ -notmatch '^Segun' }) -join ' / ')
      $badges = @($chip, $socket, $(if ($ddr -notmatch 'Segun') { $ddr }), $form, $(if ($wifi) { 'WiFi' }), $cond)
      $d.BADGES = BadgeHtml $badges
      $d.HERO_LABEL = 'Plataforma'
      $d.HERO_VALUE = HE $chipShow
      $d.HERO_DESC = HE "Motherboard $form para $plat, memoria $ddr."
      $d.INFO = (InfoHtml 'CPU' $socket $plat) + (InfoHtml 'Memoria' $ddr 'Tipo de RAM compatible declarado.') + (InfoHtml 'Formato' $form 'Verificar gabinete y cooler.')
      $d.SPEC_SUB = 'Resumen oficial de compatibilidad: procesador, memoria, formato y conectividad.'
      $d.SPECS = ((SpecHtml 'Chipset' $chipShow 'Plataforma de la motherboard.') + (SpecHtml 'Socket' $socket 'Compatibilidad fisica del procesador.') +
        (SpecHtml 'Procesadores' $plat 'Verificar lista oficial de CPU y BIOS.') + (SpecHtml 'Memoria' $ddr 'Tipo de RAM soportada.') +
        (SpecHtml 'Formato' $form 'Espacio y soportes del gabinete.') + (SpecHtml 'Conectividad' $(if ($wifi) { 'WiFi integrado (segun modelo)' } else { 'Sin WiFi declarado' }) 'Red inalambrica solo si el modelo lo declara.') +
        (SpecHtml 'Expansion' 'PCIe segun chipset/modelo' 'Ranuras segun chipset y revision.') + (SpecHtml 'Storage' 'M.2 / SATA segun modelo' 'Cantidad exacta segun ficha del fabricante.'))
      if ($sku) { $d.SPECS += SpecHtml 'SKU' $sku 'Referencia.' }
      $d.CONN_TITLE = 'Compatibilidad y conectores'
      $d.CONN_SUB = 'Validar armado antes de comprar. Cantidades exactas pueden variar por revision.'
      $d.CONNS = (ConnHtml 'CPU' 'Socket' $socket) + (ConnHtml $ddr 'Memoria' 'Slots segun modelo.') + (ConnHtml $form 'Formato' 'Compatibilidad de gabinete.')
      $d.NOTE = HE "* Specs derivadas de la denominacion $brand y del chipset. Puertos, M.2/SATA y VRM segun hoja tecnica. Verificar BIOS y QVL de CPU/RAM."
    }
    'psu' {
      $watt = Get-PsuWatt $title
      $wattStr = if ($watt -gt 0) { "$watt W" } else { 'Segun modelo' }
      $eff = Get-PsuEff $title
      $mod = ''
      if ($title -match '(?i)FULL\s*MODULAR|FULLY\s*MODULAR') { $mod = 'Full modular' }
      elseif ($title -match '(?i)SEMI\s*MODULAR') { $mod = 'Semi modular' }
      elseif ($title -match '(?i)\bMODULAR\b') { $mod = 'Modular' }
      $form = 'ATX'
      if ($title -match '(?i)SFX-?L') { $form = 'SFX-L' } elseif ($title -match '(?i)\bSFX\b') { $form = 'SFX' }
      $atx = ''
      $mm = [regex]::Match($title, '(?i)ATX\s*3\.(\d)'); if ($mm.Success) { $atx = 'ATX 3.' + $mm.Groups[1].Value } elseif ($title -match '(?i)ATX\s*3\b') { $atx = 'ATX 3.0' }
      $pcie5 = $title -match '(?i)PCIE?\s*5|12VHPWR|12V-?2X6|ATX\s*3'
      $d.MAKER = HE "$brand Fuentes"
      $d.SUBTITLE = HE ((($wattStr, $eff, $mod, $form, $cond) | Where-Object { $_ }) -join ' / ')
      $d.BADGES = BadgeHtml @($wattStr, $eff, $mod, $form, $atx, $(if ($pcie5) { 'PCIe 5.x' }), $cond)
      $d.HERO_LABEL = 'Potencia declarada'
      $d.HERO_VALUE = HE $wattStr
      $d.HERO_DESC = HE ("Fuente $brand" + $(if ($watt -gt 0) { " de $wattStr" } else { '' }) + $(if ($eff) { " con $eff" } else { '' }) + '.')
      $d.INFO = (InfoHtml 'Potencia' $wattStr 'Salida nominal declarada.') + (InfoHtml 'Eficiencia' $(if ($eff) { $eff } else { 'Segun modelo' }) 'Certificacion 80 PLUS.') + (InfoHtml 'Formato' $form 'Factor de forma.')
      $d.SPEC_SUB = 'Datos tomados de la denominacion oficial del modelo.'
      $d.SPECS = ((SpecHtml 'Potencia' $wattStr 'Salida nominal.') + (SpecHtml 'Eficiencia' $(if ($eff) { $eff } else { 'Segun ficha del modelo' }) 'Certificacion energetica.') +
        (SpecHtml 'Cableado' $(if ($mod) { $mod } else { 'Segun ficha del modelo' }) 'Gestion de cables.') + (SpecHtml 'Formato' $form 'Factor de forma fisico.') +
        (SpecHtml 'Estandar' $(if ($atx) { $atx } else { 'ATX estandar' }) 'Guia ATX.') + (SpecHtml 'Conector PCIe GPU' $(if ($pcie5) { 'PCIe 5.x / 12VHPWR (ATX 3)' } else { 'PCIe 6+2 segun modelo' }) 'Alimentacion de placa de video.'))
      if ($sku) { $d.SPECS += SpecHtml 'SKU' $sku 'Referencia.' }
      $d.CONN_TITLE = 'Compatibilidad y armado'
      $d.CONN_SUB = 'Elegir e instalar la fuente segun consumo real.'
      $d.CONNS = (ConnHtml $wattStr 'Presupuesto' 'Verificar CPU + GPU + perifericos y dejar margen.') + (ConnHtml $form 'Gabinete' 'Confirmar espacio y anclaje.') + (ConnHtml $(if ($eff) { $eff -replace '80 PLUS ','' } else { '-' }) 'Eficiencia' 'Mejor eficiencia = menos calor a igual carga.')
      $d.NOTE = HE "* Specs derivadas de la denominacion oficial $brand. Conectores y medidas exactas segun hoja tecnica. Compatibilidad final segun gabinete, mother y consumo real."
    }
    'ram' {
      $r = Parse-Ram $title $sku
      $hero = if ($r.speed) { ($r.speed -replace 'MT/s','') } elseif ($r.cap) { $r.cap } else { 'RAM' }
      $d.MAKER = HE "$brand Memorias"
      $d.SUBTITLE = HE ((($r.cap, $r.gen, $r.speed, $r.cl, $r.form, $r.profile, $r.color, $cond) | Where-Object { $_ }) -join ' / ')
      $d.BADGES = BadgeHtml @($r.cap, $r.gen, $r.speed, $r.cl, $r.volt, $r.profile, $r.form, $r.color, $cond)
      $d.HERO_LABEL = $(if ($r.gen) { "Velocidad $($r.gen)" } else { 'Memoria RAM' })
      $d.HERO_VALUE = HE $hero
      $d.HERO_DESC = HE ("Modulo $brand" + $(if ($r.cap) { " de $($r.cap)" } else { '' }) + $(if ($r.gen) { " $($r.gen)" } else { '' }) + $(if ($r.form) { " para $($r.form)." } else { '.' }))
      $d.INFO = (InfoHtml 'Capacidad' $(if ($r.cap) { $r.cap } else { 'Segun modelo' }) 'Capacidad del modulo o kit.') +
        (InfoHtml 'Tipo' $(if ($r.gen) { $r.gen } else { 'RAM' }) $(if ($r.form) { $r.form } else { 'Generacion compatible.' })) +
        (InfoHtml 'Latencia' $(if ($r.cl) { $r.cl } else { '-' }) 'CAS Latency cuando figura en titulo o SKU.')
      $d.SPEC_SUB = 'Datos utiles para compatibilidad con motherboard, CPU y perfil de memoria.'
      $specs = @(
        (SpecHtml 'Marca / modelo' $(if ($r.model) { "$brand $($r.model)" } else { "$brand $titleClean" }) 'Identificacion del producto.'),
        (SpecHtml 'Capacidad' $(if ($r.cap) { $r.cap } else { 'Segun listado' }) 'Capacidad indicada en titulo o SKU.'),
        (SpecHtml 'Tecnologia' $(if ($r.gen) { $r.gen } else { 'Segun listado' }) 'Debe coincidir con la motherboard.'),
        (SpecHtml 'Velocidad' $(if ($r.speed) { $r.speed } else { 'Segun listado' }) 'Frecuencia/transferencia publicada.'),
        (SpecHtml 'Timing' $(if ($r.cl) { $r.cl } else { 'Segun ficha del modelo' }) 'CAS Latency cuando esta declarada.'),
        (SpecHtml 'Voltaje' $(if ($r.volt) { $r.volt } else { 'Segun ficha del modelo' }) 'Voltaje del perfil publicado.'),
        (SpecHtml 'Formato' $(if ($r.form) { $r.form } else { 'Segun listado' }) 'Desktop DIMM y notebook SODIMM no son intercambiables.'),
        (SpecHtml 'Perfil / RGB' $(if ($r.profile) { $r.profile } else { $(if ($r.color) { $r.color } else { 'Segun modelo' }) }) 'Activar XMP/EXPO en BIOS si la plataforma lo permite.')
      )
      $d.SPECS = ($specs -join "`n      ")
      $d.CONN_TITLE = 'Compatibilidad'
      $d.CONN_SUB = 'Puntos rapidos antes de comprar o instalar.'
      $d.CONNS = (ConnHtml $(if ($r.gen) { $r.gen } else { 'RAM' }) 'Motherboard' 'Debe coincidir con la generacion DDR de la placa madre.') +
        (ConnHtml $(if ($r.form -match 'SODIMM') { 'SODIMM' } else { 'DIMM' }) 'Formato' 'Desktop y notebook no son intercambiables.') +
        (ConnHtml $(if ($r.cap) { $r.cap } else { 'Capacidad' }) 'Upgrade' 'Revisar slots y capacidad maxima soportada.')
      $src = if ($sku -match '(?i)^KF') { "SKU Kingston $sku (nomenclatura oficial FURY)." } else { "titulo/SKU del listado $brand." }
      $d.NOTE = HE "* Specs tomadas de $src Producto $cond; la velocidad final depende de CPU, mother y BIOS."
    }
    default {
      $typeLabel = switch ($kind) {
        'perif' { if ($categ -match '(?i)mouse') { 'Mouse' } elseif ($categ -match '(?i)tecl') { 'Teclado' } elseif ($categ -match '(?i)auri') { 'Auriculares' } else { 'Periferico' } }
        'cpu' { 'Procesador' }
        'storage' { 'Almacenamiento' }
        'case' { 'Gabinete' }
        'cooler' { 'Refrigeracion' }
        'monitor' { 'Monitor' }
        'redes' { 'Redes' }
        default {
          if ($categ) { ($categ -split '/')[-1].Trim() } else { 'Producto' }
        }
      }
      $conn = 'Segun ficha del modelo'
      if ($title -match '(?i)inalambr|wireless|bluetooth|\b2\.4\b') { $conn = 'Inalambrico' }
      elseif ($title -match '(?i)\busb\b|cable') { $conn = 'USB / cableado' }
      $caps = @()
      $m = [regex]::Match($title, '(?i)\b(\d{1,3})\s*GB\b'); if ($m.Success) { $caps += ($m.Groups[1].Value + 'GB') }
      $m = [regex]::Match($title, '(?i)\b(\d{1,2})\s*TB\b'); if ($m.Success) { $caps += ($m.Groups[1].Value + 'TB') }
      $m = [regex]::Match($title, '(?i)\b(\d{2,3})\s*Hz\b'); if ($m.Success) { $caps += ($m.Groups[1].Value + 'Hz') }
      if ($title -match '(?i)\bRGB\b|ARGB') { $caps += 'RGB' }
      if ($title -match '(?i)NVME|M\.2') { $caps += 'NVMe M.2' }
      elseif ($title -match '(?i)SATA') { $caps += 'SATA' }
      $heroVal = if ($caps.Count) { $caps[0] } else { $typeLabel }
      $d.MAKER = HE "$brand / $typeLabel"
      $d.SUBTITLE = HE "$typeLabel / $cond"
      $d.BADGES = BadgeHtml (@($typeLabel, $brand) + $caps + @($cond))
      $d.HERO_LABEL = 'Categoria'
      $d.HERO_VALUE = HE $heroVal
      $d.HERO_DESC = HE "Ficha tecnica $typeLabel $brand. Specs desde titulo/SKU; completar con hoja oficial para valores no declarados."
      $d.INFO = (InfoHtml 'Marca' $brand 'Identificacion comercial.') + (InfoHtml 'Tipo' $typeLabel 'Clasificacion.') + (InfoHtml 'Estado' $cond 'Condicion de venta.')
      $d.SPEC_SUB = 'Ficha armada con datos del listado. No se inventan valores que no figuren en titulo/SKU o categoria.'
      $specs = @(
        (SpecHtml 'Marca / modelo' "$brand - $titleClean" 'Denominacion del listado.'),
        (SpecHtml 'Tipo' $typeLabel 'Clasificacion comercial.')
      )
      if ($categ) { $specs += SpecHtml 'Categoria Odoo' $categ 'Rubro interno.' }
      if ($sku) { $specs += SpecHtml 'SKU' $sku 'Referencia.' }
      if ($conn -ne 'Segun ficha del modelo') { $specs += SpecHtml 'Conectividad' $conn 'Detectada en el titulo.' }
      foreach ($c in $caps) { $specs += SpecHtml 'Dato del listado' $c 'Extraido del titulo.' }
      $specs += SpecHtml 'Estado' $cond 'Condicion de venta.'
      $d.SPECS = ($specs -join "`n      ")
      $d.CONN_TITLE = 'Compatibilidad'
      $d.CONN_SUB = 'Revisar ficha oficial del fabricante para el detalle fino.'
      $d.CONNS = (ConnHtml $typeLabel 'Uso' "Producto de $typeLabel para el catalogo Quantum.") +
        (ConnHtml $brand 'Marca' 'Identificacion comercial.') +
        (ConnHtml $cond 'Estado' $(if ($outlet) { 'Unidad outlet; consultar stock.' } else { 'Producto nuevo.' }))
      $d.NOTE = HE "* Datos del titulo/SKU. Specs exactas: hoja oficial del fabricante $brand."
    }
  }
  return (New-FichaHtml $d)
}

Write-Host 'Cargando cobertura Odoo y specs GPU...'
$cov = Get-Content -LiteralPath $Coverage -Raw -Encoding UTF8 | ConvertFrom-Json
$idx = @{}
foreach ($p in @($cov.products)) { $idx[[int]$p.id] = $p }
$db = Get-Content -LiteralPath $SpecsDb -Raw -Encoding UTF8 | ConvertFrom-Json
$script:chips = $db.chips

$skipNames = '^(preview|_preview|PC-PENDIENTES|_template)'
$files = New-Object System.Collections.Generic.List[string]
foreach ($dir in @('GPUS','GPUS_OUTLET','MOTHERBOARDS','FUENTES','PERIFERICOS','CATALOGO')) {
  $p = Join-Path $Root $dir
  if (Test-Path $p) {
    Get-ChildItem -LiteralPath $p -Recurse -Filter '*.html' -File | ForEach-Object { $files.Add($_.FullName) }
  }
}
Get-ChildItem -LiteralPath $Root -Filter '*.html' -File | Where-Object { $_.Name -notmatch $skipNames } | ForEach-Object { $files.Add($_.FullName) }

$manifest = New-Object System.Collections.Generic.List[object]
$nOk = 0; $nSkip = 0; $nPc = 0
foreach ($fp in $files) {
  $name = [IO.Path]::GetFileName($fp)
  if ($name -match $skipNames -or $name -match '^_') { $nSkip++; continue }
  $rel = Get-PagesRel $fp
  if ($rel -match '(?i)^PCS-GAMER/|^WORKSTATIONS/') { $nPc++; continue }
  $id = Get-OdooId $name
  if ($OnlyIds.Count -gt 0 -and ($id -le 0 -or $OnlyIds -notcontains $id)) { continue }

  $title = ''; $sku = ''; $categ = ''
  if ($id -gt 0 -and $idx.ContainsKey($id)) {
    $row = $idx[$id]
    $title = [string]$row.title
    $sku = [string]$row.sku
    $categ = [string]$row.categ
  }
  if (-not $title) {
    $raw = [IO.File]::ReadAllText($fp)
    $hm = [regex]::Match($raw, '(?s)<h1[^>]*>(.*?)</h1>')
    if ($hm.Success) { $title = [regex]::Replace($hm.Groups[1].Value, '<[^>]+>', '').Trim() }
    else {
      $tm = [regex]::Match($raw, '(?s)<title>(.*?)</title>')
      if ($tm.Success) { $title = ($tm.Groups[1].Value -replace ' - Quantum Hardstore','').Trim() }
    }
  }
  if (-not $title) { $nSkip++; continue }
  if (Test-AssembledPc $categ $title $rel) { $nPc++; continue }

  if ($Limit -gt 0 -and $nOk -ge $Limit) { break }
  $kind = Get-Kind $categ $title $rel
  $html = Build-Ficha @{ title=$title; sku=$sku; categ=$categ; kind=$kind; css=(Get-CssHref $fp) }
  if (-not $DryRun) { [IO.File]::WriteAllText($fp, $html, $utf8) }
  $iframe = "<iframe src=`"$ThemeBase/$rel?v=$ThemeVersion`" style=`"width:100%;height:2400px;border:0;`" loading=`"lazy`"></iframe>"
  $manifest.Add([pscustomobject]@{
    OdooId = $id; Title = $title; Sku = $sku; File = $rel; Kind = $kind
    Matched = [bool]($id -gt 0); iframe = $iframe
  })
  $nOk++
  if (($nOk % 400) -eq 0) { Write-Host ("  ... {0} fichas" -f $nOk) }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('[')
for ($i = 0; $i -lt $manifest.Count; $i++) {
  $piece = ($manifest[$i] | ConvertTo-Json -Depth 6 -Compress)
  if ($i -lt $manifest.Count - 1) { [void]$sb.AppendLine($piece + ',') } else { [void]$sb.AppendLine($piece) }
}
[void]$sb.AppendLine(']')
if (-not $DryRun) {
  $manDir = Split-Path $ManifestPath -Parent
  if ($manDir -and -not (Test-Path $manDir)) { New-Item -ItemType Directory -Force -Path $manDir | Out-Null }
  [IO.File]::WriteAllText((Join-Path $Root $ManifestPath.TrimStart('.','\')), $sb.ToString(), $utf8)
}
Write-Host ("OK {0} | PCs omitidas {1} | Skip {2} | DryRun={3}" -f $nOk, $nPc, $nSkip, [bool]$DryRun)
Write-Host ("Manifest: {0}" -f $ManifestPath)
