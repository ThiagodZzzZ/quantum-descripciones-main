param(
  [string]$OdooUrl = $env:ODOO_URL,
  [string]$Database = $env:ODOO_DB,
  [string]$User = $env:ODOO_USER,
  [string]$ApiKey = $env:ODOO_PASS,
  [string]$ManifestGlob = '*_manifest.json',
  [string[]]$DescriptionField = @('qh_tn_description_raw'),
  [switch]$OnlyMatched,
  [int]$Limit = 0,
  [string]$OnlyIds = '',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function New-XmlRpcCall($methodName, $params) {
  $doc = New-Object System.Xml.XmlDocument
  $methodCall = $doc.CreateElement('methodCall')
  $doc.AppendChild($methodCall) | Out-Null
  $method = $doc.CreateElement('methodName')
  $method.InnerText = $methodName
  $methodCall.AppendChild($method) | Out-Null
  $paramsNode = $doc.CreateElement('params')
  $methodCall.AppendChild($paramsNode) | Out-Null

  foreach ($paramValue in $params) {
    $param = $doc.CreateElement('param')
    $value = ConvertTo-XmlRpcValue $doc $paramValue
    $param.AppendChild($value) | Out-Null
    $paramsNode.AppendChild($param) | Out-Null
  }

  $doc.OuterXml
}

function ConvertTo-XmlRpcValue($doc, $value) {
  $valueNode = $doc.CreateElement('value')
  if ($null -eq $value) {
    $valueNode.AppendChild($doc.CreateElement('nil')) | Out-Null
  } elseif ($value -is [int]) {
    $node = $doc.CreateElement('int')
    $node.InnerText = [string]$value
    $valueNode.AppendChild($node) | Out-Null
  } elseif ($value -is [bool]) {
    $node = $doc.CreateElement('boolean')
    $node.InnerText = if ($value) { '1' } else { '0' }
    $valueNode.AppendChild($node) | Out-Null
  } elseif ($value -is [hashtable]) {
    $struct = $doc.CreateElement('struct')
    foreach ($key in $value.Keys) {
      $member = $doc.CreateElement('member')
      $name = $doc.CreateElement('name')
      $name.InnerText = [string]$key
      $member.AppendChild($name) | Out-Null
      $member.AppendChild((ConvertTo-XmlRpcValue $doc $value[$key])) | Out-Null
      $struct.AppendChild($member) | Out-Null
    }
    $valueNode.AppendChild($struct) | Out-Null
  } elseif ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
    $array = $doc.CreateElement('array')
    $data = $doc.CreateElement('data')
    foreach ($item in $value) {
      $data.AppendChild((ConvertTo-XmlRpcValue $doc $item)) | Out-Null
    }
    $array.AppendChild($data) | Out-Null
    $valueNode.AppendChild($array) | Out-Null
  } else {
    $node = $doc.CreateElement('string')
    $node.InnerText = [string]$value
    $valueNode.AppendChild($node) | Out-Null
  }
  $valueNode
}

function Invoke-XmlRpc($endpoint, $methodName, $params) {
  $body = New-XmlRpcCall $methodName $params
  $response = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $endpoint -ContentType 'text/xml' -Body $body -TimeoutSec 60
  $xml = [xml]$response.Content
  $fault = $xml.methodResponse.fault
  if ($fault) { throw "Odoo XML-RPC fault: $($response.Content)" }
  $value = $xml.methodResponse.params.param.value
  ConvertFrom-XmlRpcValue $value
}

function ConvertFrom-XmlRpcValue($valueNode) {
  if ($valueNode.array) {
    return @($valueNode.array.data.value | ForEach-Object { ConvertFrom-XmlRpcValue $_ })
  }
  if ($valueNode.struct) {
    $hash = @{}
    foreach ($member in $valueNode.struct.member) {
      $hash[$member.name] = ConvertFrom-XmlRpcValue $member.value
    }
    return $hash
  }
  if ($valueNode.int) { return [int]$valueNode.int }
  if ($valueNode.i4) { return [int]$valueNode.i4 }
  if ($valueNode.boolean) { return [string]$valueNode.boolean -eq '1' }
  if ($valueNode.string) { return [string]$valueNode.string }
  return [string]$valueNode.InnerText
}

