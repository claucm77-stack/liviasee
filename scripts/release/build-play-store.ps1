[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$BuildName,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2100000000)]
    [int]$BuildNumber,

    [ValidatePattern('^https://')]
    [string]$LaravelBaseUrl = 'https://liviase.sanmartin.edu.co',

    [string]$GoogleMapsApiKey = $env:GOOGLE_MAPS_API_KEY,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$keyPropertiesPath = Join-Path $projectRoot 'android\key.properties'
$outputDirectory = Join-Path $projectRoot 'dist\play-store'
$artifactName = "liviase-$BuildName-$BuildNumber.aab"
$artifactPath = Join-Path $outputDirectory $artifactName

if ([string]::IsNullOrWhiteSpace($GoogleMapsApiKey) -or $GoogleMapsApiKey -like 'REEMPLAZAR*') {
    throw 'Defina GOOGLE_MAPS_API_KEY con una clave restringida de producción antes de generar el AAB.'
}
if (-not (Test-Path -LiteralPath $keyPropertiesPath)) {
    throw 'Falta android/key.properties; no se puede firmar el AAB de actualización.'
}
$keyProperties = @{}
foreach ($line in Get-Content -LiteralPath $keyPropertiesPath) {
    if ($line -match '^\s*([^#=]+)=(.*)$') {
        $keyProperties[$matches[1].Trim()] = $matches[2].Trim()
    }
}
foreach ($required in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) {
    if (-not $keyProperties.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($keyProperties[$required])) {
        throw "Falta $required en android/key.properties."
    }
}

$keystorePath = Join-Path (Join-Path $projectRoot 'android\app') $keyProperties['storeFile']
if (-not (Test-Path -LiteralPath $keystorePath)) {
    throw "No existe el almacén de firma: $keystorePath"
}

Push-Location $projectRoot
$previousMapsKey = $env:GOOGLE_MAPS_API_KEY
try {
    $env:GOOGLE_MAPS_API_KEY = $GoogleMapsApiKey
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falló flutter pub get.' }

    if (-not $SkipTests) {
        flutter test
        if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas Flutter.' }
        dart analyze lib test
        if ($LASTEXITCODE -ne 0) { throw 'Falló el análisis estático.' }
    }

    flutter build appbundle --release `
        --build-name=$BuildName `
        --build-number=$BuildNumber `
        --dart-define=LARAVEL_BASE_URL=$LaravelBaseUrl `
        --dart-define=GOOGLE_MAPS_API_KEY=$GoogleMapsApiKey
    if ($LASTEXITCODE -ne 0) { throw 'Falló la generación del Android App Bundle.' }

    $generatedBundle = Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab'
    if (-not (Test-Path -LiteralPath $generatedBundle)) {
        throw 'Flutter terminó sin producir app-release.aab.'
    }

    New-Item -ItemType Directory -Force $outputDirectory | Out-Null
    Copy-Item -LiteralPath $generatedBundle -Destination $artifactPath -Force
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash
    Set-Content -LiteralPath "$artifactPath.sha256" -Value "$hash  $artifactName" -Encoding ascii

    Write-Output "AAB Play Store: $artifactPath"
    Write-Output "Paquete: co.edu.sanmartin.liviase"
    Write-Output "Versión: $BuildName ($BuildNumber)"
    Write-Output "SHA-256: $hash"
}
finally {
    Pop-Location
    $env:GOOGLE_MAPS_API_KEY = $previousMapsKey
}
