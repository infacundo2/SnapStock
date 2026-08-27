[CmdletBinding()]
param(
    [SecureString]$TunnelToken
)

. (Join-Path $PSScriptRoot 'mode-common.ps1')
Assert-Administrator

$tunnel = Get-Service -Name cloudflared -ErrorAction SilentlyContinue
if (-not $tunnel) {
    $cloudflared = @(
        'C:\Program Files\cloudflared\cloudflared.exe',
        'C:\Program Files (x86)\cloudflared\cloudflared.exe'
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if (-not $cloudflared) {
        throw 'cloudflared no está instalado. Instale el conector oficial antes de activar el modo público.'
    }
    if (-not $TunnelToken) {
        throw 'El túnel aún no está registrado. Ejecute nuevamente con -TunnelToken usando un SecureString.'
    }

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($TunnelToken)
    try {
        $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        & $cloudflared service install $plainToken
        if ($LASTEXITCODE -ne 0) {
            throw "Falló el registro de cloudflared (exit code $LASTEXITCODE)."
        }
    }
    finally {
        $plainToken = $null
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

$mode = Set-SnapStockMode $false
Start-SnapStockCoreServices

$tunnel = Get-Service -Name cloudflared -ErrorAction Stop
if ($tunnel.Status -ne 'Running') {
    Start-Service -Name cloudflared
}

$health = Get-SnapStockHealth
[pscustomobject]@{
    Mode = $health.mode
    ApiUrl = $mode.PublicApiUrl
    PublicBaseUrl = $health.publicBaseUrl
    Api = (Get-Service SnapStockApi).Status
    Database = (Get-Service SnapStockMySQL).Status
    Tunnel = (Get-Service cloudflared).Status
}
