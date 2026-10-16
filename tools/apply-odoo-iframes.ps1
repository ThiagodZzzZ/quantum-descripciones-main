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
  [int]$DelayMs = 80,
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
  $attempt = 0
  while ($true) {
    $attempt++
    try {
      # UTF-8 explicito: el bloque nuevo trae tildes y PowerShell 5.1 no manda el string como UTF-8
      $response = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $endpoint -ContentType 'text/xml; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 90
      $xml = [xml]$response.Content
      $fault = $xml.methodResponse.fault
      if ($fault) { throw "Odoo XML-RPC fault: $($response.Content)" }
      $value = $xml.methodResponse.params.param.value
      return (ConvertFrom-XmlRpcValue $value)
    } catch {
      if ($attempt -ge 6) { throw }
      Start-Sleep -Seconds ([Math]::Min(30, 3 * $attempt))
    }
  }
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
$authParams = New-Object System.Collections.Generic.List[object]
foreach ($x in @($Database, $User, $ApiKey, @{})) { $authParams.Add($x) }
$uid = Invoke-XmlRpc $common 'authenticate' $authParams
if (-not $uid) { throw 'No se pudo autenticar contra Odoo.' }

$items = @()
Get-ChildItem -LiteralPath . -Filter $ManifestGlob | ForEach-Object {
  $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName | ConvertFrom-Json
  if ($manifest -is [System.Array]) { $items += $manifest }      # array plano [ ... ]
  elseif ($manifest.items) { $items += $manifest.items }         # objeto { items: [...] }
  else { $items += @($manifest) }
}

$idFilter = $null
if ($OnlyIds) { $idFilter = @($OnlyIds -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ }) }

$updated = 0; $skipped = 0; $missing = 0
foreach ($item in $items) {
  if ($OnlyMatched -and -not $item.Matched) { $skipped++; continue }
  # Bloque nuevo (16/10): si el item trae "html" (manifest generado por el generador de Quantum, _descripcion_pdp.py) se escribe
  # ese HTML; si no, el iframe de siempre.
  $nuevo = if ($item.html) { [string]$item.html } elseif ($item.iframe) { [string]$item.iframe } else { $null }
  if (-not $nuevo) { $skipped++; continue }
  $tipo = if ($item.html) { 'bloque nuevo' } else { 'iframe' }

  # Preferir OdooId (unico y sin ambiguedad). Fallback a busqueda por titulo.
  $id = $null
  if ($item.OdooId) {
    $id = [int]$item.OdooId
  } elseif ($item.title) {
    $domainInner = New-Object System.Collections.Generic.List[object]
    $domainInner.Add(@('name', '=', [string]$item.title))
    $searchArgs = New-Object System.Collections.Generic.List[object]
    $searchArgs.Add($domainInner)
    $rpcParams = New-Object System.Collections.Generic.List[object]
    foreach ($x in @($Database, $uid, $ApiKey, 'product.template', 'search')) { $rpcParams.Add($x) }
    $rpcParams.Add($searchArgs)
    $rpcParams.Add(@{ limit = 1 })
    $ids = Invoke-XmlRpc $object 'execute_kw' $rpcParams
    if ($ids -and @($ids).Count -gt 0) { $id = [int]@($ids)[0] }
  }
  if (-not $id) {
    Write-Warning "Sin OdooId ni match por titulo: $($item.title)"
    $missing++; continue
  }

  if ($idFilter -and ($id -notin $idFilter)) { $skipped++; continue }
  if ($Limit -gt 0 -and $updated -ge $Limit) { $skipped++; continue }

  # Leer lo que hay hoy en Odoo (tambien verifica que el ID exista). Sin splat: PS aplana @() y rompe kwargs.
  $idList = New-Object System.Collections.Generic.List[object]
  $idList.Add([int]$id)
  $readArgs = New-Object System.Collections.Generic.List[object]
  $readArgs.Add($idList)
  $rpcParams = New-Object System.Collections.Generic.List[object]
  foreach ($x in @($Database, $uid, $ApiKey, 'product.template', 'read')) { $rpcParams.Add($x) }
  $rpcParams.Add($readArgs)
  $rpcParams.Add(@{ fields = @($DescriptionField[0]) })
  $leido = @(Invoke-XmlRpc $object 'execute_kw' $rpcParams)
  if (-not $leido -or $leido.Count -eq 0 -or -not ($leido[0] -is [hashtable])) {
    Write-Warning "NO EXISTE product.template:$id ($($item.title))"
    $missing++; continue
  }
  $actual = $leido[0][$DescriptionField[0]]
  if ($actual -isnot [string]) { $actual = '' }   # Odoo devuelve False si esta vacio

  # GUARDA (16/10): la descripcion nueva de Quantum (bloque con data-qd-version) nunca se pisa con el iframe.
  if ($actual -match 'data-qd-version' -and -not $item.html) {
    Write-Output "OMITIDO product.template:$id ya tiene la descripcion nueva; no se vuelve al iframe  ($($item.title))"
    $skipped++; continue
  }
  if ($actual -eq $nuevo) {
    Write-Output "OMITIDO product.template:$id ya tiene exactamente esto  ($($item.title))"
    $skipped++; continue
  }

  if ($DryRun) {
    $hoy = if ($actual -match 'data-qd-version') { 'bloque nuevo' } elseif ($actual -match '<iframe') { 'iframe' } elseif ($actual) { 'otro HTML' } else { 'vacio' }
    Write-Output "DRYRUN escribiria product.template:$id  hoy: $hoy -> $tipo  <= $($item.file)  ($($item.title))"
    $updated++
    continue
  }

  $values = @{}
  foreach ($fld in $DescriptionField) { $values[$fld] = $nuevo }

  # Construir args = [[id], values] con listas para evitar el aplanamiento de @()
  $writeArgs = New-Object System.Collections.Generic.List[object]
  $writeArgs.Add($idList)   # elemento 0 = [id]
  $writeArgs.Add($values)   # elemento 1 = { campo: iframe }
  $params = New-Object System.Collections.Generic.List[object]
  foreach ($x in @($Database, $uid, $ApiKey, 'product.template', 'write')) { $params.Add($x) }
  $params.Add($writeArgs)
  $params.Add(@{})

  try {
    Invoke-XmlRpc $object 'execute_kw' $params | Out-Null
    Write-Output "UPDATED product.template:$id ($tipo) <= $($item.file)  ($($item.title))"
    $updated++
  } catch {
    Write-Warning "FALLO product.template:$id ($($item.title)) -> $($_.Exception.Message.Split([Environment]::NewLine)[0])"
    $missing++
  }
  if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
}

Write-Output ""
Write-Output ("== Resumen ==  actualizados/ok: {0} | omitidos: {1} | faltantes: {2}" -f $updated, $skipped, $missing)
if ($DryRun) { Write-Output "(DryRun: no se escribio nada en Odoo)" }
