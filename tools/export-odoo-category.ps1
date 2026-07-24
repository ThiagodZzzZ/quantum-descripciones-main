#Requires -Version 5.1
# Exporta productos de una categoria (por nombre, ilike) desde Odoo.
# Salida JSON: { category, count, products:[{id,title,internalReference,categ}] }
param(
  [string]$OdooUrl = $env:ODOO_URL,
  [string]$User    = $env:ODOO_USER,
  [string]$Secret  = $env:ODOO_PASS,
  [string]$Database = 'QuantumHard',
  [Parameter(Mandatory=$true)][string]$CategLike,   # ej: 'fuente'  /  'motherboard'
  [Parameter(Mandatory=$true)][string]$OutFile
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_xmlrpc-lib.ps1"

$base = $OdooUrl.TrimEnd('/') -replace '/odoo$',''
$uid = Invoke-XmlRpc "$base/xmlrpc/2/common" 'authenticate' @($Database,$User,$Secret,@{})
if (-not $uid) { throw "Auth fallida" }
Write-Host "uid=$uid  DB=$Database  categoria ilike '$CategLike'"

$c = New-Object System.Collections.Generic.List[object]; $c.Add('categ_id.complete_name'); $c.Add('ilike'); $c.Add($CategLike)
$dom = New-Object System.Collections.Generic.List[object]; $dom.Add($c)
$a = New-Object System.Collections.Generic.List[object]; $a.Add($dom)
$p = New-Object System.Collections.Generic.List[object]
foreach($x in @($Database,$uid,$Secret,'product.template','search_read')){ $p.Add($x) }
$p.Add($a); $p.Add(@{ fields=@('id','name','default_code','categ_id'); order='name asc' })
$rows = @(Invoke-XmlRpc "$base/xmlrpc/2/object" 'execute_kw' $p)

$products = foreach($r in $rows){
  [pscustomobject]@{
    id = [int]$r.id
    title = [string]$r.name
    internalReference = if($r.default_code){ [string]$r.default_code } else { '' }
    categ = if($r.categ_id){ [string]$r.categ_id[1] } else { '' }
  }
}

$out = [ordered]@{
  category = $CategLike
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  count = @($products).Count
  products = @($products)
}
$out | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8
Write-Host ("Exportados: {0} -> {1}" -f @($products).Count, $OutFile)
