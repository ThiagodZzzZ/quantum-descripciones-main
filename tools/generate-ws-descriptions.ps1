#Requires -Version 5.1
<#
.SYNOPSIS
  Genera descripciones HTML interactivas para Workstations Quantum Hardstore.
.NOTES
  - UI por programas profesionales (no FPS/juegos)
  - Nota clara: scores orientativos/especulativos
  - Salida: WORKSTATIONS/ws-NN.html + ws_full_manifest.json
#>
param(
  [string]$ProductsJson = '',
  [string]$OutDir = '',
  [string]$RepoRoot = '',
  [string]$ThemeVersion = '20260724quantum',
  [string]$ThemeBase = 'https://thiagodzzzz.github.io/quantum-descripciones-main'
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
if (-not $OutDir) { $OutDir = Join-Path $RepoRoot 'WORKSTATIONS' }
$ManifestPath = Join-Path $RepoRoot 'ws_full_manifest.json'

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$GpuCatalog = [ordered]@{
  '5090'   = @{ key='5090'; n='RTX 5090'; d='GDDR7'; score=100; nvidia=$true }
  '5080'   = @{ key='5080'; n='RTX 5080'; d='GDDR7'; score=97;  nvidia=$true }
  '5070'   = @{ key='5070'; n='RTX 5070'; d='GDDR7'; score=92;  nvidia=$true }
  '5060'   = @{ key='5060'; n='RTX 5060'; d='GDDR7'; score=82;  nvidia=$true }
  '4090'   = @{ key='4090'; n='RTX 4090'; d='24GB GDDR6X'; score=99; nvidia=$true }
  '4080'   = @{ key='4080'; n='RTX 4080'; d='16GB GDDR6X'; score=95; nvidia=$true }
  '3090'   = @{ key='3090'; n='RTX 3090'; d='24GB GDDR6X'; score=98; nvidia=$true }
  '3080ti' = @{ key='3080ti'; n='RTX 3080 Ti'; d='12GB GDDR6X'; score=94; nvidia=$true }
  '3080'   = @{ key='3080'; n='RTX 3080'; d='10GB GDDR6X'; score=90; nvidia=$true }
  '3070'   = @{ key='3070'; n='RTX 3070'; d='8GB GDDR6'; score=82; nvidia=$true }
  '9070'   = @{ key='9070'; n='RX 9070'; d='RDNA 4'; score=88; nvidia=$false }
  '7900xtx'= @{ key='7900xtx'; n='RX 7900 XTX'; d='24GB GDDR6'; score=94; nvidia=$false }
  '6800'   = @{ key='6800'; n='RX 6800'; d='16GB GDDR6'; score=80; nvidia=$false }
}

$UpgradeOrder = @('3070','3080','5060','3080ti','5070','9070','3090','4080','7900xtx','4090','5080','5090')

$CpuDb = @{
  'RYZEN 7 5800XT' = @{ short='Ryzen 7 5800XT'; cores='8C/16T'; arch='Zen 3'; sock='AM4'; boost='4.8 GHz'; score=78 }
  'RYZEN 7 9700X' = @{ short='Ryzen 7 9700X'; cores='8C/16T'; arch='Zen 5'; sock='AM5'; boost='5.5 GHz'; score=90 }
  'RYZEN 7 9800X3D' = @{ short='Ryzen 7 9800X3D'; cores='8C/16T'; arch='Zen 5 3D'; sock='AM5'; boost='5.2 GHz'; score=96 }
  'RYZEN 9 5900XT' = @{ short='Ryzen 9 5900XT'; cores='16C/32T'; arch='Zen 3'; sock='AM4'; boost='4.8 GHz'; score=88 }
  'RYZEN 9 7900' = @{ short='Ryzen 9 7900'; cores='12C/24T'; arch='Zen 4'; sock='AM5'; boost='5.4 GHz'; score=90 }
  'RYZEN 9 7900X' = @{ short='Ryzen 9 7900X'; cores='12C/24T'; arch='Zen 4'; sock='AM5'; boost='5.6 GHz'; score=92 }
  'RYZEN 9 7950X' = @{ short='Ryzen 9 7950X'; cores='16C/32T'; arch='Zen 4'; sock='AM5'; boost='5.7 GHz'; score=95 }
  'RYZEN 9 9950X' = @{ short='Ryzen 9 9950X'; cores='16C/32T'; arch='Zen 5'; sock='AM5'; boost='5.7 GHz'; score=98 }
  'INTEL CORE I9-13900F' = @{ short='Core i9-13900F'; cores='24C/32T'; arch='Raptor Lake'; sock='LGA1700'; boost='5.6 GHz'; score=96 }
}

$DefaultTitles = @(
  'Ryzen 9 7900 | B840 | DDR5 32GB | M.2 1TB | RTX 3080 | 850W 80+ Gold | ATX | Water Cooling',
  'Ryzen 7 5800XT | B550M | DDR4 32GB | M.2 1TB | RTX 3080 | 750W 80+ Gold | ATX | Water Cooling',
  'Intel Core i9-13900F | B760 | DDR5 32GB | M.2 1TB | RTX 5070 | 1000W | ATX | Water Cooling',
  'Ryzen 9 7900 | DDR5 32GB | RX 3090 | SSD 1TB NVMe | 850W 80+ Gold | ATX | Water Cooling',
  'Ryzen 9 7900X | DDR5 32GB | RTX 5060 | SSD 1TB NVMe | 850W 80+ Gold | ATX | Water Cooling',
  'Ryzen 9 7950X | B840 | DDR5 2x16 GB | M.2 1TB | RTX 3080 | 850W 80+ Gold | ATX | Water Cooling',
  'Ryzen 7 9700X | B840 | DDR5 32GB | M.2 1TB | RTX 3080 | 850W 80+ Gold | ATX | Water Cooling',
  'Ryzen 9 5900XT | B550M | DDR4 32GB | M.2 1TB | RTX 3080 | 750W 80+ Gold | ATX | Water Cooling',
  'Ryzen 7 9800X3D | B840 | DDR5 32GB | M.2 1TB | RTX 5070 | 1000W | ATX | Water Cooling',
  'Ryzen 9 7900X | DDR5 32GB | RX 9070 | SSD 1TB NVMe | 1000W 80+ Gold | ATX',
  'Ryzen 9 9950X | DDR5 32GB | RTX 5070 | SSD 1TB NVMe | 1000W 80+ Gold | ATX | Water Cooling'
)

function Get-CpuInfo([string]$Title) {
  $u = $Title.ToUpperInvariant()
  foreach ($k in ($CpuDb.Keys | Sort-Object { $_.Length } -Descending)) {
    if ($u -like "*$k*") { return $CpuDb[$k] }
  }
  $m = [regex]::Match($Title, '(?i)(Ryzen\s+[579]\s+\w+|Core\s+i[579]-?\d+\w*|Intel\s+Core\s+i[579]-?\d+\w*)')
  $short = if ($m.Success) { $m.Groups[1].Value } else { 'CPU' }
  return @{ short=$short; cores='Segun CPU'; arch='-'; sock='AM5'; boost='-'; score=85 }
}

function Get-GpuKey([string]$Title) {
  $u = $Title.ToUpperInvariant()
  if ($u -match 'RTX\s*5090') { return '5090' }
  if ($u -match 'RTX\s*5080') { return '5080' }
  if ($u -match 'RTX\s*5070') { return '5070' }
  if ($u -match 'RTX\s*5060') { return '5060' }
  if ($u -match 'RTX\s*4090') { return '4090' }
  if ($u -match 'RTX\s*4080') { return '4080' }
  if ($u -match 'RTX\s*3090|RX\s*3090') { return '3090' }
  if ($u -match 'RTX\s*3080\s*TI') { return '3080ti' }
  if ($u -match 'RTX\s*3080') { return '3080' }
  if ($u -match 'RTX\s*3070') { return '3070' }
  if ($u -match 'RX\s*9070') { return '9070' }
  if ($u -match 'RX\s*7900') { return '7900xtx' }
  if ($u -match 'RX\s*6800') { return '6800' }
  return '3080'
}

function Get-Chipset([string]$Title) {
  if ($Title -match '(?i)\b(B840|B850|B650|B550M|B550|B760|H610M|X670)\b') { return $Matches[1].ToUpper() }
  $cpu = Get-CpuInfo $Title
  return $cpu.sock
}

function Get-RamInfo([string]$Title) {
  $type = if ($Title -match '(?i)DDR4') { 'DDR4' } elseif ($Title -match '(?i)DDR5') { 'DDR5' } else {
    $cpu = Get-CpuInfo $Title; if ($cpu.sock -eq 'AM4') { 'DDR4' } else { 'DDR5' }
  }
  $gb = 32
  if ($Title -match '(?i)(\d+)\s*x\s*(\d+)\s*GB') { $gb = [int]$Matches[1] * [int]$Matches[2] }
  elseif ($Title -match '(?i)DDR[45]\s*(\d+)\s*GB') { $gb = [int]$Matches[1] }
  elseif ($Title -match '(?i)(\d+)\s*GB\s*DDR') { $gb = [int]$Matches[1] }
  elseif ($Title -match '(?i)\b(32|64|128)\s*GB\b') { $gb = [int]$Matches[1] }
  if ($gb -lt 32) { $gb = 32 }
  return @{ gb=$gb; type=$type }
}

function Get-StorageInfo([string]$Title) {
  if ($Title -match '(?i)4\s*TB|4TB') { return @{ k='4'; n='4TB NVMe'; d='proyectos grandes'; label='4TB NVMe' } }
  if ($Title -match '(?i)2\s*TB|2TB') { return @{ k='2'; n='2TB NVMe'; d='cache y biblioteca'; label='2TB NVMe' } }
  return @{ k='1'; n='1TB NVMe'; d='sistema + proyectos'; label='1TB NVMe' }
}

function Get-Psu([string]$Title) {
  if ($Title -match '(?i)(\d{3,4})\s*W[^\|]*?(80\+\s*(Gold|Bronze|White|Platinum))?') {
    $w = $Matches[1]
    $tier = if ($Matches[2]) { "80+ $($Matches[2])" } else { '' }
    return ("${w}w " + $tier).Trim()
  }
  if ($Title -match '(?i)(\d{3,4})\s*W') { return "$($Matches[1])w" }
  return 'Fuente segun ficha'
}

function Test-WaterCooling([string]$Title) { return [bool]($Title -match '(?i)Water\s*Cooling|AIO') }

function Get-GpuOptions([string]$BaseKey) {
  if (-not $GpuCatalog.Contains($BaseKey)) { $BaseKey = '3080' }
  $opts = New-Object System.Collections.ArrayList
  [void]$opts.Add($GpuCatalog[$BaseKey])
  $idx = [array]::IndexOf(@($UpgradeOrder), $BaseKey)
  if ($idx -ge 0) {
    for ($i = $idx + 1; $i -lt $UpgradeOrder.Count -and $opts.Count -lt 3; $i++) {
      $k = $UpgradeOrder[$i]
      if ($GpuCatalog.Contains($k)) { [void]$opts.Add($GpuCatalog[$k]) }
    }
  }
  if ($opts.Count -lt 2) {
    foreach ($k in @('5070','3090','4090')) {
      if ($k -ne $BaseKey -and $GpuCatalog.Contains($k) -and $opts.Count -lt 3) {
        [void]$opts.Add($GpuCatalog[$k])
      }
    }
  }
  return @($opts.ToArray())
}

function Get-RamOptions($RamInfo) {
  $type = $RamInfo.type
  $gb = [Math]::Max(32, [int]$RamInfo.gb)
  $ladder = @(32,64,128) | Where-Object { $_ -ge $gb }
  if (-not $ladder) { $ladder = @(32,64,128) }
  $ladder = @($ladder | Select-Object -First 3)
  $opts = @()
  foreach ($g in $ladder) {
    $d = switch ($g) { 32 { '2x16GB' } 64 { '4x16GB' } 128 { 'proyectos extremos' } default { "${g}GB" } }
    $opts += @{ k="$g"; n="${g}GB $type"; d=$d }
  }
  return $opts
}

function Get-StorageOptions($Stor) {
  $all = @(
    @{ k='1'; n='1TB NVMe'; d='sistema + proyectos' },
    @{ k='2'; n='2TB NVMe'; d='cache y biblioteca' },
    @{ k='4'; n='4TB NVMe'; d='proyectos grandes' }
  )
  $order = @('1','2','4')
  $idx = [array]::IndexOf($order, $Stor.k)
  if ($idx -lt 0) { $idx = 0 }
  $keys = @($order[$idx..([Math]::Min($idx+2, $order.Count-1))])
  return @($keys | ForEach-Object { $k=$_; $all | Where-Object { $_.k -eq $k } | Select-Object -First 1 })
}

function ConvertTo-JsonArray($objs) {
  $parts = @()
  foreach ($o in $objs) {
    if ($o.key) {
      $nv = if ($o.nvidia) { 'true' } else { 'false' }
      $parts += ('{{"key":"{0}","n":"{1}","d":"{2}","score":{3},"nvidia":{4}}}' -f $o.key, $o.n, $o.d, $o.score, $nv)
    } else {
      $parts += ('{{"k":"{0}","n":"{1}","d":"{2}"}}' -f $o.k, $o.n, $o.d)
    }
  }
  return '[' + ($parts -join ',') + ']'
}

function New-WsHtml($P) {
  $gpuBtns = ($P.GpuOptions | ForEach-Object {
    $on = if ($_.key -eq $P.GpuOptions[0].key) { ' on' } else { '' }
    "<button class=`"cfg$on`" data-gpu=`"$($_.key)`">$($_.n)<span>$($_.d)</span></button>"
  }) -join ''
  $ramBtns = ($P.RamOptions | ForEach-Object {
    $on = if ($_.k -eq $P.RamOptions[0].k) { ' on' } else { '' }
    "<button class=`"cfg$on`" data-ram=`"$($_.k)`">$($_.n)<span>$($_.d)</span></button>"
  }) -join ''
  $storBtns = ($P.StorageOptions | ForEach-Object {
    $on = if ($_.k -eq $P.StorageOptions[0].k) { ' on' } else { '' }
    "<button class=`"cfg$on`" data-storage=`"$($_.k)`">$($_.n)<span>$($_.d)</span></button>"
  }) -join ''

  $tags = '<span class="tag hot">WORKSTATION NUEVA</span><span class="tag cool">' + $P.GpuOptions[0].n + '</span>'
  if ($P.Water) { $tags += '<span class="tag sun">Water Cooling</span>' }
  $tags += '<span class="tag">Render / Edicion / IA</span>'

  $coolLine = if ($P.Water) { 'Water Cooling - gabinete ATX' } else { 'Cooling por aire - gabinete ATX' }
  $cpuDet = "$($P.Cpu.cores) - $($P.Cpu.arch) - $($P.Cpu.sock) - hasta $($P.Cpu.boost)"
  $heroTitle = ($P.Cpu.short + ' + ' + $P.GpuOptions[0].n).ToUpper()
  $sub = "$($P.Cpu.cores) - $($P.Cpu.arch) - $($P.Cpu.sock) - $($P.RamOptions[0].n) - $($P.Storage.label) - $($P.Psu)"
  $themeUrl = "$ThemeBase/quantum-theme-switch.js?v=$ThemeVersion"
  $gpuJson = ConvertTo-JsonArray $P.GpuOptions
  $ramJson = ConvertTo-JsonArray $P.RamOptions
  $storJson = ConvertTo-JsonArray $P.StorageOptions
  $cpuScore = [int]$P.Cpu.score

@"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$($P.Cpu.short) + $($P.GpuOptions[0].n) Workstation - Quantum Hardstore</title>
<link href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;600;700;800;900&family=Barlow:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0;padding:0}:root{--sky:#22b8f0;--sun:#f6c64a;--pink:#ff007f;--ink:#101319;--muted:#707783;--line:#d7edf8;--good:#17a66a}html,body{background:linear-gradient(180deg,#fff 0%,#edfaff 48%,#fff 100%);color:var(--ink);font-family:'Barlow',Arial,sans-serif;overflow-x:hidden}.wrap{max-width:840px;margin:0 auto;padding:20px 14px 54px}.hero{position:relative;overflow:hidden;text-align:center;padding:32px 14px 25px;border:1px solid #bfeafa;border-radius:14px;background:linear-gradient(180deg,#fff 0%,#eaf9ff 58%,#fff 100%);margin-bottom:14px;box-shadow:0 10px 34px rgba(34,184,240,.12)}.hero:before{content:"";position:absolute;right:-52px;top:-82px;width:240px;height:240px;border-radius:50%;background:repeating-conic-gradient(from 0deg,rgba(246,198,74,.58) 0deg 8deg,rgba(246,198,74,.12) 8deg 16deg);animation:sun 7s ease-in-out infinite}.hero:after{content:"";position:absolute;left:0;right:0;bottom:0;height:7px;background:linear-gradient(90deg,var(--sky),#fff,var(--sun),#fff,var(--sky));background-size:240% 100%;animation:stripe 4s linear infinite}@keyframes sun{50%{transform:translate(-12px,14px) rotate(10deg)}}@keyframes stripe{to{background-position:240% 0}}.brand{position:relative;font-size:11px;letter-spacing:5px;color:var(--pink);text-transform:uppercase;font-weight:800;margin-bottom:10px}.title{position:relative;font-family:'Barlow Condensed',Arial,sans-serif;font-size:42px;line-height:.95;font-weight:900}.sub{position:relative;margin-top:10px;font-size:12px;color:var(--muted);line-height:1.55}.tags{position:relative;display:flex;justify-content:center;gap:8px;flex-wrap:wrap;margin-top:14px}.tag{border:1px solid #cfe7f4;background:#fff;color:#34404d;border-radius:999px;padding:6px 12px;font-size:10px;font-weight:800;letter-spacing:1px;text-transform:uppercase}.tag.hot{background:var(--pink);border-color:var(--pink);color:#fff}.tag.cool{background:var(--sky);border-color:var(--sky);color:#fff}.tag.sun{background:#fff7d8;border-color:#f3d36d;color:#7a5600}.panel{background:linear-gradient(180deg,#f6fcff 0%,#fff 100%);border:1px solid #d5eef9;border-top:3px solid var(--sky);border-radius:12px;padding:16px;margin-bottom:14px;box-shadow:0 8px 24px rgba(34,184,240,.07)}.section-title{font-size:11px;letter-spacing:3px;color:var(--pink);text-transform:uppercase;font-weight:900;margin-bottom:14px}.cfg-row{margin-bottom:14px}.cfg-label{font-size:10px;color:#8b94a0;letter-spacing:2px;text-transform:uppercase;font-weight:800;margin-bottom:8px}.btns{display:flex;gap:7px;flex-wrap:wrap}.cfg{min-width:120px;min-height:54px;background:#fff;border:1px solid #dbe3eb;border-radius:10px;color:#151a20;cursor:pointer;padding:8px 12px;font-family:'Barlow Condensed',Arial,sans-serif;font-size:15px;font-weight:800}.cfg span{display:block;font-family:'Barlow',Arial,sans-serif;font-size:10px;font-weight:600;color:#7d8792;margin-top:2px}.cfg.on{background:linear-gradient(135deg,var(--sky),#5fd0ff);border-color:var(--sky);color:#fff}.cfg.on span{color:#edfaff}.benefit{max-height:0;overflow:hidden;opacity:0;margin-top:0;border-left:3px solid var(--pink);background:#fff;border-radius:10px;color:#4a5360;font-size:12px;line-height:1.65;transition:max-height .35s ease,opacity .25s ease,margin .25s ease,padding .25s ease;padding:0 12px}.benefit.show{max-height:170px;opacity:1;margin-top:10px;padding:10px 12px}.benefit b{color:var(--pink)}.specs{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-bottom:14px}.spec{min-height:94px;background:linear-gradient(180deg,#fff 0%,#f7fcff 100%);border:1px solid var(--line);border-top:3px solid var(--sky);border-radius:12px;padding:13px 12px}.spec-l{font-size:9px;color:var(--pink);letter-spacing:2px;text-transform:uppercase;font-weight:900;margin-bottom:5px}.spec-v{font-family:'Barlow Condensed',Arial,sans-serif;font-size:24px;line-height:1;font-weight:900;word-break:break-word}.spec-d{font-size:11px;color:var(--muted);line-height:1.35;margin-top:5px}.bars{display:grid;gap:10px}.bar-top{display:flex;justify-content:space-between;gap:12px;align-items:center;font-size:11px;margin-bottom:5px}.bar-name{font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:#197aa0;font-weight:900}.bar-score{font-weight:900;font-size:12px}.track{height:10px;border-radius:999px;background:#dbe6ee;overflow:hidden}.fill{height:100%;border-radius:999px;background:linear-gradient(90deg,var(--sky),var(--pink));width:0;transition:width .7s}.apps{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-bottom:12px}.app{min-height:72px;background:#fff;border:1px solid var(--line);border-radius:11px;padding:10px 8px;cursor:pointer;text-align:left}.app.on{border-color:var(--pink);background:#fff4fa}.app b{display:block;font-family:'Barlow Condensed',Arial,sans-serif;font-size:17px;line-height:1}.app.on b{color:var(--pink)}.app span{display:block;font-size:10px;color:#7b8591;margin-top:5px;line-height:1.25}.work-panel{background:#fff;border:1px solid var(--line);border-radius:12px;padding:15px;min-height:150px}.work-title{font-family:'Barlow Condensed',Arial,sans-serif;font-size:29px;line-height:1;font-weight:900}.work-sub{font-size:11px;color:var(--muted);margin:5px 0 13px}.work-row{display:flex;gap:16px;align-items:center}.work-num{min-width:88px;text-align:center}.work-val{font-family:'Barlow Condensed',Arial,sans-serif;font-size:54px;font-weight:900;line-height:.9;color:var(--pink)}.work-unit{font-size:10px;color:#9aa3ad;letter-spacing:2px;margin-top:4px}.work-side{flex:1}.work-side .track{height:8px;margin-bottom:6px}.work-rate{font-size:11px;color:#5c6672;font-weight:700}.tip{font-size:11px;color:#5c6672;line-height:1.6;border-top:1px solid var(--line);margin-top:12px;padding-top:10px}.info{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-top:14px}.info-card{background:#fff;border:1px solid var(--line);border-top:3px solid var(--sky);border-radius:12px;text-align:center;padding:14px 8px}.info-val{font-family:'Barlow Condensed',Arial,sans-serif;font-size:22px;font-weight:900;color:var(--pink)}.info-l{font-size:10px;color:var(--muted);margin-top:4px;line-height:1.25}.note{font-size:10px;color:#8a949f;line-height:1.7;text-align:center;border-top:1px solid var(--line);margin-top:14px;padding-top:12px}@media(max-width:560px){.wrap{padding:14px 10px 40px}.title{font-size:31px}.sub{font-size:11px}.spec{min-height:106px;padding:12px 10px}.spec-v{font-size:20px}.spec-d{font-size:10px}.cfg{flex:1 1 calc(50% - 7px);min-width:0}.apps{grid-template-columns:repeat(2,minmax(0,1fr));gap:6px}.app b{font-size:15px}.work-row{gap:10px}.work-num{min-width:70px}.work-val{font-size:44px}.info{grid-template-columns:repeat(3,minmax(0,1fr));gap:6px}.info-card{padding:12px 5px}.info-val{font-size:18px}.info-l{font-size:9px}}
</style>
<script src="$themeUrl" defer></script>
</head>
<body>
<div class="wrap">
<section class="hero"><div class="brand">Quantum Hardstore - Workstation</div><h1 class="title">$heroTitle</h1><div class="sub">$sub</div><div class="tags">$tags</div></section>
<section class="panel"><div class="section-title">Ajusta la variante visual</div><div class="cfg-row"><div class="cfg-label">GPU / Aceleracion</div><div class="btns" id="gpuBtns">$gpuBtns</div></div><div class="cfg-row"><div class="cfg-label">Memoria para proyectos</div><div class="btns" id="ramBtns">$ramBtns</div><div class="benefit" id="ramBenefit"></div></div><div class="cfg-row"><div class="cfg-label">Disco de trabajo</div><div class="btns" id="storageBtns">$storBtns</div><div class="benefit" id="storageBenefit"></div></div></section>
<section class="specs"><article class="spec"><div class="spec-l">Procesador</div><div class="spec-v">$($P.Cpu.short)</div><div class="spec-d">$cpuDet</div></article><article class="spec"><div class="spec-l">GPU</div><div class="spec-v" id="gpuName">$($P.GpuOptions[0].n)</div><div class="spec-d" id="gpuDet">$($P.GpuOptions[0].d) - CUDA/OptiX / aceleracion pro</div></article><article class="spec"><div class="spec-l">Memoria</div><div class="spec-v" id="ramName">$($P.RamOptions[0].n)</div><div class="spec-d" id="ramDet">$($P.RamOptions[0].d) - multitarea y proyectos pesados</div></article><article class="spec"><div class="spec-l">Almacenamiento</div><div class="spec-v" id="storageName">$($P.Storage.label)</div><div class="spec-d" id="storageDet">SSD M.2/NVMe - proyectos, cache y sistema</div></article><article class="spec"><div class="spec-l">Motherboard</div><div class="spec-v">$($P.Chipset)</div><div class="spec-d">Socket $($P.Cpu.sock)</div></article><article class="spec"><div class="spec-l">Fuente + Cooling</div><div class="spec-v">$($P.Psu)</div><div class="spec-d">$coolLine</div></article></section>
<section class="panel"><div class="section-title">Capacidad profesional</div><div class="bars"><div><div class="bar-top"><span class="bar-name">Render GPU</span><span class="bar-score" id="sGpu">-</span></div><div class="track"><div class="fill" id="bGpu"></div></div></div><div><div class="bar-top"><span class="bar-name">Render CPU</span><span class="bar-score" id="sCpu">-</span></div><div class="track"><div class="fill" id="bCpu"></div></div></div><div><div class="bar-top"><span class="bar-name">Edicion 4K / Color</span><span class="bar-score" id="sEdit">-</span></div><div class="track"><div class="fill" id="bEdit"></div></div></div><div><div class="bar-top"><span class="bar-name">Multitarea pesada</span><span class="bar-score" id="sMulti">-</span></div><div class="track"><div class="fill" id="bMulti"></div></div></div></div></section>
<section class="panel"><div class="section-title">Prueba por programa</div><div style="background:#fff7d8;border:1px solid #f3d36d;border-left:4px solid #f6c64a;border-radius:10px;padding:11px 13px;margin-bottom:12px;font-size:11.5px;line-height:1.6;color:#7a5600"><b>&#9888; Importante:</b> los scores son <b>ORIENTATIVOS / ESPECULATIVOS</b>, solo para comparar variantes. <b>No garantizan tiempos de render ni export reales.</b> Varian segun escena, codecs, drivers, VRAM, temperatura y configuracion del software.</div><div class="apps" id="apps"></div><div class="work-panel" id="workPanel"></div><div class="note">Scores orientativos y especulativos para comparar configuraciones. Cada motor aprovecha CPU, GPU, RAM y VRAM de forma distinta.</div></section>
<section class="info"><div class="info-card"><div class="info-val">3 DIAS</div><div class="info-l">Armado y testeo aprox.</div></div><div class="info-card"><div class="info-val">1 A&Ntilde;O</div><div class="info-l">Garant&iacute;a de PC armada</div></div><div class="info-card"><div class="info-val">30 DIAS</div><div class="info-l">Periodo de prueba</div></div></section>
<div class="note">Workstation nueva armada por Quantum Hardstore. El equipo se ensambla y testea luego de abonado el pedido. Las variantes deben coincidir con el stock publicado al momento de cerrar la compra.</div>
</div>
<script>
var GPU_OPTIONS=$gpuJson;var RAM_OPTIONS=$ramJson;var STORAGE_OPTIONS=$storJson;var WORKLOADS=[["Blender / Render GPU","Cycles, OptiX o HIP",99,"Muy fuerte para render por GPU y escenas con aceleracion CUDA/OptiX o HIP."],["DaVinci / Premiere","Edicion 4K y color",87,"Timeline 4K, correccion de color y exportaciones con aceleracion por GPU."],["Unreal Engine / 3D","Viewport y compilacion",88,"Buen balance para viewport, shaders, assets pesados y pruebas en tiempo real."],["AutoCAD / SolidWorks","Modelado y planos",81,"CPU rapida y GPU dedicada para modelos, vistas y multitarea tecnica."],["IA local / Stable Diffusion","VRAM y computo GPU",95,"La VRAM manda: mas memoria de video permite modelos y batches mas grandes."],["Multitarea pro","Apps abiertas + cache",76,"RAM, CPU y NVMe dan margen para trabajar con varias apps a la vez."]];var CPU_SCORE=$cpuScore;var state={gpu:GPU_OPTIONS[0].key,ram:RAM_OPTIONS[0].k,storage:STORAGE_OPTIONS[0].k,app:0};function byKey(a,k){return a.find(function(x){return x.key===k||x.k===k})||a[0]}function label(p){return p>=92?'Excelente':p>=82?'Muy bueno':p>=68?'Bueno':'Correcto'}function ramBonus(){return state.ram==='128'?14:state.ram==='64'?9:4}function storageBonus(){return state.storage==='4'?8:state.storage==='2'?5:0}function setButtons(box,attr,val){document.querySelectorAll('#'+box+' .cfg').forEach(function(b){b.classList.toggle('on',b.dataset[attr]===val)})}function updateSpecs(){var g=byKey(GPU_OPTIONS,state.gpu),r=byKey(RAM_OPTIONS,state.ram),s=byKey(STORAGE_OPTIONS,state.storage);gpuName.textContent=g.n;gpuDet.textContent=g.d+' - aceleracion profesional';ramName.textContent=r.n;ramDet.textContent=r.d+' - '+(state.ram==='32'?'base profesional':state.ram==='64'?'margen para escenas pesadas':'datasets, cache y proyectos extremos');storageName.textContent=s.n;storageDet.textContent=s.d;ramBenefit.innerHTML=state.ram==='32'?'':'<b>'+r.n+'</b>: mas margen para renders, timelines 4K, escenas grandes, cache y varias apps abiertas.';ramBenefit.classList.toggle('show',!!ramBenefit.innerHTML);storageBenefit.innerHTML=state.storage==='1'?'':'<b>'+s.n+'</b>: mas espacio para proyectos, cache, librerias, renders y backups locales.';storageBenefit.classList.toggle('show',!!storageBenefit.innerHTML)}function updateBars(){var g=byKey(GPU_OPTIONS,state.gpu);var rb=ramBonus(),sb=storageBonus();var vGpu=Math.min(99,g.score+Math.round(rb/2));var vCpu=Math.min(99,CPU_SCORE+Math.round(rb/3));var vEdit=Math.min(99,Math.round(g.score*.45+CPU_SCORE*.42)+rb+Math.round(sb/2));var vMulti=Math.min(99,Math.round(CPU_SCORE*.55)+rb+sb+26);bGpu.style.width=vGpu+'%';bCpu.style.width=vCpu+'%';bEdit.style.width=vEdit+'%';bMulti.style.width=vMulti+'%';sGpu.textContent=label(vGpu);sCpu.textContent=label(vCpu);sEdit.textContent=label(vEdit);sMulti.textContent=label(vMulti)}function renderApps(){var html='';WORKLOADS.forEach(function(a,i){html+='<button class="app '+(i===state.app?'on':'')+'" data-app="'+i+'"><b>'+a[0]+'</b><span>'+a[1]+'</span></button>'});apps.innerHTML=html;document.querySelectorAll('.app').forEach(function(b){b.onclick=function(){state.app=+this.dataset.app;render()}})}function renderWork(){var a=WORKLOADS[state.app],g=byKey(GPU_OPTIONS,state.gpu);var score=Math.min(99,Math.round(a[2]*(g.score/GPU_OPTIONS[0].score)+ramBonus()/2+storageBonus()/3));workPanel.innerHTML='<div class="work-title">'+a[0]+'</div><div class="work-sub">'+a[1]+'</div><div class="work-row"><div class="work-num"><div class="work-val">'+score+'</div><div class="work-unit">SCORE</div></div><div class="work-side"><div class="track"><div class="fill" style="width:'+score+'%"></div></div><div class="work-rate">'+label(score)+' para esta carga</div></div></div><div class="tip">'+a[3]+'</div>'}function render(){updateSpecs();updateBars();renderApps();renderWork();sendHeight();setTimeout(sendHeight,120)}document.querySelectorAll('#gpuBtns .cfg').forEach(function(b){b.onclick=function(){state.gpu=this.dataset.gpu;setButtons('gpuBtns','gpu',state.gpu);render()}});document.querySelectorAll('#ramBtns .cfg').forEach(function(b){b.onclick=function(){state.ram=this.dataset.ram;setButtons('ramBtns','ram',state.ram);render()}});document.querySelectorAll('#storageBtns .cfg').forEach(function(b){b.onclick=function(){state.storage=this.dataset.storage;setButtons('storageBtns','storage',state.storage);render()}});function sendHeight(){window.parent&&window.parent.postMessage('iframeHeight:'+document.body.scrollHeight,'*')}window.addEventListener('load',function(){render();sendHeight();setTimeout(sendHeight,400)});window.addEventListener('resize',sendHeight);render();
</script>
</body>
</html>
"@
}

# ---- Load titles ----
$titles = @()
if ($ProductsJson -and (Test-Path -LiteralPath $ProductsJson)) {
  $raw = Get-Content -Raw -LiteralPath $ProductsJson | ConvertFrom-Json
  $items = if ($raw -is [System.Array]) { @($raw) } elseif ($raw.items) { @($raw.items) } else { @($raw) }
  foreach ($it in $items) {
    if ($it.Title) { $titles += [string]$it.Title }
    elseif ($it.name) { $titles += [string]$it.name }
    elseif ($it -is [string]) { $titles += $it }
  }
}
if (-not $titles.Count) { $titles = $DefaultTitles }

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$manifest = New-Object System.Collections.Generic.List[object]
$n = 0
foreach ($title in $titles) {
  $n++
  $file = 'ws-{0:D2}.html' -f $n
  $cpu = Get-CpuInfo $title
  $gpuKey = Get-GpuKey $title
  $gpuOpts = @(Get-GpuOptions $gpuKey)
  $ramInfo = Get-RamInfo $title
  $ramOpts = @(Get-RamOptions $ramInfo)
  $stor = Get-StorageInfo $title
  $storOpts = @(Get-StorageOptions $stor)
  $parsed = [pscustomobject]@{
    Title = $title
    Cpu = $cpu
    GpuOptions = $gpuOpts
    RamInfo = $ramInfo
    RamOptions = $ramOpts
    Storage = $stor
    StorageOptions = $storOpts
    Chipset = Get-Chipset $title
    Psu = Get-Psu $title
    Water = Test-WaterCooling $title
  }
  $html = New-WsHtml $parsed
  Write-Utf8NoBom (Join-Path $OutDir $file) $html

  $iframeSrc = "$ThemeBase/WORKSTATIONS/${file}?v=$ThemeVersion"
  $iframe = "<iframe src=`"$iframeSrc`" style=`"width:100%;height:2800px;border:0;`" loading=`"lazy`"></iframe>"
  $manifest.Add([pscustomobject]@{
    Title = $title
    File = $file
    iframe = $iframe
    OdooId = 0
    Matched = $false
    Sku = ''
  }) | Out-Null
  Write-Host ("OK {0}  GPU={1} RAM={2}" -f $file, $gpuOpts[0].n, $ramOpts[0].n)
}

Write-Utf8NoBom $ManifestPath ($manifest | ConvertTo-Json -Depth 6)
Write-Host ("Generadas: {0} HTML en {1}" -f $manifest.Count, $OutDir)
Write-Host ("Manifest: {0}" -f $ManifestPath)
