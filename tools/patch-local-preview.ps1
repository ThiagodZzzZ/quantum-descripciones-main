#Requires -Version 5.1
# Parchea HTML de GPUS para preview local (theme switch desde localhost)
param(
  [string]$GpuDir = 'C:\Users\PC\Quantum-Descripciones-Nuevas-MAIN\GPUS',
  [switch]$Revert
)

$ErrorActionPreference = 'Stop'
$remote = 'https://thiagodzzzz.github.io/quantum-descripciones-main/quantum-theme-switch.js'
$local = '/quantum-theme-switch.js'

Get-ChildItem $GpuDir -Filter '*.html' -File | ForEach-Object {
  $text = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
  if ($Revert) {
    $text = $text -replace [regex]::Escape('<script src="/quantum-theme-switch.js'), "<script src=`"$remote"
  } else {
    $text = $text -replace "https://thiagodzzzz.github.io/quantum-descripciones-main/quantum-theme-switch.js", $local
  }
  Set-Content -LiteralPath $_.FullName -Value $text -Encoding UTF8 -NoNewline
}

Write-Host $(if ($Revert) { 'Revertido a GitHub Pages' } else { 'Parcheado para preview local' })
