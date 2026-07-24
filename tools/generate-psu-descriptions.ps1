#Requires -Version 5.1
# Genera descripciones de FUENTES (PSU) a partir del catalogo Odoo.
# Specs derivadas SOLO del titulo oficial (potencia, eficiencia 80 PLUS, modularidad, formato, ATX/PCIe5).
# No inventa numeros: lo no derivable se marca "Segun ficha oficial del modelo".
param(
  [string]$OdooJson = 'C:\Users\PC\Quantum-Imagenes-Productos\inventario\odoo-psu.json',
  [string]$OutDir   = 'C:\Users\PC\Quantum-Descripciones-Nuevas-MAIN\FUENTES',
  [string]$ManifestPath = 'C:\Users\PC\Quantum-Descripciones-Nuevas-MAIN\psu_full_manifest.json',
  [string]$ThemeVersion = '20260723quantum',
  [string]$ThemeBase = 'https://thiagodzzzz.github.io/quantum-descripciones-main'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
function HE([string]$s){ [System.Web.HttpUtility]::HtmlEncode($s) }

$BRANDS = 'AEROCOOL','AZZA','ARKTEK','ADATA','XPG','ASUS','AUREOX','CORSAIR','COOLER MASTER','COOLERMASTER','EVGA','EVOLABS','FORMULA','GIGABYTE','MSI','NOGANET','NOGA','RAIDMAX','SEASONIC','THERMALTAKE','TEROS','CROMAX','ANTEC','NZXT','BE QUIET','DEEPCOOL','GAMEMAX','SENTEY','REDRAGON','HALION','PCYES','SATE','KOLINK'

function Get-Brand([string]$t){
  foreach($b in $BRANDS){ if($t -match ('(?i)\b'+[regex]::Escape($b)+'\b')){ return $b.ToUpper() } }
  return 'QUANTUM HARDSTORE'
}
function Test-Outlet([string]$t){ $t -match '(?i)OUTLET|OPENBOX|USADO|OPEN BOX' }
function Is-NotPsu([string]$t){
  if($t -match '(?i)^\s*cable\b'){ return $true }            # "Cable Fuente 24 pines"
  if($t -match '(?i)\b(base de carga|base de cargue|zebra|cradle|dock|soporte)\b'){ return $true }
  if($t -match '(?i)\bKIT\b.*\+' -and $t -notmatch '(?i)\bW\b|\d{3,4}\s*W'){ return $true }  # kits que no son fuente
  if($t -match '(?i)switching' -or $t -match '(?i)\b\d{1,2}\s*V\s*\d{1,3}\s*A\b'){ return $true } # fuentes DC industriales (5V 15A)
  return $false
}

function Get-Watt([string]$t){
  $m=[regex]::Match($t,'(?i)(\d{3,4})\s*(?:WATT|WATTS)\b'); if($m.Success){ return [int]$m.Groups[1].Value }
  $m=[regex]::Match($t,'(?i)(\d{3,4})\s*W(?![A-Z0-9]{3,})'); if($m.Success){ return [int]$m.Groups[1].Value }
  # fallback: numeros que parezcan potencia (multiplos de 50 entre 250 y 2000) en codigos de modelo
  $cands=@()
  foreach($mm in [regex]::Matches($t,'\d{3,4}')){ $v=[int]$mm.Value; if($v -ge 250 -and $v -le 2000 -and ($v % 50 -eq 0)){ $cands+=$v } }
  if($cands.Count){ return ($cands | Sort-Object -Descending)[0] }
  return 0
}
function Get-Efficiency([string]$t){
  if($t -match '(?i)TITANIUM'){ return '80 PLUS Titanium' }
  if($t -match '(?i)PLATINUM'){ return '80 PLUS Platinum' }
  if($t -match '(?i)\bGOLD\b'){ return '80 PLUS Gold' }
  if($t -match '(?i)\bSILVER\b'){ return '80 PLUS Silver' }
  if($t -match '(?i)\bBRONZE\b'){ return '80 PLUS Bronze' }
  if($t -match '(?i)\bWHITE\b|80\s*PLUS\s*STANDARD|\b230V\b'){ return '80 PLUS White' }
  if($t -match '(?i)80\s*\+|80\s*PLUS|80\+PSU'){ return '80 PLUS' }
  return ''
}
function Get-Modular([string]$t){
  if($t -match '(?i)FULL\s*MODULAR|FULLY\s*MODULAR|\bFM\b'){ return 'Full modular' }
  if($t -match '(?i)SEMI\s*MODULAR'){ return 'Semi modular' }
  if($t -match '(?i)NO\s*MODULAR|\bNM\b'){ return 'Cableado fijo' }
  if($t -match '(?i)\bMODULAR\b'){ return 'Modular' }
  return ''
}
function Get-Form([string]$t){
  if($t -match '(?i)SFX-?L'){ return 'SFX-L' }
  if($t -match '(?i)\bSFX\b'){ return 'SFX' }
  if($t -match '(?i)\bTFX\b'){ return 'TFX' }
  return 'ATX'
}
function Get-AtxVer([string]$t){
  $m=[regex]::Match($t,'(?i)ATX\s*3\.(\d)'); if($m.Success){ return 'ATX 3.'+$m.Groups[1].Value }
  if($t -match '(?i)ATX\s*3\b'){ return 'ATX 3.0' }
  return ''
}
function Has-Pcie5([string]$t){ return [bool]($t -match '(?i)PCIE?\s*5|PCI-?E\s*5|12VHPWR|12V-?2X6|ATX\s*3') }

$template = @'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{TITLE}} - Quantum Hardstore</title>
  <link rel="stylesheet" href="../quantum-products-theme.css">
  <script src="{{THEME_BASE}}/quantum-theme-switch.js?v={{THEME_VERSION}}" defer></script>
</head>
<body>
<div class="container">
  <header class="qh-header"><div class="brand">Quantum Hardstore</div><div class="maker">{{MAKER}}</div><h1>{{H1}}</h1><div class="subtitle">{{SUBTITLE}}</div></header>
  <div class="badge-row" aria-label="Caracteristicas principales">
    {{BADGES}}
  </div>
  <section class="hero-metric"><div class="metric-box"><div class="metric-label">Potencia declarada</div><div class="metric-value">{{WATT}}</div><div class="metric-desc">{{HERO_DESC}}</div></div></section>
  <section class="section"><h2 class="section-title">Especificaciones clave</h2><p class="section-sub">Datos tomados de la denominacion oficial del modelo. Los valores no incluidos en la ficha se indican como referencia a la hoja tecnica del fabricante.</p><div class="spec-grid">
      <article class="spec-card"><div class="spec-name">Potencia</div><div class="spec-value">{{WATT}}</div><div class="spec-note">Salida nominal declarada.</div></article>
      <article class="spec-card"><div class="spec-name">Eficiencia</div><div class="spec-value">{{EFF}}</div><div class="spec-note">Certificacion de eficiencia energetica.</div></article>
      <article class="spec-card"><div class="spec-name">Cableado</div><div class="spec-value">{{MODULAR}}</div><div class="spec-note">Tipo de gestion de cables.</div></article>
      <article class="spec-card"><div class="spec-name">Formato</div><div class="spec-value">{{FORM}}</div><div class="spec-note">Factor de forma fisico.</div></article>
      <article class="spec-card"><div class="spec-name">Estandar</div><div class="spec-value">{{ATX}}</div><div class="spec-note">Guia de compatibilidad ATX.</div></article>
      <article class="spec-card"><div class="spec-name">Conector PCIe GPU</div><div class="spec-value">{{PCIE}}</div><div class="spec-note">Alimentacion de placa de video.</div></article>
    </div></section>
  <section class="section dark"><h2 class="section-title">Compatibilidad y armado</h2><p class="section-sub">Recomendaciones para elegir e instalar la fuente correctamente.</p><div class="conn-grid">
      <article class="conn-card"><div class="conn-count">{{WATT}}</div><div class="conn-name">Presupuesto de potencia</div><div class="conn-desc">Verificar el consumo de CPU + GPU + perifericos y dejar margen.</div></article>
      <article class="conn-card"><div class="conn-count">{{FORM}}</div><div class="conn-name">Gabinete</div><div class="conn-desc">Confirmar espacio y compatibilidad del factor de forma.</div></article>
      <article class="conn-card"><div class="conn-count">{{EFFSHORT}}</div><div class="conn-name">Eficiencia</div><div class="conn-desc">Mejor eficiencia = menos calor y consumo a igual carga.</div></article>
    </div></section>
  {{STATUS_BOX}}
  <div class="note">{{NOTE}}</div>
</div>
</body>
</html>
'@

$odoo = Get-Content $OdooJson -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$manifest=@(); $gen=0; $skip=@(); $noWatt=@()
foreach($p in @($odoo.products)){
  $title=[string]$p.title; $id=[int]$p.id
  if(Is-NotPsu $title){ $skip += "$id | $title"; continue }
  $watt=Get-Watt $title
  if($watt -le 0){ $noWatt += "$id | $title"; continue }

  $outlet=Test-Outlet $title
  $brand=Get-Brand $title
  $eff=Get-Efficiency $title
  $mod=Get-Modular $title
  $form=Get-Form $title
  $atx=Get-AtxVer $title
  $pcie5=Has-Pcie5 $title
  $cond= if($outlet){'Outlet'}else{'Nuevo'}

  $wattStr="$watt W"
  $effShow= if($eff){$eff}else{'Segun ficha del modelo'}
  $modShow= if($mod){$mod}else{'Segun ficha del modelo'}
  $atxShow= if($atx){$atx}else{'ATX estandar'}
  $pcieShow= if($pcie5){'PCIe 5.x / 12VHPWR (ATX 3)'}elseif($form -eq 'ATX'){'PCIe 6+2 (segun modelo)'}else{'Segun ficha del modelo'}
  $effShort= if($eff){ ($eff -replace '80 PLUS ','') } else {'-'}

  $badges=@("$wattStr")
  if($eff){$badges+=$eff}
  if($mod){$badges+=$mod}
  $badges+=$form
  if($atx){$badges+=$atx}
  if($pcie5 -and -not $atx){$badges+='PCIe 5.x'}
  $badges+=$cond
  $badgeHtml=($badges | ForEach-Object { "<span class=`"badge`">$(HE $_)</span>" }) -join "`n    "

  $heroDesc="Fuente $brand de $wattStr" + $(if($eff){" con $eff"}else{''}) + ". Compatibilidad segun potencia, conectores y formato del equipo."
  $titleClean=($title -replace '(?i)\s*\((OUTLET|OPENBOX|NUEVA|NUEVO)\)\s*',' ').Trim()
  $subtitleParts=@()
  if($eff){$subtitleParts+=$eff}
  if($mod){$subtitleParts+=$mod}
  $subtitleParts+=$form
  if($outlet){$subtitleParts+='OUTLET'}
  $subtitle=($subtitleParts -join ' / ')

  if($outlet){
    # El aviso de deposito lo inyecta quantum-theme-switch.js solo en NO-OUTLET; aca ponemos el box de outlet.
    $statusBox='<div class="status-box"><div class="status-title">Producto outlet</div><div class="status-text">Unidad outlet revisada por Quantum Hardstore. Estado y stock sujetos a confirmacion. Consultar disponibilidad antes de abonar.</div></div>'
  } else {
    # No repetir el aviso de deposito: ya lo agrega el theme-switch global arriba de la ficha.
    $statusBox=''
  }
  $note="* Specs derivadas de la denominacion oficial del modelo $brand. Conectores, dimensiones exactas y ventilacion segun hoja tecnica del fabricante. La compatibilidad final depende del gabinete, motherboard y consumo real de CPU/GPU."
  $maker="$brand Fuentes"

  $file="psu-$('{0:D5}' -f $id).html"
  $html=$template
  $repl=@{
    '{{TITLE}}'=(HE $title);'{{MAKER}}'=(HE $maker);'{{H1}}'=(HE $titleClean);'{{SUBTITLE}}'=(HE $subtitle)
    '{{BADGES}}'=$badgeHtml;'{{WATT}}'=(HE $wattStr);'{{HERO_DESC}}'=(HE $heroDesc)
    '{{EFF}}'=(HE $effShow);'{{MODULAR}}'=(HE $modShow);'{{FORM}}'=(HE $form);'{{ATX}}'=(HE $atxShow)
    '{{PCIE}}'=(HE $pcieShow);'{{EFFSHORT}}'=(HE $effShort)
    '{{STATUS_BOX}}'=$statusBox;'{{NOTE}}'=(HE $note)
    '{{THEME_BASE}}'=$ThemeBase;'{{THEME_VERSION}}'=$ThemeVersion
  }
  foreach($k in $repl.Keys){ $html=$html.Replace($k,[string]$repl[$k]) }
  Set-Content -LiteralPath (Join-Path $OutDir $file) -Value $html -Encoding UTF8

  $iframe="<iframe src=`"$ThemeBase/FUENTES/${file}?v=$ThemeVersion`" style=`"width:100%;height:2200px;border:0;`" loading=`"lazy`"></iframe>"
  $manifest += [pscustomobject]@{
    OdooId=$id; Title=$title; Sku=[string]$p.internalReference; File=$file
    Watt=$watt; Efficiency=$eff; Modular=$mod; Form=$form; Outlet=$outlet
    Matched=$true; iframe=$iframe
  }
  $gen++
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$skip  | Set-Content -LiteralPath (Join-Path (Split-Path $ManifestPath -Parent) 'psu_no_fuente.txt') -Encoding UTF8
$noWatt| Set-Content -LiteralPath (Join-Path (Split-Path $ManifestPath -Parent) 'psu_sin_watt.txt') -Encoding UTF8
Write-Host ("Generadas: {0} | No-PSU salteadas: {1} | Sin potencia: {2}" -f $gen, @($skip).Count, @($noWatt).Count)
Write-Host ("Manifest: {0}" -f $ManifestPath)
