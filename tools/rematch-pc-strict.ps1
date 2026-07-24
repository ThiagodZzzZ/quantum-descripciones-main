#Requires -Version 5.1
param(
  [string]$BuildsFile = 'audits\odoo-builds-clean.txt',
  [string[]]$Manifests = @('pc_gamer_full_manifest.json','ws_full_manifest.json'),
  [int]$MinScore = 55
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$builds = @()
Get-Content (Join-Path $Root $BuildsFile) | ForEach-Object {
  if ($_ -match '^\s*(\d+)\s*\|\s*(.+)$') {
    $n = $Matches[2].Trim()
    if ($n -notmatch 'Servicio de armado|ATX TEST') {
      $builds += [pscustomobject]@{ id = [int]$Matches[1]; name = $n }
    }
  }
}
Write-Host ("Builds cargados: {0}" -f $builds.Count)

function Get-CpuToken([string]$t) {
  $m = [regex]::Match($t, '(?i)\b((?:Ryzen|Athlon)\s*[3579]\s*\d{3,5}(?:X3D|XT|X|G|GT|F)?|(?:Intel\s+)?Core\s*i[3579]-?\d{4,5}[KF]?|i[3579]-?\d{4,5}[KF]?)\b')
  if (-not $m.Success) { return '' }
  $c = $m.Groups[1].Value.ToUpper() -replace '\s+', ''
  $c = $c -replace 'INTELCORE', 'CORE' -replace '^COREI', 'I'
  return $c
}

function Get-Tokens([string]$s) {
  $s = $s.ToUpper() -replace '[^A-Z0-9+ ]', ' '
  return @($s -split '\s+' | Where-Object { $_.Length -ge 3 })
}

function Get-Score([string]$title, [string]$name) {
  $cpu = Get-CpuToken $title
  if (-not $cpu) { return 0 }
  $nameCompact = ($name.ToUpper() -replace '\s+', '')
  if ($nameCompact -notlike ("*{0}*" -f $cpu)) { return 0 }
  $pipes = ([regex]::Matches($name, '\|')).Count
  if ($pipes -lt 3 -and $name -notmatch 'PC QUANTUM') { return 0 }
  $ta = Get-Tokens $title
  $tb = Get-Tokens $name
  $set = @{}
  foreach ($t in $tb) { $set[$t] = $true }
  $hit = 0
  foreach ($t in $ta) { if ($set.ContainsKey($t)) { $hit++ } }
  return [int](100.0 * $hit / [Math]::Max(1, $ta.Count))
}

function Load-Items([string]$path) {
  $raw = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
  if ($raw -is [System.Array]) { return @($raw) }
  if ($raw.PSObject.Properties.Name -contains 'value') { return @($raw.value) }
  if ($raw.PSObject.Properties.Name -contains 'items') { return @($raw.items) }
  return @($raw)
}

foreach ($mf in $Manifests) {
  $path = Join-Path $Root $mf
  $items = Load-Items $path
  Write-Host ""
  Write-Host ("=== {0} ({1}) ===" -f $mf, $items.Count)
  $out = @()
  $matched = 0; $un = 0
  foreach ($it in $items) {
    $title = [string]$it.Title
    $best = $null; $bestScore = -1
    foreach ($b in $builds) {
      $sc = Get-Score $title $b.name
      if ($sc -gt $bestScore) { $bestScore = $sc; $best = $b }
    }
    $oid = 0; $ok = $false; $mname = ''
    if ($best -and $bestScore -ge $MinScore) {
      $oid = [int]$best.id; $ok = $true; $mname = $best.name; $matched++
      Write-Host ("OK sc={0,3} #{1}  {2}" -f $bestScore, $oid, $it.File)
    } else {
      $un++
      Write-Host ("-- sc={0,3} cpu={1}  {2}" -f $bestScore, (Get-CpuToken $title), $it.File)
    }
    $out += [ordered]@{
      Title = $title
      File = [string]$it.File
      iframe = [string]$it.iframe
      OdooId = $oid
      Matched = $ok
      Sku = ''
      MatchedName = $mname
    }
  }
  $json = ($out | ForEach-Object { [pscustomobject]$_ }) | ConvertTo-Json -Depth 6
  if ($out.Count -eq 1) { $json = "[$json]" }
  $enc = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $json, $enc)
  Write-Host ("Saved matched={0} unmatched={1}" -f $matched, $un)
}
