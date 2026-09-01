#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
. .\tools\_odoo-env-tmp.ps1
. .\tools\_xmlrpc-lib.ps1

$Sku = 'PC-9800X3D-5070TI-M'
$Iframe = '<iframe src="https://thiagodzzzz.github.io/quantum-descripciones-main/PCS-GAMER/pc-gamer-premium-9800x3d-5070ti.html?v=20260901quantumultra4" style="width:100%;height:3600px;border:0;" loading="lazy"></iframe>'

$base = $env:ODOO_URL.TrimEnd('/') -replace '/odoo$',''
$object = "$base/xmlrpc/2/object"
$common = "$base/xmlrpc/2/common"
$uid = Invoke-XmlRpc $common 'authenticate' @($env:ODOO_DB,$env:ODOO_USER,$env:ODOO_PASS,@{})
if (-not $uid) { throw 'Auth fallida' }
Write-Host "uid=$uid"

$c = New-Object System.Collections.Generic.List[object]; $c.Add('default_code'); $c.Add('='); $c.Add($Sku)
$dom = New-Object System.Collections.Generic.List[object]; $dom.Add($c)
$a = New-Object System.Collections.Generic.List[object]; $a.Add($dom)
$p = New-Object System.Collections.Generic.List[object]
foreach($x in @($env:ODOO_DB,$uid,$env:ODOO_PASS,'product.template','search_read')){ $p.Add($x) }
$p.Add($a)
$p.Add(@{ fields=@('id','name','default_code'); limit=5 })
$rows = @(Invoke-XmlRpc $object 'execute_kw' $p)
if (-not $rows.Count) { throw "Producto no encontrado SKU=$Sku" }
$id = [int]$rows[0].id
Write-Host "OdooId=$id $($rows[0].name)"

$w = New-Object System.Collections.Generic.List[object]
$w.Add(@{ qh_tn_description_raw = $Iframe })
$idList = New-Object System.Collections.Generic.List[object]; $idList.Add($id)
$args = New-Object System.Collections.Generic.List[object]; $args.Add($idList); $args.Add($w)
$pw = New-Object System.Collections.Generic.List[object]
foreach($x in @($env:ODOO_DB,$uid,$env:ODOO_PASS,'product.template','write')){ $pw.Add($x) }
$pw.Add($args)
Invoke-XmlRpc $object 'execute_kw' $pw | Out-Null
Write-Host "UPDATED qh_tn_description_raw"

$pushArgs = New-Object System.Collections.Generic.List[object]
$idList2 = New-Object System.Collections.Generic.List[object]; $idList2.Add($id)
$pushArgs.Add($idList2)
$pp = New-Object System.Collections.Generic.List[object]
foreach($x in @($env:ODOO_DB,$uid,$env:ODOO_PASS,'product.template','action_qh_tn_push_description')){ $pp.Add($x) }
$pp.Add($pushArgs); $pp.Add(@{})
Invoke-XmlRpc $object 'execute_kw' $pp | Out-Null
Write-Host "PUSH TN ok OdooId=$id"