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

function Resolve-Chip([string]$Title, $Chips) {
  $names = $Chips.PSObject.Properties.Name
  $t = ' ' + (($Title.ToUpper() -replace '[^A-Z0-9]', ' ') -replace '\s+', ' ') + ' '

  $m = [regex]::Match($t, '\b(RTX|GTX|GT)\s*(\d{3,4})\s*(TI\s*SUPER|TI|SUPER)?\b')
  if ($m.Success) {
    $fam = $m.Groups[1].Value; $num = $m.Groups[2].Value
    $suf = ($m.Groups[3].Value -replace '\s+', ' ').Trim()
    $key = "$fam $num"
    if ($suf -match 'TI SUPER') { $key = "$fam $num Ti Super" }
    elseif ($suf -eq 'TI') { $key = "$fam $num Ti" }
    elseif ($suf -eq 'SUPER') { $key = "$fam $num Super" }
    if ($names -contains $key) { return $key }
    if ($names -contains "$fam $num") { return "$fam $num" }
  }

  $m = [regex]::Match($t, '\bRX\s*(\d{3,4})\s*(XTX|XT)?\b')
  if ($m.Success) {
    $num = $m.Groups[1].Value; $suf = $m.Groups[2].Value.Trim()
    $key = "RX $num"
    if ($suf -eq 'XTX') { $key = "RX $num XTX" }
    elseif ($suf -eq 'XT') { $key = "RX $num XT" }
    if ($names -contains $key) { return $key }
    if ($names -contains "RX $num") { return "RX $num" }
  }

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

# Features cualitativas (no numericas) para los badges, segun chip/arquitectura.
function Get-Features([string]$ChipKey, $S) {
  $f = @()
  if ($ChipKey -like 'RTX *') {
    $f += 'Ray Tracing'
    if ($ChipKey -match 'RTX 50') { $f += 'DLSS 4' }
    elseif ($ChipKey -match 'RTX 40') { $f += 'DLSS 3' }
    else { $f += 'DLSS' }
    $f += 'NVENC'
  } elseif ($ChipKey -like 'GTX *' -or $ChipKey -like 'GT *') {
    $f += 'DirectX 12'
    if ($ChipKey -notlike 'GT 710' -and $ChipKey -notlike 'GT 1030') { $f += 'NVENC' }
  } elseif ($ChipKey -like 'RX *') {
    if ($S.arch -match 'RDNA 2|RDNA 3|RDNA 4') { $f += 'Ray Tracing' }
    $f += 'FSR'
  }
  return $f
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

  <div class="badge-row" aria-label="Caracteristicas">
    {{BADGES}}
  </div>

  <section class="hero-metric"><div class="metric-box"><div class="metric-label">Memoria de video</div><div class="metric-value">{{VRAM}}</div><div class="metric-desc">{{HERO_DESC}}</div></div></section>

  <section class="section"><h2 class="section-title">Especificaciones tecnicas</h2><p class="section-sub">Datos segun ficha oficial del fabricante del chip. El modelo AIB puede variar clocks de fabrica y disipacion.</p><div class="spec-grid">
      <article class="spec-card"><div class="spec-name">Arquitectura</div><div class="spec-value">{{ARCH}}</div><div class="spec-note">Generacion y familia del GPU.</div></article>
      <article class="spec-card"><div class="spec-name">Proceso</div><div class="spec-value">{{PROCESS}}</div><div class="spec-note">Nodo de fabricacion.</div></article>
      <article class="spec-card"><div class="spec-name">{{CORE_LABEL}}</div><div class="spec-value">{{CORES}}</div><div class="spec-note">Nucleos de sombreado.</div></article>
      <article class="spec-card"><div class="spec-name">Memoria</div><div class="spec-value">{{VRAM}} {{MEMTYPE}}</div><div class="spec-note">Capacidad y tipo de VRAM.</div></article>
      <article class="spec-card"><div class="spec-name">Bus de memoria</div><div class="spec-value">{{BUS}}</div><div class="spec-note">Ancho del bus de memoria.</div></article>
      <article class="spec-card"><div class="spec-name">Boost clock</div><div class="spec-value">{{BOOST}}</div><div class="spec-note">Frecuencia maxima de referencia.</div></article>
      <article class="spec-card"><div class="spec-name">Consumo (TDP)</div><div class="spec-value">{{TDP}}</div><div class="spec-note">Potencia declarada del chip.</div></article>
      <article class="spec-card"><div class="spec-name">Interfaz</div><div class="spec-value">{{PCIE}}</div><div class="spec-note">Version de PCI Express.</div></article>
    </div></section>

  <section class="section dark"><h2 class="section-title">Requisitos y armado</h2><p class="section-sub">Lo que necesitas para instalarla correctamente en tu equipo.</p><div class="conn-grid">
      <article class="conn-card"><div class="conn-count">{{PSU}}</div><div class="conn-name">Fuente recomendada</div><div class="conn-desc">Potencia de PSU sugerida por el fabricante para el sistema.</div></article>
      <article class="conn-card"><div class="conn-count">Power</div><div class="conn-name">Alimentacion</div><div class="conn-desc">{{POWER}}</div></article>
      <article class="conn-card"><div class="conn-count">Video</div><div class="conn-name">Salidas</div><div class="conn-desc">{{OUTPUTS}}</div></article>
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
$generated = 0; $matched = 0; $unmatched = @()

foreach ($p in @($odoo.products)) {
  $title = [string]$p.title
  $id = [int]$p.id
  $file = "gpu-$('{0:D4}' -f $id).html"
  $outlet = Test-Outlet $title
  $brand = Get-Brand $title
  $chipKey = Resolve-Chip $title $chips
  $titleClean = ($title -replace '(?i)\s*\((OUTLET|OPENBOX)\)\s*', ' ').Trim()
  $cond = if ($outlet) { 'Outlet' } else { 'Nuevo' }

  if ($chipKey) {
    $matched++
    $s = $chips.$chipKey
    $vram = (Get-VramFromTitle $title); if (-not $vram) { $vram = $s.vram }

    $badges = @($chipKey) + (Get-Features $chipKey $s) + @($cond)
    $badgeHtml = ($badges | ForEach-Object { "<span class=`"badge`">$(HE $_)</span>" }) -join "`n    "

    $heroDesc = "$chipKey de $($s.brandChip). Placa de video dedicada; specs segun ficha oficial del fabricante del chip."

    $statusBox = if ($outlet) {
@'
<div class="status-box"><div class="status-title">Producto outlet</div><div class="status-text">Unidad outlet revisada por Quantum Hardstore. Estado y stock sujetos a confirmacion. Consultar disponibilidad antes de abonar.</div></div>
'@
    } else {
@'
<div class="status-box"><div class="status-title">Disponibilidad</div><div class="status-text">Producto nuevo. Puede encontrarse en deposito; en ese caso, una vez abonado, el plazo de envio del deposito al local es de 48 a 72 horas habiles aproximadas.</div></div>
'@
    }

    $note = "* Especificaciones resumidas desde ficha oficial de $($s.brandChip) $chipKey. Los valores de fabrica pueden variar segun el modelo $brand. La compatibilidad final depende de fuente, gabinete y monitor."
    $maker = if ($s.brandChip -eq 'NVIDIA') { "$brand / NVIDIA GeForce" } elseif ($s.brandChip -eq 'AMD') { "$brand / AMD Radeon" } else { $brand }
    $subtitle = "Placa de video dedicada / $($s.brandChip) $($s.arch)$(if($outlet){' / OUTLET'})"

    $html = $template
    $repl = @{
      '{{TITLE}}' = (HE $title); '{{MAKER}}' = (HE $maker); '{{H1}}' = (HE $titleClean)
      '{{SUBTITLE}}' = (HE $subtitle); '{{BADGES}}' = $badgeHtml
      '{{VRAM}}' = (HE $vram); '{{HERO_DESC}}' = (HE $heroDesc)
      '{{ARCH}}' = (HE $s.arch); '{{PROCESS}}' = (HE $s.process)
      '{{CORE_LABEL}}' = (HE $s.coreLabel); '{{CORES}}' = (HE ([string]$s.cores))
      '{{MEMTYPE}}' = (HE $s.memType); '{{BUS}}' = (HE $s.bus)
      '{{BOOST}}' = (HE $s.boost); '{{TDP}}' = (HE $s.tdp); '{{PCIE}}' = (HE $s.pcie)
      '{{PSU}}' = (HE $s.psu); '{{POWER}}' = (HE $s.power); '{{OUTPUTS}}' = (HE $s.outputs)
      '{{STATUS_BOX}}' = $statusBox; '{{NOTE}}' = (HE $note)
      '{{THEME_BASE}}' = $ThemeBase; '{{THEME_VERSION}}' = $ThemeVersion
    }
    foreach ($k in $repl.Keys) { $html = $html.Replace($k, $repl[$k]) }
  } else {
    $unmatched += "$id | $title"
    $vramGuess = Get-VramFromTitle $title; if (-not $vramGuess) { $vramGuess = 'A confirmar' }
    $badgeHtml = (@('Placa de video', $brand, $cond) | ForEach-Object { "<span class=`"badge`">$(HE $_)</span>" }) -join "`n    "
    $statusBox = '<div class="status-box"><div class="status-title">Ficha en revision</div><div class="status-text">Specs tecnicas pendientes de completar desde fuente oficial. No publicar hasta verificar.</div></div>'
    $html = $template
    $repl = @{
      '{{TITLE}}' = (HE $title); '{{MAKER}}' = (HE $brand); '{{H1}}' = (HE $titleClean)
      '{{SUBTITLE}}' = (HE "Placa de video dedicada$(if($outlet){' / OUTLET'})"); '{{BADGES}}' = $badgeHtml
      '{{VRAM}}' = (HE $vramGuess); '{{HERO_DESC}}' = 'Ficha en preparacion. Specs a completar desde fuente oficial.'
      '{{ARCH}}' = 'A confirmar'; '{{PROCESS}}' = 'A confirmar'
      '{{CORE_LABEL}}' = 'Nucleos'; '{{CORES}}' = 'A confirmar'
      '{{MEMTYPE}}' = ''; '{{BUS}}' = 'A confirmar'
      '{{BOOST}}' = 'A confirmar'; '{{TDP}}' = 'A confirmar'; '{{PCIE}}' = 'PCIe'
      '{{PSU}}' = 'A confirmar'; '{{POWER}}' = 'A confirmar'; '{{OUTPUTS}}' = 'A confirmar'
      '{{STATUS_BOX}}' = $statusBox; '{{NOTE}}' = '* Ficha pendiente de completar con specs oficiales.'
      '{{THEME_BASE}}' = $ThemeBase; '{{THEME_VERSION}}' = $ThemeVersion
    }
    foreach ($k in $repl.Keys) { $html = $html.Replace($k, [string]$repl[$k]) }
  }

  Set-Content -LiteralPath (Join-Path $OutDir $file) -Value $html -Encoding UTF8

  $iframe = "<iframe src=`"$ThemeBase/GPUS/$file?v=$ThemeVersion`" style=`"width:100%;height:2200px;border:0;`" loading=`"lazy`"></iframe>"
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
