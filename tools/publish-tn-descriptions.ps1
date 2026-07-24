#Requires -Version 5.1
param(
  [string]$OdooUrl = $env:ODOO_URL,
  [string]$User    = $env:ODOO_USER,
  [string]$Secret  = $env:ODOO_PASS,
  [string]$Database = 'QuantumHard',
  [Parameter(Mandatory=$true)][string]$Manifest,   # ej: gpu_manifest.json
  [switch]$OnlyMatched,
  [string]$OnlyIds = '',
  [int]$Limit = 0,
  [int]$DelayMs = 250,
  [switch]$PullBack
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_xmlrpc-lib.ps1"

$base = $OdooUrl.TrimEnd('/') -replace '/odoo$',''
$common = "$base/xmlrpc/2/common"; $object = "$base/xmlrpc/2/object"
$uid = Invoke-XmlRpc $common 'authenticate' @($Database,$User,$Secret,@{})
if (-not $uid) { throw "Auth fallida" }
Write-Host "uid=$uid  DB=$Database"

# cargar manifest (array plano o {items})
$raw = Get-Content -Raw -LiteralPath $Manifest | ConvertFrom-Json
if ($raw -is [System.Array]) { $items = @($raw) }
elseif ($raw.items) { $items = @($raw.items) }
else { $items = @($raw) }

$idFilter = $null
if ($OnlyIds) { $idFilter = @($OnlyIds -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ }) }

function Invoke-Method($model,$method,$id){
  $idList = New-Object System.Collections.Generic.List[object]; $idList.Add([int]$id)
  $args = New-Object System.Collections.Generic.List[object]; $args.Add($idList)
  $p = New-Object System.Collections.Generic.List[object]
  foreach($x in @($Database,$uid,$Secret,$model,$method)){ $p.Add($x) }
  $p.Add($args); $p.Add(@{})
  Invoke-XmlRpc $object 'execute_kw' $p
}

$pushed=0; $pulled=0; $fail=0; $skip=0
foreach($it in $items){
  if ($OnlyMatched -and -not $it.Matched) { $skip++; continue }
  $id = [int]$it.OdooId
  if (-not $id) { $skip++; continue }
  if ($idFilter -and ($id -notin $idFilter)) { $skip++; continue }
  if ($Limit -gt 0 -and $pushed -ge $Limit) { $skip++; continue }

  try {
    Invoke-Method 'product.template' 'action_qh_tn_push_description' $id | Out-Null
    $pushed++
    Write-Output ("PUSH ok  {0}  ({1})" -f $id, $it.Title)
  } catch {
    $fail++; Write-Warning ("PUSH FALLO {0} ({1}) -> {2}" -f $id, $it.Title, $_.Exception.Message.Split([Environment]::NewLine)[0]); continue
  }
  if ($PullBack) {
    Start-Sleep -Milliseconds $DelayMs
    try { Invoke-Method 'product.template' 'action_qh_tn_pull_description' $id | Out-Null; $pulled++ }
    catch { Write-Warning ("PULL FALLO {0} -> {1}" -f $id, $_.Exception.Message.Split([Environment]::NewLine)[0]) }
  }
  Start-Sleep -Milliseconds $DelayMs
}
Write-Output ""
Write-Output ("== Resumen == push:{0} pull:{1} fallos:{2} omitidos:{3}" -f $pushed,$pulled,$fail,$skip)
