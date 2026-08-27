[CmdletBinding()]
param(
    [string]$MySqlBin = 'C:\Program Files\MySQL\mysql-8.4.11-winx64\bin',
    [string]$CredentialsPath = 'C:\ProgramData\SnapStockApi\initial-credentials.txt'
)

$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath $CredentialsPath) {
    throw "Ya existe el archivo de credenciales: $CredentialsPath"
}

$mysql = Join-Path $MySqlBin 'mysql.exe'
if (-not (Test-Path -LiteralPath $mysql)) {
    throw "No se encontró mysql.exe en $MySqlBin"
}

function New-HexSecret([int]$ByteCount) {
    $bytes = [byte[]]::new($ByteCount)
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }
    return [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
}

$rootPassword = New-HexSecret 32
$apiPassword = New-HexSecret 32
$adminPassword = 'Snap-' + (New-HexSecret 12)
$schemaPath = Join-Path $PSScriptRoot 'schema.sql'
$schema = Get-Content -Raw -LiteralPath $schemaPath
$bootstrapSql = @"
$schema
ALTER USER 'root'@'localhost' IDENTIFIED BY '$rootPassword';
CREATE USER 'snapstock_api'@'127.0.0.1' IDENTIFIED BY '$apiPassword';
GRANT SELECT, INSERT, UPDATE, DELETE ON snapstock.* TO 'snapstock_api'@'127.0.0.1';
USE snapstock;
INSERT INTO perfiles(nombre, password, tipo) VALUES ('admin', '$adminPassword', 2);
"@

$bootstrapSql | & $mysql `
    --protocol=PIPE `
    --socket=SnapStockMySQL `
    --user=root `
    --default-character-set=utf8mb4
if ($LASTEXITCODE -ne 0) {
    throw "Falló la creación del esquema (mysql exit code $LASTEXITCODE)."
}

$credentialsDirectory = Split-Path -Parent $CredentialsPath
New-Item -ItemType Directory -Path $credentialsDirectory -Force | Out-Null
@(
    'SnapStock - credenciales iniciales'
    "Generadas: $([DateTimeOffset]::Now.ToString('o'))"
    ''
    'MySQL root: root'
    "MySQL root password: $rootPassword"
    'MySQL API user: snapstock_api'
    "MySQL API password: $apiPassword"
    'Database: snapstock'
    ''
    'APK/API initial admin: admin'
    "APK/API initial admin password: $adminPassword"
    ''
    'Cambie la contraseña inicial del administrador después de validar el acceso.'
) | Set-Content -LiteralPath $CredentialsPath -Encoding UTF8

$acl = Get-Acl -LiteralPath $CredentialsPath
$acl.SetAccessRuleProtection($true, $false)
$systemAccount = [Security.Principal.SecurityIdentifier]::new('S-1-5-18').Translate(
    [Security.Principal.NTAccount])
$administratorsAccount = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544').Translate(
    [Security.Principal.NTAccount])
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $systemAccount, 'FullControl', 'Allow'))
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $administratorsAccount, 'FullControl', 'Allow'))
Set-Acl -LiteralPath $CredentialsPath -AclObject $acl

[pscustomobject]@{
    Database = 'snapstock'
    ApiUser = 'snapstock_api'
    InitialAdmin = 'admin'
    CredentialsFile = $CredentialsPath
}
