#Requires -Version 5.1
param(
  [string]$Worklist = '.\audits\gpus-all-worklist-20260824.json',
  [string]$SpecsDb  = '.\tools\gpu-specs-db.json',
  [string]$Template = '.\GPUS\_template-gpu-v2.html',
  [string]$OutDir   = '.\GPUS',
  [string]$ManifestPath = '.\audits\gpu_v2_all_20260824_manifest.json',
  [string]$ThemeVersion = '20260824gpuvall',
  [string]$ThemeBase = 'https://thiagodzzzz.github.io/quantum-descripciones-main',
  [switch]$SkipImages,
  [switch]$FetchOdooImages
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
$utf8 = New-Object System.Text.UTF8Encoding $false
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

function HE([string]$s) { [System.Web.HttpUtility]::HtmlEncode($s) }
function Get-Brand([string]$Title) {
  if ($Title -match '(?i)\b(MSI|ASUS|GIGABYTE|AORUS|ASROCK|Sapphire|PowerColor|ZOTAC|Palit|EVGA|XFX|PNY|Gainward|AFOX|Colorful|Inno3D|Galax|KFA2|Yeston|Manli|Biostar|iGAME)\b') { return $Matches[1].ToUpper() }
  if ($Title -match '(?i)GeForce|RTX|GTX|NVIDIA') { return 'NVIDIA' }
  if ($Title -match '(?i)Radeon|\bRX\b|AMD') { return 'AMD' }
  return 'AIB'
}
function Test-Outlet([string]$Title) { $Title -match '(?i)OUTLET|OPENBOX|USADO' }
function Test-Junk([string]$Title) { $Title -match '(?i)Pasta\s*T|Fan\s*Cooler|E2E\s*T66|Workstation|Notebook|iCUE\s*LINK|^\s*Fuente\b|\bFUENTE\b|WATER\s*COOLER|KIT WATER' }

function Resolve-Chip([string]$Title, $Chips) {
  $names = @($Chips.PSObject.Properties.Name)
  $raw = $Title.ToUpper()
  $raw = $raw -replace '\(TM\)|\(R\)|\(C\)',' '
  $raw = $raw -replace 'GEFORCERTX','GEFORCE RTX'
  $raw = $raw -replace 'GEFORCEGTX','GEFORCE GTX'
  $t = ' ' + (($raw -replace '[^A-Z0-9]', ' ') -replace '\s+', ' ') + ' '
  $preferAmd = (($Title -match '(?i)\b(XFX|Sapphire|PowerColor)\b') -or ($Title -match '(?i)Radeon|\bRX\b')) -and ($Title -notmatch '(?i)\bRTX\b|\bGTX\b|\bGeForce\b')

  $m = [regex]::Match($t, '\bRTX\s*PRO\s*(\d{4})\b')
  if ($m.Success) { $key = "RTX PRO $($m.Groups[1].Value)"; if ($names -contains $key) { return $key } }
  $m = [regex]::Match($t, '\b(?:QUADRO\s+)?RTX\s*A(\d{3,4})\b')
  if ($m.Success) { $key = "RTX A$($m.Groups[1].Value)"; if ($names -contains $key) { return $key } }

  $m = [regex]::Match($t, '\b(RTX|GTX|GT)\s*(\d{3,4})\s*(TI)?\s*(SUPER)?\b')
  if ($m.Success -and -not $preferAmd) {
    $fam=$m.Groups[1].Value; $num=$m.Groups[2].Value; $hasTi=[bool]$m.Groups[3].Value; $hasSuper=[bool]$m.Groups[4].Value
    $key="$fam $num"; if($hasTi -and $hasSuper){$key="$fam $num Ti Super"} elseif($hasTi){$key="$fam $num Ti"} elseif($hasSuper){$key="$fam $num Super"}
    if ($names -contains $key) { return $key }
  }
  $m = [regex]::Match($t, '\b(RTX|GTX|GT)(\d{3,4})(TI)?(SUPER)?\b')
  if ($m.Success -and -not $preferAmd) {
    $fam=$m.Groups[1].Value; $num=$m.Groups[2].Value; $hasTi=[bool]$m.Groups[3].Value; $hasSuper=[bool]$m.Groups[4].Value
    $key="$fam $num"; if($hasTi -and $hasSuper){$key="$fam $num Ti Super"} elseif($hasTi){$key="$fam $num Ti"} elseif($hasSuper){$key="$fam $num Super"}
    if ($names -contains $key) { return $key }
  }
  $m = [regex]::Match($t, '\bRX\s*(\d{3,4})\s*(XTX|XT|GRE)?\b')
  if ($m.Success) {
    $num=$m.Groups[1].Value; $suf=$m.Groups[2].Value.Trim(); $key="RX $num"
    if($suf -eq 'XTX'){$key="RX $num XTX"} elseif($suf -eq 'XT'){$key="RX $num XT"}
    if ($names -contains $key) { return $key }
    if ($names -contains "RX $num") { return "RX $num" }
  }
  $m = [regex]::Match($t, '\bRX(\d{3,4})(XTX|XT)?\b')
  if ($m.Success) {
    $num=$m.Groups[1].Value; $suf=$m.Groups[2].Value.Trim(); $key="RX $num"
    if($suf -eq 'XTX'){$key="RX $num XTX"} elseif($suf -eq 'XT'){$key="RX $num XT"}
    if ($names -contains $key) { return $key }
    if ($names -contains "RX $num") { return "RX $num" }
  }
  if ($Title -match '(?i)\b6900\s*XT\b|\b6900XT\b') { if ($names -contains 'RX 6900 XT') { return 'RX 6900 XT' } }
  if ($Title -match '(?i)\b6800\s*XT\b') { if ($names -contains 'RX 6800 XT') { return 'RX 6800 XT' } }
  if ($Title -match '(?i)\b6800\b' -and $Title -notmatch '(?i)XT|RTX|GTX') { if ($names -contains 'RX 6800') { return 'RX 6800' } }
  if ($Title -match '(?i)\bXFX\b.*\b6600\b' -or $Title -match '(?i)^\s*XFX\s*\|\s*6600') { if ($names -contains 'RX 6600') { return 'RX 6600' } }

  # Bare model numbers: "3090 ASUS", "1660 SUPER", "4070 GIGABYTE", Sapphire 570/6700
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
      if ($preferAmd -or $Title -match '(?i)Sapphire|XFX|PowerColor|Radeon') { $cands += "RX $num"; $cands += "RX $num XT" }
      foreach ($fam in 'RTX','GTX','GT') { $cands += "$fam $num" }
      $cands += "RX $num"
    }
    foreach ($cand in $cands) { if ($names -contains $cand) { return $cand } }
    $m = $m.NextMatch()
  }
  return $null
}
function Get-VramGb([string]$Title, $S) {
  $m = [regex]::Match($Title.ToUpper(), '(\d{1,2})\s*GB\b'); if ($m.Success) { return [int]$m.Groups[1].Value }
  $m = [regex]::Match($Title.ToUpper(), '\b(\d{1,2})G\b'); if ($m.Success) { return [int]$m.Groups[1].Value }
  $m = [regex]::Match([string]$S.vram, '(\d+)'); if ($m.Success) { return [int]$m.Groups[1].Value }
  return 0
}
function Get-CleanTitle([string]$Title) {
  $t = $Title
  $t = $t -replace '(?i)^\s*(PLACA\s+DE\s+VIDEO|VGA|GPU)\s+', ''
  $t = $t -replace '(?i)\s*\((OUTLET|OPENBOX|USADO)[^)]*\)\s*', ' '
  $t = $t -replace '(?i)\s*\(Caja Original\)\s*', ' '
  $t = $t -replace '\s*\(\d{4}\)\s*$', ''
  $t = $t -replace '\s*\d{4}\s*$', ''  # trailing sku nums like (7344) already handled; bare 912-...
  $t = $t -replace '\s+', ' '
  return $t.Trim()
}
function Get-SeriesTag([string]$Title) {
  $tags = @()
  foreach ($pair in @(
    @('WINDFORCE','WINDFORCE'),@('VENTUS','VENTUS'),@('\bTUF\b','TUF'),@('\bROG\b|ASTRAL','ROG'),
    @('EAGLE','EAGLE'),@('SHADOW','SHADOW'),@('DUAL','DUAL'),@('GAMING','GAMING OC'),
    @('AERO','AERO'),@('PHANTOM','PHANTOM'),@('FTW','FTW3'),@('CHALLENGER','CHALLENGER'),
    @('PRIME','PRIME'),@('TWIN\s*X2','TWIN X2'),@('ADVANCED|ADVANCE','ADVANCED'),@('MLG','MLG'),@('TRIO','GAMING TRIO')
  )) {
    if ($Title -match ('(?i)' + $pair[0])) { $tags += $pair[1] }
  }
  return @($tags | Select-Object -Unique | Select-Object -First 3)
}
function Get-FeatureTags([string]$ChipKey) {
  if ($ChipKey -like 'RTX 50*') { return @('DLSS 4','PCIe 5.0') }
  if ($ChipKey -like 'RTX 40*') { return @('DLSS 3','PCIe 4.0') }
  if ($ChipKey -like 'RTX *') { return @('DLSS','PCIe 4.0') }
  if ($ChipKey -like 'GTX *') { return @('DirectX 12','PCIe 3.0') }
  if ($ChipKey -like 'RX 90*') { return @('FSR','PCIe 5.0') }
  if ($ChipKey -like 'RX *') { return @('FSR','PCIe 4.0') }
  return @('PCIe')
}
function Get-ChipUrl([string]$ChipKey, [string]$BrandChip) {
  if ($BrandChip -eq 'NVIDIA') {
    if ($ChipKey -match 'RTX 50') { return 'https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/' }
    if ($ChipKey -match 'RTX 30|GTX 16') { return 'https://www.nvidia.com/en-us/geforce/graphics-cards/30-series/' }
    return 'https://www.nvidia.com/en-us/geforce/graphics-cards/'
  }
  if ($ChipKey -match 'RX 90') { return 'https://www.amd.com/en/products/graphics/desktops/radeon/9000-series.html' }
  if ($ChipKey -match 'RX 6') { return 'https://www.amd.com/en/products/graphics/desktops/radeon/6000-series.html' }
  return 'https://www.amd.com/en/products/graphics/desktops/radeon.html'
}

