[CmdletBinding()]
param(
    [string]$ReleaseId = (Get-Date -Format 'yyyyMMdd-HHmm'),
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outputDirectory = Join-Path $projectRoot 'dist\admin-web'
$outputFile = Join-Path $outputDirectory "liviase-admin-$ReleaseId.zip"
$stagingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "liviase-admin-$([guid]::NewGuid().ToString('N'))"

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "No se encontró el comando requerido: $Name"
    }
}

Require-Command php
Require-Command composer
Require-Command npm

Push-Location $projectRoot
try {
    if (-not $SkipTests) {
        php artisan test
        if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas Laravel.' }
    }

    npm ci
    if ($LASTEXITCODE -ne 0) { throw 'Falló npm ci.' }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación Vite.' }

    New-Item -ItemType Directory -Force $stagingDirectory, $outputDirectory | Out-Null

    $directories = @('app', 'bootstrap', 'config', 'database', 'public', 'resources', 'routes')
    foreach ($directory in $directories) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination $stagingDirectory -Recurse
    }

    $publicStorage = Join-Path $stagingDirectory 'public\storage'
    if (Test-Path -LiteralPath $publicStorage) {
        Remove-Item -LiteralPath $publicStorage -Recurse -Force
    }

    foreach ($storagePath in @(
        'storage\app\public',
        'storage\framework\cache\data',
        'storage\framework\sessions',
        'storage\framework\testing',
        'storage\framework\views',
        'storage\logs'
    )) {
        New-Item -ItemType Directory -Force (Join-Path $stagingDirectory $storagePath) | Out-Null
    }

    $files = @(
        'artisan', 'composer.json', 'composer.lock', 'package.json',
        'package-lock.json', 'phpunit.xml', 'vite.config.js', '.env.example'
    )
    foreach ($file in $files) {
        $source = Join-Path $projectRoot $file
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $stagingDirectory
        }
    }

    if (Test-Path -LiteralPath $outputFile) {
        Remove-Item -LiteralPath $outputFile -Force
    }
    Compress-Archive -Path (Join-Path $stagingDirectory '*') -DestinationPath $outputFile -CompressionLevel Optimal

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputFile).Hash
    Set-Content -LiteralPath "$outputFile.sha256" -Value "$hash  $([System.IO.Path]::GetFileName($outputFile))" -Encoding ascii

    Write-Output "Paquete Laravel: $outputFile"
    Write-Output "SHA-256: $hash"
}
finally {
    Pop-Location
    if (Test-Path -LiteralPath $stagingDirectory) {
        Remove-Item -LiteralPath $stagingDirectory -Recurse -Force
    }
}
