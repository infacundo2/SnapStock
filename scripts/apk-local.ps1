[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'mode-common.ps1')
Assert-Administrator
$mode = Set-SnapStockMode $true
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    $flutterFallback = 'C:\SDK\flutter\bin\flutter.bat'
    if (-not (Test-Path -LiteralPath $flutterFallback)) {
        throw 'Flutter no está instalado o no está incluido en PATH.'
    }
    $flutterCommand = $flutterFallback
}
else {
    $flutterCommand = $flutter.Source
}

$appPath = Join-Path $script:SnapStockRoot 'SnapStockQR 3.0.0'
Push-Location $appPath
try {
    & $flutterCommand pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falló flutter pub get.' }
    & $flutterCommand build apk `
        --release `
        --flavor local `
        "--dart-define=SNAPSTOCK_API_URL=$($mode.LocalApiUrl)"
    if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación de la APK local.' }
}
finally {
    Pop-Location
}

Get-ChildItem -LiteralPath (Join-Path $appPath 'build\app\outputs\flutter-apk') `
    -Filter '*LOCAL*.apk' |
    Select-Object FullName, Length, LastWriteTime