$db = Get-Content $SpecsDb -Raw | ConvertFrom-Json
$chips = $db.chips
$wl = Get-Content $Worklist -Raw | ConvertFrom-Json
$tpl = [System.IO.File]::ReadAllText((Resolve-Path $Template), $utf8)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'img\product') | Out-Null

$odooReady = $false
if ($FetchOdooImages) {
  . "$PSScriptRoot\_odoo-env-tmp.ps1"
  . "$PSScriptRoot\_xmlrpc-lib.ps1"
  $baseOdoo = $env:ODOO_URL.TrimEnd('/') -replace '/odoo$',''
  $uid = Invoke-XmlRpc "$baseOdoo/xmlrpc/2/common" 'authenticate' @($env:ODOO_DB,$env:ODOO_USER,$env:ODOO_PASS,@{})
  if (-not $uid) { throw 'Auth Odoo fallida' }
  $odooReady = $true
  Write-Host "Odoo uid=$uid"
}

function Get-OdooImg([int]$Id) {
  $c = New-Object System.Collections.Generic.List[object]; $c.Add('id'); $c.Add('='); $c.Add($Id)
  $dom = New-Object System.Collections.Generic.List[object]; $dom.Add($c)
  $a = New-Object System.Collections.Generic.List[object]; $a.Add($dom)
  $p = New-Object System.Collections.Generic.List[object]
  foreach ($x in @($env:ODOO_DB,$uid,$env:ODOO_PASS,'product.template','search_read')) { $p.Add($x) }
  $p.Add($a); $p.Add(@{ fields=@('id','image_1024'); limit=1 })
  $rows = @(Invoke-XmlRpc "$baseOdoo/xmlrpc/2/object" 'execute_kw' $p)
  if (-not $rows) { return $null }
  $img = $rows[0].image_1024
  if (-not $img -or ($img -is [bool])) { return $null }
  return [string]$img
}

