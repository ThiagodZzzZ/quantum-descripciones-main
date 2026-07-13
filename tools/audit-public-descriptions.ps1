param(
  [string]$ProductsUrl = 'https://quantumhardstore.com/productos/',
  [string]$SitemapUrl = 'https://quantumhardstore.com/sitemap.xml',
  [switch]$UseCatalogPages,
  [int]$Pages = 47,
  [string]$GithubNeedle = 'thiagodzzzz.github.io/quantum-descripciones-main/',
  [int]$DelayMs = 900,
  [int]$Retries = 2,
  [string]$OutDir = '.\audits'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$links = [System.Collections.Generic.HashSet[string]]::new()

if (-not $UseCatalogPages) {
  $sitemap = (Invoke-WebRequest -UseBasicParsing -Uri $SitemapUrl -TimeoutSec 45).Content
  [regex]::Matches($sitemap, '<loc>(https://quantumhardstore\.com/productos/[^<]+)</loc>', 'IgnoreCase') | ForEach-Object {
    [void]$links.Add($_.Groups[1].Value)
  }
} else {
  for ($page = 1; $page -le $Pages; $page++) {
    $url = if ($page -eq 1) { $ProductsUrl } else { "${ProductsUrl}?page=$page" }
    $html = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 45).Content
    [regex]::Matches($html, 'https://quantumhardstore\.com/productos/[^"''\s<>#?]+/?') | ForEach-Object {
      [void]$links.Add($_.Value)
    }
    [regex]::Matches($html, 'href=["''](/productos/[^"''#?]+/?)["'']') | ForEach-Object {
      [void]$links.Add('https://quantumhardstore.com' + $_.Groups[1].Value)
    }
    Start-Sleep -Milliseconds $DelayMs
  }
}

$allLinks = $links | Sort-Object
$allLinks | Set-Content -LiteralPath (Join-Path $OutDir 'product_links.txt') -Encoding UTF8

$results = foreach ($url in $allLinks) {
  $attempt = 0
  $done = $false
  while (-not $done -and $attempt -le $Retries) {
    $attempt++
    try {
      $html = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 45).Content
      $title = ''
      $titleMatch = [regex]::Match($html, '<meta property="og:title" content="([^"]*)"', 'IgnoreCase')
      if ($titleMatch.Success) { $title = [System.Web.HttpUtility]::HtmlDecode($titleMatch.Groups[1].Value) }
      $hasIframe = $html.Contains($GithubNeedle)
      $iframe = ''
      $iframeMatch = [regex]::Match($html, '<iframe[^>]+thiagodzzzz\.github\.io/quantum-descripciones-main/[^>]+>', 'IgnoreCase')
      if ($iframeMatch.Success) { $iframe = $iframeMatch.Value }
      [pscustomobject]@{
        url = $url
        title = $title
        has_github_iframe = $hasIframe
        iframe = $iframe
        status = 'ok'
        error = ''
      }
      $done = $true
    } catch {
      if ($attempt -gt $Retries) {
        [pscustomobject]@{
          url = $url
          title = ''
          has_github_iframe = $false
          iframe = ''
          status = 'error'
          error = $_.Exception.Message
        }
        $done = $true
      } else {
        Start-Sleep -Milliseconds ([Math]::Max($DelayMs * 3, 2500))
      }
    }
  }
  Start-Sleep -Milliseconds $DelayMs
}

$auditPath = Join-Path $OutDir 'description_audit.csv'
$missingPath = Join-Path $OutDir 'missing_github_iframe.csv'
$results | Export-Csv -LiteralPath $auditPath -NoTypeInformation -Encoding UTF8
$results | Where-Object { $_.status -eq 'ok' -and -not $_.has_github_iframe } |
  Export-Csv -LiteralPath $missingPath -NoTypeInformation -Encoding UTF8

$withIframe = ($results | Where-Object { $_.has_github_iframe }).Count
$missing = ($results | Where-Object { $_.status -eq 'ok' -and -not $_.has_github_iframe }).Count
$errors = ($results | Where-Object { $_.status -ne 'ok' }).Count
Write-Output "TOTAL=$($results.Count) WITH_IFRAME=$withIframe MISSING=$missing ERRORS=$errors"
