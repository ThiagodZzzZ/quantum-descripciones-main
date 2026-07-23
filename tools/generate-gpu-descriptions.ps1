#Requires -Version 5.1
param(
  [string]$OdooJson = 'C:\Users\PC\Quantum-Imagenes-Productos\inventario\odoo-gpus-action-619.json',
  [string]$SpecsDb  = 'C:\Users\PC\Quantum-Descripciones-Nuevas-MAIN\tools\gpu-specs-db.json',
  [string]$OutDir   = 'C:\Users\PC\Quantum-Descripciones-Nuevas-MAIN\GPUS',
  [string]$ThemeVersion = '20260723quantum',
  [string]$ThemeBase = 'https://thiagodzzzz.github.io/quantum-descripciones-main'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web

function HE([string]$s) { [System.Web.HttpUtility]::HtmlEncode($s) }

function Get-Brand([string]$Title) {
  if ($Title -match '(?i)\b(MSI|ASUS|GIGABYTE|AORUS|ASROCK|Sapphire|PowerColor|ZOTAC|Palit|EVGA|XFX|PNY|Gainward|AFOX|Colorful|Inno3D|Galax|KFA2|Yeston|Manli|Biostar)\b') {
    return $Matches[1].ToUpper()
  }
  if ($Title -match '(?i)GeForce|RTX|GTX|NVIDIA') { return 'NVIDIA' }
  if ($Title -match '(?i)Radeon|\bRX\b|AMD') { return 'AMD' }
  return 'QUANTUM HARDSTORE'
}

function Test-Outlet([string]$Title) { $Title -match '(?i)OUTLET|OPENBOX|USADO' }

# Detecta el chip a partir del titulo. Devuelve la clave del DB o $null.
function Resolve-Chip([string]$Title, $Chips) {
  $names = $Chips.PSObject.Properties.Name
  $t = ' ' + (($Title.ToUpper() -replace '[^A-Z0-9]', ' ') -replace '\s+', ' ') + ' '

  # NVIDIA RTX / GTX / GT con prefijo
  $m = [regex]::Match($t, '\b(RTX|GTX|GT)\s*(\d{3,4})\s*(TI\s*SUPER|TI|SUPER)?\b')
  if ($m.Success) {
    $fam = $m.Groups[1].Value
    $num = $m.Groups[2].Value
    $suf = ($m.Groups[3].Value -replace '\s+', ' ').Trim()
    $key = "$fam $num"
    if ($suf -match 'TI SUPER') { $key = "$fam $num Ti Super" }
    elseif ($suf -eq 'TI') { $key = "$fam $num Ti" }
    elseif ($suf -eq 'SUPER') { $key = "$fam $num Super" }
    if ($names -contains $key) { return $key }
    if ($names -contains "$fam $num") { return "$fam $num" }
  }

  # AMD RX con prefijo
  $m = [regex]::Match($t, '\bRX\s*(\d{3,4})\s*(XTX|XT)?\b')
  if ($m.Success) {
    $num = $m.Groups[1].Value
    $suf = $m.Groups[2].Value.Trim()
    $key = "RX $num"
    if ($suf -eq 'XTX') { $key = "RX $num XTX" }
    elseif ($suf -eq 'XT') { $key = "RX $num XT" }
    if ($names -contains $key) { return $key }
    if ($names -contains "RX $num") { return "RX $num" }
  }

  # Fallback sin prefijo de familia. El sufijo desambigua: Ti/Super = NVIDIA, XT/XTX = AMD.
  $m = [regex]::Match($t, '\b(\d{3,4})\s*(TI\s*SUPER|TI|SUPER|XTX|XT)?\b')
  while ($m.Success) {
    $num = $m.Groups[1].Value
    $suf = ($m.Groups[2].Value -replace '\s+', ' ').Trim()
    $cands = @()
    if ($suf -match 'XT') {
      if ($suf -eq 'XTX') { $cands += "RX $num XTX" }
      $cands += "RX $num XT"; $cands += "RX $num"
    } elseif ($suf -match 'TI|SUPER') {
      foreach ($fam in 'RTX','GTX','GT') {
        if ($suf -match 'TI SUPER') { $cands += "$fam $num Ti Super" }
        elseif ($suf -eq 'TI') { $cands += "$fam $num Ti" }
        elseif ($suf -eq 'SUPER') { $cands += "$fam $num Super" }
      }
    } else {
      # Sin sufijo: probar NVIDIA y luego AMD (las claves del DB son exactas y validan)
      foreach ($fam in 'RTX','GTX','GT') { $cands += "$fam $num" }
      $cands += "RX $num"
    }
    foreach ($c in $cands) { if ($names -contains $c) { return $c } }
    $m = $m.NextMatch()
  }
  return $null
}

function Get-VramFromTitle([string]$Title) {
  $m = [regex]::Match($Title.ToUpper(), '(\d{1,2})\s*GB\b')
  if ($m.Success) { return "$($m.Groups[1].Value) GB" }
  $m = [regex]::Match($Title.ToUpper(), '\b(\d{1,2})G\b')
  if ($m.Success) { return "$($m.Groups[1].Value) GB" }
  return $null
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
  <header class="qh-header">
    <div class="brand">Quantum Hardstore</div>
    <div class="maker">{{MAKER}}</div>
    <h1>{{H1}}</h1>
    <div class="subtitle">{{SUBTITLE}}</div>
  </header>

  <div class="badge-row" aria-label="Caracteristicas principales">
    {{BADGES}}
  </div>

  <section class="hero-metric"><div class="metric-box"><div class="metric-label">Placa de video</div><div class="metric-value">{{HERO_VALUE}}</div><div class="metric-desc">{{HERO_DESC}}</div></div></section>

  <section class="card-grid" aria-label="Resumen">
    <article class="info-card"><div class="label">Memoria</div><div class="value">{{VRAM}}</div><div class="desc">{{MEMTYPE}} / {{BUS}}</div></article>
    <article class="info-card"><div class="label">{{CORE_LABEL}}</div><div class="value">{{CORES}}</div><div class="desc">Unidades de procesamiento grafico.</div></article>
    <article class="info-card"><div class="label">Boost</div><div class="value">{{BOOST}}</div><div class="desc">Frecuencia de referencia; el AIB puede variar.</div></article>
  </section>

  <section class="section"><h2 class="section-title">Especificaciones clave</h2><p class="section-sub">Datos tecnicos segun ficha oficial del fabricante del chip. El modelo AIB puede variar clocks de fabrica, disipacion y conectores.</p><div class="spec-grid">
      <article class="spec-card"><div class="spec-name">Arquitectura</div><div class="spec-value">{{ARCH}}</div><div class="spec-note">Generacion y familia del GPU.</div></article>
      <article class="spec-card"><div class="spec-name">Proceso</div><div class="spec-value">{{PROCESS}}</div><div class="spec-note">Nodo de fabricacion.</div></article>
      <article class="spec-card"><div class="spec-name">{{CORE_LABEL}}</div><div class="spec-value">{{CORES}}</div><div class="spec-note">Nucleos de sombreado.</div></article>
      <article class="spec-card"><div class="spec-name">Memoria</div><div class="spec-value">{{VRAM}} {{MEMTYPE}}</div><div class="spec-note">Capacidad y tipo de VRAM.</div></article>
      <article class="spec-card"><div class="spec-name">Bus de memoria</div><div class="spec-value">{{BUS}}</div><div class="spec-note">Ancho del bus de memoria.</div></article>
      <article class="spec-card"><div class="spec-name">Boost clock</div><div class="spec-value">{{BOOST}}</div><div class="spec-note">Frecuencia maxima de referencia.</div></article>
      <article class="spec-card"><div class="spec-name">Consumo (TDP)</div><div class="spec-value">{{TDP}}</div><div class="spec-note">Potencia declarada del chip.</div></article>
      <article class="spec-card"><div class="spec-name">Interfaz</div><div class="spec-value">{{PCIE}}</div><div class="spec-note">Version de PCI Express.</div></article>
    </div></section>

  <section class="section dark"><h2 class="section-title">Conectividad y armado</h2><p class="section-sub">Puntos a validar para compatibilidad con gabinete, fuente y monitor.</p><div class="conn-grid">
      <article class="conn-card"><div class="conn-count">{{VRAM}}</div><div class="conn-name">VRAM</div><div class="conn-desc">{{MEMTYPE}}</div></article>
      <article class="conn-card"><div class="conn-count">{{PCIE}}</div><div class="conn-name">PCI Express</div><div class="conn-desc">Ranura x16</div></article>
      <article class="conn-card"><div class="conn-count">{{TDP}}</div><div class="conn-name">Consumo</div><div class="conn-desc">Fuente recomendada acorde</div></article>
      <article class="conn-card"><div class="conn-count">Video</div><div class="conn-name">Salidas</div><div class="conn-desc">{{OUTPUTS}}</div></article>
      <article class="conn-card"><div class="conn-count">Power</div><div class="conn-name">Alimentacion</div><div class="conn-desc">{{POWER}}</div></article>
      <article class="conn-card"><div class="conn-count">{{ARCH_SHORT}}</div><div class="conn-name">Arquitectura</div><div class="conn-desc">{{BRAND_CHIP}}</div></article>
    </div></section>

  {{STATUS_BOX}}

  <div class="note">{{NOTE}}</div>
</div>
</body>
</html>
'@

$db = Get-Content $SpecsDb -Raw | ConvertFrom-Json
$chips = $db.chips
$odoo = Get-Content $OdooJson -Raw | ConvertFrom-Json

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$manifest = @()
$generated = 0
$matched = 0
$unmatched = @()

foreach ($p in @($odoo.products)) {
  $title = [string]$p.title
  $id = [int]$p.id
  $file = "gpu-$('{0:D4}' -f $id).html"
  $outlet = Test-Outlet $title
  $brand = Get-Brand $title
  $chipKey = Resolve-Chip $title $chips
  $titleClean = ($title -replace '(?i)\s*\((OUTLET|OPENBOX)\)\s*', ' ').Trim()

  if ($chipKey) {
    $matched++
    $s = $chips.$chipKey
    $vram = (Get-VramFromTitle $title); if (-not $vram) { $vram = $s.vram }
    $archShort = ($s.arch -split '[ (]')[0]

    $badges = @()
    $badges += $chipKey
    $badges += "$vram $($s.memType)"
    $badges += "$($s.cores) $($s.coreLabel)"
    $badges += $s.bus
    $badges += $s.pcie
    if ($outlet) { $badges += 'Outlet' } else { $badges += 'Nuevo' }
    $badgeHtml = ($badges | ForEach-Object { "<span class=`"badge`">$(HE $_)</span>" }) -join "`n    "

    $heroValue = $vram
    $heroDesc = "$chipKey ($($s.brandChip) $($s.arch)). Specs segun ficha oficial del fabricante del chip; el modelo $brand puede variar clocks de fabrica y disipacion."

    $statusBox = if ($outlet) {
@'
<div class="status-box"><div class="status-title">Producto outlet</div><div class="status-text">Unidad outlet revisada por Quantum Hardstore. Estado y stock sujetos a confirmacion. Consultar disponibilidad antes de abonar.</div></div>
'@
    } else {
@'
<div class="status-box"><div class="status-title">Disponibilidad</div><div class="status-text">Producto nuevo. Puede encontrarse en deposito; en ese caso el plazo de envio del deposito al local es de 48 a 72 horas habiles aproximadas una vez abonado.</div></div>
'@
    }

    $note = "* Especificaciones resumidas desde ficha oficial de $($s.brandChip) $chipKey. Los valores de fabrica pueden variar segun el modelo $brand (clocks, disipacion, conectores, salidas de video). La compatibilidad final depende de fuente, gabinete y monitor."

    $maker = if ($s.brandChip -eq 'NVIDIA') { "$brand / NVIDIA GeForce" } elseif ($s.brandChip -eq 'AMD') { "$brand / AMD Radeon" } else { $brand }

    $html = $template
    $repl = @{
      '{{TITLE}}' = (HE $title)
      '{{MAKER}}' = (HE $maker)
      '{{H1}}' = (HE $titleClean)
      '{{SUBTITLE}}' = (HE "$chipKey / $($s.arch) / $vram $($s.memType) / $($s.bus) / $($s.pcie)$(if($outlet){' / OUTLET'})")
      '{{BADGES}}' = $badgeHtml
      '{{HERO_VALUE}}' = (HE $heroValue)
      '{{HERO_DESC}}' = (HE $heroDesc)
      '{{VRAM}}' = (HE $vram)
      '{{MEMTYPE}}' = (HE $s.memType)
      '{{BUS}}' = (HE $s.bus)
      '{{CORE_LABEL}}' = (HE $s.coreLabel)
      '{{CORES}}' = (HE ([string]$s.cores))
      '{{BOOST}}' = (HE $s.boost)
      '{{ARCH}}' = (HE $s.arch)
      '{{ARCH_SHORT}}' = (HE $archShort)
      '{{PROCESS}}' = (HE $s.process)
      '{{TDP}}' = (HE $s.tdp)
      '{{PCIE}}' = (HE $s.pcie)
      '{{OUTPUTS}}' = (HE $s.outputs)
      '{{POWER}}' = (HE $s.power)
      '{{BRAND_CHIP}}' = (HE $s.brandChip)
      '{{STATUS_BOX}}' = $statusBox
      '{{NOTE}}' = (HE $note)
      '{{THEME_BASE}}' = $ThemeBase
      '{{THEME_VERSION}}' = $ThemeVersion
    }
    foreach ($k in $repl.Keys) { $html = $html.Replace($k, $repl[$k]) }
  } else {
    $unmatched += "$id | $title"
    # Ficha generica sin specs de chip (marca para revision manual)
    $badgeHtml = @("<span class=`"badge`">Placa de video</span>", "<span class=`"badge`">$(HE $brand)</span>", "<span class=`"badge`">$(if($outlet){'Outlet'}else{'Nuevo'})</span>") -join "`n    "
    $statusBox = '<div class="status-box"><div class="status-title">Ficha en revision</div><div class="status-text">Specs tecnicas pendientes de completar desde fuente oficial. No publicar hasta verificar.</div></div>'
    $vramGuess = Get-VramFromTitle $title
    if (-not $vramGuess) { $vramGuess = 'A confirmar' }
    $heroGuess = Get-VramFromTitle $title
    if (-not $heroGuess) { $heroGuess = 'GPU' }
    $html = $template
    $repl = @{
      '{{TITLE}}' = (HE $title); '{{MAKER}}' = (HE $brand); '{{H1}}' = (HE $titleClean)
      '{{SUBTITLE}}' = (HE "$(if($outlet){'OUTLET / '})Placa de video"); '{{BADGES}}' = $badgeHtml
      '{{HERO_VALUE}}' = (HE $heroGuess); '{{HERO_DESC}}' = (HE "Ficha en preparacion. Specs a completar desde fuente oficial.")
      '{{VRAM}}' = (HE $vramGuess); '{{MEMTYPE}}' = 'GDDR'; '{{BUS}}' = 'A confirmar'
      '{{CORE_LABEL}}' = 'Nucleos'; '{{CORES}}' = 'A confirmar'; '{{BOOST}}' = 'A confirmar'
      '{{ARCH}}' = 'A confirmar'; '{{ARCH_SHORT}}' = 'GPU'; '{{PROCESS}}' = 'A confirmar'; '{{TDP}}' = 'A confirmar'
      '{{PCIE}}' = 'PCIe'; '{{OUTPUTS}}' = 'A confirmar'; '{{POWER}}' = 'A confirmar'; '{{BRAND_CHIP}}' = (HE $brand)
      '{{STATUS_BOX}}' = $statusBox; '{{NOTE}}' = (HE '* Ficha pendiente de completar con specs oficiales.')
      '{{THEME_BASE}}' = $ThemeBase; '{{THEME_VERSION}}' = $ThemeVersion
    }
    foreach ($k in $repl.Keys) { $html = $html.Replace($k, [string]$repl[$k]) }
  }

  Set-Content -LiteralPath (Join-Path $OutDir $file) -Value $html -Encoding UTF8

  $iframe = "<iframe src=`"$ThemeBase/GPUS/$file?v=$ThemeVersion`" style=`"width:100%;height:2600px;border:0;`" loading=`"lazy`"></iframe>"
  $manifest += [pscustomobject]@{
    OdooId = $id; Title = $title; Sku = [string]$p.internalReference
    File = $file; Chip = $chipKey; Outlet = $outlet
    Matched = [bool]$chipKey; Iframe = $iframe
  }
  $generated++
}

$manifestPath = Join-Path (Split-Path $OutDir -Parent) 'gpu_manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$unmatched | Set-Content -LiteralPath (Join-Path (Split-Path $OutDir -Parent) 'gpu_sin_specs.txt') -Encoding UTF8

Write-Host "Generadas: $generated | Con specs de chip: $matched | Sin match: $($unmatched.Count)"
Write-Host "Manifest: $manifestPath"
if ($unmatched.Count -gt 0) { Write-Host "Sin specs (revisar): gpu_sin_specs.txt" -ForegroundColor Yellow }
