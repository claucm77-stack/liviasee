[CmdletBinding()]
param(
    [ValidatePattern('^https://')]
    [string]$BaseUrl = 'https://liviase.sanmartin.edu.co'
)

$ErrorActionPreference = 'Stop'
$checks = @(
    @{ Name = 'Salud Laravel'; Path = '/up'; Expected = 200 },
    @{ Name = 'Login administrativo'; Path = '/login'; Expected = 200 },
    @{ Name = 'Contenidos públicos'; Path = '/api/contents'; Expected = 200 },
    @{ Name = 'Categorías públicas'; Path = '/api/content-categories'; Expected = 200 },
    @{ Name = 'Campos de micronegocios'; Path = '/api/microbusiness-fields'; Expected = 200 }
)

$failed = $false
foreach ($check in $checks) {
    $uri = $BaseUrl.TrimEnd('/') + $check.Path
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $uri -MaximumRedirection 5
        $ok = $response.StatusCode -eq $check.Expected
        Write-Output ("{0}: HTTP {1} {2}" -f $check.Name, $response.StatusCode, $(if ($ok) { 'OK' } else { 'ERROR' }))
        if (-not $ok) { $failed = $true }
    }
    catch {
        Write-Output ("{0}: ERROR - {1}" -f $check.Name, $_.Exception.Message)
        $failed = $true
    }
}

if ($failed) {
    throw 'Una o más verificaciones de producción fallaron.'
}

Write-Output 'Verificación HTTP de producción completada.'
