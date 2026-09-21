function ConvertTo-XmlRpcValue($doc, $value) {
  $valueNode = $doc.CreateElement('value')
  if ($null -eq $value) { $valueNode.AppendChild($doc.CreateElement('nil')) | Out-Null }
  elseif ($value -is [int]) { $n=$doc.CreateElement('int'); $n.InnerText=[string]$value; $valueNode.AppendChild($n)|Out-Null }
  elseif ($value -is [bool]) { $n=$doc.CreateElement('boolean'); $n.InnerText=$(if($value){'1'}else{'0'}); $valueNode.AppendChild($n)|Out-Null }
  elseif ($value -is [hashtable]) {
    $struct=$doc.CreateElement('struct')
    foreach($k in $value.Keys){ $m=$doc.CreateElement('member'); $nm=$doc.CreateElement('name'); $nm.InnerText=[string]$k; $m.AppendChild($nm)|Out-Null; $m.AppendChild((ConvertTo-XmlRpcValue $doc $value[$k]))|Out-Null; $struct.AppendChild($m)|Out-Null }
    $valueNode.AppendChild($struct)|Out-Null
  }
  elseif ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
    $array=$doc.CreateElement('array'); $data=$doc.CreateElement('data')
    foreach($item in $value){ $data.AppendChild((ConvertTo-XmlRpcValue $doc $item))|Out-Null }
    $array.AppendChild($data)|Out-Null; $valueNode.AppendChild($array)|Out-Null
  }
  else { $n=$doc.CreateElement('string'); $n.InnerText=[string]$value; $valueNode.AppendChild($n)|Out-Null }
  $valueNode
}

function New-XmlRpcCall($methodName, $params) {
  $doc=New-Object System.Xml.XmlDocument
  $mc=$doc.CreateElement('methodCall'); $doc.AppendChild($mc)|Out-Null
  $mn=$doc.CreateElement('methodName'); $mn.InnerText=$methodName; $mc.AppendChild($mn)|Out-Null
  $ps=$doc.CreateElement('params'); $mc.AppendChild($ps)|Out-Null
  foreach($pv in $params){ $p=$doc.CreateElement('param'); $p.AppendChild((ConvertTo-XmlRpcValue $doc $pv))|Out-Null; $ps.AppendChild($p)|Out-Null }
  $doc.OuterXml
}

function ConvertFrom-XmlRpcValue($v) {
  if ($v.array) { return @($v.array.data.value | ForEach-Object { ConvertFrom-XmlRpcValue $_ }) }
  if ($v.struct) { $h=@{}; foreach($m in $v.struct.member){ $h[$m.name]=ConvertFrom-XmlRpcValue $m.value }; return $h }
  if ($v.int) { return [int]$v.int }
  if ($v.i4) { return [int]$v.i4 }
  if ($v.boolean) { return ([string]$v.boolean -eq '1') }
  if ($v.string) { return [string]$v.string }
  return [string]$v.InnerText
}

function Invoke-XmlRpc($endpoint, $methodName, $params) {
  $body = New-XmlRpcCall $methodName $params
  $attempt = 0
  while ($true) {
    $attempt++
    try {
      $resp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $endpoint -ContentType 'text/xml' -Body $body -TimeoutSec 120
      $xml = [xml]$resp.Content
      if ($xml.methodResponse.fault) { throw "Odoo fault: $($resp.Content)" }
      return (ConvertFrom-XmlRpcValue $xml.methodResponse.params.param.value)
    } catch {
      if ($attempt -ge 6) { throw }
      Start-Sleep -Seconds ([Math]::Min(30, 3 * $attempt))
    }
  }
}
