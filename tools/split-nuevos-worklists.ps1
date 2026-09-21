#Requires -Version 5.1
# Parte audits/nuevos-sin-desc-*.json en worklists por generador.
param(
  [string]$Source = '.\audits\nuevos-sin-desc-20260818.json',
  [string]$OutDir = '.\audits',
  [string]$OutputPrefix = 'nuevos',
  [switch]$ExcludeExistingHtml
)
$ErrorActionPreference = 'Stop'
$src = Get-Content -LiteralPath $Source -Raw | ConvertFrom-Json
$products = @($src.products | Where-Object {
  $hasDescProperty = $_.PSObject.Properties['hasDesc']
  -not $hasDescProperty -or -not [bool]$_.hasDesc
})
if ($ExcludeExistingHtml) {
  $repoRoot = Split-Path $PSScriptRoot -Parent
  $existingIds = New-Object 'System.Collections.Generic.HashSet[int]'
  Get-ChildItem -Path $repoRoot -Recurse -File -Filter '*.html' | ForEach-Object {
    if ($_.Name -match '(?:gpu|mb|psu|pc-gamer|perif|cat)-(\d+)\.html$') {
      [void]$existingIds.Add([int]$Matches[1])
    }
  }
  $before = $products.Count
  $products = @($products | Where-Object { -not $existingIds.Contains([int]$_.id) })
  Write-Host ("Excluded existing HTML: {0}" -f ($before - $products.Count))
}

function Get-PerifFolder([string]$categ, [string]$title) {
  $c = "$categ $title"
  if ($c -match '(?i)mouse\s*pad|mousepad|pad\s*gamer') { return 'accesorios' }
  if ($c -match '(?i)\bmouse\b') { return 'mouse' }
  if ($c -match '(?i)teclado|keyboard') { return 'teclados' }
  if ($c -match '(?i)auricular|headset|headphone') { return 'auriculares' }
  if ($c -match '(?i)parlante|speaker') { return 'parlantes' }
  if ($c -match '(?i)webcam|camara') { return 'webcams' }
  if ($c -match '(?i)microfono|microphone|\bmic\b') { return 'microfonos' }
  if ($c -match '(?i)silla') { return 'sillas' }
  if ($c -match '(?i)volante|joystick|gamepad|control') { return 'gaming' }
  if ($c -match '(?i)monitor') { return 'monitores' }
  return 'accesorios'
}

function Top-Cat([string]$categ) {
  if ([string]::IsNullOrWhiteSpace($categ) -or $categ -match 'sin categoria') { return 'Sin categoria' }
  return ($categ -split '/')[0].Trim()
}