$manifest = New-Object System.Collections.Generic.List[object]
$junk = New-Object System.Collections.Generic.List[object]
$unmatched = New-Object System.Collections.Generic.List[object]
$generated = 0

foreach ($p in @($wl.products)) {
  $id = [int]$p.id
  $title = [string]$p.title
  $sku = [string]$p.sku; if (-not $sku) { $sku = [string]$p.internalReference }

  if (Test-Junk $title) { [void]$junk.Add("$id | $title"); Write-Host "SKIP junk $id"; continue }
  $chipKey = Resolve-Chip $title $chips
  if (-not $chipKey) { [void]$unmatched.Add("$id | $title"); Write-Host "NO CHIP $id $title" -ForegroundColor Yellow; continue }

  $s = $chips.$chipKey
  $outlet = Test-Outlet $title
  $brand = Get-Brand $title
  $h1 = Get-CleanTitle $title
  $titleDoc = if ($outlet -and $h1 -notmatch '(?i)OUTLET') { "$h1 (OUTLET)" } else { $h1 }
  $vramGb = Get-VramGb $title $s
  $memType = [string]$s.memType
  $archName = if ($s.brandChip -eq 'NVIDIA') { "NVIDIA $($s.arch)" } else { "AMD $($s.arch)" }
  $gpuName = if ($s.brandChip -eq 'NVIDIA') { "GeForce $chipKey" } else { "Radeon $chipKey" }
  $bus = ([string]$s.bus) -replace '-bit',''
  $boost = [string]$s.boost
  $tdp = [string]$s.tdp
  $power = [string]$s.power
  $outputs = ([string]$s.outputs) -replace '\s*/\s*',' · '
  $psuWatts = 650; if ([string]$s.psu -match '(\d+)') { $psuWatts = [int]$Matches[1] }
  $fill = [Math]::Min(95, [Math]::Max(35, [int](($psuWatts / 1000.0) * 100)))
  $boostLabel = if ($s.brandChip -eq 'NVIDIA') { 'Boost referencia NVIDIA' } else { 'Boost referencia AMD' }

  $feat = @(Get-FeatureTags $chipKey) + @(Get-SeriesTag $title)
  $feat = @($feat | Select-Object -Unique | Select-Object -First 4)
  $tagsHtml = ($feat | ForEach-Object { "        <span class=`"tag`">$(HE $_)</span>" }) -join "`n"

  $rows = @(
    @{n='GPU';x=$gpuName}, @{n='Arquitectura';x=$archName},
    @{n='Memoria';x="$vramGb GB $memType"}, @{n='Bus de memoria';x="$bus-bit"},
    @{n=$boostLabel;x=$boost}, @{n='Consumo (TGP/TDP)';x=$tdp},
    @{n='Alimentacion';x=$power}, @{n='Salidas';x=$outputs},
    @{n='Fuente sugerida';x="$psuWatts W (sistema)"}
  )
  $specRows = ($rows | ForEach-Object { "          <div class=`"spec-row`"><span class=`"n`">$(HE $_.n)</span><span class=`"x`">$(HE $_.x)</span></div>" }) -join "`n"

  $chipUrl = Get-ChipUrl $chipKey $s.brandChip
  $src = "Fuentes: chip <a href=`"$chipUrl`" target=`"_blank`" rel=`"noopener`">$(HE ($s.brandChip + ' ' + $chipKey))</a> - modelo AIB <b>$(HE $brand)</b> (clocks de fabrica y medidas pueden variar segun revision)."

  $sub = "$(HE $brand) - $vramGb GB $memType. Specs desde ficha oficial del chip $($s.brandChip)."
  $psuHint = "Segun recomendacion de sistema del fabricante del chip para esta $chipKey. Suma margen con CPU potente u overclock."
  $note = "* Specs del chip segun sitio oficial del fabricante. Clocks/medidas del modelo $brand pueden variar. El stock (nuevo/outlet) puede variar."


  $imgUrl = $null
  $localJpg = Join-Path $OutDir "img\product\$id-main.jpg"
  $localWebp = Join-Path $OutDir "img\product\$id-main.webp"
  if (Test-Path $localJpg) {
    $imgUrl = "$ThemeBase/GPUS/img/product/$id-main.jpg"
  } elseif (Test-Path $localWebp) {
    $imgUrl = "$ThemeBase/GPUS/img/product/$id-main.webp"
  } elseif (-not $SkipImages -and $odooReady) {
    try {
      $b64 = Get-OdooImg $id
      if ($b64) {
        $bytes = [Convert]::FromBase64String($b64)
        [System.IO.File]::WriteAllBytes($localJpg, $bytes)
        $imgUrl = "$ThemeBase/GPUS/img/product/$id-main.jpg"
        Write-Host "IMG $id $($bytes.Length)"
      }
    } catch { Write-Host "IMG fail $id $($_.Exception.Message)" -ForegroundColor DarkYellow }
  }
  if (-not $imgUrl) {
    $slug = ($chipKey.ToLower() -replace '\s+','-')
    $imgUrl = "$ThemeBase/GPUS/img/compare/$slug.png"
  }

  $defaultRival = if ($s.brandChip -eq 'AMD') { 'RTX 5070' } else { 'RX 9070 XT' }
  if ($defaultRival -eq $chipKey) { $defaultRival = 'RTX 5080' }

  $html = $tpl
  $repl = @{
    '{{OUTLET_ATTR}}' = $(if ($outlet) { ' data-outlet="1"' } else { '' })
    '{{TITLE}}' = (HE $titleDoc)
    '{{THEME_VERSION}}' = $ThemeVersion
    '{{H1}}' = (HE $h1)
    '{{SUB}}' = $sub
    '{{TAGS}}' = $tagsHtml
    '{{SPEC_ROWS}}' = $specRows
    '{{SRC}}' = $src
    '{{CURRENT}}' = $chipKey
    '{{CURRENT_IMG}}' = $imgUrl
    '{{PSU_FILL}}' = [string]$fill
    '{{PSU_WATTS}}' = [string]$psuWatts
    '{{PSU_HINT}}' = (HE $psuHint)
    '{{DEFAULT_RIVAL}}' = $defaultRival
    '{{NOTE}}' = (HE $note)
  }
  foreach ($k in $repl.Keys) { $html = $html.Replace($k, [string]$repl[$k]) }

  # If this chip is not in CATALOG JS, inject a fallback entry before CURRENT usage
  if ($html -notmatch [regex]::Escape('"' + $chipKey + '":')) {
    $inj = '      "' + $chipKey + '": { brand:"' + $s.brandChip + '", arch:"' + $s.arch + '", vramGb:' + $vramGb + ', mem:"' + $memType + '", bus:' + $bus + ', boost:' + ($boost -replace '[^\d]','') + ', tdp:' + ($tdp -replace '[^\d]','') + ', psu:' + $psuWatts + ', rel:50 },' + "`n"
    $html = $html -replace '(var CATALOG = \{)', ('$1' + "`n" + $inj)
  }
  # Ensure product image overrides chip map for CURRENT
  if ($html -match ('"' + [regex]::Escape($chipKey) + '"\s*:\s*"[^"]+"')) {
    $html = [regex]::Replace($html, '"' + [regex]::Escape($chipKey) + '"\s*:\s*"[^"]+"', '"' + $chipKey + '": "' + $imgUrl + '"')
  } else {
    $html = $html -replace '(var CHIP_IMG = \{)', ('$1' + "`n      `"$chipKey`": `"$imgUrl`",")
  }

  $file = "gpu-$id.html"
  [System.IO.File]::WriteAllText((Join-Path $OutDir $file), $html, $utf8)
  $iframe = "<iframe src=`"$ThemeBase/GPUS/${file}?v=$ThemeVersion`" style=`"width:100%;height:2800px;border:0;`" loading=`"lazy`"></iframe>"
  [void]$manifest.Add([pscustomobject]@{
    OdooId=$id; Title=$title; Sku=$sku; File=$file; Chip=$chipKey; Matched=$true
    Outlet=[bool]$outlet; HasProductImage=($imgUrl -match '/img/product/'); iframe=$iframe
  })
  $generated++
  Write-Host "OK $id [$chipKey] $title"
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('[')
for ($i=0; $i -lt $manifest.Count; $i++) {
  $piece = ($manifest[$i] | ConvertTo-Json -Depth 6 -Compress)
  if ($i -lt $manifest.Count-1) { [void]$sb.AppendLine($piece + ',') } else { [void]$sb.AppendLine($piece) }
}
[void]$sb.AppendLine(']')
[System.IO.File]::WriteAllText($ManifestPath, $sb.ToString(), $utf8)
$junk | Set-Content '.\audits\gpus-v2-junk-skipped.txt' -Encoding UTF8
$unmatched | Set-Content '.\audits\gpus-v2-unmatched.txt' -Encoding UTF8
Write-Host ""
Write-Host "Generadas: $generated | Junk: $($junk.Count) | Sin chip: $($unmatched.Count)"
Write-Host "Manifest: $ManifestPath"
if ($unmatched.Count -gt 0) { $unmatched | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow } }
