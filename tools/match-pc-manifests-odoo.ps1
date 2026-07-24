#Requires -Version 5.1
<#
.SYNOPSIS
  Empareja manifests de PC Gamer / Workstation con product.template en Odoo.
.DESCRIPTION
  - Usa ODOO_URL / ODOO_USER / ODOO_PASS (DB QuantumHard)
  - Extrae token CPU distintivo (5800XT, 7800X3D, i5-12400, etc.)
  - Busca name ilike %TOKEN%
  - Elige el mejor match con >= 3 segmentos '|' y mayor similitud de tokens (GPU, RAM, PSU, chipset)
  - Actualiza OdooId / Matched / Sku en el JSON
  - NO sube descripciones ni escribe en Odoo
.EXAMPLE
  $env:ODOO_URL='https://...'; $env:ODOO_USER='...'; $env:ODOO_PASS='...'
  .\tools\match-pc-manifests-odoo.ps1
  .\tools\match-pc-manifests-odoo.ps1 -Manifest pc_gamer_full_manifest.json
#>
param(
  [string]$OdooUrl = $env:ODOO_URL,
  [string]$User = $env:ODOO_USER,
  [string]$Secret = $env:ODOO_PASS,
  [string]$Database = 'QuantumHard',
  [string[]]$Manifests = @(),
  [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'
trap { Write-Host ("ERROR: {0}" -f $_.Exception.Message); Write-Host $_.InvocationInfo.PositionMessage; break }
. "$PSScriptRoot\_xmlrpc-lib.ps1"

if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
if (-not $Manifests -or $Manifests.Count -eq 0) {
  $Manifests = @(
    (Join-Path $RepoRoot 'pc_gamer_full_manifest.json'),
    (Join-Path $RepoRoot 'ws_full_manifest.json')
  )
}

if (-not $OdooUrl -or -not $User -or -not $Secret) {
  throw "Faltan credenciales. Definir ODOO_URL, ODOO_USER y ODOO_PASS."
}

$base = $OdooUrl.TrimEnd('/') -replace '/odoo$',''
$common = "$base/xmlrpc/2/common"
$object = "$base/xmlrpc/2/object"
$uid = Invoke-XmlRpc $common 'authenticate' @($Database, $User, $Secret, @{})
if (-not $uid) { throw "Auth fallida contra $Database" }
Write-Host "uid=$uid  DB=$Database"

function Search-Read($field, $op, $val, $fields, $limit = 40) {
  $c = New-Object System.Collections.Generic.List[object]
  $c.Add($field); $c.Add($op); $c.Add($val)
  $dom = New-Object System.Collections.Generic.List[object]
  $dom.Add($c)
  $a = New-Object System.Collections.Generic.List[object]
  $a.Add($dom)
  $p = New-Object System.Collections.Generic.List[object]
  foreach ($x in @($Database, $uid, $Secret, 'product.template', 'search_read')) { $p.Add($x) }
  $p.Add($a)
  $p.Add(@{ fields = $fields; limit = [int]$limit })
  return @(Invoke-XmlRpc $object 'execute_kw' $p)
}

function Get-CpuToken([string]$Title) {
  # Tokens distintivos de mayor a menor especificidad
  $patterns = @(
    '(?i)\b(9800X3D|7800X3D|7950X|9950X|7900X|5900XT|5800XT|5700X|5700G|5600GT|5600G|5500|7600X|7700X|7700|8700G|8600G|8500G|9700X|3000G)\b',
    '(?i)\b(i9-13900F|i5-13400|i5-12400|i3-13100F|i3-12100F|i3-12100)\b',
    '(?i)\b(Core\s+i[3579]-?\d{4,5}\w*)\b',
    '(?i)\b(Ryzen\s+[579]\s+\w+)\b',
    '(?i)\b(Athlon\s+\w+)\b'
  )
  foreach ($pat in $patterns) {
    $m = [regex]::Match($Title, $pat)
    if ($m.Success) {
      $t = $m.Groups[1].Value -replace '\s+', ' '
      # Preferir el numero/modelo solo cuando sea corto y distintivo
      if ($t -match '(?i)(9800X3D|7800X3D|7950X|9950X|7900X|7900|5900XT|5800XT|5700X|5700G|5600GT|5600G|5500|7600X|7700X|7700|8700G|8600G|8500G|9700X|3000G|i9-13900F|i5-13400|i5-12400|i3-13100F|i3-12100F|i3-12100)') {
        return $Matches[1]
      }
      return $t
    }
  }
  return $null
}

function Get-SignificantTokens([string]$Title) {
  $u = $Title.ToUpperInvariant()
  $tokens = New-Object System.Collections.Generic.List[string]
  $add = {
    param($t)
    if ($t -and -not $tokens.Contains($t)) { $tokens.Add($t) | Out-Null }
  }

  # GPU
  if ($u -match 'RTX\s*(\d{4}\s*(?:TI|SUPER)?)') { & $add ("RTX" + ($Matches[1] -replace '\s+','')) }
  elseif ($u -match 'GTX\s*(\d{3,4}\s*(?:TI|SUPER)?)') { & $add ("GTX" + ($Matches[1] -replace '\s+','')) }
  elseif ($u -match 'RX\s*(\d{3,4}\w*)') { & $add ("RX" + $Matches[1]) }
  elseif ($u -match '780M|760M|740M|VEGA\s*8|VEGA\s*7|RADEON|INTEGRAD') { & $add 'IGPU' }

  # RAM size
  if ($u -match '(\d+)\s*X\s*(\d+)\s*GB') { & $add (("RAM{0}" -f ([int]$Matches[1]*[int]$Matches[2]))) }
  elseif ($u -match 'DDR[45]\s*(\d+)\s*GB|(\d+)\s*GB\s*DDR|\b(8|16|32|64)\s*GB\b') {
    $g = $Matches[1]; if (-not $g) { $g = $Matches[2] }; if (-not $g) { $g = $Matches[3] }
    & $add ("RAM$g")
  }

  # DDR type
  if ($u -match 'DDR5') { & $add 'DDR5' } elseif ($u -match 'DDR4') { & $add 'DDR4' }

  # PSU
  if ($u -match '(\d{3,4})\s*W') { & $add ("PSU$($Matches[1])") }

  # Chipset / board
  if ($u -match '\b(B840|B850|B650|B550M|B550|A520|H610M|H610|B760|X670)\b') { & $add $Matches[1] }

  # Storage
  if ($u -match '240\s*GB') { & $add 'SSD240' }
  elseif ($u -match '1\s*TB|1TB') { & $add 'SSD1TB' }
  elseif ($u -match '2\s*TB|2TB') { & $add 'SSD2TB' }

  # Form / cooling
  if ($u -match 'MINI\s*ITX|ITX') { & $add 'ITX' }
  if ($u -match 'WATER') { & $add 'WATER' }

  return @($tokens)
}

function Get-PipeSegmentCount([string]$Name) {
  return (@($Name -split '\|')).Count
}

function Score-Match([string]$Title, [string]$CandidateName) {
  $a = @(Get-SignificantTokens $Title)
  $b = @(Get-SignificantTokens $CandidateName)
  if (-not $a.Count) { return 0 }
  $shared = 0
  foreach ($t in $a) { if ($b -contains $t) { $shared++ } }
  # Bonus por misma cantidad de RAM exacta / GPU exacta
  $score = $shared
  # Penalizar si el candidato tiene muy pocos tokens
  if ($b.Count -eq 0) { $score = $score * 0.5 }
  return [double]$score
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

$totalMatched = 0
$totalUnmatched = 0

foreach ($manifestPath in $Manifests) {
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Warning "No existe: $manifestPath"
    continue
  }
  Write-Host ""
  Write-Host "=== Manifest: $manifestPath ==="
  $raw = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
  $items = if ($raw -is [System.Array]) { @($raw) } else { @($raw) }
  $out = New-Object System.Collections.Generic.List[object]
  $matched = 0; $unmatched = 0

  foreach ($it in $items) {
    $title = [string]$it.Title
    $token = Get-CpuToken $title
    $best = $null
    $bestScore = -1.0

    if ($token) {
      $rows = @(Search-Read 'name' 'ilike' "%$token%" @('id','name','default_code') 50)
      # Filtrar candidatos con estructura de PC (al menos 3 segmentos |)
      $cands = @($rows | Where-Object { (Get-PipeSegmentCount ([string]$_.name)) -ge 3 })
      if (-not $cands.Count) { $cands = @($rows) }

      foreach ($row in $cands) {
        $sc = Score-Match $title ([string]$row.name)
        # Preferir mas segmentos pipe como desempate
        $sc += (Get-PipeSegmentCount ([string]$row.name)) * 0.05
        if ($sc -gt $bestScore) {
          $bestScore = $sc
          $best = $row
        }
      }
    }

    $obj = [ordered]@{
      Title = $title
      File = [string]$it.File
      iframe = [string]$it.iframe
      OdooId = 0
      Matched = $false
      Sku = ''
    }
    if ($best -and $bestScore -gt 0) {
      $obj.OdooId = [int]$best.id
      $obj.Matched = $true
      $obj.Sku = if ($best.default_code) { [string]$best.default_code } else { '' }
      $matched++
      Write-Host ("MATCH  [{0}] token={1} score={2:N1} -> #{3}  {4}" -f $it.File, $token, $bestScore, $best.id, $best.name)
    } else {
      $unmatched++
      Write-Host ("NO MATCH  [{0}] token={1}  title={2}" -f $it.File, $token, $title)
    }
    $out.Add([pscustomobject]$obj) | Out-Null
  }

  Write-Utf8NoBom $manifestPath ($out | ConvertTo-Json -Depth 6)
  Write-Host ("Resumen {0}: matched={1} unmatched={2}" -f (Split-Path $manifestPath -Leaf), $matched, $unmatched)
  $totalMatched += $matched
  $totalUnmatched += $unmatched
}

Write-Host ""
Write-Host ("TOTAL matched={0} unmatched={1}" -f $totalMatched, $totalUnmatched)
Write-Host "Uso: definir ODOO_URL/USER/PASS y ejecutar este script. No escribe en Odoo; solo actualiza los JSON locales."