function Write-JsonArrayFile([string]$Path, $Items) {
  $list = @($Items)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('[')
  for ($i = 0; $i -lt $list.Count; $i++) {
    $piece = ($list[$i] | ConvertTo-Json -Depth 6 -Compress)
    if ($i -lt $list.Count - 1) { [void]$sb.AppendLine($piece + ',') } else { [void]$sb.AppendLine($piece) }
  }
  [void]$sb.AppendLine(']')
  [System.IO.File]::WriteAllText($Path, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
  Write-Host ("Wrote {0} ({1})" -f $Path, $list.Count)
}

function Write-WrappedProducts([string]$Path, $Items) {
  $list = @($Items)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('{')
  [void]$sb.AppendLine(('  "generatedAt": "{0}",' -f (Get-Date).ToUniversalTime().ToString('o')))
  [void]$sb.AppendLine('  "products": [')
  for ($i = 0; $i -lt $list.Count; $i++) {
    $piece = ($list[$i] | ConvertTo-Json -Depth 6 -Compress)
    if ($i -lt $list.Count - 1) { [void]$sb.AppendLine('    ' + $piece + ',') } else { [void]$sb.AppendLine('    ' + $piece) }
  }
  [void]$sb.AppendLine('  ]')
  [void]$sb.AppendLine('}')
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($Path, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
  Write-Host ("Wrote {0} ({1})" -f $Path, $list.Count)
}

function Write-WrappedItems([string]$Path, $Items) {
  $list = @($Items)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('{')
  [void]$sb.AppendLine(('  "generatedAt": "{0}",' -f (Get-Date).ToUniversalTime().ToString('o')))
  [void]$sb.AppendLine('  "items": [')
  for ($i = 0; $i -lt $list.Count; $i++) {
    $piece = ($list[$i] | ConvertTo-Json -Depth 6 -Compress)
    if ($i -lt $list.Count - 1) { [void]$sb.AppendLine('    ' + $piece + ',') } else { [void]$sb.AppendLine('    ' + $piece) }
  }
  [void]$sb.AppendLine('  ]')
  [void]$sb.AppendLine('}')
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($Path, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
  Write-Host ("Wrote {0} ({1})" -f $Path, $list.Count)
}

$gpus = @(); $mbs = @(); $psus = @(); $pcs = @(); $perif = @(); $catalog = @(); $skip = @()

foreach ($p in $products) {
  $categ = [string]$p.categ
  $title = [string]$p.title
  $id = [int]$p.id
  $sku = [string]$p.sku
  $entryProd = [pscustomobject]@{ id = $id; title = $title; internalReference = $sku; sku = $sku; categ = $categ }

  if ($categ -match '(?i)Placas de video') {
    $gpus += $entryProd
    continue
  }
  if ($categ -match '(?i)Motherboard') {
    $mbs += $entryProd
    continue
  }
  if ($categ -match '(?i)Fuentes' -and $title -notmatch '(?i)^\s*Cable\b') {
    $psus += $entryProd
    continue
  }
  if (($categ -match '(?i)Hardware\s*/\s*PCs' -and $title -match '\|') -or ($title -match '(?i)\|.*\|' -and $sku -match '(?i)^PC-')) {
    $pcs += $entryProd
    continue
  }
  if ($categ -match '(?i)^Perif') {
    $folder = Get-PerifFolder $categ $title
    $perif += [pscustomobject]@{ id = $id; title = $title; sku = $sku; folder = $folder; categ = $categ }
    continue
  }
  if ($categ -match '(?i)Pendiente Mapping|Goods') {
    $skip += $entryProd
    continue
  }
  $catalog += [pscustomobject]@{ id = $id; title = $title; sku = $sku; categ = $categ }
}

$byCat = @{}
foreach ($it in $catalog) {
  $top = Top-Cat $it.categ
  if (-not $byCat.ContainsKey($top)) { $byCat[$top] = @() }
  $byCat[$top] += $it
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-WrappedProducts (Join-Path $OutDir "$OutputPrefix-gpus-worklist.json") $gpus
Write-WrappedProducts (Join-Path $OutDir "$OutputPrefix-mb-worklist.json") $mbs
Write-WrappedProducts (Join-Path $OutDir "$OutputPrefix-psu-worklist.json") $psus
Write-WrappedProducts (Join-Path $OutDir "$OutputPrefix-pcs-worklist.json") $pcs
Write-WrappedItems (Join-Path $OutDir "$OutputPrefix-perifericos-worklist.json") $perif
Write-WrappedProducts (Join-Path $OutDir "$OutputPrefix-skip-mapping.json") $skip

# catalogo byCategory manual
$catPath = Join-Path $OutDir "$OutputPrefix-catalogo-worklist.json"
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('{')
[void]$sb.AppendLine(('  "generatedAt": "{0}",' -f (Get-Date).ToUniversalTime().ToString('o')))
[void]$sb.AppendLine('  "byCategory": [')
$keys = @($byCat.Keys | Sort-Object)
for ($ki = 0; $ki -lt $keys.Count; $ki++) {
  $k = $keys[$ki]
  $items = @($byCat[$k])
  [void]$sb.AppendLine('    {')
  [void]$sb.AppendLine(('      "category": {0},' -f (ConvertTo-Json $k)))
  [void]$sb.AppendLine(('      "count": {0},' -f $items.Count))
  [void]$sb.AppendLine('      "items": [')
  for ($i = 0; $i -lt $items.Count; $i++) {
    $piece = ($items[$i] | ConvertTo-Json -Depth 6 -Compress)
    if ($i -lt $items.Count - 1) { [void]$sb.AppendLine('        ' + $piece + ',') } else { [void]$sb.AppendLine('        ' + $piece) }
  }
  [void]$sb.AppendLine('      ]')
  if ($ki -lt $keys.Count - 1) { [void]$sb.AppendLine('    },') } else { [void]$sb.AppendLine('    }') }
}
[void]$sb.AppendLine('  ]')
[void]$sb.AppendLine('}')
[System.IO.File]::WriteAllText($catPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
Write-Host ("Wrote {0} ({1})" -f $catPath, $catalog.Count)

$pcMan = @($pcs | ForEach-Object {
  [pscustomobject]@{
    OdooId = $_.id
    Title = $_.title
    Sku = $_.sku
    File = ("pc-gamer-{0}.html" -f $_.id)
  }
})
Write-JsonArrayFile (Join-Path $OutDir "$OutputPrefix-pcs-manifest-seed.json") $pcMan

Write-Host ''
Write-Host '== Resumen split =='
Write-Host ("GPU:  {0}" -f $gpus.Count)
Write-Host ("MB:   {0}" -f $mbs.Count)
Write-Host ("PSU:  {0}" -f $psus.Count)
Write-Host ("PC:   {0}" -f $pcs.Count)
Write-Host ("Perif:{0}" -f $perif.Count)
Write-Host ("Cat:  {0}" -f $catalog.Count)
Write-Host ("Skip: {0}" -f $skip.Count)
Write-Host ("TOTAL:{0}" -f ($gpus.Count + $mbs.Count + $psus.Count + $pcs.Count + $perif.Count + $catalog.Count + $skip.Count))
