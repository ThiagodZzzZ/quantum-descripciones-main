param(
  [Parameter(Mandatory = $true)]
  [string[]]$ManifestPath,
  [Parameter(Mandatory = $true)]
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$items = New-Object System.Collections.Generic.List[object]
$ids = New-Object 'System.Collections.Generic.HashSet[int]'

foreach ($path in $ManifestPath) {
  $entries = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
  foreach ($entry in $entries) {
    $id = [int]$entry.OdooId
    if (-not $ids.Add($id)) { throw "OdooId duplicado: $id" }
    $iframe = [string]$entry.iframe
    if ([string]::IsNullOrWhiteSpace($iframe)) { throw "Iframe faltante para OdooId $id" }
    [void]$items.Add([pscustomobject]@{
      OdooId = $id
      Title = [string]$entry.Title
      Sku = [string]$entry.Sku
      File = [string]$entry.File
      iframe = $iframe
      Matched = $true
    })
  }
}

$json = $items | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($OutputPath, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Host ("Combined: {0}" -f $items.Count)
