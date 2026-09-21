#Requires -Version 5.1
param(
  [string]$Coverage = '.\audits\odoo-coverage-20260921.json',
  [string]$OutputPath = '.\missing_all_20260921_manifest.json',
  [string]$ThemeBase = 'https://thiagodzzzz.github.io/quantum-descripciones-main',
  [string]$ThemeVersion = '20260921all'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$index = @{}
Get-ChildItem -Path $root -Recurse -File -Filter '*.html' | ForEach-Object {
  if ($_.Name -match '^(gpu|mb|psu|pc-gamer|ws|perif|cat)-(\d+)\.html$') {
    $kind = $Matches[1]
    $id = [int]$Matches[2]
    $rel = $_.FullName.Substring($root.Length).TrimStart('\','/').Replace('\','/')
    $height = switch ($kind) {
      'gpu' { 2800 }
      'mb' { 2400 }
      'psu' { 2200 }
      'pc-gamer' { 2800 }
      'ws' { 2800 }
      'perif' { 2200 }
      default { 2000 }
    }
    $index[$id] = [pscustomobject]@{ File = $rel; Height = $height }
  }
}

$cov = Get-Content -LiteralPath $Coverage -Raw | ConvertFrom-Json
$items = New-Object System.Collections.Generic.List[object]
$missingNoHtml = New-Object System.Collections.Generic.List[object]
foreach ($p in @($cov.products)) {
  if ([bool]$p.hasDesc) { continue }
  $id = [int]$p.id
  if (-not $index.ContainsKey($id)) {
    [void]$missingNoHtml.Add("$id | $($p.title)")
    continue
  }
  $hit = $index[$id]
  $iframe = "<iframe src=`"$ThemeBase/$($hit.File)?v=$ThemeVersion`" style=`"width:100%;height:$($hit.Height)px;border:0;`" loading=`"lazy`"></iframe>"
  [void]$items.Add([pscustomobject]@{
    OdooId = $id
    Title = [string]$p.title
    Sku = [string]$p.sku
    File = $hit.File
    iframe = $iframe
    Matched = $true
  })
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('[')
for ($i = 0; $i -lt $items.Count; $i++) {
  $piece = ($items[$i] | ConvertTo-Json -Depth 6 -Compress)
  if ($i -lt $items.Count - 1) { [void]$sb.AppendLine($piece + ',') } else { [void]$sb.AppendLine($piece) }
}
[void]$sb.AppendLine(']')
[System.IO.File]::WriteAllText($OutputPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
$missingNoHtml | Set-Content '.\audits\missing-20260921-no-local-html.txt' -Encoding UTF8
Write-Host ("Indexed HTML: {0}" -f $index.Count)
Write-Host ("Manifest: {0} ({1})" -f $OutputPath, $items.Count)
Write-Host ("Sin HTML local: {0}" -f $missingNoHtml.Count)