$baseUrl = $OdooUrl.TrimEnd('/') -replace '/odoo$', ''
$common = "$baseUrl/xmlrpc/2/common"
$object = "$baseUrl/xmlrpc/2/object"
$uid = Invoke-XmlRpc $common 'authenticate' @($Database, $User, $ApiKey, @{})
if (-not $uid) { throw 'No se pudo autenticar contra Odoo.' }

$items = @()
Get-ChildItem -LiteralPath . -Filter $ManifestGlob | ForEach-Object {
  $manifest = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
  if ($manifest -is [System.Array]) { $items += $manifest }      # array plano [ ... ]
  elseif ($manifest.items) { $items += $manifest.items }         # objeto { items: [...] }
  else { $items += @($manifest) }
}

$idFilter = $null
if ($OnlyIds) { $idFilter = @($OnlyIds -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ }) }

$updated = 0; $skipped = 0; $missing = 0
foreach ($item in $items) {
  if ($OnlyMatched -and -not $item.Matched) { $skipped++; continue }
  if (-not $item.iframe) { $skipped++; continue }

  # Preferir OdooId (unico y sin ambiguedad). Fallback a busqueda por titulo.
  $id = $null
  if ($item.OdooId) {
    $id = [int]$item.OdooId
  } elseif ($item.title) {
    $domain = @(@('name', '=', [string]$item.title))
    $ids = Invoke-XmlRpc $object 'execute_kw' @($Database, $uid, $ApiKey, 'product.template', 'search', @($domain), @{ limit = 1 })
    if ($ids -and $ids.Count -gt 0) { $id = [int]$ids[0] }
  }
  if (-not $id) {
    Write-Warning "Sin OdooId ni match por titulo: $($item.title)"
    $missing++; continue
  }

  if ($idFilter -and ($id -notin $idFilter)) { $skipped++; continue }
  if ($Limit -gt 0 -and $updated -ge $Limit) { $skipped++; continue }

  if ($DryRun) {
    # Verificar que el ID exista realmente en Odoo
    $domainId = @(@('id', '=', $id))
    $found = Invoke-XmlRpc $object 'execute_kw' @($Database, $uid, $ApiKey, 'product.template', 'search', @($domainId), @{ limit = 1 })
    if ($found -and $found.Count -gt 0) {
      Write-Output "DRYRUN OK product.template:$id <= $($item.file)  ($($item.title))"
      $updated++
    } else {
      Write-Warning "DRYRUN NO EXISTE product.template:$id ($($item.title))"
      $missing++
    }
    continue
  }

  $values = @{}
  foreach ($fld in $DescriptionField) { $values[$fld] = [string]$item.iframe }

  # Construir args = [[id], values] con listas para evitar el aplanamiento de @()
  $idList = New-Object System.Collections.Generic.List[object]
  $idList.Add([int]$id)
  $writeArgs = New-Object System.Collections.Generic.List[object]
  $writeArgs.Add($idList)   # elemento 0 = [id]
  $writeArgs.Add($values)   # elemento 1 = { campo: iframe }
  $params = New-Object System.Collections.Generic.List[object]
  foreach ($x in @($Database, $uid, $ApiKey, 'product.template', 'write')) { $params.Add($x) }
  $params.Add($writeArgs)
  $params.Add(@{})

  try {
    Invoke-XmlRpc $object 'execute_kw' $params | Out-Null
    Write-Output "UPDATED product.template:$id <= $($item.file)  ($($item.title))"
    $updated++
  } catch {
    Write-Warning "FALLO product.template:$id ($($item.title)) -> $($_.Exception.Message.Split([Environment]::NewLine)[0])"
    $missing++
  }
}

Write-Output ""
Write-Output ("== Resumen ==  actualizados/ok: {0} | omitidos: {1} | faltantes: {2}" -f $updated, $skipped, $missing)
if ($DryRun) { Write-Output "(DryRun: no se escribio nada en Odoo)" }
