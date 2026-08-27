$ErrorActionPreference = 'Stop'

$script:SnapStockRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:ModeSourcePath = Join-Path $script:SnapStockRoot 'snapstock-mode.json'
$script:ModeRuntimePath = Join-Path $env:ProgramData 'SnapStockApi\deployment-mode.json'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Ejecute PowerShell como administrador.'
    }
}

function Set-SnapStockMode([bool]$UseLocal) {
    if (-not (Test-Path -LiteralPath $script:ModeSourcePath)) {
        throw "No se encontró $script:ModeSourcePath"
    }

    $mode = Get-Content -Raw -LiteralPath $script:ModeSourcePath | ConvertFrom-Json
    $mode.UseLocal = $UseLocal
    $modeJson = $mode | ConvertTo-Json -Depth 4
    $modeJson | Set-Content -LiteralPath $script:ModeSourcePath -Encoding UTF8

    $runtimeDirectory = Split-Path -Parent $script:ModeRuntimePath
    New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
    $modeJson | Set-Content -LiteralPath $script:ModeRuntimePath -Encoding UTF8

    $acl = Get-Acl -LiteralPath $script:ModeRuntimePath
    $acl.SetAccessRuleProtection($true, $false)
    $systemAccount = [Security.Principal.SecurityIdentifier]::new('S-1-5-18').Translate(
        [Security.Principal.NTAccount])
    $administratorsAccount = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544').Translate(
        [Security.Principal.NTAccount])
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $systemAccount, 'FullControl', 'Allow'))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $administratorsAccount, 'FullControl', 'Allow'))
    Set-Acl -LiteralPath $script:ModeRuntimePath -AclObject $acl

    return $mode
}

function Start-SnapStockCoreServices {
    foreach ($serviceName in 'SnapStockMySQL', 'SnapStockApi') {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        if ($service.Status -ne 'Running') {
            Start-Service -Name $serviceName
        }
    }

    Restart-Service -Name SnapStockApi -Force
    (Get-Service -Name SnapStockApi).WaitForStatus('Running', [TimeSpan]::FromSeconds(60))
}

function Get-SnapStockHealth {
    return Invoke-RestMethod `
        -Uri 'http://127.0.0.1:5000/api/Registros/test' `
        -TimeoutSec 15
}
