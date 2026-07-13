param(
  [Parameter(Mandatory = $true)][string]$OdooUrl,
  [Parameter(Mandatory = $true)][string]$Database,
  [Parameter(Mandatory = $true)][string]$User,
  [Parameter(Mandatory = $true)][string]$ApiKey,
  [string]$ManifestGlob = '*_manifest.json',
  [string]$DescriptionField = 'website_description',
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
  $items += $manifest.items
}

foreach ($item in $items) {
  if (-not $item.iframe -or -not $item.title) { continue }
  $domain = @(@('name', '=', [string]$item.title))
  $ids = Invoke-XmlRpc $object 'execute_kw' @($Database, $uid, $ApiKey, 'product.template', 'search', @($domain), @{ limit = 1 })
  if (-not $ids -or $ids.Count -eq 0) {
    Write-Warning "No encontrado en Odoo: $($item.title)"
    continue
  }

  if ($DryRun) {
    Write-Output "DRYRUN product.template:$($ids[0]) <= $($item.file)"
    continue
  }

  $values = @{ $DescriptionField = [string]$item.iframe }
  Invoke-XmlRpc $object 'execute_kw' @($Database, $uid, $ApiKey, 'product.template', 'write', @(,@($ids[0]), $values), @{}) | Out-Null
  Write-Output "UPDATED product.template:$($ids[0]) <= $($item.file)"
}
