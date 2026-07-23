#Requires -Version 5.1
param(
  [string]$Root = 'C:\Users\PC\Quantum-Descripciones-Nuevas-MAIN',
  [int]$Port = 8796,
  [switch]$OpenSamples,
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'

function Get-ContentType([string]$Path) {
  switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    '.html' { 'text/html; charset=utf-8' }
    '.js'   { 'text/javascript; charset=utf-8' }
    '.css'  { 'text/css; charset=utf-8' }
    '.json' { 'application/json; charset=utf-8' }
    '.png'  { 'image/png' }
    '.jpg'  { 'image/jpeg' }
    '.jpeg' { 'image/jpeg' }
    '.webp' { 'image/webp' }
    default { 'application/octet-stream' }
  }
}

function Resolve-SafePath([string]$RequestPath) {
  $clean = [Uri]::UnescapeDataString(($RequestPath -split '\?')[0]).TrimStart('/')
  if ([string]::IsNullOrWhiteSpace($clean)) { $clean = 'index.html' }
  $full = [IO.Path]::GetFullPath((Join-Path $Root $clean))
  $rootFull = [IO.Path]::GetFullPath($Root)
  if (-not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Ruta fuera del directorio permitido.'
  }
  return $full
}

$rootFull = [IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath $rootFull)) { throw "No existe: $rootFull" }

# Index simple si no existe
$indexPath = Join-Path $rootFull 'index.html'
if (-not (Test-Path -LiteralPath $indexPath)) {
  $gpuDir = Join-Path $rootFull 'GPUS'
  $links = @()
  if (Test-Path -LiteralPath $gpuDir) {
    Get-ChildItem $gpuDir -Filter 'gpu-4131.html','gpu-9565.html','gpu-*.html' -File | Select-Object -First 20 | ForEach-Object {
      $links += "<li><a href=`"/GPUS/$($_.Name)`">$($_.Name)</a></li>"
    }
  }
  @"
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Quantum Descripciones Local</title>
<style>body{font-family:Arial,sans-serif;max-width:860px;margin:24px auto;padding:0 16px} a{color:#B80063}</style></head>
<body><h1>Preview local descripciones</h1><p>Servidor PowerShell en puerto $Port</p><ul>$($links -join '')</ul></body></html>
"@ | Set-Content -LiteralPath $indexPath -Encoding UTF8
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://127.0.0.1:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host ''
Write-Host '=== Quantum Descripciones — Preview Local (PowerShell) ===' -ForegroundColor Cyan
Write-Host "Raiz:  $rootFull"
Write-Host "URL:   $prefix"
Write-Host ''
Write-Host 'Muestras directas:' -ForegroundColor Yellow
Write-Host "  $prefix GPUS/gpu-4131.html  (NUEVA + aviso deposito)"
Write-Host "  $prefix GPUS/gpu-9565.html  (OUTLET)"
Write-Host ''
Write-Host 'Ctrl+C para detener' -ForegroundColor DarkGray
Write-Host ''

if ($OpenSamples -and -not $NoBrowser) {
  Start-Process 'http://127.0.0.1:{0}/GPUS/gpu-4131.html' -f $Port
  Start-Sleep -Milliseconds 700
  Start-Process 'http://127.0.0.1:{0}/GPUS/gpu-9565.html' -f $Port
}

while ($listener.IsListening) {
  $context = $listener.GetContext()
  $request = $context.Request
  $response = $context.Response
  try {
    $target = Resolve-SafePath $request.Url.LocalPath
    if (-not (Test-Path -LiteralPath $target) -or (Get-Item -LiteralPath $target).PSIsContainer) {
      throw 'No encontrado'
    }
    $bytes = [IO.File]::ReadAllBytes($target)
    $response.StatusCode = 200
    $response.ContentType = Get-ContentType $target
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
  } catch {
    $msg = [Text.Encoding]::UTF8.GetBytes($_.Exception.Message)
    $response.StatusCode = 404
    $response.ContentType = 'text/plain; charset=utf-8'
    $response.ContentLength64 = $msg.Length
    $response.OutputStream.Write($msg, 0, $msg.Length)
  } finally {
    $response.OutputStream.Close()
  }
}
