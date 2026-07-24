#Requires -Version 5.1
# Enriquece un manifest (Title/Sku/File/Iframe) con OdooId + Matched.
# Busca por default_code (SKU); fallback por name exacto; expande duplicados (varias copias del mismo producto en Odoo).
param(
  [string]$OdooUrl = $env:ODOO_URL,
  [string]$User    = $env:ODOO_USER,
  [string]$Secret  = $env:ODOO_PASS,
  [string]$Database = 'QuantumHard',
  [Parameter(Mandatory=$true)][string]$Manifest,
  [string]$OutFile = ''
)
$ErrorActionPreference = 'Stop'
trap { Write-Host ("ERROR: {0}" -f $_.Exception.Message); Write-Host $_.InvocationInfo.PositionMessage; break }
. "$PSScriptRoot\_xmlrpc-lib.ps1"

if (-not $OutFile) { $OutFile = [IO.Path]::ChangeExtension($Manifest, $null).TrimEnd('.') + '_odoo.json' }

$base = $OdooUrl.TrimEnd('/') -replace '/odoo$',''
$common = "$base/xmlrpc/2/common"; $object = "$base/xmlrpc/2/object"
$uid = Invoke-XmlRpc $common 'authenticate' @($Database,$User,$Secret,@{})
if (-not $uid) { throw "Auth fallida" }
Write-Host "uid=$uid  DB=$Database"

$raw = Get-Content -Raw -LiteralPath $Manifest | ConvertFrom-Json
$items = if ($raw -is [System.Array]) { @($raw) } elseif ($raw.items) { @($raw.items) } else { @($raw) }

function Search-Read($field,$op,$val,$fields){
  $c = New-Object System.Collections.Generic.List[object]; $c.Add($field); $c.Add($op); $c.Add($val)
  $dom = New-Object System.Collections.Generic.List[object]; $dom.Add($c)
  $a = New-Object System.Collections.Generic.List[object]; $a.Add($dom)
  $p = New-Object System.Collections.Generic.List[object]
  foreach($x in @($Database,$uid,$Secret,'product.template','search_read')){ $p.Add($x) }
  $p.Add($a); $p.Add(@{fields=$fields})
  $res = Invoke-XmlRpc $object 'execute_kw' $p
  return $res
}

# 1) batch por SKU: traemos todas las filas y luego filtramos por default_code
$skus = @($items | ForEach-Object { $_.Sku } | Where-Object { $_ } | Select-Object -Unique)
$allRows = @()
if ($skus.Count) {
  $allRows = @(Search-Read 'default_code' 'in' ([object[]]$skus) @('id','name','default_code'))
}

$out = New-Object System.Collections.Generic.List[object]
$matched=0; $unmatched=0; $expanded=0
foreach($it in $items){
  $ids = @()
  $sku = if ($it.Sku) { [string]$it.Sku } else { '' }
  if ($sku -ne '') { $ids = @($allRows | Where-Object { [string]$_.default_code -eq $sku } | ForEach-Object { [int]$_.id }) }
  if (-not $ids.Count -and $it.Title) {
    $rows = @(Search-Read 'name' '=' ([string]$it.Title) @('id','name'))
    if ($rows.Count) { $ids = @($rows | ForEach-Object { [int]$_.id }) }
  }
  if (-not $ids.Count) {
    $unmatched++
    $o = [ordered]@{ Title=$it.Title; Sku=$it.Sku; File=$it.File; iframe=$it.Iframe; OdooId=0; Matched=$false }
    $out.Add([pscustomobject]$o); continue
  }
  $matched++
  if ($ids.Count -gt 1) { $expanded += ($ids.Count-1) }
  foreach($id in $ids){
    $o = [ordered]@{ Title=$it.Title; Sku=$it.Sku; File=$it.File; iframe=$it.Iframe; OdooId=[int]$id; Matched=$true }
    $out.Add([pscustomobject]$o)
  }
}

$out | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8
Write-Host ("Manifest items: {0}  matched:{1}  unmatched:{2}  copias extra:{3}  -> filas Odoo:{4}" -f $items.Count,$matched,$unmatched,$expanded,$out.Count)
Write-Host ("Salida: {0}" -f $OutFile)
