#Requires -Version 5.1
# Audita cobertura de descripciones en Odoo (product.template).
# Exporta todos los productos con categoria y si tienen qh_tn_description_raw.
param(
  [string]$OdooUrl = $env:ODOO_URL,
  [string]$User    = $env:ODOO_USER,
  [string]$Secret  = $env:ODOO_PASS,
  [string]$Database = 'QuantumHard',
  [string]$DescField = 'qh_tn_description_raw',
  [string]$OutFile = '.\audits\odoo-coverage.json'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_xmlrpc-lib.ps1"

$base = $OdooUrl.TrimEnd('/') -replace '/odoo$',''
$uid = Invoke-XmlRpc "$base/xmlrpc/2/common" 'authenticate' @($Database,$User,$Secret,@{})
if (-not $uid) { throw "Auth fallida" }
Write-Host "uid=$uid DB=$Database"

# search_read TODOS los product.template activos, vendibles en web
$c = New-Object System.Collections.Generic.List[object]; $c.Add('sale_ok'); $c.Add('='); $c.Add($true)
$dom = New-Object System.Collections.Generic.List[object]; $dom.Add($c)
$a = New-Object System.Collections.Generic.List[object]; $a.Add($dom)
$p = New-Object System.Collections.Generic.List[object]
foreach($x in @($Database,$uid,$Secret,'product.template','search_read')){ $p.Add($x) }
$p.Add($a); $p.Add(@{ fields=@('id','name','default_code','categ_id',$DescField); order='id asc' })
$rows = @(Invoke-XmlRpc "$base/xmlrpc/2/object" 'execute_kw' $p)
Write-Host ("Productos (sale_ok): {0}" -f $rows.Count)

$products = foreach($r in $rows){
  $raw = $r.$DescField
  $has = -not ([string]::IsNullOrWhiteSpace([string]$raw) -or ($raw -is [bool] -and -not $raw))
  [pscustomobject]@{
    id = [int]$r.id
    title = [string]$r.name
    sku = if($r.default_code){ [string]$r.default_code } else { '' }
    categ = if($r.categ_id){ [string]$r.categ_id[1] } else { '(sin categoria)' }
    hasDesc = [bool]$has
  }
}

$out = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  descField = $DescField
  total = @($products).Count
  withDesc = @($products | Where-Object { $_.hasDesc }).Count
  missing = @($products | Where-Object { -not $_.hasDesc }).Count
  products = @($products)
}
$dir = Split-Path -Parent $OutFile
if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$out | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8

Write-Host ("== Cobertura == total:{0}  con desc:{1}  faltan:{2}" -f $out.total,$out.withDesc,$out.missing)
Write-Host ""
Write-Host "Faltantes por categoria (top):"
$products | Where-Object { -not $_.hasDesc } | Group-Object categ | Sort-Object Count -Descending |
  Select-Object -First 40 | ForEach-Object { "  {0,4}  {1}" -f $_.Count, $_.Name }
