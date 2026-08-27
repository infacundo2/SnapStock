[CmdletBinding()]
param(
    [switch]$KeepPublicTunnel
)

. (Join-Path $PSScriptRoot 'mode-common.ps1')
Assert-Administrator

$mode = Set-SnapStockMode $true
Start-SnapStockCoreServices

$caddy = Get-Service -Name Caddy -ErrorAction SilentlyContinue
if (-not $caddy) {
    throw 'Caddy no está instalado. Ejecute primero la instalación local del proxy HTTPS.'
}
if ($caddy.Status -ne 'Running') {
    Start-Service -Name Caddy
}

$tunnel = Get-Service -Name cloudflared -ErrorAction SilentlyContinue
if ($tunnel -and -not $KeepPublicTunnel -and $tunnel.Status -ne 'Stopped') {
    Stop-Service -Name cloudflared
}

$health = Get-SnapStockHealth
[pscustomobject]@{
    Mode = $health.mode
    ApiUrl = $mode.LocalApiUrl
    PublicBaseUrl = $health.publicBaseUrl
    Api = (Get-Service SnapStockApi).Status
    Database = (Get-Service SnapStockMySQL).Status
    HttpsProxy = (Get-Service Caddy).Status
    Tunnel = if ($tunnel) { (Get-Service cloudflared).Status } else { 'NotInstalled' }
}
