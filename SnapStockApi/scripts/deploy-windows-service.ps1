[CmdletBinding()]
param(
    [SecureString]$DatabaseConnectionString,
    [string]$InstallPath = 'C:\Apis\SnapStock',
    [string]$ServiceName = 'SnapStockApi',
    [string]$ListenUrl = 'http://127.0.0.1:5000'
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Ejecute PowerShell como administrador.'
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$dataRoot = Join-Path $env:ProgramData 'SnapStockApi'
$photosPath = Join-Path $dataRoot 'fotos'
$configPath = Join-Path $dataRoot 'appsettings.Production.json'
$stagingPath = Join-Path ([IO.Path]::GetTempPath()) ("SnapStockApi-" + [Guid]::NewGuid().ToString('N'))
$publishedExecutable = Join-Path $PSScriptRoot 'SnapStockApi.exe'
$runningFromPublishedPackage = Test-Path -LiteralPath $publishedExecutable

New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
New-Item -ItemType Directory -Path $photosPath -Force | Out-Null
if (-not $runningFromPublishedPackage) {
    New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null
}

$existingConfig = $null
if (Test-Path -LiteralPath $configPath) {
    $existingConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

$plainConnection = $null
if ($DatabaseConnectionString) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($DatabaseConnectionString)
    try {
        $plainConnection = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}
elseif ($existingConfig) {
    $plainConnection = $existingConfig.ConnectionStrings.SnapStock
}

if ([string]::IsNullOrWhiteSpace($plainConnection)) {
    throw 'En la primera instalación debe indicar -DatabaseConnectionString usando un SecureString.'
}

$jwtKey = $existingConfig.Jwt.SigningKey
if ([string]::IsNullOrWhiteSpace($jwtKey)) {
    $bytes = [byte[]]::new(64)
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
        $jwtKey = [Convert]::ToBase64String($bytes)
    }
    finally {
        $generator.Dispose()
    }
}

$configuration = [ordered]@{
    ConnectionStrings = [ordered]@{ SnapStock = $plainConnection }
    Jwt = [ordered]@{
        Issuer = 'SnapStockApi'
        Audience = 'SnapStockQR'
        SigningKey = $jwtKey
        ExpirationHours = 168
    }
    Storage = [ordered]@{
        PhotosPath = $photosPath
        PublicBaseUrl = 'https://api.jahmantencion.cl'
    }
}

$configuration | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding UTF8
$acl = Get-Acl -LiteralPath $configPath
$acl.SetAccessRuleProtection($true, $false)
$systemAccount = [Security.Principal.SecurityIdentifier]::new('S-1-5-18').Translate(
    [Security.Principal.NTAccount])
$administratorsAccount = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544').Translate(
    [Security.Principal.NTAccount])
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $systemAccount, 'FullControl', 'Allow'))
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $administratorsAccount, 'FullControl', 'Allow'))
Set-Acl -LiteralPath $configPath -AclObject $acl

$legacyPhotos = Join-Path $InstallPath 'wwwroot\fotos'
if (Test-Path -LiteralPath $legacyPhotos) {
    Get-ChildItem -LiteralPath $legacyPhotos -Force |
        Copy-Item -Destination $photosPath -Recurse -Force
}

$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service -and $service.Status -ne 'Stopped') {
    Stop-Service -Name $ServiceName -Force
    $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
}

try {
    $sourcePath = $PSScriptRoot
    if (-not $runningFromPublishedPackage) {
        dotnet publish (Join-Path $projectRoot 'SnapStockApi.csproj') `
            -c Release `
            -r win-x64 `
            --self-contained true `
            -o $stagingPath
        if ($LASTEXITCODE -ne 0) { throw 'Falló dotnet publish.' }
        $sourcePath = $stagingPath
    }

    if ([IO.Path]::GetFullPath($sourcePath).TrimEnd('\') -ne [IO.Path]::GetFullPath($InstallPath).TrimEnd('\')) {
        Copy-Item -Path (Join-Path $sourcePath '*') -Destination $InstallPath -Recurse -Force
    }
}
finally {
    if (-not $runningFromPublishedPackage -and (Test-Path -LiteralPath $stagingPath)) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force
    }
}

$executable = Join-Path $InstallPath 'SnapStockApi.exe'
$binaryPath = '"{0}" --urls {1}' -f $executable, $ListenUrl
if (-not $service) {
    New-Service `
        -Name $ServiceName `
        -BinaryPathName $binaryPath `
        -DisplayName 'SnapStock API' `
        -Description 'API corporativa de inventario SnapStock QR' `
        -StartupType Automatic
}
else {
    & sc.exe config $ServiceName "binPath= $binaryPath" start= auto | Out-Null
}

& sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/15000/restart/60000 | Out-Null
& sc.exe failureflag $ServiceName 1 | Out-Null
Start-Service -Name $ServiceName

Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" |
    Select-Object Name, State, StartMode, StartName, PathName
